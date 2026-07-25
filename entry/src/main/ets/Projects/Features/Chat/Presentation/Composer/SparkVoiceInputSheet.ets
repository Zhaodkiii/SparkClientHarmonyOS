import { ComposerTheme } from './Models/ComposerTheme';

/**
 * 语音识别会话。完整 CoreSpeechKit 接入前提供可编译骨架：
 * - 可切换录音态与电平动画
 * - 识别文本需后续替换为 speechRecognizer 回调
 */
@Observed
export class SparkSpeechRecognizer {
  recognizedText: string = '';
  isRecording: boolean = false;
  audioLevel: number = 0.2;
  errorMessage: string = '';
  private levelTimer: number = -1;

  async requestAuthorization(): Promise<boolean> {
    // module.json5 需声明 ohos.permission.MICROPHONE；此处先返回 true 以便 UI 联调。
    return true;
  }

  async startRecording(): Promise<void> {
    if (this.isRecording) {
      return;
    }
    this.stopRecording();
    this.recognizedText = '';
    this.errorMessage = '';
    this.isRecording = true;
    this.audioLevel = 0.25;
    this.levelTimer = setInterval(() => {
      if (!this.isRecording) {
        return;
      }
      const wave = Math.sin(Date.now() / 180) * 0.2 + 0.35;
      this.audioLevel = Math.min(1, Math.max(0.08, wave));
    }, 80);
  }

  stopRecording(): void {
    if (this.levelTimer !== -1) {
      clearInterval(this.levelTimer);
      this.levelTimer = -1;
    }
    this.isRecording = false;
    this.audioLevel = 0;
  }

  /** 联调占位：将当前草稿提示为“已听写片段”。 */
  commitPlaceholder(): void {
    if (this.recognizedText.trim().length === 0) {
      this.recognizedText = '（语音识别待接入 CoreSpeechKit）';
    }
  }
}

/** 语音输入 Sheet，对标 iOS SparkVoiceInputSheet。 */
@Component
export struct SparkVoiceInputSheet {
  @Link text: string;
  onClose: () => void = () => {};
  onPolish: (() => Promise<string>) | undefined = undefined;

  @State private speechRecognizer: SparkSpeechRecognizer = new SparkSpeechRecognizer();
  @State private isPolishing: boolean = false;
  @State private originalText: string = '';
  @State private polishedText: string = '';
  @State private actionError: string = '';
  @State private wavePhase: number = 0;
  private waveformTimer: number = -1;

  aboutToAppear(): void {
    this.speechRecognizer.requestAuthorization().then((ok: boolean) => {
      if (ok) {
        this.speechRecognizer.startRecording();
      }
    });
    this.waveformTimer = setInterval(() => {
      if (this.speechRecognizer.isRecording) {
        this.wavePhase += 0.15;
      }
    }, 60);
  }

  aboutToDisappear(): void {
    if (this.waveformTimer !== -1) {
      clearInterval(this.waveformTimer);
      this.waveformTimer = -1;
    }
    this.speechRecognizer.stopRecording();
  }

