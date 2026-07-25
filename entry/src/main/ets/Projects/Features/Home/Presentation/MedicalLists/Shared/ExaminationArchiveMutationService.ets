import { SparkMedicalWorkflowAPI } from '../../../../../Core/Networking/API/Medical/MedicalWorkflowAPI';
import { SparkMedicalResourceKind } from '../../../../../Core/Networking/API/Medical/SparkMedicalResourceKind';
import { RemoteExaminationReportWithAttachments } from '../../../../../Core/Networking/API/Medical/MedicalSyncAPI';

/**
 * 检查报告归档/删除。对齐 iOS MedicalArchiveMutationService（检查分支）。
 * 禁止复用 setHealthExamArchived。
 */
export class ExaminationArchiveMutationService {
  private readonly workflowAPI: SparkMedicalWorkflowAPI;

  constructor(workflowAPI: SparkMedicalWorkflowAPI) {
    this.workflowAPI = workflowAPI;
  }

  async setArchived(id: number, archived: boolean): Promise<RemoteExaminationReportWithAttachments> {
    return this.workflowAPI.setExaminationArchived(id, archived);
  }

  async deleteReport(id: number): Promise<void> {
    await this.workflowAPI.deleteResource(SparkMedicalResourceKind.EXAMINATION_REPORTS, id);
  }
}
