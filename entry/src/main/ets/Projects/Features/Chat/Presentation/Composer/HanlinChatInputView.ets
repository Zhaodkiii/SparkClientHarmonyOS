import { Member } from '../../../../Core/Domain/Entities/Member';
import {
  ChatComposerAttachmentPreview,
  ChatModelReasoningContext,
  defaultModelReasoning
} from './Models/ChatComposerDraftModels';
import { HealthResourceRef } from './Models/HealthResourceRef';
import { ComposerTheme } from './Models/ComposerTheme';
import { HanlinChatTextView } from './HanlinChatTextView';
import { HanlinAttachmentThumbnail } from './HanlinAttachmentThumbnail';
import { HanlinAttachmentSheet } from './HanlinAttachmentSheet';
import { HanlinHealthResourceThumbnail } from './HanlinHealthResourceThumbnail';
import { ChatComposerRuntimeTogglesRow } from './ChatComposerRuntimeTogglesRow';
import { SparkVoiceInputSheet } from './SparkVoiceInputSheet';

/**
 * 专业版输入区主体，对标 iOS HanlinChatInputView。
 * 状态以 @Link/@Prop + 回调承接，发送/附件预处理仍由 ChatTabPage 管线负责。
 */
@Component
export struct HanlinChatInputView {
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
  @Prop canOpenCamera: boolean = false;
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

  @State private attachmentMenuOpen: boolean = false;
  @State private voiceInputSheet: boolean = false;
  @State private previewSelection: string = '';

  private canSendPayload(): boolean {
    const hasContent = this.draft.trim().length > 0
      || this.attachments.length > 0
      || this.healthResourceRefs.length > 0;
    const attachmentsReady = this.attachments.length === this.preparedAttachmentCount;
    return !this.running && hasContent && attachmentsReady;
  }

  private composerAttachmentAreaHasContent(): boolean {
    return this.attachments.length > 0 || this.healthResourceRefs.length > 0;
  }

  private plusForeground(): string {
    if (this.running || this.attachments.length > 4) {
      return ComposerTheme.gray;
    }
    if (this.attachmentMenuOpen) {
      return ComposerTheme.systemRed;
    }
    return ComposerTheme.accent;
  }

  private uploadProgressFor(_id: string): number {
    if (this.attachments.length === this.preparedAttachmentCount) {
      return -1;
    }
    return 0.45;
  }

  build() {
    Column({ space: 6 }) {
      if (this.composerAttachmentAreaHasContent()) {
        this.composerAttachmentArea()
      }

      if (this.attachmentStatus.length > 0) {
        Text(this.attachmentStatus)
          .fontSize(12)
          .fontColor(ComposerTheme.textTertiary)
          .width('100%')
          .padding({ left: 12, right: 12 })
      }

      Column({ space: 0 }) {
        Row() {
          HanlinChatTextView({
            text: $draft,
            minimumHeight: 44,
            maximumHeight: 160,
            isSending: this.running,
            placeholder: '请输入你的问题'
          })
            .layoutWeight(1)
        }
        .padding({ left: 12, right: 12, top: 10 })

        Row({ space: 6 }) {
          this.plusButton()

          ChatComposerRuntimeTogglesRow({
            disabled: this.running,
            useTools: $useTools,
            useKnowledgeBase: $useKnowledgeBase,
            useWebSearch: $useWebSearch,
            reasoningEnabled: $reasoningEnabled,
            reasoningEffortTier: $reasoningEffortTier,
            modelReasoning: this.modelReasoning,
            members: this.members,
            boundMemberID: this.boundMemberID,
            defaultMemberID: this.defaultMemberID,
            onSetMemberBinding: (memberID: number) => {
              this.onSetMemberBinding(memberID);
            }
          })
            .layoutWeight(1)

          this.voiceButton()
          this.trailingSendControl()
        }
        .width('100%')
        .padding({ left: 6, right: 6, bottom: 8 })
      }
      .backgroundColor(ComposerTheme.secondaryBackground)
      .borderRadius(20)
      .margin({ left: 12, right: 12 })
    }
    .bindSheet(this.attachmentMenuOpen, this.attachmentSheetBuilder(), {
      height: SheetSize.MEDIUM,
      dragBar: true,
      onDisappear: () => {
        this.attachmentMenuOpen = false;
      }
    })
    .bindSheet(this.voiceInputSheet, this.voiceSheetBuilder(), {
      height: SheetSize.MEDIUM,
      dragBar: true,
      onDisappear: () => {
        this.voiceInputSheet = false;
      }
    })
  }

