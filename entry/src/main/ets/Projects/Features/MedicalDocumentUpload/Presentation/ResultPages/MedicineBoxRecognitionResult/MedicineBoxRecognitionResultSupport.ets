import { RemoteMedicineBox } from '../../../../../Core/Networking/API/Medical/MedicalSyncAPI';
import { MedicineBoxDraftMapping } from '../../../../Home/Presentation/MedicalLists/MedicineBox/MedicineBoxDraftMapping';
import { MedicineBoxRecognitionDraft } from '../../../Domain/MedicalDocumentRecognitionDrafts';
import { MedicalDocumentKind } from '../../../Domain/MedicalDocumentKind';
import {
  MedicalPreSubmitValidationIssue,
  MedicalPreSubmitValidationResourceType
} from '../../../Domain/MedicalPreSubmitValidationIssue';
import { MedicalDocumentUploadViewModel } from '../../MedicalDocumentUploadViewModel';
import { MedicalDocumentLocalAttachmentItem } from '../MedicalDocumentLocalAttachmentItem';

export class MedicineBoxRecognitionResultSupport {
  static boxes(viewModel: MedicalDocumentUploadViewModel): MedicineBoxRecognitionDraft[] {
    const tree = viewModel.ensureTypedDraftTree(MedicalDocumentKind.MEDICINE_BOX);
    return tree.medicineBoxDrafts;
  }

  static temporaryMedicineBoxID(index: number): number {
    return -20000 - index;
  }

  static draftForCard(
    viewModel: MedicalDocumentUploadViewModel,
    index: number
  ): MedicineBoxRecognitionDraft | undefined {
    const list = MedicineBoxRecognitionResultSupport.boxes(viewModel);
    if (index < 0 || index >= list.length) {
      return undefined;
    }
    return MedicineBoxDraftMapping.cloneDraft(list[index]);
  }

  static remoteBoxForCard(
    viewModel: MedicalDocumentUploadViewModel,
    index: number,
    memberID: number
  ): RemoteMedicineBox {
    const draft = MedicineBoxRecognitionResultSupport.draftForCard(viewModel, index);
    if (draft === undefined) {
      return new RemoteMedicineBox();
    }
    return MedicineBoxDraftMapping.remoteMedicineBoxFromDraft(
      draft,
      memberID,
      MedicineBoxRecognitionResultSupport.temporaryMedicineBoxID(index)
    );
  }

  static updateBoxDraftAt(
    viewModel: MedicalDocumentUploadViewModel,
    index: number,
    draft: MedicineBoxRecognitionDraft
  ): void {
    const list = MedicineBoxRecognitionResultSupport.boxes(viewModel);
    if (index < 0 || index >= list.length) {
      return;
    }
    let resolved = MedicineBoxDraftMapping.cloneDraft(draft);
    if (resolved.sortOrder === undefined || resolved.sortOrder.trim().length === 0) {
      resolved.sortOrder = list[index].sortOrder;
    }
    if (resolved.attachmentFileIds.length === 0) {
      resolved.attachmentFileIds = list[index].attachmentFileIds.slice();
    }
    list[index] = resolved;
    viewModel.notifyTypedDraftChanged();
  }

  static deleteBoxDraft(viewModel: MedicalDocumentUploadViewModel, index: number): void {
    const list = MedicineBoxRecognitionResultSupport.boxes(viewModel);
    if (index < 0 || index >= list.length) {
      return;
    }
    list.splice(index, 1);
    viewModel.notifyTypedDraftChanged();
  }

  static associatedAttachmentFileIds(boxes: MedicineBoxRecognitionDraft[]): string[] {
    const ids: string[] = [];
    for (let i = 0; i < boxes.length; i++) {
      const fileIds = boxes[i].attachmentFileIds;
      for (let j = 0; j < fileIds.length; j++) {
        if (ids.indexOf(fileIds[j]) < 0) {
          ids.push(fileIds[j]);
        }
      }
    }
    return ids;
  }

