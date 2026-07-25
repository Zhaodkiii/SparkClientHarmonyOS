import { FilePreviewInput } from '../../../Core/UI/FilePreview/FilePreviewInput';
import { MedicalAttachmentInput } from '../../Home/Presentation/MedicalLists/MedicalDocumentAttachmentUploader';
import { MedicalAttachmentPreviewAdapter } from
  '../../Home/Presentation/MedicalLists/Shared/MedicalAttachmentPreviewAdapter';
import { MedicalUploadLocalFile } from './MedicalDocumentUploadModels';

/**
 * 上传域附件预览门面。对齐 iOS `MedicalUploadLocalFile.previewInput` 在 upload 域内的归属。
 */
export class MedicalDocumentUploadAttachmentPreview {
  static fromLocalFile(file: MedicalUploadLocalFile): FilePreviewInput {
    return file.previewInput();
  }

  static fromAttachment(file: MedicalAttachmentInput, title?: string): FilePreviewInput {
    return MedicalAttachmentPreviewAdapter.fromLocalAttachment(file, title);
  }

  static fromAttachments(files: MedicalAttachmentInput[]): FilePreviewInput[] {
    return MedicalAttachmentPreviewAdapter.fromLocalAttachments(files);
  }
}
