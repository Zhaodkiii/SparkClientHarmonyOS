import { UserSession } from '../../../Core/Domain/Entities/UserSession';
import {
  AuthAPI,
  DeviceLoginRequest,
  CurrentSessionResult
} from '../../../Core/Networking/API/Auth/AuthAPI';
import {
  OTPAPI,
  PhoneOTPRequest,
  PhoneOTPVerifyRequest,
  OTPRequestResponse
} from '../../../Core/Networking/API/Auth/OTPAPI';
import { AuthTokenProvider, AuthTokenProviderError } from '../../../Core/Networking/AuthTokenProvider';
import { SupportNetworkError } from '../../../Core/Networking/SupportNetworkModels';
import { DeviceCredentialStore } from '../../../../Foundation/Security/DeviceCredentialStore';
import { SessionSnapshotStore } from './SessionSnapshotStore';
import { AuthRepository } from '../Domain/AuthRepository';
import { AccountSessionRuntime } from '../../../../App/AccountSessionRuntime';
import { NetworkLogger } from '../../../../Foundation/Logging/NetworkLogger';

/**
 * 复用 AuthAPI/OTPAPI；负责写快照与本地清理，不重写 path。
 */
export class DefaultAuthRepository extends AuthRepository {
  private readonly auth: AuthAPI;
  private readonly otp: OTPAPI;
  private readonly tokenProvider: AuthTokenProvider;
  private readonly credentials: DeviceCredentialStore;
  private readonly snapshotStore: SessionSnapshotStore;
  private readonly runtime: AccountSessionRuntime;
  private readonly logger: NetworkLogger;

  constructor(
    auth: AuthAPI,
    otp: OTPAPI,
    tokenProvider: AuthTokenProvider,
    credentials: DeviceCredentialStore,
    snapshotStore: SessionSnapshotStore,
    runtime: AccountSessionRuntime,
    logger?: NetworkLogger
  ) {
    super();
    this.auth = auth;
    this.otp = otp;
    this.tokenProvider = tokenProvider;
    this.credentials = credentials;
    this.snapshotStore = snapshotStore;
    this.runtime = runtime;
    this.logger = logger ?? new NetworkLogger();
  }

  async signInWithDevice(): Promise<UserSession> {
    const cred = await this.credentials.getOrCreate();
    const ctx = await this.auth.deviceLogin(
      new DeviceLoginRequest(cred.bundleId, cred.deviceId, cred.deviceSecret)
    );
    const session = UserSession.fromAuthContext(ctx);
    await this.snapshotStore.save(session);
    await this.runtime.onSignedIn(session);
    return session;
  }

  async requestPhoneOTP(phoneNumber: string, scene: string = 'login'): Promise<OTPRequestResponse> {
    const cred = await this.credentials.getOrCreateDeviceIdentity();
    return this.otp.requestPhoneOTP(
      new PhoneOTPRequest(phoneNumber, cred.bundleId, cred.deviceId, scene)
    );
  }

  async signInWithPhoneOTP(otpId: string, phoneNumber: string, code: string): Promise<UserSession> {
    // 与 iOS SparkKeychain.loadDeviceSecret() ?? "" 对齐：
    // 新安装尚未完成设备登录时，不发送新生成的 device_secret。
    // 发送未登记的 secret 会让后端按 40162 device_credential_not_registered 拒绝 OTP。
    const identity = await this.credentials.getOrCreateDeviceIdentity();
    const stored = await this.credentials.load();
    // 只有本地仍有设备登录会话时，才把 secret 作为“已登记凭据”复用；
    // 兼容旧版鸿蒙曾在匿名启动时生成、但从未注册到服务端的孤儿 secret。
    const hasDeviceSession = await this.tokenProvider.hasRefreshToken();
    const deviceSecret = hasDeviceSession && stored?.deviceId === identity.deviceId
      ? stored.deviceSecret
      : '';
    const result = await this.otp.verifyPhoneOTP(
      new PhoneOTPVerifyRequest(otpId, phoneNumber, code, identity.bundleId, identity.deviceId, deviceSecret)
    );
    const session = UserSession.fromPhoneOTP(result);
    await this.snapshotStore.save(session);
    await this.runtime.onSignedIn(session);
    return session;
  }

  async restoreSession(): Promise<UserSession | undefined> {
    const local = await this.snapshotStore.load();
    await this.tokenProvider.restoreIfNeeded();
    const hasRefresh = await this.tokenProvider.hasRefreshToken();
    if (!hasRefresh) {
      await this.snapshotStore.clear();
      return undefined;
    }
    try {
      // 预热/刷新 access；临时失败保留快照
      await this.tokenProvider.authorizationHeaderValue();
      const remote: CurrentSessionResult = await this.auth.currentSession();
      const merged = UserSession.fromCurrentSession(remote, local);
      await this.snapshotStore.save(merged);
      return merged;
    } catch (e) {
      if (e instanceof AuthTokenProviderError) {
        if (e.kind === 'refreshTemporarilyUnavailable') {
          this.logger.warn('restoreSession: temporary refresh failure; keeping snapshot');
          return local;
        }
        if (e.kind === 'missingTokens' || e.kind === 'refreshFailed') {
          await this.clearLocalSession();
          return undefined;
        }
      }
      if (e instanceof SupportNetworkError) {
        if (e.statusCode === 401 || (e.backend && e.backend.code >= 40100 && e.backend.code <= 40199)) {
          await this.clearLocalSession();
          return undefined;
        }
        // 其他网络错误：有快照则保留已登录态
        if (local) {
          this.logger.warn(`restoreSession: network error keeping snapshot status=${e.statusCode}`);
          return local;
        }
      }
      if (local) {
        return local;
      }
      return undefined;
    }
  }

  async signOut(): Promise<void> {
    try {
      await this.auth.logout();
    } catch (_e) {
      // 服务端失败仍清本地
      await this.tokenProvider.clearTokens();
    }
    await this.snapshotStore.clear();
    await this.runtime.onSignedOut();
  }

  async clearLocalSession(): Promise<void> {
    await this.tokenProvider.clearTokens();
    await this.snapshotStore.clear();
    await this.runtime.onSignedOut();
  }
}
