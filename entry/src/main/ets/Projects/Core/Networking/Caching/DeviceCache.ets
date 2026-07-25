import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { NetworkLogger } from '../../../../Foundation/Logging/NetworkLogger';
import { DeviceRegistrationSubmittedSnapshot } from '../../Device/Application/DeviceRegistrationSubmittedSnapshot';

const LAST_REGISTRATION_SNAPSHOT_KEY: string = 'last_device_registration_snapshot';

/**
 * 非敏感设备/账号元数据；不得存 Token/STS/API Key。
 */
export class DeviceCache {
  private pref?: preferences.Preferences;
  private readonly logger: NetworkLogger;
  private memory: Map<string, string> = new Map();
  private accountScope: string = 'anonymous';
  private readonly useMemoryOnly: boolean;

  constructor(context?: common.Context, logger?: NetworkLogger) {
    this.logger = logger ?? new NetworkLogger();
    this.useMemoryOnly = !context;
    if (context) {
      preferences.getPreferences(context, 'support_device_cache')
        .then((p) => {
          this.pref = p;
        })
        .catch((e: Error) => {
          this.logger.warn(`DeviceCache preferences init failed: ${e}`);
        });
    }
  }

  static memoryOnly(logger?: NetworkLogger): DeviceCache {
    return new DeviceCache(undefined, logger);
  }

  setAccountScope(scope: string): void {
    this.accountScope = scope && scope.length > 0 ? scope : 'anonymous';
  }

  getAccountScope(): string {
    return this.accountScope;
  }

  async putString(key: string, value: string): Promise<void> {
    const scoped = this.scopedKey(key);
    this.memory.set(scoped, value);
    if (this.useMemoryOnly || !this.pref) {
      return;
    }
    await this.pref.put(scoped, value);
    await this.pref.flush();
  }

  async getString(key: string): Promise<string | undefined> {
    const scoped = this.scopedKey(key);
    if (this.memory.has(scoped)) {
      return this.memory.get(scoped);
    }
    if (this.useMemoryOnly || !this.pref) {
      return undefined;
    }
    const value = await this.pref.get(scoped, '');
    if (typeof value === 'string' && value.length > 0) {
      this.memory.set(scoped, value);
      return value;
    }
    return undefined;
  }

  async clearAccountScope(scope?: string): Promise<void> {
    const target = scope ?? this.accountScope;
    const prefix = `${target}::`;
    const keys: string[] = [];
    this.memory.forEach((_v: string, k: string) => {
      keys.push(k);
    });
    for (let i = 0; i < keys.length; i++) {
      if (keys[i].startsWith(prefix)) {
        this.memory.delete(keys[i]);
      }
    }
  }

  async clearAllNonSensitive(): Promise<void> {
    this.memory.clear();
    if (this.pref) {
      await this.pref.clear();
      await this.pref.flush();
    }
  }

  async getLastDeviceRegistrationSnapshot(): Promise<DeviceRegistrationSubmittedSnapshot | undefined> {
    const text = await this.getString(LAST_REGISTRATION_SNAPSHOT_KEY);
    if (!text) {
      return undefined;
    }
    return DeviceRegistrationSubmittedSnapshot.fromJson(text);
  }

  async setLastDeviceRegistrationSnapshot(snapshot: DeviceRegistrationSubmittedSnapshot): Promise<void> {
    await this.putString(LAST_REGISTRATION_SNAPSHOT_KEY, snapshot.toJson());
  }

  private scopedKey(key: string): string {
    return `${this.accountScope}::${key}`;
  }
}
