/**
 * 上传识别流水线阶段与进度出口。
 * Progress 细节仍在 MedicalDocumentUploadProgress；此处补充断点阶段与 OCR 交接边界。
 */
export {
  MedicalDocumentUploadProgress,
  MedicalDocumentUploadProgressStep,
  medicalUploadPipelineOrder,
  medicalUploadPipelineSteps
} from './MedicalDocumentUploadProgress';

export {
  MedicalDocumentUploadFlowStep,
  MedicalDocumentUploadFlowStepKind,
  MedicalDocumentUploadStepOutcome
} from './MedicalDocumentUploadFlowStep';

/** 上传断点阶段（工单 4.4 / 0002 / 0006）。 */
export type MedicalDocumentUploadCheckpointStage =
  'picking' | 'uploading' | 'uploaded' | 'ocr_pending' | 'ocr_done' | 'type_resolved' | 'extracted';
