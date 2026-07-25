/**
 * 设备登记跨启动去重摘要（非敏感；不含 deviceSecret / Token）。
 */
export class DeviceRegistrationSubmittedSnapshot {
  accountID?: number;
  isAuthenticated: boolean = false;
  bundleID: string = '';
  deviceID: string = '';
  countryCode: string = '';
  regionCode: string = '';
  notificationsEnabled?: boolean;
  pushTokenHash?: string;

  static equals(
    a: DeviceRegistrationSubmittedSnapshot | undefined,
    b: DeviceRegistrationSubmittedSnapshot | undefined
  ): boolean {
    if (!a || !b) {
      return false;
    }
    return (a.accountID ?? -1) === (b.accountID ?? -1)
      && a.isAuthenticated === b.isAuthenticated
      && a.bundleID === b.bundleID
      && a.deviceID === b.deviceID
      && a.countryCode === b.countryCode
      && a.regionCode === b.regionCode
      && (a.notificationsEnabled ?? false) === (b.notificationsEnabled ?? false)
      && (a.pushTokenHash ?? '') === (b.pushTokenHash ?? '');
  }

  static fromPlain(obj: Record<string, Object | string | number | boolean | undefined>): DeviceRegistrationSubmittedSnapshot {
    const s = new DeviceRegistrationSubmittedSnapshot();
    if (typeof obj['accountID'] === 'number') {
      s.accountID = obj['accountID'];
    }
    s.isAuthenticated = obj['isAuthenticated'] === true;
    s.bundleID = `${obj['bundleID'] ?? ''}`;
    s.deviceID = `${obj['deviceID'] ?? ''}`;
    s.countryCode = `${obj['countryCode'] ?? ''}`;
    s.regionCode = `${obj['regionCode'] ?? ''}`;
    if (typeof obj['notificationsEnabled'] === 'boolean') {
      s.notificationsEnabled = obj['notificationsEnabled'];
    }
    if (obj['pushTokenHash'] !== undefined) {
      s.pushTokenHash = `${obj['pushTokenHash']}`;
    }
    return s;
  }

  toPlain(): Record<string, string | number | boolean | undefined> {
    const out: Record<string, string | number | boolean | undefined> = {};
    out['accountID'] = this.accountID;
    out['isAuthenticated'] = this.isAuthenticated;
    out['bundleID'] = this.bundleID;
    out['deviceID'] = this.deviceID;
    out['countryCode'] = this.countryCode;
    out['regionCode'] = this.regionCode;
    out['notificationsEnabled'] = this.notificationsEnabled;
    out['pushTokenHash'] = this.pushTokenHash;
    return out;
  }

  toJson(): string {
    return JSON.stringify(this.toPlain());
  }

  static fromJson(text: string): DeviceRegistrationSubmittedSnapshot | undefined {
    if (!text || text.length === 0) {
      return undefined;
    }
    try {
      const obj = JSON.parse(text) as Record<string, Object | string | number | boolean | undefined>;
      return DeviceRegistrationSubmittedSnapshot.fromPlain(obj);
    } catch (_e) {
      return undefined;
    }
  }
}