  static allLocalAttachments(viewModel: MedicalDocumentUploadViewModel): MedicalDocumentLocalAttachmentItem[] {
    return MedicalDocumentLocalAttachmentItem.fromAttachments(viewModel.selectedFiles);
  }

  static matchedAttachments(
    viewModel: MedicalDocumentUploadViewModel,
    attachmentFileIds: string[]
  ): MedicalDocumentLocalAttachmentItem[] {
    if (attachmentFileIds.length === 0) {
      return [];
    }
    const idSet = new Set<string>(attachmentFileIds);
    const items: MedicalDocumentLocalAttachmentItem[] = [];
    for (let i = 0; i < viewModel.selectedFiles.length; i++) {
      const file = viewModel.selectedFiles[i];
      if (idSet.has(file.previewId)) {
        items.push(MedicalDocumentLocalAttachmentItem.fromAttachment(file));
      }
    }
    return items;
  }

  static unlinkedAttachments(
    viewModel: MedicalDocumentUploadViewModel,
    boxes: MedicineBoxRecognitionDraft[]
  ): MedicalDocumentLocalAttachmentItem[] {
    const associated = new Set<string>(
      MedicineBoxRecognitionResultSupport.associatedAttachmentFileIds(boxes)
    );
    const items: MedicalDocumentLocalAttachmentItem[] = [];
    for (let i = 0; i < viewModel.selectedFiles.length; i++) {
      const file = viewModel.selectedFiles[i];
      if (!associated.has(file.previewId)) {
        items.push(MedicalDocumentLocalAttachmentItem.fromAttachment(file));
      }
    }
    return items;
  }

  static removeAttachmentIDsFromOtherBoxes(
    viewModel: MedicalDocumentUploadViewModel,
    ids: string[],
    exceptIndex: number
  ): void {
    if (ids.length === 0) {
      return;
    }
    const idSet = new Set<string>(ids);
    const list = MedicineBoxRecognitionResultSupport.boxes(viewModel);
    for (let i = 0; i < list.length; i++) {
      if (i === exceptIndex) {
        continue;
      }
      const next: string[] = [];
      for (let j = 0; j < list[i].attachmentFileIds.length; j++) {
        const fileId = list[i].attachmentFileIds[j];
        if (!idSet.has(fileId)) {
          next.push(fileId);
        }
      }
      list[i].attachmentFileIds = next;
    }
    viewModel.notifyTypedDraftChanged();
  }

  static setBoxAttachmentIDs(
    viewModel: MedicalDocumentUploadViewModel,
    index: number,
    ids: string[]
  ): void {
    const list = MedicineBoxRecognitionResultSupport.boxes(viewModel);
    if (index < 0 || index >= list.length) {
      return;
    }
    MedicineBoxRecognitionResultSupport.removeAttachmentIDsFromOtherBoxes(viewModel, ids, index);
    list[index].attachmentFileIds = ids.slice();
    viewModel.notifyTypedDraftChanged();
  }

  static cardIssues(
    viewModel: MedicalDocumentUploadViewModel,
    index: number
  ): MedicalPreSubmitValidationIssue[] {
    return viewModel.preSubmitValidationIssues.filter(
      (issue: MedicalPreSubmitValidationIssue): boolean =>
        issue.resourceType === MedicalPreSubmitValidationResourceType.MEDICINE_BOX &&
        issue.cardIndex === index
    );
  }

  static issueSummaryLines(viewModel: MedicalDocumentUploadViewModel, index: number): string[] {
    const issues = MedicineBoxRecognitionResultSupport.cardIssues(viewModel, index);
    const lines: string[] = [];
    const limit = issues.length > 2 ? 2 : issues.length;
    for (let i = 0; i < limit; i++) {
      lines.push(issues[i].summaryLine());
    }
    return lines;
  }

  static err(viewModel: MedicalDocumentUploadViewModel, fieldKey: string): string {
    return viewModel.preSubmitIssueMessage(fieldKey);
  }

  static pageSubtitle(viewModel: MedicalDocumentUploadViewModel): string {
    const count = MedicineBoxRecognitionResultSupport.boxes(viewModel).length;
    return `共 ${count} 个药品条目`;
  }
}
