import { asset } from '@kit.AssetStoreKit';
import { util } from '@kit.ArkTS';
import { BusinessError } from '@kit.BasicServicesKit';
import { Logger } from '../Logging/Logger';
import { LogModule } from '../Logging/LogModule';
import { LogFields } from '../Logging/LogEvent';
import { SecureRandom } from './SecureRandom';

/**
 * 安装级设备 ID / 设备登录密钥：对标 iOS SparkKeychain。
 *
 * Asset Store alias：
 * - `device_unique_id`：安装标识（升级 / 卸载重装后尽量连续，依赖 IS_PERSISTENT）
 * - `device_login_secret`：设备登录高熵密钥（决策 1A）
 */
export class SparkAssetStore {
  private static readonly DEVICE_ID_ALIAS = 'device_unique_id';
  private static readonly DEVICE_SECRET_ALIAS = 'device_login_secret';
  /** Asset NOT_FOUND */
  private static readonly ERR_NOT_FOUND = 24000002;

  private static stringToUint8Array(str: string): Uint8Array {
    return new util.TextEncoder().encodeInto(str);
  }

  private static uint8ArrayToString(arr: Uint8Array): string {
    return new util.TextDecoder().decodeToString(arr);
  }

  /// 对应 iOS：getOrCreateDeviceID()
  /// 获取或创建卸载后尽量保留的 DeviceID；保存失败时允许降级为内存 UUID
  static async getOrCreateDeviceID(): Promise<string> {
    const existingId = await SparkAssetStore.load(SparkAssetStore.DEVICE_ID_ALIAS);
    if (existingId) {
      return existingId;
    }

    const newID = util.generateRandomUUID(true);
    try {
      await SparkAssetStore.save(newID, SparkAssetStore.DEVICE_ID_ALIAS);
      return newID;
    } catch (error) {
      const err = error as BusinessError;
      const fields = new LogFields();
      fields.detail = `code=${err.code}, msg=${err.message}`;
      Logger.warn('asset.save_device_id_failed', LogModule.GENERAL, fields);
      return newID;
    }
  }

  /// 对应 iOS：getOrCreatePersistentDeviceID()
  /// 认证场景必须使用可持久化的安装标识，禁止降级
  static async getOrCreatePersistentDeviceID(): Promise<string> {
    const existingId = await SparkAssetStore.load(SparkAssetStore.DEVICE_ID_ALIAS);
    if (existingId) {
      return existingId;
    }

    const newID = util.generateRandomUUID(true);
    try {
      await SparkAssetStore.save(newID, SparkAssetStore.DEVICE_ID_ALIAS);
      return newID;
    } catch (error) {
      const err = error as BusinessError;
      throw new Error(`DeviceCredentialUnavailable: code=${err.code}`);
    }
  }

  /// 对应 iOS：getOrCreateDeviceSecret()
  /// 保存失败不得返回仅存在于内存的临时 secret
  static async getOrCreateDeviceSecret(): Promise<string> {
    const existing = await SparkAssetStore.load(SparkAssetStore.DEVICE_SECRET_ALIAS);
    if (existing) {
      return existing;
    }

    const secret = SecureRandom.hex(32);
    try {
      await SparkAssetStore.save(secret, SparkAssetStore.DEVICE_SECRET_ALIAS);
      const fields = new LogFields();
      fields.detail = 'device_login_secret persisted (plaintext omitted)';
      Logger.info('asset.device_secret_created', LogModule.AUTH, fields);
      return secret;
    } catch (error) {
      const err = error as BusinessError;
      const fields = new LogFields();
      fields.detail = `code=${err.code}, msg=${err.message}`;
      Logger.error('asset.save_device_secret_failed', LogModule.AUTH, fields);
      throw new Error(`DeviceCredentialUnavailable: code=${err.code}`);
    }
  }

  static async loadDeviceID(): Promise<string | null> {
    return SparkAssetStore.load(SparkAssetStore.DEVICE_ID_ALIAS);
  }

  static async loadDeviceSecret(): Promise<string | null> {
    return SparkAssetStore.load(SparkAssetStore.DEVICE_SECRET_ALIAS);
  }

  static async replaceDeviceID(deviceId: string): Promise<void> {
    const trimmed = deviceId.trim();
    if (trimmed.length === 0) {
      throw new Error('DeviceCredentialUnavailable: empty deviceId');
    }
    await SparkAssetStore.save(trimmed, SparkAssetStore.DEVICE_ID_ALIAS);
  }

  static async replaceDeviceSecret(secret: string): Promise<void> {
    const trimmed = secret.trim();
    if (trimmed.length === 0) {
      throw new Error('DeviceCredentialUnavailable: empty deviceSecret');
    }
    await SparkAssetStore.save(trimmed, SparkAssetStore.DEVICE_SECRET_ALIAS);
  }

  static async deleteDeviceSecret(): Promise<void> {
    await SparkAssetStore.delete(SparkAssetStore.DEVICE_SECRET_ALIAS);
  }

  /** 仅测试：清空设备 ID 与 secret */
  static async clearAllForTests(): Promise<void> {
    await SparkAssetStore.delete(SparkAssetStore.DEVICE_ID_ALIAS);
    await SparkAssetStore.delete(SparkAssetStore.DEVICE_SECRET_ALIAS);
  }

  /// 底层实现：安全保存到系统资产存储区
  private static async save(value: string, accountAlias: string): Promise<void> {
    const addMap: asset.AssetMap = new Map();
    addMap.set(asset.Tag.ALIAS, SparkAssetStore.stringToUint8Array(accountAlias));
    addMap.set(asset.Tag.SECRET, SparkAssetStore.stringToUint8Array(value));
    // 应用卸载后保留（对标 iOS Keychain 默认卸载保留；需 ohos.permission.STORE_PERSISTENT_DATA）
    addMap.set(asset.Tag.IS_PERSISTENT, true);
    // 首次解锁设备后可访问（对标 kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly）
    addMap.set(asset.Tag.ACCESSIBILITY, asset.Accessibility.DEVICE_FIRST_UNLOCKED);

    // Asset API 不能直接覆盖，已存在时需先删除（对标 SecItemDelete）
    await SparkAssetStore.delete(accountAlias);
    await asset.add(addMap);
  }

  /// 底层实现：从系统资产存储区读取
  private static async load(accountAlias: string): Promise<string | null> {
    const queryMap: asset.AssetMap = new Map();
    queryMap.set(asset.Tag.ALIAS, SparkAssetStore.stringToUint8Array(accountAlias));
    queryMap.set(asset.Tag.RETURN_TYPE, asset.ReturnType.ALL);

    try {
      const res: Array<asset.AssetMap> = await asset.query(queryMap);
      if (res && res.length > 0) {
        const secretArr = res[0].get(asset.Tag.SECRET) as Uint8Array;
        if (secretArr && secretArr.length > 0) {
          return SparkAssetStore.uint8ArrayToString(secretArr);
        }
      }
    } catch (error) {
      const err = error as BusinessError;
      if (err.code !== SparkAssetStore.ERR_NOT_FOUND) {
        const fields = new LogFields();
        fields.detail = `alias=${accountAlias}, code=${err.code}`;
        Logger.error('asset.load_failed', LogModule.GENERAL, fields);
      }
    }
    return null;
  }

  private static async delete(accountAlias: string): Promise<void> {
    const removeMap: asset.AssetMap = new Map();
    removeMap.set(asset.Tag.ALIAS, SparkAssetStore.stringToUint8Array(accountAlias));
    try {
      await asset.remove(removeMap);
    } catch (_e) {
      // 忽略找不到等异常
    }
  }
}
