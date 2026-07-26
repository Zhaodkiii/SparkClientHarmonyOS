import { MedicineBoxRecognitionDraft } from '../../../Domain/MedicalDocumentRecognitionDrafts';
import { MedicalUploadL10n } from '../../../Domain/SupportingModels';
import { MedicalDocumentUploadViewModel } from '../../MedicalDocumentUploadViewModel';
import { CaseMatchedAttachmentsGridView } from '../CaseMatchedAttachmentsGridView';
import { MedicalDocumentResultDetailNavigationSupport } from '../MedicalDocumentResultDetailNavigationSupport';
import { MedicalValidationIssueInlineView } from '../PreSubmitValidation/MedicalValidationIssueInlineView';
import {
  medicineBoxStockText,
  medicineStrengthDetailValue,
  medicineTypeText
} from '../../../../Home/Presentation/MedicalLists/MedicineBox/MedicineBoxDisplaySupport';
import { MedicineBoxDraftMapping } from '../../../../Home/Presentation/MedicalLists/MedicineBox/MedicineBoxDraftMapping';
import { MedicineBoxRecognitionResultSupport } from './MedicineBoxRecognitionResultSupport';

/**
 * 药箱药品列表区块。对齐 iOS `MedicineBoxListSectionView`：
 * 区块头部 + 逐条卡片预览，可跳转本地草稿详情，支持附件网格与校验提示。
 */
@Component
export struct MedicineBoxListSectionView {
  @ObjectLink viewModel: MedicalDocumentUploadViewModel;
  @Prop selectedMemberID: number = 0;
  onOpenCardDetail: (index: number) => void = () => {};
  onManageAttachments: (index: number) => void = () => {};

  private boxes(): MedicineBoxRecognitionDraft[] {
    return MedicineBoxRecognitionResultSupport.boxes(this.viewModel);
  }

  private canOpenDetail(): boolean {
    return MedicalDocumentResultDetailNavigationSupport.makeContext(
      this.selectedMemberID,
      this.viewModel
    ) !== undefined;
  }

  private hasCardIssues(index: number): boolean {
    return MedicineBoxRecognitionResultSupport.cardIssues(this.viewModel, index).length > 0;
  }

  private openDetail(index: number): void {
    if (!this.canOpenDetail()) {
      return;
    }
    this.onOpenCardDetail(index);
  }

  private stockText(box: MedicineBoxRecognitionDraft, index: number): string {
    const raw = (box.totalQuantity ?? '').trim();
    if (raw.length > 0) {
      return raw;
    }
    return medicineBoxStockText(
      MedicineBoxDraftMapping.remoteMedicineBoxFromDraft(
        box,
        this.selectedMemberID,
        MedicineBoxRecognitionResultSupport.temporaryMedicineBoxID(index)
      )
    );
  }

  @Builder
  private SectionHeader() {
    Row({ space: 10 }) {
      SymbolGlyph($r('sys.symbol.square_stack_3d'))
        .fontSize(20)
        .fontColor(['#0A84FF'])
      Column({ space: 2 }) {
        Text(MedicalUploadL10n.text('medical.upload.result.medicine_box.section.title'))
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor('#1C1C1E')
          .width('100%')
        Text(MedicalUploadL10n.text('medical.upload.result.medicine_box.section.subtitle'))
          .fontSize(13)
          .fontColor('#8E8E93')
          .width('100%')
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      Text(`${this.boxes().length}`)
        .fontSize(12)
        .fontWeight(FontWeight.Medium)
        .fontColor('#8E8E93')
        .padding({ left: 8, right: 8, top: 4, bottom: 4 })
        .backgroundColor('#F2F2F7')
        .borderRadius(8)
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
  }

  @Builder
  private InfoLine(title: string, value: string) {
    if (value.length > 0) {
      Row({ space: 8 }) {
        Text(title)
          .fontSize(12)
          .fontColor('#8E8E93')
          .width(56)
        Text(value)
          .fontSize(12)
          .fontColor('#1C1C1E')
          .layoutWeight(1)
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)
    }
  }

  @Builder
  private ItemCard(box: MedicineBoxRecognitionDraft, index: number) {
    Column({ space: 10 }) {
      Row({ space: 10 }) {
        SymbolGlyph($r('sys.symbol.heart_fill'))
          .fontSize(14)
          .fontColor(['#5856D6'])
          .margin({ top: 2 })
        Column({ space: 6 }) {
          if (this.boxes().length > 1) {
            Text(`${index + 1} / ${this.boxes().length}`)
              .fontSize(12)
              .fontWeight(FontWeight.Medium)
              .fontColor('#8E8E93')
              .width('100%')
          }
          Text((box.medicineName ?? '').length > 0 ?
            (box.medicineName ?? '') :
            MedicalUploadL10n.text('medical.upload.presubmit.value.not_filled'))
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.hasCardIssues(index) ? '#C93400' : '#1C1C1E')
            .width('100%')
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          this.InfoLine('药品类型', medicineTypeText(box.medicineType))
          this.InfoLine('品牌', box.brandName ?? '')
          this.InfoLine('剂型', box.dosageForm ?? '')
          this.InfoLine('规格', medicineStrengthDetailValue(box.strength ?? ''))
          this.InfoLine('总数量', this.stockText(box, index))
          this.InfoLine('有效期', box.expireDate ?? '')
          this.InfoLine('备注', box.notes ?? '')
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        if (this.canOpenDetail()) {
          Text('›')
            .fontSize(18)
            .fontColor('#C7C7CC')
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)

      ForEach(MedicineBoxRecognitionResultSupport.issueSummaryLines(this.viewModel, index),
        (line: string) => {
          MedicalValidationIssueInlineView({ message: line })
        }, (line: string, issueIndex: number): string => `mb-issue-${index}-${issueIndex}`)

      if (box.attachmentFileIds.length > 0) {
        CaseMatchedAttachmentsGridView({
          title: '药品附件',
          attachments: MedicineBoxRecognitionResultSupport.matchedAttachments(
            this.viewModel, box.attachmentFileIds),
          onManage: () => {
            this.onManageAttachments(index);
          }
        })
      }
    }
    .width('100%')
    .padding(12)
    .backgroundColor('#F2F2F7')
    .borderRadius(12)
    .border({
      width: this.hasCardIssues(index) ? 1 : 0,
      color: '#C93400'
    })
    .id(`preSubmitValidation.card.medicineBox.${index}`)
    .onClick(() => {
      this.openDetail(index);
    })
  }

  @Builder
  private EmptyHint() {
    Text(MedicalUploadL10n.text('medical.upload.result.medicine_box.empty'))
      .fontSize(15)
      .fontColor('#8E8E93')
      .width('100%')
      .padding(12)
      .backgroundColor('#F2F2F7')
      .borderRadius(12)
  }

  build() {
    Column({ space: 12 }) {
      this.SectionHeader()
      if (this.boxes().length === 0) {
        this.EmptyHint()
      } else {
        ForEach(this.boxes(), (box: MedicineBoxRecognitionDraft, index: number) => {
          this.ItemCard(box, index)
        }, (box: MedicineBoxRecognitionDraft, index: number): string =>
          `mb-card-${index}-${box.medicineName ?? ''}-${box.expireDate ?? ''}`)
      }
    }
    .width('100%')
    .id('preSubmitValidation.section.medicineBoxList')
  }
}
