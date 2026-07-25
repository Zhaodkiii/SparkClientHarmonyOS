import { MedicalAttachmentInput } from '../../Home/Presentation/MedicalLists/MedicalDocumentAttachmentUploader';
import {
  MedicalDocumentAttachmentIdUtils
} from './MedicalDocumentAttachmentBindingModels';
import { MedicalDocumentKind } from './MedicalDocumentKind';
import {
  CaseRecognitionDraft,
  FollowUpRecognitionDraft,
  MedicalDocumentTypedDraftTree,
  MedicalReportRecognitionDraft,
  MedicationPlanRecognitionDraft,
  MedicineBoxRecognitionDraft,
  PrescriptionRecognitionDraft,
  SurgeryRecognitionDraft,
  SymptomRecognitionDraft,
  VisitRecognitionDraft
} from './MedicalDocumentRecognitionDrafts';
import {
  MedicalDocumentTypeResolution,
  MedicalDocumentTypedEnvelope,
  MedicalDocumentTypedExtractionOutput,
  MedicalTypedResultPayload
} from './MedicalDocumentTypedModels';

enum UploadModeHint {
  CHECKUP_REPORT = 'checkupReport',
  EXAM_REPORT = 'examReport',
  CASE_DOCUMENT = 'caseDocument',
  MEDICATION = 'medication',
  UNKNOWN = 'unknown'
}

class UploadModeScoreCandidate {
  mode: UploadModeHint = UploadModeHint.UNKNOWN;
  score: number = 0;

  static make(mode: UploadModeHint, score: number): UploadModeScoreCandidate {
    const item = new UploadModeScoreCandidate();
    item.mode = mode;
    item.score = score;
    return item;
  }
}

class UploadModeDetectResult {
  mode: UploadModeHint = UploadModeHint.UNKNOWN;
  confidence: number = 0;

  static make(mode: UploadModeHint, confidence: number): UploadModeDetectResult {
    const item = new UploadModeDetectResult();
    item.mode = mode;
    item.confidence = confidence;
    return item;
  }
}

/**
 * 医疗文档附件业务匹配器。对齐 iOS `MedicalDocumentAttachmentBusinessMatcher`：
 * 根据 OCR 文本将本地上传附件匹配到结构化草稿节点。
 */
export class MedicalDocumentAttachmentBusinessMatcher {
  /** 对齐 iOS：返回新 output，不原地修改入参。 */
  static matchAndUpdate(
    files: MedicalAttachmentInput[],
    output: MedicalDocumentTypedExtractionOutput
  ): MedicalDocumentTypedExtractionOutput {
    const result = MedicalDocumentAttachmentBusinessMatcher.cloneOutput(output);
    result.typedDrafts = MedicalDocumentAttachmentBusinessMatcher.matchTree(
      files, result.typedDrafts
    );
    result.envelope.fileCount = files.length;
    return result;
  }

  static matchTree(
    files: MedicalAttachmentInput[],
    tree: MedicalDocumentTypedDraftTree
  ): MedicalDocumentTypedDraftTree {
    const working = MedicalDocumentAttachmentBusinessMatcher.cloneTree(tree);
    switch (working.kind) {
      case MedicalDocumentKind.CASE_DOCUMENT:
        if (working.caseDraft !== undefined) {
          working.caseDraft =
            MedicalDocumentAttachmentBusinessMatcher.matchCase(files, working.caseDraft);
        }
        break;
      case MedicalDocumentKind.HEALTH_EXAM_REPORT:
        if (working.healthExamDraft !== undefined) {
          for (let i = 0; i < files.length; i++) {
            const file = files[i];
            if ((file.ocrText ?? '').trim().length === 0) {
              continue;
            }
            working.healthExamDraft.attachmentFileIds =
              MedicalDocumentAttachmentIdUtils.appendUnique(
                working.healthExamDraft.attachmentFileIds, file.previewId
              );
          }
        }
        break;
      case MedicalDocumentKind.MEDICAL_REPORT:
        working.medicalReportDrafts =
          MedicalDocumentAttachmentBusinessMatcher.matchReports(files, working.medicalReportDrafts);
        break;
      case MedicalDocumentKind.PRESCRIPTION:
        working.prescriptionDrafts =
          MedicalDocumentAttachmentBusinessMatcher.matchPrescriptions(
            files, working.prescriptionDrafts
          );
        break;
      case MedicalDocumentKind.MEDICATION_PLAN:
        working.medicationPlanDrafts =
          MedicalDocumentAttachmentBusinessMatcher.matchMedications(
            files, working.medicationPlanDrafts
          );
        break;
      case MedicalDocumentKind.MEDICINE_BOX:
        working.medicineBoxDrafts =
          MedicalDocumentAttachmentBusinessMatcher.matchMedicineBoxes(
            files, working.medicineBoxDrafts
          );
        break;
      default:
        break;
    }
    return working;
  }

