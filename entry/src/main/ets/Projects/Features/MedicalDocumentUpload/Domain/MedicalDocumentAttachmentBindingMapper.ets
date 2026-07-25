import { MedicalAttachmentInput } from '../../Home/Presentation/MedicalLists/MedicalDocumentAttachmentUploader';
import { MedicalDocumentKind } from './MedicalDocumentKind';
import {
  MedicalDocumentAttachmentBusinessTypes,
  MedicalDocumentAttachmentIdUtils,
  MedicalDocumentAttachmentMatchSummary,
  MedicalDocumentPreparedAttachmentBinding
} from './MedicalDocumentAttachmentBindingModels';
import {
  CaseRecognitionDraft,
  HealthExamRecognitionDraft,
  MedicalDocumentTypedDraftTree,
  MedicalReportRecognitionDraft,
  MedicationPlanRecognitionDraft,
  MedicineBoxRecognitionDraft,
  PrescriptionRecognitionDraft
} from './MedicalDocumentRecognitionDrafts';
import {
  HealthExamSavePayload,
  MedicineBoxWritePayload
} from '../../../Core/Networking/API/Medical/MedicalWorkflowAPI';

/**
 * 本地 attachmentFileIds → 远端 file_ids 映射，以及已确认契约的保存载荷组装。
 * 对齐 iOS DefaultTypedMedicalDocumentSaver.fileIds(from:envelope:)。
 * 0010：只读 typedDrafts，不另起草稿模型。
 */
export class MedicalDocumentAttachmentBindingMapper {
  /**
   * 将草稿上的本地文件 ID（previewId）解析为远端 Int file id。
   */
  static remoteFileIdsFromLocal(
    matchedLocalFileIds: string[],
    files: MedicalAttachmentInput[]
  ): number[] {
    const remoteByLocal = new Map<string, number>();
    for (let i = 0; i < files.length; i++) {
      const file = files[i];
      if (file.remoteFile !== undefined && file.remoteFile.id > 0) {
        remoteByLocal.set(file.previewId, file.remoteFile.id);
      }
    }
    const out: number[] = [];
    for (let i = 0; i < matchedLocalFileIds.length; i++) {
      const remote = remoteByLocal.get(matchedLocalFileIds[i]);
      if (remote !== undefined && out.indexOf(remote) < 0) {
        out.push(remote);
      }
    }
    return out;
  }

  /** 收集草稿树上所有已匹配的本地附件 ID。 */
  static collectMatchedLocalIds(tree: MedicalDocumentTypedDraftTree): string[] {
    let ids: string[] = [];
    switch (tree.kind) {
      case MedicalDocumentKind.CASE_DOCUMENT:
        if (tree.caseDraft !== undefined) {
          ids = MedicalDocumentAttachmentBindingMapper.collectCaseIds(tree.caseDraft);
        }
        break;
      case MedicalDocumentKind.HEALTH_EXAM_REPORT:
        if (tree.healthExamDraft !== undefined) {
          ids = tree.healthExamDraft.attachmentFileIds.slice();
        }
        break;
      case MedicalDocumentKind.MEDICAL_REPORT:
        for (let i = 0; i < tree.medicalReportDrafts.length; i++) {
          ids = MedicalDocumentAttachmentBindingMapper.mergeLocal(
            ids, tree.medicalReportDrafts[i].attachmentFileIds);
        }
        break;
      case MedicalDocumentKind.PRESCRIPTION:
        for (let i = 0; i < tree.prescriptionDrafts.length; i++) {
          ids = MedicalDocumentAttachmentBindingMapper.mergeLocal(
            ids, tree.prescriptionDrafts[i].attachmentFileIds);
          const plans = tree.prescriptionDrafts[i].medicationPlans;
          if (plans !== undefined) {
            for (let j = 0; j < plans.length; j++) {
              ids = MedicalDocumentAttachmentBindingMapper.mergeLocal(
                ids, plans[j].attachmentFileIds);
              if (plans[j].medicineBox !== undefined) {
                ids = MedicalDocumentAttachmentBindingMapper.mergeLocal(
                  ids, plans[j].medicineBox!.attachmentFileIds);
              }
            }
          }
        }
        break;
      case MedicalDocumentKind.MEDICATION_PLAN:
        for (let i = 0; i < tree.medicationPlanDrafts.length; i++) {
          ids = MedicalDocumentAttachmentBindingMapper.mergeLocal(
            ids, tree.medicationPlanDrafts[i].attachmentFileIds);
        }
        break;
      case MedicalDocumentKind.MEDICINE_BOX:
        for (let i = 0; i < tree.medicineBoxDrafts.length; i++) {
          ids = MedicalDocumentAttachmentBindingMapper.mergeLocal(
            ids, tree.medicineBoxDrafts[i].attachmentFileIds);
        }
        break;
      default:
        break;
    }
    return ids;
  }

