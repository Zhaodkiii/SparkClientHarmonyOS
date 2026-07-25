import { RemoteExaminationReportWithAttachments } from '../../../../../Core/Networking/API/Medical/MedicalSyncAPI';
import { nonEmptyText } from '../Shared/HealthExamFlagSupport';

/** 客户端分类。对齐 iOS ExaminationReportCategory；非后端独立资源。 */
export type ExaminationReportCategory = 'laboratory' | 'imaging' | 'pathology';

export type ExaminationFilterKey = 'all' | ExaminationReportCategory;

export function examinationCategoryTitle(category: ExaminationReportCategory): string {
  if (category === 'imaging') {
    return '影像';
  }
  if (category === 'pathology') {
    return '病理';
  }
  return '实验室';
}

export function examinationCategoryTint(category: ExaminationReportCategory): string {
  if (category === 'imaging') {
    return '#5856D6';
  }
  if (category === 'pathology') {
    return '#AF52DE';
  }
  return '#0A84FF';
}

/**
 * 分类图标。对齐 iOS 分类语义（testtube.2 / camera.fill / doc.text.magnifyingglass），
 * 但 ArkUI SymbolGlyph 仅能使用工程内已验证可用的 sys.symbol，故做近似映射：
 * 实验室→square_stack_3d（成组管），影像→doc_text（成像文档），病理→checkmark_circle_fill（诊断结论）。
 * 这是平台图标集受限下的近似对齐，非像素级图标复刻。
 */
export function examinationCategoryIcon(category: ExaminationReportCategory): Resource {
  if (category === 'imaging') {
    return $r('sys.symbol.doc_text');
  }
  if (category === 'pathology') {
    return $r('sys.symbol.checkmark_circle_fill');
  }
  return $r('sys.symbol.square_stack_3d');
}

/** 全部分类图标（用于筛选栏「全部」以外的分类 Chip）。 */
export function examinationAllFilterIcon(): Resource {
  return $r('sys.symbol.square_stack_3d');
}

/**
 * 分类匹配：字面 → 摘要关键词 → 默认 laboratory（对齐 iOS）。
 */
export function resolveExaminationCategory(
  report: RemoteExaminationReportWithAttachments
): ExaminationReportCategory {
  const blob = `${nonEmptyText(report.category)} ${nonEmptyText(report.subCategory)}`.toLowerCase();
  if (blob.indexOf('影像') >= 0
    || blob.indexOf('imaging') >= 0
    || blob.indexOf('ct') >= 0
    || blob.indexOf('mr') >= 0
    || blob.indexOf('超声') >= 0
    || blob.indexOf('x线') >= 0
    || blob.indexOf('x-ray') >= 0) {
    return 'imaging';
  }
  if (blob.indexOf('病理') >= 0 || blob.indexOf('patholog') >= 0) {
    return 'pathology';
  }
  if (blob.indexOf('检验') >= 0
    || blob.indexOf('实验室') >= 0
    || blob.indexOf('laboratory') >= 0
    || blob.indexOf('lab') >= 0) {
    return 'laboratory';
  }

  const narrative =
    `${nonEmptyText(report.findings)} ${nonEmptyText(report.impression)} ${nonEmptyText(report.itemName)}`
      .toLowerCase();
  if (narrative.indexOf('影像') >= 0
    || narrative.indexOf('ct') >= 0
    || narrative.indexOf('mr') >= 0
    || narrative.indexOf('超声') >= 0) {
    return 'imaging';
  }
  if (narrative.indexOf('病理') >= 0) {
    return 'pathology';
  }
  return 'laboratory';
}

export function examinationCategoryMatches(
  report: RemoteExaminationReportWithAttachments,
  filter: ExaminationFilterKey
): boolean {
  if (filter === 'all') {
    return true;
  }
  return resolveExaminationCategory(report) === filter;
}

/** 时间线排序键：reportedAt ?? performedAt。 */
export function examinationSortKey(report: RemoteExaminationReportWithAttachments): string {
  const reported = nonEmptyText(report.reportedAt);
  if (reported.length > 0) {
    return reported;
  }
  return nonEmptyText(report.performedAt);
}

export function formatExaminationDateText(report: RemoteExaminationReportWithAttachments): string {
  const raw = examinationSortKey(report);
  if (raw.length >= 10) {
    return raw.substring(0, 10).replace(/-/g, '/');
  }
  return raw;
}

/** 时间线分组：连续同分类的报告聚合为一段。对齐 iOS ExaminationReportTimelineSection.makeSections。 */
export interface ExaminationTimelineSection {
  category: ExaminationReportCategory;
  reports: RemoteExaminationReportWithAttachments[];
}

export function buildExaminationTimelineSections(
  reports: RemoteExaminationReportWithAttachments[]
): ExaminationTimelineSection[] {
  const sorted = reports.slice().sort(
    (lhs: RemoteExaminationReportWithAttachments, rhs: RemoteExaminationReportWithAttachments): number => {
      const a = examinationSortKey(lhs);
      const b = examinationSortKey(rhs);
      if (a === b) {
        return 0;
      }
      return a < b ? 1 : -1;
    }
  );

  const sections: ExaminationTimelineSection[] = [];
  for (let i = 0; i < sorted.length; i++) {
    const report = sorted[i];
    const category = resolveExaminationCategory(report);
    const last = sections.length > 0 ? sections[sections.length - 1] : undefined;
    if (last && last.category === category) {
      last.reports.push(report);
    } else {
      sections.push({ category: category, reports: [report] });
    }
  }
  return sections;
}
