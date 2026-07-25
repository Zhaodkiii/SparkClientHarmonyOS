import { SupportAPIResponseDecoder } from '../../Projects/Core/Networking/API/Common/SupportAPIResponseDecoder';
import {
  FileDownloadUrlPayload,
  FileRegistrationBody,
  ManagedFileRecord
} from './FileStorageModels';

type JsonRec = Record<string, Object | string | number | boolean | null>;

/**
 * SparkService file_manager / OSS STS 解码。
 * 兼容 snake_case 与 camelCase；未知字段忽略。
 */
export class FileStorageDecode {
  static decodeRecord(data: Object | null): ManagedFileRecord {
    const obj = SupportAPIResponseDecoder.asRecord(data);
    const r = new ManagedFileRecord();
    r.id = SupportAPIResponseDecoder.numAny(obj, ['id'], 0);
    r.fileUuid = SupportAPIResponseDecoder.strAny(obj, ['fileUuid', 'file_uuid'], '');
    r.filePath = SupportAPIResponseDecoder.strAny(obj, ['filePath', 'file_path'], '');
    r.originalName = SupportAPIResponseDecoder.strAny(obj, ['originalName', 'original_name'], '');
    r.fileSize = SupportAPIResponseDecoder.numAny(obj, ['fileSize', 'file_size'], 0);
    r.mimeType = SupportAPIResponseDecoder.strAny(obj, ['mimeType', 'mime_type'], 'application/octet-stream');
    r.fileMd5 = SupportAPIResponseDecoder.strAny(obj, ['fileMd5', 'file_md5'], '').toLowerCase();
    r.isPublic = SupportAPIResponseDecoder.boolAny(obj, ['isPublic', 'is_public'], false);
    r.businessType = SupportAPIResponseDecoder.strAny(obj, ['businessType', 'business_type'], '');
    r.businessId = SupportAPIResponseDecoder.strAny(obj, ['businessId', 'business_id'], '');
    r.objectKey = SupportAPIResponseDecoder.strAny(obj, ['objectKey', 'object_key'], '');
    r.storageType = SupportAPIResponseDecoder.strAny(obj, ['storageType', 'storage_type'], 'oss');
    r.createdAt = SupportAPIResponseDecoder.strAny(obj, ['createdAt', 'created_at'], '');
    return r;
  }

  static decodeList(data: Object | null): ManagedFileRecord[] {
    const out: ManagedFileRecord[] = [];
    if (!data) {
      return out;
    }
    if (Array.isArray(data)) {
      const arr = data as Object[];
      for (let i = 0; i < arr.length; i++) {
        const item = arr[i];
        if (item && typeof item === 'object') {
          out.push(FileStorageDecode.decodeRecord(item));
        }
      }
      return out;
    }
    const obj = SupportAPIResponseDecoder.asRecord(data);
    const nested = obj['results'] ?? obj['items'] ?? obj['files'];
    if (Array.isArray(nested)) {
      return FileStorageDecode.decodeList(nested as Object);
    }
    return out;
  }

  static decodeDownloadUrl(data: Object | null): FileDownloadUrlPayload {
    const obj = SupportAPIResponseDecoder.asRecord(data);
    const payload = new FileDownloadUrlPayload();
    payload.url = SupportAPIResponseDecoder.strAny(obj, ['url'], '');
    return payload;
  }

  static decodeDeleteId(data: Object | null): number {
    const obj = SupportAPIResponseDecoder.asRecord(data);
    return SupportAPIResponseDecoder.numAny(obj, ['id'], 0);
  }

  static toRegisterBody(
    fileUuid: string,
    originalName: string,
    fileSize: number,
    mimeType: string,
    objectKey: string,
    businessType: string,
    businessId: string,
    isPublic: boolean,
    fileMd5: string
  ): FileRegistrationBody {
    const body = new FileRegistrationBody();
    body.file_uuid = fileUuid;
    body.original_name = originalName;
    body.file_size = fileSize;
    body.mime_type = mimeType;
    body.file_path = objectKey;
    body.object_key = objectKey;
    body.storage_type = 'oss';
    body.business_type = businessType;
    body.business_id = businessId;
    body.is_public = isPublic;
    body.file_md5 = fileMd5;
    return body;
  }

  static assertRegisterMatches(
    record: ManagedFileRecord,
    expectedUuid: string,
    expectedObjectKey: string
  ): boolean {
    if (record.id <= 0) {
      return false;
    }
    if (record.fileUuid.length === 0 || record.fileUuid !== expectedUuid) {
      return false;
    }
    if (record.objectKey.length === 0 || record.objectKey !== expectedObjectKey) {
      return false;
    }
    return true;
  }

  /** 供单测：从任意 JSON 对象取字符串字段 */
  static peekStr(obj: JsonRec, keys: string[]): string {
    return SupportAPIResponseDecoder.strAny(obj, keys, '');
  }
}
