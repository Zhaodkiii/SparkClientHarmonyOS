import { AppContainer } from '../../../../../../App/AppContainer';
import { MedicalArchiveListMode } from '../../../../../Core/Networking/API/Medical/MedicalArchiveModels';
import {
  RemoteHealthExamReportWithAttachments,
  RemoteMedExamDetail
} from '../../../../../Core/Networking/API/Medical/MedicalSyncAPI';
import { NotificationClient } from '../../../../../Core/Notification/Application/NotificationClient';
import { Logger } from '../../../../../../Foundation/Logging/Logger';
import { LogFields } from '../../../../../../Foundation/Logging/LogEvent';
import { LogModule } from '../../../../../../Foundation/Logging/LogModule';
import { HomeViewModel } from '../../HomeViewModel';
import { HealthExamArchiveMutationService } from '../Shared/HealthExamArchiveMutationService';
import {
  formatExamDateText,
  healthExamRiskTint,
  healthExamRiskTitle,
  inferredHealthExamRiskLevel,
  HealthExamRiskLevel,
  nonEmptyText
} from '../Shared/HealthExamFlagSupport';
import {
  MEDICAL_LIST_ACCENT,
  MEDICAL_LIST_PAGE_BG,
  MedicalListPageHeaderChrome
} from '../Shared/MedicalListPageChrome';

/**
 * 体检详情（只读）。对齐 iOS HealthExamReportDetailPage → HealthExamRecognitionResultView(detail)。
 */
@Component
export struct HealthExamReportDetailPage {
  homeVm?: HomeViewModel;
  onBack?: () => void;
  onDeleted?: (reportID: number) => void;
  onArchiveStateChanged?: (reportID: number, isArchived: boolean) => void;

  @State private tick: number = 0;
  @State private errorText: string = '';
  @State private busy: boolean = false;
  @State private showDeleteConfirm: boolean = false;
  @State private showArchiveConfirm: boolean = false;
  @State private isArchived: boolean = false;

  private report: RemoteHealthExamReportWithAttachments = new RemoteHealthExamReportWithAttachments();
  private archiveMode: MedicalArchiveListMode = MedicalArchiveListMode.ACTIVE;
  private notification?: NotificationClient;
  private archiveService?: HealthExamArchiveMutationService;

  aboutToAppear(): void {
    const container = AppContainer.shared();
    const query = container?.backend.medicalQuery;
    this.notification = container?.notificationClient;
    if (query) {
      this.archiveService = new HealthExamArchiveMutationService(query.workflowAPI);
    }
    const target = this.homeVm?.healthExamDetailTarget;
    if (target) {
      this.report = target.clone();
      this.isArchived = target.isArchived;
    }
    this.archiveMode = this.homeVm?.healthExamDetailArchiveMode ?? MedicalArchiveListMode.ACTIVE;
    this.tick += 1;
  }

  private titleText(): string {
    const institution = nonEmptyText(this.report.institutionName);
    if (institution.length > 0) {
      return institution;
    }
    return '体检报告';
  }

  private detailRows(): RemoteMedExamDetail[] {
    return this.report.medExamDetails;
  }

  private categoryLine(item: RemoteMedExamDetail): string {
    const category = nonEmptyText(item.category);
    const sub = nonEmptyText(item.subCategory);
    if (category.length > 0 && sub.length > 0) {
      return `${category} · ${sub}`;
    }
    if (category.length > 0) {
      return category;
    }
    return sub;
  }

  private riskOf(item: RemoteMedExamDetail): HealthExamRiskLevel {
    return inferredHealthExamRiskLevel(
      item.flag,
      nonEmptyText(item.diagnosis),
      nonEmptyText(item.resultValue),
      item.referenceRange
    );
  }

  private async deleteReport(): Promise<void> {
    const service = this.archiveService;
    if (!service || this.busy) {
      return;
    }
    this.busy = true;
    this.errorText = '';
    try {
      await service.deleteReport(this.report.id);
      this.notification?.success('体检报告已删除', undefined, 'health.exam.detail');
      if (this.onDeleted) {
        this.onDeleted(this.report.id);
      }
      if (this.onBack) {
        this.onBack();
      }
    } catch (e) {
      const message = `${e}`;
      this.errorText = message;
      this.notification?.error(message, '删除失败', 'health.exam.detail');
      const fields = new LogFields();
      fields.detail = message;
      Logger.warn('health_exam.detail.delete_failed', LogModule.HOME, fields);
    } finally {
      this.busy = false;
      this.showDeleteConfirm = false;
    }
  }

