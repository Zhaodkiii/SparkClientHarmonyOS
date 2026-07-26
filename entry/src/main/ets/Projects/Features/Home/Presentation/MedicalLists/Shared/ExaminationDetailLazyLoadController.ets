import { SparkMedicalQueryAPI } from '../../../../../Core/Networking/API/Medical/MedicalQueryAPI';
import {
  RemoteExaminationReportWithAttachments,
  RemoteMedExamDetail
} from '../../../../../Core/Networking/API/Medical/MedicalSyncAPI';
import { Logger } from '../../../../../../Foundation/Logging/Logger';
import { LogFields } from '../../../../../../Foundation/Logging/LogEvent';
import { LogModule } from '../../../../../../Foundation/Logging/LogModule';

const ACCEPTED_BUSINESS_TYPES: string[] = ['examination_report', 'examination'];
const DETAIL_BUSINESS_TYPE: string = 'examination_report';

/**
 * 检查报告明细懒加载。对齐 iOS MedExamDetailLazyLoadViewModel（检查分支）。
 * business_type=examination_report；禁止与体检 health_exam_report 混用。
 */
export class ExaminationDetailLazyLoadController {
  reports: RemoteExaminationReportWithAttachments[] = [];
  private loadingIds: number[] = [];
  private readonly medicalQueryAPI: SparkMedicalQueryAPI;
  private readonly onReportsUpdated?: (reports: RemoteExaminationReportWithAttachments[]) => void;

  constructor(
    reports: RemoteExaminationReportWithAttachments[],
    medicalQueryAPI: SparkMedicalQueryAPI,
    onReportsUpdated?: (reports: RemoteExaminationReportWithAttachments[]) => void
  ) {
    this.reports = reports.slice();
    this.medicalQueryAPI = medicalQueryAPI;
    this.onReportsUpdated = onReportsUpdated;
  }

  /** 对齐 iOS：medExamDetails 已回填则视为已加载，滚动/重进列表不重复请求。 */
  static hasLoadedDetails(report: RemoteExaminationReportWithAttachments): boolean {
    return report.detailsLoaded;
  }

  /**
   * 将摘要列表与已有明细合并。用于 hydrate / revision 回写时保留已懒加载的子数据，
   * 避免重进列表或首页缓存已含明细时再次打网。
   */
  static mergePreservingLoadedDetails(
    incoming: RemoteExaminationReportWithAttachments[],
    existing: RemoteExaminationReportWithAttachments[]
  ): RemoteExaminationReportWithAttachments[] {
    const loadedById = new Map<number, RemoteExaminationReportWithAttachments>();
    for (let i = 0; i < existing.length; i++) {
      const row = existing[i];
      if (ExaminationDetailLazyLoadController.hasLoadedDetails(row)) {
        loadedById.set(row.id, row);
      }
    }
    const merged: RemoteExaminationReportWithAttachments[] = [];
    for (let i = 0; i < incoming.length; i++) {
      const row = incoming[i];
      const previous = loadedById.get(row.id);
      if (previous) {
        const copy = row.clone();
        copy.detailsLoaded = true;
        copy.medExamDetails = previous.medExamDetails.slice();
        merged.push(copy);
      } else {
        merged.push(row);
      }
    }
    return merged;
  }

  isLoading(reportID: number): boolean {
    return this.loadingIds.indexOf(reportID) >= 0;
  }

  replaceReports(newReports: RemoteExaminationReportWithAttachments[]): void {
    this.reports = newReports.slice();
    this.emit();
  }

  removeReport(reportID: number): void {
    const next: RemoteExaminationReportWithAttachments[] = [];
    for (let i = 0; i < this.reports.length; i++) {
      if (this.reports[i].id !== reportID) {
        next.push(this.reports[i]);
      }
    }
    this.reports = next;
    this.emit();
  }

  upsertReport(report: RemoteExaminationReportWithAttachments): void {
    let found = false;
    for (let i = 0; i < this.reports.length; i++) {
      if (this.reports[i].id === report.id) {
        this.reports[i] = report;
        found = true;
        break;
      }
    }
    if (!found) {
      const next: RemoteExaminationReportWithAttachments[] = [report];
      for (let i = 0; i < this.reports.length; i++) {
        next.push(this.reports[i]);
      }
      this.reports = next;
    }
    this.emit();
  }

  async loadDetailsIfNeeded(reportID: number): Promise<void> {
    let index = -1;
    for (let i = 0; i < this.reports.length; i++) {
      if (this.reports[i].id === reportID) {
        index = i;
        break;
      }
    }
    if (index < 0) {
      return;
    }
    if (ExaminationDetailLazyLoadController.hasLoadedDetails(this.reports[index])) {
      return;
    }
    if (this.loadingIds.indexOf(reportID) >= 0) {
      return;
    }
    this.loadingIds.push(reportID);
    const memberID = this.reports[index].member;
    const fields = new LogFields();
    fields.detail = `reportID=${reportID} memberID=${memberID}`;
    Logger.info('examination.details.load_start', LogModule.HOME, fields);
    try {
      const rows = await this.medicalQueryAPI.listMedExamDetails(memberID, DETAIL_BUSINESS_TYPE, reportID);
      const filtered = this.filterAndSort(rows);
      const updated = this.reports[index].clone();
      updated.detailsLoaded = true;
      updated.medExamDetails = filtered;
      this.reports[index] = updated;
      this.emit();
      const done = new LogFields();
      done.detail = `reportID=${reportID} count=${filtered.length}`;
      Logger.info('examination.details.load_done', LogModule.HOME, done);
    } catch (e) {
      const warn = new LogFields();
      warn.detail = `reportID=${reportID} error=${e}`;
      Logger.warn('examination.details.load_failed', LogModule.HOME, warn);
    } finally {
      const nextLoading: number[] = [];
      for (let i = 0; i < this.loadingIds.length; i++) {
        if (this.loadingIds[i] !== reportID) {
          nextLoading.push(this.loadingIds[i]);
        }
      }
      this.loadingIds = nextLoading;
    }
  }

  private filterAndSort(rows: RemoteMedExamDetail[]): RemoteMedExamDetail[] {
    const filtered: RemoteMedExamDetail[] = [];
    for (let i = 0; i < rows.length; i++) {
      const normalized = rows[i].businessType.toLowerCase();
      let accepted = false;
      for (let j = 0; j < ACCEPTED_BUSINESS_TYPES.length; j++) {
        if (ACCEPTED_BUSINESS_TYPES[j] === normalized) {
          accepted = true;
          break;
        }
      }
      if (accepted || rows.length === 1) {
        filtered.push(rows[i]);
      }
    }
    filtered.sort((lhs: RemoteMedExamDetail, rhs: RemoteMedExamDetail): number => {
      if (lhs.sortOrder === rhs.sortOrder) {
        return lhs.id - rhs.id;
      }
      return lhs.sortOrder - rhs.sortOrder;
    });
    return filtered;
  }

  private emit(): void {
    if (this.onReportsUpdated) {
      this.onReportsUpdated(this.reports.slice());
    }
  }
}
