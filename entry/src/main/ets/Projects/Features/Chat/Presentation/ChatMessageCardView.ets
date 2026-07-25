import { ChatMessageBlock } from '../Domain/ChatModels';
import { ChatBlockPresentation } from './ChatPresentationModels';
import { Markdown, MarkdownController } from '@luvi/lv-markdown-in';

@Component
export struct ChatMessageCardView {
  @Prop block: ChatMessageBlock;
  @Prop isUser: boolean;
  onOpenToolDetail: (block: ChatMessageBlock) => void = (_b: ChatMessageBlock) => {};
  @State private expanded: boolean = false;
  private markdownController: MarkdownController = new MarkdownController();

  aboutToAppear(): void {
    this.markdownController.setTextColor(this.isUser ? '#FFFFFF' : '#20252B');
    this.markdownController.setTextSize(this.isCard() ? 14 : 16);
    this.markdownController.setTextLineHeight(this.isCard() ? 21 : 24);
    this.markdownController.setTextSelectionEnable(true);
  }

  private isCard(): boolean {
    return this.block.kind !== 'text' && this.block.kind !== 'deepThought';
  }

  private bodyText(): string {
    if (this.block.text.length > 0) return this.block.text;
    if (this.block.status === 'pending' || this.block.status === 'streaming') return '正在准备内容…';
    if (this.block.status === 'failed') return '内容生成失败，请稍后重试';
    return this.block.kind === 'tool' ? '正在调用工具…' : '已生成结构化内容';
  }

  private cardTitle(): string { return ChatBlockPresentation.from(this.block).title; }
  private cardAccent(): string { return ChatBlockPresentation.from(this.block).accent; }

  build() {
    Column() {
      if (!this.isCard()) {
        Markdown({ controller: this.markdownController, text: this.bodyText() })
          .width('100%')
      } else {
        Row() {
          Text(this.cardTitle()).fontSize(13).fontWeight(FontWeight.Medium).fontColor(this.cardAccent()).layoutWeight(1)
          if (this.block.status === 'pending' || this.block.status === 'streaming') {
            Text('处理中').fontSize(11).fontColor('#8A6B35')
          }
        }
        .width('100%')
        .margin({ bottom: 8 })
        Markdown({ controller: this.markdownController, text: this.bodyText() })
          .width('100%')
        if (this.bodyText().length > 120) {
          Text(this.expanded ? '收起' : '展开').fontSize(12).fontColor('#3973B9').margin({ top: 6 })
            .onClick(() => { this.expanded = !this.expanded; })
        }
      }
    }
    .width('100%')
    .padding(this.isCard() ? 14 : 0)
    .backgroundColor(this.isCard() ? '#F7FAFC' : '#00000000')
    .borderRadius(this.isCard() ? 14 : 0)
    .border(this.isCard() ? { width: 1, color: '#E5EDF5' } : { width: 0, color: '#00000000' })
    .onClick(() => {
      if (this.block.kind === 'tool' || this.block.kind === 'toolPresentation') {
        this.onOpenToolDetail(this.block);
      }
    })
  }
}
