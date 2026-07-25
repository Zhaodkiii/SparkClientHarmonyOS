import { MedicalDocumentUploadViewModel } from '../../MedicalDocumentUploadViewModel';
import { MedicalDocumentResultSectionCard } from '../MedicalDocumentResultSupport';
import { MedicalUploadL10n } from '../../../Domain/SupportingModels';
import { CategoryCount, MedicalReportResultSupport } from './MedicalReportResultSupport';
import { MedicalReportMemberBindingMenu } from './MedicalReportMemberBindingMenu';
import { examinationCategoryIcon } from
  '../../../../Home/Presentation/MedicalLists/ExaminationReports/ExaminationReportCategory';

/**
 * 成员确认 + 统计概览组合区块。对齐 iOS `MedicalReportMemberConfirmSectionView`。
 */
@Component
export struct MedicalReportMemberConfirmSectionView {
  @ObjectLink viewModel: MedicalDocumentUploadViewModel;
  @Prop selectedMemberID: number = 0;
  onSelectMember?: (memberID: number) => void;

  private counts(): CategoryCount[] {
    return MedicalReportResultSupport.categoryCounts(MedicalReportResultSupport.reports(this.viewModel));
  }

  @Builder
  private StatChip(item: CategoryCount) {
    Column({ space: 6 }) {
      Row({ space: 6 }) {
        SymbolGlyph(examinationCategoryIcon(item.category))
          .fontSize(12)
          .fontColor([MedicalReportResultSupport.categoryTint(item.category)])
        Text(MedicalReportResultSupport.categoryTitle(item.category))
          .fontSize(12)
          .fontColor('#8E8E93')
      }
      .width('100%')
      Text(`${item.count}`)
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .fontColor(MedicalReportResultSupport.categoryTint(item.category))
    }
    .alignItems(HorizontalAlign.Start)
    .layoutWeight(1)
    .padding(10)
    .backgroundColor('#F2F2F7')
    .borderRadius(12)
  }

  @Builder
  private OverviewContent() {
    Column({ space: 18 }) {
      MedicalReportMemberBindingMenu({
        viewModel: this.viewModel,
        selectedMemberID: this.selectedMemberID,
        onSelectMember: (memberID: number) => {
          if (this.onSelectMember) {
            this.onSelectMember(memberID);
          }
        }
      })

      Column({ space: 12 }) {
        Row({ space: 8 }) {
          SymbolGlyph($r('sys.symbol.doc_text'))
            .fontSize(18)
            .fontColor(['#0A84FF'])
          Text(MedicalUploadL10n.text('medical.upload.result.medical_report.stats.title'))
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor('#1C1C1E')
        }
        .width('100%')
        Row({ space: 10 }) {
          ForEach(this.counts(), (item: CategoryCount) => {
            this.StatChip(item)
          }, (item: CategoryCount): string => `mr-member-stat-${item.category}`)
        }
        .width('100%')
      }
      .width('100%')
    }
    .width('100%')
  }

  build() {
    MedicalDocumentResultSectionCard({
      title: MedicalUploadL10n.text('medical.upload.result.member.title'),
      subtitle: MedicalUploadL10n.text('medical.upload.result.medical_report.member.subtitle'),
      content: () => {
        this.OverviewContent()
      }
    })
  }
}
