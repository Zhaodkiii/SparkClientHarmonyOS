import { AIConfigRepository } from '../../../../Core/AI/Application/AIConfigRepository';
import { ChatDefaults } from '../Domain/ChatDefaults';
import { ChatNewId, ChatThread } from '../Domain/ChatModels';
import { ChatRepository } from '../Infrastructure/ChatRepository';
import { MemberContextStore } from '../../MemberContext/Presentation/MemberContextStore';
import { MemberContextSummaryBuilder } from './MemberContextSummaryBuilder';
import { Logger } from '../../../../Foundation/Logging/Logger';
import { LogModule } from '../../../../Foundation/Logging/LogModule';
import { LogFields } from '../../../../Foundation/Logging/LogEvent';

/**
 * 对齐 iOS CreateThreadUseCase：
 * AIConfig 读链路 → 默认 image_delivery_mode → 本地落库 → 变更通知触发 thread-push。
 */
export class CreateThreadUseCase {
  private readonly repository: ChatRepository;
  private readonly aiConfigRepository: AIConfigRepository;
  private readonly memberContext?: MemberContextStore;

  constructor(
    repository: ChatRepository,
    aiConfigRepository: AIConfigRepository,
    memberContext?: MemberContextStore
  ) {
    this.repository = repository;
    this.aiConfigRepository = aiConfigRepository;
    this.memberContext = memberContext;
  }

  async execute(accountId: number, title: string = ChatDefaults.THREAD_TITLE): Promise<ChatThread> {
    if (accountId <= 0) {
      throw new Error('accountRequired');
    }
    const snapFields = new LogFields();
    snapFields.detail = `AIConfigCenter.currentSnapshot 读链路开始（仓储解析会话，resolved=${accountId}）`;
    Logger.debug('chat.create.snapshot.begin', LogModule.GENERAL, snapFields);

    // 对齐 iOS：读快照（副作用：确保 runtime/缓存链路热启）；默认投递模式恒为 directMultimodal。
    const snapshot = await this.aiConfigRepository.loadSnapshot(accountId);
    const hit = new LogFields();
    hit.detail =
      `AIConfigCenter.currentSnapshot 命中内存缓存 厂商Key=${snapshot.providers.length}` +
      ` 模型=${snapshot.models.length} 提示词=0`;
    Logger.debug('chat.create.snapshot.hit', LogModule.GENERAL, hit);

    const now = new Date().toISOString();
    const thread = new ChatThread();
    thread.clientId = ChatNewId.uuidLike();
    thread.threadId = thread.clientId;
    thread.accountId = accountId;
    const trimmed = title.trim();
    thread.title = trimmed.length > 0 ? trimmed.substring(0, 40) : ChatDefaults.THREAD_TITLE;
    thread.scenario = ChatDefaults.SCENARIO;
    thread.topP = ChatDefaults.TOP_P;
    thread.maxMessages = ChatDefaults.MAX_MESSAGES;
    thread.rolePrompt = '';
    thread.imageDeliveryMode = ChatDefaults.IMAGE_DELIVERY_MODE;
    thread.memberId = MemberContextSummaryBuilder.selectedMemberId(this.memberContext);
    thread.createdAt = now;
    thread.updatedAt = now;
    await this.repository.upsertThread(thread);
    // upsertThread 已发布 threadsChanged；此处不再重复 publish

    const done = new LogFields();
    done.detail = `创建会话完成，thread=${CreateThreadUseCase.shortId(thread.clientId)} title=${thread.title}`;
    Logger.info('chat.create.done', LogModule.GENERAL, done);
    return thread;
  }

  private static shortId(id: string): string {
    return id.length > 8 ? id.substring(0, 8) : id;
  }
}
