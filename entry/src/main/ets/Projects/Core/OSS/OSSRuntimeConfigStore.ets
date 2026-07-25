import { OSSAPI } from '../Networking/API/OSS/OSSAPI';
import { OSSRuntimeConfig } from './OSSRuntimeConfig';
import { OSSSTSConfigValidator } from './OSSSTSConfigValidator';
import { Logger } from '../../../Foundation/Logging/Logger';
import { LogModule } from '../../../Foundation/Logging/LogModule';
import { LogFields } from '../../../Foundation/Logging/LogEvent';
import { ErrorLogger } from '../../../Foundation/Logging/ErrorLogger';
import { FileHashUtil } from '../../../Core/FileStorage/FileHashUtil';
import { FileTransferError, stsAgeBucketOf } from '../../../Core/FileStorage/FileStorageModels';

/**
 * STS 内存快照 + single-flight 刷新。到期前 300 秒主动续期。
 * 对齐 iOS SparkOSSConfigurationStore 生命周期；仅 HarmonyOS 实现（HOS-0005）。
 * 不落盘；切号 / 登出 / 401 必须 invalidate；冲突配置不得缓存。
 */
export class OSSRuntimeConfigStore {
  private snapshot?: OSSRuntimeConfig;
  private snapshotScope: string = '';
  private cachedConfigVersion: string = '';
  private refreshPromise?: Promise<OSSRuntimeConfig>;
  private readonly api: OSSAPI;
  private accountScope: string = 'anon';

  constructor(api: OSSAPI) {
    this.api = api;
  }

  setAccountScope(accountId: number | undefined): void {
    let next = 'anon';
    if (accountId !== undefined && accountId > 0) {
      next = `${accountId}`;
    }
    if (next !== this.accountScope) {
      this.invalidate();
      this.accountScope = next;
    }
  }

  /** 当前账号 scope（诊断用，非敏感）。 */
  currentAccountScope(): string {
    return this.accountScope;
  }

  invalidate(): void {
    this.snapshot = undefined;
    this.snapshotScope = '';
    this.cachedConfigVersion = '';
    this.refreshPromise = undefined;
  }

  /** 当前内存快照；未刷新或已 invalidate 时为空。不触发网络。 */
  peek(): OSSRuntimeConfig | undefined {
    return this.snapshot;
  }

  /** 登录后尽力预热，失败不阻塞主 Tab。 */
  async prefetch(): Promise<void> {
    try {
      await this.getForUpload();
      Logger.info('oss.sts.prefetch_ok', LogModule.OSS);
    } catch (err) {
      ErrorLogger.log('oss.sts.prefetch_failed', LogModule.OSS, err as Object);
    }
  }

  async getForUpload(): Promise<OSSRuntimeConfig> {
    if (this.snapshot &&
      this.snapshotScope === this.accountScope &&
      this.snapshot.isFresh(300)) {
      const cachedCheck = OSSSTSConfigValidator.validate(this.snapshot);
      if (cachedCheck.ok) {
        return this.snapshot;
      }
      // 缓存已失效或契约冲突：丢弃，不得继续使用。
      this.invalidate();
    }
    if (this.refreshPromise) {
      return this.refreshPromise;
    }
    this.refreshPromise = this.refreshInternal();
    try {
      return await this.refreshPromise;
    } finally {
      this.refreshPromise = undefined;
    }
  }

  private async refreshInternal(): Promise<OSSRuntimeConfig> {
    const startedAt = Date.now();
    const accountHash = this.accountScope === 'anon'
      ? 'anon'
      : FileHashUtil.sha256HexOfString(`account:${this.accountScope}`).substring(0, 16);
    const requested = new LogFields();
    requested.operation = 'oss.sts.credentials';
    requested.accountHash = accountHash;
    requested.detail = `environmentAlias=client;scope=${this.accountScope === 'anon' ? 'anon' : 'authed'}`;
    Logger.info('oss.sts.requested', LogModule.OSS, requested);

    try {
      const cfg = await this.api.credentials(this.accountScope);
      // API 层已做契约校验；此处再检一次，冲突绝不入库。
      const check = OSSSTSConfigValidator.validate(cfg);
      if (!check.ok) {
        const err = OSSSTSConfigValidator.toError(
          check.reason.length > 0 ? check.reason : 'regionEndpointMismatch'
        );
        const fail = new LogFields();
        fail.operation = 'oss.sts.credentials';
        fail.elapsedMs = Date.now() - startedAt;
        fail.accountHash = accountHash;
        fail.code = err.code;
        fail.detail = OSSSTSConfigValidator.safeLogDetail(cfg, check.init, check.reason);
        ErrorLogger.log('oss.sts.failed', LogModule.OSS, err, undefined, fail);
        throw err;
      }

      // 同 configVersion 且仍 fresh 时避免无意义覆盖（仍更新 snapshot 保持一致）。
      this.snapshot = cfg;
      this.snapshotScope = this.accountScope;
      this.cachedConfigVersion = cfg.configVersion;
      const fields = new LogFields();
      fields.operation = 'oss.sts.credentials';
      fields.elapsedMs = Date.now() - startedAt;
      fields.accountHash = accountHash;
      fields.detail =
        `stsAgeBucket=${stsAgeBucketOf(cfg.expirationEpochSeconds, false)};` +
        `roleMode=${cfg.roleMode()};` +
        OSSSTSConfigValidator.safeLogDetail(cfg, check.init) +
        `;regionEndpointConsistent=true`;
      Logger.info('oss.sts.succeeded', LogModule.OSS, fields);
      return cfg;
    } catch (err) {
      if (!(err instanceof FileTransferError)) {
        // API 已映射；兜底。
      }
      const fail = new LogFields();
      fail.operation = 'oss.sts.credentials';
      fail.elapsedMs = Date.now() - startedAt;
      fail.accountHash = accountHash;
      if (err instanceof FileTransferError) {
        fail.code = err.code;
        if (err.requestId) {
          fail.requestId = err.requestId;
        }
        fail.detail =
          `reason=${err.requestValidationReason ?? err.code};` +
          `stage=${err.stage}`;
        if (err.code === 'unauthorized') {
          this.invalidate();
        }
        // 配置冲突 / 网络失败：不保留过期 snapshot（invalidate 已在切号时处理；
        // 刷新失败时若旧 snapshot 已过期也不应返回——本路径不回退旧值）。
        ErrorLogger.log('oss.sts.failed', LogModule.OSS, err, undefined, fail);
        throw err;
      }
      ErrorLogger.log('oss.sts.failed', LogModule.OSS, err as Object, undefined, fail);
      throw OSSSTSConfigValidator.toError('unknown');
    }
  }
}
