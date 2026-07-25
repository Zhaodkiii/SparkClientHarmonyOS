import { MedicalDocumentResultKindResolver } from '../../../Domain/MedicalDocumentResultKindResolver';
import { MedicalDocumentKind } from '../../../Domain/MedicalDocumentKind';
import { MedicalDocumentUploadViewModel } from '../../MedicalDocumentUploadViewModel';
import { MedicalDocumentTypedResultScaffoldView } from '../MedicalDocumentTypedResultScaffoldView';
import { PrescriptionRecognitionResultSupport } from './PrescriptionRecognitionResultSupport';
import {
  PrescriptionBatchesSectionView,
  PrescriptionCandidateSectionView
} from './PrescriptionResultSections';

@Component
export struct PrescriptionRecognitionResultContentView {
  @ObjectLink viewModel: MedicalDocumentUploadViewModel;

  @Builder
  private BodySections() {
    Column({ space: 14 }) {
      PrescriptionCandidateSectionView()
      PrescriptionBatchesSectionView({ viewModel: this.viewModel })
    }
    .width('100%')
  }

  build() {
    MedicalDocumentTypedResultScaffoldView({
      viewModel: this.viewModel,
      pageTitle: '',
      pageSubtitle: `共 ${PrescriptionRecognitionResultSupport.batches(this.viewModel).length} 张处方`,
      kindLabel: MedicalDocumentResultKindResolver.kindLabel(MedicalDocumentKind.PRESCRIPTION),
      body: () => {
        this.BodySections()
      }
    })
  }
}
