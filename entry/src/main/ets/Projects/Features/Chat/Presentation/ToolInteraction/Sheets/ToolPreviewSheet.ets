import { ToolPreviewPrompt } from '../Models/ToolPreviewPrompt';

@Component
export struct ToolPreviewSheet {
  @Prop prompt: ToolPreviewPrompt = new ToolPreviewPrompt();
  onClose: () => void = () => {};

  private argumentsText(): string {
    if (!this.prompt.toolArguments) {
      return '无';
    }
    const text = ToolPreviewPrompt.displayText(this.prompt.toolArguments);
    return text.length > 0 ? text : '无';
  }

  build() {
    Column({ space: 12 }) {
      Text('工具详情')
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .width('100%')
      Text(`工具：${this.prompt.toolName}`)
        .fontSize(14)
        .width('100%')
      if (this.prompt.toolCallID) {
        Text(`Call ID：${this.prompt.toolCallID}`)
          .fontSize(12)
          .fontColor('#666666')
          .width('100%')
      }
      Text('参数')
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .width('100%')
      Text(this.argumentsText())
        .fontSize(13)
        .fontColor('#333333')
        .width('100%')
      Text('输出')
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .width('100%')
      Scroll() {
        Text(this.prompt.toolContent.length > 0 ? this.prompt.toolContent : '无输出')
          .fontSize(13)
          .width('100%')
      }
      .layoutWeight(1)
      .width('100%')
      Button('关闭')
        .width('100%')
        .onClick(() => this.onClose())
    }
    .padding(16)
    .width('100%')
    .height('100%')
  }
}
