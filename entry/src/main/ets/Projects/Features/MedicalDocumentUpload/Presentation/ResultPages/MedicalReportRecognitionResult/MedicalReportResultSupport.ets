import { RemoteExaminationReportWithAttachments } from
  '../../../../../Core/Networking/API/Medical/MedicalSyncAPI';
import { MedicalReportRecognitionDraft } from '../../../Domain/MedicalDocumentRecognitionDrafts';
import { MedicalDocumentKind } from '../../../Domain/MedicalDocumentKind';
import { MedicalDocumentUploadViewModel } from '../../MedicalDocumentUploadViewModel';
import { MedicalPreSubmitValidationIssue, MedicalPreSubmitValidationResourceType } from
  '../../../Domain/MedicalPreSubmitValidationIssue';
import { MedicalAttachmentInput } from
  '../../../../Home/Presentation/MedicalLists/MedicalDocumentAttachmentUploader';
import { ExaminationReportCategory, examinationCategoryTint, examinationCategoryTitle } from
  '../../../../Home/Presentation/MedicalLists/ExaminationReports/ExaminationReportCategory';
import { ExaminationReportDraftMapping } from
  '../../../../Home/Presentation/MedicalLists/ExaminationReports/ExaminationReportDraftMapping';
import { MedicalDocumentLocalAttachmentItem } from '../MedicalDocumentLocalAttachmentItem';

/** 识别结果页报告卡片 → 本地草稿详情导航目标。 */
export class MedicalReportCardDetailTarget {
  index: number = 0;
  category: ExaminationReportCategory = 'laboratory';
}

/**
 * 检查报告识别结果页支持方法。对齐 iOS `ExaminationReportCategory` / `MedicalReportResultSections` 分类与文案逻辑。
 */
export class MedicalReportResultSupport {
  static reports(viewModel: MedicalDocumentUploadViewModel): MedicalReportRecognitionDraft[] {
    const tree = viewModel.ensureTypedDraftTree(MedicalDocumentKind.MEDICAL_REPORT);
    return tree.medicalReportDrafts;
  }

  static ensureFirst(viewModel: MedicalDocumentUploadViewModel): MedicalReportRecognitionDraft {
    const tree = viewModel.ensureTypedDraftTree(MedicalDocumentKind.MEDICAL_REPORT);
    if (tree.medicalReportDrafts.length === 0) {
      tree.medicalReportDrafts.push(new MedicalReportRecognitionDraft());
    }
    return tree.medicalReportDrafts[0];
  }

  static addReport(viewModel: MedicalDocumentUploadViewModel): void {
    const tree = viewModel.ensureTypedDraftTree(MedicalDocumentKind.MEDICAL_REPORT);
    tree.medicalReportDrafts.push(new MedicalReportRecognitionDraft());
    viewModel.notifyTypedDraftChanged();
  }

  static deleteReport(viewModel: MedicalDocumentUploadViewModel, index: number): void {
    const list = MedicalReportResultSupport.reports(viewModel);
    if (index < 0 || index >= list.length) {
      return;
    }
    list.splice(index, 1);
    viewModel.notifyTypedDraftChanged();
  }

  static updateReportDraftAt(
    viewModel: MedicalDocumentUploadViewModel,
    index: number,
    draft: MedicalReportRecognitionDraft
  ): void {
    const list = MedicalReportResultSupport.reports(viewModel);
    if (index < 0 || index >= list.length) {
      return;
    }
    let resolved = ExaminationReportDraftMapping.cloneDraft(draft);
    if (resolved.attachmentFileIds.length === 0) {
      resolved.attachmentFileIds = list[index].attachmentFileIds.slice();
    }
    list[index] = resolved;
    viewModel.notifyTypedDraftChanged();
  }

  static temporaryExaminationReportID(index: number): number {
    return -10000 - index;
  }

  static associatedAttachmentFileIds(reports: MedicalReportRecognitionDraft[]): string[] {
    const ids: string[] = [];
    for (let i = 0; i < reports.length; i++) {
      const fileIds = reports[i].attachmentFileIds;
      for (let j = 0; j < fileIds.length; j++) {
        if (ids.indexOf(fileIds[j]) < 0) {
          ids.push(fileIds[j]);
        }
      }
    }
    return ids;
  }

