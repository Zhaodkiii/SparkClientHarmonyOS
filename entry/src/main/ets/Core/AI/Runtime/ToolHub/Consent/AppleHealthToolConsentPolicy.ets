import { runtimeRequiresAppleHealthConsent } from '../Models/ToolDataPolicy';
import { ToolExecutionResult } from '../Models/ToolingModels';
import { ToolConsentPermissionStore } from './ToolConsentPermissionStore';

/**
 * 对齐 iOS AppleHealthToolConsentPolicy。
 */
export class AppleHealthToolConsentPolicy {
  private readonly store: ToolConsentPermissionStore;

  constructor(store?: ToolConsentPermissionStore) {
    this.store = store ?? new ToolConsentPermissionStore();
  }

  get permissionStore(): ToolConsentPermissionStore {
    return this.store;
  }

  requiresConsent(result: ToolExecutionResult, providerCompany: string | undefined): boolean {
    return runtimeRequiresAppleHealthConsent(
      result.toolName,
      result.sensitive,
      providerCompany,
      this.store.isAllowed(result.toolName)
    );
  }

  rememberAllowed(toolName: string): void {
    this.store.rememberAllowed(toolName);
  }
}
