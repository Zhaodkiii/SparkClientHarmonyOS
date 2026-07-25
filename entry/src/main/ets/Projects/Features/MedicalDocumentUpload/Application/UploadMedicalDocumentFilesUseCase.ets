import { Logger } from '../../../../Foundation/Logging/Logger';
import { LogModule } from '../../../../Foundation/Logging/LogModule';
import { LogFields } from '../../../../Foundation/Logging/LogEvent';
import {
  MedicalAttachmentInput,
  MedicalDocumentAttachmentUploader
} from '../../Home/Presentation/MedicalLists/MedicalDocumentAttachmentUploader';

export type MedicalDocumentUploadProgressHandler = (
  fileName: string,
  progress: number,
  index: number,
  total: number
) => void;

export type MedicalDocumentUploadFileDoneHandler = (completed: MedicalAttachmentInput[]) => void;

/**
 * 对齐 iOS `UploadMedicalDocumentFilesUseCase`：
 * 批量上传医疗文档源文件，统一 `businessType=medical_document_upload_source`。
 * 不做 OCR / 类型识别 / 业务绑定。
 */
export class UploadMedicalDocumentFilesUseCase {
  private readonly uploader: MedicalDocumentAttachmentUploader;

  constructor(uploader: MedicalDocumentAttachmentUploader) {
    this.uploader = uploader;
  }

  /**
   * @param reuploadAll false 时跳过已有 `remoteFile` 的文件（断点续跑）
   * @param onFileDone 每完成一个文件（含跳过）回调已完成前缀，便于中断后保留远端元数据
   */
  async execute(
    memberID: number,
    files: MedicalAttachmentInput[],
    reuploadAll: boolean = true,
    onProgress?: MedicalDocumentUploadProgressHandler,
    onFileDone?: MedicalDocumentUploadFileDoneHandler
  ): Promise<MedicalAttachmentInput[]> {
    const output: MedicalAttachmentInput[] = [];
    let uploadedCount = 0;
    let skippedCount = 0;
    const total = files.length;

    for (let i = 0; i < files.length; i++) {
      const file = files[i];
      if (!reuploadAll && file.remoteFile !== undefined && file.remoteFile.id > 0) {
        const skipFields = new LogFields();
        skipFields.detail = `name=${file.originalName};fileID=${file.remoteFile.id}`;
        Logger.info('medical.upload.skip_existing', LogModule.HOME, skipFields);
        output.push(file);
        skippedCount += 1;
        if (onFileDone) {
          onFileDone(output.slice());
        }
        continue;
      }

      if (onProgress) {
        onProgress(file.originalName, 0, i, total);
      }
      const record = await this.uploader.upload(file, memberID, (progress: number) => {
        if (onProgress) {
          onProgress(file.originalName, progress, i, total);
        }
      });
      output.push(file.withRemoteFile(record));
      uploadedCount += 1;
      if (onFileDone) {
        onFileDone(output.slice());
      }
    }

    const doneFields = new LogFields();
    doneFields.detail = `total=${output.length};uploaded=${uploadedCount};skipped=${skippedCount}`;
    Logger.info('medical.upload.batch_done', LogModule.HOME, doneFields);
    return output;
  }
}
