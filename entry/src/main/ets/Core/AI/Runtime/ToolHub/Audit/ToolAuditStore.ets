import { ToolAuditEvent, ToolAuditStatus } from '../Models/ToolingModels';

/**
 * 对齐 iOS ToolAuditStore：进程内审计；带上限环形缓冲（鸿蒙侧保留 MAX 防膨胀）。
 */
export class ToolAuditStore {
  private readonly events: ToolAuditEvent[] = [];
  private static readonly MAX: number = 200;
  private persistHandler?: (event: ToolAuditEvent) => Promise<void>;

  setPersistence(handler: (event: ToolAuditEvent) => Promise<void>): void {
    this.persistHandler = handler;
  }

  append(event: ToolAuditEvent): void {
    this.events.push(event);
    while (this.events.length > ToolAuditStore.MAX) {
      this.events.shift();
    }
    if (this.persistHandler) {
      void this.persistHandler(event).catch(() => {
        // 审计持久化失败不阻断模型回复；内存审计仍保留本次事件。
      });
    }
  }

  record(
    toolName: string,
    status: ToolAuditStatus,
    inputSummary: string,
    outputSummary: string,
    memberID?: number,
    requestId?: string,
    threadId?: string,
    accountId: number = 0
  ): void {
    const e = new ToolAuditEvent();
    e.id = `audit_${Date.now()}_${this.events.length}`;
    e.accountId = accountId;
    e.toolName = toolName;
    e.status = status;
    e.memberID = memberID;
    e.inputSummary = inputSummary.length > 200 ? inputSummary.substring(0, 200) : inputSummary;
    e.outputSummary = outputSummary.length > 200 ? outputSummary.substring(0, 200) : outputSummary;
    e.createdAt = new Date().toISOString();
    e.requestId = requestId;
    e.threadId = threadId;
    this.append(e);
  }

  recent(limit: number = 20): ToolAuditEvent[] {
    const sorted = this.events.slice().sort((a, b) => {
      return a.createdAt < b.createdAt ? 1 : (a.createdAt > b.createdAt ? -1 : 0);
    });
    const n = Math.max(1, limit);
    return sorted.slice(0, Math.min(n, sorted.length));
  }

  summaryText(): string {
    const list = this.recent(20);
    if (list.length === 0) {
      return '最近没有工具调用审计记录。';
    }
    const lines: string[] = [];
    for (let i = 0; i < list.length; i++) {
      lines.push(`[${list[i].createdAt}] ${list[i].toolName} - ${list[i].status}`);
    }
    return lines.join('\n');
  }
}