  /**
   * 从匹配后的 typedDrafts + 源文件组装保存前绑定准备结果。
   * 药箱仅一条且草稿无匹配时，回退全部源文件远端 ID（对齐 iOS）。
   */
  static prepare(
    tree: MedicalDocumentTypedDraftTree,
    files: MedicalAttachmentInput[]
  ): MedicalDocumentPreparedAttachmentBinding {
    const prepared = new MedicalDocumentPreparedAttachmentBinding();
    prepared.kind = tree.kind;
    prepared.businessType = MedicalDocumentAttachmentBusinessTypes.forKind(tree.kind);
    let localIds = MedicalDocumentAttachmentBindingMapper.collectMatchedLocalIds(tree);
    if (tree.kind === MedicalDocumentKind.MEDICINE_BOX &&
      localIds.length === 0 &&
      tree.medicineBoxDrafts.length === 1) {
      localIds = files
        .filter((f: MedicalAttachmentInput): boolean =>
          f.remoteFile !== undefined && f.remoteFile.id > 0)
        .map((f: MedicalAttachmentInput): string => f.previewId);
    }
    prepared.matchedLocalFileIds = localIds;
    prepared.remoteFileIds =
      MedicalDocumentAttachmentBindingMapper.remoteFileIdsFromLocal(localIds, files);
    prepared.fileIdsForSave = prepared.remoteFileIds.slice();
    return prepared;
  }

  /** 组装体检保存载荷的 file_ids（其余字段由调用方/SaveUseCase 填充）。 */
  static applyFileIdsToHealthExamPayload(
    payload: HealthExamSavePayload,
    draft: HealthExamRecognitionDraft,
    files: MedicalAttachmentInput[]
  ): HealthExamSavePayload {
    payload.file_ids = MedicalDocumentAttachmentBindingMapper.remoteFileIdsFromLocal(
      draft.attachmentFileIds, files
    );
    return payload;
  }

  /** 组装药箱保存载荷的 file_ids。 */
  static applyFileIdsToMedicineBoxPayload(
    payload: MedicineBoxWritePayload,
    draft: MedicineBoxRecognitionDraft,
    files: MedicalAttachmentInput[],
    fallbackAllWhenEmpty: boolean = true
  ): MedicineBoxWritePayload {
    let localIds = draft.attachmentFileIds.slice();
    if (localIds.length === 0 && fallbackAllWhenEmpty) {
      localIds = files
        .filter((f: MedicalAttachmentInput): boolean =>
          f.remoteFile !== undefined && f.remoteFile.id > 0)
        .map((f: MedicalAttachmentInput): string => f.previewId);
    }
    payload.file_ids = MedicalDocumentAttachmentBindingMapper.remoteFileIdsFromLocal(
      localIds, files
    );
    return payload;
  }

