import { OCROrchestrator } from '../../../Core/OCR/OCROrchestrator';
import {
  OCRRecognition,
  OCRRequestOptions
} from '../../../Core/OCR/OCRModels';
import { MedicalAttachmentInput } from '../../Home/Presentation/MedicalLists/MedicalDocumentAttachmentUploader';

/**
 * 医疗上传 OCR 适配器：把附件 URI/MIME 路由到 Core OCR 编排器。
 */
export class HarmonyMedicalDocumentOCRAdapter {
  private readonly orchestrator: OCROrchestrator;

  constructor(orchestrator: OCROrchestrator) {
    this.orchestrator = orchestrator;
  }

  async recognizeFile(
    file: MedicalAttachmentInput,
    options: OCRRequestOptions = OCRRequestOptions.medicalDefault()
  ): Promise<OCRRecognition> {
    if (file.sourceUri.length === 0) {
      throw new Error('attachmentSourceInvalid');
    }
    if (HarmonyMedicalDocumentOCRAdapter.isImage(file)) {
      return await this.orchestrator.recognizeFromUri(file.sourceUri, options);
    }
    return await this.orchestrator.recognizeDocument(
      file.sourceUri,
      file.mimeType,
      options
    );
  }

  static isImage(file: MedicalAttachmentInput): boolean {
    const mime = file.mimeType.toLowerCase();
    if (mime.indexOf('image/') === 0) {
      return true;
    }
    const name = file.originalName.toLowerCase();
    const uri = file.sourceUri.toLowerCase();
    const path = name.length > 0 ? name : uri;
    return path.endsWith('.jpg') || path.endsWith('.jpeg') || path.endsWith('.png') ||
      path.endsWith('.webp') || path.endsWith('.heic') || path.endsWith('.bmp');
  }
}