  private static cloneOutput(
    output: MedicalDocumentTypedExtractionOutput
  ): MedicalDocumentTypedExtractionOutput {
    const copy = new MedicalDocumentTypedExtractionOutput();
    copy.envelope = MedicalDocumentAttachmentBusinessMatcher.cloneEnvelope(output.envelope);
    copy.typedResult = MedicalDocumentAttachmentBusinessMatcher.cloneTypedResult(output.typedResult);
    copy.typedDrafts = MedicalDocumentAttachmentBusinessMatcher.cloneTree(output.typedDrafts);
    copy.extractedJSON = output.extractedJSON;
    copy.payloadPreview = output.payloadPreview;
    copy.source = output.source;
    copy.retryFeedback = output.retryFeedback;
    copy.rawAIOutput = output.rawAIOutput;
    return copy;
  }

  private static cloneEnvelope(source: MedicalDocumentTypedEnvelope): MedicalDocumentTypedEnvelope {
    const envelope = new MedicalDocumentTypedEnvelope();
    envelope.memberID = source.memberID;
    envelope.uploadSessionId = source.uploadSessionId;
    envelope.ocrTextPreview = source.ocrTextPreview;
    envelope.fileCount = source.fileCount;
    envelope.fileBoundarySummary = source.fileBoundarySummary;
    envelope.extractionSource = source.extractionSource;
    envelope.hasRetryFeedback = source.hasRetryFeedback;
    const resolution = new MedicalDocumentTypeResolution();
    resolution.kind = source.typeResolution.kind;
    resolution.kindLabel = source.typeResolution.kindLabel;
    resolution.sourceLabel = source.typeResolution.sourceLabel;
    resolution.confidence = source.typeResolution.confidence;
    resolution.source = source.typeResolution.source;
    resolution.reason = source.typeResolution.reason;
    envelope.typeResolution = resolution;
    return envelope;
  }

  private static cloneTypedResult(source: MedicalTypedResultPayload): MedicalTypedResultPayload {
    const payload = new MedicalTypedResultPayload();
    payload.kind = source.kind;
    payload.title = source.title;
    payload.summary = source.summary;
    payload.diagnosis = source.diagnosis;
    payload.occurredAt = source.occurredAt;
    payload.rawType = source.rawType;
    payload.fieldsJSON = source.fieldsJSON;
    payload.itemsJSON = source.itemsJSON;
    payload.warningCount = source.warningCount;
    payload.warnings = source.warnings.slice();
    return payload;
  }

  private static cloneTree(tree: MedicalDocumentTypedDraftTree): MedicalDocumentTypedDraftTree {
    const plain = JSON.parse(JSON.stringify(tree)) as MedicalDocumentTypedDraftTree;
    return MedicalDocumentTypedDraftTree.ensureInstance(plain);
  }

  private static matchCase(
    files: MedicalAttachmentInput[],
    draft: CaseRecognitionDraft
  ): CaseRecognitionDraft {
    const working = MedicalDocumentAttachmentBusinessMatcher.cloneTree(
      ((): MedicalDocumentTypedDraftTree => {
        const t = new MedicalDocumentTypedDraftTree();
        t.caseDraft = draft;
        return t;
      })()
    ).caseDraft!;
    for (let i = 0; i < files.length; i++) {
      const file = files[i];
      const ocrText = (file.ocrText ?? '').trim();
      if (ocrText.length === 0) {
        continue;
      }
      const detected = MedicalDocumentAttachmentBusinessMatcher.detectMode(ocrText);
      let matched = false;
      if (detected.confidence >= 35 && detected.mode !== UploadModeHint.UNKNOWN) {
        matched = MedicalDocumentAttachmentBusinessMatcher.matchByDocumentType(
          detected.mode, ocrText, working, file.previewId
        );
      }
      if (!matched) {
        matched = MedicalDocumentAttachmentBusinessMatcher.matchByOriginalLogic(
          ocrText, working, file.previewId
        );
      }
      if (!matched) {
        working.attachmentFileIds = MedicalDocumentAttachmentIdUtils.appendUnique(
          working.attachmentFileIds, file.previewId
        );
      }
    }
    return working;
  }

