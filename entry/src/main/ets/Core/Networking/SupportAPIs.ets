import { SupportBackendConfiguration } from '../../Projects/Core/Networking/SupportBackendConfiguration';

/**
 * 跨业务 API 的组合根占位类型。
 *
 * File / OSS 已迁移至 Projects/Core/Networking/API/{File,OSS}；
 * 此处仅保留尚未完成字段映射编译验证的 OCR 占位。
 */
export class SupportDeviceAPI {
  private readonly configuration: SupportBackendConfiguration;
  constructor(configuration: SupportBackendConfiguration) {
    this.configuration = configuration;
  }
}

export class SupportOCRAPI {
  private readonly configuration: SupportBackendConfiguration;
  constructor(configuration: SupportBackendConfiguration) {
    this.configuration = configuration;
  }
}
