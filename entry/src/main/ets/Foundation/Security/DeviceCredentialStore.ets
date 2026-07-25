import { NetworkLogger } from '../Logging/NetworkLogger';
import { SparkAssetStore } from './SparkAssetStore';

export const AUTH_BUNDLE_ID: string = 'cn.Zhaodk.Health';

export class DeviceCredential {
  deviceId: string;
  deviceSecret: string;
  bundleId: string;

  constructor(deviceId: string, deviceSecret: string, bundleId: string = AUTH_BUNDLE_ID) {
    this.deviceId = deviceId;
    this.deviceSecret = deviceSecret;
    this.bundleId = bundleId;
  }
}

/**
 * 可注入凭证提供者（单测 / 真实 DeviceCredentialStore）。
 */
export abstract class DeviceCredentialProvider {
  abstract getOrCreate(): Promise<DeviceCredential>;

  /**
   * iOS 对齐：匿名设备登记与手机号 OTP 只需要安装级 device_id，
   * 不应为了这两个流程提前生成尚未向服务端登记的 device_secret。
   */
  abstract getOrCreateDeviceIdentity(): Promise<DeviceCredential>;
}

/**
 * 安装级设备凭证：deviceId + deviceSecret 存 Asset Store（对标 iOS SparkKeychain）。
 * logout 不清；secret 持久化失败必须阻断游客登录。
 */
export class DeviceCredentialStore extends DeviceCredentialProvider {
  private readonly logger: NetworkLogger;
  private cached?: DeviceCredential;

  /**
   * @param _filesDir 保留构造签名以兼容 AppContainer / 单测；持久化已迁至 Asset Store，不再依赖沙箱文件。
   */
  constructor(_filesDir: string, logger?: NetworkLogger) {
    super();
    this.logger = logger ?? new NetworkLogger();
  }

  async getOrCreate(): Promise<DeviceCredential> {
    if (this.cached) {
      return this.cached;
    }
    try {
      const deviceId = await SparkAssetStore.getOrCreatePersistentDeviceID();
      const deviceSecret = await SparkAssetStore.getOrCreateDeviceSecret();
      const generated = new DeviceCredential(deviceId, deviceSecret, AUTH_BUNDLE_ID);
      this.cached = generated;
      return generated;
    } catch (e) {
      const reason: string = e instanceof Error ? e.message : String(e);
      this.logger.warn(`DeviceCredentialStore getOrCreate failed: ${reason}`);
      throw new Error(`DeviceCredentialStore: getOrCreate failed: ${reason}`);
    }
  }

  async getOrCreateDeviceIdentity(): Promise<DeviceCredential> {
    if (this.cached) {
      return new DeviceCredential(this.cached.deviceId, '', this.cached.bundleId);
    }
    try {
      const deviceId = await SparkAssetStore.getOrCreatePersistentDeviceID();
      return new DeviceCredential(deviceId, '', AUTH_BUNDLE_ID);
    } catch (e) {
      const reason: string = e instanceof Error ? e.message : String(e);
      this.logger.warn(`DeviceCredentialStore getOrCreateDeviceIdentity failed: ${reason}`);
      throw new Error(`DeviceCredentialStore: getOrCreateDeviceIdentity failed: ${reason}`);
    }
  }

  async save(credential: DeviceCredential): Promise<void> {
    if (!credential.deviceId || !credential.deviceSecret) {
      throw new Error('DeviceCredentialStore: missing deviceId or deviceSecret');
    }
    try {
      await SparkAssetStore.replaceDeviceID(credential.deviceId);
      await SparkAssetStore.replaceDeviceSecret(credential.deviceSecret);
      this.cached = new DeviceCredential(
        credential.deviceId,
        credential.deviceSecret,
        credential.bundleId || AUTH_BUNDLE_ID
      );
    } catch (e) {
      this.logger.warn(`DeviceCredentialStore save failed: ${e}`);
      throw new Error('DeviceCredentialStore: persist failed');
    }
  }

  async load(): Promise<DeviceCredential | undefined> {
    try {
      const deviceId = await SparkAssetStore.loadDeviceID();
      const deviceSecret = await SparkAssetStore.loadDeviceSecret();
      if (!deviceId || !deviceSecret) {
        return undefined;
      }
      return new DeviceCredential(deviceId, deviceSecret, AUTH_BUNDLE_ID);
    } catch (e) {
      this.logger.warn(`DeviceCredentialStore load failed: ${e}`);
      return undefined;
    }
  }

  /** 仅测试：清空缓存与 Asset 条目 */
  async clearForTests(): Promise<void> {
    this.cached = undefined;
    await SparkAssetStore.clearAllForTests();
  }
}

/** 单测固定凭证 */
export class FixedDeviceCredentials extends DeviceCredentialProvider {
  private readonly credential: DeviceCredential;

  constructor(credential: DeviceCredential) {
    super();
    this.credential = credential;
  }

  async getOrCreate(): Promise<DeviceCredential> {
    return this.credential;
  }

  async getOrCreateDeviceIdentity(): Promise<DeviceCredential> {
    return this.credential;
  }
}