  private static matchByDocumentType(
    mode: UploadModeHint,
    ocrText: string,
    draft: CaseRecognitionDraft,
    fileID: string
  ): boolean {
    if (mode === UploadModeHint.CHECKUP_REPORT || mode === UploadModeHint.EXAM_REPORT) {
      if (draft.examinationReports !== undefined) {
        for (let i = 0; i < draft.examinationReports.length; i++) {
          if (MedicalDocumentAttachmentBusinessMatcher.matchReportText(
            ocrText, draft.examinationReports[i]
          )) {
            draft.examinationReports[i].attachmentFileIds =
              MedicalDocumentAttachmentIdUtils.appendUnique(
                draft.examinationReports[i].attachmentFileIds, fileID
              );
            return true;
          }
        }
      }
      return false;
    }
    if (mode === UploadModeHint.CASE_DOCUMENT) {
      if (draft.visit !== undefined &&
        MedicalDocumentAttachmentBusinessMatcher.matchVisitText(ocrText, draft.visit)) {
        draft.visit.attachmentFileIds = MedicalDocumentAttachmentIdUtils.appendUnique(
          draft.visit.attachmentFileIds, fileID
        );
        return true;
      }
      if (draft.symptom !== undefined &&
        MedicalDocumentAttachmentBusinessMatcher.matchSymptomText(ocrText, draft.symptom)) {
        draft.symptom.attachmentFileIds = MedicalDocumentAttachmentIdUtils.appendUnique(
          draft.symptom.attachmentFileIds, fileID
        );
        return true;
      }
      if (MedicalDocumentAttachmentBusinessMatcher.matchCaseText(ocrText, draft)) {
        draft.attachmentFileIds = MedicalDocumentAttachmentIdUtils.appendUnique(
          draft.attachmentFileIds, fileID
        );
        return true;
      }
      return false;
    }
    if (mode === UploadModeHint.MEDICATION && draft.prescriptions !== undefined) {
      for (let i = 0; i < draft.prescriptions.length; i++) {
        if (MedicalDocumentAttachmentBusinessMatcher.matchPrescriptionText(
          ocrText, draft.prescriptions[i]
        )) {
          draft.prescriptions[i].attachmentFileIds =
            MedicalDocumentAttachmentIdUtils.appendUnique(
              draft.prescriptions[i].attachmentFileIds, fileID
            );
          return true;
        }
      }
      for (let i = 0; i < draft.prescriptions.length; i++) {
        const plans = draft.prescriptions[i].medicationPlans;
        if (plans === undefined) {
          continue;
        }
        for (let j = 0; j < plans.length; j++) {
          if (MedicalDocumentAttachmentBusinessMatcher.matchMedicationText(ocrText, plans[j])) {
            plans[j].attachmentFileIds = MedicalDocumentAttachmentIdUtils.appendUnique(
              plans[j].attachmentFileIds, fileID
            );
            return true;
          }
        }
      }
      for (let i = 0; i < draft.prescriptions.length; i++) {
        if (MedicalDocumentAttachmentBusinessMatcher.bindFirstMatchingMedicineBoxInPrescription(
          ocrText, fileID, draft.prescriptions[i]
        )) {
          return true;
        }
      }
    }
    return false;
  }

  private static matchByOriginalLogic(
    ocrText: string,
    draft: CaseRecognitionDraft,
    fileID: string
  ): boolean {
    if (draft.examinationReports !== undefined) {
      for (let i = 0; i < draft.examinationReports.length; i++) {
        if (MedicalDocumentAttachmentBusinessMatcher.matchReportText(
          ocrText, draft.examinationReports[i]
        )) {
          draft.examinationReports[i].attachmentFileIds =
            MedicalDocumentAttachmentIdUtils.appendUnique(
              draft.examinationReports[i].attachmentFileIds, fileID
            );
          return true;
        }
      }
    }
    if (draft.symptom !== undefined &&
      MedicalDocumentAttachmentBusinessMatcher.matchSymptomText(ocrText, draft.symptom)) {
      draft.symptom.attachmentFileIds = MedicalDocumentAttachmentIdUtils.appendUnique(
        draft.symptom.attachmentFileIds, fileID
      );
      return true;
    }
    if (draft.visit !== undefined &&
      MedicalDocumentAttachmentBusinessMatcher.matchVisitText(ocrText, draft.visit)) {
      draft.visit.attachmentFileIds = MedicalDocumentAttachmentIdUtils.appendUnique(
        draft.visit.attachmentFileIds, fileID
      );
      return true;
    }
    if (draft.prescriptions !== undefined) {
      for (let i = 0; i < draft.prescriptions.length; i++) {
        if (MedicalDocumentAttachmentBusinessMatcher.matchPrescriptionText(
          ocrText, draft.prescriptions[i]
        )) {
          draft.prescriptions[i].attachmentFileIds =
            MedicalDocumentAttachmentIdUtils.appendUnique(
              draft.prescriptions[i].attachmentFileIds, fileID
            );
          return true;
        }
      }
      for (let i = 0; i < draft.prescriptions.length; i++) {
        const plans = draft.prescriptions[i].medicationPlans;
        if (plans === undefined) {
          continue;
        }
        for (let j = 0; j < plans.length; j++) {
          if (MedicalDocumentAttachmentBusinessMatcher.matchMedicationText(ocrText, plans[j])) {
            plans[j].attachmentFileIds = MedicalDocumentAttachmentIdUtils.appendUnique(
              plans[j].attachmentFileIds, fileID
            );
            return true;
          }
        }
      }
      for (let i = 0; i < draft.prescriptions.length; i++) {
        if (MedicalDocumentAttachmentBusinessMatcher.bindFirstMatchingMedicineBoxInPrescription(
          ocrText, fileID, draft.prescriptions[i]
        )) {
          return true;
        }
      }
    }
    if (draft.surgery !== undefined &&
      MedicalDocumentAttachmentBusinessMatcher.matchSurgeryText(ocrText, draft.surgery)) {
      draft.surgery.attachmentFileIds = MedicalDocumentAttachmentIdUtils.appendUnique(
        draft.surgery.attachmentFileIds, fileID
      );
      return true;
    }
    if (draft.followUps !== undefined) {
      for (let i = 0; i < draft.followUps.length; i++) {
        if (MedicalDocumentAttachmentBusinessMatcher.matchFollowUpText(
          ocrText, draft.followUps[i]
        )) {
          draft.followUps[i].attachmentFileIds = MedicalDocumentAttachmentIdUtils.appendUnique(
            draft.followUps[i].attachmentFileIds, fileID
          );
          return true;
        }
      }
    }
    if (MedicalDocumentAttachmentBusinessMatcher.matchCaseText(ocrText, draft)) {
      draft.attachmentFileIds = MedicalDocumentAttachmentIdUtils.appendUnique(
        draft.attachmentFileIds, fileID
      );
      return true;
    }
    return false;
  }

