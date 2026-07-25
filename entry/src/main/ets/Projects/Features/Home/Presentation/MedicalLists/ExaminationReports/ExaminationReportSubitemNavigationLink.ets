import { RemoteMedExamDetail } from '../../../../../Core/Networking/API/Medical/MedicalSyncAPI';
import { ExaminationReportCategory } from './ExaminationReportCategory';
import { ExaminationReportSubitemSummaryRow } from './ExaminationReportSubitemSummaryRow';

/**
 * 可点击的明细摘要行。对齐 iOS MainNavigationLink + ExaminationReportSubitemSummaryRow。
 */
@Component
export struct ExaminationReportSubitemNavigationLink {
  @Prop category: ExaminationReportCategory = 'laboratory';
  @Prop item: RemoteMedExamDetail = new RemoteMedExamDetail();
  onTap: () => void = () => {};

  build() {
    ExaminationReportSubitemSummaryRow({
      category: this.category,
      item: this.item
    })
      .onClick(() => {
        this.onTap();
      })
  }
}
