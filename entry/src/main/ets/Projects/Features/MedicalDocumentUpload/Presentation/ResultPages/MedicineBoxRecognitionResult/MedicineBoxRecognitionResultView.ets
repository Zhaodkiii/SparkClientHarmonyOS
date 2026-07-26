import { MedicalDocumentUploadViewModel } from '../../MedicalDocumentUploadViewModel';
import { MedicineBoxRecognitionResultContentView } from './MedicineBoxRecognitionResultContentView';
import { MedicineBoxRecognitionResultRoutes } from './MedicineBoxRecognitionResultRoutes';

/**
 * 药箱识别结果页。对齐 iOS `MedicineBoxRecognitionResultView`：
 * 结果列表 + Navigation 推入本地草稿详情。
 */
@Component
export struct MedicineBoxRecognitionResultView {
  @ObjectLink viewModel: MedicalDocumentUploadViewModel;

  build() {
    MedicineBoxRecognitionResultContentView({
      viewModel: this.viewModel,
      onOpenCardDetail: (index: number) => {
        this.viewModel.openMedicineBoxCardDetail(index);
        this.viewModel.medicalUploadNavStack?.pushPath({
          name: MedicineBoxRecognitionResultRoutes.LOCAL_DRAFT_DETAIL
        });
      }
    })
  }
}