  private static matchReports(
    files: MedicalAttachmentInput[],
    reports: MedicalReportRecognitionDraft[]
  ): MedicalReportRecognitionDraft[] {
    if (reports.length === 0) {
      return reports;
    }
    const working = MedicalDocumentAttachmentBusinessMatcher.cloneTree(
      ((): MedicalDocumentTypedDraftTree => {
        const t = new MedicalDocumentTypedDraftTree();
        t.medicalReportDrafts = reports;
        return t;
      })()
    ).medicalReportDrafts;
    for (let i = 0; i < files.length; i++) {
      const file = files[i];
      const ocrText = (file.ocrText ?? '').trim();
      if (ocrText.length === 0) {
        continue;
      }
      const detected = MedicalDocumentAttachmentBusinessMatcher.detectMode(ocrText);
      let matched = false;
      if (detected.confidence >= 35 &&
        (detected.mode === UploadModeHint.CHECKUP_REPORT ||
          detected.mode === UploadModeHint.EXAM_REPORT)) {
        matched = MedicalDocumentAttachmentBusinessMatcher.bindFirstMatchingReport(
          ocrText, file.previewId, working
        );
      }
      if (!matched) {
        matched = MedicalDocumentAttachmentBusinessMatcher.bindFirstMatchingReport(
          ocrText, file.previewId, working
        );
      }
      if (!matched) {
        working[0].attachmentFileIds = MedicalDocumentAttachmentIdUtils.appendUnique(
          working[0].attachmentFileIds, file.previewId
        );
      }
    }
    return working;
  }

  private static matchPrescriptions(
    files: MedicalAttachmentInput[],
    prescriptions: PrescriptionRecognitionDraft[]
  ): PrescriptionRecognitionDraft[] {
    if (prescriptions.length === 0) {
      return prescriptions;
    }
    const working = MedicalDocumentAttachmentBusinessMatcher.cloneTree(
      ((): MedicalDocumentTypedDraftTree => {
        const t = new MedicalDocumentTypedDraftTree();
        t.prescriptionDrafts = prescriptions;
        return t;
      })()
    ).prescriptionDrafts;
    for (let i = 0; i < files.length; i++) {
      const file = files[i];
      const ocrText = (file.ocrText ?? '').trim();
      if (ocrText.length === 0) {
        continue;
      }
      const detected = MedicalDocumentAttachmentBusinessMatcher.detectMode(ocrText);
      let matched = false;
      if (detected.confidence >= 35 && detected.mode === UploadModeHint.MEDICATION) {
        for (let j = 0; j < working.length; j++) {
          if (MedicalDocumentAttachmentBusinessMatcher.matchPrescriptionText(
            ocrText, working[j]
          )) {
            working[j].attachmentFileIds = MedicalDocumentAttachmentIdUtils.appendUnique(
              working[j].attachmentFileIds, file.previewId
            );
            matched = true;
            break;
          }
        }
      }
      if (!matched) {
        for (let j = 0; j < working.length; j++) {
          if (MedicalDocumentAttachmentBusinessMatcher.bindPrescriptionOrMedication(
            ocrText, file.previewId, working[j]
          )) {
            matched = true;
            break;
          }
        }
      }
      if (!matched) {
        working[0].attachmentFileIds = MedicalDocumentAttachmentIdUtils.appendUnique(
          working[0].attachmentFileIds, file.previewId
        );
      }
    }
    return working;
  }

