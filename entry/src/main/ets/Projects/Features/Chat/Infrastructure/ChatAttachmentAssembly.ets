import { ManagedFileRecord } from '../../../../Core/FileStorage/FileStorageModels';
import { ChatAttachment, ChatAttachmentKind } from '../Domain/ChatModels';

export class ChatPreparedAttachment {
  previewId: string = '';
  attachment: ChatAttachment = new ChatAttachment();
  ocrText?: string;
}

/** 把文件域的远端记录转换成 ChatMessage.attachments_json 的稳定 DTO。 */
export class ChatAttachmentAssembly {
  static fromManagedFile(
    record: ManagedFileRecord,
    kind: ChatAttachmentKind,
    ocrText?: string,
    publicUrl?: string
  ): ChatPreparedAttachment {
    const prepared = new ChatPreparedAttachment();
    prepared.previewId = record.fileUuid;
    prepared.ocrText = ocrText;
    const attachment = new ChatAttachment();
    attachment.id = record.fileUuid.length > 0 ? record.fileUuid : `file_${record.id}`;
    attachment.kind = kind;
    attachment.fileId = record.id > 0 ? `${record.id}` : undefined;
    attachment.fileMd5 = record.fileMd5.length > 0 ? record.fileMd5 : undefined;
    attachment.fileName = record.originalName.length > 0 ? record.originalName : undefined;
    attachment.mimeType = record.mimeType.length > 0 ? record.mimeType : undefined;
    attachment.size = record.fileSize > 0 ? record.fileSize : undefined;
    attachment.fullCacheKey = record.fileUuid.length > 0 && record.originalName.length > 0
      ? `${record.fileUuid.toLowerCase()}/${record.originalName}`
      : undefined;
    attachment.objectKey = record.objectKey.length > 0 ? record.objectKey : undefined;
    attachment.url = publicUrl;
    attachment.text = ocrText;
    prepared.attachment = attachment;
    return prepared;
  }
}
