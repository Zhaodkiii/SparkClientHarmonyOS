import { ManagedFileRecord } from '../../../../Core/FileStorage/FileStorageModels';
import { FilePreviewInput } from '../../../Core/UI/FilePreview/FilePreviewInput';
import { MedicalAttachmentInput } from '../../Home/Presentation/MedicalLists/MedicalDocumentAttachmentUploader';
import { MedicalDocumentKind } from './MedicalDocumentKind';

/** 进入医疗文档上传流程的业务来源，对齐 iOS 外部唤起和页面入口语义。 */
export enum MedicalDocumentUploadEntrySource {
  HOME = 'home',
  SECOND_CAMERA = 'secondCamera',
  CHAT = 'chat',
  EXTERNAL_PDF = 'externalPdf'
}

/** 上传页的整体阶段，对齐 iOS `MedicalDocumentUploadViewModel.Stage`。 */
export enum MedicalDocumentUploadStage {
  PICKING = 'picking',
  PROCESSING = 'processing',
  RESULT = 'result'
}

/** 本地附件上传状态（前两阶段）。 */
export type MedicalUploadFileState = 'pending' | 'uploading' | 'uploaded' | 'failed';

/**
 * AI 上传报告领域本地文件模型（工单 5.4）。
 * Presentation / Infrastructure 产出此模型；上传 UseCase 经适配器转 MedicalAttachmentInput。
 */
export class MedicalUploadLocalFile {
  localId: string = '';
  uri: string = '';
  displayName: string = '';
  mimeType: string = 'application/octet-stream';
  sizeBytes: number = 0;
  fileMd5: string = '';
  remoteFile?: ManagedFileRecord;
  uploadState: MedicalUploadFileState = 'pending';
  /** 单文件 OCR 文本；本工单不写入。 */
  ocrText: string = '';

  static fromAttachment(input: MedicalAttachmentInput): MedicalUploadLocalFile {
    const file = new MedicalUploadLocalFile();
    file.localId = input.previewId;
    file.uri = input.sourceUri;
    file.displayName = input.originalName;
    file.mimeType = input.mimeType;
    file.ocrText = input.ocrText;
    file.remoteFile = input.remoteFile;
    if (input.remoteFile !== undefined && input.remoteFile.id > 0) {
      file.uploadState = 'uploaded';
      file.sizeBytes = input.remoteFile.fileSize;
      file.fileMd5 = input.remoteFile.fileMd5;
    }
    return file;
  }

  toAttachment(): MedicalAttachmentInput {
    const input = new MedicalAttachmentInput();
    input.previewId = this.localId.length > 0 ? this.localId : `medical_pending_${Date.now()}`;
    input.sourceUri = this.uri;
    input.originalName = this.displayName;
    input.mimeType = this.mimeType;
    input.ocrText = this.ocrText;
    input.remoteFile = this.remoteFile;
    return input;
  }

  /** 对齐 iOS `MedicalUploadLocalFile.previewInput`。 */
  previewInput(): FilePreviewInput {
    const displayName = this.displayName.length > 0 ? this.displayName : '医疗附件';
    return FilePreviewInput.create(
      this.uri,
      displayName,
      this.mimeType,
      this.localId.length > 0 ? this.localId : undefined
    );
  }
}

/** 已上传源文件，供 OCR 阶段消费。 */
export class UploadedMedicalDocumentFile {
  localId: string = '';
  remoteFile: ManagedFileRecord = new ManagedFileRecord();
  sourceBusinessType: string = 'medical_document_upload_source';
  sourceBusinessId: string = '';
}

/**
 * 上传完成后交给 OCR 的最小输入（工单 5.5 / 0002）。
 * OCR 未接入时仍生成此对象，便于断点恢复与下游独立接入。
 */
export class MedicalDocumentOCRInput {
  uploadSessionId: string = '';
  memberId: number = 0;
  selectedKind: MedicalDocumentKind = MedicalDocumentKind.AUTO;
  files: UploadedMedicalDocumentFile[] = [];
  reRecognizeAll: boolean = false;
}

/** 路由进入参数；外部 PDF / 相机 / 聊天通过同一参数进入。 */
export class MedicalDocumentUploadEntry {
  source: MedicalDocumentUploadEntrySource = MedicalDocumentUploadEntrySource.HOME;
  memberId: number = 0;
  memberName: string = '';
  preferredKind?: MedicalDocumentKind;
  /** 入口预填文件（相机抓拍 / 外部 PDF）。 */
  initialFiles: MedicalAttachmentInput[] = [];
  /**
   * 兼容旧调用方；新代码请写 initialFiles。
   * prepareForEntry 会合并二者（initialFiles 优先）。
   */
  externalFiles: MedicalAttachmentInput[] = [];
}

/** 流水线能力开关：未实现能力必须显式为 false，禁止在深处抛通用错误。 */
export class MedicalDocumentUploadCapabilities {
  upload: boolean = true;
  ocr: boolean = false;
  typeRecognition: boolean = false;
  extraction: boolean = false;
  /** 抽取后本地附件匹配（无网络）。 */
  attachmentBinding: boolean = false;
  save: boolean = false;
}
