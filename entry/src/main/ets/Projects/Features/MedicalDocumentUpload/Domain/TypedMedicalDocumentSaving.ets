import { MedicalDocumentKind } from './MedicalDocumentKind';
import { MedicalDocumentTypedExtractionOutput } from './MedicalDocumentTypedModels';
import { MedicalDocumentSaveReceipt } from './MedicalDocumentAttachmentBindingModels';
import { MedicalAttachmentInput } from '../../Home/Presentation/MedicalLists/MedicalDocumentAttachmentUploader';

/** 对齐 iOS TypedMedicalDocumentSaving。 */
export interface TypedMedicalDocumentSaving {
  save(
    output: MedicalDocumentTypedExtractionOutput,
    sourceFiles: MedicalAttachmentInput[]
  ): Promise<MedicalDocumentSaveReceipt>;
}

export class MedicalDocumentSaveError extends Error {
  readonly code: string;

  constructor(code: string, message: string) {
    super(message);
    this.code = code;
    this.name = 'MedicalDocumentSaveError';
  }

  static noMember(): MedicalDocumentSaveError {
    return new MedicalDocumentSaveError('no_member', '缺少成员，无法保存');
  }

  static emptyDraft(kind: MedicalDocumentKind): MedicalDocumentSaveError {
    return new MedicalDocumentSaveError('empty_draft', `没有可保存的${kind}草稿`);
  }

  static unsupported(kind: MedicalDocumentKind): MedicalDocumentSaveError {
    return new MedicalDocumentSaveError('unsupported_kind', `不支持保存类型：${kind}`);
  }
}
