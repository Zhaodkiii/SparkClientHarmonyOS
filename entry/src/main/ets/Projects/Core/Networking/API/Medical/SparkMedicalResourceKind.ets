/**
 * 统一医疗资源 kind，与 iOS SparkMedicalResourceKind / 后端 MEDICAL_UNIFIED_RESOURCE_VIEWSETS 对齐。
 */
export enum SparkMedicalResourceKind {
  MEMBERS = 'members',
  CASES = 'cases',
  SYMPTOMS = 'symptoms',
  VISITS = 'visits',
  SURGERIES = 'surgeries',
  FOLLOW_UPS = 'follow-ups',
  HEALTH_EXAM_REPORTS = 'health-exam-reports',
  EXAMINATION_REPORTS = 'examination-reports',
  MED_EXAM_DETAILS = 'med-exam-details',
  MEDICINE_BOXES = 'medicine-boxes',
  PRESCRIPTIONS = 'prescriptions',
  MEDICATION_PLANS = 'medication-plans',
  MEDICATION_RECORDS = 'medication-records',
  MEMBER_MEDICAL_PROFILES = 'member-medical-profiles',
  MEMBER_KEY_INDICATORS = 'member-key-indicators',
  MEMBER_MODULE_SETTINGS = 'member-module-settings'
}

export function sparkMedicalResourceKindRaw(kind: SparkMedicalResourceKind): string {
  return `${kind}`;
}
