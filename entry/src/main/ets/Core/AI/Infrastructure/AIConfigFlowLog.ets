import { Logger } from '../../../Foundation/Logging/Logger';
import { LogModule } from '../../../Foundation/Logging/LogModule';
import { LogFields } from '../../../Foundation/Logging/LogEvent';
import {
  AIConfigSnapshot,
  LocalModel,
  LocalProvider,
  RuntimeSnapshot
} from '../Domain/AIConfigModels';
import { isLocalCompany, isLocalProviderId } from '../Domain/AILocalProviderIds';

/**
 * AI 配置生命周期专用日志。
 * 注意：Logger 的 event 必须是小写点分名（如 ai.seed.begin），
 * 中文说明与排查细节一律放在 LogFields.detail，否则会被改写成 general.invalid_event。
 * detail 超过约 180 字会按空格语义拆成多条，避免全局 200 字截断丢原因，也避免半截 key=value。
 */
export class AIConfigFlowLog {
  /** 预留 `[n/m] ` 前缀与 sanitizer 余量；单段不超过 180 */
  private static readonly CHUNK: number = 180;

  static info(event: string, detail: string): void {
    AIConfigFlowLog.emit('info', event, detail);
  }

  static warn(event: string, detail: string): void {
    AIConfigFlowLog.emit('warn', event, detail);
  }

  static debug(event: string, detail: string): void {
    AIConfigFlowLog.emit('debug', event, detail);
  }

  /**
   * 主动按语义段输出多条（每段独立 event.pN），避免超长拼接后再盲切。
   * 空段跳过；单段超长时先按空格切开，再统一编号，避免嵌套 [n/m]。
   */
  static infoParts(event: string, parts: string[]): void {
    const chunks: string[] = [];
    for (let i = 0; i < parts.length; i++) {
      const p = parts[i];
      if (!p || p.length === 0) {
        continue;
      }
      if (p.length <= AIConfigFlowLog.CHUNK) {
        chunks.push(p);
      } else {
        const split = AIConfigFlowLog.splitAtWordBoundary(p, AIConfigFlowLog.CHUNK);
        for (let j = 0; j < split.length; j++) {
          chunks.push(split[j]);
        }
      }
    }
    if (chunks.length === 0) {
      return;
    }
    if (chunks.length === 1) {
      AIConfigFlowLog.write('info', event, chunks[0]);
      return;
    }
    const total = chunks.length;
    for (let i = 0; i < chunks.length; i++) {
      const part = i + 1;
      const ev = part === 1 ? event : `${event}.p${part}`;
      AIConfigFlowLog.write('info', ev, `[${part}/${total}] ${chunks[i]}`);
    }
  }

  private static emit(level: string, event: string, detail: string): void {
    if (!detail || detail.length <= AIConfigFlowLog.CHUNK) {
      AIConfigFlowLog.write(level, event, detail);
      return;
    }
    const chunks = AIConfigFlowLog.splitAtWordBoundary(detail, AIConfigFlowLog.CHUNK);
    const total = chunks.length;
    for (let i = 0; i < chunks.length; i++) {
      const part = i + 1;
      const ev = part === 1 ? event : `${event}.p${part}`;
      AIConfigFlowLog.write(level, ev, `[${part}/${total}] ${chunks[i]}`);
    }
  }

  /** 在不超过 limit 的前提下优先按空格切断，避免把 `overlay=yes` 拆成 `overlay` / `=yes` */
  private static splitAtWordBoundary(text: string, limit: number): string[] {
    const out: string[] = [];
    let rest = text;
    while (rest.length > limit) {
      let cut = limit;
      const window = rest.substring(0, limit + 1);
      const sp = window.lastIndexOf(' ');
      if (sp >= Math.floor(limit * 0.55)) {
        cut = sp;
      }
      out.push(rest.substring(0, cut).trimEnd());
      rest = rest.substring(cut).trimStart();
    }
    if (rest.length > 0) {
      out.push(rest);
    }
    return out;
  }

  private static write(level: string, event: string, detail: string): void {
    const fields = new LogFields();
    fields.detail = detail;
    if (level === 'warn') {
      Logger.warn(event, LogModule.AI_CONFIG, fields);
    } else if (level === 'debug') {
      Logger.debug(event, LogModule.AI_CONFIG, fields);
    } else {
      Logger.info(event, LogModule.AI_CONFIG, fields);
    }
  }

