import {
  AIResolvedConfig,
  AIRuntimeMessage,
  AIScenario,
  RuntimeSnapshot
} from '../../../../Core/AI/Domain/AIConfigModels';
import { AIConfigRepository } from '../../../../Core/AI/Application/AIConfigRepository';
import { ScenarioPolicyResolver } from '../../../../Core/AI/Application/ScenarioPolicyResolver';
import { AIRuntimeCancellationToken } from '../../../../Core/AI/Runtime/AIRuntimeCancellation';
import { ChatOrchestrator } from '../../../../Core/AI/Runtime/ChatOrchestrator';
import { ChatOrchestratorInferenceOptions } from '../../../../Core/AI/Runtime/ChatOrchestratorInferenceOptions';
import { ChatAssistantPartialDelta } from '../../../../Core/AI/Runtime/ChatOrchestrator';
import { ChatSystemPromptResolver } from '../../../../Core/AI/Runtime/ChatSystemPromptResolver';
import { LocalSmallTask } from '../../../../Core/AI/Domain/AIConfigModels';
import { ChatModelReasoningContext } from '../../../../Core/AI/Runtime/RuntimeReasoningPolicy';
import { ToolSideEffect } from '../../../../Core/AI/Runtime/ToolHub/ToolSideEffectSink';
import {
  ChatMessage,
  ChatNewId,
  ChatThread,
  ChatAttachment,
  ChatMessageBlock
} from '../Domain/ChatModels';
import { ChatDefaults } from '../Domain/ChatDefaults';
import { ChatRepository } from '../Infrastructure/ChatRepository';
import { MessageRunActor, MessageRunEffect } from './MessageRunActor';
import { MemberContextStore } from '../../MemberContext/Presentation/MemberContextStore';
import { MemberContextSummaryBuilder } from './MemberContextSummaryBuilder';
import { ChatStableBlockID } from '../Domain/ChatStableBlockID';
import { CreateThreadUseCase } from './CreateThreadUseCase';
import { Logger } from '../../../../Foundation/Logging/Logger';
import { LogModule } from '../../../../Foundation/Logging/LogModule';
import { LogFields } from '../../../../Foundation/Logging/LogEvent';

export class SendChatMessageResult {
  threadClientId: string = '';
  userClientId: string = '';
  assistantClientId: string = '';
  text: string = '';
  errorCode?: string;
  messageCount: number = 0;
}

class ChatAttachmentBlockPayload {
  attachments: Object[] = [];
}

class ToolEffectPayload {
  text: string = '';
}

class TextPayload {
  text: string = '';
}

/**
 * 对齐 iOS SendChatMessageUseCase：
 * AIConfig 读链路 → 用户消息入库 → 助手占位 → Orchestrator → MessageRunActor finalize → Outbox 旁路。
 */
export class SendChatMessageUseCase {
  private readonly repo: ChatRepository;
  private readonly orchestrator: ChatOrchestrator;
  private readonly runActor: MessageRunActor;
  private readonly aiConfigRepository: AIConfigRepository;
  private readonly createThreadUseCase: CreateThreadUseCase;
  private readonly memberContext?: MemberContextStore;
  private readonly promptResolver: ChatSystemPromptResolver = new ChatSystemPromptResolver();

  constructor(
    repo: ChatRepository,
    orchestrator: ChatOrchestrator,
    runActor: MessageRunActor,
    aiConfigRepository: AIConfigRepository,
    createThreadUseCase: CreateThreadUseCase,
    memberContext?: MemberContextStore
  ) {
    this.repo = repo;
    this.orchestrator = orchestrator;
    this.runActor = runActor;
    this.aiConfigRepository = aiConfigRepository;
    this.createThreadUseCase = createThreadUseCase;
    this.memberContext = memberContext;
    this.orchestrator.hub.sink.setHandler((effect: ToolSideEffect) => {
      if (!effect.assistantMessageClientId || effect.accountId <= 0) {
        return;
      }
      const rich = new MessageRunEffect();
      rich.kind = 'richBlock';
      rich.accountId = effect.accountId;
      rich.assistantClientId = effect.assistantMessageClientId;
      rich.generation = this.runActor.generation;
      rich.text = effect.text;
      rich.toolName = effect.toolName;
      rich.toolCallId = effect.toolCallId;
      rich.blockKind = effect.kind === 'chatBlock' ? 'toolPresentation' : 'rich';
      const payload = new ToolEffectPayload();
      payload.text = effect.text;
      rich.payloadJson = JSON.stringify(payload);
      void this.runActor.apply(rich);
    });
  }

