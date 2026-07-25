import { ChatMessageBlock } from '../Domain/ChatModels';

export class ChatTimelineNode {
  id: string = '';
  blocks: ChatMessageBlock[] = [];
  isHealthResourceGroup: boolean = false;
  isToolGroup: boolean = false;
}

/** 对齐 iOS ChatMessageTimelineProjector：工具块归并，用户连续健康资源引用分组。 */
export class ChatTimelineProjector {
  static project(blocks: ChatMessageBlock[], isUser: boolean): ChatTimelineNode[] {
    const sorted = blocks.slice().sort((a: ChatMessageBlock, b: ChatMessageBlock): number => {
      if (a.orderKey !== b.orderKey) return a.orderKey - b.orderKey;
      if (a.createdAt !== b.createdAt) return a.createdAt < b.createdAt ? -1 : 1;
      return a.blockId < b.blockId ? -1 : 1;
    });
    const nodes: ChatTimelineNode[] = [];
    const toolIndexes = new Map<string, number>();
    for (let i = 0; i < sorted.length; i++) {
      const block = sorted[i];
      if (isUser && block.kind === 'healthResourceReference') {
        const group = new ChatTimelineNode(); group.id = block.blockId; group.isHealthResourceGroup = true; group.blocks.push(block);
        while (i + 1 < sorted.length && sorted[i + 1].kind === 'healthResourceReference') { i++; group.blocks.push(sorted[i]); }
        nodes.push(group); continue;
      }
      const callID = block.toolCallId || block.parentToolCallId || '';
      if ((block.nodeRole === 'tool' || block.nodeRole === 'toolPresentation') && callID.length > 0) {
        let index = toolIndexes.get(callID);
        if (index === undefined) { const group = new ChatTimelineNode(); group.id = block.blockId; group.isToolGroup = true; nodes.push(group); index = nodes.length - 1; toolIndexes.set(callID, index); }
        nodes[index].blocks.push(block); continue;
      }
      const node = new ChatTimelineNode(); node.id = block.blockId; node.blocks.push(block); nodes.push(node);
    }
    return nodes;
  }
}