  private async toggleArchive(): Promise<void> {
    const service = this.archiveService;
    if (!service || this.busy) {
      return;
    }
    const nextArchived = !this.isArchived;
    this.busy = true;
    this.errorText = '';
    try {
      const updated = await service.setArchived(this.report.id, nextArchived);
      this.report = updated.clone();
      this.isArchived = updated.isArchived;
      this.notification?.success(
        nextArchived ? '已归档' : '已取消归档',
        undefined,
        'health.exam.detail.archive'
      );
      if (this.onArchiveStateChanged) {
        this.onArchiveStateChanged(updated.id, updated.isArchived);
      }
      const belongs = this.archiveMode === MedicalArchiveListMode.ARCHIVED
        ? updated.isArchived
        : !updated.isArchived;
      if (!belongs && this.onBack) {
        this.onBack();
      }
      this.tick += 1;
    } catch (e) {
      const message = `${e}`;
      this.errorText = message;
      this.notification?.error(message, '操作失败', 'health.exam.detail.archive');
      const fields = new LogFields();
      fields.detail = message;
      Logger.warn('health_exam.detail.archive_failed', LogModule.HOME, fields);
    } finally {
      this.busy = false;
      this.showArchiveConfirm = false;
    }
  }

  @Builder
  private detailTrailing() {
    Row({ space: 8 }) {
      Text(this.isArchived ? '取消归档' : '归档')
        .fontSize(14)
        .fontColor(MEDICAL_LIST_ACCENT)
        .onClick(() => {
          this.showArchiveConfirm = true;
        })
      Text('删除')
        .fontSize(14)
        .fontColor('#FF3B30')
        .onClick(() => {
          this.showDeleteConfirm = true;
        })
    }
  }

