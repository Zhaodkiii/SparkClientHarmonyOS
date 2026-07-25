/** 对齐 iOS ToolPreviewPrompt：聊天内工具详情 Sheet 载荷（不入库）。 */
export class ToolPreviewPrompt {
  id: string = '';
  toolName: string = '';
  toolContent: string = '';
  toolArguments?: Record<string, string>;
  toolCallID?: string;
  threadID: string = '';
  sourceClientMessageID: string = '';
  relatedBlockIDs: string[] = [];

  static create(
    toolName: string,
    toolContent: string,
    threadID: string,
    sourceClientMessageID: string,
    relatedBlockIDs: string[],
    toolArguments?: Record<string, string>,
    toolCallID?: string
  ): ToolPreviewPrompt {
    const p = new ToolPreviewPrompt();
    p.id = `${Date.now()}_${Math.floor(Math.random() * 100000)}`;
    p.toolName = toolName;
    p.toolContent = toolContent;
    p.toolArguments = toolArguments;
    p.toolCallID = toolCallID;
    p.threadID = threadID;
    p.sourceClientMessageID = sourceClientMessageID;
    p.relatedBlockIDs = relatedBlockIDs;
    return p;
  }

  /** 参数字典稳定排序展示，避免 UI 每次顺序跳动。 */
  static displayText(toolArguments: Record<string, string>): string {
    const keys = Object.keys(toolArguments).sort();
    const lines: string[] = [];
    for (let i = 0; i < keys.length; i++) {
      const key = keys[i];
      const value = (toolArguments[key] ?? '').trim();
      lines.push(value.length === 0 ? key : `${key}: ${value}`);
    }
    return lines.join('\n');
  }
}
