import { SupportNetworkError } from '../Projects/Core/Networking/SupportNetworkModels';
import { Logger } from '../Foundation/Logging/Logger';
import { LogModule } from '../Foundation/Logging/LogModule';
import { ErrorLogger } from '../Foundation/Logging/ErrorLogger';
import { AIConfigRepository, AISeedLoadError } from '../Core/AI/Application/AIConfigRepository';
import { AISeedValidationError } from '../Core/AI/Infrastructure/AIConfigSeedLoader';
import { AIConfigFlowLog } from '../Core/AI/Infrastructure/AIConfigFlowLog';
import { OSSRuntimeConfigStore } from '../Projects/Core/OSS/OSSRuntimeConfigStore';
import { FileTransferService } from '../Core/FileStorage/FileTransferService';
import { publishAiRuntimeReady } from './AppStartupKeys';

export class BootstrapOutcome {
  /** true：可继续标记 prepared（含 localReady / degraded） */
  ok: boolean = true;
  authInvalidated: boolean = false;
  state: string = 'localReady';
}

/** 便于单测注入的账号 AI 准备网关。 */
export abstract class AIAccountBootstrapGateway {
  abstract prepareAccount(accountId: number): Promise<BootstrapOutcome>;
}

export class AIConfigRepositoryBootstrapGateway extends AIAccountBootstrapGateway {
  private readonly repository: AIConfigRepository;

  constructor(repository: AIConfigRepository) {
    super();
    this.repository = repository;
  }

  async prepareAccount(accountId: number): Promise<BootstrapOutcome> {
    const outcome = new BootstrapOutcome();
    // ① 首次登录：rawfile JSON → RDB；非首次跳过
    AIConfigFlowLog.info('ai.bootstrap.prepare.begin', `账号 AI 准备开始 accountId=${accountId}`);
    await this.repository.ensureSeeded(accountId);
    // ② RDB → Runtime 内存缓存
    await this.repository.buildRuntime(accountId);
    outcome.state = 'localReady';
    try {
      // ③ 后台拉 Pro（失败可 degraded）
      const refresh = await this.repository.refreshRemote(accountId, '1.0.0');
      outcome.state = refresh.state;
      if (refresh.state === 'invalidated') {
        outcome.ok = false;
        outcome.authInvalidated = true;
      }
      AIConfigFlowLog.info(
        'ai.bootstrap.prepare.ok',
        `账号 AI 准备完成 accountId=${accountId} state=${outcome.state}`
      );
    } catch (err) {
      if (AIConfigRepositoryBootstrapGateway.isAuthInvalidation(err as Object)) {
        outcome.ok = false;
        outcome.authInvalidated = true;
        outcome.state = 'invalidated';
        AIConfigFlowLog.warn('ai.bootstrap.prepare.auth', `鉴权失效 accountId=${accountId}`);
        return outcome;
      }
      // 网络失败：保留本地 Runtime，标记 degraded 仍可放行
      outcome.state = 'degraded';
      AIConfigFlowLog.warn(
        'ai.bootstrap.prepare.degraded',
        `Pro 刷新失败已降级，本地配置可用 accountId=${accountId} err=${err}`
      );
    }
    return outcome;
  }

  private static isAuthInvalidation(err: Object): boolean {
    if (err instanceof SupportNetworkError) {
      if (err.statusCode === 401) {
        return true;
      }
      if (err.backend && err.backend.code >= 40100 && err.backend.code <= 40199) {
        return true;
      }
    }
    return false;
  }
}

/**
 * 账号级 bootstrap：local-first → 后台 refresh → degraded 可放行；401 中止。
 * seed / buildRuntime 失败不标记 prepared，不发布 aiRuntimeReady。
 * STS 预热失败不阻塞主 Tab。
 */
export class AppBootstrapper {
  private readonly gateway: AIAccountBootstrapGateway;
  private readonly ossStore?: OSSRuntimeConfigStore;
  private readonly fileTransfer?: FileTransferService;
  private bootstrappedAccountIds: number[] = [];

  constructor(
    gateway: AIAccountBootstrapGateway,
    ossStore?: OSSRuntimeConfigStore,
    fileTransfer?: FileTransferService
  ) {
    this.gateway = gateway;
    this.ossStore = ossStore;
    this.fileTransfer = fileTransfer;
  }

  reset(): void {
    this.bootstrappedAccountIds = [];
    publishAiRuntimeReady(false, -1);
  }

  hasBootstrapped(accountId: number): boolean {
    return this.bootstrappedAccountIds.indexOf(accountId) >= 0;
  }

  /**
   * @returns true 表示可继续标记 prepared；false 表示鉴权失效应中止。
   * seed 失败抛错，由调用方 rollback preparing（不触发鉴权失效）。
   */
  async bootstrapAccountIfNeeded(accountId: number): Promise<boolean> {
    if (this.hasBootstrapped(accountId)) {
      AIConfigFlowLog.info('ai.bootstrap.skip', `账号已完成 bootstrap，跳过 accountId=${accountId}`);
      return true;
    }

    try {
      const outcome = await this.gateway.prepareAccount(accountId);
      if (outcome.authInvalidated || !outcome.ok) {
        ErrorLogger.log('bootstrap.ai_auth_invalidated', LogModule.LIFECYCLE, new Error(outcome.state));
        publishAiRuntimeReady(false, accountId);
        return false;
      }
      AIConfigFlowLog.info('ai.bootstrap.ok', `bootstrap 成功 accountId=${accountId} state=${outcome.state}`);
    } catch (err) {
      if (err instanceof SupportNetworkError) {
        if (err.statusCode === 401 ||
          (err.backend && err.backend.code >= 40100 && err.backend.code <= 40199)) {
          ErrorLogger.log('bootstrap.ai_auth_invalidated', LogModule.LIFECYCLE, err as Object);
          publishAiRuntimeReady(false, accountId);
          return false;
        }
      }
      if (err instanceof AISeedLoadError) {
        ErrorLogger.log('bootstrap.ai_seed_failed', LogModule.LIFECYCLE, err as Object);
        publishAiRuntimeReady(false, accountId);
        throw new AISeedLoadError(err.code, err.message);
      }
      if (err instanceof AISeedValidationError) {
        ErrorLogger.log('bootstrap.ai_seed_failed', LogModule.LIFECYCLE, err as Object);
        publishAiRuntimeReady(false, accountId);
        throw new AISeedValidationError(err.code, err.detail);
      }
      ErrorLogger.log('bootstrap.ai_prepare_failed', LogModule.LIFECYCLE, err as Object);
      publishAiRuntimeReady(false, accountId);
      throw new Error(`bootstrap.ai_prepare_failed:${err}`);
    }

    if (this.ossStore) {
      this.ossStore.setAccountScope(accountId);
      await this.ossStore.prefetch();
    } else {
      Logger.info('bootstrap.oss_skipped', LogModule.LIFECYCLE);
    }

    if (this.fileTransfer) {
      // 恢复未登记 / 清理 .part / 重试 pending_delete；失败不阻塞主 Tab
      this.fileTransfer.recoverAfterSignedIn(accountId).catch((err: Object) => {
        ErrorLogger.log('bootstrap.file_recover_failed', LogModule.LIFECYCLE, err);
      });
    }

    this.bootstrappedAccountIds.push(accountId);
    AIConfigFlowLog.info('ai.bootstrap.complete', `账号 bootstrap 标记完成 accountId=${accountId}`);
    return true;
  }
}
