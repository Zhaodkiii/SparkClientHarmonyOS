import { ChatMessageBlock, ChatBlockKind } from '../Domain/ChatModels';
import { ChatStableBlockID } from '../Domain/ChatStableBlockID';
import { ChatRepository } from '../Infrastructure/ChatRepository';

export type MessageRunEffectKind =
  | 'partialText'
  | 'partialReasoning'
  | 'toolBlock'
  | 'richBlock'
  | 'assistantStatusCard'
  | 'setStatus'
  | 'finalize';

export class MessageRunEffect {
  kind: MessageRunEffectKind = 'partialText';
  accountId: number = 0;
  assistantClientId: string = '';
  generation: number = 0;
  text: string = '';
  status?: string;
  errorCode?: string;
  toolName?: string;
  toolCallId?: string;
  blockKind?: ChatBlockKind;
  payloadJson?: string;
  orderKey?: number;
}

class AssistantStatusPayload {
  status: string = 'interrupted';
  retryable: boolean = true;
}

class TextBlockPayload {
  text: string = '';
}

/**
 * 对齐 iOS MessageRunActor：同一 assistant 消息的 partial/block 串行落库。
 */
export class MessageRunActor {
  private readonly repo: ChatRepository;
  private chain: Promise<void> = Promise.resolve();
  private readonly textBlockIds: Map<string, string> = new Map();
  private readonly reasoningBlockIds: Map<string, string> = new Map();
  private readonly toolBlockIds: Map<string, string> = new Map();
  private readonly revisions: Map<string, number> = new Map();
  private activeGeneration: number = 0;
  private terminalAssistants: Set<string> = new Set();

  constructor(repo: ChatRepository) {
    this.repo = repo;
  }

  bumpGeneration(): number {
    this.activeGeneration += 1;
    this.terminalAssistants.clear();
    return this.activeGeneration;
  }

  get generation(): number {
    return this.activeGeneration;
  }

  apply(effect: MessageRunEffect): Promise<void> {
    this.chain = this.chain.then(async () => {
      await this.handle(effect);
    }).catch((_e: Object) => {
      // 单次副作用失败不阻断后续
    });
    return this.chain;
  }

  private async handle(effect: MessageRunEffect): Promise<void> {
    if (effect.generation !== this.activeGeneration) {
      return;
    }
    const terminalKey = `${effect.accountId}:${effect.assistantClientId}`;
    if (this.terminalAssistants.has(terminalKey) &&
      (effect.kind === 'partialText' || effect.kind === 'partialReasoning' || effect.kind === 'toolBlock')) {
      return;
    }
    const now = new Date().toISOString();
    if (effect.kind === 'partialText') {
      const blockId = this.ensureBlockId(this.textBlockIds, effect.assistantClientId, 'text');
      const rev = this.nextRevision(effect.assistantClientId);
      const block = new ChatMessageBlock();
      block.blockId = blockId;
      block.kind = 'text';
      block.text = effect.text;
      block.orderKey = 10;
      block.revision = rev;
      block.status = 'streaming';
      block.nodeRole = 'timeline';
      const payload = new TextBlockPayload();
      payload.text = effect.text;
      block.payloadJson = JSON.stringify(payload);
      block.updatedAt = now;
      await this.repo.upsertBlock(effect.accountId, effect.assistantClientId, block);
      await this.repo.updateMessageStatus(effect.accountId, effect.assistantClientId, 'streamed', effect.text);
      return;
    }
    if (effect.kind === 'partialReasoning') {
      const blockId = this.ensureBlockId(this.reasoningBlockIds, effect.assistantClientId, 'reasoning');
      const rev = this.nextRevision(effect.assistantClientId);
      const block = new ChatMessageBlock();
      block.blockId = blockId;
      block.kind = 'deepThought';
      block.text = effect.text;
      block.orderKey = 5;
      block.revision = rev;
      block.status = 'streaming';
      block.nodeRole = 'timeline';
      const payload = new TextBlockPayload();
      payload.text = effect.text;
      block.payloadJson = JSON.stringify(payload);
      block.updatedAt = now;
      await this.repo.upsertBlock(effect.accountId, effect.assistantClientId, block);
      return;
    }
    if (effect.kind === 'toolBlock') {
      const key = `${effect.assistantClientId}:${effect.toolCallId ?? effect.toolName ?? 'tool'}`;
      let blockId = this.toolBlockIds.get(key);
      if (!blockId) {
        blockId = ChatStableBlockID.tool(effect.assistantClientId, effect.toolCallId ?? effect.toolName ?? 'tool');
        this.toolBlockIds.set(key, blockId);
      }
      const rev = this.nextRevision(effect.assistantClientId);
      const block = new ChatMessageBlock();
      block.blockId = blockId;
      block.kind = 'tool';
      block.text = effect.text;
      block.toolName = effect.toolName;
      block.toolCallId = effect.toolCallId;
      block.orderKey = 20;
      block.revision = rev;
      block.status = 'streaming';
      block.nodeRole = 'tool';
      const payload = new TextBlockPayload();
      payload.text = effect.text;
      block.payloadJson = JSON.stringify(payload);
      block.updatedAt = now;
      await this.repo.upsertBlock(effect.accountId, effect.assistantClientId, block);
      return;
    }
    if (effect.kind === 'richBlock') {
      const kind = effect.blockKind ?? 'rich';
      const blockId = ChatStableBlockID.rich(effect.assistantClientId, kind, effect.toolCallId);
      const rev = this.nextRevision(effect.assistantClientId);
      const block = new ChatMessageBlock();
      block.blockId = blockId;
      block.kind = kind;
      block.text = effect.text;
      block.toolName = effect.toolName;
      block.toolCallId = effect.toolCallId;
      block.orderKey = effect.orderKey ?? 2100;
      block.revision = rev;
      block.status = 'ready';
      block.nodeRole = 'toolPresentation';
      block.payloadJson = effect.payloadJson ?? '{}';
      block.updatedAt = now;
      await this.repo.upsertBlock(effect.accountId, effect.assistantClientId, block);
      return;
    }
    if (effect.kind === 'assistantStatusCard') {
      const block = new ChatMessageBlock();
      block.blockId = ChatStableBlockID.rich(effect.assistantClientId, 'assistantStatusCard');
      block.kind = 'assistantStatusCard';
      block.text = effect.text;
      block.orderKey = 3200;
      block.revision = this.nextRevision(effect.assistantClientId);
      block.status = 'ready';
      block.nodeRole = 'timeline';
      block.payloadJson = effect.payloadJson ?? '{}';
      block.updatedAt = now;
      await this.repo.upsertBlock(effect.accountId, effect.assistantClientId, block);
      await this.repo.updateMessageStatus(effect.accountId, effect.assistantClientId, 'pending', effect.text, effect.errorCode);
      this.terminalAssistants.add(terminalKey);
      return;
    }
    if (effect.kind === 'setStatus') {
      const status = effect.status ?? 'failed';
      this.terminalAssistants.add(terminalKey);
      if (status === 'cancelled') {
        await this.finalizeStreamingBlocks(effect.accountId, effect.assistantClientId, effect.text, now);
        const interrupted = new ChatMessageBlock();
        interrupted.blockId = ChatStableBlockID.rich(effect.assistantClientId, 'assistantStatusCard');
        interrupted.kind = 'assistantStatusCard';
        interrupted.text = effect.text.length > 0 ? effect.text : '本次回答已停止，可继续重试。';
        interrupted.orderKey = 3200;
        interrupted.revision = this.nextRevision(effect.assistantClientId);
        interrupted.status = 'ready';
        interrupted.nodeRole = 'timeline';
        const statusPayload = new AssistantStatusPayload();
        interrupted.payloadJson = JSON.stringify(statusPayload);
        interrupted.updatedAt = now;
        await this.repo.upsertBlock(effect.accountId, effect.assistantClientId, interrupted);
        await this.repo.updateMessageStatus(effect.accountId, effect.assistantClientId, 'pending', effect.text, effect.errorCode, true);
      } else if (status === 'failed') {
        await this.repo.updateMessageStatus(
          effect.accountId,
          effect.assistantClientId,
          'failed',
          effect.text,
          effect.errorCode
        );
      } else if (status === 'completed') {
        await this.repo.updateMessageStatus(
          effect.accountId,
          effect.assistantClientId,
          'completed',
          effect.text,
          undefined
        );
      }
      return;
    }
    if (effect.kind === 'finalize') {
      this.terminalAssistants.add(terminalKey);
      // 对齐 iOS finalizeAssistantBlocks：streaming → ready，再进入 outbox
      await this.finalizeStreamingBlocks(effect.accountId, effect.assistantClientId, effect.text, now);
      await this.repo.updateMessageStatus(
        effect.accountId,
        effect.assistantClientId,
        'pending',
        effect.text,
        undefined,
        true
      );
    }
  }

