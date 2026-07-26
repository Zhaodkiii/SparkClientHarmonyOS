import { MedicalDocumentResultKindResolver } from '../../../Domain/MedicalDocumentResultKindResolver';
import { MedicalDocumentKind } from '../../../Domain/MedicalDocumentKind';
import { MedicalDocumentUploadViewModel } from '../../MedicalDocumentUploadViewModel';
import { MedicalDocumentAttachmentAssociationSheet } from '../MedicalDocumentAttachmentAssociationSheet';
import { MedicalDocumentResultInfoLine, MedicalDocumentResultSectionCard } from '../MedicalDocumentResultSupport';
import { MedicalDocumentTypedResultScaffoldView } from '../MedicalDocumentTypedResultScaffoldView';
import { MedicalDocumentUnlinkedAttachmentsSectionView } from '../MedicalReportRecognitionResult/MedicalDocumentUnlinkedAttachmentsSectionView';
import { MedicineBoxMemberConfirmSectionView } from './MedicineBoxMemberConfirmSectionView';
import { MedicineBoxListSectionView } from './MedicineBoxResultSections';
import { MedicineBoxRecognitionResultSupport } from './MedicineBoxRecognitionResultSupport';

/**
 * 药箱识别结果页正文。对齐 iOS `MedicineBoxRecognitionResultContentView`：
 * 成员确认 → 药品条目卡片 → 未关联附件 → 保存回执。
 */
@Component
export struct MedicineBoxRecognitionResultContentView {
  @ObjectLink viewModel: MedicalDocumentUploadViewModel;
  onOpenCardDetail: (index: number) => void = () => {};
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
    const boxes = MedicineBoxRecognitionResultSupport.boxes(this.viewModel);
    if (this.associationTargetIndex < 0 || this.associationTargetIndex >= boxes.length) {
      return '管理附件';
    }
    const name = boxes[this.associationTargetIndex].medicineName ?? '';
    return name.length > 0 ? `管理「${name}」附件` : '管理附件';
  }

  private associationSelectedIDs(): string[] {
    const boxes = MedicineBoxRecognitionResultSupport.boxes(this.viewModel);
    if (this.associationTargetIndex < 0 || this.associationTargetIndex >= boxes.length) {
      return [];
    }
    return boxes[this.associationTargetIndex].attachmentFileIds.slice();
  }

  private openAssociation(index: number): void {
    this.associationTargetIndex = index;
    this.showAssociationSheet = true;
  }

  @Builder
  private associationSheet() {
    MedicalDocumentAttachmentAssociationSheet({
      title: this.associationTitle(),
      localAttachments: MedicineBoxRecognitionResultSupport.allLocalAttachments(this.viewModel),
      selectedIDs: this.associationSelectedIDs(),
      onSubmit: (ids: string[]) => {
        if (this.associationTargetIndex >= 0) {
          MedicineBoxRecognitionResultSupport.setBoxAttachmentIDs(
            this.viewModel,
            this.associationTargetIndex,
            ids
          );
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
      MedicineBoxMemberConfirmSectionView({
        viewModel: this.viewModel,
        selectedMemberID: this.selectedMemberID,
        onSelectMember: (memberID: number) => {
          this.onSelectMember(memberID);
        }
      })
      MedicineBoxListSectionView({
        viewModel: this.viewModel,
        selectedMemberID: this.selectedMemberID,
        onOpenCardDetail: (index: number) => {
          this.onOpenCardDetail(index);
        },
        onManageAttachments: (index: number) => {
          this.openAssociation(index);
        }
      })
      MedicalDocumentUnlinkedAttachmentsSectionView({
        attachments: MedicineBoxRecognitionResultSupport.unlinkedAttachments(
          this.viewModel,
          MedicineBoxRecognitionResultSupport.boxes(this.viewModel)
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
      pageSubtitle: MedicineBoxRecognitionResultSupport.pageSubtitle(this.viewModel),
      kindLabel: MedicalDocumentResultKindResolver.kindLabel(MedicalDocumentKind.MEDICINE_BOX),
      showMemberBar: false,
      showSourceAttachmentsSection: false,
      body: () => {
        this.BodySections()
      }
    })
  }
}
