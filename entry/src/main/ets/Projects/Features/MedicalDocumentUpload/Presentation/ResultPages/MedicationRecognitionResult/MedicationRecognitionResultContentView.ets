import { MedicalDocumentResultKindResolver } from '../../../Domain/MedicalDocumentResultKindResolver';
import { MedicalDocumentKind } from '../../../Domain/MedicalDocumentKind';
import { MedicalDocumentUploadViewModel } from '../../MedicalDocumentUploadViewModel';
import { MedicalDocumentTypedResultScaffoldView } from '../MedicalDocumentTypedResultScaffoldView';
import { MedicationRecognitionResultSupport } from './MedicationRecognitionResultSupport';
import { MedicationPlansSectionView } from './MedicationResultSections';

@Component
export struct MedicationRecognitionResultContentView {
  @ObjectLink viewModel: MedicalDocumentUploadViewModel;

  @Builder
  private BodySections() {
    MedicationPlansSectionView({ viewModel: this.viewModel })
  }

  build() {
    MedicalDocumentTypedResultScaffoldView({
      viewModel: this.viewModel,
      pageTitle: '',
      pageSubtitle: `共 ${MedicationRecognitionResultSupport.plans(this.viewModel).length} 条计划`,
      kindLabel: MedicalDocumentResultKindResolver.kindLabel(MedicalDocumentKind.MEDICATION_PLAN),
      body: () => {
        this.BodySections()
      }
    })
  }
}
