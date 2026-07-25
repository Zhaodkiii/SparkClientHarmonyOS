import { ComposerTheme } from './Models/ComposerTheme';
import { picker } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';

/** Prompt 输入抽屉，对标 iOS SparkPromptInputDrawerSheet。 */
@Component
export struct SparkPromptInputDrawerSheet {
  @Link text: string;
  onClose: () => void = () => {};
  onAutoFill: (() => Promise<string>) | undefined = undefined;
  onPolish: (() => Promise<string>) | undefined = undefined;
  onTranslate: (() => Promise<string>) | undefined = undefined;
  onOCRImage: ((imagePath: string) => Promise<string>) | undefined = undefined;

  @State private isAutoFilling: boolean = false;
  @State private isPolishing: boolean = false;
  @State private isTranslating: boolean = false;
  @State private isOCRRecognizing: boolean = false;
  @State private originalText: string = '';
  @State private processedText: string = '';
  @State private actionError: string = '';
  @State private showOCRSourceOptions: boolean = false;
  @State private showLinkInputRow: boolean = false;
  @State private linkText: string = '';

  private tokenEstimate(): number {
    return estimateTokens(this.text);
  }

  private isBusyActionRunning(): boolean {
    return this.isAutoFilling || this.isPolishing || this.isTranslating || this.isOCRRecognizing;
  }

  build() {
    Column({ space: 12 }) {
      TextArea({ text: this.text, placeholder: '在此编辑完整提示词…' })
        .layoutWeight(1)
        .width('100%')
        .fontSize(16)
        .fontColor(ComposerTheme.textPrimary)
        .backgroundColor(Color.Transparent)
        .onChange((value: string) => {
          this.text = value;
        })

      if (this.actionError.length > 0) {
        Text(this.actionError)
          .fontSize(12)
          .fontColor(ComposerTheme.systemRed)
          .width('100%')
      }

      this.bottomToolbar()
    }
    .padding(12)
    .backgroundColor(ComposerTheme.systemGray6)
    .width('100%')
    .height('100%')
  }

  @Builder
  private bottomToolbar() {
    Column({ space: 10 }) {
      if (this.showLinkInputRow) {
        this.linkInputRow()
      }

      Row({ space: 8 }) {
        if (this.onAutoFill) {
          this.processingButton(
            this.processedText === this.text && this.text.length > 0 ? '↺' : '✦',
            this.isAutoFilling,
            () => this.runAutoFill()
          )
        }
        if (this.onPolish) {
          this.processingButton(
            this.processedText === this.text && this.text.length > 0 ? '↺' : '✎',
            this.isPolishing,
            () => this.runPolish()
          )
        }
        if (this.onTranslate) {
          this.processingButton(
            this.processedText === this.text && this.text.length > 0 ? '↺' : '文',
            this.isTranslating,
            () => this.runTranslate()
          )
        }
        if (this.onOCRImage) {
          this.processingButton('▣', this.isOCRRecognizing, () => this.toggleOCRSources())
        }

        this.toolbarButton('🔗', () => this.toggleLinkRow())
        this.toolbarButton('⌫', () => this.clearText())
        this.toolbarButton('⌄', () => this.onClose())

        Blank()

        Column({ space: 2 }) {
          Text(`${this.text.length} 字`).fontSize(11).fontColor(ComposerTheme.textSecondary)
          Text(`约 ${this.tokenEstimate()} tokens`).fontSize(11).fontColor(ComposerTheme.textSecondary)
        }
        .alignItems(HorizontalAlign.End)
        .opacity(0.8)
      }
      .alignItems(VerticalAlign.Center)

      if (this.showOCRSourceOptions) {
        this.ocrSourceSelector()
      }
    }
    .padding(12)
    .backgroundColor(ComposerTheme.materialSoft)
    .borderRadius(26)
    .shadow({ radius: 1, color: ComposerTheme.withOpacity(ComposerTheme.accent, 0.18) })
    .animation({ duration: 350, curve: Curve.Friction })
  }

  @Builder
  private ocrSourceSelector() {
    Row({ space: 6 }) {
      this.sourceButton('◎', '拍照', () => {
        this.actionError = '相机 OCR 待接入 CameraKit';
      })
      this.sourceButton('▣', '相册', () => {
        this.presentPhotoLibrary();
      })
    }
  }

  @Builder
  private linkInputRow() {
    Row({ space: 8 }) {
      TextInput({ placeholder: '粘贴链接', text: this.linkText })
        .type(InputType.URL)
        .layoutWeight(1)
        .onChange((value: string) => {
          this.linkText = value;
        })

      Text('+')
        .fontSize(22)
        .fontColor(ComposerTheme.accent)
        .width(28)
        .height(28)
        .textAlign(TextAlign.Center)
        .opacity(this.linkText.trim().length === 0 ? 0.4 : 1)
        .onClick(() => {
          if (this.linkText.trim().length > 0) {
            this.appendLink();
          }
        })
    }
  }