  private static matchMedications(
    files: MedicalAttachmentInput[],
    medications: MedicationPlanRecognitionDraft[]
  ): MedicationPlanRecognitionDraft[] {
    if (medications.length === 0) {
      return medications;
    }
    const working = MedicalDocumentAttachmentBusinessMatcher.cloneTree(
      ((): MedicalDocumentTypedDraftTree => {
        const t = new MedicalDocumentTypedDraftTree();
        t.medicationPlanDrafts = medications;
        return t;
      })()
    ).medicationPlanDrafts;
    for (let i = 0; i < files.length; i++) {
      const file = files[i];
      const ocrText = (file.ocrText ?? '').trim();
      if (ocrText.length === 0) {
        continue;
      }
      const detected = MedicalDocumentAttachmentBusinessMatcher.detectMode(ocrText);
      let matched = false;
      if (detected.confidence >= 35 && detected.mode === UploadModeHint.MEDICATION) {
        matched = MedicalDocumentAttachmentBusinessMatcher.bindFirstMatchingMedication(
          ocrText, file.previewId, working
        );
      }
      if (!matched) {
        matched = MedicalDocumentAttachmentBusinessMatcher.bindFirstMatchingMedication(
          ocrText, file.previewId, working
        );
      }
      if (!matched) {
        working[0].attachmentFileIds = MedicalDocumentAttachmentIdUtils.appendUnique(
          working[0].attachmentFileIds, file.previewId
        );
      }
    }
    return working;
  }

  private static matchMedicineBoxes(
    files: MedicalAttachmentInput[],
    boxes: MedicineBoxRecognitionDraft[]
  ): MedicineBoxRecognitionDraft[] {
    if (boxes.length === 0) {
      return boxes;
    }
    const working = MedicalDocumentAttachmentBusinessMatcher.cloneTree(
      ((): MedicalDocumentTypedDraftTree => {
        const t = new MedicalDocumentTypedDraftTree();
        t.medicineBoxDrafts = boxes;
        return t;
      })()
    ).medicineBoxDrafts;
    for (let i = 0; i < files.length; i++) {
      const file = files[i];
      const ocrText = (file.ocrText ?? '').trim();
      if (ocrText.length === 0) {
        working[0].attachmentFileIds = MedicalDocumentAttachmentIdUtils.appendUnique(
          working[0].attachmentFileIds, file.previewId
        );
        continue;
      }
      let matched = false;
      for (let j = 0; j < working.length; j++) {
        if (MedicalDocumentAttachmentBusinessMatcher.matchMedicineBoxText(ocrText, working[j])) {
          working[j].attachmentFileIds = MedicalDocumentAttachmentIdUtils.appendUnique(
            working[j].attachmentFileIds, file.previewId
          );
          matched = true;
          break;
        }
      }
      if (!matched) {
        working[0].attachmentFileIds = MedicalDocumentAttachmentIdUtils.appendUnique(
          working[0].attachmentFileIds, file.previewId
        );
      }
    }
    return working;
  }

  private static bindFirstMatchingReport(
    ocrText: string,
    fileID: string,
    reports: MedicalReportRecognitionDraft[]
  ): boolean {
    for (let i = 0; i < reports.length; i++) {
      if (MedicalDocumentAttachmentBusinessMatcher.matchReportText(ocrText, reports[i])) {
        reports[i].attachmentFileIds = MedicalDocumentAttachmentIdUtils.appendUnique(
          reports[i].attachmentFileIds, fileID
        );
        return true;
      }
    }
    return false;
  }

  private static bindPrescriptionOrMedication(
    ocrText: string,
    fileID: string,
    prescription: PrescriptionRecognitionDraft
  ): boolean {
    if (MedicalDocumentAttachmentBusinessMatcher.matchPrescriptionText(ocrText, prescription)) {
      prescription.attachmentFileIds = MedicalDocumentAttachmentIdUtils.appendUnique(
        prescription.attachmentFileIds, fileID
      );
      return true;
    }
    const plans = prescription.medicationPlans;
    if (plans !== undefined) {
      for (let i = 0; i < plans.length; i++) {
        if (MedicalDocumentAttachmentBusinessMatcher.matchMedicationText(ocrText, plans[i])) {
          plans[i].attachmentFileIds = MedicalDocumentAttachmentIdUtils.appendUnique(
            plans[i].attachmentFileIds, fileID
          );
          return true;
        }
      }
    }
    return MedicalDocumentAttachmentBusinessMatcher.bindFirstMatchingMedicineBoxInPrescription(
      ocrText, fileID, prescription
    );
  }

