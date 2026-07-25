import { webview } from '@kit.ArkWeb';
import { LegalUrls } from '../../../../App/LegalAcceptanceStore';

@Component
export struct LegalWebPage {
  @Prop docType: string = 'terms';
  @Prop titleText: string = '';
  onClose?: () => void;
  @State loadFailed: boolean = false;
  private controller: webview.WebviewController = new webview.WebviewController();

  private pageUrl(): string {
    return LegalUrls.urlFor(this.docType);
  }

  build() {
    NavDestination() {
      Column() {
        Row() {
          Button($r('app.string.auth_legal_web_close'))
            .type(ButtonType.Normal)
            .onClick(() => {
              if (this.onClose) {
                this.onClose();
              }
            })
          Text(this.titleText.length > 0 ? this.titleText : $r('app.string.auth_legal_terms'))
            .fontSize(17)
            .fontWeight(FontWeight.Medium)
            .layoutWeight(1)
            .textAlign(TextAlign.Center)
          Blank().width(64)
        }
        .width('100%')
        .height(52)
        .padding({ left: 12, right: 12 })

        if (this.loadFailed) {
          Column({ space: 12 }) {
            Text($r('app.string.auth_legal_web_failed'))
              .fontSize(14)
              .fontColor($r('sys.color.font_secondary'))
            Button($r('app.string.auth_legal_web_retry'))
              .onClick(() => {
                this.loadFailed = false;
                try {
                  this.controller.loadUrl(this.pageUrl());
                } catch (_e) {
                  this.loadFailed = true;
                }
              })
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
        } else {
          Web({ src: this.pageUrl(), controller: this.controller })
            .width('100%')
            .layoutWeight(1)
            .javaScriptAccess(true)
            .fileAccess(false)
            .onHttpErrorReceive(() => {
              this.loadFailed = true;
            })
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor(Color.White)
    }
    .hideTitleBar(true)
    .backgroundColor(Color.White)
  }
}
