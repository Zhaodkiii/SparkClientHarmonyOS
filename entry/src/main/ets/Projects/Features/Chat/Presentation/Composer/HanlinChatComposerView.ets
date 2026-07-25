import { Member } from '../../../../Core/Domain/Entities/Member';
import { SmallTask } from './Models/SmallTask';
import { AIScenarioRemoteModelRow } from './Models/AIScenarioRemoteModelRow';
import {
  ChatComposerAttachmentPreview,
  ChatModelReasoningContext,
  defaultModelReasoning
} from './Models/ChatComposerDraftModels';
import { HealthResourceRef } from './Models/HealthResourceRef';
import { ComposerTheme } from './Models/ComposerTheme';
import { ChatComposerContextTaskBar } from './ChatComposerContextTaskBar';
import { HanlinChatInputView } from './HanlinChatInputView';
import { ChatComposerModelPickerRow } from './ChatComposerModelPickerRow';

/**
 * 专业版输入区顶层容器，对标 iOS HanlinChatComposerView：
 * ContextTaskBar → HanlinChatInputView → ModelPickerRow。
 */
@Component
export struct HanlinChatComposerView {
  @Link draft: string;
  @Link useTools: boolean;
  @Link useKnowledgeBase: boolean;
  @Link useWebSearch: boolean;
  @Link reasoningEnabled: boolean;
  @Link reasoningEffortTier: number;
  @Prop running: boolean = false;
  @Prop attachments: ChatComposerAttachmentPreview[] = [];
  @Prop preparedAttachmentCount: number = 0;
  @Prop attachmentStatus: string = '';
  @Prop healthResourceRefs: HealthResourceRef[] = [];
  @Prop modelReasoning: ChatModelReasoningContext = defaultModelReasoning();
  @Prop members: Member[] = [];
  @Prop boundMemberID: number = 0;
  @Prop defaultMemberID: number = 0;
  @Prop smallTasks: SmallTask[] = [];
  @Prop modelRows: AIScenarioRemoteModelRow[] = [];
  @Prop selectedModelName: string | undefined = undefined;
  @Prop canOpenCamera: boolean = false;
  @Prop hideModelPicker: boolean = false;
  onSend: () => void = () => {};
  onCancel: () => void = () => {};
  onPickImages: () => void = () => {};
  onPickCamera: () => void = () => {};
  onPickFiles: () => void = () => {};
  onRemoveAttachment: (id: string) => void = (_id: string) => {};
  onSelectAttachment: (id: string) => void = (_id: string) => {};
  onSetMemberBinding: (memberID: number) => void = (_id: number) => {};
  onRemoveHealthResourceRef: (ref: HealthResourceRef) => void = (_ref: HealthResourceRef) => {};
  onClearHealthResourceRefs: () => void = () => {};
  onSmallTaskTapped: (task: SmallTask) => void = (_task: SmallTask) => {};
  onPresentAskReportPicker: () => void = () => {};
  onSelectModel: (name: string | undefined) => void = (_name: string | undefined) => {};

  build() {
    Column({ space: 4 }) {
      ChatComposerContextTaskBar({
        boundMemberID: this.boundMemberID,
        isSending: this.running,
        smallTasks: this.smallTasks,
        onAskReport: () => this.onPresentAskReportPicker(),
        onSmallTaskTapped: (task: SmallTask) => this.onSmallTaskTapped(task)
      })

      HanlinChatInputView({
        draft: $draft,
        useTools: $useTools,
        useKnowledgeBase: $useKnowledgeBase,
        useWebSearch: $useWebSearch,
        reasoningEnabled: $reasoningEnabled,
        reasoningEffortTier: $reasoningEffortTier,
        running: this.running,
        attachments: this.attachments,
        preparedAttachmentCount: this.preparedAttachmentCount,
        attachmentStatus: this.attachmentStatus,
        healthResourceRefs: this.healthResourceRefs,
        modelReasoning: this.modelReasoning,
        members: this.members,
        boundMemberID: this.boundMemberID,
        defaultMemberID: this.defaultMemberID,
        canOpenCamera: this.canOpenCamera,
        onSend: () => this.onSend(),
        onCancel: () => this.onCancel(),
        onPickImages: () => this.onPickImages(),
        onPickCamera: () => this.onPickCamera(),
        onPickFiles: () => this.onPickFiles(),
        onRemoveAttachment: (id: string) => this.onRemoveAttachment(id),
        onSelectAttachment: (id: string) => this.onSelectAttachment(id),
        onSetMemberBinding: (memberID: number) => this.onSetMemberBinding(memberID),
        onRemoveHealthResourceRef: (ref: HealthResourceRef) => this.onRemoveHealthResourceRef(ref),
        onClearHealthResourceRefs: () => this.onClearHealthResourceRefs()
      })

      if (!this.hideModelPicker) {
        ChatComposerModelPickerRow({
          models: this.modelRows,
          selectedModelName: this.selectedModelName,
          onSelect: (name: string | undefined) => this.onSelectModel(name)
        })
      }
    }
    .padding({ bottom: 8 })
    .backgroundColor(ComposerTheme.background)
    .width('100%')
  }
}
