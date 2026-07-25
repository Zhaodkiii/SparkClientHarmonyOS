import { AIConfigRepository } from '../../../../Core/AI/Application/AIConfigRepository';
import { AIConfigAPI, ProviderTestResult } from '../../../Core/Networking/API/AI/AIConfigAPI';
import { AIKeyStore } from '../../../../Core/AI/Infrastructure/AIKeyStore';
import { AccountSessionRuntime } from '../../../../App/AccountSessionRuntime';
import {
  AIConfigSnapshot,
  AIDefaultSource,
  AIScenario,
  AITrialStatus,
  LocalModel,
  LocalProvider,
  LocalScenarioBinding,
  LocalSmallTask,
  ModelCapabilities,
  nowIso,
  hydrateSnapshot
} from '../../../../Core/AI/Domain/AIConfigModels';
import { NotificationClient } from '../../../Core/Notification/Application/NotificationClient';
import { AISettingsErrorLocalizer } from '../Application/AISettingsErrorLocalizer';
import { LoadAISettingsUseCase, SaveAISettingsUseCase } from '../Application/LoadSaveAISettingsUseCases';
import { ProviderUseCases } from '../Application/ProviderUseCases';
import { ModelCatalogUseCases } from '../Application/ModelCatalogUseCases';
import { SmallTaskUseCases, TaskReferenceHit } from '../Application/SmallTaskUseCases';
import { ProviderModelCatalogService, ProProviderCredentialPresentation, AIModelPresentation } from '../Application/ProviderModelCatalogService';
import {
  ProviderRemoteModel,
  ProviderRemoteModelFetchService
} from '../Application/ProviderRemoteModelFetchService';
import { AIConfigFlowLog } from '../../../../Core/AI/Infrastructure/AIConfigFlowLog';
import { SupportSystemInfo } from '../../../../Foundation/SupportSystemInfo';

@Observed
export class AISettingsViewModel {
  persistedSnapshot?: AIConfigSnapshot;
  draftSnapshot?: AIConfigSnapshot;
  /** Pro overlay 物化片段：仅供模型页只读展示，不进密钥列表草稿 */
  proOverlayFragment?: AIConfigSnapshot;
  syncStateText: string = 'empty';
  hasUnsavedChanges: boolean = false;
  loading: boolean = false;
  saving: boolean = false;
  trialStatus?: AITrialStatus;
  trialMessage: string = '';
  trialSubmitting: boolean = false;
  testResultMessage: string = '';
  errorMessage: string = '';
  /** 编辑页暂存的 Key 明文（仅内存，确认前不写 HUKS） */
  pendingApiKeyByProvider: Map<string, string> = new Map();
  /** 连通性测试选中的模型名 */
  testModelByProvider: Map<string, string> = new Map();
  keyConfiguredByProvider: Map<string, boolean> = new Map();
  /** 进入设置页后只打一次厂商/模型清单，避免重复刷屏 */
  private providersCatalogLogged: boolean = false;

  private readonly repository: AIConfigRepository;
  private readonly loadUseCase: LoadAISettingsUseCase;
  private readonly saveUseCase: SaveAISettingsUseCase;
  private readonly api: AIConfigAPI;
  private readonly keys: AIKeyStore;
  private readonly session: AccountSessionRuntime;
  private readonly notifications?: NotificationClient;
  private previewTimer?: number;
  private onChanged?: () => void;

  constructor(
    repository: AIConfigRepository,
    api: AIConfigAPI,
    keys: AIKeyStore,
    session: AccountSessionRuntime,
    notifications?: NotificationClient
  ) {
    this.repository = repository;
    this.loadUseCase = new LoadAISettingsUseCase(repository);
    this.saveUseCase = new SaveAISettingsUseCase(repository);
    this.api = api;
    this.keys = keys;
    this.session = session;
    this.notifications = notifications;
  }

  setOnChanged(cb: () => void): void {
    this.onChanged = cb;
  }

  private notify(): void {
    this.onChanged?.();
  }

  private accountId(): number {
    return this.session.activeAccountId ?? 0;
  }

  private setError(err: Object | string | undefined): void {
    this.errorMessage = AISettingsErrorLocalizer.localize(err);
  }

