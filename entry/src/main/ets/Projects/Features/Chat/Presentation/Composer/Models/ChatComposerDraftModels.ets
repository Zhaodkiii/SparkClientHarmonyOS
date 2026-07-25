import { util } from '@kit.ArkTS';
import { HealthResourceRef } from './HealthResourceRef';

export enum ChatComposerAttachmentSource {
  PHOTO_LIBRARY = 'photoLibrary',
  CAMERA = 'camera',
  DOCUMENT = 'document'
}

export enum ChatComposerAttachmentKind {
  IMAGE = 'image',
  PDF = 'pdf',
  FILE = 'file'
}

export interface ChatComposerAttachmentPreviewParams {
  source: ChatComposerAttachmentSource;
  kind?: ChatComposerAttachmentKind;
  sourceUri: string;
  displayName: string;
  mimeType?: string;
  id?: string;
}

/** UI 预览附件；发送前仍由页面走 ChatAttachmentPreprocessor。 */
export class ChatComposerAttachmentPreview {
  id: string = '';
  source: ChatComposerAttachmentSource = ChatComposerAttachmentSource.PHOTO_LIBRARY;
  kind: ChatComposerAttachmentKind = ChatComposerAttachmentKind.IMAGE;
  sourceUri: string = '';
  displayName: string = '';
  mimeType?: string;

  static create(params: ChatComposerAttachmentPreviewParams): ChatComposerAttachmentPreview {
    const preview = new ChatComposerAttachmentPreview();
    preview.id = params.id ?? util.generateRandomUUID(true);
    preview.source = params.source;
    preview.kind = params.kind ?? ChatComposerAttachmentKind.IMAGE;
    preview.sourceUri = params.sourceUri;
    preview.displayName = params.displayName;
    preview.mimeType = params.mimeType;
    return preview;
  }

  get isImage(): boolean {
    return this.kind === ChatComposerAttachmentKind.IMAGE;
  }

  get isPDF(): boolean {
    return this.kind === ChatComposerAttachmentKind.PDF;
  }
}

export class ChatComposerRuntimeFlags {
  useTools: boolean = false;
  useKnowledgeBase: boolean = true;
  useWebSearch: boolean = true;
  reasoningEnabled: boolean = false;
  reasoningEffortTier: number = 1;
  selectedChatModelName?: string;
}

export function defaultRuntimeFlags(): ChatComposerRuntimeFlags {
  return new ChatComposerRuntimeFlags();
}

export class ChatComposerDraft {
  text: string = '';
  attachments: ChatComposerAttachmentPreview[] = [];
  runtimeFlags: ChatComposerRuntimeFlags = defaultRuntimeFlags();
  isShowingAttachmentMenu: boolean = false;
  isShowingPhotoPicker: boolean = false;
  isShowingCamera: boolean = false;
  previewSelection?: string;
  pendingHealthResourceRefs: HealthResourceRef[] = [];

  get trimmedText(): string {
    return this.text.trim();
  }

  get hasVisualContent(): boolean {
    return this.trimmedText.length > 0
      || this.attachments.length > 0
      || this.pendingHealthResourceRefs.length > 0;
  }
}

export class ChatModelReasoningContext {
  supportsReasoning: boolean = true;
  reasoningControllable: boolean = true;
  providerCompany?: string;

  static make(
    supportsReasoning: boolean,
    reasoningControllable: boolean,
    providerCompany?: string
  ): ChatModelReasoningContext {
    const ctx = new ChatModelReasoningContext();
    ctx.supportsReasoning = supportsReasoning;
    ctx.reasoningControllable = reasoningControllable;
    ctx.providerCompany = providerCompany;
    return ctx;
  }
}

export function defaultModelReasoning(): ChatModelReasoningContext {
  return ChatModelReasoningContext.make(true, true, undefined);
}

/** 深度思考菜单供应商差异，对标 iOS ProviderRegistry。 */
export class ComposerProviderRegistry {
  static showsReasoningDepthMenu(providerCompany?: string): boolean {
    const company = (providerCompany ?? '').trim().toUpperCase();
    if (company.length === 0) {
      return true;
    }
    return company !== 'OPENAI';
  }

  static usesHighMaxReasoningEffortUI(providerCompany?: string): boolean {
    const company = (providerCompany ?? '').trim().toUpperCase();
    return company === 'OPENAI' || company.indexOf('OAI') >= 0;
  }
}

/** bindMenu 用的显式菜单项类型（ArkTS 禁止内联对象字面量类型）。 */
export class ComposerMenuActionItem {
  value: string = '';
  action: () => void = () => {};

  constructor(value: string, action: () => void) {
    this.value = value;
    this.action = action;
  }
}