  private static bindFirstMatchingMedicineBoxInPrescription(
    ocrText: string,
    fileID: string,
    prescription: PrescriptionRecognitionDraft
  ): boolean {
    const plans = prescription.medicationPlans;
    if (plans === undefined) {
      return false;
    }
    for (let i = 0; i < plans.length; i++) {
      const box = plans[i].medicineBox;
      if (box !== undefined &&
        MedicalDocumentAttachmentBusinessMatcher.matchMedicineBoxText(ocrText, box)) {
        plans[i].medicineBox!.attachmentFileIds = MedicalDocumentAttachmentIdUtils.appendUnique(
          box.attachmentFileIds, fileID
        );
        return true;
      }
    }
    return false;
  }

  private static bindFirstMatchingMedication(
    ocrText: string,
    fileID: string,
    medications: MedicationPlanRecognitionDraft[]
  ): boolean {
    for (let i = 0; i < medications.length; i++) {
      if (MedicalDocumentAttachmentBusinessMatcher.matchMedicationText(ocrText, medications[i])) {
        medications[i].attachmentFileIds = MedicalDocumentAttachmentIdUtils.appendUnique(
          medications[i].attachmentFileIds, fileID
        );
        return true;
      }
    }
    return false;
  }

  private static displayMedicineName(draft: MedicationPlanRecognitionDraft): string | undefined {
    if (draft.medicineName !== undefined && draft.medicineName.trim().length > 0) {
      return draft.medicineName;
    }
    if (draft.medicineBox?.medicineName !== undefined &&
      draft.medicineBox.medicineName.trim().length > 0) {
      return draft.medicineBox.medicineName;
    }
    if (draft.brandName !== undefined && draft.brandName.trim().length > 0) {
      return draft.brandName;
    }
    return undefined;
  }

  private static displayMedicineBoxName(draft: MedicineBoxRecognitionDraft): string | undefined {
    if (draft.medicineName !== undefined && draft.medicineName.trim().length > 0) {
      return draft.medicineName;
    }
    if (draft.brandName !== undefined && draft.brandName.trim().length > 0) {
      return draft.brandName;
    }
    return undefined;
  }

  private static matchCaseText(ocrText: string, draft: CaseRecognitionDraft): boolean {
    const text = MedicalDocumentAttachmentBusinessMatcher.normalized(ocrText);
    let score = 0;
    if (MedicalDocumentAttachmentBusinessMatcher.contains(text, draft.title)) {
      score += 3;
    }
    if (MedicalDocumentAttachmentBusinessMatcher.contains(text, draft.diagnosis)) {
      score += 3;
    }
    if (MedicalDocumentAttachmentBusinessMatcher.contains(text, draft.summary)) {
      score += 2;
    }
    if (MedicalDocumentAttachmentBusinessMatcher.contains(text, draft.hospitalName)) {
      score += 1;
    }
    if (draft.symptom !== undefined &&
      MedicalDocumentAttachmentBusinessMatcher.contains(text, draft.symptom.name)) {
      score += 2;
    }
    if (draft.prescriptions !== undefined) {
      for (let i = 0; i < draft.prescriptions.length; i++) {
        const plans = draft.prescriptions[i].medicationPlans;
        if (plans === undefined) {
          continue;
        }
        for (let j = 0; j < plans.length; j++) {
          const name = MedicalDocumentAttachmentBusinessMatcher.displayMedicineName(plans[j]);
          if (MedicalDocumentAttachmentBusinessMatcher.contains(text, name)) {
            score += 2;
          }
        }
      }
    }
    return score >= 3;
  }

  private static matchReportText(ocrText: string, draft: MedicalReportRecognitionDraft): boolean {
    const text = MedicalDocumentAttachmentBusinessMatcher.normalized(ocrText);
    let score = 0;
    if (MedicalDocumentAttachmentBusinessMatcher.contains(text, draft.title)) {
      score += 3;
    }
    if (MedicalDocumentAttachmentBusinessMatcher.contains(text, draft.category)) {
      score += 2;
    }
    if (MedicalDocumentAttachmentBusinessMatcher.contains(text, draft.content)) {
      score += 2;
    }
    if (MedicalDocumentAttachmentBusinessMatcher.contains(text, draft.hospital)) {
      score += 1;
    }
    let detailScore = 0;
    for (let i = 0; i < draft.details.length; i++) {
      const item = draft.details[i];
      if (MedicalDocumentAttachmentBusinessMatcher.contains(text, item.itemName)) {
        detailScore += 3;
      }
      if (MedicalDocumentAttachmentBusinessMatcher.contains(text, item.resultValue)) {
        detailScore += 1;
      }
      if (MedicalDocumentAttachmentBusinessMatcher.contains(text, item.referenceRange)) {
        detailScore += 1;
      }
      if (MedicalDocumentAttachmentBusinessMatcher.contains(text, item.modality)) {
        detailScore += 2;
      }
      if (MedicalDocumentAttachmentBusinessMatcher.contains(text, item.bodyPart)) {
        detailScore += 3;
      }
      if (MedicalDocumentAttachmentBusinessMatcher.contains(text, item.diagnosis)) {
        detailScore += 2;
      }
    }
    score += detailScore;
    let threshold = 2;
    if (draft.details.length > 0) {
      threshold = Math.max(threshold, 5);
    }
    return score >= threshold;
  }

