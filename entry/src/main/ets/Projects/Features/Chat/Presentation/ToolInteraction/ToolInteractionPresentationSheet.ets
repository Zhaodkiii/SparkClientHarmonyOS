import { ToolInteractionSnapshot } from './ToolInteractionSnapshot';
import { ToolPreviewSheet } from './Sheets/ToolPreviewSheet';
import { SystemMessageSettingsSheet } from './Sheets/SystemMessageSettingsSheet';
import { HealthResourceCandidateSheet } from './Sheets/HealthResourceCandidateSheet';
import { AskReportPickerSheet } from './Sheets/AskReportPickerSheet';
import { HealthResourceToolCandidateDTO } from '../../../../../Core/AI/Runtime/HealthResourceToolCandidatePrompt';
import { HealthResourceRef } from '../Composer/Models/HealthResourceRef';

@Component
export struct ToolInteractionPresentationSheet {
  @Prop snapshot?: ToolInteractionSnapshot = undefined;
  onDismiss: () => void = () => {};
  onSaveSessionPrompt: (sessionPrompt: string) => void = (_s: string) => {};
  onHealthCandidatesConfirmed: (selected: HealthResourceToolCandidateDTO[]) => void =
    (_s: HealthResourceToolCandidateDTO[]) => {};
  onAskReportConfirmed: (refs: HealthResourceRef[]) => void = (_r: HealthResourceRef[]) => {};

  build() {
    if (!this.snapshot) {
      Blank()
    } else if (this.snapshot.kind === 'toolPreview' && this.snapshot.toolPreview) {
      ToolPreviewSheet({
        prompt: this.snapshot.toolPreview,
        onClose: () => this.onDismiss()
      })
    } else if (this.snapshot.kind === 'systemMessageSettings' && this.snapshot.systemMessageSettings) {
      SystemMessageSettingsSheet({
        prompt: this.snapshot.systemMessageSettings,
        onSave: (sessionPrompt: string) => this.onSaveSessionPrompt(sessionPrompt),
        onClose: () => this.onDismiss()
      })
    } else if (this.snapshot.kind === 'healthResourceCandidates' && this.snapshot.healthResourceCandidates) {
      HealthResourceCandidateSheet({
        prompt: this.snapshot.healthResourceCandidates,
        onConfirm: (selected: HealthResourceToolCandidateDTO[]) =>
          this.onHealthCandidatesConfirmed(selected),
        onClose: () => this.onDismiss()
      })
    } else if (this.snapshot.kind === 'askReportPicker' && this.snapshot.askReportPicker) {
      AskReportPickerSheet({
        prompt: this.snapshot.askReportPicker,
        onConfirm: (refs: HealthResourceRef[]) => this.onAskReportConfirmed(refs),
        onClose: () => this.onDismiss()
      })
    } else {
      Blank()
    }
  }
}
