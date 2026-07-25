import { ComposerTheme } from './Models/ComposerTheme';
import { SparkPromptInputDrawerSheet } from './SparkPromptInputDrawerSheet';

/**
 * 自适应高度输入框，对标 iOS HanlinChatTextView。
 * ArkUI TextArea 原生支持约束高度，触顶后可展开抽屉。
 */
@Component
export struct HanlinChatTextView {
  @Link text: string;
  @Prop minimumHeight: number = 44;
  @Prop maximumHeight: number = 160;
  @Prop isSending: boolean = false;
  @Prop placeholder: string = '请输入你的问题';
  @State private reachedScrollThreshold: boolean = false;
  @State private inputExpandedSheet: boolean = false;

  build() {
    Row({ space: 8 }) {
      Stack({ alignContent: Alignment.TopStart }) {
        TextArea({ text: this.text, placeholder: this.placeholder })
          .layoutWeight(1)
          .fontSize(18)
          .fontColor(ComposerTheme.textPrimary)
          .placeholderColor(ComposerTheme.textSecondary)
          .backgroundColor(Color.Transparent)
          .padding(0)
          .constraintSize({ minHeight: this.minimumHeight, maxHeight: this.maximumHeight })
          .enabled(!this.isSending)
          .onChange((value: string) => {
            this.text = value;
          })
          .onAreaChange((_oldArea: Area, newArea: Area) => {
            const h = Number(newArea.height);
            this.reachedScrollThreshold = h >= this.maximumHeight - 1;
          })
      }
      .layoutWeight(1)

      if (this.reachedScrollThreshold) {
        Text(this.inputExpandedSheet ? '⌄' : '⌃')
          .fontSize(16)
          .fontColor(ComposerTheme.gray)
          .margin({ right: 8, top: 6 })
          .opacity(this.isSending ? 0.5 : 1)
          .onClick(() => {
            if (!this.isSending) {
              this.inputExpandedSheet = true;
            }
          })
      }
    }
    .alignItems(VerticalAlign.Top)
    .bindSheet(this.inputExpandedSheet, this.expandedDrawerBuilder(), {
      height: SheetSize.LARGE,
      dragBar: true,
      onDisappear: () => {
        this.inputExpandedSheet = false;
      }
    })
  }

  @Builder
  private expandedDrawerBuilder() {
    SparkPromptInputDrawerSheet({
      text: $text,
      onClose: () => {
        this.inputExpandedSheet = false;
      }
    })
  }
}
