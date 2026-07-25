import { SupportBackendConfiguration } from '../../SupportBackendConfiguration';

/**
 * 成员分享 API 扩展文件（与 iOS MedicalMemberAPI+Share 同名）。方法待补全。
 */
export class SparkMedicalMemberShareAPI {
  private readonly configuration: SupportBackendConfiguration;

  constructor(configuration: SupportBackendConfiguration) {
    this.configuration = configuration;
  }

  /** 桩占位：后续 Share 方法使用 configuration */
  isConfigured(): boolean {
    return this.configuration !== undefined;
  }

  // TODO: fetchMemberDetail / generateShareTicket / resolveShareTicket / acceptShareTicket
}
