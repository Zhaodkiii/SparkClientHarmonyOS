/**
 * 对齐 iOS `MedicalDocumentKind`（Projects/Features/MedicalDocumentUpload/Domain/MedicalDocumentTypedModels.swift）。
 * 取值需与后端 `rawType` / 前端上传表单保持一致，不应再新增或改名。
 */
export enum MedicalDocumentKind {
  AUTO = 'auto',
  CASE_DOCUMENT = 'caseDocument',
  HEALTH_EXAM_REPORT = 'healthExamReport',
  MEDICAL_REPORT = 'medicalReport',
  PRESCRIPTION = 'prescription',
  MEDICATION_PLAN = 'medicationPlan',
  MEDICINE_BOX = 'medicineBox'
}

/** 选择器展示顺序，对齐 iOS `MedicalDocumentKind.allCases`。 */
export function medicalDocumentKindAllCases(): MedicalDocumentKind[] {
  return [
    MedicalDocumentKind.AUTO,
    MedicalDocumentKind.CASE_DOCUMENT,
    MedicalDocumentKind.HEALTH_EXAM_REPORT,
    MedicalDocumentKind.MEDICAL_REPORT,
    MedicalDocumentKind.PRESCRIPTION,
    MedicalDocumentKind.MEDICATION_PLAN,
    MedicalDocumentKind.MEDICINE_BOX
  ];
}

/** 对齐 iOS `localizedPickerLabel`（中文默认文案；UI 层优先走 $r）。 */
export function medicalDocumentKindPickerLabel(kind: MedicalDocumentKind): string {
  switch (kind) {
    case MedicalDocumentKind.AUTO:
      return '自动识别';
    case MedicalDocumentKind.CASE_DOCUMENT:
      return '病例';
    case MedicalDocumentKind.HEALTH_EXAM_REPORT:
      return '体检报告';
    case MedicalDocumentKind.MEDICAL_REPORT:
      return '医疗报告';
    case MedicalDocumentKind.PRESCRIPTION:
      return '处方';
    case MedicalDocumentKind.MEDICATION_PLAN:
      return '服药计划';
    case MedicalDocumentKind.MEDICINE_BOX:
      return '药品';
    default:
      return kind;
  }
}

/** 类型图标：用工程内已使用的系统 Symbol 近似 iOS SF Symbol。 */
export function medicalDocumentKindSymbol(kind: MedicalDocumentKind): Resource {
  switch (kind) {
    case MedicalDocumentKind.AUTO:
      return $r('sys.symbol.star_fill');
    case MedicalDocumentKind.CASE_DOCUMENT:
      return $r('sys.symbol.doc_text');
    case MedicalDocumentKind.HEALTH_EXAM_REPORT:
      return $r('sys.symbol.heart_fill');
    case MedicalDocumentKind.MEDICAL_REPORT:
      return $r('sys.symbol.doc_text');
    case MedicalDocumentKind.PRESCRIPTION:
      return $r('sys.symbol.paperclip');
    case MedicalDocumentKind.MEDICATION_PLAN:
      return $r('sys.symbol.checkmark_circle_fill');
    case MedicalDocumentKind.MEDICINE_BOX:
      return $r('sys.symbol.square_stack_3d');
    default:
      return $r('sys.symbol.doc_text');
  }
}