  private static matchSymptomText(ocrText: string, draft: SymptomRecognitionDraft): boolean {
    const text = MedicalDocumentAttachmentBusinessMatcher.normalized(ocrText);
    let score = 0;
    if (MedicalDocumentAttachmentBusinessMatcher.contains(text, draft.name)) {
      score += 3;
    }
    if (MedicalDocumentAttachmentBusinessMatcher.contains(text, draft.severity)) {
      score += 1;
    }
    if (MedicalDocumentAttachmentBusinessMatcher.contains(text, draft.bodyPart)) {
      score += 1;
    }
    if (MedicalDocumentAttachmentBusinessMatcher.contains(text, draft.notes)) {
      score += 1;
    }
    return score >= 2;
  }

  private static matchVisitText(ocrText: string, draft: VisitRecognitionDraft): boolean {
    const text = MedicalDocumentAttachmentBusinessMatcher.normalized(ocrText);
    let score = 0;
    if (MedicalDocumentAttachmentBusinessMatcher.contains(text, draft.department)) {
      score += 2;
    }
    if (MedicalDocumentAttachmentBusinessMatcher.contains(text, draft.doctorName)) {
      score += 1;
    }
    if (MedicalDocumentAttachmentBusinessMatcher.contains(text, draft.visitNo)) {
      score += 2;
    }
    if (MedicalDocumentAttachmentBusinessMatcher.contains(text, draft.notes)) {
      score += 2;
    }
    return score >= 3;
  }

  private static matchMedicationText(
    ocrText: string,
    draft: MedicationPlanRecognitionDraft
  ): boolean {
    const text = MedicalDocumentAttachmentBusinessMatcher.normalized(ocrText);
    let score = 0;
    const name = MedicalDocumentAttachmentBusinessMatcher.displayMedicineName(draft);
    if (MedicalDocumentAttachmentBusinessMatcher.contains(text, name)) {
      score += 3;
    }
    if (MedicalDocumentAttachmentBusinessMatcher.contains(text, draft.dosePerTime) ||
      MedicalDocumentAttachmentBusinessMatcher.contains(text, draft.doseValue)) {
      score += 2;
    }
    if (MedicalDocumentAttachmentBusinessMatcher.contains(text, draft.frequencyText) ||
      MedicalDocumentAttachmentBusinessMatcher.contains(text, draft.frequencyType)) {
      score += 1;
    }
    return score >= 3;
  }

  private static matchMedicineBoxText(
    ocrText: string,
    draft: MedicineBoxRecognitionDraft
  ): boolean {
    const text = MedicalDocumentAttachmentBusinessMatcher.normalized(ocrText);
    let score = 0;
    const name = MedicalDocumentAttachmentBusinessMatcher.displayMedicineBoxName(draft);
    if (MedicalDocumentAttachmentBusinessMatcher.contains(text, name)) {
      score += 3;
    }
    if (MedicalDocumentAttachmentBusinessMatcher.contains(text, draft.strength)) {
      score += 2;
    }
    if (MedicalDocumentAttachmentBusinessMatcher.contains(text, draft.dosageForm)) {
      score += 1;
    }
    return score >= 3;
  }

  private static matchSurgeryText(ocrText: string, draft: SurgeryRecognitionDraft): boolean {
    const text = MedicalDocumentAttachmentBusinessMatcher.normalized(ocrText);
    let score = 0;
    if (MedicalDocumentAttachmentBusinessMatcher.contains(text, draft.procedureName)) {
      score += 3;
    }
    if (MedicalDocumentAttachmentBusinessMatcher.contains(text, draft.surgeon)) {
      score += 1;
    }
    if (MedicalDocumentAttachmentBusinessMatcher.contains(text, draft.site)) {
      score += 1;
    }
    return score >= 2;
  }

  private static matchFollowUpText(ocrText: string, draft: FollowUpRecognitionDraft): boolean {
    const text = MedicalDocumentAttachmentBusinessMatcher.normalized(ocrText);
    let score = 0;
    if (MedicalDocumentAttachmentBusinessMatcher.contains(text, draft.outcome)) {
      score += 3;
    }
    if (MedicalDocumentAttachmentBusinessMatcher.contains(text, draft.nextAction)) {
      score += 2;
    }
    if (MedicalDocumentAttachmentBusinessMatcher.contains(text, draft.method)) {
      score += 1;
    }
    return score >= 2;
  }

