import { MedicalDocumentUploadViewModel } from '../MedicalDocumentUploadViewModel';
import { HealthExamRecognitionResultContentView } from './HealthExamRecognitionResult/HealthExamRecognitionResultContentView';

@Component
export struct HealthExamRecognitionResultView {
  @ObjectLink viewModel: MedicalDocumentUploadViewModel;

  build() {
    HealthExamRecognitionResultContentView({ viewModel: this.viewModel })
  }
}
