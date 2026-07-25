import { MedicalDocumentUploadViewModel } from '../../MedicalDocumentUploadViewModel';
import { MedicineBoxRecognitionResultContentView } from './MedicineBoxRecognitionResultContentView';

/** 药箱识别结果页。对齐 iOS MedicineBoxRecognitionResultView（View 置于子目录）。 */
@Component
export struct MedicineBoxRecognitionResultView {
  @ObjectLink viewModel: MedicalDocumentUploadViewModel;

  build() {
    MedicineBoxRecognitionResultContentView({ viewModel: this.viewModel })
  }
}
