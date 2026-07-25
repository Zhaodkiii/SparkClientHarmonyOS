import {
  RemoteExaminationReportWithAttachments,
  RemoteMedExamDetail
} from '../../../../../Core/Networking/API/Medical/MedicalSyncAPI';
import { isPotentiallyAbnormalFlag, nonEmptyText } from '../Shared/HealthExamFlagSupport';
import { ExaminationReportCategory } from './ExaminationReportCategory';

/** 检验单项 / 完整检验表导航目标。对齐 iOS 子项 NavigationLink 上下文。 */
export class ExaminationSubitemDetailTarget {
  report: RemoteExaminationReportWithAttachments = new RemoteExaminationReportWithAttachments();
  category: ExaminationReportCategory = 'laboratory';
  navigationTitleOverride: string = '';
  /** true：查看完整检验表（LaboratoryReportDetailPage）；false：单项详情路由。 */
  isFullLabTable: boolean = false;
}

export class ExaminationReportDetailSupport {
  /** 明细排序：sortOrder 升序，再 id 升序。对齐 iOS sortedDetails。 */
  static sortMedExamDetails(details: RemoteMedExamDetail[]): RemoteMedExamDetail[] {
    const copy = details.slice();
    copy.sort((lhs: RemoteMedExamDetail, rhs: RemoteMedExamDetail): number => {
      if (lhs.sortOrder === rhs.sortOrder) {
        return lhs.id - rhs.id;
      }
      return lhs.sortOrder - rhs.sortOrder;
    });
    return copy;
  }

  static sortedDetails(report: RemoteExaminationReportWithAttachments): RemoteMedExamDetail[] {
    return ExaminationReportDetailSupport.sortMedExamDetails(report.medExamDetails);
  }

  /** 构造仅包含指定明细行的报告副本。对齐 iOS replacingMedExamDetails。 */
  static replacingMedExamDetails(
    report: RemoteExaminationReportWithAttachments,
    details: RemoteMedExamDetail[]
  ): RemoteExaminationReportWithAttachments {
    const copy = report.clone();
    copy.medExamDetails = details.slice();
    copy.detailsLoaded = true;
    return copy;
  }

  static resultValueWithUnit(item: RemoteMedExamDetail): string {
    const value = nonEmptyText(item.resultValue);
    const unit = nonEmptyText(item.unit);
    if (value.length > 0 && unit.length > 0) {
      return `${value}${unit}`;
    }
    return value.length > 0 ? value : unit;
  }

  static flagDisplayText(flag?: string): string {
    const text = nonEmptyText(flag);
    return text.length > 0 ? text : '正常';
  }

  static flagColor(flag?: string): string {
    return isPotentiallyAbnormalFlag(nonEmptyText(flag)) ? '#FF3B30' : '#34C759';
  }

  /** 单项摘要副标题。对齐 iOS ExaminationReportSubitemSummaryRow.subtitle。 */
  static subitemSubtitle(category: ExaminationReportCategory, item: RemoteMedExamDetail): string {
    if (category === 'laboratory') {
      const parts: string[] = [];
      const result = ExaminationReportDetailSupport.resultValueWithUnit(item);
      if (result.length > 0) {
        parts.push(result);
      }
      const ref = nonEmptyText(item.referenceRange);
      if (ref.length > 0) {
        parts.push(`参考 ${ref}`);
      }
      const flag = nonEmptyText(item.flag);
      if (flag.length > 0) {
        parts.push(flag);
      }
      return parts.join(' · ');
    }
    if (category === 'imaging') {
      const parts: string[] = [];
      const modality = nonEmptyText(item.modality);
      const bodyPart = nonEmptyText(item.bodyPart);
      const result = ExaminationReportDetailSupport.resultValueWithUnit(item);
      if (modality.length > 0) {
        parts.push(modality);
      }
      if (bodyPart.length > 0) {
        parts.push(bodyPart);
      }
      if (result.length > 0) {
        parts.push(result);
      }
      return parts.join(' · ');
    }
    const parts: string[] = [];
    const result = ExaminationReportDetailSupport.resultValueWithUnit(item);
    if (result.length > 0) {
      parts.push(result);
    }
    const diagnosis = nonEmptyText(item.diagnosis);
    if (diagnosis.length > 0) {
      parts.push(diagnosis);
    }
    return parts.join(' · ');
  }

  static subitemTitle(item: RemoteMedExamDetail): string {
    const name = nonEmptyText(item.itemName);
    return name.length > 0 ? name : '未命名项目';
  }

  static resolveNavigationTitle(
    navigationTitleOverride: string,
    report: RemoteExaminationReportWithAttachments,
    fallback: string
  ): string {
    const override = nonEmptyText(navigationTitleOverride);
    if (override.length > 0) {
      return override;
    }
    const itemName = nonEmptyText(report.itemName);
    if (itemName.length > 0) {
      return itemName;
    }
    return fallback;
  }

  static formatDateField(raw?: string): string {
    const text = nonEmptyText(raw);
    if (text.length >= 10) {
      return text.substring(0, 10).replace(/-/g, '/');
    }
    return text;
  }

  static attachmentDisplayNames(
    report: RemoteExaminationReportWithAttachments,
    localNames: string[]
  ): string[] {
    const names: string[] = [];
    for (let i = 0; i < report.attachments.length; i++) {
      const name = nonEmptyText(report.attachments[i].originalName);
      if (name.length > 0) {
        names.push(name);
      }
    }
    for (let j = 0; j < localNames.length; j++) {
      if (localNames[j].length > 0) {
        names.push(localNames[j]);
      }
    }
    return names;
  }
}
