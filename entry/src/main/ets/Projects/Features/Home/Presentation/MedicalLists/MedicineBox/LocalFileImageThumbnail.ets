import { image } from '@kit.ImageKit';
import { fileIo as fs } from '@kit.CoreFileKit';

/**
 * 对齐 iOS `LocalFileImageThumbnail`：
 * 异步解码本地路径为 PixelMap，避免阻塞列表滚动主路径过久。
 */
@Component
export struct LocalFileImageThumbnail {
  @Prop @Watch('onFilePathChanged') filePath: string = '';
  @State private pixelMap?: image.PixelMap = undefined;
  @State private loadFailed: boolean = false;
  private requestToken: number = 0;

  aboutToAppear(): void {
    this.load();
  }

  private onFilePathChanged(): void {
    this.pixelMap = undefined;
    this.loadFailed = false;
    this.load();
  }

  build() {
    Stack() {
      if (this.filePath.indexOf('://') >= 0) {
        Image(this.filePath)
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Cover)
      } else if (this.pixelMap) {
        Image(this.pixelMap)
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Cover)
      } else {
        Column() {
          if (!this.loadFailed) {
            LoadingProgress()
              .width(20)
              .height(20)
          } else {
            SymbolGlyph($r('sys.symbol.doc_text'))
              .fontSize(18)
              .fontColor(['#8E8E93'])
          }
        }
        .width('100%')
        .height('100%')
        .backgroundColor('#F2F2F7')
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
      }
    }
  }

  private load(): void {
    const path = this.filePath;
    if (!path || path.length === 0) {
      return;
    }
    if (path.indexOf('://') >= 0) {
      return;
    }
    this.requestToken += 1;
    const token = this.requestToken;
    this.decode(path).then((result: image.PixelMap | undefined) => {
      if (token !== this.requestToken) {
        return;
      }
      if (result) {
        this.pixelMap = result;
      } else {
        this.loadFailed = true;
      }
    }).catch(() => {
      if (token === this.requestToken) {
        this.loadFailed = true;
      }
    });
  }

  private async decode(path: string): Promise<image.PixelMap | undefined> {
    let file: fs.File | undefined = undefined;
    try {
      file = fs.openSync(path, fs.OpenMode.READ_ONLY);
      const imageSource = image.createImageSource(file.fd);
      const pixelMap = await imageSource.createPixelMap();
      await imageSource.release();
      return pixelMap;
    } catch (_e) {
      return undefined;
    } finally {
      if (file) {
        try {
          fs.closeSync(file);
        } catch (_closeErr) {
          // ignore
        }
      }
    }
  }
}