  static unlinkedAttachmentNames(
    viewModel: MedicalDocumentUploadViewModel,
    reports: MedicalReportRecognitionDraft[]
  ): string[] {
    const associated = new Set<string>(MedicalReportResultSupport.associatedAttachmentFileIds(reports));
    const names: string[] = [];
    for (let i = 0; i < viewModel.selectedFiles.length; i++) {
      const file = viewModel.selectedFiles[i];
      if (!associated.has(file.previewId)) {
        names.push(file.originalName.length > 0 ? file.originalName : file.previewId);
      }
    }
    return names;
  }

  static issueSummaryLines(viewModel: MedicalDocumentUploadViewModel, index: number): string[] {
    const issues = MedicalReportResultSupport.cardIssues(viewModel, index);
    const lines: string[] = [];
    const limit = issues.length > 3 ? 3 : issues.length;
    for (let i = 0; i < limit; i++) {
      lines.push(issues[i].summaryLine());
    }
    return lines;
  }

  static err(viewModel: MedicalDocumentUploadViewModel, fieldKey: string): string {
    return viewModel.preSubmitIssueMessage(fieldKey);
  }

  /**
   * 客户端分类归一：优先按字面标准值匹配，兜底归为实验室检查。
   * 对齐 iOS `ExaminationReportCategory.from(_:)`。
   */
  static categoryOf(rawCategory?: string): ExaminationReportCategory {
    const trimmed = (rawCategory ?? '').trim().toLowerCase();
    if (trimmed.length === 0) {
      return 'laboratory';
    }
    if (['laboratory', 'lab', '实验室检查', '检验', '化验'].indexOf(trimmed) >= 0) {
      return 'laboratory';
    }
    if (['imaging', 'image', '影像', '影像学检查'].indexOf(trimmed) >= 0) {
      return 'imaging';
    }
    if (['pathology', '病理', '病理检查'].indexOf(trimmed) >= 0) {
      return 'pathology';
    }
    if (trimmed.indexOf('影像') >= 0 || trimmed.indexOf('超声') >= 0 || trimmed.indexOf('ct') >= 0
      || trimmed.indexOf('mr') >= 0 || trimmed.indexOf('放射') >= 0 || trimmed.indexOf('x线') >= 0
      || trimmed.indexOf('b超') >= 0 || trimmed.indexOf('彩超') >= 0 || trimmed.indexOf('image') >= 0) {
      return 'imaging';
    }
    if (trimmed.indexOf('病理') >= 0 || trimmed.indexOf('path') >= 0) {
      return 'pathology';
    }
    return 'laboratory';
  }

  static categoryTitle(category: ExaminationReportCategory): string {
    return examinationCategoryTitle(category);
  }

  static categoryTint(category: ExaminationReportCategory): string {
    return examinationCategoryTint(category);
  }

  static readonly ALL_CATEGORIES: ExaminationReportCategory[] = ['laboratory', 'imaging', 'pathology'];

  /** 各分类统计：对齐 iOS `overviewContent` 统计卡片。 */
  static categoryCounts(reports: MedicalReportRecognitionDraft[]): CategoryCount[] {
    return MedicalReportResultSupport.ALL_CATEGORIES.map((category: ExaminationReportCategory) => {
      const count = reports.filter(
        (report: MedicalReportRecognitionDraft): boolean =>
          MedicalReportResultSupport.categoryOf(report.category) === category
      ).length;
      return new CategoryCount(category, count);
    });
  }

  private static isImagingOrPathology(category?: string): boolean {
    const category0 = MedicalReportResultSupport.categoryOf(category);
    return category0 === 'imaging' || category0 === 'pathology';
  }

  /** 报告「所见」：优先 `content`。对齐 iOS `resolvedFindingsText`。 */
  static resolvedFindingsText(report: MedicalReportRecognitionDraft): string {
    return (report.content ?? '').trim();
  }

  /** 报告「印象/结论」：影像/病理拼接明细 `diagnosis`；其他类型与 `content` 一致。对齐 iOS `resolvedImpressionText`。 */
  static resolvedImpressionText(report: MedicalReportRecognitionDraft): string {
    if (MedicalReportResultSupport.isImagingOrPathology(report.category)) {
      const joined = report.details
        .map((item): string => (item.diagnosis ?? '').trim())
        .filter((text: string): boolean => text.length > 0)
        .join('\n');
      if (joined.length > 0) {
        return joined;
      }
    }
    return (report.content ?? '').trim();
  }

