/**
 * 上传模式选择（HOS-FILE-OSS-0008）。
 * 阈值集中配置；业务页不得自行决定 Vendor API。
 */
export type FileUploadModeKind = 'simple' | 'multipart';

export class FileUploadModeSelection {
  mode: FileUploadModeKind = 'simple';
  fileSize: number = 0;
  partSize: number = 0;
  totalParts: number = 0;
  thresholdBytes: number = FileUploadMode.SIMPLE_THRESHOLD_BYTES;
  thresholdVersion: string = FileUploadMode.THRESHOLD_VERSION;
}

export class FileUploadMode {
  /** 小文件 PutObject；大文件 Multipart。工程阈值，非官方强制。 */
  static readonly SIMPLE_THRESHOLD_BYTES: number = 8 * 1024 * 1024;
  /** 分片大小（官方 FilePath+offset+length）。 */
  static readonly PART_SIZE_BYTES: number = 5 * 1024 * 1024;
  static readonly THRESHOLD_VERSION: string = 'v1-8m-5m';

  static select(fileSize: number): FileUploadModeSelection {
    const out = new FileUploadModeSelection();
    out.fileSize = fileSize;
    out.thresholdBytes = FileUploadMode.SIMPLE_THRESHOLD_BYTES;
    out.thresholdVersion = FileUploadMode.THRESHOLD_VERSION;
    if (fileSize > FileUploadMode.SIMPLE_THRESHOLD_BYTES) {
      out.mode = 'multipart';
      out.partSize = FileUploadMode.PART_SIZE_BYTES;
      out.totalParts = FileUploadMode.computeTotalParts(fileSize, out.partSize);
    } else {
      out.mode = 'simple';
      out.partSize = 0;
      out.totalParts = 0;
    }
    return out;
  }

  static computeTotalParts(fileSize: number, partSize: number): number {
    if (fileSize <= 0 || partSize <= 0) {
      return 0;
    }
    return Math.ceil(fileSize / partSize);
  }

  static partOffset(partNumber: number, partSize: number): number {
    return (partNumber - 1) * partSize;
  }

  static partLength(fileSize: number, partNumber: number, partSize: number): number {
    const offset = FileUploadMode.partOffset(partNumber, partSize);
    if (offset >= fileSize) {
      return 0;
    }
    const remain = fileSize - offset;
    return remain < partSize ? remain : partSize;
  }

  static sizeBucket(bytes: number): string {
    if (bytes <= 0) {
      return '0';
    }
    if (bytes < 64 * 1024) {
      return 'lt64k';
    }
    if (bytes < 1024 * 1024) {
      return 'lt1m';
    }
    if (bytes < 8 * 1024 * 1024) {
      return 'lt8m';
    }
    if (bytes < 32 * 1024 * 1024) {
      return 'lt32m';
    }
    return 'gte32m';
  }

  static toLogDetail(sel: FileUploadModeSelection): string {
    const policy = sel.mode === 'multipart' ? 'multipart-v1' : 'simple-v1';
    return `mode=${sel.mode};policy=${policy};` +
      `fileSizeBucket=${FileUploadMode.sizeBucket(sel.fileSize)};` +
      `partSizeBucket=${sel.partSize > 0 ? FileUploadMode.sizeBucket(sel.partSize) : 'n'};` +
      `totalParts=${sel.totalParts};thresholdVersion=${sel.thresholdVersion}`;
  }
}