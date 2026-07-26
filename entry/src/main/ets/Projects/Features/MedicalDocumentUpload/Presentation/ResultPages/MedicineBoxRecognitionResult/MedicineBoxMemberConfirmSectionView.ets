import { MedicalDocumentUploadViewModel } from '../../MedicalDocumentUploadViewModel';
import { MedicalDocumentResultInfoLine, MedicalDocumentResultSectionCard } from '../MedicalDocumentResultSupport';
import { MedicalUploadL10n } from '../../../Domain/SupportingModels';
import { MedicalReportMemberBindingMenu } from '../MedicalReportRecognitionResult/MedicalReportMemberBindingMenu';
import { MedicineBoxRecognitionResultSupport } from './MedicineBoxRecognitionResultSupport';

/**
 * 药箱成员确认 + 药品数量概览。对齐 iOS `MedicineBoxMemberConfirmSectionView`。
 */
@Component
export struct MedicineBoxMemberConfirmSectionView {
  @ObjectLink viewModel: MedicalDocumentUploadViewModel;
  @Prop selectedMemberID: number = 0;
  onSelectMember?: (memberID: number) => void;

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
      MedicalDocumentResultInfoLine({
        label: MedicalUploadL10n.text('medical.upload.result.medicine_box.total_count'),
        value: `${MedicineBoxRecognitionResultSupport.boxes(this.viewModel).length}`
      })
    }
    .width('100%')
  }

  build() {
    MedicalDocumentResultSectionCard({
      title: MedicalUploadL10n.text('medical.upload.result.medicine_box.member.title'),
      subtitle: MedicalUploadL10n.text('medical.upload.result.medicine_box.member.subtitle'),
      content: () => {
        this.OverviewContent()
      }
    })
  }
}
