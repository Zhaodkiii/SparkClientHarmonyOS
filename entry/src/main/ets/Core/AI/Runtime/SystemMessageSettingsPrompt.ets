import { PromptRepo } from '../../../Projects/Features/AISettings/Domain/PromptRepo';

/** 对齐 iOS SystemMessageSettingsPrompt：会话系统消息设置 Sheet 载荷（不入库）。 */
export class SystemMessageSettingsPrompt {
  id: string = '';
  threadID: string = '';
  sessionPrompt: string = '';
  defaultPrompt: string = '';
  modelDisplayName: string = '';
  isAgentModel: boolean = false;
  agentPrompt?: string;
  promptTemplates: PromptRepo[] = [];

  static create(
    threadID: string,
    sessionPrompt: string,
    defaultPrompt: string,
    modelDisplayName: string,
    isAgentModel: boolean,
    agentPrompt?: string,
    promptTemplates?: PromptRepo[]
  ): SystemMessageSettingsPrompt {
    const p = new SystemMessageSettingsPrompt();
    p.id = `${Date.now()}_${Math.floor(Math.random() * 100000)}`;
    p.threadID = threadID;
    p.sessionPrompt = sessionPrompt;
    p.defaultPrompt = defaultPrompt;
    p.modelDisplayName = modelDisplayName;
    p.isAgentModel = isAgentModel;
    p.agentPrompt = agentPrompt;
    p.promptTemplates = promptTemplates ?? [];
    return p;
  }
}
