import { FilePreviewInput } from '../../../../Core/UI/FilePreview/FilePreviewInput';
import { MedicalAttachmentInput } from '../../../Home/Presentation/MedicalLists/MedicalDocumentAttachmentUploader';
import { MedicalDocumentUploadAttachmentPreview } from '../../Domain/MedicalDocumentUploadAttachmentPreview';

const IMAGE_EXTENSIONS: string[] = ['png', 'jpg', 'jpeg', 'heic', 'webp'];

/** 对齐 iOS `MedicalDocumentLocalAttachmentItem`：结果页本地源文件附件项。 */
export class MedicalDocumentLocalAttachmentItem {
  id: string = '';
  fileURL: string = '';
  displayName: string = '';
  mimeType?: string = undefined;

  static fromAttachment(input: MedicalAttachmentInput): MedicalDocumentLocalAttachmentItem {
    const item = new MedicalDocumentLocalAttachmentItem();
    item.id = input.previewId;
    item.fileURL = input.sourceUri;
    item.displayName = input.originalName.length > 0 ? input.originalName : '医疗附件';
    item.mimeType = input.mimeType;
    return item;
  }

  static fromAttachments(inputs: MedicalAttachmentInput[]): MedicalDocumentLocalAttachmentItem[] {
    const items: MedicalDocumentLocalAttachmentItem[] = [];
    for (let i = 0; i < inputs.length; i++) {
      items.push(MedicalDocumentLocalAttachmentItem.fromAttachment(inputs[i]));
    }
    return items;
  }

  previewInput(): FilePreviewInput {
    const attachment = new MedicalAttachmentInput();
    attachment.previewId = this.id;
    attachment.sourceUri = this.fileURL;
    attachment.originalName = this.displayName;
    attachment.mimeType = this.mimeType ?? 'application/octet-stream';
    return MedicalDocumentUploadAttachmentPreview.fromAttachment(attachment, this.displayName);
  }

  private extension(): string {
    const dot = this.displayName.lastIndexOf('.');
    if (dot < 0) {
      return '';
    }
    return this.displayName.slice(dot + 1).toLowerCase();
  }

  tintColor(): string {
    const mime = (this.mimeType ?? '').toLowerCase();
    const ext = this.extension();
    if (mime.indexOf('pdf') >= 0 || ext === 'pdf') {
      return '#FF3B30';
    }
    if (mime.indexOf('image') >= 0 || IMAGE_EXTENSIONS.indexOf(ext) >= 0) {
      return '#0A84FF';
    }
    return '#5856D6';
  }
}
