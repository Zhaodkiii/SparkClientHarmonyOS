/**
 * 跨流式、跨设备稳定的消息块 ID。
 * 服务端 ChatMessageBlock.id 是 UUID 主键，因此稳定 ID 也必须输出 UUID。
 */
export class ChatStableBlockID {
  static textSegment(messageId: string, index: number = 0): string {
    return ChatStableBlockID.make(`chat.message.${messageId}.block.text.${index}`);
  }

  static reasoning(messageId: string): string {
    return ChatStableBlockID.make(`chat.message.${messageId}.block.reasoning`);
  }

  static tool(messageId: string, toolCallId: string): string {
    return ChatStableBlockID.make(`chat.message.${messageId}.tool.${toolCallId}.row`);
  }

  static rich(messageId: string, kind: string, toolCallId?: string): string {
    const suffix = toolCallId && toolCallId.length > 0 ? `.${toolCallId}` : '';
    return ChatStableBlockID.make(`chat.message.${messageId}.rich.${kind}${suffix}`);
  }

  static healthResource(messageId: string, resourceType: string, resourceId: number, memberId: number): string {
    return ChatStableBlockID.make(`chat.message.${messageId}.health.${resourceType}.${resourceId}.${memberId}`);
  }

  private static make(seed: string): string {
    let first = 2166136261;
    let second = 16777619;
    for (let i = 0; i < seed.length; i++) {
      const code = seed.charCodeAt(i);
      first = (first ^ code) >>> 0;
      first = Math.imul(first, 16777619) >>> 0;
      second = (second + code + i) >>> 0;
      second = Math.imul(second ^ (second >>> 13), 2246822519) >>> 0;
    }
    // 用两个 32 位 hash 扩展成 128 位确定性 UUID；同一个消息块在流式更新、重启和多端同步中保持不变。
    const third = (first ^ second ^ 0x9e3779b9) >>> 0;
    const fourth = (second + 0x7f4a7c15) >>> 0;
    const raw = `${ChatStableBlockID.hex(first)}${ChatStableBlockID.hex(second)}${ChatStableBlockID.hex(third)}${ChatStableBlockID.hex(fourth)}`;
    const versioned = `${raw.substring(0, 12)}5${raw.substring(13, 16)}8${raw.substring(17)}`;
    return `${versioned.substring(0, 8)}-${versioned.substring(8, 12)}-${versioned.substring(12, 16)}-${versioned.substring(16, 20)}-${versioned.substring(20)}`;
  }

  private static hex(value: number): string {
    return value.toString(16).padStart(8, '0');
  }
}