  async load(): Promise<void> {
    const accountId = this.accountId();
    if (accountId <= 0) {
      this.errorMessage = '未登录';
      this.notify();
      return;
    }
    // 设置页加载：ensureSeeded（必要时）→ 读库 → 克隆草稿 → 刷新密钥状态
    AIConfigFlowLog.info('ai.settings.load.begin', `进入 AI 设置，开始加载配置 accountId=${accountId}`);
    this.loading = true;
    this.errorMessage = '';
    this.notify();
    let phase = 'init';
    try {
      phase = 'ensure_seeded_and_load_db';
      const snap = await this.loadUseCase.execute(accountId);
      AIConfigFlowLog.info(
        'ai.settings.load.db_ok',
        `读库完成，准备克隆草稿 ${AIConfigFlowLog.snapshotSummary(snap)} sync=${snap.syncState}`
      );

      // 若上次 Pro 刷新中断，sync 可能卡在 refreshing：设置页按本地可用展示
      if (snap.syncState === 'refreshing') {
        snap.syncState = 'degraded';
        AIConfigFlowLog.warn(
          'ai.settings.load.sync_heal',
          '检测到 syncState=refreshing（疑似上次刷新中断），已降级为 degraded 供页面展示'
        );
      }

      phase = 'clone_snapshot';
      this.persistedSnapshot = snap;
      this.draftSnapshot = AISettingsViewModel.cloneSnapshot(snap);
      this.proOverlayFragment = await this.repository.loadProOverlay(accountId);
      AIConfigFlowLog.info(
        'ai.settings.load.clone_ok',
        `草稿克隆成功 providers=${this.draftSnapshot.providers.length} models=${this.draftSnapshot.models.length} ` +
          `proOverlayModels=${this.proOverlayFragment?.models.length ?? 0}`
      );

      phase = 'apply_ui_state';
      this.syncStateText = snap.syncState;
      this.hasUnsavedChanges = false;
      this.pendingApiKeyByProvider = new Map();

      phase = 'refresh_key_flags';
      await this.refreshKeyFlags();
      AIConfigFlowLog.info(
        'ai.settings.load.keys_ok',
        `密钥状态已刷新 configuredCount=${AISettingsViewModel.countConfigured(this.keyConfiguredByProvider)}/${snap.providers.length}`
      );

      phase = 'trial_status';
      try {
        this.trialStatus = await this.api.trialStatus();
      } catch (trialErr) {
        AIConfigFlowLog.warn('ai.settings.load.trial_skip', `试用状态拉取失败（不阻断） err=${trialErr}`);
      }

      phase = 'done';
      AIConfigFlowLog.info(
        'ai.settings.load.ok',
        `设置页加载完成 accountId=${accountId} providers=${snap.providers.length} models=${snap.models.length} sync=${this.syncStateText}`
      );
    } catch (err) {
      this.setError(err as Object);
      const name = (err as Error)?.name ?? typeof err;
      const message = (err as Error)?.message ?? `${err}`;
      const stack = (err as Error)?.stack ?? '';
      AIConfigFlowLog.warn(
        'ai.settings.load.fail',
        `设置页加载失败 accountId=${accountId} phase=${phase} name=${name} message=${message}`
      );
      if (stack.length > 0) {
        const max = 400;
        const truncated = stack.length > max ? stack.substring(0, max) : stack;
        AIConfigFlowLog.warn('ai.settings.load.fail.stack', `phase=${phase} stack=${truncated}`);
      }
    } finally {
      this.loading = false;
      this.notify();
    }
  }

  private static countConfigured(flags: Map<string, boolean>): number {
    let n = 0;
    flags.forEach((v: boolean) => {
      if (v) {
        n += 1;
      }
    });
    return n;
  }

  /**
   * 进入「模型密钥」页时强制再打一次当前厂商/模型清单（不含密钥明文）。
   */
  logProvidersPageCatalog(): void {
    if (!this.draftSnapshot) {
      return;
    }
    this.providersCatalogLogged = false;
    this.logProvidersCatalogOnce(this.draftSnapshot);
  }

  /**
   * 进入「模型密钥/厂商」相关页面时，打印一次当前加载到的厂商与模型（不含密钥明文）。
   */
  private logProvidersCatalogOnce(snap: AIConfigSnapshot): void {
    if (this.providersCatalogLogged) {
      return;
    }
    this.providersCatalogLogged = true;
    const rows = ProviderModelCatalogService.localCredentialProviders(snap, this.keyConfiguredByProvider);
    const keyFlags: string[] = [];
    for (let i = 0; i < rows.length; i++) {
      const row = rows[i];
      keyFlags.push(`${row.providerId}(${row.sourceLabel}):key=${row.credentialState === 'ready' ? 'yes' : 'no'}`);
    }
    AIConfigFlowLog.info(
      'ai.provider_catalog.local.begin',
      `模型密钥页-本地凭证目录 count=${rows.length}`
    );
    AIConfigFlowLog.info(
      'ai.settings.catalog',
      `模型密钥页-厂商清单 count=${rows.length} keys=[${keyFlags.join(',')}] ` +
        `proOverlayExcluded=${this.proOverlayFragment?.providers.length ?? 0}`
    );
    AIConfigFlowLog.info(
      'ai.settings.models',
      `模型密钥页-本地模型清单 count=${snap.models.length} ${AIConfigFlowLog.modelsBrief(snap.models, 40)}`
    );
  }

  private async refreshKeyFlags(): Promise<void> {
    this.keyConfiguredByProvider.clear();
    if (!this.draftSnapshot) {
      return;
    }
    for (let i = 0; i < this.draftSnapshot.providers.length; i++) {
      const p = this.draftSnapshot.providers[i];
      const has = await this.keys.hasSecret(p.secretRef);
      this.keyConfiguredByProvider.set(p.id, has);
    }
  }

