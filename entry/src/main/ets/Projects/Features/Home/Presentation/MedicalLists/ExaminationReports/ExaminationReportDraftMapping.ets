import {
  RemoteExaminationReportWithAttachments,
  RemoteMedExamDetail
} from '../../../../../Core/Networking/API/Medical/MedicalSyncAPI';
import { ItemDraft, MedicalReportRecognitionDraft } from
  '../../../../MedicalDocumentUpload/Domain/MedicalDocumentRecognitionDrafts';
import { MedicalReportResultSupport } from
  '../../../../MedicalDocumentUpload/Presentation/ResultPages/MedicalReportRecognitionResult/MedicalReportResultSupport';
import { nonEmptyText } from '../Shared/HealthExamFlagSupport';

/**
 * 检查报告远端实体 ↔ 识别/编辑草稿互转。对齐 iOS
 * `MedicalCaseTimelineRemoteMapping.examinationDraft` /
 * `MedicalDocumentResultDetailNavigationSupport.remoteExaminationReport` /
 * `applyingRecognitionDraft`。
 */
export class ExaminationReportDraftMapping {
  static newItemId(): string {
    return `item_${Date.now()}_${Math.floor(Math.random() * 100000)}`;
  }

  static dateOnlyText(iso?: string): string {
    const raw = (iso ?? '').trim();
    if (raw.length === 0) {
      return '';
    }
    if (raw.length >= 10 && raw.charAt(4) === '-' && raw.charAt(7) === '-') {
      return raw.substring(0, 10);
    }
    return raw;
  }

  static todayDateText(): string {
    return ExaminationReportDraftMapping.formatDate(new Date());
  }

  /** 将 `Date` 格式化为 `yyyy-MM-dd`。对齐 iOS `formatExamDayString`。 */
  static formatDate(day: Date): string {
    const month = `${day.getMonth() + 1}`.padStart(2, '0');
    const dayOfMonth = `${day.getDate()}`.padStart(2, '0');
    return `${day.getFullYear()}-${month}-${dayOfMonth}`;
  }

  /** 将日期字符串解析为本地 `Date`。对齐 iOS `parseExamDay`。 */
  static parseDate(raw?: string): Date {
    const trimmed = (raw ?? '').trim();
    if (trimmed.length >= 10 && trimmed.charAt(4) === '-' && trimmed.charAt(7) === '-') {
      const year = parseInt(trimmed.substring(0, 4), 10);
      const month = parseInt(trimmed.substring(5, 7), 10);
      const day = parseInt(trimmed.substring(8, 10), 10);
      if (!Number.isNaN(year) && !Number.isNaN(month) && !Number.isNaN(day)
        && month >= 1 && month <= 12 && day >= 1 && day <= 31) {
        return new Date(year, month - 1, day);
      }
    }
    if (trimmed.length > 0) {
      const iso = new Date(trimmed);
      if (!Number.isNaN(iso.getTime())) {
        return iso;
      }
    }
    return new Date();
  }

  static itemDraftFromDetail(detail: RemoteMedExamDetail): ItemDraft {
    const draft = new ItemDraft();
    draft.id = detail.id > 0 ? `detail_${detail.id}` : ExaminationReportDraftMapping.newItemId();
    draft.category = nonEmptyText(detail.category).length > 0 ? detail.category : undefined;
    draft.subCategory = nonEmptyText(detail.subCategory).length > 0 ? detail.subCategory : undefined;
    draft.itemName = nonEmptyText(detail.itemName).length > 0 ? detail.itemName : undefined;
    draft.resultValue = detail.resultValue;
    draft.unit = nonEmptyText(detail.unit).length > 0 ? detail.unit : undefined;
    draft.referenceRange = nonEmptyText(detail.referenceRange).length > 0 ?
      detail.referenceRange : undefined;
    draft.flag = nonEmptyText(detail.flag).length > 0 ? detail.flag : undefined;
    draft.modality = nonEmptyText(detail.modality).length > 0 ? detail.modality : undefined;
    draft.bodyPart = nonEmptyText(detail.bodyPart).length > 0 ? detail.bodyPart : undefined;
    draft.resultAt = ExaminationReportDraftMapping.dateOnlyText(detail.resultAt);
    draft.diagnosis = detail.diagnosis;
    return draft;
  }

  static examinationDraftFromReport(
    report: RemoteExaminationReportWithAttachments
  ): MedicalReportRecognitionDraft {
    const draft = new MedicalReportRecognitionDraft();
    draft.category = report.category;
    draft.title = nonEmptyText(report.itemName);
    draft.hospital = report.organizationName;
    draft.doctor = report.doctorName;
    const findings = nonEmptyText(report.findings);
    const impression = nonEmptyText(report.impression);
    draft.content = impression.length > 0 ? impression : findings;
    draft.date = ExaminationReportDraftMapping.dateOnlyText(report.reportedAt ?? report.performedAt);
    const details: ItemDraft[] = [];
    for (let i = 0; i < report.medExamDetails.length; i++) {
      details.push(ExaminationReportDraftMapping.itemDraftFromDetail(report.medExamDetails[i]));
    }
    draft.details = details;
    return draft;
  }