  get messageRunActor(): MessageRunActor {
    return this.runActor;
  }

  async ensureDefaultThread(accountId: number): Promise<ChatThread> {
    const list = await this.repo.listThreads(accountId);
    if (list.length > 0) {
      return list[0];
    }
    return await this.createThreadUseCase.execute(accountId);
  }

  /** @deprecated 使用 CreateThreadUseCase；保留兼容旧调用。 */
  async createThread(accountId: number, title: string = ChatDefaults.THREAD_TITLE): Promise<ChatThread> {
    return await this.createThreadUseCase.execute(accountId, title);
  }

  async execute(
    accountId: number,
    threadClientId: string,
    userInput: string,
    preferredModelName: string | undefined,
    cancellationToken: AIRuntimeCancellationToken,
    onUiPartial?: (assistantClientId: string, answer: string, reasoning: string) => void,
    sessionPrompt?: string,
    agentPrompt?: string,
    reasoningEnabled: boolean = false,
    supportsDeepReasoning: boolean = false,
    attachmentsJson: string = '[]',
    useTools: boolean = false,
    reasoningEffortTier: number = 0,
    useKnowledgeBag: boolean = true,
    useWebSearch: boolean = true,
    assistantClientMessageID?: string,
    selectedSmallTask?: LocalSmallTask
  ): Promise<SendChatMessageResult> {
    const start = Date.now();
    const trimmed = userInput.trim();
    const attachmentObjects = SendChatMessageUseCase.decodeAttachments(attachmentsJson);
    const result = new SendChatMessageResult();
    result.threadClientId = threadClientId;

    if (trimmed.length === 0 && attachmentObjects.length === 0) {
      result.errorCode = 'emptyInput';
      return result;
    }
    if (accountId <= 0) {
      result.errorCode = 'accountRequired';
      return result;
    }

    const memberId = MemberContextSummaryBuilder.selectedMemberId(this.memberContext);
    const begin = new LogFields();
    begin.detail =
      `sendMessage 开始，thread=${SendChatMessageUseCase.shortId(threadClientId)},` +
      ` member=${memberId ?? '-'}, inputLength=${trimmed.length},` +
      ` attachments=${attachmentObjects.length}, healthRefs=0`;
    Logger.info('chat.send.begin', LogModule.GENERAL, begin);

    const snapFields = new LogFields();
    snapFields.detail = `AIConfigCenter.currentSnapshot 读链路开始（仓储解析会话，resolved=${accountId}）`;
    Logger.debug('chat.send.snapshot.begin', LogModule.GENERAL, snapFields);

    const snapshot = await this.aiConfigRepository.loadSnapshot(accountId);
    const hit = new LogFields();
    hit.detail =
      `AIConfigCenter.currentSnapshot 命中内存缓存 厂商Key=${snapshot.providers.length}` +
      ` 模型=${snapshot.models.length} 提示词=0`;
    Logger.debug('chat.send.snapshot.hit', LogModule.GENERAL, hit);

    let runtime = this.aiConfigRepository.currentRuntime(accountId);
    if (!runtime) {
      runtime = await this.aiConfigRepository.buildRuntime(accountId);
    }

    let thread = await this.repo.findThreadByRemoteId(accountId, threadClientId);
    if (!thread) {
      thread = await this.createThreadUseCase.execute(accountId);
      result.threadClientId = thread.clientId;
    }

    const preferred = SendChatMessageUseCase.firstNonEmpty(
      preferredModelName,
      thread.preferredModelName
    );
    const resolved = SendChatMessageUseCase.resolveChatModel(runtime, preferred);
    if (!resolved) {
      result.errorCode = 'missingModelForScenario';
      return result;
    }

    const persistedModelName = SendChatMessageUseCase.firstNonEmpty(
      preferredModelName,
      thread.preferredModelName,
      resolved.modelName
    );
    if (thread.preferredModelName !== persistedModelName) {
      await this.repo.updateThreadGenerationConfig(
        accountId,
        thread.clientId,
        persistedModelName,
        thread.temperature,
        thread.topP,
        thread.maxTokens,
        thread.maxMessages,
        thread.rolePrompt
      );
      thread.preferredModelName = persistedModelName;
    }

    const temperature = thread.temperature ?? resolved.temperature;
    const topP = thread.topP;
    const maxTokens = thread.maxTokens ?? resolved.maxTokens;
    const systemPrompt = this.promptResolver.resolveWithTask(
      sessionPrompt ?? thread.rolePrompt,
      agentPrompt ?? resolved.systemProvision,
      selectedSmallTask
    );

    const generation = this.runActor.bumpGeneration();
    const now = new Date().toISOString();
    const memberSummary = thread.memberId
      ? MemberContextSummaryBuilder.build(this.memberContext)
      : '';

    const user = new ChatMessage();
    user.clientId = ChatNewId.uuidLike();
    user.accountId = accountId;
    user.threadClientId = thread.clientId;
    user.threadId = thread.threadId || thread.clientId;
    user.role = 'user';
    user.kind = 'text';
    user.text = trimmed;
    user.attachmentsJson = attachmentsJson.length > 0 ? attachmentsJson : '[]';
    user.deliveryStatus = 'pending';
    user.syncState = 'pending';
    user.modelName = ChatDefaults.USER_MODEL_NAME;
    user.createdAt = now;
    user.updatedAt = now;
    if (trimmed.length > 0) {
      const textBlock = new ChatMessageBlock();
      textBlock.blockId = ChatStableBlockID.textSegment(user.clientId, 0);
      textBlock.kind = 'text';
      textBlock.text = trimmed;
      textBlock.orderKey = 10;
      textBlock.revision = 1;
      textBlock.status = 'ready';
      textBlock.nodeRole = 'timeline';
      const textPayload = new TextPayload();
      textPayload.text = trimmed;
      textBlock.payloadJson = JSON.stringify(textPayload);
      textBlock.createdAt = now;
      textBlock.updatedAt = now;
      user.blocks.push(textBlock);
    }
    SendChatMessageUseCase.appendAttachmentBlocks(user, attachmentObjects);
    await this.repo.upsertMessage(user);
    result.userClientId = user.clientId;

    const userPersisted = new LogFields();
    userPersisted.detail =
      `用户消息已入库，thread=${SendChatMessageUseCase.shortId(thread.clientId)},` +
      ` clientMessageID=${SendChatMessageUseCase.shortId(user.clientId)},` +
      ` blocks=${user.blocks.length}, healthBlocks=0`;
    Logger.debug('chat.send.user_persisted', LogModule.GENERAL, userPersisted);

    const assistantId = assistantClientMessageID && ChatNewId.isUUID(assistantClientMessageID)
      ? assistantClientMessageID
      : ChatNewId.uuidLike();
    const assistant = new ChatMessage();
    assistant.clientId = assistantId;
    assistant.accountId = accountId;
    assistant.threadClientId = thread.clientId;
    assistant.threadId = thread.threadId || thread.clientId;
    assistant.role = 'assistant';
    assistant.kind = 'text';
    assistant.text = '';
    assistant.deliveryStatus = 'sending';
    // 流式中不进入 outbox；finalize 后再 pending
    assistant.syncState = 'synced';
    assistant.modelName = resolved.modelName;
    assistant.createdAt = now;
    assistant.updatedAt = now;
    await this.repo.upsertMessage(assistant, true, false);
    result.assistantClientId = assistant.clientId;

    const historyRows = await this.repo.listMessages(accountId, thread.clientId);
    // history 不含本轮 user/assistant；本轮 userInput 单独组装（对齐 iOS merge 前的语义）。
    let eligibleHistoryRows: ChatMessage[] = [];
    for (let i = 0; i < historyRows.length; i++) {
      const row = historyRows[i];
      if (row.clientId === assistant.clientId || row.clientId === user.clientId) {
        continue;
      }
      if (row.role !== 'user' && row.role !== 'assistant') {
        continue;
      }
      if (row.deliveryStatus === 'failed' || row.deliveryStatus === 'cancelled') {
        continue;
      }
      eligibleHistoryRows.push(row);
    }
    // 对齐 iOS `history.suffix(maxMessages)`：按线程配置裁剪窗口，避免无上限历史膨胀 token 成本。
    if (thread.maxMessages > 0 && eligibleHistoryRows.length > thread.maxMessages) {
      eligibleHistoryRows = eligibleHistoryRows.slice(eligibleHistoryRows.length - thread.maxMessages);
    }

    const historyExcludeCurrent: AIRuntimeMessage[] = [];
    let historyAttachmentCount = 0;
    for (let i = 0; i < eligibleHistoryRows.length; i++) {
      const row = eligibleHistoryRows[i];
      const msg = new AIRuntimeMessage();
      msg.role = row.role;
      let rowAttachments: ChatAttachment[] = [];
      for (let b = 0; b < row.blocks.length; b++) {
        const block = row.blocks[b];
        if (block.kind === 'deepThought' && block.text.length > 0) {
          msg.reasoningContent = block.text;
        } else if (row.role === 'user' && (block.kind === 'imageGallery' || block.kind === 'fileAttachments')) {
          rowAttachments = rowAttachments.concat(SendChatMessageUseCase.decodeAttachmentBlock(block.payloadJson));
        }
      }
      const baseText = SendChatMessageUseCase.messageText(row);
      msg.content = row.role === 'user'
        ? SendChatMessageUseCase.mergeAttachmentContent(baseText, rowAttachments)
        : baseText;
      historyAttachmentCount += rowAttachments.length;
      if (msg.content.length > 0) {
        historyExcludeCurrent.push(msg);
      }
    }

    // 对齐 iOS LocalOCR 路径：把本轮附件的识别文字拼进发给模型的正文，避免模型对图片/文件内容一无所知。
    const currentAttachments: ChatAttachment[] = [];
    for (let i = 0; i < attachmentObjects.length; i++) {
      currentAttachments.push(ChatAttachment.fromJson(attachmentObjects[i]));
    }
    const currentUserInput = SendChatMessageUseCase.mergeAttachmentContent(trimmed, currentAttachments);

    const prep = new LogFields();
    prep.detail =
      `准备 AI 编排，thread=${SendChatMessageUseCase.shortId(thread.clientId)},` +
      ` history=${historyExcludeCurrent.length + 1}, memberContextLength=${memberSummary.length},` +
      ` maxMessages=${thread.maxMessages}, currentAttachments=${currentAttachments.length},` +
      ` historyAttachments=${historyAttachmentCount}`;
    Logger.debug('chat.send.orchestrate.prep', LogModule.GENERAL, prep);

    const inference = ChatOrchestratorInferenceOptions.defaultOptions();
    inference.useTools = useTools;
    inference.useKnowledgeBag = useKnowledgeBag;
    inference.useWebSearch = useWebSearch;
    inference.reasoningEnabled = reasoningEnabled;
    inference.reasoningEffortTier = reasoningEffortTier;
    const modelReasoning = ChatModelReasoningContext.fromCapabilities(
      supportsDeepReasoning || resolved.capabilities.supportsDeepReasoning === true,
      true
    );
    const providerCompany = resolved.company.length > 0
      ? resolved.company.toUpperCase()
      : undefined;

    try {
      cancellationToken.checkCancellation();
      const out = await this.orchestrator.generateReply(
        currentUserInput.length > 0 ? currentUserInput : '请分析我发送的附件。',
        historyExcludeCurrent,
        memberSummary,
        accountId,
        inference,
        systemPrompt,
        resolved.modelName,
        providerCompany,
        temperature,
        topP,
        maxTokens,
        thread.memberId,
        thread.clientId,
        cancellationToken,
        (delta: ChatAssistantPartialDelta) => {
          if (onUiPartial) {
            onUiPartial(assistant.clientId, delta.answer, delta.reasoning ?? '');
          }
          const textFx = new MessageRunEffect();
          textFx.kind = 'partialText';
          textFx.accountId = accountId;
          textFx.assistantClientId = assistant.clientId;
          textFx.generation = generation;
          textFx.text = delta.answer;
          this.runActor.apply(textFx);
          if (delta.reasoning && delta.reasoning.length > 0) {
            const rFx = new MessageRunEffect();
            rFx.kind = 'partialReasoning';
            rFx.accountId = accountId;
            rFx.assistantClientId = assistant.clientId;
            rFx.generation = generation;
            rFx.text = delta.reasoning;
            this.runActor.apply(rFx);
          }
          if (delta.toolName && delta.toolContent) {
            const tFx = new MessageRunEffect();
            tFx.kind = 'toolBlock';
            tFx.accountId = accountId;
            tFx.assistantClientId = assistant.clientId;
            tFx.generation = generation;
            tFx.text = delta.toolContent;
            tFx.toolName = delta.toolName;
            tFx.toolCallId = delta.toolCallID;
            this.runActor.apply(tFx);
          }
        },
        modelReasoning,
        assistant.clientId
      );

      if (out.errorCode === 'emptyOutput' || out.kind === 'error') {
        const fx = new MessageRunEffect();
        fx.kind = 'setStatus';
        fx.accountId = accountId;
        fx.assistantClientId = assistant.clientId;
        fx.generation = generation;
        fx.status = 'failed';
        fx.text = out.text;
        fx.errorCode = out.errorCode ?? 'failed';
        await this.runActor.apply(fx);
        result.errorCode = out.errorCode ?? 'failed';
        result.text = out.text;
        return result;
      }

      const doneFx = new MessageRunEffect();
      doneFx.kind = 'finalize';
      doneFx.accountId = accountId;
      doneFx.assistantClientId = assistant.clientId;
      doneFx.generation = generation;
      doneFx.text = out.text;
      await this.runActor.apply(doneFx);
      result.text = out.text;

      const latest = await this.repo.listMessages(accountId, thread.clientId);
      result.messageCount = latest.length;
      const cost = ((Date.now() - start) / 1000).toFixed(3);
      const orchDone = new LogFields();
      orchDone.detail =
        `AI 编排完成，thread=${SendChatMessageUseCase.shortId(thread.clientId)},` +
        ` kind=${out.kind}, outputLength=${out.text.length}`;
      Logger.info('chat.send.orchestrate.done', LogModule.GENERAL, orchDone);
      const sendDone = new LogFields();
      sendDone.detail =
        `sendMessage 完成，thread=${SendChatMessageUseCase.shortId(thread.clientId)},` +
        ` messages=${latest.length}, cost=${cost}s`;
      Logger.info('chat.send.done', LogModule.GENERAL, sendDone);
      return result;
    } catch (err) {
      const msg = `${err}`;
      const cancelled = msg.indexOf('cancelled') >= 0;
      const fx = new MessageRunEffect();
      fx.kind = 'setStatus';
      fx.accountId = accountId;
      fx.assistantClientId = assistant.clientId;
      fx.generation = generation;
      fx.status = cancelled ? 'cancelled' : 'failed';
      fx.text = cancelled ? '' : '生成失败，请重试';
      fx.errorCode = cancelled ? 'cancelled' : 'providerError';
      await this.runActor.apply(fx);
      result.errorCode = fx.errorCode;
      const fail = new LogFields();
      fail.detail = `sendMessage 失败，cost=${((Date.now() - start) / 1000).toFixed(3)}s error=${msg}`;
      Logger.error('chat.send.failed', LogModule.GENERAL, fail);
      return result;
    }
  }