  async refreshRemote(): Promise<void> {
    const accountId = this.accountId();
    this.loading = true;
    this.errorMessage = '';
    this.notify();
    const clientVersion = new SupportSystemInfo().collect().appVersion;
    AIConfigFlowLog.info(
      'ai.refresh.begin',
      `scope=aiBootstrap accountId=${accountId} platform=harmonyos clientVersion=${clientVersion}`
    );
    try {
      const result = await this.repository.refreshRemote(accountId, clientVersion);
      this.syncStateText = result.state;
      if (result.reason === 'revision_unchanged') {
        AIConfigFlowLog.info('ai.refresh.no_change', `revision=${result.revision ?? '-'}`);
      }
      await this.load();
    } catch (err) {
      this.setError(err as Object);
      AIConfigFlowLog.warn('ai.refresh.degraded', `err=${err}`);
    } finally {
      this.loading = false;
      this.notify();
    }
  }

  markDirty(): void {
    this.hasUnsavedChanges = true;
    this.notify();
    if (this.previewTimer !== undefined) {
      clearTimeout(this.previewTimer);
    }
    this.previewTimer = setTimeout(() => {
      this.applyDraftPreview();
    }, 300) as number;
  }

  private async applyDraftPreview(): Promise<void> {
    if (!this.draftSnapshot) {
      return;
    }
    try {
      await this.saveUseCase.saveDraft(this.accountId(), this.draftSnapshot);
    } catch (_e) {
      // 预览失败忽略
    }
  }

  async save(): Promise<void> {
    if (!this.draftSnapshot) {
      return;
    }
    const accountId = this.accountId();
    this.saving = true;
    this.errorMessage = '';
    this.notify();
    try {
      AIConfigFlowLog.info(
        'ai.settings.save.begin',
        `设置页确认保存 ${AIConfigFlowLog.catalogWriteSummary(
          accountId,
          this.draftSnapshot.providers.length,
          this.draftSnapshot.models.length,
          this.draftSnapshot.scenarioBindings.length,
          this.draftSnapshot.smallTasks.length,
          this.draftSnapshot.modelFiles.length,
          `pendingKeys=${this.pendingApiKeyByProvider.size}`
        )}`
      );
      // 确认写入所有 pending Key
      const pendingIds: string[] = [];
      this.pendingApiKeyByProvider.forEach((_v: string, k: string) => {
        pendingIds.push(k);
      });
      for (let i = 0; i < pendingIds.length; i++) {
        const pid = pendingIds[i];
        const key = this.pendingApiKeyByProvider.get(pid) ?? '';
        if (key.length > 0) {
          const ref = await this.keys.put(accountId, pid, key);
          const provider = ProviderUseCases.find(this.draftSnapshot, pid);
          if (provider) {
            provider.secretRef = ref;
          }
        }
      }
      this.pendingApiKeyByProvider.clear();
      this.draftSnapshot.updatedAt = nowIso();
      await this.saveUseCase.execute(accountId, this.draftSnapshot);
      this.persistedSnapshot = AISettingsViewModel.cloneSnapshot(this.draftSnapshot);
      this.hasUnsavedChanges = false;
      this.syncStateText = 'localReady';
      await this.refreshKeyFlags();
      AIConfigFlowLog.info(
        'ai.settings.save.ok',
        `设置页保存完成 accountId=${accountId} ` +
          `厂商=${this.draftSnapshot.providers.length} 模型=${this.draftSnapshot.models.length} ` +
          `小任务=${this.draftSnapshot.smallTasks.length}`
      );
      this.notifications?.success('AI 设置已保存', undefined, 'AISettings');
    } catch (err) {
      AIConfigFlowLog.warn(
        'ai.settings.save.fail',
        `设置页保存失败 accountId=${accountId} err=${err}`
      );
      this.setError(err as Object);
      this.hasUnsavedChanges = true;
    } finally {
      this.saving = false;
      this.notify();
    }
  }

  discard(): void {
    if (!this.persistedSnapshot) {
      return;
    }
    this.draftSnapshot = AISettingsViewModel.cloneSnapshot(this.persistedSnapshot);
    this.pendingApiKeyByProvider.clear();
    this.hasUnsavedChanges = false;
    this.errorMessage = '';
    this.notify();
    this.refreshKeyFlags().then(() => this.notify());
  }

  /** 仅更新内存草稿中的待写 Key，不触碰 HUKS */
  setPendingProviderKey(providerId: string, apiKey: string): void {
    if (apiKey.length === 0) {
      this.pendingApiKeyByProvider.delete(providerId);
    } else {
      this.pendingApiKeyByProvider.set(providerId, apiKey);
    }
    this.markDirty();
  }

  /** 编辑页「确认写入 Key」：立即写 HUKS 并更新 secretRef */
  async confirmProviderKey(providerId: string): Promise<void> {
    if (!this.draftSnapshot) {
      return;
    }
    const apiKey = this.pendingApiKeyByProvider.get(providerId) ?? '';
    if (apiKey.length === 0) {
      this.errorMessage = '请先输入 API Key';
      this.notify();
      return;
    }
    try {
      const ref = await this.keys.put(this.accountId(), providerId, apiKey);
      const p = ProviderUseCases.find(this.draftSnapshot, providerId);
      if (p) {
        p.secretRef = ref;
      }
      this.pendingApiKeyByProvider.delete(providerId);
      this.keyConfiguredByProvider.set(providerId, true);
      this.markDirty();
      this.notifications?.success('API Key 已安全保存', undefined, 'AISettings');
    } catch (err) {
      this.setError(err as Object);
      this.notify();
    }
  }

