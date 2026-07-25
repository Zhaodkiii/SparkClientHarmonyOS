import {
  RemoteExaminationReportWithAttachments,
  RemoteManagedFile,
  RemoteMedExamDetail
} from '../../../../../Core/Networking/API/Medical/MedicalSyncAPI';
import { ManagedFileRecord } from '../../../../../../Core/FileStorage/FileStorageModels';
import { FileTransferService } from '../../../../../../Core/FileStorage/FileTransferService';
import { MedicalAttachmentGridPreview } from '../Shared/MedicalAttachmentComponents';
import { remoteManagedFileFromRecord } from '../Shared/MedicalAttachmentPreviewSupport';
import { HomeViewModel } from '../../HomeViewModel';
import { nonEmptyText } from '../Shared/HealthExamFlagSupport';
import {
  examinationCategoryIcon,
  examinationCategoryTint,
  examinationCategoryTitle,
  formatExaminationDateText,
  ExaminationReportCategory
} from './ExaminationReportCategory';
import {
  ExaminationReportDetailSupport,
  ExaminationSubitemDetailTarget
} from './ExaminationReportDetailSupport';
import { ExaminationReportSubitemNavigationLink } from './ExaminationReportSubitemNavigationLink';

/**
 * 检查报告总览详情内容。对齐 iOS `ExaminationReportSummaryDetailPage`：
 * 仅负责头部、附件、所见/印象、明细列表与跳转，不承接编辑/删除/归档。
 */
@Component
export struct ExaminationReportSummaryDetailPage {
  homeVm?: HomeViewModel;
  @Prop @Watch('onReportPropChanged') report: RemoteExaminationReportWithAttachments =
    new RemoteExaminationReportWithAttachments();
  @Prop category: ExaminationReportCategory = 'laboratory';
  @Prop contentTick: number = 0;
  @Prop localAttachmentNames: string[] = [];
  fileTransferService?: FileTransferService;
  onOpenSubitemDetail?: () => void;
  onRequestSubitemDetail?: (target: ExaminationSubitemDetailTarget) => void;
  onAttachmentsUpdated?: (report: RemoteExaminationReportWithAttachments) => void;

  @State private isEditingAttachments: boolean = false;
  @State private attachmentsDirty: boolean = false;
  @State private remoteAttachments: RemoteManagedFile[] = [];
  @State private attachmentErrorText: string = '';

  aboutToAppear(): void {
    this.syncRemoteAttachments();
  }

  private onReportPropChanged(): void {
    if (!this.isEditingAttachments) {
      this.syncRemoteAttachments();
    }
  }

  private syncRemoteAttachments(): void {
    this.remoteAttachments = this.report.attachments.slice();
  }

  private sortedDetails(): RemoteMedExamDetail[] {
    return ExaminationReportDetailSupport.sortedDetails(this.report);
  }

  private attachmentNames(): string[] {
    return ExaminationReportDetailSupport.attachmentDisplayNames(this.report, this.localAttachmentNames);
  }

  private showsRemoteAttachmentGrid(): boolean {
    return this.fileTransferService !== undefined &&
      (this.remoteAttachments.length > 0 || this.isEditingAttachments);
  }

  private finishAttachmentEditing(): void {
    this.isEditingAttachments = false;
    if (!this.attachmentsDirty) {
      return;
    }
    const updated = this.report.clone();
    updated.attachments = this.remoteAttachments.slice();
    if (this.onAttachmentsUpdated) {
      this.onAttachmentsUpdated(updated);
    }
    this.attachmentsDirty = false;
  }

  private async handleAttachmentDeleted(fileID: number): Promise<void> {
    const transfer = this.fileTransferService;
    if (transfer) {
      try {
        await transfer.delete(fileID);
      } catch (_e) {
        this.attachmentErrorText = '删除失败';
        return;
      }
    }
    this.remoteAttachments = this.remoteAttachments.filter(
      (file: RemoteManagedFile): boolean => file.id !== fileID
    );
    this.attachmentsDirty = true;
  }

  private async handleFileUploaded(record: ManagedFileRecord): Promise<void> {
    const transfer = this.fileTransferService;
    if (!transfer) {
      return;
    }
    try {
      await transfer.updateBusinessBinding(
        record.id,
        'examination_report',
        `${this.report.id}`
      );
      const newFile = remoteManagedFileFromRecord(
        record,
        'examination_report',
        `${this.report.id}`
      );
      this.remoteAttachments = this.remoteAttachments.concat([newFile]);
      this.attachmentsDirty = true;
    } catch (_e) {
      this.attachmentErrorText = '上传失败';
    }
  }

