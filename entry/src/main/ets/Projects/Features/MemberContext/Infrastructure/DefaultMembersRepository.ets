import { SparkMedicalQueryAPI } from '../../../Core/Networking/API/Medical/MedicalQueryAPI';
import { remoteMembersToDomain } from '../../../Core/Networking/API/Medical/MedicalRemoteDTO+Domain';
import { Member } from '../../../Core/Domain/Entities/Member';

/**
 * 成员列表局部刷新。失败返回空数组（与 iOS DefaultMembersRepository 语义一致）。
 */
export class DefaultMembersRepository {
  private readonly medicalQueryAPI: SparkMedicalQueryAPI;

  constructor(medicalQueryAPI: SparkMedicalQueryAPI) {
    this.medicalQueryAPI = medicalQueryAPI;
  }

  async loadMembers(): Promise<Member[]> {
    try {
      const remotes = await this.medicalQueryAPI.listMembers();
      return remoteMembersToDomain(remotes);
    } catch (_e) {
      return [];
    }
  }
}