  build() {
    Column() {
      MedicalListPageHeaderChrome({
        title: this.titleText(),
        titleFontSize: 17,
        onBack: () => {
          if (this.onBack) {
            this.onBack();
          }
        },
        trailing: this.detailTrailing,
        showDivider: false
      })

      if (this.busy) {
        LoadingProgress().width(24).height(24).margin({ bottom: 8 })
      }

      if (this.errorText.length > 0) {
        Text(this.errorText)
          .fontSize(13)
          .fontColor('#FF3B30')
          .width('100%')
          .padding({ left: 16, right: 16, bottom: 8 })
      }

      Scroll() {
        Column({ space: 12 }) {
          Column({ space: 8 }) {
            if (formatExamDateText(this.report.examDate).length > 0) {
              Text(`体检日期 ${formatExamDateText(this.report.examDate)}`)
                .fontSize(13)
                .fontColor('#8E8E93')
                .width('100%')
            }
            if (nonEmptyText(this.report.reportNo).length > 0) {
              Text(`报告编号 ${nonEmptyText(this.report.reportNo)}`)
                .fontSize(13)
                .fontColor('#8E8E93')
                .width('100%')
            }
            if (nonEmptyText(this.report.summary).length > 0) {
              Text(nonEmptyText(this.report.summary))
                .fontSize(14)
                .fontColor('#1C1C1E')
                .width('100%')
            }
            Text(`附件 ${this.report.attachments.length} · 明细 ${this.detailRows().length}`)
              .fontSize(12)
              .fontColor('#AEAEB2')
              .width('100%')
          }
          .width('100%')
          .padding(16)
          .backgroundColor('#FFFFFF')
          .borderRadius(12)

          if (this.detailRows().length === 0) {
            Text('暂无体检明细')
              .fontSize(14)
              .fontColor('#8E8E93')
              .width('100%')
              .padding(24)
              .textAlign(TextAlign.Center)
          } else {
            ForEach(this.detailRows(), (item: RemoteMedExamDetail) => {
              this.detailRow(item)
            }, (item: RemoteMedExamDetail) => `detail-${item.id}-${this.tick}`)
          }
          Blank().height(24)
        }
        .width('100%')
        .padding({ left: 16, right: 16, bottom: 16 })
      }
      .layoutWeight(1)
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor(MEDICAL_LIST_PAGE_BG)
    .bindSheet(this.showDeleteConfirm, this.deleteSheetBuilder, {
      height: SheetSize.FIT_CONTENT,
      dragBar: true,
      showClose: true,
      onDisappear: () => {
        this.showDeleteConfirm = false;
      }
    })
    .bindSheet(this.showArchiveConfirm, this.archiveSheetBuilder, {
      height: SheetSize.FIT_CONTENT,
      dragBar: true,
      showClose: true,
      onDisappear: () => {
        this.showArchiveConfirm = false;
      }
    })
  }

  @Builder
  detailRow(item: RemoteMedExamDetail) {
    Column({ space: 6 }) {
      Row() {
        Text(nonEmptyText(item.itemName).length > 0 ? item.itemName : `项目 #${item.id}`)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor('#1C1C1E')
          .layoutWeight(1)
        Text(healthExamRiskTitle(this.riskOf(item)))
          .fontSize(12)
          .fontColor(healthExamRiskTint(this.riskOf(item)))
      }
      .width('100%')

      if (this.categoryLine(item).length > 0) {
        Text(this.categoryLine(item))
          .fontSize(12)
          .fontColor('#8E8E93')
          .width('100%')
      }

      Row({ space: 8 }) {
        if (nonEmptyText(item.resultValue).length > 0 || nonEmptyText(item.unit).length > 0) {
          Text(`${nonEmptyText(item.resultValue)}${nonEmptyText(item.unit)}`)
            .fontSize(13)
            .fontColor('#3A3A3C')
        }
        if (nonEmptyText(item.referenceRange).length > 0) {
          Text(`参考 ${nonEmptyText(item.referenceRange)}`)
            .fontSize(12)
            .fontColor('#AEAEB2')
        }
        if (nonEmptyText(item.flag).length > 0) {
          Text(nonEmptyText(item.flag))
            .fontSize(12)
            .fontColor('#FF3B30')
        }
      }
      .width('100%')

      if (nonEmptyText(item.diagnosis).length > 0) {
        Text(nonEmptyText(item.diagnosis))
          .fontSize(12)
          .fontColor('#3A3A3C')
          .width('100%')
      }
    }
    .width('100%')
    .padding(14)
    .backgroundColor('#FFFFFF')
    .borderRadius(12)
  }

  @Builder
  deleteSheetBuilder() {
    Column({ space: 12 }) {
      Text('删除体检报告？')
        .fontSize(17)
        .fontWeight(FontWeight.Medium)
      Text('删除后该报告将从列表中移除。')
        .fontSize(14)
        .fontColor('#8E8E93')
      Row({ space: 12 }) {
        Button('取消')
          .layoutWeight(1)
          .backgroundColor('#F2F2F7')
          .fontColor('#1C1C1E')
          .onClick(() => {
            this.showDeleteConfirm = false;
          })
        Button('删除')
          .layoutWeight(1)
          .backgroundColor('#FF3B30')
          .fontColor(Color.White)
          .onClick(() => {
            this.deleteReport();
          })
      }
      .width('100%')
    }
    .width('100%')
    .padding(20)
  }

  @Builder
  archiveSheetBuilder() {
    Column({ space: 12 }) {
      Text(this.isArchived ? '取消归档？' : '归档该报告？')
        .fontSize(17)
        .fontWeight(FontWeight.Medium)
      Text(this.isArchived ? '取消后将回到活跃列表。' : '归档后可在归档列表中查看。')
        .fontSize(14)
        .fontColor('#8E8E93')
      Row({ space: 12 }) {
        Button('取消')
          .layoutWeight(1)
          .backgroundColor('#F2F2F7')
          .fontColor('#1C1C1E')
          .onClick(() => {
            this.showArchiveConfirm = false;
          })
        Button(this.isArchived ? '取消归档' : '归档')
          .layoutWeight(1)
          .backgroundColor('#0A84FF')
          .fontColor(Color.White)
          .onClick(() => {
            this.toggleArchive();
          })
      }
      .width('100%')
    }
    .width('100%')
    .padding(20)
  }
}
