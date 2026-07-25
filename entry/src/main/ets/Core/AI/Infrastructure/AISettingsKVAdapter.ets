/**
 * KV 仅允许轻量偏好与同步元数据镜像；RDB 为 AI 目录唯一事实源。
 * 白名单：lastRemoteRevision / lastSyncState / allowNetwork / allowLocalModel / selectedProviderId / selectedModelId
 * 禁止：API Key、完整 Provider/Model/Binding、GGUF、prompt、Runtime。
 */
export class AISettingsKVAdapter {
  /** @deprecated 始终 false；当前不落盘 KV，仅保留接口 */
  kvMirrorPending: boolean = false;

  async mirrorPreferences(_accountId: number, payloadJson: string): Promise<void> {
    // 校验白名单形状后丢弃：正式 KV 模块落地前不做持久化，避免与 RDB 双写
    try {
      const obj = JSON.parse(payloadJson) as Record<string, Object | string | number | boolean | null>;
      if (obj['apiKey'] !== undefined || obj['api_key'] !== undefined || obj['providers'] !== undefined) {
        this.kvMirrorPending = false;
        return;
      }
    } catch (_e) {
      // ignore
    }
    this.kvMirrorPending = false;
  }

  async retryPending(): Promise<void> {
    this.kvMirrorPending = false;
  }
}
