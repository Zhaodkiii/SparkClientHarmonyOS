import {
  MedicationPlanRecognitionDraft,
  PrescriptionRecognitionDraft
} from '../../../Domain/MedicalDocumentRecognitionDrafts';
import { MedicalDocumentUploadViewModel } from '../../MedicalDocumentUploadViewModel';
import {
  MedicalDocumentResultSectionCard,
  MedicalValidatedEditableField
} from '../MedicalDocumentResultSupport';
import { PrescriptionRecognitionResultSupport } from './PrescriptionRecognitionResultSupport';

@Component
export struct PrescriptionCandidateSectionView {
  @Builder
  private CandidateHint() {
    Text('识别到的药品可在保存后匹配家庭药箱；当前先确认处方与用药明细。')
      .fontSize(13)
      .fontColor('#636366')
      .width('100%')
  }

  build() {
    MedicalDocumentResultSectionCard({
      title: '药箱候选',
      subtitle: '保存链路接通后可绑定已有药箱或新建',
      content: () => {
        this.CandidateHint()
      }
    })
  }
}

@Component
export struct PrescriptionBatchesSectionView {
  @ObjectLink viewModel: MedicalDocumentUploadViewModel;

  @Builder
  private BatchEditor(batch: PrescriptionRecognitionDraft, index: number) {
    Column({ space: 10 }) {
      MedicalValidatedEditableField({
        label: '开方机构',
        value: batch.institutionName ?? '',
        onValueChange: (v: string) => {
          batch.institutionName = v;
          this.viewModel.notifyTypedDraftChanged();
        }
      })
      MedicalValidatedEditableField({
        label: '开方医生',
        value: batch.prescriberName ?? '',
        onValueChange: (v: string) => {
          batch.prescriberName = v;
          this.viewModel.notifyTypedDraftChanged();
        }
      })
      MedicalValidatedEditableField({
        label: '开方日期',
        value: batch.prescribedAt ?? '',
        placeholder: 'yyyy-MM-dd',
        fieldKey: `prescriptions[${index}].prescribed_at`,
        errorMessage: PrescriptionRecognitionResultSupport.err(
          this.viewModel, `prescriptions[${index}].prescribed_at`),
        onValueChange: (v: string) => {
          batch.prescribedAt = v;
          this.viewModel.notifyTypedDraftChanged([`prescriptions[${index}].prescribed_at`]);
        }
      })
      MedicalValidatedEditableField({
        label: '诊断',
        value: batch.diagnosis ?? '',
        onValueChange: (v: string) => {
          batch.diagnosis = v;
          this.viewModel.notifyTypedDraftChanged();
        }
      })
      MedicalValidatedEditableField({
        label: '处方号',
        value: batch.prescriptionNo ?? '',
        onValueChange: (v: string) => {
          batch.prescriptionNo = v;
          this.viewModel.notifyTypedDraftChanged();
        }
      })

      Text('药品明细')
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor('#1C1C1E')
        .width('100%')
        .margin({ top: 4 })

      ForEach(batch.medicationPlans ?? [], (plan: MedicationPlanRecognitionDraft, pIndex: number) => {
        Column({ space: 8 }) {
          MedicalValidatedEditableField({
            label: '药品名',
            value: plan.medicineName ?? '',
            fieldKey: `prescriptions[${index}].medication_plans[${pIndex}].drug_name`,
            errorMessage: PrescriptionRecognitionResultSupport.err(
              this.viewModel,
              `prescriptions[${index}].medication_plans[${pIndex}].drug_name`),
            onValueChange: (v: string) => {
              plan.medicineName = v;
              this.viewModel.notifyTypedDraftChanged([
                `prescriptions[${index}].medication_plans[${pIndex}].drug_name`
              ]);
            }
          })
          MedicalValidatedEditableField({
            label: '剂量',
            value: plan.doseValue ?? plan.dosePerTime ?? '',
            onValueChange: (v: string) => {
              plan.doseValue = v;
              this.viewModel.notifyTypedDraftChanged();
            }
          })
          MedicalValidatedEditableField({
            label: '频次',
            value: plan.frequencyType ?? plan.frequencyText ?? '',
            onValueChange: (v: string) => {
              plan.frequencyType = v;
              this.viewModel.notifyTypedDraftChanged();
            }
          })
        }
        .width('100%')
        .padding(10)
        .backgroundColor('#F7F7F9')
        .borderRadius(10)
        .id(`preSubmitValidation.card.medicationPlan.${index}.${pIndex}`)
      }, (plan: MedicationPlanRecognitionDraft, pIndex: number): string =>
        `rx-med-${index}-${pIndex}-${plan.medicineName ?? ''}`)

      if ((batch.medicationPlans ?? []).length === 0) {
        Button('添加一味药品')
          .height(36)
          .fontSize(13)
          .fontColor('#0A84FF')
          .backgroundColor('#E8F2FF')
          .onClick(() => {
            if (batch.medicationPlans === undefined) {
              batch.medicationPlans = [];
            }
            batch.medicationPlans.push(new MedicationPlanRecognitionDraft());
            this.viewModel.notifyTypedDraftChanged();
          })
      }
    }
    .width('100%')
    .id(`preSubmitValidation.card.prescription.${index}`)
  }

  build() {
    Column({ space: 14 }) {
      if (PrescriptionRecognitionResultSupport.batches(this.viewModel).length === 0) {
        MedicalDocumentResultSectionCard({
          title: '处方批次',
          content: () => {
            this.BatchEditor(PrescriptionRecognitionResultSupport.ensureFirst(this.viewModel), 0)
          }
        })
      } else {
        ForEach(PrescriptionRecognitionResultSupport.batches(this.viewModel),
          (batch: PrescriptionRecognitionDraft, index: number) => {
            MedicalDocumentResultSectionCard({
              title: batch.prescriptionNo ?? `处方 ${index + 1}`,
              subtitle: batch.institutionName ?? '开方机构待补充',
              badgeText: `${(batch.medicationPlans ?? []).length} 药`,
              enableCollapse: true,
              forceExpanded: this.viewModel.isPreSubmitSectionExpanded(
                'preSubmitValidation.section.treatmentPlan'),
              content: () => {
                this.BatchEditor(batch, index)
              }
            })
          },
          (batch: PrescriptionRecognitionDraft, index: number): string =>
            `rx-${index}-${batch.prescriptionNo ?? ''}-${batch.prescribedAt ?? ''}`)
      }
    }
    .width('100%')
  }
}
