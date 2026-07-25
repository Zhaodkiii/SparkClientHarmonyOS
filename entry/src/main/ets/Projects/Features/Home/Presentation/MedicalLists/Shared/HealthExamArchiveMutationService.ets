import { SparkMedicalWorkflowAPI } from '../../../../../Core/Networking/API/Medical/MedicalWorkflowAPI';
import { SparkMedicalResourceKind } from '../../../../../Core/Networking/API/Medical/SparkMedicalResourceKind';
import { RemoteHealthExamReportWithAttachments } from '../../../../../Core/Networking/API/Medical/MedicalSyncAPI';

/**
 * 体检归档/删除。对齐 iOS MedicalArchiveMutationService（体检分支）。
 */
export class HealthExamArchiveMutationService {
  private readonly workflowAPI: SparkMedicalWorkflowAPI;

  constructor(workflowAPI: SparkMedicalWorkflowAPI) {
    this.workflowAPI = workflowAPI;
  }

  async setArchived(id: number, archived: boolean): Promise<RemoteHealthExamReportWithAttachments> {
    return this.workflowAPI.setHealthExamArchived(id, archived);
  }

  async deleteReport(id: number): Promise<void> {
    await this.workflowAPI.deleteResource(SparkMedicalResourceKind.HEALTH_EXAM_REPORTS, id);
  }
}
