import { FileHashUtil } from '../../../Core/FileStorage/FileHashUtil';
import { FileUploadMode } from '../../../Core/FileStorage/FileUploadMode';

/**
 * OSS 诊断指纹工具（HOS-FILE-OSS-0009）。
 * 仅安全摘要，不含 PutObject/Multipart 调用。
 */
export class OSSDiagnosticFingerprint {
  static bucketFingerprint(bucketName: string): string {
    if (bucketName.length === 0) {
      return 'v1:empty:len=0';
    }
    const digest = FileHashUtil.sha256HexOfString(bucketName);
    return `v1:${digest.substring(0, 12)}:len=${bucketName.length}`;
  }

  static sizeBucket(bytes: number): string {
    return FileUploadMode.sizeBucket(bytes);
  }

  static uploadIdHash(uploadId: string): string {
    if (uploadId.length === 0) {
      return 'empty';
    }
    return FileHashUtil.sha256HexOfString(uploadId).substring(0, 16);
  }

  static etagHash(etag: string): string {
    if (etag.length === 0) {
      return '';
    }
    return FileHashUtil.sha256HexOfString(etag).substring(0, 12);
  }
}
