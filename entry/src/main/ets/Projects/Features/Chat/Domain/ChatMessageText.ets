import { ChatMessage, ChatMessageBlock } from './ChatModels';

/** 从 denormalized text 或 timeline text block 取展示/落库正文。 */
export class ChatMessageText {
  static fromMessage(message: ChatMessage): string {
    const top = message.text?.trim() ?? '';
    if (top.length > 0) {
      return message.text;
    }
    return ChatMessageText.fromBlocks(message.blocks);
  }

  static fromBlocks(blocks: ChatMessageBlock[]): string {
    for (let i = 0; i < blocks.length; i++) {
      const block = blocks[i];
      if (block.kind === 'text' && block.text.trim().length > 0) {
        return block.text;
      }
    }
    return '';
  }

  /** 终态消息：有正文的 streaming/pending timeline 块纠偏为 ready。 */
  static coerceTerminalBlocks(deliveryStatus: string, blocks: ChatMessageBlock[]): ChatMessageBlock[] {
    const terminal = deliveryStatus === 'sent' || deliveryStatus === 'completed' ||
      deliveryStatus === 'read';
    if (!terminal) {
      return blocks;
    }
    for (let i = 0; i < blocks.length; i++) {
      const block = blocks[i];
      if ((block.kind === 'text' || block.kind === 'deepThought' || block.kind === 'tool') &&
        (block.status === 'streaming' || block.status === 'pending') &&
        block.text.trim().length > 0) {
        block.status = 'ready';
      }
    }
    return blocks;
  }
}
