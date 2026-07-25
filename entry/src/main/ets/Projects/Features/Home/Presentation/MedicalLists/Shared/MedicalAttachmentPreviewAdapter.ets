import { ManagedFileRecord } from '../../../../../../Core/FileStorage/FileStorageModels';
import { RemoteManagedFile } from '../../../../../Core/Networking/API/Medical/MedicalSyncAPI';
import { FilePreviewInput } from '../../../../../Core/UI/FilePreview/FilePreviewInput';
import { MedicalAttachmentInput } from '../MedicalDocumentAttachmentUploader';
import {
  numberedAttachmentDisplayName,
  remoteManagedFileDisplayName
} from './MedicalAttachmentPreviewSupport';

/**
 * 本地附件 / 远端附件 → 统一预览输入。对齐 iOS `MedicalUploadLocalFile.previewInput`。
 */
export class MedicalAttachmentPreviewAdapter {
  static fromLocalAttachment(file: MedicalAttachmentInput, title?: string): FilePreviewInput {
    const displayName = title && title.length > 0 ? title :
      (file.originalName.length > 0 ? file.originalName : '医疗附件');
    return FilePreviewInput.create(
      file.sourceUri,
      displayName,
      file.mimeType,
      file.previewId.length > 0 ? file.previewId : undefined
    );
  }

  static fromLocalAttachments(files: MedicalAttachmentInput[]): FilePreviewInput[] {
    const inputs: FilePreviewInput[] = [];
    for (let i = 0; i < files.length; i++) {
      inputs.push(MedicalAttachmentPreviewAdapter.fromLocalAttachment(files[i]));
    }
    return inputs;
  }

  static fromManagedRecord(record: ManagedFileRecord, title?: string): FilePreviewInput {
    const displayName = title && title.length > 0 ? title :
      (record.originalName.length > 0 ? record.originalName : '医疗附件');
    const path = record.filePath.length > 0 ? record.filePath : '';
    return FilePreviewInput.create(path, displayName, record.mimeType, `${record.id}`);
  }

  static fromRemoteAttachment(
    file: RemoteManagedFile,
    localPath: string,
    index: number = 0
  ): FilePreviewInput {
    const displayName = numberedAttachmentDisplayName(index);
    const fallbackName = remoteManagedFileDisplayName(file);
    return FilePreviewInput.create(
      localPath,
      displayName.length > 0 ? displayName : fallbackName,
      file.mimeType ?? undefined,
      `remote-${file.id}`
    );
  }
}
