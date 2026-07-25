import { RemoteManagedFile } from '../../../../../Core/Networking/API/Medical/MedicalSyncAPI';
import { ManagedFileRecord } from '../../../../../../Core/FileStorage/FileStorageModels';
import { nilIfBlank, isMedicationImageLike } from '../MedicineBox/MedicalFileUtils';

const IMAGE_EXTENSIONS: string[] = ['png', 'jpg', 'jpeg', 'heic', 'webp'];

export function remoteManagedFileFromRecord(
  record: ManagedFileRecord,
  businessType?: string,
  businessId?: string
): RemoteManagedFile {
  const file = new RemoteManagedFile();
  file.id = record.id;
  file.fileUuid = record.fileUuid;
  file.originalName = record.originalName;
  file.fileSize = record.fileSize;
  file.mimeType = record.mimeType;
  file.fileMd5 = record.fileMd5;
  file.businessType = businessType ?? record.businessType;
  file.businessId = businessId ?? record.businessId;
  file.objectKey = record.objectKey;
  file.storageType = record.storageType;
  file.createdAt = record.createdAt;
  file.fileUrl = record.filePath;
  return file;
}

export function numberedAttachmentDisplayName(index: number): string {
  return `附件 ${index + 1}`;
}

export function remoteManagedFileDisplayName(file: RemoteManagedFile): string {
  const name = nilIfBlank(file.originalName);
  if (name) {
    return name;
  }
  return `Attachment-${file.id}`;
}

export function isRemoteFileImageLike(file: RemoteManagedFile): boolean {
  return isMedicationImageLike(file);
}

export function remoteFileSymbolName(file: RemoteManagedFile): string {
  const displayName = remoteManagedFileDisplayName(file);
  const dot = displayName.lastIndexOf('.');
  const ext = dot >= 0 ? displayName.slice(dot + 1).toLowerCase() : '';
  const mime = (file.mimeType ?? '').toLowerCase();
  if (mime.indexOf('pdf') >= 0 || ext === 'pdf') {
    return 'doc.richtext';
  }
  if (mime.indexOf('image') >= 0 || IMAGE_EXTENSIONS.indexOf(ext) >= 0) {
    return 'photo';
  }
  return 'doc';
}

export function remoteFileTintColor(file: RemoteManagedFile): string {
  const displayName = remoteManagedFileDisplayName(file);
  const dot = displayName.lastIndexOf('.');
  const ext = dot >= 0 ? displayName.slice(dot + 1).toLowerCase() : '';
  const mime = (file.mimeType ?? '').toLowerCase();
  if (mime.indexOf('pdf') >= 0 || ext === 'pdf') {
    return '#FF3B30';
  }
  if (mime.indexOf('image') >= 0 || IMAGE_EXTENSIONS.indexOf(ext) >= 0) {
    return '#0A84FF';
  }
  return '#5856D6';
}

export function toManagedFileRecordFromRemote(file: RemoteManagedFile): ManagedFileRecord | undefined {
  if (file.id <= 0) {
    return undefined;
  }
  const fileUuid = nilIfBlank(file.fileUuid);
  if (!fileUuid) {
    return undefined;
  }
  const record = new ManagedFileRecord();
  record.id = file.id;
  record.fileUuid = fileUuid;
  record.filePath = nilIfBlank(file.fileUrl) ?? nilIfBlank(file.objectKey) ?? '';
  record.originalName = remoteManagedFileDisplayName(file);
  record.fileSize = file.fileSize ?? 0;
  record.mimeType = nilIfBlank(file.mimeType) ?? 'application/octet-stream';
  record.fileMd5 = nilIfBlank(file.fileMd5) ?? '';
  record.objectKey = nilIfBlank(file.objectKey) ?? '';
  record.businessType = nilIfBlank(file.businessType) ?? 'medical_attachment';
  record.businessId = nilIfBlank(file.businessId) ?? '';
  return record;
}
