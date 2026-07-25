import { MedicalDocumentResultKindResolver } from '../../../Domain/MedicalDocumentResultKindResolver';
import { MedicalDocumentKind } from '../../../Domain/MedicalDocumentKind';
import { MedicalDocumentUploadViewModel } from '../../MedicalDocumentUploadViewModel';
import {
  MedicalDocumentResultSectionCard,
  MedicalValidatedEditableField
} from '../MedicalDocumentResultSupport';
import { MedicalDocumentTypedResultScaffoldView } from '../MedicalDocumentTypedResultScaffoldView';
import { CaseRecognitionDraft } from '../../../Domain/MedicalDocumentRecognitionDrafts';
import { CaseRecognitionResultSupport } from './CaseRecognitionResultSupport';
import {
  CaseHistoryDiagnosisSectionView,
  CaseMemberInfoSectionView
} from './CaseRecognitionResultSections';

@Component
export struct CaseRecognitionResultContentView {
  @ObjectLink viewModel: MedicalDocumentUploadViewModel;

  private draft(): CaseRecognitionDraft {
    return CaseRecognitionResultSupport.ensureDraft(this.viewModel);
  }

  build() {
    MedicalDocumentTypedResultScaffoldView({
      viewModel: this.viewModel,
      pageTitle: '',
      pageSubtitle: '请确认关键字段后保存',
      kindLabel: MedicalDocumentResultKindResolver.kindLabel(MedicalDocumentKind.CASE_DOCUMENT),
      body: () => {
        this.BodySections()
      }
    })
  }

  @Builder
  private BodySections() {
    Column({ space: 14 }) {
      CaseMemberInfoSectionView({ viewModel: this.viewModel })

      MedicalDocumentResultSectionCard({
        title: '基本信息',
        subtitle: '标题、医院、日期',
        content: () => {
          this.BasicFields()
        }
      })

      CaseHistoryDiagnosisSectionView({ viewModel: this.viewModel })
    }
    .width('100%')
  }

  @Builder
  private BasicFields() {
    Column({ space: 10 }) {
      MedicalValidatedEditableField({
        label: '标题',
        value: this.draft().title,
        fieldKey: 'medical_case.title',
        scrollTargetID: CaseRecognitionResultSupport.fieldScroll('medical_case.title'),
        errorMessage: CaseRecognitionResultSupport.err(this.viewModel, 'medical_case.title'),
        onValueChange: (v: string) => {
          this.draft().title = v;
          this.viewModel.notifyTypedDraftChanged(['medical_case.title']);
        }
      })
      MedicalValidatedEditableField({
        label: '医院',
        value: this.draft().hospitalName ?? '',
        onValueChange: (v: string) => {
          this.draft().hospitalName = v;
          this.viewModel.notifyTypedDraftChanged();
        }
      })
      MedicalValidatedEditableField({
        label: '就诊日期',
        value: this.draft().occurredAt ?? '',
        placeholder: 'yyyy-MM-dd',
        fieldKey: 'medical_case.occurred_at',
        scrollTargetID: CaseRecognitionResultSupport.fieldScroll('medical_case.occurred_at'),
        errorMessage: CaseRecognitionResultSupport.err(this.viewModel, 'medical_case.occurred_at'),
        onValueChange: (v: string) => {
          this.draft().occurredAt = v;
          this.viewModel.notifyTypedDraftChanged(['medical_case.occurred_at']);
        }
      })
      MedicalValidatedEditableField({
        label: '就诊年龄',
        value: this.draft().ageAtVisit ?? '',
        fieldKey: 'medical_case.age_at_visit',
        scrollTargetID: CaseRecognitionResultSupport.fieldScroll('medical_case.age_at_visit'),
        errorMessage: CaseRecognitionResultSupport.err(this.viewModel, 'medical_case.age_at_visit'),
        onValueChange: (v: string) => {
          this.draft().ageAtVisit = v;
          this.viewModel.notifyTypedDraftChanged(['medical_case.age_at_visit']);
        }
      })
      MedicalValidatedEditableField({
        label: '摘要',
        value: this.draft().summary ?? '',
        onValueChange: (v: string) => {
          this.draft().summary = v;
          this.viewModel.notifyTypedDraftChanged();
        }
      })
    }
    .width('100%')
  }
}
