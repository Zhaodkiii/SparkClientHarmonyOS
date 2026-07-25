import { bundleManager } from '@kit.AbilityKit';
import { deviceInfo } from '@kit.BasicServicesKit';
import { display } from '@kit.ArkUI';
import { i18n } from '@kit.LocalizationKit';
import { AUTH_BUNDLE_ID } from './Security/DeviceCredentialStore';

/**
 * 设备/应用画像快照；供设备登记请求填充。
 */
export class SupportSystemInfoSnapshot {
  bundleId: string = AUTH_BUNDLE_ID;
  appVersion: string = '1.0.0';
  buildVersion: string = '1';
  platform: string = 'harmonyos';
  systemVersion: string = '';
  deviceModel: string = '';
  deviceModelName: string = 'phone';
  deviceName: string = '';
  screenSize: string = '';
  screenScale?: number;
  timeZone: string = '';
  languageCode: string = '';
  regionCode: string = '';
  countryCode: string = '';
  isSimulator: boolean = false;
}

/**
 * 系统信息采集；可注入固定快照供单测。
 */
export abstract class SystemInfoProvider {
  abstract collect(): SupportSystemInfoSnapshot;
}

export class FixedSystemInfo extends SystemInfoProvider {
  private readonly snapshot: SupportSystemInfoSnapshot;

  constructor(snapshot: SupportSystemInfoSnapshot) {
    super();
    this.snapshot = snapshot;
  }

  collect(): SupportSystemInfoSnapshot {
    return this.snapshot;
  }
}

export class SupportSystemInfo extends SystemInfoProvider {
  collect(): SupportSystemInfoSnapshot {
    const snap = new SupportSystemInfoSnapshot();
    SupportSystemInfo.fillBundle(snap);
    SupportSystemInfo.fillDevice(snap);
    SupportSystemInfo.fillDisplay(snap);
    SupportSystemInfo.fillLocale(snap);
    return snap;
  }

  private static fillBundle(snap: SupportSystemInfoSnapshot): void {
    try {
      const flag = bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION;
      const info = bundleManager.getBundleInfoForSelfSync(flag);
      if (info.name && info.name.length > 0) {
        snap.bundleId = info.name;
      }
      if (info.versionName && info.versionName.length > 0) {
        snap.appVersion = info.versionName;
      }
      snap.buildVersion = `${info.versionCode}`;
    } catch (_e) {
      // keep defaults
    }
  }

  private static fillDevice(snap: SupportSystemInfoSnapshot): void {
    try {
      if (deviceInfo.osFullName && deviceInfo.osFullName.length > 0) {
        snap.systemVersion = deviceInfo.osFullName;
      } else {
        snap.systemVersion = `API${deviceInfo.sdkApiVersion}`;
      }
      if (deviceInfo.productModel && deviceInfo.productModel.length > 0) {
        snap.deviceModel = deviceInfo.productModel;
      }
      if (deviceInfo.marketName && deviceInfo.marketName.length > 0) {
        snap.deviceModelName = deviceInfo.marketName;
      } else if (snap.deviceModel.length > 0) {
        snap.deviceModelName = snap.deviceModel;
      }
      const dtype = `${deviceInfo.deviceType ?? ''}`;
      if (dtype.indexOf('emulator') >= 0 || dtype.indexOf(' Emulator') >= 0) {
        snap.isSimulator = true;
      }
    } catch (_e) {
      // keep defaults
    }
  }

  private static fillDisplay(snap: SupportSystemInfoSnapshot): void {
    try {
      const d = display.getDefaultDisplaySync();
      snap.screenSize = `${Math.floor(d.width)}x${Math.floor(d.height)}`;
      if (d.scaledDensity !== undefined && d.scaledDensity > 0) {
        snap.screenScale = d.scaledDensity;
      } else if (d.densityDPI > 0) {
        snap.screenScale = d.densityDPI / 160;
      }
    } catch (_e) {
      // keep defaults
    }
  }

  private static fillLocale(snap: SupportSystemInfoSnapshot): void {
    try {
      const lang = i18n.System.getSystemLanguage();
      if (lang && lang.length > 0) {
        const parts = lang.split(/[-_]/);
        snap.languageCode = parts[0] ?? lang;
        if (parts.length > 1) {
          snap.regionCode = parts[parts.length - 1].toUpperCase();
          snap.countryCode = snap.regionCode;
        }
      }
    } catch (_e) {
      // keep defaults
    }
    try {
      const region = i18n.System.getSystemRegion();
      if (region && region.length > 0) {
        snap.regionCode = region.toUpperCase();
        snap.countryCode = snap.regionCode;
      }
    } catch (_e2) {
      // keep defaults
    }
    try {
      const tz = Intl.DateTimeFormat().resolvedOptions().timeZone;
      if (tz && tz.length > 0) {
        snap.timeZone = tz;
      }
    } catch (_e3) {
      // keep defaults
    }
  }
}
