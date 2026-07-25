import { ChatRepository } from '../Infrastructure/ChatRepository';

/** 对齐 iOS：仅允许失败/取消消息回到 pending，随后由 ChatSyncEngine 负责上送。 */
export class RetryFailedMessageUseCase {
  private readonly repository: ChatRepository;

  constructor(repository: ChatRepository) {
    this.repository = repository;
  }

  async execute(accountId: number, clientMessageId: string): Promise<void> {
    if (accountId <= 0 || clientMessageId.length === 0) {
      return;
    }
    await this.repository.retryMessage(accountId, clientMessageId);
  }
}