  @Builder
  private composerAttachmentArea() {
    Column({ space: 8 }) {
      if (this.attachments.length > 0) {
        this.attachmentStrip()
      }
      if (this.healthResourceRefs.length > 0) {
        this.healthResourcePreviewStrip()
      }
    }
    .alignItems(HorizontalAlign.Start)
    .padding({ left: 12, right: 12, top: 8 })
  }

  @Builder
  private healthResourcePreviewStrip() {
    Row({ space: 8 }) {
      Scroll() {
        Row({ space: 10 }) {
          ForEach(this.healthResourceRefs, (ref: HealthResourceRef, index: number) => {
            HanlinHealthResourceThumbnail({
              refItem: ref,
              index: index + 1,
              total: this.healthResourceRefs.length,
              onTap: () => {
                // 健康资料详情预览后续接入
              },
              onRemove: () => this.onRemoveHealthResourceRef(ref)
            })
          }, (ref: HealthResourceRef) => ref.id)
        }
        .padding({ left: 2, right: 2 })
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .layoutWeight(1)

      if (this.healthResourceRefs.length > 1) {
        Text('清空全部')
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor(ComposerTheme.textSecondary)
          .onClick(() => this.onClearHealthResourceRefs())
      }
    }
  }

  @Builder
  private attachmentStrip() {
    Scroll() {
      Row({ space: 10 }) {
        ForEach(this.attachments, (attachment: ChatComposerAttachmentPreview) => {
          HanlinAttachmentThumbnail({
            attachment: attachment,
            uploadProgress: this.uploadProgressFor(attachment.id),
            isSelected: this.previewSelection === attachment.id,
            onTap: () => {
              this.previewSelection = attachment.id;
              this.onSelectAttachment(attachment.id);
            },
            onRemove: () => this.onRemoveAttachment(attachment.id)
          })
        }, (attachment: ChatComposerAttachmentPreview) => attachment.id)
      }
      .padding({ left: 2, right: 2 })
    }
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Off)
  }

  @Builder
  private plusButton() {
    SymbolGlyph($r('sys.symbol.plus'))
      .fontSize(28)
      .fontColor([this.plusForeground()])
      .rotate({ angle: this.attachmentMenuOpen ? 45 : 0 })
      .animation({ duration: 300, curve: Curve.Friction })
      .opacity((this.running || this.attachments.length > 4) ? 0.4 : 1)
      .width(36)
      .height(36)
      .onClick(() => {
        if (this.running || this.attachments.length > 4) {
          return;
        }
        this.attachmentMenuOpen = true;
      })
  }

  @Builder
  private voiceButton() {
    Text('🎤')
      .fontSize(20)
      .width(32)
      .height(32)
      .textAlign(TextAlign.Center)
      .opacity(this.running ? 0.4 : 1)
      .onClick(() => {
        if (!this.running) {
          this.voiceInputSheet = true;
        }
      })
  }

  @Builder
  private trailingSendControl() {
    if (this.running) {
      SymbolGlyph($r('sys.symbol.stop_circle_fill'))
        .fontSize(30)
        .fontColor([ComposerTheme.systemRed])
        .width(36)
        .height(36)
        .onClick(() => this.onCancel())
    } else if (this.canSendPayload()) {
      SymbolGlyph($r('sys.symbol.arrowtriangle_up_fill'))
        .fontSize(30)
        .fontColor([ComposerTheme.accent])
        .width(36)
        .height(36)
        .onClick(() => this.onSend())
    } else {
      SymbolGlyph($r('sys.symbol.arrowtriangle_up_fill'))
        .fontSize(30)
        .fontColor([ComposerTheme.gray])
        .width(36)
        .height(36)
    }
  }

  @Builder
  private attachmentSheetBuilder() {
    HanlinAttachmentSheet({
      isCameraAvailable: this.canOpenCamera,
      onPhotos: () => {
        this.attachmentMenuOpen = false;
        this.onPickImages();
      },
      onCamera: () => {
        this.attachmentMenuOpen = false;
        this.onPickCamera();
      },
      onFiles: () => {
        this.attachmentMenuOpen = false;
        this.onPickFiles();
      }
    })
  }

  @Builder
  private voiceSheetBuilder() {
    SparkVoiceInputSheet({
      text: $draft,
      onClose: () => {
        this.voiceInputSheet = false;
      }
    })
  }
}
