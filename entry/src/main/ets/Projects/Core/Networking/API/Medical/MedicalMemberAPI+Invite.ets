import { SupportBackendConfiguration } from '../../SupportBackendConfiguration';

/**
 * 成员邀请 API 扩展文件（与 iOS MedicalMemberAPI+Invite 同名）。方法待补全。
 */
export class SparkMedicalMemberInviteAPI {
  private readonly configuration: SupportBackendConfiguration;

  constructor(configuration: SupportBackendConfiguration) {
    this.configuration = configuration;
  }

  /** 桩占位：后续 Invite 方法使用 configuration */
  isConfigured(): boolean {
    return this.configuration !== undefined;
  }

  // TODO: createInvite / pendingInvites / acceptInvite / rejectInvite / cancelInvite / binding 权限
}
