import { MedicineBoxRecognitionDraft } from '../../../../MedicalDocumentUpload/Domain/MedicalDocumentRecognitionDrafts';
import { RemoteMedicineBox, RemoteManagedFile } from '../../../../../Core/Networking/API/Medical/MedicalSyncAPI';
import { nilIfBlank } from './MedicalFileUtils';
import { MedicineBoxFormModel } from './MedicineBoxFormModel';

/** 药箱草稿与远端 DTO 互转，对齐 iOS `PrescriptionRecognitionDraftMapper` 药箱分支。 */
export class MedicineBoxDraftMapping {
  static cloneDraft(draft: MedicineBoxRecognitionDraft): MedicineBoxRecognitionDraft {
    const cloned = new MedicineBoxRecognitionDraft();
    cloned.medicineName = draft.medicineName;
    cloned.medicineType = draft.medicineType;
    cloned.brandName = draft.brandName;
    cloned.dosageForm = draft.dosageForm;
    cloned.strength = draft.strength;
    cloned.doseUnit = draft.doseUnit;
    cloned.totalQuantity = draft.totalQuantity;
    cloned.expireDate = draft.expireDate;
    cloned.notes = draft.notes;
    cloned.sortOrder = draft.sortOrder;
    cloned.attachmentFileIds = draft.attachmentFileIds.slice();
    if (draft.extra) {
      cloned.extra = new Map<string, string>();
      draft.extra.forEach((value: string, key: string) => {
        cloned.extra?.set(key, value);
      });
    }
    return cloned;
  }

  static cloneBox(box: RemoteMedicineBox): RemoteMedicineBox {
    const cloned = new RemoteMedicineBox();
    cloned.id = box.id;
    cloned.member = box.member;
    cloned.medicineName = box.medicineName;
    cloned.medicineType = box.medicineType;
    cloned.brandName = box.brandName;
    cloned.dosageForm = box.dosageForm;
    cloned.strength = box.strength;
    cloned.doseUnit = box.doseUnit;
    cloned.totalQuantity = box.totalQuantity;
    cloned.expireDate = box.expireDate;
    cloned.notes = box.notes;
    const extraCopy: Record<string, string> = {};
    const extraKeys = Object.keys(box.extra);
    for (let i = 0; i < extraKeys.length; i++) {
      const key = extraKeys[i];
      extraCopy[key] = box.extra[key];
    }
    cloned.extra = extraCopy;
    cloned.attachments = box.attachments.slice();
    cloned.updatedAt = box.updatedAt;
    cloned.isArchived = box.isArchived;
    cloned.archivedAt = box.archivedAt;
    return cloned;
  }

  static medicineBoxDraftFromBox(box: RemoteMedicineBox): MedicineBoxRecognitionDraft {
    return MedicineBoxFormModel.fromBox(box).toRecognitionDraft();
  }

  static remoteMedicineBoxFromDraft(
    draft: MedicineBoxRecognitionDraft,
    memberID: number,
    id: number
  ): RemoteMedicineBox {
    const box = new RemoteMedicineBox();
    box.id = id;
    box.member = memberID;
    box.medicineName = nilIfBlank(draft.medicineName) ?? '';
    box.medicineType = nilIfBlank(draft.medicineType);
    box.brandName = nilIfBlank(draft.brandName) ?? '';
    box.dosageForm = nilIfBlank(draft.dosageForm) ?? '';
    box.strength = nilIfBlank(draft.strength) ?? '';
    box.doseUnit = nilIfBlank(draft.doseUnit) ?? '';
    if (nilIfBlank(draft.totalQuantity) !== undefined) {
      const quantity = Number(draft.totalQuantity);
      if (Number.isFinite(quantity)) {
        box.totalQuantity = quantity;
      }
    }
    box.expireDate = nilIfBlank(draft.expireDate);
    box.notes = nilIfBlank(draft.notes) ?? '';
    if (draft.extra) {
      const extra: Record<string, string> = {};
      draft.extra.forEach((value: string, key: string) => {
        extra[key] = value;
      });
      box.extra = extra;
    }
    box.attachments = [];
    return box;
  }
}