  private static resolveChatModel(
    runtime: RuntimeSnapshot,
    preferred?: string
  ): AIResolvedConfig | undefined {
    const list = runtime.scenarios.get(AIScenario.CHAT) ?? [];
    if (preferred && preferred.length > 0) {
      const hit = ScenarioPolicyResolver.pickExact(list, preferred);
      if (hit) {
        return hit;
      }
    }
    return list.length > 0 ? list[0] : undefined;
  }

  private static messageText(row: ChatMessage): string {
    if (row.text && row.text.length > 0) {
      return row.text;
    }
    for (let i = 0; i < row.blocks.length; i++) {
      if (row.blocks[i].kind === 'text' && row.blocks[i].text.length > 0) {
        return row.blocks[i].text;
      }
    }
    return '';
  }

  private static firstNonEmpty(...values: Array<string | undefined>): string | undefined {
    for (let i = 0; i < values.length; i++) {
      const v = values[i]?.trim();
      if (v && v.length > 0) {
        return v;
      }
    }
    return undefined;
  }

  private static shortId(id: string): string {
    return id.length > 8 ? id.substring(0, 8).toUpperCase() : id.toUpperCase();
  }

  /**
   * 对齐 iOS buildLocalOCRContent：把附件 OCR/识别文字拼进发给模型的正文，
   * 附件本身仍只用于本地展示，鸿蒙端当前不发送内联图片（多模态直传另案）。
   */
  private static mergeAttachmentContent(text: string, attachments: ChatAttachment[]): string {
    if (attachments.length === 0) {
      return text;
    }
    const blocks: string[] = [];
    for (let i = 0; i < attachments.length; i++) {
      const att = attachments[i];
      const ocr = (att.text ?? '').trim();
      const isPdf = att.kind === 'pdf';
      const isImage = att.kind === 'image';
      const label = isPdf ? 'PDF附件' : (isImage ? '图片附件' : '文件附件');
      const ocrLabel = isPdf ? 'PDF识别' : (isImage ? '图片识别' : '文件识别');
      const fileIdStr = `file_id=${att.fileId ?? '-'}`;
      const fileUuidStr = `file_uuid=${att.fileUuid ?? '-'}`;
      blocks.push(`【${label}】${fileIdStr} ${fileUuidStr}\n【${ocrLabel}】\n${ocr.length > 0 ? ocr : '(无文字)'}`);
    }
    const trimmedText = text.trim();
    if (trimmedText.length > 0) {
      blocks.push(`【用户输入】\n${trimmedText}`);
    }
    return blocks.join('\n\n');
  }

