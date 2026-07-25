import { SparkMedicalMemberAPI } from '../../../Core/Networking/API/Medical/MedicalMemberAPI';
import { UpsertMemberPayload } from '../../../Core/Networking/API/Medical/MedicalWorkflowAPI';
import { remoteMemberToDomain } from '../../../Core/Networking/API/Medical/MedicalRemoteDTO+Domain';
import { Member } from '../../../Core/Domain/Entities/Member';

/**
 * 家庭成员增删改。与 iOS ManageHomeMemberUseCase 对齐。
 */
export class ManageHomeMemberUseCase {
  private readonly memberAPI: SparkMedicalMemberAPI;

  constructor(memberAPI: SparkMedicalMemberAPI) {
    this.memberAPI = memberAPI;
  }

  async create(
    name: string,
    relationship: string,
    gender: string,
    birthDate?: string
  ): Promise<Member> {
    const payload = new UpsertMemberPayload();
    payload.name = name;
    payload.relationship = relationship;
    payload.gender = gender;
    payload.birth_date = birthDate;
    payload.blood_type = '';
    payload.allergies = [];
    payload.chronic_conditions = [];
    payload.notes = '';
    payload.avatar_url = '';
    payload.is_primary = false;
    const remote = await this.memberAPI.createMember(payload);
    return remoteMemberToDomain(remote);
  }

  async update(
    member: Member,
    name: string,
    relationship: string,
    gender: string,
    birthDate?: string
  ): Promise<Member> {
    const payload = new UpsertMemberPayload();
    payload.name = name;
    payload.relationship = relationship;
    payload.gender = gender;
    payload.birth_date = birthDate;
    payload.blood_type = member.bloodType;
    payload.allergies = member.allergies;
    payload.chronic_conditions = member.chronicConditions;
    payload.notes = member.notes;
    payload.avatar_url = member.avatarUrl;
    payload.is_primary = member.isPrimary;
    const remote = await this.memberAPI.updateMember(member.id, payload);
    return remoteMemberToDomain(remote);
  }

  async delete(member: Member): Promise<void> {
    await this.memberAPI.deleteMember(member.id);
  }
}