  private dispatchSubitem(target: ExaminationSubitemDetailTarget): void {
    if (this.onRequestSubitemDetail) {
      this.onRequestSubitemDetail(target);
      return;
    }
    const homeVm = this.homeVm;
    if (homeVm && this.onOpenSubitemDetail) {
      homeVm.examinationSubitemDetailTarget = target;
      this.onOpenSubitemDetail();
    }
  }

  private openSubitemDetail(item: RemoteMedExamDetail): void {
    const target = new ExaminationSubitemDetailTarget();
    target.report = ExaminationReportDetailSupport.replacingMedExamDetails(this.report, [item]);
    target.category = this.category;
    target.navigationTitleOverride = nonEmptyText(item.itemName);
    target.isFullLabTable = false;
    this.dispatchSubitem(target);
  }

  private openFullLabTable(): void {
    const target = new ExaminationSubitemDetailTarget();
    target.report = ExaminationReportDetailSupport.replacingMedExamDetails(
      this.report,
      this.sortedDetails()
    );
    target.category = 'laboratory';
    target.navigationTitleOverride = '';
    target.isFullLabTable = true;
    this.dispatchSubitem(target);
  }

  @Builder
  private InfoRow(label: string, value: string) {
    if (value.length > 0) {
      Row() {
        Text(label)
          .fontSize(13)
          .fontColor('#8E8E93')
          .width(72)
        Text(value)
          .fontSize(13)
          .fontColor('#1C1C1E')
          .layoutWeight(1)
      }
      .width('100%')
    }
  }

