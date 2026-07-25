import { PromptLocalizer } from './PromptLocalizer';
import { AIPromptKeywords } from './AIPromptKeywords';
import { AIPromptL10n } from './AIPromptL10n';
import { LocalSmallTask } from '../Domain/AIConfigModels';
import { common } from '@kit.AbilityKit';

/**
 * 对齐 iOS ChatSystemPromptResolver：
 * 小任务对象 > Agent Prompt > 会话 Prompt > 默认。
 * 日期关键字使用 AIPromptKeywords.currentDate（{{CURRENT_DATE}}）。
 */
export class ChatSystemPromptResolver {
  private static context?: common.UIAbilityContext;
  private readonly defaultPrompt: string;

  static bindContext(context: common.UIAbilityContext): void {
    ChatSystemPromptResolver.context = context;
  }

  static clearContextForTests(): void {
    ChatSystemPromptResolver.context = undefined;
  }

  constructor(defaultPrompt?: string) {
    this.defaultPrompt = defaultPrompt && defaultPrompt.length > 0
      ? defaultPrompt
      : new PromptLocalizer().chatSystemPrompt();
  }

  /** 兼容旧入口：小任务已拼装为字符串时使用。 */
  resolve(sessionPrompt?: string, agentPrompt?: string, smallTaskPrompt?: string): string {
    let resolved = this.defaultPrompt;
    if (smallTaskPrompt && smallTaskPrompt.trim().length > 0) {
      resolved = smallTaskPrompt.trim();
    } else if (agentPrompt && agentPrompt.trim().length > 0) {
      resolved = agentPrompt.trim();
    } else if (sessionPrompt && sessionPrompt.trim().length > 0) {
      resolved = sessionPrompt.trim();
    }
    return ChatSystemPromptResolver.replaceDateKeyword(resolved);
  }

  /** 对齐 iOS：优先用 LocalSmallTask 拼装结构化 system prompt。 */
  resolveWithTask(
    sessionPrompt?: string,
    agentPrompt?: string,
    smallTask?: LocalSmallTask
  ): string {
    let resolved = this.defaultPrompt;
    if (smallTask && smallTask.code.length > 0) {
      resolved = ChatSystemPromptResolver.makeSmallTaskSystemPrompt(smallTask);
    } else if (agentPrompt && agentPrompt.trim().length > 0) {
      resolved = agentPrompt.trim();
    } else if (sessionPrompt && sessionPrompt.trim().length > 0) {
      resolved = sessionPrompt.trim();
    }
    return ChatSystemPromptResolver.replaceDateKeyword(resolved);
  }

  static makeSmallTaskSystemPrompt(task: LocalSmallTask): string {
    const brief = task.brief && task.brief.trim().length > 0 ? task.brief.trim() : '无';
    const blocks: string[] = [
      `【小任务】\n${task.name}`,
      `【任务简介】\n${brief}`,
      `【任务设定 / Prompt】\n${task.prompt}`
    ];
    if (task.toolList && task.toolList.length > 0) {
      blocks.push(`【允许工具】\n${task.toolList.join(', ')}`);
    }
    return blocks.join('\n\n');
  }

  private static replaceDateKeyword(prompt: string): string {
    if (!AIPromptKeywords.contains(AIPromptKeywords.currentDate, prompt)) {
      return prompt;
    }
    return prompt.split(AIPromptKeywords.currentDate).join(
      ChatSystemPromptResolver.currentDateInstruction()
    );
  }

  private static currentDateInstruction(): string {
    const d = new Date();
    const y = d.getFullYear();
    const m = `${d.getMonth() + 1}`.padStart(2, '0');
    const day = `${d.getDate()}`.padStart(2, '0');
    const dateStr = `${y}-${m}-${day}`;
    const fallback =
      'Current date: %@. Please use this date to interpret time expressions such as today, tomorrow, and this week.';
    const template = ChatSystemPromptResolver.readDateInstructionTemplate(fallback);
    return AIPromptL10n.format(template, [dateStr]);
  }

  private static readDateInstructionTemplate(fallback: string): string {
    try {
      const ctx = ChatSystemPromptResolver.context;
      if (!ctx) {
        return fallback;
      }
      // 优先 iOS 稳定 key，其次现有 Harmony key
      const keys: string[] = [
        'ai_runtime.prompt.current_date_instruction_format',
        'ai_runtime_prompt_current_date_instruction_format'
      ];
      for (let i = 0; i < keys.length; i++) {
        try {
          const value = ctx.resourceManager.getStringByNameSync(keys[i]);
          if (value && value.length > 0 && value !== keys[i]) {
            return value;
          }
        } catch (_inner) {
          // try next key
        }
      }
      return fallback;
    } catch (_e) {
      return fallback;
    }
  }
}