  /** 解码 imageGallery/fileAttachments 块的 payloadJson，取回历史轮次的附件列表（用于回填 OCR 文本）。 */
  private static decodeAttachmentBlock(payloadJson: string): ChatAttachment[] {
    try {
      const parsed = JSON.parse(payloadJson) as Record<string, Object>;
      const raw = parsed['attachments'] as Object[] | undefined;
      if (!raw) {
        return [];
      }
      const out: ChatAttachment[] = [];
      for (let i = 0; i < raw.length; i++) {
        out.push(ChatAttachment.fromJson(raw[i]));
      }
      return out;
    } catch (_e) {
      return [];
    }
  }

  private static decodeAttachments(raw: string): Object[] {
    try {
      const parsed: Object = JSON.parse(raw) as Object;
      return Array.isArray(parsed) ? parsed as Object[] : [];
    } catch (_e) {
      return [];
    }
  }

  private static appendAttachmentBlocks(message: ChatMessage, rawAttachments: Object[]): void {
    if (rawAttachments.length === 0) {
      return;
    }
    const imagePayload = new ChatAttachmentBlockPayload();
    const filePayload = new ChatAttachmentBlockPayload();
    for (let i = 0; i < rawAttachments.length; i++) {
      const attachment = ChatAttachment.fromJson(rawAttachments[i]);
      if (attachment.kind === 'image') {
        imagePayload.attachments.push(rawAttachments[i]);
      } else {
        filePayload.attachments.push(rawAttachments[i]);
      }
    }
    if (imagePayload.attachments.length > 0) {
      const block = new ChatMessageBlock();
      block.blockId = ChatStableBlockID.rich(message.clientId, 'imageGallery');
      block.kind = 'imageGallery';
      block.orderKey = 100;
      block.nodeRole = 'timeline';
      block.status = 'ready';
      block.payloadJson = JSON.stringify(imagePayload);
      block.updatedAt = message.updatedAt;
      message.blocks.push(block);
    }
    if (filePayload.attachments.length > 0) {
      const block = new ChatMessageBlock();
      block.blockId = ChatStableBlockID.rich(message.clientId, 'fileAttachments');
      block.kind = 'fileAttachments';
      block.orderKey = 200;
      block.nodeRole = 'timeline';
      block.status = 'ready';
      block.payloadJson = JSON.stringify(filePayload);
      block.updatedAt = message.updatedAt;
      message.blocks.push(block);
    }
  }
}
