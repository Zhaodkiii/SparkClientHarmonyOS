import { MedicalDocumentUploadViewModel } from '../MedicalDocumentUploadViewModel';
import { CaseRecognitionResultContentView } from './CaseRecognitionResult/CaseRecognitionResultContentView';

/** 病例识别结果页。对齐 iOS CaseRecognitionResultView。 */
@Component
export struct CaseRecognitionResultView {
  @ObjectLink viewModel: MedicalDocumentUploadViewModel;

  build() {
    CaseRecognitionResultContentView({ viewModel: this.viewModel })
  }
}