  @Builder
  private HeaderCard() {
    Column({ space: 12 }) {
      Row({ space: 10 }) {
        Column() {
          SymbolGlyph(examinationCategoryIcon(this.category))
            .fontSize(20)
            .fontColor([examinationCategoryTint(this.category)])
        }
        .width(48)
        .height(48)
        .justifyContent(FlexAlign.Center)
        .backgroundColor(`${examinationCategoryTint(this.category)}24`)
        .borderRadius(12)

        Column({ space: 4 }) {
          Text(nonEmptyText(this.report.itemName).length > 0 ? this.report.itemName : '检查报告')
            .fontSize(17)
            .fontWeight(FontWeight.Medium)
            .fontColor('#1C1C1E')
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          if (formatExaminationDateText(this.report).length > 0) {
            Text(formatExaminationDateText(this.report))
              .fontSize(12)
              .fontColor('#8E8E93')
          }
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)

      Column({ space: 8 }) {
        this.InfoRow('报告类型', examinationCategoryTitle(this.category))
        this.InfoRow('亚类', nonEmptyText(this.report.subCategory))
        this.InfoRow('检查日期', ExaminationReportDetailSupport.formatDateField(this.report.performedAt))
        this.InfoRow('报告日期', ExaminationReportDetailSupport.formatDateField(this.report.reportedAt))
        this.InfoRow('机构', nonEmptyText(this.report.organizationName))
        this.InfoRow('科室', nonEmptyText(this.report.departmentName))
        this.InfoRow('医生', nonEmptyText(this.report.doctorName))
      }
      .width('100%')
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#FFFFFF')
    .borderRadius(12)
  }

  @Builder
  private AttachmentsSection() {
    if (this.attachmentNames().length === 0 && !this.fileTransferService) {
      Column() {}
    } else {
      Column({ space: 10 }) {
        Row() {
          Row({ space: 4 }) {
            SymbolGlyph($r('sys.symbol.paperclip'))
              .fontSize(14)
              .fontColor(['#1C1C1E'])
            Text('附件')
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor('#1C1C1E')
          }
          Blank().layoutWeight(1)
          if (this.fileTransferService && this.onAttachmentsUpdated) {
            Text(this.isEditingAttachments ? '完成' : '管理')
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor('#0A84FF')
              .onClick(() => {
                if (this.isEditingAttachments) {
                  this.finishAttachmentEditing();
                } else {
                  this.isEditingAttachments = true;
                }
              })
          } else if (this.attachmentNames().length > 0) {
            Text(`${this.attachmentNames().length}`)
              .fontSize(12)
              .fontColor('#8E8E93')
          }
        }
        .width('100%')

        if (this.attachmentErrorText.length > 0) {
          Text(this.attachmentErrorText)
            .fontSize(12)
            .fontColor('#FF3B30')
            .width('100%')
        }

        if (this.attachmentNames().length === 0 && !this.showsRemoteAttachmentGrid()) {
          Text('暂无附件')
            .fontSize(13)
            .fontColor('#8E8E93')
            .width('100%')
        } else if (this.showsRemoteAttachmentGrid()) {
          MedicalAttachmentGridPreview({
            attachments: this.remoteAttachments,
            fileTransferService: this.fileTransferService,
            isEditing: this.isEditingAttachments,
            onDeleted: (fileID: number) => {
              void this.handleAttachmentDeleted(fileID);
            },
            onFileUploaded: (record: ManagedFileRecord) => {
              void this.handleFileUploaded(record);
            }
          })
        } else {
          Column({ space: 8 }) {
            ForEach(this.attachmentNames(), (name: string) => {
              Row({ space: 8 }) {
                SymbolGlyph($r('sys.symbol.paperclip'))
                  .fontSize(14)
                  .fontColor(['#0A84FF'])
                Text(name)
                  .fontSize(14)
                  .fontColor('#1C1C1E')
                  .layoutWeight(1)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
              }
              .width('100%')
              .padding({ left: 10, right: 10, top: 8, bottom: 8 })
              .backgroundColor('#F8F8FA')
              .borderRadius(8)
            }, (name: string, index: number): string => `exam-attach-${index}-${name}`)
          }
          .width('100%')
        }
      }
      .width('100%')
      .padding(16)
      .backgroundColor('#FFFFFF')
      .borderRadius(12)
    }
  }

  @Builder
  subitemsSection() {
    Column({ space: 12 }) {
      Row() {
        Text('检查明细')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor('#1C1C1E')
          .layoutWeight(1)
        Text(`${this.sortedDetails().length} 项`)
          .fontSize(12)
          .fontColor('#8E8E93')
        if (this.category === 'laboratory') {
          Text('查看完整检验表 ›')
            .fontSize(12)
            .fontColor('#0A84FF')
            .margin({ left: 10 })
            .opacity(this.sortedDetails().length > 0 ? 1 : 0.4)
            .onClick(() => {
              if (this.sortedDetails().length > 0) {
                this.openFullLabTable();
              }
            })
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      if (this.sortedDetails().length === 0) {
        Text('暂无明细数据')
          .fontSize(14)
          .fontColor('#8E8E93')
          .width('100%')
          .padding({ top: 8, bottom: 8 })
      } else {
        Column({ space: 10 }) {
          ForEach(this.sortedDetails(), (item: RemoteMedExamDetail) => {
            ExaminationReportSubitemNavigationLink({
              category: this.category,
              item: item,
              onTap: () => {
                this.openSubitemDetail(item);
              }
            })
          }, (item: RemoteMedExamDetail): string => `subitem-${item.id}`)
        }
        .width('100%')
      }
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#FFFFFF')
    .borderRadius(12)
  }

  build() {
    Scroll() {
      Column({ space: 12 }) {
        this.HeaderCard()

        if (nonEmptyText(this.report.findings).length > 0) {
          Column({ space: 6 }) {
            Text('所见')
              .fontSize(13)
              .fontColor('#0A84FF')
              .width('100%')
            Text(nonEmptyText(this.report.findings))
              .fontSize(14)
              .fontColor('#1C1C1E')
              .width('100%')
          }
          .width('100%')
          .padding(16)
          .backgroundColor('#FFFFFF')
          .borderRadius(12)
        }

        if (nonEmptyText(this.report.impression).length > 0
          && nonEmptyText(this.report.impression) !== nonEmptyText(this.report.findings)) {
          Column({ space: 6 }) {
            Text('印象')
              .fontSize(13)
              .fontColor('#5856D6')
              .width('100%')
            Text(nonEmptyText(this.report.impression))
              .fontSize(14)
              .fontColor('#1C1C1E')
              .width('100%')
          }
          .width('100%')
          .padding(16)
          .backgroundColor('#FFFFFF')
          .borderRadius(12)
        }

        this.AttachmentsSection()
        this.subitemsSection()

        Blank().height(24)
      }
      .width('100%')
      .padding({ left: 16, right: 16, bottom: 16 })
    }
    .layoutWeight(1)
    .width('100%')
    .backgroundColor(Color.Transparent)
  }
}
