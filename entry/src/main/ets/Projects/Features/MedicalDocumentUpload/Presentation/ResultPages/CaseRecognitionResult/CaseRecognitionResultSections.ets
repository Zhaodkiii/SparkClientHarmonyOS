import {
  CaseRecognitionDraft,
  SymptomRecognitionDraft
} from '../../../Domain/MedicalDocumentRecognitionDrafts';
import { MedicalDocumentUploadViewModel } from '../../MedicalDocumentUploadViewModel';
import {
  MedicalDocumentResultSectionCard,
  MedicalValidatedEditableField
} from '../MedicalDocumentResultSupport';
import { CaseRecognitionResultSupport } from './CaseRecognitionResultSupport';

@Component
export struct CaseMemberInfoSectionView {
  @ObjectLink viewModel: MedicalDocumentUploadViewModel;

  private draft(): CaseRecognitionDraft {
    return CaseRecognitionResultSupport.ensureDraft(this.viewModel);
  }

  @Builder
  private MemberContent() {
    Column({ space: 6 }) {
      Text(this.viewModel.selectedMemberName.length > 0 ?
        this.viewModel.selectedMemberName : '未选择成员')
        .fontSize(15)
        .fontColor('#1C1C1E')
        .width('100%')
      if (this.draft().title.length > 0) {
        Text(this.draft().title)
          .fontSize(13)
          .fontColor('#8E8E93')
          .width('100%')
      }
    }
    .width('100%')
  }

  build() {
    MedicalDocumentResultSectionCard({
      title: '病例归属',
      subtitle: '成员与病例标题摘要',
      content: () => {
        this.MemberContent()
      }
    })
  }
}

@Component
export struct CaseHistoryDiagnosisSectionView {
  @ObjectLink viewModel: MedicalDocumentUploadViewModel;

  private draft(): CaseRecognitionDraft {
    return CaseRecognitionResultSupport.ensureDraft(this.viewModel);
  }

  @Builder
  private HistoryContent() {
    Column({ space: 10 }) {
      MedicalValidatedEditableField({
        label: '诊断',
        value: this.draft().diagnosis ?? '',
        onValueChange: (v: string) => {
          this.draft().diagnosis = v;
          this.viewModel.notifyTypedDraftChanged();
        }
      })
      MedicalValidatedEditableField({
        label: '主诉 / 症状',
        value: this.draft().symptom?.name ?? '',
        fieldKey: 'symptom.name',
        scrollTargetID: CaseRecognitionResultSupport.fieldScroll('symptom.name'),
        errorMessage: CaseRecognitionResultSupport.err(this.viewModel, 'symptom.name'),
        onValueChange: (v: string) => {
          const d = this.draft();
          if (d.symptom === undefined) {
            d.symptom = new SymptomRecognitionDraft();
          }
          d.symptom.name = v;
          this.viewModel.notifyTypedDraftChanged(['symptom.name']);
        }
      })
    }
    .width('100%')
  }

  build() {
    MedicalDocumentResultSectionCard({
      title: '病史与诊断',
      subtitle: '主诉 / 诊断',
      enableCollapse: true,
      forceExpanded: this.viewModel.isPreSubmitSectionExpanded(
        'preSubmitValidation.section.caseHistory'),
      content: () => {
        this.HistoryContent()
      }
    })
  }
}

@Component
export struct CaseVisitInfoSectionView {
  build() {
    Column() {}
  }
}

@Component
export struct CaseTreatmentPlanSectionView {
  build() {
    Column() {}
  }
}

export { CaseMatchedAttachmentsGridView } from '../CaseMatchedAttachmentsGridView';
