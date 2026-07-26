import { MedicalDocumentResultKindResolver } from '../../../Domain/MedicalDocumentResultKindResolver';
import { MedicalDocumentKind } from '../../../Domain/MedicalDocumentKind';
import { MedicalDocumentUploadViewModel } from '../../MedicalDocumentUploadViewModel';
import { MedicalDocumentTypedResultScaffoldView } from '../MedicalDocumentTypedResultScaffoldView';
import { MedicalDocumentResultSectionCard, MedicalDocumentResultInfoLine } from '../MedicalDocumentResultSupport';
import { MedicalDocumentAttachmentAssociationSheet } from '../MedicalDocumentAttachmentAssociationSheet';
import { MedicalReportResultSupport } from './MedicalReportResultSupport';
import { MedicalReportCardsSectionView } from './MedicalReportResultSections';
import { MedicalReportMemberConfirmSectionView } from './MedicalReportMemberConfirmSectionView';
import { MedicalDocumentUnlinkedAttachmentsSectionView } from './MedicalDocumentUnlinkedAttachmentsSectionView';
import { ExaminationReportCategory } from
  '../../../../Home/Presentation/MedicalLists/ExaminationReports/ExaminationReportCategory';

/**
 * 检查报告识别结果页正文。对齐 iOS `MedicalReportRecognitionResultContentView`：
 * 成员确认+统计 → 分类分组报告卡片（可跳详情）→ 未关联附件 → 保存回执。
 */
@Component
export struct MedicalReportRecognitionResultContentView {
  @ObjectLink viewModel: MedicalDocumentUploadViewModel;
  onOpenCardDetail: (index: number, category: ExaminationReportCategory) => void = () => {};
  /** 结果页内保存归属成员。对齐 iOS `@State private var selectedMemberID`。 */
  @State private selectedMemberID: number = 0;
  @State private showAssociationSheet: boolean = false;
  @State private associationTargetIndex: number = -1;

  aboutToAppear(): void {
    this.syncSelectedMemberFromOutput();
  }

  private syncSelectedMemberFromOutput(): void {
    const envelopeMemberID = this.viewModel.typedOutput?.envelope.memberID ?? 0;
    if (envelopeMemberID > 0) {
      this.selectedMemberID = envelopeMemberID;
      return;
    }
    if (this.viewModel.selectedMemberID > 0) {
      this.selectedMemberID = this.viewModel.selectedMemberID;
    }
  }

  private onSelectMember(memberID: number): void {
    this.selectedMemberID = memberID;
    this.viewModel.updateResultMemberID(memberID);
  }

  private associationTitle(): string {
    const reports = MedicalReportResultSupport.reports(this.viewModel);
    if (this.associationTargetIndex < 0 || this.associationTargetIndex >= reports.length) {
      return '管理附件';
    }
    const title = reports[this.associationTargetIndex].title;
    return title.length > 0 ? `管理「${title}」附件` : '管理附件';
  }

  private associationSelectedIDs(): string[] {
    const reports = MedicalReportResultSupport.reports(this.viewModel);
    if (this.associationTargetIndex < 0 || this.associationTargetIndex >= reports.length) {
      return [];
    }
    return reports[this.associationTargetIndex].attachmentFileIds.slice();
  }

  private openAssociation(index: number): void {
    this.associationTargetIndex = index;
    this.showAssociationSheet = true;
  }

  @Builder
  private associationSheet() {
    MedicalDocumentAttachmentAssociationSheet({
      title: this.associationTitle(),
      localAttachments: MedicalReportResultSupport.allLocalAttachments(this.viewModel),
      selectedIDs: this.associationSelectedIDs(),
      onSubmit: (ids: string[]) => {
        if (this.associationTargetIndex >= 0) {
          MedicalReportResultSupport.setReportAttachmentIDs(this.viewModel, this.associationTargetIndex, ids);
        }
        this.showAssociationSheet = false;
        this.associationTargetIndex = -1;
      },
      onCancel: () => {
        this.showAssociationSheet = false;
        this.associationTargetIndex = -1;
      }
    })
  }

  @Builder
  private SaveReceiptContent() {
    MedicalDocumentResultInfoLine({
      label: '记录 ID',
      value: `${this.viewModel.saveReceipt?.recordID ?? ''}`
    })
  }

  @Builder
  private SaveReceiptSection() {
    if (this.viewModel.saveReceipt) {
      MedicalDocumentResultSectionCard({
        title: '保存状态',
        subtitle: '已成功保存',
        badgeText: '已保存',
        content: () => {
          this.SaveReceiptContent()
        }
      })
    }
  }

  @Builder
  private BodySections() {
    Column({ space: 14 }) {
      MedicalReportMemberConfirmSectionView({
        viewModel: this.viewModel,
        selectedMemberID: this.selectedMemberID,
        onSelectMember: (memberID: number) => {
          this.onSelectMember(memberID);
        }
      })
      MedicalReportCardsSectionView({
        viewModel: this.viewModel,
        onOpenCardDetail: (index: number, category: ExaminationReportCategory) => {
          this.onOpenCardDetail(index, category);
        },
        onManageAttachments: (index: number) => {
          this.openAssociation(index);
        }
      })
      MedicalDocumentUnlinkedAttachmentsSectionView({
        attachments: MedicalReportResultSupport.unlinkedAttachments(
          this.viewModel,
          MedicalReportResultSupport.reports(this.viewModel)
        )
      })
      this.SaveReceiptSection()
    }
    .width('100%')
    .bindSheet(this.showAssociationSheet, this.associationSheet, {
      height: SheetSize.LARGE,
      dragBar: true,
      showClose: true,
      onDisappear: () => {
        this.showAssociationSheet = false;
        this.associationTargetIndex = -1;
      }
    })
  }

  build() {
    MedicalDocumentTypedResultScaffoldView({
      viewModel: this.viewModel,
      pageTitle: '',
      pageSubtitle: MedicalReportResultSupport.categoryStats(
        MedicalReportResultSupport.reports(this.viewModel)),
      kindLabel: MedicalDocumentResultKindResolver.kindLabel(MedicalDocumentKind.MEDICAL_REPORT),
      showMemberBar: false,
      showSourceAttachmentsSection: false,
      body: () => {
        this.BodySections()
      }
    })
  }
}
