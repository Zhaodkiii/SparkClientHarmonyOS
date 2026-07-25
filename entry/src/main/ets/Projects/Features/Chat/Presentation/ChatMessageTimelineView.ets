import { ChatMessageBlock } from '../Domain/ChatModels';
import { ChatMessageCardView } from './ChatMessageCardView';
import { ChatTimelineNode, ChatTimelineProjector } from './ChatTimelineProjector';

@Component
export struct ChatMessageTimelineView {
  @Prop blocks: ChatMessageBlock[];
  @Prop isUser: boolean;
  onOpenToolDetail: (block: ChatMessageBlock) => void = (_b: ChatMessageBlock) => {};

  build() {
    Column() {
      ForEach(ChatTimelineProjector.project(this.blocks, this.isUser), (node: ChatTimelineNode) => {
        Column() {
          if (node.isHealthResourceGroup) {
            Text('健康资料引用').fontSize(12).fontColor('#3973B9').margin({ bottom: 6 })
          }
          ForEach(node.blocks, (block: ChatMessageBlock) => {
            ChatMessageCardView({
              block: block,
              isUser: this.isUser,
              onOpenToolDetail: (b: ChatMessageBlock) => this.onOpenToolDetail(b)
            }).margin({ top: 6 })
          }, (block: ChatMessageBlock) => `${block.blockId}_${block.revision}`)
        }
        .width('100%')
        .margin({ top: 4 })
      }, (node: ChatTimelineNode) => node.id)
    }.width('100%')
  }
}
