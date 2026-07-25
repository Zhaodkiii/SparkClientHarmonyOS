import { SupportBackend } from '../Core/Networking/SupportBackend';
import { NetworkPathStatus } from '../Foundation/NetworkPathMonitor';
import { AppSessionStore } from './AppSessionStore';
import { AccountSessionRuntime } from './AccountSessionRuntime';
import { SignedInSessionPreparationRegistry } from './SignedInSessionPreparationRegistry';
import { DeviceRegistrationCoordinator } from './DeviceRegistrationCoordinator';
import { AppBootstrapper } from './AppBootstrapper';
import { DeviceRegistrationOutcomes, DeviceRegistrationReason } from './DeviceRegistrationRequestOutcome';
import { UserSession } from '../Projects/Core/Domain/Entities/UserSession';
import { publishNetworkGate } from './AppStartupKeys';
import { Logger } from '../Foundation/Logging/Logger';
import { LogModule } from '../Foundation/Logging/LogModule';
import { LogFields } from '../Foundation/Logging/LogEvent';
import { ErrorLogger } from '../Foundation/Logging/ErrorLogger';
import { SessionInvalidation } from '../Projects/Core/Networking/SessionInvalidation';
import { FileTransferService } from '../Core/FileStorage/FileTransferService';

/**
 * 启动链路唯一编排：网络门控、会话恢复、已登录准备、鉴权失效回收。
 */
export class AppLifecycleCoordinator {
  private readonly backend: SupportBackend;
  private readonly sessionStore: AppSessionStore;
  private readonly accountRuntime: AccountSessionRuntime;
  private readonly preparationRegistry: SignedInSessionPreparationRegistry;
  private readonly deviceRegistration: DeviceRegistrationCoordinator;
  private readonly bootstrapper: AppBootstrapper;
  private readonly fileTransfer?: FileTransferService;

  private didBootstrapLaunch: boolean = false;
  private started: boolean = false;
  private handlingAuthInvalidation: boolean = false;
  private networkListener?: (status: NetworkPathStatus, hasEvaluated: boolean) => void;

  constructor(
    backend: SupportBackend,
    sessionStore: AppSessionStore,
    accountRuntime: AccountSessionRuntime,
    preparationRegistry: SignedInSessionPreparationRegistry,
    deviceRegistration: DeviceRegistrationCoordinator,
    bootstrapper: AppBootstrapper,
    fileTransfer?: FileTransferService
  ) {
    this.backend = backend;
    this.sessionStore = sessionStore;
    this.accountRuntime = accountRuntime;
    this.preparationRegistry = preparationRegistry;
    this.deviceRegistration = deviceRegistration;
    this.bootstrapper = bootstrapper;
    this.fileTransfer = fileTransfer;
  }

  start(): void {
    if (this.started) {
      return;
    }
    this.started = true;
    this.networkListener = (status: NetworkPathStatus, hasEvaluated: boolean): void => {
      this.handleNetwork(status, hasEvaluated).catch((err: Object) => {
        ErrorLogger.log('startup.network_gate_failed', LogModule.LIFECYCLE, err);
      });
    };
    this.backend.networkPathMonitor.subscribe(this.networkListener);
    Logger.info('lifecycle.started', LogModule.LIFECYCLE);
  }

  stop(): void {
    if (!this.started) {
      return;
    }
    if (this.networkListener) {
      this.backend.networkPathMonitor.unsubscribe(this.networkListener);
      this.networkListener = undefined;
    }
    this.started = false;
  }

  /**
   * 本地主动登出：清准备/bootstrap/设备登记去重态。
   */
  onLocalSignOut(): void {
    this.preparationRegistry.reset();
    this.bootstrapper.reset();
    this.deviceRegistration.reset();
    this.accountRuntime.clearPublishedAccountIds();
  }

  /**
   * 前台轻量：不重复冷启动 restore；signedOut 补游客登记；signedIn 可触发前台登记（摘要未变则跳过）。
   */
  onForeground(): void {
    const monitor = this.backend.networkPathMonitor;
    if (!monitor.hasEvaluated || monitor.currentStatus !== 'satisfied') {
      return;
    }
    if (this.sessionStore.sessionState === 'signedOut') {
      this.deviceRegistration.registerGuestDevice('guestColdLaunch').catch((err: Object) => {
        ErrorLogger.log('startup.guest_register_foreground_failed', LogModule.LIFECYCLE, err);
      });
      return;
    }
    if (this.sessionStore.sessionState === 'signedIn') {
      const session = this.sessionStore.session;
      if (!session) {
        return;
      }
      this.deviceRegistration.requestRegisterWithLimitedRetry(session, 'signedInForeground').catch((err: Object) => {
        ErrorLogger.log('startup.signed_in_register_foreground_failed', LogModule.LIFECYCLE, err);
      });
      if (this.fileTransfer) {
        this.fileTransfer.onForegroundResume().catch((err: Object) => {
          ErrorLogger.log('startup.file_foreground_resume_failed', LogModule.LIFECYCLE, err);
        });
      }
    }
  }