  /** 将 text / deepThought / tool 的 streaming|pending 块落成 ready。 */
  private async finalizeStreamingBlocks(
    accountId: number,
    assistantClientId: string,
    finalText: string,
    now: string
  ): Promise<void> {
    const existing = await this.repo.listBlocks(accountId, assistantClientId);
    let hasTextBlock = false;
    for (let i = 0; i < existing.length; i++) {
      const block = existing[i];
      if (block.kind !== 'text' && block.kind !== 'deepThought' && block.kind !== 'tool') {
        continue;
      }
      if (block.kind === 'text') {
        hasTextBlock = true;
      }
      if (block.status !== 'streaming' && block.status !== 'pending') {
        continue;
      }
      block.status = 'ready';
      block.revision = this.nextRevision(assistantClientId);
      block.updatedAt = now;
      if (block.kind === 'text' && finalText.length > 0) {
        block.text = finalText;
        const payload = new TextBlockPayload();
        payload.text = finalText;
        block.payloadJson = JSON.stringify(payload);
      } else if (block.text.length > 0) {
        const payload = new TextBlockPayload();
        payload.text = block.text;
        block.payloadJson = JSON.stringify(payload);
      }
      await this.repo.upsertBlock(accountId, assistantClientId, block);
    }
    if (!hasTextBlock && finalText.length > 0) {
      const blockId = this.ensureBlockId(this.textBlockIds, assistantClientId, 'text');
      const block = new ChatMessageBlock();
      block.blockId = blockId;
      block.kind = 'text';
      block.text = finalText;
      block.orderKey = 10;
      block.revision = this.nextRevision(assistantClientId);
      block.status = 'ready';
      block.nodeRole = 'timeline';
      const payload = new TextBlockPayload();
      payload.text = finalText;
      block.payloadJson = JSON.stringify(payload);
      block.createdAt = now;
      block.updatedAt = now;
      await this.repo.upsertBlock(accountId, assistantClientId, block);
    }
  }

  private ensureBlockId(map: Map<string, string>, assistantId: string, prefix: string): string {
    let id = map.get(assistantId);
    if (!id) {
      id = prefix === 'text'
        ? ChatStableBlockID.textSegment(assistantId, 0)
        : ChatStableBlockID.reasoning(assistantId);
      map.set(assistantId, id);
    }
    return id;
  }

  private nextRevision(assistantId: string): number {
    const cur = this.revisions.get(assistantId) ?? 0;
    const next = cur + 1;
    this.revisions.set(assistantId, next);
    return next;
  }
}
