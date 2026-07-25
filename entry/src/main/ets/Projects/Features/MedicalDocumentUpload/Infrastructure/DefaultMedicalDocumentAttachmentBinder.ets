import { FileTransferService } from '../../../../Core/FileStorage/FileTransferService';
import { Logger } from '../../../../Foundation/Logging/Logger';
import { LogFields } from '../../../../Foundation/Logging/LogEvent';
import { LogModule } from '../../../../Foundation/Logging/LogModule';
import { MedicalDocumentKind } from '../Domain/MedicalDocumentKind';
import {
  MedicalDocumentAttachmentBinding,
  MedicalDocumentAttachmentBusinessTypes,
  MedicalDocumentSaveReceipt
} from '../Domain/MedicalDocumentAttachmentBindingModels';

/**
 * 保存后把远端文件 businessType/businessId 回写到最终业务。
 * 对齐 iOS DefaultMedicalDocumentAttachmentBinder。
 */
export class DefaultMedicalDocumentAttachmentBinder implements MedicalDocumentAttachmentBinding {
  private readonly fileTransfer: FileTransferService;
  private readonly getGeneration: () => number;

  constructor(
    fileTransfer: FileTransferService,
    getGeneration: () => number = (): number => 0
  ) {
    this.fileTransfer = fileTransfer;
    this.getGeneration = getGeneration;
  }

  async bind(
    remoteFileIds: number[],
    kind: MedicalDocumentKind,
    receipt: MedicalDocumentSaveReceipt
  ): Promise<void> {
    if (!receipt.isSuccess || receipt.recordID <= 0) {
      const fields = new LogFields();
      fields.detail = 'receipt_invalid';
      Logger.warn('medical.upload.attach.bind_skipped', LogModule.HOME, fields);
      return;
    }
    const businessType = MedicalDocumentAttachmentBusinessTypes.forKind(kind);
    const businessId = `${receipt.recordID}`;
    const generation = this.getGeneration();
    for (let i = 0; i < remoteFileIds.length; i++) {
      const fileId = remoteFileIds[i];
      if (fileId <= 0) {
        continue;
      }
      try {
        await this.fileTransfer.updateBusinessBinding(
          fileId, businessType, businessId, generation
        );
      } catch (_e) {
        const errFields = new LogFields();
        errFields.detail = `fileId=${fileId};type=${businessType}`;
        Logger.error('medical.upload.attach.bind_failed', LogModule.HOME, errFields);
      }
    }
    const done = new LogFields();
    done.detail = `count=${remoteFileIds.length};type=${businessType};biz=${businessId}`;
    Logger.info('medical.upload.attach.bind_done', LogModule.HOME, done);
  }
}
