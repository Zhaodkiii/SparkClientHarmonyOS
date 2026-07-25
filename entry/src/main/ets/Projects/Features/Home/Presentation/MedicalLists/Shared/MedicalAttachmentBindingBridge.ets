import { MedicalAttachmentInput } from '../MedicalDocumentAttachmentUploader';
import { MedicalDocumentAttachmentBindingMapper } from '../../../../MedicalDocumentUpload/Domain/MedicalDocumentAttachmentBindingMapper';
import {
  HealthExamRecognitionDraft,
  MedicineBoxRecognitionDraft
} from '../../../../MedicalDocumentUpload/Domain/MedicalDocumentRecognitionDrafts';
import {
  HealthExamSavePayload,
  MedicineBoxWritePayload
} from '../../../../../Core/Networking/API/Medical/MedicalWorkflowAPI';

/**
 * 各业务结果页共享的附件桥接：把草稿 attachmentFileIds 写入保存载荷 file_ids。
 * 对齐工单 0007 Shared 桥接；事实源仍是 typedDrafts。
 */
export class MedicalAttachmentBindingBridge {
  static applyHealthExamFileIds(
    payload: HealthExamSavePayload,
    draft: HealthExamRecognitionDraft,
    sourceFiles: MedicalAttachmentInput[]
  ): HealthExamSavePayload {
    return MedicalDocumentAttachmentBindingMapper.applyFileIdsToHealthExamPayload(
      payload, draft, sourceFiles
    );
  }

  static applyMedicineBoxFileIds(
    payload: MedicineBoxWritePayload,
    draft: MedicineBoxRecognitionDraft,
    sourceFiles: MedicalAttachmentInput[],
    fallbackAllWhenEmpty: boolean = true
  ): MedicineBoxWritePayload {
    return MedicalDocumentAttachmentBindingMapper.applyFileIdsToMedicineBoxPayload(
      payload, draft, sourceFiles, fallbackAllWhenEmpty
    );
  }

  static remoteFileIdsFromLocal(
    matchedLocalFileIds: string[],
    sourceFiles: MedicalAttachmentInput[]
  ): number[] {
    return MedicalDocumentAttachmentBindingMapper.remoteFileIdsFromLocal(
      matchedLocalFileIds, sourceFiles
    );
  }
}
