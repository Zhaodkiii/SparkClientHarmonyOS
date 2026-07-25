import { MedicalDocumentResultKindResolver } from '../../../Domain/MedicalDocumentResultKindResolver';
import { MedicalDocumentKind } from '../../../Domain/MedicalDocumentKind';
import { MedicalDocumentUploadViewModel } from '../../MedicalDocumentUploadViewModel';
import { MedicalDocumentTypedResultScaffoldView } from '../MedicalDocumentTypedResultScaffoldView';
import {
  HealthExamBasicInfoEditorView,
  HealthExamItemsSectionView,
  HealthExamRiskOverviewSectionView
} from './HealthExamResultSections';

@Component
export struct HealthExamRecognitionResultContentView {
  @ObjectLink viewModel: MedicalDocumentUploadViewModel;
  @State private filterMode: string = 'all';

  build() {
    MedicalDocumentTypedResultScaffoldView({
      viewModel: this.viewModel,
      pageTitle: '',
      pageSubtitle: '',
      kindLabel: MedicalDocumentResultKindResolver.kindLabel(MedicalDocumentKind.HEALTH_EXAM_REPORT),
      body: () => {
        this.BodySections()
      }
    })
  }

  @Builder
  private BodySections() {
    Column({ space: 14 }) {
      HealthExamBasicInfoEditorView({ viewModel: this.viewModel })
      HealthExamRiskOverviewSectionView({ viewModel: this.viewModel })
      HealthExamItemsSectionView({
        viewModel: this.viewModel,
        filterMode: this.filterMode,
        onFilterChange: (mode: string) => {
          this.filterMode = mode;
        }
      })
    }
    .width('100%')
  }
}
