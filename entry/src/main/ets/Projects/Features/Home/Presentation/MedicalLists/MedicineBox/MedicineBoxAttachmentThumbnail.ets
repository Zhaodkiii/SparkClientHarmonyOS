import { RemoteManagedFile } from '../../../../../Core/Networking/API/Medical/MedicalSyncAPI';
import { FileTransferService } from '../../../../../../Core/FileStorage/FileTransferService';
import { FileDownloadOptions } from '../../../../../../Core/FileStorage/FileStorageModels';
import { isMedicationImageLike, toManagedFileRecord } from './MedicalFileUtils';
import { FilePreviewInput, MedicalDocumentFilePreviewSquareCard } from './MedicalDocumentFilePreviewSquareCard';

/**
 * 药品详情页附件缩略图格，对齐 iOS `MedicalAttachmentGridPreview` 单元格：
 * 图片附件下载/缓存后显示缩略图，非图片附件直接显示文档图标+文件名。
 */
@Component
export struct MedicineBoxAttachmentThumbnail {
  @Prop attachment: RemoteManagedFile = new RemoteManagedFile();
  fileTransferService?: FileTransferService;

  @State private localPath: string = '';
  @State private isLoading: boolean = false;
  private requestToken: number = 0;

  aboutToAppear(): void {
    this.loadThumbnail();
  }

  private previewInput(): FilePreviewInput {
    const input = new FilePreviewInput();
    input.isImage = this.localPath.length > 0;
    input.fileURL = this.localPath;
    input.resolvedDisplayName = this.attachment.originalName ?? '药品附件';
    return input;
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      MedicalDocumentFilePreviewSquareCard({
        item: this.previewInput(),
        showDelete: false
      })

      if (this.isLoading) {
        LoadingProgress().width(20).height(20)
      }
    }
  }

  private async loadThumbnail(): Promise<void> {
    const attachment = this.attachment;
    const transfer = this.fileTransferService;
    if (!attachment || !isMedicationImageLike(attachment) || !transfer) {
      return;
    }
    const managed = toManagedFileRecord(attachment);
    if (!managed) {
      return;
    }

    this.requestToken += 1;
    const token = this.requestToken;
    try {
      const cached = await transfer.cachedURL(managed, managed.fileMd5);
      if (token !== this.requestToken) {
        return;
      }
      if (cached && cached.localPath.length > 0) {
        this.localPath = cached.localPath;
        return;
      }
      this.isLoading = true;
      const options = new FileDownloadOptions();
      options.expectedMd5 = managed.fileMd5;
      const handle = await transfer.download(managed, options);
      if (token !== this.requestToken) {
        return;
      }
      this.localPath = handle.localPath;
    } catch (_e) {
      // 下载失败保留文档图标占位，对齐 iOS try?
    } finally {
      if (token === this.requestToken) {
        this.isLoading = false;
      }
    }
  }
}