  /** 该报告卡片是否存在预提交校验问题。对齐 iOS `cardIssues`。 */
  static cardIssues(
    viewModel: MedicalDocumentUploadViewModel,
    index: number
  ): MedicalPreSubmitValidationIssue[] {
    return viewModel.preSubmitValidationIssues.filter(
      (issue: MedicalPreSubmitValidationIssue): boolean =>
        issue.resourceType === MedicalPreSubmitValidationResourceType.EXAMINATION_REPORT &&
        issue.cardIndex === index
    );
  }

  /** 该报告已匹配的源文件名。对齐 iOS `matchedAttachments(for:)`。 */
  static matchedAttachmentNames(
    viewModel: MedicalDocumentUploadViewModel,
    attachmentFileIds: string[]
  ): string[] {
    return MedicalReportResultSupport.matchedAttachments(viewModel, attachmentFileIds)
      .map((item: MedicalDocumentLocalAttachmentItem): string => item.displayName);
  }

  /** 该报告已匹配的源文件项。 */
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

  static allLocalAttachments(viewModel: MedicalDocumentUploadViewModel): MedicalDocumentLocalAttachmentItem[] {
    return MedicalDocumentLocalAttachmentItem.fromAttachments(viewModel.selectedFiles);
  }

  static unlinkedAttachments(
    viewModel: MedicalDocumentUploadViewModel,
    reports: MedicalReportRecognitionDraft[]
  ): MedicalDocumentLocalAttachmentItem[] {
    const associated = new Set<string>(MedicalReportResultSupport.associatedAttachmentFileIds(reports));
    const items: MedicalDocumentLocalAttachmentItem[] = [];
    for (let i = 0; i < viewModel.selectedFiles.length; i++) {
      const file = viewModel.selectedFiles[i];
      if (!associated.has(file.previewId)) {
        items.push(MedicalDocumentLocalAttachmentItem.fromAttachment(file));
      }
    }
    return items;
  }

  static removeAttachmentIDsFromOtherReports(
    viewModel: MedicalDocumentUploadViewModel,
    ids: string[],
    exceptIndex: number
  ): void {
    if (ids.length === 0) {
      return;
    }
    const idSet = new Set<string>(ids);
    const list = MedicalReportResultSupport.reports(viewModel);
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

  static setReportAttachmentIDs(
    viewModel: MedicalDocumentUploadViewModel,
    index: number,
    ids: string[]
  ): void {
    const list = MedicalReportResultSupport.reports(viewModel);
    if (index < 0 || index >= list.length) {
      return;
    }
    MedicalReportResultSupport.removeAttachmentIDsFromOtherReports(viewModel, ids, index);
    list[index].attachmentFileIds = ids.slice();
    viewModel.notifyTypedDraftChanged();
  }

  /** 统计文案兜底（未按分类分组场景使用）。 */
  static categoryStats(reports: MedicalReportRecognitionDraft[]): string {
    const counts = MedicalReportResultSupport.categoryCounts(reports);
    return counts
      .map((item: CategoryCount): string =>
        `${MedicalReportResultSupport.categoryTitle(item.category)} ${item.count}`)
      .join(' · ');
  }

  static remoteReportForCard(
    viewModel: MedicalDocumentUploadViewModel,
    index: number
  ): RemoteExaminationReportWithAttachments {
    const report = MedicalReportResultSupport.reports(viewModel)[index];
    return ExaminationReportDraftMapping.remoteExaminationReportFromDraft(
      report,
      viewModel.selectedMemberID,
      MedicalReportResultSupport.temporaryExaminationReportID(index)
    );
  }

  static draftForCard(
    viewModel: MedicalDocumentUploadViewModel,
    index: number
  ): MedicalReportRecognitionDraft {
    return ExaminationReportDraftMapping.cloneDraft(MedicalReportResultSupport.reports(viewModel)[index]);
  }

  static localAttachmentNamesForCard(
    viewModel: MedicalDocumentUploadViewModel,
    index: number
  ): string[] {
    const draft = MedicalReportResultSupport.draftForCard(viewModel, index);
    const names: string[] = [];
    const files = viewModel.selectedFiles;
    for (let i = 0; i < draft.attachmentFileIds.length; i++) {
      const previewId = draft.attachmentFileIds[i];
      for (let j = 0; j < files.length; j++) {
        if (files[j].previewId === previewId) {
          const name = files[j].originalName.length > 0 ? files[j].originalName : `附件 ${j + 1}`;
          names.push(name);
          break;
        }
      }
    }
    return names;
  }
}

export class CategoryCount {
  category: ExaminationReportCategory;
  count: number;

  constructor(category: ExaminationReportCategory, count: number) {
    this.category = category;
    this.count = count;
  }
}