  /**
   * 登录成功后由 SessionStore 回调。
   */
  onSessionEnteredSignedIn(session: UserSession): void {
    if (this.handlingAuthInvalidation) {
      return;
    }
    this.prepareSignedIn(session, 'signedInColdLaunch').catch((err: Object) => {
      ErrorLogger.log('startup.prepare_signed_in_failed', LogModule.LIFECYCLE, err);
    });
  }

  async handleServerAuthInvalidation(_source: string): Promise<void> {
    if (this.handlingAuthInvalidation) {
      SessionInvalidation.clearInvalidatingFlag();
      return;
    }
    this.handlingAuthInvalidation = true;
    try {
      this.deviceRegistration.suspendPendingSubmissions();
      this.preparationRegistry.reset();
      this.bootstrapper.reset();
      this.accountRuntime.clearPublishedAccountIds();
      const gen = this.sessionStore.generation;
      const applied = this.sessionStore.handleAuthInvalidated(gen);
      this.deviceRegistration.reset();
      SessionInvalidation.clearInvalidatingFlag();
      if (applied) {
        Logger.info('lifecycle.auth_invalidated', LogModule.LIFECYCLE);
      } else {
        Logger.debug('lifecycle.auth_invalidated_ignored', LogModule.LIFECYCLE);
      }
    } finally {
      this.handlingAuthInvalidation = false;
    }
  }

  private async handleNetwork(status: NetworkPathStatus, hasEvaluated: boolean): Promise<void> {
    if (!hasEvaluated) {
      publishNetworkGate('evaluating');
      return;
    }
    if (status !== 'satisfied') {
      publishNetworkGate('offline');
      return;
    }
    publishNetworkGate('none');
    if (this.didBootstrapLaunch) {
      return;
    }
    this.didBootstrapLaunch = true;
    Logger.info('lifecycle.cold_launch_restore', LogModule.LIFECYCLE);
    await this.sessionStore.restoreIfNeeded();
    await this.handleCurrentSessionState();
  }

  private async handleCurrentSessionState(): Promise<void> {
    const state = this.sessionStore.sessionState;
    if (state === 'signedOut') {
      this.preparationRegistry.reset();
      this.accountRuntime.clearPublishedAccountIds();
      this.deviceRegistration.registerGuestDevice('guestColdLaunch').catch((err: Object) => {
        ErrorLogger.log('startup.guest_register_failed', LogModule.LIFECYCLE, err);
      });
      return;
    }
    if (state === 'signedIn') {
      const session = this.sessionStore.session;
      if (session) {
        await this.prepareSignedIn(session, 'signedInColdLaunch');
      }
    }
  }

  private async prepareSignedIn(session: UserSession, reason: DeviceRegistrationReason): Promise<void> {
    await this.preparationRegistry.runIfNeeded(session.accountId, async () => {
      await this.runSignedInPreparation(session, reason);
    });
  }

  private async runSignedInPreparation(session: UserSession, reason: DeviceRegistrationReason): Promise<void> {
    if (this.handlingAuthInvalidation) {
      this.preparationRegistry.rollbackPreparingIfNeeded(session.accountId);
      return;
    }

    await this.accountRuntime.activateUser(session.accountId);

    const registrationOutcome = await this.deviceRegistration.requestRegisterWithLimitedRetry(session, reason);
    if (registrationOutcome === 'authSessionInvalidated') {
      this.preparationRegistry.rollbackPreparingIfNeeded(session.accountId);
      await this.handleServerAuthInvalidation('device.register');
      return;
    }
    if (!DeviceRegistrationOutcomes.allowsAccountBootstrap(registrationOutcome)) {
      Logger.warn('lifecycle.device_reg_blocked_bootstrap', LogModule.LIFECYCLE);
      this.preparationRegistry.rollbackPreparingIfNeeded(session.accountId);
      return;
    }

    if (this.sessionStore.sessionState !== 'signedIn' || this.handlingAuthInvalidation) {
      this.preparationRegistry.rollbackPreparingIfNeeded(session.accountId);
      return;
    }

    let bootstrapOk = false;
    try {
      bootstrapOk = await this.bootstrapper.bootstrapAccountIfNeeded(session.accountId);
    } catch (_e) {
      // seed / Runtime 失败：不标记 prepared，不触发鉴权失效，允许用户重试登录准备
      this.preparationRegistry.rollbackPreparingIfNeeded(session.accountId);
      Logger.warn('lifecycle.ai_bootstrap_seed_failed', LogModule.LIFECYCLE);
      return;
    }
    if (!bootstrapOk) {
      this.preparationRegistry.rollbackPreparingIfNeeded(session.accountId);
      await this.handleServerAuthInvalidation('bootstrap.ai');
      return;
    }

    if (this.sessionStore.sessionState !== 'signedIn' || this.handlingAuthInvalidation) {
      this.preparationRegistry.rollbackPreparingIfNeeded(session.accountId);
      return;
    }

    this.preparationRegistry.markPrepared(session.accountId);
    const fields = new LogFields();
    fields.detail = `账号准备完成 accountId=${session.accountId}`;
    Logger.info('lifecycle.prepared', LogModule.LIFECYCLE, fields);
  }
}
