import { fileIo as fs } from '@kit.CoreFileKit';

const IMAGE_EXTENSIONS: string[] = ['png', 'jpg', 'jpeg', 'heic', 'webp', 'gif', 'bmp'];

/**
 * 统一文件预览输入模型。对齐 iOS `FilePreviewInput`：
 * 与业务无关，聊天/医疗等场景共用。
 */
export class FilePreviewInput {
  id: string = '';
  fileURL: string = '';
  displayName?: string = undefined;
  mimeType?: string = undefined;
  utTypeIdentifier?: string = undefined;

  static create(
    fileURL: string,
    displayName?: string,
    mimeType?: string,
    id?: string
  ): FilePreviewInput {
    const input = new FilePreviewInput();
    input.id = id && id.length > 0 ? id : `preview_${Date.now()}_${Math.random()}`;
    input.fileURL = fileURL;
    input.displayName = displayName;
    input.mimeType = mimeType;
    return input;
  }

  resolvedDisplayName(): string {
    const named = (this.displayName ?? '').trim();
    if (named.length > 0) {
      return named;
    }
    const path = this.fileURL.trim();
    if (path.length === 0) {
      return '文件';
    }
    const slash = Math.max(path.lastIndexOf('/'), path.lastIndexOf('\\'));
    const filename = slash >= 0 ? path.slice(slash + 1) : path;
    return filename.length > 0 ? filename : '文件';
  }

  private fileExtension(): string {
    const name = this.resolvedDisplayName();
    const dot = name.lastIndexOf('.');
    if (dot < 0) {
      return '';
    }
    return name.slice(dot + 1).toLowerCase();
  }

  isImageType(): boolean {
    const mime = (this.mimeType ?? '').toLowerCase();
    if (mime.indexOf('image/') === 0) {
      return true;
    }
    return IMAGE_EXTENSIONS.indexOf(this.fileExtension()) >= 0;
  }

  isPdfType(): boolean {
    const mime = (this.mimeType ?? '').toLowerCase();
    if (mime.indexOf('pdf') >= 0) {
      return true;
    }
    return this.fileExtension() === 'pdf';
  }

  /** 相册/文档选择器返回的 URI，需由 Image 直接加载，不能走 fs 路径。 */
  isContentUri(): boolean {
    const path = this.fileURL.trim();
    if (path.length === 0) {
      return false;
    }
    if (path.startsWith('datashare://') || path.startsWith('internal://')) {
      return true;
    }
    if (path.startsWith('file://') && !path.startsWith('file:///')) {
      return true;
    }
    return false;
  }

  /** 供 Image 组件使用的预览地址（保留原始 URI）。 */
  previewUri(): string {
    return this.fileURL.trim();
  }

  isLocalFileAvailable(): boolean {
    const path = this.fileURL.trim();
    if (path.length === 0) {
      return false;
    }
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return true;
    }
    if (this.isContentUri()) {
      return true;
    }
    const localPath = this.localFilePath();
    if (localPath.length === 0) {
      return false;
    }
    try {
      fs.statSync(localPath);
      return true;
    } catch (_e) {
      return false;
    }
  }

  localFilePath(): string {
    const path = this.fileURL.trim();
    if (this.isContentUri()) {
      return path;
    }
    if (path.startsWith('file://')) {
      return path.replace('file://', '');
    }
    return path;
  }
}
