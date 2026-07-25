import { MedicalAttachmentInput } from '../../Home/Presentation/MedicalLists/MedicalDocumentAttachmentUploader';
import { MedicalDocumentTypedExtractionOutput } from '../Domain/MedicalDocumentTypedModels';
import { MedicalDocumentSaveReceipt } from '../Domain/MedicalDocumentAttachmentBindingModels';
import { TypedMedicalDocumentSaving } from '../Domain/TypedMedicalDocumentSaving';

/**
 * 薄封装。对齐 iOS SaveTypedMedicalDocumentUseCase。
 */
export class SaveTypedMedicalDocumentUseCase {
  private readonly saver: TypedMedicalDocumentSaving;

  constructor(saver: TypedMedicalDocumentSaving) {
    this.saver = saver;
  }

  async execute(
    output: MedicalDocumentTypedExtractionOutput,
    sourceFiles: MedicalAttachmentInput[]
  ): Promise<MedicalDocumentSaveReceipt> {
    return this.saver.save(output, sourceFiles);
  }
}
