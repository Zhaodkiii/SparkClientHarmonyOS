import { MedicineBoxRecognitionDraft } from '../../../../MedicalDocumentUpload/Domain/MedicalDocumentRecognitionDrafts';
import { MedicineBoxWritePayload } from '../../../../../Core/Networking/API/Medical/MedicalWorkflowAPI';
import { RemoteMedicineBox, RemoteManagedFile } from '../../../../../Core/Networking/API/Medical/MedicalSyncAPI';
import { nilIfBlank } from './MedicalFileUtils';

export class MedicineBoxFormModel {
  medicineName: string = '';
  medicineType: string = '';
  brandName: string = '';
  dosageForm: string = '';
  strength: string = '';
  doseUnit: string = '';
  totalQuantity: string = '';
  hasExpireDate: boolean = false;
  expireDate: string = '';
  notes: string = '';
  bindingMemberID?: number;
  /** 已保存附件，仅用于回显；提交时以 `fileIds` 为准 */
  attachments: RemoteManagedFile[] = [];
  /** 已有附件 id + 本次新上传附件 id，提交前由表单页写入 */
  fileIds: number[] = [];

  static fromRecognitionDraft(draft: MedicineBoxRecognitionDraft): MedicineBoxFormModel {
    const model = new MedicineBoxFormModel();
    model.medicineName = draft.medicineName ?? '';
    model.medicineType = draft.medicineType ?? '';
    model.brandName = draft.brandName ?? '';
    model.dosageForm = draft.dosageForm ?? '';
    model.strength = draft.strength ?? '';
    model.doseUnit = draft.doseUnit ?? '';
    model.totalQuantity = draft.totalQuantity ?? '';
    model.hasExpireDate = (draft.expireDate ?? '').length > 0;
    model.expireDate = draft.expireDate ?? '';
    model.notes = draft.notes ?? '';
    return model;
  }

  toRecognitionDraft(): MedicineBoxRecognitionDraft {
    const draft = new MedicineBoxRecognitionDraft();
    draft.medicineName = nilIfBlank(this.medicineName);
    draft.medicineType = nilIfBlank(this.medicineType);
    draft.brandName = nilIfBlank(this.brandName);
    draft.dosageForm = nilIfBlank(this.dosageForm);
    draft.strength = nilIfBlank(this.strength);
    draft.doseUnit = nilIfBlank(this.doseUnit);
    draft.totalQuantity = nilIfBlank(this.totalQuantity);
    draft.expireDate = this.hasExpireDate ? nilIfBlank(this.expireDate) : undefined;
    draft.notes = nilIfBlank(this.notes);
    return draft;
  }

  static fromBox(box: RemoteMedicineBox): MedicineBoxFormModel {
    const model = new MedicineBoxFormModel();
    model.medicineName = box.medicineName;
    model.medicineType = box.medicineType ?? '';
    model.brandName = box.brandName;
    model.dosageForm = box.dosageForm;
    model.strength = box.strength;
    model.doseUnit = box.doseUnit;
    model.totalQuantity = box.totalQuantity === undefined ? '' : `${box.totalQuantity}`;
    model.hasExpireDate = (box.expireDate ?? '').length > 0;
    model.expireDate = box.expireDate ?? '';
    model.notes = box.notes;
    model.bindingMemberID = box.member;
    model.attachments = box.attachments;
    model.fileIds = box.attachments.map((file: RemoteManagedFile): number => file.id);
    return model;
  }

  validate(): string {
    if (this.medicineName.trim().length === 0) {
      return '请输入药品名称';
    }
    if (this.totalQuantity.trim().length > 0) {
      const quantity = Number(this.totalQuantity.trim());
      if (!Number.isFinite(quantity)) {
        return '库存数量必须是数字';
      }
    }
    if (this.hasExpireDate && this.expireDate.trim().length === 0) {
      return '请选择有效期';
    }
    return '';
  }

  toPayload(entryMemberID: number, personal: boolean): MedicineBoxWritePayload {
    const payload = new MedicineBoxWritePayload();
    payload.entry_member_id = entryMemberID;
    payload.member = personal ? entryMemberID : this.bindingMemberID;
    payload.medicine_name = this.medicineName.trim();
    payload.medicine_type = this.medicineType.trim().length > 0 ? this.medicineType.trim() : undefined;
    payload.brand_name = this.brandName.trim();
    payload.dosage_form = this.dosageForm.trim();
    payload.strength = this.strength.trim();
    payload.dose_unit = this.doseUnit.trim();
    if (this.totalQuantity.trim().length > 0) {
      payload.total_quantity = Number(this.totalQuantity.trim());
    }
    payload.expire_date = this.hasExpireDate ? this.expireDate.trim() : undefined;
    payload.notes = this.notes.trim();
    payload.file_ids = this.fileIds;
    return payload;
  }
}
