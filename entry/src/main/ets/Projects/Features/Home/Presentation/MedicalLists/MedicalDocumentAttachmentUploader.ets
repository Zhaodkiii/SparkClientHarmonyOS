import { FileUploadRequest, ManagedFileRecord } from '../../../../../Core/FileStorage/FileStorageModels';
import { FileTransferService } from '../../../../../Core/FileStorage/FileTransferService';

/**
 * 待上传的本地医疗附件，对齐 iOS `MedicalUploadLocalFile`。
 * 选择器返回时通常只有本地 URI；上传成功后回填 `remoteFile`。
 */
export class MedicalAttachmentInput {
  previewId: string = '';
  sourceUri: string = '';
  originalName: string = '';
  mimeType: string = 'application/octet-stream';
  /** 单文件 OCR 文本；后续 OCR 步骤回填，上传步骤不写入。 */
  ocrText: string = '';
  /** 上传成功后的远端文件元数据（register 结果）。 */
  remoteFile?: ManagedFileRecord;

  withRemoteFile(record: ManagedFileRecord): MedicalAttachmentInput {
    const copy = new MedicalAttachmentInput();
    copy.previewId = this.previewId;
    copy.sourceUri = this.sourceUri;
    copy.originalName = this.originalName;
    copy.mimeType = this.mimeType;
    copy.ocrText = this.ocrText;
    copy.remoteFile = record;
    return copy;
  }

  withOCRText(text: string): MedicalAttachmentInput {
    const copy = new MedicalAttachmentInput();
    copy.previewId = this.previewId;
    copy.sourceUri = this.sourceUri;
    copy.originalName = this.originalName;
    copy.mimeType = this.mimeType;
    copy.ocrText = text;
    copy.remoteFile = this.remoteFile;
    return copy;
  }
}

/**
 * 医疗文档源文件上传，对齐 iOS `UploadMedicalDocumentFilesUseCase`：
 * 统一 `businessType=medical_document_upload_source`，`businessId=memberID`。
 * 只负责把已选文件交给 `FileTransferService`；不做 OCR/识别，不决定最终业务绑定。
 */
export class MedicalDocumentAttachmentUploader {
  static readonly BUSINESS_TYPE: string = 'medical_document_upload_source';

  private readonly fileTransfer: FileTransferService;
  private readonly getAccountId: () => number | undefined;
  private readonly getGeneration: () => number;

  constructor(
    fileTransfer: FileTransferService,
    getAccountId: () => number | undefined,
    getGeneration: () => number
  ) {
    this.fileTransfer = fileTransfer;
    this.getAccountId = getAccountId;
    this.getGeneration = getGeneration;
  }

  async upload(
    input: MedicalAttachmentInput,
    memberID: number,
    onProgress?: (progress: number) => void
  ): Promise<ManagedFileRecord> {
    const accountId = this.getAccountId();
    if (accountId === undefined || accountId <= 0) {
      throw new Error('accountRequired');
    }
    if (input.sourceUri.length === 0 || input.originalName.length === 0) {
      throw new Error('attachmentSourceInvalid');
    }
    const request = new FileUploadRequest();
    request.transferId = input.previewId.length > 0 ? input.previewId : `medical_${Date.now()}`;
    request.accountId = accountId;
    request.generation = this.getGeneration();
    request.sourceUri = input.sourceUri;
    request.originalName = input.originalName;
    request.mimeType = input.mimeType;
    request.businessType = MedicalDocumentAttachmentUploader.BUSINESS_TYPE;
    request.businessId = `${memberID}`;
    request.isPublic = false;
    return this.fileTransfer.upload(request, (snapshot) => {
      if (onProgress) {
        onProgress(Math.max(0, Math.min(1, snapshot.progress)));
      }
    });
  }
}