  @Builder
  private sourceButton(icon: string, title: string, action: () => void) {
    Column({ space: 6 }) {
      Text(icon).fontSize(22).fontColor(ComposerTheme.accent)
      Text(title)
        .fontSize(12)
        .fontWeight(FontWeight.Bold)
        .fontColor(ComposerTheme.accent)
        .maxLines(1)
    }
    .layoutWeight(1)
    .padding(12)
    .backgroundColor(ComposerTheme.withOpacity(ComposerTheme.accent, 0.1))
    .borderRadius(20)
    .onClick(() => action())
  }

  @Builder
  private processingButton(icon: string, isBusy: boolean, action: () => void) {
    if (isBusy) {
      LoadingProgress().width(36).height(36)
    } else {
      Text(icon)
        .fontSize(20)
        .fontColor(ComposerTheme.gray)
        .width(36)
        .height(36)
        .textAlign(TextAlign.Center)
        .opacity(this.isBusyActionRunning() ? 0.5 : 1)
        .onClick(() => {
          if (!this.isBusyActionRunning()) {
            action();
          }
        })
    }
  }

  @Builder
  private toolbarButton(icon: string, action: () => void) {
    Text(icon)
      .fontSize(18)
      .fontColor(ComposerTheme.gray)
      .width(36)
      .height(36)
      .textAlign(TextAlign.Center)
      .opacity(this.isBusyActionRunning() ? 0.5 : 1)
      .onClick(() => {
        if (!this.isBusyActionRunning()) {
          action();
        }
      })
  }

  private runAutoFill(): void {
    if (!this.onAutoFill) {
      return;
    }
    this.runTextAction(() => this.onAutoFill!(), (busy: boolean) => {
      this.isAutoFilling = busy;
    });
  }

  private runPolish(): void {
    if (!this.onPolish) {
      return;
    }
    this.runTextAction(() => this.onPolish!(), (busy: boolean) => {
      this.isPolishing = busy;
    });
  }

  private runTranslate(): void {
    if (!this.onTranslate) {
      return;
    }
    this.runTextAction(() => this.onTranslate!(), (busy: boolean) => {
      this.isTranslating = busy;
    });
  }

  private runTextAction(work: () => Promise<string>, setBusy: (busy: boolean) => void): void {
    if (this.processedText === this.text && this.originalText.length > 0) {
      this.text = this.originalText;
      this.processedText = '';
      return;
    }
    this.originalText = this.text;
    setBusy(true);
    work().then((raw: string) => {
      const result = raw.trim();
      if (result.length > 0) {
        this.text = result;
        this.processedText = result;
      }
      setBusy(false);
    }).catch((err: Error) => {
      this.actionError = err.message ?? '处理失败';
      setBusy(false);
    });
  }

  private toggleOCRSources(): void {
    this.showOCRSourceOptions = !this.showOCRSourceOptions;
    if (this.showOCRSourceOptions) {
      this.showLinkInputRow = false;
    }
  }

  private toggleLinkRow(): void {
    this.showLinkInputRow = !this.showLinkInputRow;
    if (this.showLinkInputRow) {
      this.showOCRSourceOptions = false;
    }
  }

  private async presentPhotoLibrary(): Promise<void> {
    try {
      const context = getContext(this) as common.UIAbilityContext;
      const photoSelectOptions = new picker.PhotoSelectOptions();
      photoSelectOptions.MIMEType = picker.PhotoViewMIMETypes.IMAGE_TYPE;
      photoSelectOptions.maxSelectNumber = 1;
      const photoPicker = new picker.PhotoViewPicker(context);
      const result = await photoPicker.select(photoSelectOptions);
      if (result && result.photoUris.length > 0) {
        this.runOCR(result.photoUris[0]);
        this.showOCRSourceOptions = false;
      }
    } catch (_e) {
      // 用户取消
    }
  }

  private runOCR(imagePath: string): void {
    if (!this.onOCRImage) {
      this.actionError = 'OCR 回调未接入';
      return;
    }
    this.isOCRRecognizing = true;
    this.showOCRSourceOptions = false;
    this.onOCRImage(imagePath).then((raw: string) => {
      const result = raw.trim();
      if (result.length > 0) {
        this.appendBlock(result);
      }
      this.isOCRRecognizing = false;
    }).catch((err: Error) => {
      this.actionError = err.message ?? 'OCR 失败';
      this.isOCRRecognizing = false;
    });
  }

  private appendLink(): void {
    const trimmed = this.linkText.trim();
    if (trimmed.length === 0) {
      return;
    }
    this.appendBlock(trimmed);
    this.linkText = '';
    this.showLinkInputRow = false;
  }

  private appendBlock(value: string): void {
    if (this.text.trim().length === 0) {
      this.text = value;
    } else {
      this.text = `${this.text}\n${value}`;
    }
    this.processedText = '';
  }

  private clearText(): void {
    this.text = '';
    this.processedText = '';
    this.originalText = '';
  }
}

function estimateTokens(text: string): number {
  const parts = text.split(/[\s,.!?;:，。！？；：]+/);
  let count = 0;
  for (let i = 0; i < parts.length; i++) {
    if (parts[i].length > 0) {
      count += 1;
    }
  }
  return Math.max(1, Math.ceil(count * 1.2));
}
