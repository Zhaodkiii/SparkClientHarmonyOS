import { FileTransferService } from '../../../../../../../Core/FileStorage/FileTransferService';
import {
  MedicationDoseLogStatus,
  MedicationExecutionDose,
  MedicationExecutionDoseEdit,
  MedicationExecutionLogSheetContext,
  MedicationExecutionLogSubmission,
  medicationDoseLogStatusTitle
} from './MedicationExecutionModels';
import { MedicationImageGlyph } from '../../MedicineBox/MedicationImageGlyph';

@Component
export struct MedicationExecutionLogSheet {
  @Prop context: MedicationExecutionLogSheetContext = new MedicationExecutionLogSheetContext();
  @Prop isSaving: boolean = false;
  fileTransferService?: FileTransferService;
  onCancel?: () => void;
  onDone?: (submission: MedicationExecutionLogSubmission) => void;

  @State private selections: Record<string, MedicationDoseLogStatus> = {};
  @State private doseEdits: Record<string, MedicationExecutionDoseEdit> = {};

  aboutToAppear(): void {
    this.selections = this.context.initialSelections();
    const edits: Record<string, MedicationExecutionDoseEdit> = {};
    for (let i = 0; i < this.context.doses.length; i++) {
      const dose = this.context.doses[i];
      edits[dose.id] = MedicationExecutionDoseEdit.fromDose(dose);
    }
    this.doseEdits = edits;
  }

  private canSubmit(): boolean {
    return Object.keys(this.selections).length > 0 && !this.isSaving;
  }

  private toggleStatus(doseID: string, status: MedicationDoseLogStatus): void {
    const next: Record<string, MedicationDoseLogStatus> = {};
    const keys = Object.keys(this.selections);
    let toggledOff = false;
    for (let i = 0; i < keys.length; i++) {
      const key = keys[i];
      if (key === doseID && this.selections[key] === status) {
        toggledOff = true;
        continue;
      }
      next[key] = this.selections[key];
    }
    if (!toggledOff) {
      next[doseID] = status;
    }
    this.selections = next;
  }

  build() {
    Column() {
      Row() {
        Button('取消')
          .fontSize(16)
          .fontColor('#007AFF')
          .backgroundColor(Color.Transparent)
          .onClick(() => {
            if (this.onCancel) {
              this.onCancel();
            }
          })
        Blank()
        Text(this.context.title)
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
        Blank()
        Text(' ')
          .width(48)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 8 })

      Scroll() {
        Column({ space: 16 }) {
          if (this.context.doses.length === 0) {
            Text('暂无用药计划，可点击右上角按钮从药箱选择用药。')
              .fontSize(15)
              .fontColor('#8E8E93')
              .textAlign(TextAlign.Center)
              .width('100%')
              .padding({ top: 24, bottom: 24 })
          } else {
            ForEach(this.context.doses, (dose: MedicationExecutionDose) => {
              this.doseRow(dose)
            }, (dose: MedicationExecutionDose) => dose.id)
          }
        }
        .padding({ left: 20, right: 20, top: 12, bottom: 120 })
      }
      .layoutWeight(1)

      Button('完成')
        .width('100%')
        .height(56)
        .fontSize(17)
        .fontWeight(FontWeight.Medium)
        .fontColor(Color.White)
        .backgroundColor(this.canSubmit() ? '#007AFF' : '#C7C7CC')
        .borderRadius(28)
        .enabled(this.canSubmit())
        .margin({ left: 20, right: 20, bottom: 20 })
        .onClick(() => {
          if (!this.canSubmit() || !this.onDone) {
            return;
          }
          const submission = new MedicationExecutionLogSubmission();
          submission.selections = this.selections;
          submission.edits = this.doseEdits;
          submission.doses = this.context.doses;
          this.onDone(submission);
        })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F2F2F7')
  }

  @Builder
  private doseRow(dose: MedicationExecutionDose) {
    Column({ space: 12 }) {
      Row({ space: 12 }) {
        MedicationImageGlyph({
          seed: dose.plan.id,
          attachmentId: dose.imageAttachment?.id ?? 0,
          attachment: dose.imageAttachment,
          fileTransferService: this.fileTransferService
        })
          .width(44)
          .height(44)

        Column({ space: 4 }) {
          Text(dose.displayName())
            .fontSize(17)
            .fontWeight(FontWeight.Medium)
            .fontColor('#1C1C1E')
          Text(dose.instructionText(this.doseEdits[dose.id]))
            .fontSize(13)
            .fontColor('#8E8E93')
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
      }

      Row({ space: 12 }) {
        Button(medicationDoseLogStatusTitle(MedicationDoseLogStatus.TAKEN))
          .layoutWeight(1)
          .height(44)
          .fontSize(15)
          .fontColor(this.selections[dose.id] === MedicationDoseLogStatus.TAKEN ? Color.White : '#007AFF')
          .backgroundColor(this.selections[dose.id] === MedicationDoseLogStatus.TAKEN ? '#007AFF' : '#007AFF1A')
          .borderRadius(22)
          .onClick(() => {
            this.toggleStatus(dose.id, MedicationDoseLogStatus.TAKEN);
          })

        Button(medicationDoseLogStatusTitle(MedicationDoseLogStatus.SKIPPED))
          .layoutWeight(1)
          .height(44)
          .fontSize(15)
          .fontColor(this.selections[dose.id] === MedicationDoseLogStatus.SKIPPED ? Color.White : '#8E8E93')
          .backgroundColor(this.selections[dose.id] === MedicationDoseLogStatus.SKIPPED ? '#8E8E93' : '#F2F2F7')
          .borderRadius(22)
          .onClick(() => {
            this.toggleStatus(dose.id, MedicationDoseLogStatus.SKIPPED);
          })
      }
    }
    .padding(16)
    .backgroundColor('#FFFFFF')
    .borderRadius(20)
    .width('100%')
  }
}