  /** 快照摘要：数量级信息，不含密钥明文 */
  static snapshotSummary(snap: AIConfigSnapshot): string {
    return `accountId=${snap.accountId} seedVersion=${snap.seedVersion ?? 0} ` +
      `sync=${snap.syncState} providers=${snap.providers.length} models=${snap.models.length} ` +
      `bindings=${snap.scenarioBindings.length} tasks=${snap.smallTasks.length} ` +
      `files=${snap.modelFiles.length} revision=${snap.revision ?? '-'}`;
  }

  /**
   * 对标 iOS「写链路」计数文案：厂商/模型/绑定/小任务/文件。
   * HarmonyOS 无独立 searchKeys / promptRepo 表，用 bindings + files 补齐排查维度。
   */
  static catalogWriteSummary(
    accountId: number,
    providers: number,
    models: number,
    bindings: number,
    tasks: number,
    files: number,
    extras?: string
  ): string {
    const base =
      `accountId=${accountId} 厂商行=${providers} 模型行=${models} ` +
      `绑定行=${bindings} 小任务行=${tasks} 文件行=${files}`;
    return extras && extras.length > 0 ? `${base} ${extras}` : base;
  }

  /** 对标 iOS loadSnapshot 读链路完成计数 */
  static catalogReadSummary(
    accountId: number,
    providers: number,
    models: number,
    bindings: number,
    tasks: number,
    files: number,
    extras?: string
  ): string {
    const base =
      `accountId=${accountId} 读到 厂商=${providers} 模型=${models} ` +
      `绑定=${bindings} 小任务=${tasks} 文件=${files}`;
    return extras && extras.length > 0 ? `${base} ${extras}` : base;
  }

  /** 厂商列表摘要：含 id/source，避免同公司 Pro+seed 被误判为重复插入 */
  static providersBrief(providers: LocalProvider[], limit: number = 12): string {
    const names: string[] = [];
    const n = Math.min(providers.length, limit);
    for (let i = 0; i < n; i++) {
      const p = providers[i];
      const src = AIConfigFlowLog.providerSourceLabel(p);
      names.push(`${p.id}|${src}|${p.isEnabled ? 'on' : 'off'}`);
    }
    const more = providers.length > limit ? `...+${providers.length - limit}` : '';
    return `[${names.join(',')}]${more}`;
  }

  /** Pro / 本地种子 / 自定义 / 本地模型 / 其它 */
  static providerSourceLabel(p: LocalProvider): string {
    if (p.kind === 'local' || isLocalProviderId(p.id) || isLocalCompany(p.company)) {
      return '本地模型';
    }
    if (p.id.indexOf('pro:') === 0 || p.source === 'pro') {
      return 'Pro';
    }
    if (p.source === 'trial') {
      return '试用';
    }
    if (p.id.indexOf('seed:') === 0 || p.source === 'localSeed' || p.source === 'system') {
      return '本地种子';
    }
    if (p.id.indexOf('custom:') === 0 || p.source === 'custom' || p.source === 'localUser') {
      return '自定义';
    }
    return p.source.length > 0 ? p.source : 'local';
  }

  /** 模型列表摘要 */
  static modelsBrief(models: LocalModel[], limit: number = 16): string {
    const names: string[] = [];
    const n = Math.min(models.length, limit);
    for (let i = 0; i < n; i++) {
      const m = models[i];
      names.push(`${m.displayName || m.name}@${m.providerId}`);
    }
    const more = models.length > limit ? `...+${models.length - limit}` : '';
    return `[${names.join(',')}]${more}`;
  }

  /** 小任务 code 列表摘要 */
  static tasksBrief(codes: string[], limit: number = 12): string {
    const n = Math.min(codes.length, limit);
    const names: string[] = [];
    for (let i = 0; i < n; i++) {
      names.push(codes[i]);
    }
    const more = codes.length > limit ? `...+${codes.length - limit}` : '';
    return `[${names.join(',')}]${more}`;
  }

  static runtimeSummary(runtime: RuntimeSnapshot): string {
    return `accountId=${runtime.accountId} gen=${runtime.generation} state=${runtime.state} ` +
      `providers=${runtime.providers.size} scenarios=${runtime.scenarios.size} ` +
      `defaults=${runtime.effectiveDefaults.size} remoteRev=${runtime.remoteRevision ?? '-'}`;
  }
}
