import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';

const PREF_NAME: string = 'member_context_selected';
const KEY_PREFIX: string = 'memberContext.selectedMemberID.';

/**
 * 按账号隔离持久化当前选中成员 ID。与 iOS UserDefaultsSelectedMemberIDStore 对齐。
 */
export class SelectedMemberIDStore {
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

  private key(accountID: number): string {
    return `${KEY_PREFIX}${accountID}`;
  }

  async load(accountID: number): Promise<number | undefined> {
    await this.ensureReady();
    if (!this.pref) {
      return undefined;
    }
    const raw = await this.pref.get(this.key(accountID), 0);
    const n = Number(raw);
    if (!n || n <= 0) {
      return undefined;
    }
    return n;
  }

  async save(memberID: number | undefined, accountID: number): Promise<void> {
    await this.ensureReady();
    if (!this.pref) {
      return;
    }
    const k = this.key(accountID);
    if (memberID === undefined || memberID === null) {
      await this.pref.delete(k);
    } else {
      await this.pref.put(k, memberID);
    }
    await this.pref.flush();
  }

  async clear(accountID: number): Promise<void> {
    await this.save(undefined, accountID);
  }
}
