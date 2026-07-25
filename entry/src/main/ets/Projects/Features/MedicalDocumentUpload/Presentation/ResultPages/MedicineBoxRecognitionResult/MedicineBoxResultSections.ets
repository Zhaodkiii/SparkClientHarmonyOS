import { MedicineBoxRecognitionDraft } from '../../../Domain/MedicalDocumentRecognitionDrafts';
import { MedicalDocumentUploadViewModel } from '../../MedicalDocumentUploadViewModel';
import {
  MedicalDocumentResultSectionCard,
  MedicalValidatedEditableField
} from '../MedicalDocumentResultSupport';
import { MedicineBoxRecognitionResultSupport } from './MedicineBoxRecognitionResultSupport';

@Component
export struct MedicineBoxItemsSectionView {
  @ObjectLink viewModel: MedicalDocumentUploadViewModel;

  @Builder
  private BoxEditor(box: MedicineBoxRecognitionDraft, index: number) {
    Column({ space: 10 }) {
      MedicalValidatedEditableField({
        label: '药品名称',
        value: box.medicineName ?? '',
        fieldKey: `medicine_boxes[${index}].medicine_name`,
        scrollTargetID: `preSubmitValidation.card.medicineBox.${index}`,
        errorMessage: MedicineBoxRecognitionResultSupport.err(
          this.viewModel, `medicine_boxes[${index}].medicine_name`),
        onValueChange: (v: string) => {
          box.medicineName = v;
          this.viewModel.notifyTypedDraftChanged([
            `medicine_boxes[${index}].medicine_name`
          ]);
        }
      })
      MedicalValidatedEditableField({
        label: '药品类型',
        value: box.medicineType ?? '',
        onValueChange: (v: string) => {
          box.medicineType = v;
          this.viewModel.notifyTypedDraftChanged();
        }
      })
      MedicalValidatedEditableField({
        label: '品牌',
        value: box.brandName ?? '',
        onValueChange: (v: string) => {
          box.brandName = v;
          this.viewModel.notifyTypedDraftChanged();
        }
      })
      MedicalValidatedEditableField({
        label: '剂型',
        value: box.dosageForm ?? '',
        onValueChange: (v: string) => {
          box.dosageForm = v;
          this.viewModel.notifyTypedDraftChanged();
        }
      })
      MedicalValidatedEditableField({
        label: '规格',
        value: box.strength ?? '',
        onValueChange: (v: string) => {
          box.strength = v;
          this.viewModel.notifyTypedDraftChanged();
        }
      })
      MedicalValidatedEditableField({
        label: '剂量单位',
        value: box.doseUnit ?? '',
        onValueChange: (v: string) => {
          box.doseUnit = v;
          this.viewModel.notifyTypedDraftChanged();
        }
      })
      MedicalValidatedEditableField({
        label: '总数量',
        value: box.totalQuantity ?? '',
        fieldKey: `medicine_boxes[${index}].total_quantity`,
        errorMessage: MedicineBoxRecognitionResultSupport.err(
          this.viewModel, `medicine_boxes[${index}].total_quantity`),
        onValueChange: (v: string) => {
          box.totalQuantity = v;
          this.viewModel.notifyTypedDraftChanged([
            `medicine_boxes[${index}].total_quantity`
          ]);
        }
      })
      MedicalValidatedEditableField({
        label: '有效期',
        value: box.expireDate ?? '',
        placeholder: 'yyyy-MM-dd',
        onValueChange: (v: string) => {
          box.expireDate = v;
          this.viewModel.notifyTypedDraftChanged();
        }
      })
      MedicalValidatedEditableField({
        label: '备注',
        value: box.notes ?? '',
        onValueChange: (v: string) => {
          box.notes = v;
          this.viewModel.notifyTypedDraftChanged();
        }
      })
    }
    .width('100%')
    .id(`preSubmitValidation.card.medicineBox.${index}`)
  }

  build() {
    Column({ space: 14 }) {
      if (MedicineBoxRecognitionResultSupport.boxes(this.viewModel).length === 0) {
        MedicalDocumentResultSectionCard({
          title: '药品信息',
          content: () => {
            this.BoxEditor(MedicineBoxRecognitionResultSupport.ensureFirst(this.viewModel), 0)
          }
        })
      } else {
        ForEach(MedicineBoxRecognitionResultSupport.boxes(this.viewModel),
          (box: MedicineBoxRecognitionDraft, index: number) => {
            MedicalDocumentResultSectionCard({
              title: box.medicineName ?? `药品 ${index + 1}`,
              subtitle: box.brandName ?? box.dosageForm ?? '待补充品牌/剂型',
              enableCollapse: true,
              forceExpanded: this.viewModel.isPreSubmitSectionExpanded(
                'preSubmitValidation.section.medicineBoxList'),
              content: () => {
                this.BoxEditor(box, index)
              }
            })
          },
          (box: MedicineBoxRecognitionDraft, index: number): string =>
            `box-${index}-${box.medicineName ?? ''}-${box.expireDate ?? ''}`)
      }
    }
    .width('100%')
  }
}
