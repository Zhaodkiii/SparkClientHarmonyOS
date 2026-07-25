import { MedicalDocumentUploadViewModel } from '../MedicalDocumentUploadViewModel';
import { MedicationRecognitionResultContentView } from './MedicationRecognitionResult/MedicationRecognitionResultContentView';

@Component
export struct MedicationRecognitionResultView {
  @ObjectLink viewModel: MedicalDocumentUploadViewModel;

  build() {
    MedicationRecognitionResultContentView({ viewModel: this.viewModel })
  }
}
