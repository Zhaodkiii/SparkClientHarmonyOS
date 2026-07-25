import { MedicalDocumentResultKindResolver } from '../../../Domain/MedicalDocumentResultKindResolver';
import { MedicalDocumentKind } from '../../../Domain/MedicalDocumentKind';
import { MedicalDocumentUploadViewModel } from '../../MedicalDocumentUploadViewModel';
import { MedicalDocumentTypedResultScaffoldView } from '../MedicalDocumentTypedResultScaffoldView';
import { MedicineBoxRecognitionResultSupport } from './MedicineBoxRecognitionResultSupport';
import { MedicineBoxItemsSectionView } from './MedicineBoxResultSections';

@Component
export struct MedicineBoxRecognitionResultContentView {
  @ObjectLink viewModel: MedicalDocumentUploadViewModel;

  @Builder
  private BodySections() {
    MedicineBoxItemsSectionView({ viewModel: this.viewModel })
  }

  build() {
    MedicalDocumentTypedResultScaffoldView({
      viewModel: this.viewModel,
      pageTitle: '',
      pageSubtitle: `共 ${MedicineBoxRecognitionResultSupport.boxes(this.viewModel).length} 个药品条目`,
      kindLabel: MedicalDocumentResultKindResolver.kindLabel(MedicalDocumentKind.MEDICINE_BOX),
      body: () => {
        this.BodySections()
      }
    })
  }
}
