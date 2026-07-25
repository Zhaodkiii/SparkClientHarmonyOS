import { RemoteManagedFile } from '../../../../../Core/Networking/API/Medical/MedicalSyncAPI';
import { FileTransferService } from '../../../../../../Core/FileStorage/FileTransferService';
import { FileDownloadOptions } from '../../../../../../Core/FileStorage/FileStorageModels';
import { isMedicationImageLike, toManagedFileRecord } from './MedicalFileUtils';
import { LocalFileImageThumbnail } from './LocalFileImageThumbnail';

/**
 * 对齐 iOS `MedicationImageGlyph`：
 * seed 决定占位符号色；有图片附件则缓存/下载后圆形覆盖。
 */
@Component
export struct MedicationImageGlyph {
  @Prop @Watch('onSeedOrAttachmentChanged') seed: number = 0;
  @Prop @Watch('onSeedOrAttachmentChanged') attachmentId: number = 0;
  attachment?: RemoteManagedFile;
  fileTransferService?: FileTransferService;

  @State private localImagePath: string = '';
  @State private isLoadingImage: boolean = false;
  private requestToken: number = 0;

  aboutToAppear(): void {
    this.loadAttachmentThumbnail();
  }

  private onSeedOrAttachmentChanged(): void {
    this.loadAttachmentThumbnail();
  }

  private symbolColor(): string {
    switch (this.seed % 4) {
      case 0:
        return '#007AFF';
      case 1:
        return '#34C759';
      case 2:
        return '#5856D6';
      default:
        return '#5AC8FA';
    }
  }

  private symbolResource(): Resource {
    // 仅使用工程内已验证可用的 sys.symbol，避免编译期 Unknown resource
    switch (this.seed % 4) {
      case 0:
        return $r('sys.symbol.heart_fill');
      case 1:
        return $r('sys.symbol.checkmark_circle_fill');
      case 2:
        return $r('sys.symbol.square_stack_3d');
      default:
        return $r('sys.symbol.star_fill');
    }
  }

  private withAlpha(hex: string, alpha: number): string {
    const a = Math.round(alpha * 255).toString(16).padStart(2, '0');
    return `${hex}${a}`;
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Circle()
        .fill(this.withAlpha(this.symbolColor(), 0.16))
        .width('100%')
        .height('100%')

      if (this.localImagePath.length > 0) {
        LocalFileImageThumbnail({ filePath: this.localImagePath })
          .width('100%')
          .height('100%')
          .borderRadius('50%')
          .clip(true)
      } else {
        SymbolGlyph(this.symbolResource())
          .fontSize(28)
          .fontColor([this.symbolColor()])
      }

      if (this.isLoadingImage) {
        LoadingProgress()
          .width(22)
          .height(22)
          .color(this.symbolColor())
      }
    }
    .aspectRatio(1)
  }

  private async loadAttachmentThumbnail(): Promise<void> {
    this.localImagePath = '';
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
        this.localImagePath = cached.localPath;
        return;
      }
      this.isLoadingImage = true;
      const options = new FileDownloadOptions();
      options.expectedMd5 = managed.fileMd5;
      const handle = await transfer.download(managed, options);
      if (token !== this.requestToken) {
        return;
      }
      this.localImagePath = handle.localPath;
    } catch (_e) {
      // 下载失败保留占位符，对齐 iOS try?
    } finally {
      if (token === this.requestToken) {
        this.isLoadingImage = false;
      }
    }
  }
}
