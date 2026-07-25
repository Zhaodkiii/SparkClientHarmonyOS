import { Member } from '../../../Core/Domain/Entities/Member';
import { SelectedMemberIDStore } from '../Infrastructure/SelectedMemberIDStore';

export class MemberContext {
  members: Member[] = [];
  selectedMemberID?: number;
}

/**
 * 成员上下文。与 iOS MemberContextStore 对齐（内存 + 选中持久化）。
 */
export class MemberContextStore {
  private readonly persistence: SelectedMemberIDStore;
  private current: MemberContext = new MemberContext();
  private accountID: number = 0;
  private changeListeners: Array<() => void> = [];

  constructor(persistence: SelectedMemberIDStore) {
    this.persistence = persistence;
  }

  get context(): MemberContext {
    return this.current;
  }

  onMembersDidChange(listener: () => void): void {
    this.changeListeners.push(listener);
  }

  private notifyChange(): void {
    for (let i = 0; i < this.changeListeners.length; i++) {
      this.changeListeners[i]();
    }
  }

  async bindAccount(accountID: number): Promise<void> {
    if (this.accountID !== accountID) {
      this.accountID = accountID;
      this.current = new MemberContext();
      const persisted = await this.persistence.load(accountID);
      this.current.selectedMemberID = persisted;
    }
  }

  async update(members: Member[], selectedMemberID: number | undefined): Promise<void> {
    this.current.members = members;
    this.current.selectedMemberID = selectedMemberID;
    if (this.accountID > 0) {
      await this.persistence.save(selectedMemberID, this.accountID);
    }
    this.notifyChange();
  }

  async select(memberID: number | undefined): Promise<void> {
    this.current.selectedMemberID = memberID;
    if (this.accountID > 0) {
      await this.persistence.save(memberID, this.accountID);
    }
    this.notifyChange();
  }

  async clearForAccount(accountID: number): Promise<void> {
    await this.persistence.clear(accountID);
    if (this.accountID === accountID) {
      this.current = new MemberContext();
      this.notifyChange();
    }
  }
}
