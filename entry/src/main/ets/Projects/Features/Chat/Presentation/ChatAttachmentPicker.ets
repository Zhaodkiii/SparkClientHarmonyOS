import { common } from '@kit.AbilityKit';
import { picker } from '@kit.CoreFileKit';
import { ChatAttachmentKind } from '../Domain/ChatModels';
import { ChatComposerAttachmentInput } from '../Infrastructure/ChatAttachmentPreprocessor';

export class ChatPickedAttachment {
  input: ChatComposerAttachmentInput = new ChatComposerAttachmentInput();
}

/** 通过系统 PhotoViewPicker/DocumentViewPicker 获取 URI，不把系统 URI 直接写入消息。 */
export class ChatAttachmentPicker {
  static async pickImages(context: common.UIAbilityContext): Promise<ChatPickedAttachment[]> {
    const viewPicker = new picker.PhotoViewPicker(context);
    const options = new picker.PhotoSelectOptions();
    options.MIMEType = picker.PhotoViewMIMETypes.IMAGE_TYPE;
    options.maxSelectNumber = 9;
    const result = await viewPicker.select(options);
    return result.photoUris.map((uri: string): ChatPickedAttachment => ChatAttachmentPicker.make(uri, 'image'));
  }

  static async pickDocuments(context: common.UIAbilityContext): Promise<ChatPickedAttachment[]> {
    const viewPicker = new picker.DocumentViewPicker(context);
    const options = new picker.DocumentSelectOptions();
    options.maxSelectNumber = 9;
    options.fileSuffixFilters = ['PDF|.pdf', '文档|.doc,.docx,.txt'];
    const uris = await viewPicker.select(options);
    return uris.map((uri: string): ChatPickedAttachment => ChatAttachmentPicker.make(uri, 'file'));
  }

  private static make(uri: string, kind: ChatAttachmentKind): ChatPickedAttachment {
    const picked = new ChatPickedAttachment();
    const input = new ChatComposerAttachmentInput();
    input.previewId = `preview_${Date.now()}_${Math.floor(Math.random() * 1000000)}`;
    input.sourceUri = uri;
    input.originalName = ChatAttachmentPicker.fileName(uri);
    input.mimeType = kind === 'image' ? 'image/*' : 'application/octet-stream';
    input.kind = kind;
    picked.input = input;
    return picked;
  }

  private static fileName(uri: string): string {
    const clean = uri.split('?')[0];
    const slash = clean.lastIndexOf('/');
    const value = slash >= 0 ? clean.substring(slash + 1) : clean;
    return value.length > 0 ? decodeURIComponent(value) : `attachment_${Date.now()}`;
  }
}
