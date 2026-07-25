import { SupportBackendConfiguration } from '../../SupportBackendConfiguration';
import { SparkMedicalWorkflowAPI, UpsertMemberPayload } from './MedicalWorkflowAPI';
import { RemoteMember } from './MedicalSyncAPI';
import { SparkMedicalResourceKind } from './SparkMedicalResourceKind';

/**
 * 成员 CRUD。与 iOS SparkMedicalMemberAPI 对齐。
 */
export class SparkMedicalMemberAPI {
  private readonly resources: SparkMedicalWorkflowAPI;

  constructor(configuration: SupportBackendConfiguration, workflow?: SparkMedicalWorkflowAPI) {
    this.resources = workflow ?? new SparkMedicalWorkflowAPI(configuration);
  }

  async listMembers(): Promise<RemoteMember[]> {
    return this.resources.listMembers();
  }

  async createMember(payload: UpsertMemberPayload): Promise<RemoteMember> {
    return this.resources.createMember(payload);
  }

  async updateMember(remoteID: number, payload: UpsertMemberPayload): Promise<RemoteMember> {
    return this.resources.replaceMember(remoteID, payload);
  }

  async deleteMember(remoteID: number): Promise<void> {
    await this.resources.deleteResource(SparkMedicalResourceKind.MEMBERS, remoteID);
  }
}
