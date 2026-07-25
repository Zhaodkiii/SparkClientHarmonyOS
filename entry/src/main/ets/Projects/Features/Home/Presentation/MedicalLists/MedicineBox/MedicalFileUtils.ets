import { RemoteManagedFile } from '../../../../../Core/Networking/API/Medical/MedicalSyncAPI';
import { ManagedFileRecord } from '../../../../../../Core/FileStorage/FileStorageModels';

const IMAGE_EXTENSIONS: string[] = ['png', 'jpg', 'jpeg', 'heic', 'webp'];

/** 对齐 iOS `RemoteManagedFile.isMedicationImageLike` */
export function isMedicationImageLike(file: RemoteManagedFile): boolean {
  const displayName = file.originalName ?? '';
  const dotIndex = displayName.lastIndexOf('.');
  const ext = dotIndex >= 0 ? displayName.slice(dotIndex + 1).toLowerCase() : '';
  const mime = (file.mimeType ?? '').toLowerCase();
  return mime.indexOf('image') >= 0 || IMAGE_EXTENSIONS.indexOf(ext) >= 0;
}

/** 对齐 iOS `.nilIfBlank` */
export function nilIfBlank(value: string | undefined | null): string | undefined {
  if (value === undefined || value === null) {
    return undefined;
  }
  const trimmed = value.trim();
  return trimmed.length === 0 ? undefined : trimmed;
}

/** 将医疗同步附件映射为 FileTransferService 可下载的 ManagedFileRecord */
export function toManagedFileRecord(file: RemoteManagedFile): ManagedFileRecord | undefined {
  if (file.id <= 0) {
    return undefined;
  }
  const record = new ManagedFileRecord();
  record.id = file.id;
  record.fileUuid = (file.fileUuid ?? '').length > 0 ? (file.fileUuid as string) : `remote_file_${file.id}`;
  record.originalName = file.originalName ?? '';
  record.fileSize = file.fileSize ?? 0;
  record.mimeType = file.mimeType ?? '';
  record.fileMd5 = file.fileMd5 ?? '';
  record.objectKey = file.objectKey ?? '';
  record.businessType = file.businessType ?? '';
  record.businessId = file.businessId ?? '';
  return record;
}

export function formatQuantity(value: number | undefined): string {
  if (value === undefined || value === null) {
    return '';
  }
  const fixed = value.toFixed(2);
  let trimmed = fixed.replace(/0+$/, '');
  if (trimmed.endsWith('.')) {
    trimmed = trimmed.substring(0, trimmed.length - 1);
  }
  return trimmed;
}