  setProviderEnabled(providerId: string, enabled: boolean): void {
    if (!this.draftSnapshot) {
      return;
    }
    ProviderUseCases.setEnabled(this.draftSnapshot, providerId, enabled);
    this.markDirty();
  }

  /**
   * 列表页启停：启用前必须有 pending Key 或已配置 HUKS；成功后立即落盘（对标 iOS setProviderEnabledAndPersist）。
   */
  async setProviderEnabledAndPersist(providerId: string, enabled: boolean): Promise<boolean> {
    if (!this.draftSnapshot) {
      return false;
    }
    if (enabled) {
      const pending = (this.pendingApiKeyByProvider.get(providerId) ?? '').trim();
      if (pending.length === 0 && !this.isKeyConfigured(providerId)) {
        this.errorMessage = '请先配置有效 API Key';
        this.notify();
        return false;
      }
    }
    ProviderUseCases.setEnabled(this.draftSnapshot, providerId, enabled);
    this.markDirty();
    await this.save();
    return this.errorMessage.length === 0;
  }

  /**
   * 编辑页开关：与列表页同一套启停/落盘语义（对标 iOS setProviderEnabledFromEditorAndPersist）。
   */
  async setProviderEnabledFromEditorAndPersist(providerId: string, enabled: boolean): Promise<boolean> {
    return await this.setProviderEnabledAndPersist(providerId, enabled);
  }

  /**
   * 编辑页保存：写入 URL + pending Key，立即持久化并刷新 Runtime（对标 iOS saveProviderFromEditorAndPersist）。
   */
  async saveProviderFromEditorAndPersist(providerId: string, requestUrl: string): Promise<boolean> {
    if (!this.draftSnapshot) {
      return false;
    }
    const provider = ProviderUseCases.find(this.draftSnapshot, providerId);
    if (!provider) {
      this.errorMessage = 'Provider 不存在';
      this.notify();
      return false;
    }
    if (provider.isEnabled) {
      const pending = (this.pendingApiKeyByProvider.get(providerId) ?? '').trim();
      if (pending.length === 0 && !this.isKeyConfigured(providerId)) {
        this.errorMessage = '请先配置有效 API Key';
        this.notify();
        return false;
      }
    }
    ProviderUseCases.setRequestUrl(this.draftSnapshot, providerId, requestUrl.trim());
    this.markDirty();
    await this.save();
    return this.errorMessage.length === 0;
  }

  /** 编辑页删除模型并立即落盘（对标 iOS deleteModelAndPersist） */
  async deleteModelAndPersist(modelId: string): Promise<boolean> {
    if (!this.draftSnapshot) {
      return false;
    }
    try {
      ModelCatalogUseCases.delete(this.draftSnapshot, modelId);
      this.markDirty();
      await this.save();
      return this.errorMessage.length === 0;
    } catch (err) {
      this.setError(err as Object);
      this.notify();
      return false;
    }
  }

  setProviderRequestUrl(providerId: string, url: string): void {
    if (!this.draftSnapshot) {
      return;
    }
    ProviderUseCases.setRequestUrl(this.draftSnapshot, providerId, url);
    this.markDirty();
  }

  addCustomProvider(company: string, name: string, url: string): LocalProvider {
    if (!this.draftSnapshot) {
      throw new Error('未加载');
    }
    const p = ProviderUseCases.createCustom(company, name, url);
    ProviderUseCases.upsert(this.draftSnapshot, p);
    this.markDirty();
    return p;
  }

  /**
   * 新增自定义供应商并立即持久化（对标 iOS addProviderAndPersist / AddCustomProviderSheet）。
   * 自动生成 CUSTOM_XXXXXXXX company；写入 HUKS 后落盘，不做连通性测试。
   */
  async addCustomProviderAndPersist(name: string, apiKey: string, requestUrl: string): Promise<boolean> {
    if (!this.draftSnapshot) {
      this.errorMessage = '未加载';
      this.notify();
      return false;
    }
    const accountId = this.accountId();
    if (accountId <= 0) {
      this.errorMessage = '未登录';
      this.notify();
      return false;
    }
    const trimmedName = name.trim();
    const key = apiKey.trim();
    const url = requestUrl.trim();
    if (trimmedName.length === 0 || key.length === 0 || url.length === 0) {
      this.errorMessage = '请填写完整信息';
      this.notify();
      return false;
    }
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      this.errorMessage = '请求地址必须以 http:// 或 https:// 开头';
      this.notify();
      return false;
    }