  private static matchPrescriptionText(
    ocrText: string,
    draft: PrescriptionRecognitionDraft
  ): boolean {
    const text = MedicalDocumentAttachmentBusinessMatcher.normalized(ocrText);
    let score = 0;
    if (MedicalDocumentAttachmentBusinessMatcher.contains(text, draft.prescriptionNo)) {
      score += 4;
    }
    if (MedicalDocumentAttachmentBusinessMatcher.contains(text, draft.institutionName)) {
      score += 3;
    }
    if (MedicalDocumentAttachmentBusinessMatcher.contains(text, draft.prescriberName)) {
      score += 2;
    }
    if (MedicalDocumentAttachmentBusinessMatcher.contains(text, draft.diagnosis)) {
      score += 2;
    }
    const plans = draft.medicationPlans;
    if (plans !== undefined) {
      for (let i = 0; i < plans.length; i++) {
        const name = MedicalDocumentAttachmentBusinessMatcher.displayMedicineName(plans[i]);
        if (MedicalDocumentAttachmentBusinessMatcher.contains(text, name)) {
          score += 1;
        }
      }
    }
    return score >= 4;
  }

  private static contains(normalizedText: string, raw: string | undefined): boolean {
    if (raw === undefined) {
      return false;
    }
    const trimmed = raw.trim();
    if (trimmed.length === 0) {
      return false;
    }
    const value = MedicalDocumentAttachmentBusinessMatcher.normalized(trimmed);
    if (value.length < 2) {
      return false;
    }
    return normalizedText.indexOf(value) >= 0;
  }

  private static normalized(text: string): string {
    return text.toLowerCase().replace(/\s+/g, '');
  }

  private static detectMode(text: string): UploadModeDetectResult {
    const lower = text.toLowerCase();
    const checkupHigh: string[] = ['体检报告', '健康体检', '体检中心', '体检结论', '体检建议'];
    const checkupMedium: string[] = ['参考范围', '正常范围', '总胆固醇', '血红蛋白'];
    const caseHigh: string[] = ['门诊病历', '住院病历', '急诊病历', '主诉', '现病史', '既往史', '初步诊断'];
    const caseMedium: string[] = ['辅助检查', '过敏史', '住院号', '门诊号'];
    const examHigh: string[] =
      ['诊断报告单', '检查报告单', '影像表现', '诊断意见', '影像诊断', '检验报告单'];
    const examMedium: string[] = ['检查项目', '检测项目', '报告医生', '标本类型', '参考区间'];
    const medicationHigh: string[] = ['处方笺', '处方单', '处方', 'rp', '用法', '用量'];
    const medicationMedium: string[] = ['药品名称', '发药清单', '医师签名', 'tid', 'bid', 'qd'];
    const candidates: UploadModeScoreCandidate[] = [
      UploadModeScoreCandidate.make(
        UploadModeHint.CHECKUP_REPORT,
        MedicalDocumentAttachmentBusinessMatcher.keywordScore(lower, checkupHigh, checkupMedium)
      ),
      UploadModeScoreCandidate.make(
        UploadModeHint.CASE_DOCUMENT,
        MedicalDocumentAttachmentBusinessMatcher.keywordScore(lower, caseHigh, caseMedium)
      ),
      UploadModeScoreCandidate.make(
        UploadModeHint.EXAM_REPORT,
        MedicalDocumentAttachmentBusinessMatcher.keywordScore(lower, examHigh, examMedium)
      ),
      UploadModeScoreCandidate.make(
        UploadModeHint.MEDICATION,
        MedicalDocumentAttachmentBusinessMatcher.keywordScore(
          lower, medicationHigh, medicationMedium
        )
      )
    ];
    let bestMode = UploadModeHint.UNKNOWN;
    let bestScore = 0;
    for (let i = 0; i < candidates.length; i++) {
      if (candidates[i].score > bestScore) {
        bestScore = candidates[i].score;
        bestMode = candidates[i].mode;
      }
    }
    if (bestScore <= 0) {
      return UploadModeDetectResult.make(UploadModeHint.UNKNOWN, 0);
    }
    return UploadModeDetectResult.make(bestMode, Math.min(bestScore, 100));
  }

  private static keywordScore(text: string, high: string[], medium: string[]): number {
    let score = 0;
    for (let i = 0; i < high.length; i++) {
      if (text.indexOf(high[i].toLowerCase()) >= 0) {
        score += 15;
      }
    }
    let mediumHits = 0;
    for (let i = 0; i < medium.length; i++) {
      if (text.indexOf(medium[i].toLowerCase()) >= 0) {
        mediumHits += 1;
      }
    }
    score += Math.min(mediumHits, 5) * 2;
    return score;
  }
}