  static remoteMedExamDetailFromItemDraft(
    item: ItemDraft,
    memberID: number,
    businessID: number,
    id: number,
    sortOrder: number
  ): RemoteMedExamDetail {
    const row = new RemoteMedExamDetail();
    row.id = id;
    row.businessType = 'examination_report';
    row.businessId = businessID;
    row.member = memberID;
    row.category = nonEmptyText(item.category);
    row.subCategory = nonEmptyText(item.subCategory);
    row.itemName = nonEmptyText(item.itemName).length > 0 ?
      nonEmptyText(item.itemName) : nonEmptyText(item.category);
    row.resultValue = item.resultValue;
    row.unit = nonEmptyText(item.unit);
    row.referenceRange = nonEmptyText(item.referenceRange);
    row.flag = nonEmptyText(item.flag);
    row.resultAt = nonEmptyText(item.resultAt).length > 0 ? item.resultAt : undefined;
    row.modality = nonEmptyText(item.modality);
    row.bodyPart = nonEmptyText(item.bodyPart);
    row.diagnosis = item.diagnosis;
    row.sortOrder = sortOrder;
    return row;
  }

  static remoteExaminationReportFromDraft(
    draft: MedicalReportRecognitionDraft,
    memberID: number,
    id: number,
    medicalCaseID?: number
  ): RemoteExaminationReportWithAttachments {
    const report = new RemoteExaminationReportWithAttachments();
    report.id = id;
    report.member = memberID;
    report.medicalRecord = medicalCaseID;
    report.category = draft.category;
    report.subCategory = draft.details.length > 0 ? draft.details[0].subCategory : undefined;
    report.itemName = draft.title;
    report.organizationName = draft.hospital;
    report.doctorName = draft.doctor;
    report.findings = MedicalReportResultSupport.resolvedFindingsText(draft);
    report.impression = MedicalReportResultSupport.resolvedImpressionText(draft);
    const dateText = nonEmptyText(draft.date).length > 0 ?
      nonEmptyText(draft.date) : ExaminationReportDraftMapping.todayDateText();
    report.performedAt = dateText;
    report.reportedAt = dateText;
    report.detailsLoaded = true;
    const details: RemoteMedExamDetail[] = [];
    for (let i = 0; i < draft.details.length; i++) {
      details.push(ExaminationReportDraftMapping.remoteMedExamDetailFromItemDraft(
        draft.details[i],
        memberID,
        id,
        id * 1000 + i,
        i
      ));
    }
    report.medExamDetails = details;
    return report;
  }

  static applyingRecognitionDraft(
    report: RemoteExaminationReportWithAttachments,
    draft: MedicalReportRecognitionDraft
  ): RemoteExaminationReportWithAttachments {
    const updated = report.clone();
    updated.category = draft.category ?? updated.category;
    updated.itemName = draft.title;
    updated.organizationName = draft.hospital;
    updated.doctorName = draft.doctor;
    updated.findings = MedicalReportResultSupport.resolvedFindingsText(draft);
    updated.impression = MedicalReportResultSupport.resolvedImpressionText(draft);
    const dateText = nonEmptyText(draft.date);
    if (dateText.length > 0) {
      updated.reportedAt = dateText;
      updated.performedAt = dateText;
    }
    updated.detailsLoaded = true;
    const details: RemoteMedExamDetail[] = [];
    for (let i = 0; i < draft.details.length; i++) {
      details.push(ExaminationReportDraftMapping.remoteMedExamDetailFromItemDraft(
        draft.details[i],
        updated.member,
        updated.id,
        i + 1,
        i
      ));
    }
    updated.medExamDetails = details;
    return updated;
  }

  static cloneItemDraft(source: ItemDraft): ItemDraft {
    const copy = new ItemDraft();
    copy.id = source.id.length > 0 ? source.id : ExaminationReportDraftMapping.newItemId();
    copy.category = source.category;
    copy.subCategory = source.subCategory;
    copy.itemName = source.itemName;
    copy.resultValue = source.resultValue;
    copy.unit = source.unit;
    copy.referenceRange = source.referenceRange;
    copy.flag = source.flag;
    copy.modality = source.modality;
    copy.bodyPart = source.bodyPart;
    copy.resultAt = source.resultAt;
    copy.diagnosis = source.diagnosis;
    return copy;
  }

  static cloneDraft(source: MedicalReportRecognitionDraft): MedicalReportRecognitionDraft {
    const copy = new MedicalReportRecognitionDraft();
    copy.category = source.category;
    copy.title = source.title;
    copy.hospital = source.hospital;
    copy.doctor = source.doctor;
    copy.content = source.content;
    copy.date = source.date;
    copy.attachmentFileIds = source.attachmentFileIds.slice();
    const details: ItemDraft[] = [];
    for (let i = 0; i < source.details.length; i++) {
      details.push(ExaminationReportDraftMapping.cloneItemDraft(source.details[i]));
    }
    copy.details = details;
    return copy;
  }
}
