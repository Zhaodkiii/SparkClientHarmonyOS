import { ChatRepository } from '../Infrastructure/ChatRepository';

/** 线程删除采用本地 tombstone，和消息同步共用 outbox/sync cursor。 */
export class DeleteChatThreadUseCase {
  private readonly repository: ChatRepository;

  constructor(repository: ChatRepository) {
    this.repository = repository;
  }

  async execute(accountId: number, threadClientId: string): Promise<void> {
    if (accountId <= 0 || threadClientId.length === 0) {
      return;
    }
    await this.repository.softDeleteThread(accountId, threadClientId);
  }
}
