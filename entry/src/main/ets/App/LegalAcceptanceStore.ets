import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { AuthUiState } from '../Projects/Features/Auth/AuthUiState';

const PREF_NAME: string = 'support_auth_legal';
const KEY_ACCEPTED: string = 'legal_accepted';
const KEY_VERSION: string = 'legal_accepted_version';

/**
 * 协议确认态（非敏感）；写后 flush。
 */
export class LegalAcceptanceStore {
  private pref?: preferences.Preferences;
  private readonly ready: Promise<void>;

  constructor(context: common.Context) {
    this.ready = preferences.getPreferences(context, PREF_NAME)
      .then((p: preferences.Preferences) => {
        this.pref = p;
      })
      .catch(() => {
        this.pref = undefined;
      });
  }

  async ensureReady(): Promise<void> {
    await this.ready;
  }

  async isAccepted(): Promise<boolean> {
    await this.ensureReady();
    if (!this.pref) {
      return false;
    }
    const accepted = await this.pref.get(KEY_ACCEPTED, false);
    const version = `${await this.pref.get(KEY_VERSION, '')}`;
    return accepted === true && version === AuthUiState.LEGAL_VERSION;
  }

  async accept(): Promise<void> {
    await this.ensureReady();
    if (!this.pref) {
      return;
    }
    await this.pref.put(KEY_ACCEPTED, true);
    await this.pref.put(KEY_VERSION, AuthUiState.LEGAL_VERSION);
    await this.pref.flush();
  }

  async revoke(): Promise<void> {
    await this.ensureReady();
    if (!this.pref) {
      return;
    }
    await this.pref.put(KEY_ACCEPTED, false);
    await this.pref.put(KEY_VERSION, '');
    await this.pref.flush();
  }

  async clearForTests(): Promise<void> {
    await this.ensureReady();
    if (!this.pref) {
      return;
    }
    await this.pref.clear();
    await this.pref.flush();
  }
}

/** 协议阅读占位 HTTPS（可后续替换正式域名）。 */
export class LegalUrls {
  static readonly TERMS: string = 'https://www.dreamwhale.top/legal/terms';
  static readonly PRIVACY: string = 'https://www.dreamwhale.top/legal/privacy';
  static readonly HEALTH: string = 'https://www.dreamwhale.top/legal/health-disclaimer';
  static readonly PERMISSIONS: string = 'https://www.dreamwhale.top/legal/permissions';

  static urlFor(type: string): string {
    if (type === 'privacy') {
      return LegalUrls.PRIVACY;
    }
    if (type === 'health') {
      return LegalUrls.HEALTH;
    }
    if (type === 'permissions') {
      return LegalUrls.PERMISSIONS;
    }
    return LegalUrls.TERMS;
  }
}
