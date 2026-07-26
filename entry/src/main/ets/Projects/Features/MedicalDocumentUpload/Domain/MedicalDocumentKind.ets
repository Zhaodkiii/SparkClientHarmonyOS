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

/** 列表页附件上传默认入口。 */
export enum MedicalAttachmentUploadAutoPresentation {
  CAMERA = 'camera',
  PHOTO_LIBRARY = 'photoLibrary',
  FILE_PICKER = 'filePicker'
}

/**
 * 医疗列表附件上传 Sheet 配置。
 * 对齐 iOS `MedicalAttachmentUploadListSheet.swift` 中的 `MedicalDocumentKind` 扩展。
 */
export class MedicalAttachmentUploadKindConfig {
  fileNamePrefix: string = 'medical_upload';
  maxFileCount: number = 5;
  cameraMaxCaptureCount: number = 1;
  sheetTitle: string = '选择文件';
  headerTitle: string = '选择上传方式';
  headerSubtitle: string = '可拍照、从相册选择或上传 PDF/图片，确认后开始识别。';
  emptyTitle: string = '尚未选择文件';
  emptySubtitle: string = '可拍照、从相册选择或上传 PDF/图片';
  showsManualAddButton: boolean = true;
  listManualAddActionTitle: string = '手动添加';
  listCameraAddActionTitle: string = '拍摄添加';
  tintColor: string = '#0A84FF';
  autoPresentation: MedicalAttachmentUploadAutoPresentation =
    MedicalAttachmentUploadAutoPresentation.CAMERA;
}

export function medicalAttachmentUploadConfig(kind: MedicalDocumentKind): MedicalAttachmentUploadKindConfig {
  const config = new MedicalAttachmentUploadKindConfig();
  switch (kind) {
    case MedicalDocumentKind.MEDICAL_REPORT:
      config.fileNamePrefix = 'medical_report';
      config.maxFileCount = 3;
      config.cameraMaxCaptureCount = 3;
      config.sheetTitle = '选择检查报告图片';
      config.headerTitle = '选择上传方式';
      config.headerSubtitle = '可一次选择多张检查、检验或影像报告图片，确认后开始识别。';
      config.emptyTitle = '尚未选择文件';
      config.emptySubtitle = '可拍照、从相册选择或上传 PDF/图片';
      config.showsManualAddButton = true;
      config.listManualAddActionTitle = '手动添加';
      config.listCameraAddActionTitle = '拍摄添加报告';
      config.tintColor = '#0A84FF';
      config.autoPresentation = MedicalAttachmentUploadAutoPresentation.CAMERA;
      return config;
    case MedicalDocumentKind.HEALTH_EXAM_REPORT:
      config.fileNamePrefix = 'health_exam_report';
      config.maxFileCount = 6;
      config.cameraMaxCaptureCount = 6;
      config.sheetTitle = '选择体检报告';
      config.headerSubtitle = '可一次拍摄或选择最多 6 张体检报告图片，确认后开始识别。';
      config.emptySubtitle = '可拍照、从相册选择或上传 PDF/图片';
      config.showsManualAddButton = false;
      config.listCameraAddActionTitle = '拍摄添加体检报告';
      config.tintColor = '#30B0C7';
      config.autoPresentation = MedicalAttachmentUploadAutoPresentation.FILE_PICKER;
      return config;
    case MedicalDocumentKind.CASE_DOCUMENT:
      config.fileNamePrefix = 'case_document';
      config.maxFileCount = 5;
      config.cameraMaxCaptureCount = 5;
      config.sheetTitle = '选择病历图片';
      config.headerSubtitle = '可一次选择最多 5 个门诊病历、出院小结或相关附件，确认后开始识别。';
      config.listCameraAddActionTitle = '拍摄添加病历';
      config.autoPresentation = MedicalAttachmentUploadAutoPresentation.PHOTO_LIBRARY;
      return config;
    case MedicalDocumentKind.PRESCRIPTION:
    case MedicalDocumentKind.MEDICATION_PLAN:
      config.fileNamePrefix = kind === MedicalDocumentKind.PRESCRIPTION ? 'prescription' : 'medication_plan';
      config.maxFileCount = 5;
      config.cameraMaxCaptureCount = 5;
      config.sheetTitle = kind === MedicalDocumentKind.PRESCRIPTION ? '处方' : '选择服药计划图片';
      config.headerSubtitle = '可一次选择多张处方、药品说明或服药计划图片，确认后开始识别。';
      config.listCameraAddActionTitle = '拍摄添加计划';
      config.tintColor = '#AF52DE';
      return config;
    case MedicalDocumentKind.MEDICINE_BOX:
      config.fileNamePrefix = 'medicine_box';
      config.maxFileCount = 5;
      config.cameraMaxCaptureCount = 1;
      config.sheetTitle = '选择药品图片';
      config.headerSubtitle = '可一次选择多张药盒、药瓶或说明书图片，确认后开始识别。';
      config.showsManualAddButton = false;
      config.listCameraAddActionTitle = '拍照添加药品';
      config.tintColor = '#AF52DE';
      return config;
    default:
      return config;
  }
}
