import { MedicalAttachmentInput } from '../../Home/Presentation/MedicalLists/MedicalDocumentAttachmentUploader';
import { MedicalDocumentKind } from './MedicalDocumentKind';
import { MedicalDocumentOCRResult, MedicalFileOCRResult } from './MedicalDocumentOCRResult';

export { MedicalDocumentOCRResult, MedicalFileOCRResult };

/**
 * OCR UseCase 请求：使用本地附件 URI 做识别，不依赖 UI 状态。
 * 与断点用的 MedicalDocumentOCRInput（远程文件列表）互补。
 */
export class MedicalDocumentOCRRequest {
  uploadSessionId: string = '';
  memberId: number = 0;
  selectedKind: MedicalDocumentKind = MedicalDocumentKind.AUTO;
  files: MedicalAttachmentInput[] = [];
  reRecognizeAll: boolean = false;
}
