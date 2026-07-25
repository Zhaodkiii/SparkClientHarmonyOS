import { AIConfigRepository } from '../../../../Core/AI/Application/AIConfigRepository';
import { AIConfigSnapshot } from '../../../../Core/AI/Domain/AIConfigModels';

export class LoadAISettingsUseCase {
  private readonly repository: AIConfigRepository;

  constructor(repository: AIConfigRepository) {
    this.repository = repository;
  }

  /** 设置页读配置：必要时补种子，再从 RDB 拉最新快照 */
  async execute(accountId: number): Promise<AIConfigSnapshot> {
    await this.repository.ensureSeeded(accountId);
    return await this.repository.loadSnapshot(accountId);
  }
}

export class SaveAISettingsUseCase {
  private readonly repository: AIConfigRepository;

  constructor(repository: AIConfigRepository) {
    this.repository = repository;
  }

  async execute(accountId: number, snapshot: AIConfigSnapshot): Promise<void> {
    await this.repository.save(accountId, snapshot);
  }

  async saveDraft(accountId: number, snapshot: AIConfigSnapshot): Promise<void> {
    await this.repository.saveDraft(accountId, snapshot);
  }
}