    const suffix = `${Date.now().toString(16).toUpperCase().slice(-8)}`;
    const company = `CUSTOM_${suffix}`;
    let secretRef: string | undefined = undefined;
    let providerId = '';
    this.saving = true;
    this.errorMessage = '';
    this.notify();
    try {
      const p = ProviderUseCases.createCustom(company, trimmedName, url, suffix);
      providerId = p.id;
      secretRef = await this.keys.put(accountId, p.id, key);
      p.secretRef = secretRef;
      p.isEnabled = true;
      ProviderUseCases.upsert(this.draftSnapshot, p);
      this.draftSnapshot.updatedAt = nowIso();
      await this.saveUseCase.execute(accountId, this.draftSnapshot);
      this.persistedSnapshot = AISettingsViewModel.cloneSnapshot(this.draftSnapshot);
      this.hasUnsavedChanges = false;
      this.keyConfiguredByProvider.set(p.id, true);
      this.syncStateText = 'localReady';
      this.notifications?.success('自定义供应商已保存', undefined, 'AISettings');
      this.notify();
      return true;
    } catch (err) {
      if (secretRef) {
        try {
          await this.keys.delete(secretRef);
        } catch (_e) {
          // ignore rollback failure
        }
      }
      if (this.draftSnapshot && providerId.length > 0) {
        this.draftSnapshot.providers =
          this.draftSnapshot.providers.filter((x: LocalProvider) => x.id !== providerId);
      }
      this.setError(err as Object);
      this.notify();
      return false;
    } finally {
      this.saving = false;
      this.notify();
    }
  }

  /**
   * 自定义供应商原子保存：校验 → 连通性测试 → HUKS → RDB → Runtime。
   * 任一步失败回滚本次 HUKS，不留下半套目录。
   */
  async saveCustomProviderAtomic(
    company: string,
    name: string,
    url: string,
    apiKey: string,
    testModel: string
  ): Promise<LocalProvider> {
    if (!this.draftSnapshot) {
      throw new Error('未加载');
    }
    const accountId = this.accountId();
    if (accountId <= 0) {
      throw new Error('未登录');
    }
    const key = apiKey.trim();
    const model = testModel.trim();
    if (key.length === 0) {
      throw new Error('请填写 API Key');
    }
    if (model.length === 0) {
      throw new Error('请填写用于连通性测试的模型名');
    }
    const p = ProviderUseCases.createCustom(company, name, url);
    if (!p.requestUrl) {
      throw new Error('缺少 requestUrl');
    }

    this.saving = true;
    this.errorMessage = '';
    this.notify();
    let secretRef: string | undefined = undefined;
    try {
      const result: ProviderTestResult = await this.api.testProviderConnection(p.requestUrl, key, model);
      if (!result.isReachable) {
        throw new Error(result.message ?? '连通性测试失败');
      }
      secretRef = await this.keys.put(accountId, p.id, key);
      p.secretRef = secretRef;
      // 测试成功后再启用
      p.isEnabled = true;
      ProviderUseCases.upsert(this.draftSnapshot, p);
      this.draftSnapshot.updatedAt = nowIso();
      await this.saveUseCase.execute(accountId, this.draftSnapshot);
      this.persistedSnapshot = AISettingsViewModel.cloneSnapshot(this.draftSnapshot);
      this.hasUnsavedChanges = false;
      this.keyConfiguredByProvider.set(p.id, true);
      this.syncStateText = 'localReady';
      this.notifications?.success('自定义供应商已保存', undefined, 'AISettings');
      this.notify();
      return p;
    } catch (err) {
      if (secretRef) {
        try {
          await this.keys.delete(secretRef);
        } catch (_e) {
          // ignore rollback failure
        }
      }
      // 回滚草稿中的插入
      if (this.draftSnapshot) {
        this.draftSnapshot.providers = this.draftSnapshot.providers.filter((x: LocalProvider) => x.id !== p.id);
      }
      this.setError(err as Object);
      this.notify();
      throw new Error(AISettingsErrorLocalizer.localize(err as Object));
    } finally {
      this.saving = false;
      this.notify();
    }
  }

  upsertProvider(provider: LocalProvider): void {
    if (!this.draftSnapshot) {
      return;
    }
    ProviderUseCases.upsert(this.draftSnapshot, provider);
    this.markDirty();
  }

  deleteProvider(providerId: string): void {
    if (!this.draftSnapshot) {
      return;
    }
    try {
      ProviderUseCases.delete(this.draftSnapshot, providerId);
      this.markDirty();
    } catch (err) {
      this.setError(err as Object);
      this.notify();
    }
  }

  setScenarioDefault(scenario: string, modelId: string): void {
    if (!this.draftSnapshot) {
      return;
    }
    for (let i = 0; i < this.draftSnapshot.scenarioBindings.length; i++) {
      const b = this.draftSnapshot.scenarioBindings[i];
      if (b.scenario === scenario) {
        b.isDefault = b.modelId === modelId;
      }
    }
    this.markDirty();
  }

  setScenarioSource(scenario: string, source: AIDefaultSource): void {
    if (!this.draftSnapshot) {
      return;
    }
    this.draftSnapshot.preferences.scenarioSources[scenario] = source;
    this.markDirty();
  }

  scenarioSource(scenario: string): AIDefaultSource {
    const map = this.draftSnapshot?.preferences.scenarioSources;
    if (map && map[scenario]) {
      return map[scenario];
    }
    return this.draftSnapshot?.preferences.defaultSource ?? 'auto';
  }

  upsertBinding(binding: LocalScenarioBinding): void {
    if (!this.draftSnapshot) {
      return;
    }
    binding.updatedAt = nowIso();
    let found = false;
    for (let i = 0; i < this.draftSnapshot.scenarioBindings.length; i++) {
      const b = this.draftSnapshot.scenarioBindings[i];
      if (b.scenario === binding.scenario && b.modelId === binding.modelId) {
        this.draftSnapshot.scenarioBindings[i] = binding;
        found = true;
      }
    }
    if (!found) {
      this.draftSnapshot.scenarioBindings.push(binding);
    }
    if (binding.isDefault) {
      this.setScenarioDefault(binding.scenario, binding.modelId);
    } else {
      this.markDirty();
    }
  }

  setModelEnabled(modelId: string, enabled: boolean): void {
    if (!this.draftSnapshot) {
      return;
    }
    try {
      const m = ModelCatalogUseCases.findModel(this.draftSnapshot, modelId);
      const has = m ? (this.keyConfiguredByProvider.get(m.providerId) === true) : false;
      ModelCatalogUseCases.setEnabled(this.draftSnapshot, modelId, enabled, has);
      this.markDirty();
    } catch (err) {
      this.setError(err as Object);
      this.notify();
    }
  }

  /** 对标 iOS setModelVisibilityAndPersist：开关后立即落盘 */
  async setModelEnabledAndPersist(modelId: string, enabled: boolean): Promise<boolean> {
    try {
      this.setModelEnabled(modelId, enabled);
      if (this.errorMessage.length > 0) {
        return false;
      }
      await this.save();
      return this.errorMessage.length === 0;
    } catch (err) {
      this.setError(err as Object);
      this.notify();
      return false;
    }
  }

  upsertModel(model: LocalModel): void {
    if (!this.draftSnapshot) {
      return;
    }
    ModelCatalogUseCases.upsert(this.draftSnapshot, model);
    this.markDirty();
  }

  /** 对标 iOS replaceModelAndPersist */
  async replaceModelAndPersist(model: LocalModel): Promise<boolean> {
    if (!this.draftSnapshot) {
      return false;
    }
    try {
      ModelCatalogUseCases.upsert(this.draftSnapshot, model);
      this.markDirty();
      await this.save();
      return this.errorMessage.length === 0;
    } catch (err) {
      this.setError(err as Object);
      this.notify();
      return false;
    }
  }

  addOnlineModel(
    providerId: string,
    name: string,
    displayName: string,
    caps: ModelCapabilities
  ): LocalModel {
    if (!this.draftSnapshot) {
      throw new Error('未加载');
    }
    const m = ModelCatalogUseCases.createOnline(providerId, name, displayName, caps);
    ModelCatalogUseCases.upsert(this.draftSnapshot, m);
    this.markDirty();
    return m;
  }

  /** 管理页添加在线模型并立即落盘（对标 iOS AddOnlineModelSheet 确认） */
  async addOnlineModelAndPersist(
    providerId: string,
    name: string,
    displayName: string,
    caps: ModelCapabilities
  ): Promise<boolean> {
    return this.addOnlineModelAndPersistFull(providerId, name, displayName, caps, 2, false);
  }

  /** 完整字段落盘：价格档位 + 默认隐藏（对标 iOS appendOnlineModelAndPersist） */
  async addOnlineModelAndPersistFull(
    providerId: string,
    name: string,
    displayName: string,
    caps: ModelCapabilities,
    priceTier: number,
    isHidden: boolean
  ): Promise<boolean> {
    try {
      if (!this.draftSnapshot) {
        throw new Error('未加载');
      }
      const m = ModelCatalogUseCases.createOnline(
        providerId,
        name,
        displayName,
        caps,
        priceTier,
        isHidden
      );
      ModelCatalogUseCases.upsert(this.draftSnapshot, m);
      this.markDirty();
      await this.save();
      return this.errorMessage.length === 0;
    } catch (err) {
      this.setError(err as Object);
      this.notify();
      return false;
    }
  }

  /**
   * 解析厂商明文 Key：优先 pending，再 HUKS secretRef。
   * 仅短暂用于远端目录刷新 / 连通性测试，不落盘、不日志。
   */
  async resolveProviderApiKey(providerId: string): Promise<string> {
    let apiKey = (this.pendingApiKeyByProvider.get(providerId) ?? '').trim();
    if (apiKey.length > 0) {
      return apiKey;
    }
    const provider = this.draftSnapshot ? ProviderUseCases.find(this.draftSnapshot, providerId) : undefined;
    if (provider?.secretRef) {
      try {
        apiKey = ((await this.keys.get(provider.secretRef)) ?? '').trim();
      } catch (err) {
        this.setError(err as Object);
        this.notify();
        return '';
      }
    }
    return apiKey;
  }

  /** 对标 iOS fetchRemoteModels(for:) */
  async fetchRemoteModels(providerId: string, requestUrl: string): Promise<ProviderRemoteModel[]> {
    const apiKey = await this.resolveProviderApiKey(providerId);
    return ProviderRemoteModelFetchService.fetchModels(requestUrl, apiKey);
  }

  upsertAgent(displayName: string, baseModelId: string, systemProvision: string, existingId?: string): LocalModel {
    if (!this.draftSnapshot) {
      throw new Error('未加载');
    }
    const agent = ModelCatalogUseCases.upsertAgent(
      this.draftSnapshot,
      displayName,
      baseModelId,
      systemProvision,
      existingId
    );
    this.markDirty();
    return agent;
  }

  deleteModel(modelId: string): void {
    if (!this.draftSnapshot) {
      return;
    }
    try {
      ModelCatalogUseCases.delete(this.draftSnapshot, modelId);
      this.markDirty();
    } catch (err) {
      this.setError(err as Object);
      this.notify();
    }
  }

  upsertSmallTask(task: LocalSmallTask): void {
    if (!this.draftSnapshot) {
      return;
    }
    try {
      SmallTaskUseCases.upsert(this.draftSnapshot, task);
      AIConfigFlowLog.info(
        'ai.small_task.upsert',
        `小任务草稿已更新 accountId=${this.accountId()} code=${task.code} ` +
          `name=${task.name} tools=${task.toolList.length} enabled=${task.isEnabled} ` +
          `totalTasks=${this.draftSnapshot.smallTasks.length}`
      );
      this.markDirty();
    } catch (err) {
      this.setError(err as Object);
      this.notify();
      throw new Error(AISettingsErrorLocalizer.localize(err as Object));
    }
  }

  taskReferences(code: string): TaskReferenceHit[] {
    if (!this.draftSnapshot) {
      return [];
    }
    return SmallTaskUseCases.findReferences(this.draftSnapshot, code);
  }

  deleteSmallTask(code: string): void {
    if (!this.draftSnapshot) {
      return;
    }
    try {
      SmallTaskUseCases.delete(this.draftSnapshot, code);
      AIConfigFlowLog.info(
        'ai.small_task.delete',
        `小任务草稿已删除 accountId=${this.accountId()} code=${code} ` +
          `remaining=${this.draftSnapshot.smallTasks.length}`
      );
      this.markDirty();
    } catch (err) {
      this.setError(err as Object);
      this.notify();
      throw new Error(AISettingsErrorLocalizer.localize(err as Object));
    }
  }

  async applyTrial(note: string): Promise<boolean> {
    if (this.trialSubmitting) {
      return false;
    }
    this.trialSubmitting = true;
    this.trialMessage = '';
    this.notify();
    try {
      const result = await this.api.applyTrial(note);
      this.trialMessage = result.message ?? (result.submitted ? '已提交试用申请' : '申请失败');
      this.trialStatus = await this.api.trialStatus();
      return result.submitted === true;
    } catch (err) {
      this.trialMessage = AISettingsErrorLocalizer.localize(err as Object);
      return false;
    } finally {
      this.trialSubmitting = false;
      this.notify();
    }
  }

  setTestModel(providerId: string, modelName: string): void {
    this.testModelByProvider.set(providerId, modelName);
    this.notify();
  }

  async testProvider(provider: LocalProvider): Promise<void> {
    this.testResultMessage = '';
    this.notify();
    let apiKey = this.pendingApiKeyByProvider.get(provider.id) ?? '';
    if (apiKey.length === 0 && provider.secretRef) {
      try {
        apiKey = (await this.keys.get(provider.secretRef)) ?? '';
      } catch (err) {
        this.testResultMessage = AISettingsErrorLocalizer.localize(err as Object);
        this.notify();
        return;
      }
    }
    if (!provider.requestUrl) {
      this.testResultMessage = '缺少 requestUrl';
      this.notify();
      return;
    }
    let modelName = this.testModelByProvider.get(provider.id) ?? '';
    if (modelName.length === 0 && this.draftSnapshot) {
      const texts = ProviderModelCatalogService.enabledTextModels(this.draftSnapshot, provider.id);
      if (texts.length > 0) {
        modelName = texts[0].name;
      }
    }
    if (modelName.length === 0) {
      this.testResultMessage = '请先选择已启用的文本模型';
      this.notify();
      return;
    }
    try {
      const result: ProviderTestResult = await this.api.testProviderConnection(
        provider.requestUrl,
        apiKey,
        modelName
      );
      this.testResultMessage = result.isReachable ? '连通成功' : (result.message ?? '不可达');
    } catch (err) {
      this.testResultMessage = AISettingsErrorLocalizer.localize(err as Object);
    }
    this.notify();
  }

  /**
   * 编辑页连通性测试（对标 iOS testProviderConnection）。
   * 优先用草稿 URL + pending/HUKS Key；返回结构化结果供 UI 展示。
   */
  async testProviderConnectionFromEditor(
    providerId: string,
    requestUrl: string,
    modelName: string
  ): Promise<ProviderTestResult> {
    const out = new ProviderTestResult();
    out.reachable = false;
    let apiKey = (this.pendingApiKeyByProvider.get(providerId) ?? '').trim();
    if (apiKey.length === 0) {
      const provider = this.draftSnapshot ? ProviderUseCases.find(this.draftSnapshot, providerId) : undefined;
      if (provider?.secretRef) {
        try {
          apiKey = (await this.keys.get(provider.secretRef)) ?? '';
        } catch (err) {
          out.message = AISettingsErrorLocalizer.localize(err as Object);
          return out;
        }
      }
    }
    if (apiKey.length === 0) {
      out.message = '请先配置有效 API Key';
      return out;
    }
    const url = requestUrl.trim();
    if (url.length === 0) {
      out.message = '缺少 requestUrl';
      return out;
    }
    const model = modelName.trim();
    if (model.length === 0) {
      out.message = '当前厂商无可测试模型，请先配置模型';
      return out;
    }
    try {
      return await this.api.testProviderConnection(url, apiKey, model);
    } catch (err) {
      out.message = AISettingsErrorLocalizer.localize(err as Object);
      return out;
    }
  }

  providers(): LocalProvider[] {
    return this.localCredentialProviders();
  }

  /** 模型密钥页：仅本地 seed/custom API Provider */
  localCredentialProviders(): LocalProvider[] {
    const snap = this.draftSnapshot;
    if (!snap) {
      return [];
    }
    const rows = ProviderModelCatalogService.localCredentialProviders(snap, this.keyConfiguredByProvider);
    const out: LocalProvider[] = [];
    for (let i = 0; i < rows.length; i++) {
      const found = this.findProvider(rows[i].providerId);
      if (found) {
        out.push(found);
      }
    }
    return out;
  }

  /** @deprecated 使用 localCredentialProviders */
  proCredentialProviders(): LocalProvider[] {
    return this.localCredentialProviders();
  }

  localCredentialRows(): ProProviderCredentialPresentation[] {
    if (!this.draftSnapshot) {
      return [];
    }
    return ProviderModelCatalogService.localCredentialProviders(this.draftSnapshot, this.keyConfiguredByProvider);
  }

  /** @deprecated 使用 localCredentialRows */
  proCredentialRows(): ProProviderCredentialPresentation[] {
    return this.localCredentialRows();
  }

  visibleModelRows(filter: string, query: string): AIModelPresentation[] {
    if (!this.draftSnapshot) {
      return [];
    }
    const catalogFilter = filter === 'models' || filter === 'agents' || filter === 'local' || filter === 'pro'
      ? filter
      : 'all';
    return ProviderModelCatalogService.visibleModelsMerged(
      this.draftSnapshot,
      this.proOverlayFragment,
      catalogFilter,
      query,
      this.keyConfiguredByProvider
    );
  }

  isProModelRow(modelId: string): boolean {
    if (modelId.indexOf('pro:') === 0) {
      return true;
    }
    const frag = this.proOverlayFragment;
    if (!frag) {
      return false;
    }
    for (let i = 0; i < frag.models.length; i++) {
      if (frag.models[i].id === modelId) {
        return true;
      }
    }
    return false;
  }

  private findProvider(providerId: string): LocalProvider | undefined {
    const list = this.draftSnapshot?.providers ?? [];
    for (let i = 0; i < list.length; i++) {
      if (list[i].id === providerId) {
        return list[i];
      }
    }
    return undefined;
  }

  models(): LocalModel[] {
    const local = this.draftSnapshot?.models ?? [];
    const pro = this.proOverlayFragment?.models ?? [];
    if (pro.length === 0) {
      return local;
    }
    return local.concat(pro);
  }

  smallTasks(): LocalSmallTask[] {
    const local = this.draftSnapshot?.smallTasks ?? [];
    const pro = this.proOverlayFragment?.smallTasks ?? [];
    if (pro.length === 0) {
      return local;
    }
    const out = local.slice();
    for (let i = 0; i < pro.length; i++) {
      if (out.some((t) => t.code === pro[i].code)) {
        continue;
      }
      out.push(pro[i]);
    }
    return out;
  }

  knownScenarios(): string[] {
    return AIScenario.allKnown();
  }

  bindingsForScenario(scenario: string): LocalScenarioBinding[] {
    const local = (this.draftSnapshot?.scenarioBindings ?? []).filter((b) => b.scenario === scenario);
    const pro = (this.proOverlayFragment?.scenarioBindings ?? []).filter((b) => b.scenario === scenario);
    if (pro.length === 0) {
      return local;
    }
    return local.concat(pro);
  }

  isKeyConfigured(providerId: string): boolean {
    return this.keyConfiguredByProvider.get(providerId) === true;
  }

  private static cloneSnapshot(src: AIConfigSnapshot): AIConfigSnapshot {
    // 直接 hydrate 深拷贝；勿依赖 JSON.stringify（会把 capabilities 变成无 toJson 的普通对象）
    return hydrateSnapshot(src);
  }
}
