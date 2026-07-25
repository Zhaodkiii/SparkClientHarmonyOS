import { Member, MemberBindingInfo } from '../../../Domain/Entities/Member';
import { RemoteMember } from './MedicalSyncAPI';

/**
 * Remote DTO → Domain 映射。与 iOS MedicalRemoteDTO+Domain 对齐（成员首期）。
 */
export function remoteMemberToDomain(remote: RemoteMember): Member {
  const m = new Member();
  m.id = remote.id;
  m.name = remote.name;
  m.gender = remote.gender;
  m.relationship = remote.relationship && remote.relationship.length > 0 ? remote.relationship : 'self';
  m.birthDate = remote.birthDate;
  m.bloodType = remote.bloodType;
  m.allergies = remote.allergies;
  m.chronicConditions = remote.chronicConditions;
  m.notes = remote.notes;
  m.avatarUrl = remote.avatarUrl;
  m.isPrimary = remote.isPrimary;
  m.updatedAt = remote.updatedAt;
  if (remote.bindingId !== undefined && remote.bindingId !== null) {
    const b = new MemberBindingInfo();
    b.bindingID = remote.bindingId;
    b.role = remote.bindingRole && remote.bindingRole.length > 0 ? remote.bindingRole : 'owner';
    b.sharedUserCount = remote.sharedUserCount !== undefined ? remote.sharedUserCount : 1;
    b.canShare = remote.canShare === true;
    b.canEdit = remote.canEdit === true;
    b.canDelete = remote.canDelete === true;
    b.canUnbind = remote.canUnbind !== false;
    b.canManageBindings = remote.canManageBindings === true;
    m.binding = b;
  }
  return m;
}

export function remoteMembersToDomain(remotes: RemoteMember[]): Member[] {
  const out: Member[] = [];
  for (let i = 0; i < remotes.length; i++) {
    out.push(remoteMemberToDomain(remotes[i]));
  }
  return out;
}
