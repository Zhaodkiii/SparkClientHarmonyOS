/**
 * 对齐 iOS PromptRepo（AISettingsDomainModels）：系统消息设置 Sheet 可插入的模板。
 * 完整 CRUD 属阶段 3；本工单仅提供载荷类型。
 */
export class PromptRepo {
  id: string = '';
  title: string = '';
  content: string = '';
  isSystem: boolean = false;
  timestamp: string = '';
  localizationKey?: string;

  static create(title: string, content: string, isSystem: boolean = false): PromptRepo {
    const repo = new PromptRepo();
    repo.id = `${Date.now()}_${Math.floor(Math.random() * 100000)}`;
    repo.title = title;
    repo.content = content;
    repo.isSystem = isSystem;
    repo.timestamp = new Date().toISOString();
    return repo;
  }
}
