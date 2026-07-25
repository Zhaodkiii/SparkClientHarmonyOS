import { SparkMedicalWorkflowAPI } from '../../../../../Core/Networking/API/Medical/MedicalWorkflowAPI';
import { SparkMedicalResourceKind } from '../../../../../Core/Networking/API/Medical/SparkMedicalResourceKind';
import { RemoteMedicineBox } from '../../../../../Core/Networking/API/Medical/MedicalSyncAPI';

/**
 * 药箱归档/删除。对齐 iOS MedicalArchiveMutationService（药箱分支）。
 */
export class MedicineBoxArchiveMutationService {
  private readonly workflowAPI: SparkMedicalWorkflowAPI;

  constructor(workflowAPI: SparkMedicalWorkflowAPI) {
    this.workflowAPI = workflowAPI;
  }

  async setArchived(id: number, archived: boolean): Promise<RemoteMedicineBox> {
    return this.workflowAPI.setMedicineBoxArchived(id, archived);
  }

  async deleteBox(id: number): Promise<void> {
    await this.workflowAPI.deleteResource(SparkMedicalResourceKind.MEDICINE_BOXES, id);
  }
}
