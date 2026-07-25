import { FileUploadRequest, ManagedFileRecord } from '../../../../Core/FileStorage/FileStorageModels';
import { FileTransferService } from '../../../../Core/FileStorage/FileTransferService';
import { ChatAttachmentKind } from '../Domain/ChatModels';
import { ChatAttachmentAssembly, ChatPreparedAttachment } from './ChatAttachmentAssembly';

export type ChatComposerAttachmentPhase = 'pending' | 'uploading' | 'ocring' | 'success' | 'failed';

export class ChatComposerAttachmentInput {
  previewId: string = '';
  sourceUri: string = '';
  originalName: string = '';
  mimeType: string = 'application/octet-stream';
  kind: ChatAttachmentKind = 'file';
}

export class ChatComposerAttachmentProgress {
  previewId: string = '';
  phase: ChatComposerAttachmentPhase = 'pending';
  progress: number = 0;
  errorMessage?: string;
  prepared?: ChatPreparedAttachment;
}

export type ChatAttachmentProgressHandler = (progress: ChatComposerAttachmentProgress) => void;

export interface ChatAttachmentOCRAdapter {
  recognizeImage(sourceUri: string): Promise<string>;
  recognizeDocument(sourceUri: string, mimeType: string): Promise<string>;
}

class EmptyChatAttachmentOCRAdapter implements ChatAttachmentOCRAdapter {
  async recognizeImage(sourceUri: string): Promise<string> {
    void sourceUri;
    return '';
  }

  async recognizeDocument(sourceUri: string, mimeType: string): Promise<string> {
    void sourceUri;
    void mimeType;
    return '';
  }
}

/**
 * 作曲器附件预处理：上传是生产路径，OCR 通过明确适配器注入。
 * 未装配 Vision Kit 时只返回空 OCR，不伪造文字，并保留原图可发送语义。
 */
export class ChatAttachmentPreprocessor {
  static readonly BUSINESS_TYPE: string = 'chat_attachment';
  private readonly fileTransfer: FileTransferService;
  private readonly getAccountId: () => number | undefined;
  private readonly getGeneration: () => number;
  private readonly ocr: ChatAttachmentOCRAdapter;

  constructor(
    fileTransfer: FileTransferService,
    getAccountId: () => number | undefined,
    getGeneration: () => number,
    ocr?: ChatAttachmentOCRAdapter
  ) {
    this.fileTransfer = fileTransfer;
    this.getAccountId = getAccountId;
    this.getGeneration = getGeneration;
    this.ocr = ocr ?? new EmptyChatAttachmentOCRAdapter();
  }

  async prepare(input: ChatComposerAttachmentInput, handler?: ChatAttachmentProgressHandler): Promise<ChatPreparedAttachment> {
    const accountId = this.getAccountId();
    if (accountId === undefined || accountId <= 0) {
      throw new Error('accountRequired');
    }
    if (input.previewId.length === 0 || input.sourceUri.length === 0 || input.originalName.length === 0) {
      throw new Error('attachmentSourceInvalid');
    }
    const emit = (phase: ChatComposerAttachmentPhase, progress: number, errorMessage?: string): void => {
      if (!handler) return;
      const state = new ChatComposerAttachmentProgress();
      state.previewId = input.previewId;
      state.phase = phase;
      state.progress = progress;
      state.errorMessage = errorMessage;
      handler(state);
    };
    emit('uploading', 0);
    const request = new FileUploadRequest();
    request.transferId = input.previewId;
    request.accountId = accountId;
    request.generation = this.getGeneration();
    request.sourceUri = input.sourceUri;
    request.originalName = input.originalName;
    request.mimeType = input.mimeType;
    request.businessType = ChatAttachmentPreprocessor.BUSINESS_TYPE;
    request.businessId = input.previewId;
    request.isPublic = false;
    try {
      const record = await this.fileTransfer.upload(request, (snapshot) => {
        const progress = Math.max(0, Math.min(0.99, snapshot.progress));
        emit('uploading', progress);
      });
      emit('ocring', 0.99);
      const ocrText = input.kind === 'image'
        ? await this.ocr.recognizeImage(input.sourceUri)
        : await this.ocr.recognizeDocument(input.sourceUri, input.mimeType);
      const url = this.fileTransfer.publicHTTPSURLForObjectKey(record.objectKey);
      const prepared = ChatAttachmentAssembly.fromManagedFile(record, input.kind, ocrText.trim(), url);
      const done = new ChatComposerAttachmentProgress();
      done.previewId = input.previewId;
      done.phase = 'success';
      done.progress = 1;
      done.prepared = prepared;
      if (handler) handler(done);
      return prepared;
    } catch (err) {
      const message = `${err}`;
      emit('failed', 0, message.substring(0, 200));
      throw new Error(message);
    }
  }
}
