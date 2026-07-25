import { MedicalDocumentUploadViewModel } from '../MedicalDocumentUploadViewModel';
import { PrescriptionRecognitionResultContentView } from './PrescriptionRecognitionResult/PrescriptionRecognitionResultContentView';

@Component
export struct PrescriptionRecognitionResultView {
  @ObjectLink viewModel: MedicalDocumentUploadViewModel;

  build() {
    PrescriptionRecognitionResultContentView({ viewModel: this.viewModel })
  }
}
