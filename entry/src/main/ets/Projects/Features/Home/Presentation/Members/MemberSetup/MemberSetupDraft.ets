/**
 * 成员建档草稿与模块枚举。与 iOS MemberSetupDraft / MemberSetupModule 对齐。
 */
export class MemberSetupDraft {
  name: string = '';
  birthDate?: string;
  relationshipCode: string = 'self';
  gender: string = '';
}

export class MemberSetupModule {
  static readonly MEDICAL: MemberSetupModule = new MemberSetupModule('medical', 0, '医疗模块', '慢病、用药、体检、症状随访', true);
  static readonly NUTRITION: MemberSetupModule =
    new MemberSetupModule('nutrition', 1, '饮食健康', '饮食目标、营养、体重管理', true);
  static readonly DAILY_HEALTH: MemberSetupModule =
    new MemberSetupModule('daily_health', 2, '日常健康', '运动、睡眠、饮水、照护提醒（预留）', false);

  readonly rawValue: string;
  readonly displayOrder: number;
  readonly title: string;
  readonly subtitle: string;
  readonly isVisibleInSetup: boolean;

  constructor(
    rawValue: string,
    displayOrder: number,
    title: string,
    subtitle: string,
    isVisibleInSetup: boolean
  ) {
    this.rawValue = rawValue;
    this.displayOrder = displayOrder;
    this.title = title;
    this.subtitle = subtitle;
    this.isVisibleInSetup = isVisibleInSetup;
  }

  static allVisible(): MemberSetupModule[] {
    return [MemberSetupModule.MEDICAL, MemberSetupModule.NUTRITION];
  }

  static fromRaw(raw: string): MemberSetupModule | undefined {
    if (raw === MemberSetupModule.MEDICAL.rawValue) {
      return MemberSetupModule.MEDICAL;
    }
    if (raw === MemberSetupModule.NUTRITION.rawValue) {
      return MemberSetupModule.NUTRITION;
    }
    if (raw === MemberSetupModule.DAILY_HEALTH.rawValue) {
      return MemberSetupModule.DAILY_HEALTH;
    }
    return undefined;
  }
}

export type MemberSetupFlowMode = 'create' | 'maintain';

export type MemberSetupStep = 'nameBirth' | 'birthDate' | 'relationship' | 'modules';