  build() {
    Column({ space: 12 }) {
      Column({ space: 8 }) {
        TextArea({ text: this.text, placeholder: '语音识别结果将追加到这里…' })
          .layoutWeight(1)
          .constraintSize({ minHeight: 120 })
          .backgroundColor(Color.Transparent)
          .onChange((value: string) => {
            this.text = value;
          })

        Scroll() {
          Text(this.speechRecognizer.recognizedText.length > 0
            ? this.speechRecognizer.recognizedText
            : (this.speechRecognizer.isRecording ? '正在聆听…' : '未开始识别'))
            .maxLines(1)
            .fontColor(ComposerTheme.accent)
            .padding({ left: 12, right: 12, top: 8, bottom: 8 })
        }
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)
      }
      .padding({ left: 12, right: 12 })
      .layoutWeight(1)

      if (this.actionError.length > 0) {
        Text(this.actionError).fontSize(12).fontColor(ComposerTheme.systemRed)
      }

      Row({ space: 16 }) {
        Text(this.speechRecognizer.isRecording ? '■' : '🎤')
          .fontSize(22)
          .fontColor(this.speechRecognizer.isRecording ? Color.Red : ComposerTheme.accent)
          .width(42)
          .height(42)
          .textAlign(TextAlign.Center)
          .opacity(this.isPolishing ? 0.5 : 1)
          .onClick(() => {
            if (!this.isPolishing) {
              this.toggleRecording();
            }
          })

        if (this.speechRecognizer.isRecording) {
          Row() {
            this.waveformBars()
          }
          .layoutWeight(1)
          .constraintSize({ minHeight: 42 })
          .alignItems(VerticalAlign.Center)
        } else {
          Blank()
        }

        if (this.onPolish && !this.speechRecognizer.isRecording) {
          if (this.isPolishing) {
            LoadingProgress().width(42).height(42)
          } else {
            Text(this.polishedText === this.text && this.text.length > 0 ? '↺' : '✎')
              .fontSize(22)
              .fontColor(ComposerTheme.accent)
              .width(42)
              .height(42)
              .textAlign(TextAlign.Center)
              .onClick(() => this.runPolish())
          }
        }

        Text('✓')
          .fontSize(22)
          .fontColor(this.speechRecognizer.isRecording ? ComposerTheme.gray : ComposerTheme.accent)
          .width(42)
          .height(42)
          .textAlign(TextAlign.Center)
          .opacity((this.isPolishing || this.speechRecognizer.isRecording) ? 0.5 : 1)
          .onClick(() => {
            if (this.isPolishing || this.speechRecognizer.isRecording) {
              return;
            }
            this.appendRecognizedText();
            this.onClose();
          })
      }
      .padding({ left: 12, right: 12 })
      .backgroundColor(ComposerTheme.materialSoft)
      .borderRadius(32)
      .shadow({ radius: 1, color: ComposerTheme.withOpacity(ComposerTheme.accent, 0.18) })
      .margin({ left: 12, right: 12 })
    }
    .padding({ top: 12, bottom: 12 })
    .backgroundColor(ComposerTheme.systemGray6)
    .width('100%')
    .height('100%')
  }

  @Builder
  private waveformBars() {
    Row({ space: 4 }) {
      ForEach(this.barIndexes(), (index: number) => {
        Column()
          .width(4)
          .height(this.barHeight(index))
          .borderRadius(2)
          .backgroundColor(ComposerTheme.accent)
      }, (index: number) => `${index}`)
    }
    .alignItems(VerticalAlign.Center)
    .height(42)
  }

  private barIndexes(): number[] {
    const values: number[] = [];
    for (let i = 0; i < 24; i++) {
      values.push(i);
    }
    return values;
  }

  private barHeight(index: number): number {
    const wave = Math.sin(index * 0.7 + this.wavePhase * 7);
    const normalized = Math.max(0.08, this.speechRecognizer.audioLevel + wave * 0.12);
    return Math.min(42, Math.max(8, normalized * 48));
  }

  private toggleRecording(): void {
    if (this.speechRecognizer.isRecording) {
      this.speechRecognizer.commitPlaceholder();
      this.speechRecognizer.stopRecording();
      this.appendRecognizedText();
    } else {
      this.speechRecognizer.startRecording();
    }
  }

  private appendRecognizedText(): void {
    const recognized = this.speechRecognizer.recognizedText.trim();
    if (recognized.length === 0) {
      return;
    }
    this.text = this.text.length === 0 ? recognized : `${this.text}\n${recognized}`;
    this.speechRecognizer.recognizedText = '';
  }

  private runPolish(): void {
    if (!this.onPolish) {
      return;
    }
    if (this.polishedText === this.text && this.originalText.length > 0) {
      this.text = this.originalText;
      this.polishedText = '';
      return;
    }
    this.originalText = this.text;
    this.isPolishing = true;
    this.onPolish().then((result: string) => {
      const trimmed = result.trim();
      if (trimmed.length > 0) {
        this.text = trimmed;
        this.polishedText = trimmed;
      }
      this.isPolishing = false;
    }).catch((err: Error) => {
      this.actionError = err.message ?? '';
      this.isPolishing = false;
    });
  }
}