  static buildMatchSummary(
    tree: MedicalDocumentTypedDraftTree,
    files: MedicalAttachmentInput[]
  ): MedicalDocumentAttachmentMatchSummary {
    const summary = new MedicalDocumentAttachmentMatchSummary();
    summary.kind = tree.kind;
    summary.matchedLocalFileIds =
      MedicalDocumentAttachmentBindingMapper.collectMatchedLocalIds(tree);
    const matchedSet = new Map<string, boolean>();
    for (let i = 0; i < summary.matchedLocalFileIds.length; i++) {
      matchedSet.set(summary.matchedLocalFileIds[i], true);
    }
    for (let i = 0; i < files.length; i++) {
      const id = files[i].previewId;
      if (!matchedSet.has(id)) {
        summary.unmatchedLocalFileIds =
          MedicalDocumentAttachmentIdUtils.appendUnique(summary.unmatchedLocalFileIds, id);
      }
    }
    summary.targetNodeCount = MedicalDocumentAttachmentBindingMapper.countTargetNodes(tree);
    return summary;
  }

  private static collectCaseIds(draft: CaseRecognitionDraft): string[] {
    let ids = draft.attachmentFileIds.slice();
    if (draft.symptom !== undefined) {
      ids = MedicalDocumentAttachmentBindingMapper.mergeLocal(ids, draft.symptom.attachmentFileIds);
    }
    if (draft.visit !== undefined) {
      ids = MedicalDocumentAttachmentBindingMapper.mergeLocal(ids, draft.visit.attachmentFileIds);
    }
    if (draft.surgery !== undefined) {
      ids = MedicalDocumentAttachmentBindingMapper.mergeLocal(ids, draft.surgery.attachmentFileIds);
    }
    if (draft.followUps !== undefined) {
      for (let i = 0; i < draft.followUps.length; i++) {
        ids = MedicalDocumentAttachmentBindingMapper.mergeLocal(
          ids, draft.followUps[i].attachmentFileIds);
      }
    }
    if (draft.examinationReports !== undefined) {
      for (let i = 0; i < draft.examinationReports.length; i++) {
        ids = MedicalDocumentAttachmentBindingMapper.mergeLocal(
          ids, draft.examinationReports[i].attachmentFileIds);
      }
    }
    if (draft.prescriptions !== undefined) {
      for (let i = 0; i < draft.prescriptions.length; i++) {
        ids = MedicalDocumentAttachmentBindingMapper.mergeLocal(
          ids, draft.prescriptions[i].attachmentFileIds);
        const plans = draft.prescriptions[i].medicationPlans;
        if (plans !== undefined) {
          for (let j = 0; j < plans.length; j++) {
            ids = MedicalDocumentAttachmentBindingMapper.mergeLocal(
              ids, plans[j].attachmentFileIds);
          }
        }
      }
    }
    return ids;
  }

  private static mergeLocal(base: string[], extra: string[]): string[] {
    let out = base.slice();
    for (let i = 0; i < extra.length; i++) {
      out = MedicalDocumentAttachmentIdUtils.appendUnique(out, extra[i]);
    }
    return out;
  }

  private static countTargetNodes(tree: MedicalDocumentTypedDraftTree): number {
    switch (tree.kind) {
      case MedicalDocumentKind.CASE_DOCUMENT:
        return tree.caseDraft !== undefined ? 1 : 0;
      case MedicalDocumentKind.HEALTH_EXAM_REPORT:
        return tree.healthExamDraft !== undefined ? 1 : 0;
      case MedicalDocumentKind.MEDICAL_REPORT:
        return tree.medicalReportDrafts.length;
      case MedicalDocumentKind.PRESCRIPTION:
        return tree.prescriptionDrafts.length;
      case MedicalDocumentKind.MEDICATION_PLAN:
        return tree.medicationPlanDrafts.length;
      case MedicalDocumentKind.MEDICINE_BOX:
        return tree.medicineBoxDrafts.length;
      default:
        return 0;
    }
  }
}
