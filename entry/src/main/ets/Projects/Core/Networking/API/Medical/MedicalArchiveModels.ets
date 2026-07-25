/**
 * 医疗资源归档查询参数，对应服务端 archived query。与 iOS MedicalArchiveModels 对齐。
 */
export enum MedicalArchiveQuery {
  ACTIVE = 'false',
  ARCHIVED = 'true',
  ALL = 'all'
}

export enum MedicalArchiveListMode {
  ACTIVE = 'active',
  ARCHIVED = 'archived'
}

export function medicalArchiveQueryForMode(mode: MedicalArchiveListMode): MedicalArchiveQuery {
  if (mode === MedicalArchiveListMode.ARCHIVED) {
    return MedicalArchiveQuery.ARCHIVED;
  }
  return MedicalArchiveQuery.ACTIVE;
}
