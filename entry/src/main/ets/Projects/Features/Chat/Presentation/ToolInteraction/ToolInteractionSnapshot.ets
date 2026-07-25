import { SystemMessageSettingsPrompt } from '../../../../../Core/AI/Runtime/SystemMessageSettingsPrompt';
import { HealthResourceToolCandidatePrompt } from '../../../../../Core/AI/Runtime/HealthResourceToolCandidatePrompt';
import { AskReportPickerPrompt } from '../../../../../Core/AI/Runtime/AskReportPickerPrompt';
import { ToolPreviewPrompt } from './Models/ToolPreviewPrompt';

export type ToolInteractionKind =
  | 'toolPreview'
  | 'systemMessageSettings'
  | 'healthResourceCandidates'
  | 'askReportPicker';

/** 对齐 iOS ToolInteractionSnapshot：当前活动 Sheet 载荷。 */
export class ToolInteractionSnapshot {
  kind: ToolInteractionKind = 'toolPreview';
  toolPreview?: ToolPreviewPrompt;
  systemMessageSettings?: SystemMessageSettingsPrompt;
  healthResourceCandidates?: HealthResourceToolCandidatePrompt;
  askReportPicker?: AskReportPickerPrompt;

  static toolPreview(prompt: ToolPreviewPrompt): ToolInteractionSnapshot {
    const s = new ToolInteractionSnapshot();
    s.kind = 'toolPreview';
    s.toolPreview = prompt;
    return s;
  }

  static systemMessageSettings(prompt: SystemMessageSettingsPrompt): ToolInteractionSnapshot {
    const s = new ToolInteractionSnapshot();
    s.kind = 'systemMessageSettings';
    s.systemMessageSettings = prompt;
    return s;
  }

  static healthResourceCandidates(prompt: HealthResourceToolCandidatePrompt): ToolInteractionSnapshot {
    const s = new ToolInteractionSnapshot();
    s.kind = 'healthResourceCandidates';
    s.healthResourceCandidates = prompt;
    return s;
  }

  static askReportPicker(prompt: AskReportPickerPrompt): ToolInteractionSnapshot {
    const s = new ToolInteractionSnapshot();
    s.kind = 'askReportPicker';
    s.askReportPicker = prompt;
    return s;
  }
}
