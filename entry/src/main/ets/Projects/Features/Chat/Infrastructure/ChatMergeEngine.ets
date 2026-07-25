import { ChatAttachment, ChatMessage, ChatMessageBlock } from '../Domain/ChatModels';
import { ChatMessageText } from '../Domain/ChatMessageText';
import { ChatRemoteMessageDTO } from '../../../Core/Networking/API/AI/ChatRemoteAPI';

/** 入站消息合并规则：服务端时间取胜，但保留本地尚未被后端认识的健康引用块与更强正文。 */
export class ChatMergeEngine {
  static merge(local: ChatMessage | undefined, remote: ChatMessage, rawRemote: ChatRemoteMessageDTO): ChatMessage {
    if (!local) {
      return remote;
    }
    if (ChatMergeEngine.attachmentScore(local) > ChatMergeEngine.attachmentScore(remote) && local.role === 'user') {
      remote.attachmentsJson = local.attachmentsJson;
    }
    // 远端未带回 denormalized text 时保留本地全文
    if ((!remote.text || remote.text.trim().length === 0) && local.text.trim().length > 0) {
      remote.text = local.text;
    }
    const existing = new Map<string, ChatMessageBlock>();
    for (let i = 0; i < remote.blocks.length; i++) {
      existing.set(remote.blocks[i].blockId, remote.blocks[i]);
    }
    for (let i = 0; i < local.blocks.length; i++) {
      const block = local.blocks[i];
      if (block.kind === 'healthResourceReference' && !existing.has(block.blockId)) {
        remote.blocks.push(block);
        continue;
      }
      // 本地 ready 且有正文，远端同 id 仍 streaming/空正文时保留本地块
      const remoteBlock = existing.get(block.blockId);
      if (remoteBlock && ChatMergeEngine.shouldPreferLocalBlock(block, remoteBlock)) {
        const index = remote.blocks.indexOf(remoteBlock);
        if (index >= 0) {
          remote.blocks[index] = block;
          existing.set(block.blockId, block);
        }
      }
    }
    remote.blocks.sort((a: ChatMessageBlock, b: ChatMessageBlock): number => {
      if (a.orderKey !== b.orderKey) return a.orderKey - b.orderKey;
      return a.createdAt < b.createdAt ? -1 : 1;
    });
    if (remote.text.trim().length === 0) {
      remote.text = ChatMessageText.fromBlocks(remote.blocks);
    }
    void rawRemote;
    return remote;
  }

  private static shouldPreferLocalBlock(local: ChatMessageBlock, remote: ChatMessageBlock): boolean {
    if (local.kind !== 'text' && local.kind !== 'deepThought' && local.kind !== 'tool') {
      return false;
    }
    const localReady = local.status === 'ready' && local.text.trim().length > 0;
    if (!localReady) {
      return false;
    }
    const remoteWeak = remote.status === 'streaming' || remote.status === 'pending' ||
      remote.text.trim().length === 0;
    if (remoteWeak) {
      return true;
    }
    return local.text.length > remote.text.length;
  }

  private static attachmentScore(message: ChatMessage): number {
    let raw: Object;
    try {
      raw = JSON.parse(message.attachmentsJson) as Object;
    } catch (_e) {
      return 0;
    }
    if (!Array.isArray(raw)) return 0;
    const list = raw as Object[];
    let score = 0;
    for (let i = 0; i < list.length; i++) {
      const attachment = ChatAttachment.fromJson(list[i]);
      if (attachment.url && attachment.url.startsWith('https://')) score += 8;
      if (attachment.fullCacheKey) score += 2;
      if (attachment.fileMd5) score += 2;
      if (attachment.fileId) score += 2;
      if (attachment.text) score += 1;
    }
    return score;
  }
}
