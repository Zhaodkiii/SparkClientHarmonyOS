import { SupportBackendConfiguration } from '../../SupportBackendConfiguration';

/**
 * 体检档案 ExamArchive DTO/API。与 iOS MedicalExamArchiveAPI 对齐；方法待挂到 QueryAPI。
 */
export class SparkMedicalExamArchiveAPI {
  private readonly configuration: SupportBackendConfiguration;

  constructor(configuration: SupportBackendConfiguration) {
    this.configuration = configuration;
  }

  /** 桩占位：后续 ExamArchive 方法使用 configuration */
  isConfigured(): boolean {
    return this.configuration !== undefined;
  }

  // TODO: preview/confirm abnormal items, evidence, AI plan
}
