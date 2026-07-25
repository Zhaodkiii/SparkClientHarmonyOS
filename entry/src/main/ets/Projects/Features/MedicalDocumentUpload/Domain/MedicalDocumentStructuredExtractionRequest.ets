import { MedicalAttachmentInput } from '../../Home/Presentation/MedicalLists/MedicalDocumentAttachmentUploader';
import { MedicalDocumentKind } from './MedicalDocumentKind';
import { MedicalDocumentTypeResolution } from './MedicalDocumentTypedModels';
import { MedicalExtractionPromptSource } from './MedicalExtractionInputSource';
import { MedicalExtractionRetryFeedbackModel } from './MedicalExtractionRetryFeedback';

/** 结构化抽取请求：与 ViewModel 解耦的稳定输入边界。 */
export class MedicalDocumentStructuredExtractionRequest {
  memberId: number = 0;
  uploadSessionId: string = '';
  selectedKind: MedicalDocumentKind = MedicalDocumentKind.AUTO;
  typeResolution?: MedicalDocumentTypeResolution;
  mergedOCRText: string = '';
  files: MedicalAttachmentInput[] = [];
  promptSource: MedicalExtractionPromptSource = MedicalExtractionPromptSource.OCR_TEXT;
  previousRetryFeedback?: MedicalExtractionRetryFeedbackModel;
  preferredModelName: string = '';
}
