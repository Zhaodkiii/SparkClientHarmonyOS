import { ToolInteractionSnapshot } from './ToolInteractionSnapshot';

export type ToolInteractionChanged = (snapshot?: ToolInteractionSnapshot) => void;

/** 对齐 iOS ToolInteractionCoordinator：统一管理工具交互 Sheet 活动态。 */
export class ToolInteractionCoordinator {
  private active?: ToolInteractionSnapshot;
  private onChanged?: ToolInteractionChanged;

  setOnChanged(handler: ToolInteractionChanged): void {
    this.onChanged = handler;
  }

  current(): ToolInteractionSnapshot | undefined {
    return this.active;
  }

  present(snapshot: ToolInteractionSnapshot): void {
    this.active = snapshot;
    if (this.onChanged) {
      this.onChanged(this.active);
    }
  }

  dismiss(): void {
    this.active = undefined;
    if (this.onChanged) {
      this.onChanged(undefined);
    }
  }
}
