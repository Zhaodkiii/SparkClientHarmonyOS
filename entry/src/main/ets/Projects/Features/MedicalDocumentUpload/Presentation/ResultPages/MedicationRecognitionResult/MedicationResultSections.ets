import { MedicationPlanRecognitionDraft } from '../../../Domain/MedicalDocumentRecognitionDrafts';
import { MedicalDocumentUploadViewModel } from '../../MedicalDocumentUploadViewModel';
import {
  MedicalDocumentResultSectionCard,
  MedicalValidatedEditableField
} from '../MedicalDocumentResultSupport';
import { MedicationRecognitionResultSupport } from './MedicationRecognitionResultSupport';

@Component
export struct MedicationPlansSectionView {
  @ObjectLink viewModel: MedicalDocumentUploadViewModel;

  @Builder
  private PlanEditor(plan: MedicationPlanRecognitionDraft, index: number) {
    Column({ space: 10 }) {
      MedicalValidatedEditableField({
        label: '药品名',
        value: plan.medicineName ?? '',
        fieldKey: `medication_plans[${index}].drug_name`,
        scrollTargetID: `preSubmitValidation.card.medicationPlan.${index}`,
        errorMessage: MedicationRecognitionResultSupport.err(
          this.viewModel, `medication_plans[${index}].drug_name`),
        onValueChange: (v: string) => {
          plan.medicineName = v;
          this.viewModel.notifyTypedDraftChanged([
            `medication_plans[${index}].drug_name`
          ]);
        }
      })
      MedicalValidatedEditableField({
        label: '规格',
        value: plan.strength ?? '',
        onValueChange: (v: string) => {
          plan.strength = v;
          this.viewModel.notifyTypedDraftChanged();
        }
      })
      MedicalValidatedEditableField({
        label: '单次剂量',
        value: plan.doseValue ?? plan.dosePerTime ?? '',
        onValueChange: (v: string) => {
          plan.doseValue = v;
          this.viewModel.notifyTypedDraftChanged();
        }
      })
      MedicalValidatedEditableField({
        label: '频次类型',
        value: plan.frequencyType ?? '',
        placeholder: '每天 / 每周 / 间隔',
        onValueChange: (v: string) => {
          plan.frequencyType = v;
          this.viewModel.notifyTypedDraftChanged();
        }
      })
      MedicalValidatedEditableField({
        label: '开始日期',
        value: plan.startDate ?? '',
        placeholder: 'yyyy-MM-dd',
        onValueChange: (v: string) => {
          plan.startDate = v;
          this.viewModel.notifyTypedDraftChanged();
        }
      })
      MedicalValidatedEditableField({
        label: '结束日期',
        value: plan.endDate ?? '',
        placeholder: 'yyyy-MM-dd',
        onValueChange: (v: string) => {
          plan.endDate = v;
          this.viewModel.notifyTypedDraftChanged();
        }
      })
      MedicalValidatedEditableField({
        label: '提醒时间',
        value: MedicationRecognitionResultSupport.reminderText(plan),
        placeholder: 'HH:mm，多个用顿号分隔',
        editable: false
      })
      MedicalValidatedEditableField({
        label: '用法说明',
        value: plan.instructions ?? '',
        onValueChange: (v: string) => {
          plan.instructions = v;
          this.viewModel.notifyTypedDraftChanged();
        }
      })
    }
    .width('100%')
    .id(`preSubmitValidation.card.medicationPlan.${index}`)
  }

  build() {
    Column({ space: 14 }) {
      if (MedicationRecognitionResultSupport.plans(this.viewModel).length === 0) {
        MedicalDocumentResultSectionCard({
          title: '用药计划',
          content: () => {
            this.PlanEditor(MedicationRecognitionResultSupport.ensureFirst(this.viewModel), 0)
          }
        })
      } else {
        ForEach(MedicationRecognitionResultSupport.plans(this.viewModel),
          (plan: MedicationPlanRecognitionDraft, index: number) => {
            MedicalDocumentResultSectionCard({
              title: plan.medicineName ?? `计划 ${index + 1}`,
              subtitle: plan.frequencyText ?? plan.frequencyType ?? '频次待补充',
              enableCollapse: true,
              forceExpanded: this.viewModel.isPreSubmitSectionExpanded(
                'preSubmitValidation.section.medicationList'),
              content: () => {
                this.PlanEditor(plan, index)
              }
            })
          },
          (plan: MedicationPlanRecognitionDraft, index: number): string =>
            `med-${index}-${plan.medicineName ?? ''}-${plan.startDate ?? ''}`)
      }
    }
    .width('100%')
  }
}
