/**
 * 领域成员与绑定能力。与 iOS Member / MemberBindingInfo 对齐。
 */
export class MemberBindingInfo {
  bindingID: number = 0;
  role: string = 'unknown';
  sharedUserCount: number = 0;
  canShare: boolean = false;
  canEdit: boolean = false;
  canDelete: boolean = false;
  canUnbind: boolean = false;
  canManageBindings: boolean = false;

  static restrictedFallback(): MemberBindingInfo {
    return new MemberBindingInfo();
  }
}

export class Member {
  id: number = 0;
  name: string = '';
  gender: string = 'unknown';
  relationship: string = 'self';
  birthDate?: string;
  bloodType: string = '';
  allergies: string[] = [];
  chronicConditions: string[] = [];
  notes: string = '';
  avatarUrl: string = '';
  isPrimary: boolean = false;
  updatedAt: string = '';
  binding?: MemberBindingInfo;

  get effectiveBinding(): MemberBindingInfo {
    if (this.binding) {
      return this.binding;
    }
    return MemberBindingInfo.restrictedFallback();
  }

  get isSelfMember(): boolean {
    const normalized = this.relationship.trim().toLowerCase();
    return normalized === 'self' || normalized === '本人';
  }
}
