/**
 * 对齐 iOS ToolConsentPermissionStore：「始终允许」集合。
 * 当前用内存 Set；后续可换 Preferences 持久化。
 */
export class ToolConsentPermissionStore {
  private readonly allowed: Set<string> = new Set();

  isAllowed(toolName: string): boolean {
    return this.allowed.has(ToolConsentPermissionStore.normalize(toolName));
  }

  rememberAllowed(toolName: string): void {
    this.allowed.add(ToolConsentPermissionStore.normalize(toolName));
  }

  revoke(toolName: string): void {
    this.allowed.delete(ToolConsentPermissionStore.normalize(toolName));
  }

  private static normalize(value: string): string {
    return value.trim().toLowerCase();
  }
}
