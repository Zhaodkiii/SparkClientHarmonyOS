import { MedicalDocumentKind } from '../Domain/MedicalDocumentKind';
import {
  MedicalDocumentAttachmentBinding,
  MedicalDocumentSaveReceipt
} from '../Domain/MedicalDocumentAttachmentBindingModels';

/**
 * 保存后附件业务绑定编排。对齐 iOS BindUploadedFilesToMedicalBusinessUseCase。
 */
export class BindUploadedFilesToMedicalBusinessUseCase {
  private readonly binder: MedicalDocumentAttachmentBinding;

  constructor(binder: MedicalDocumentAttachmentBinding) {
    this.binder = binder;
  }

  async execute(
    remoteFileIds: number[],
    kind: MedicalDocumentKind,
    receipt: MedicalDocumentSaveReceipt
  ): Promise<void> {
    await this.binder.bind(remoteFileIds, kind, receipt);
  }
}
