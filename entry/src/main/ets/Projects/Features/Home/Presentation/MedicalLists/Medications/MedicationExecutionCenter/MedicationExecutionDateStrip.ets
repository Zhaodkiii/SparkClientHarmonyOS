import {
  RemoteMedicationPlan,
  RemoteMedicationRecord,
  RemoteMedicineBox
} from '../../../../../../Core/Networking/API/Medical/MedicalSyncAPI';
import { MedicationExecutionDateStripMetrics } from './MedicationExecutionDateDot';
import { MedicationExecutionLegacyDateStripScrollView } from './MedicationExecutionLegacyDateStripScrollView';
import { MedicationExecutionDateItem } from './MedicationExecutionModels';
import { MED_EXEC_DIVIDER, MED_EXEC_PRIMARY_TEXT } from './MedicationExecutionTheme';

@Component
export struct MedicationExecutionDateStrip {
  @Prop selectedDate: number = Date.now();
  @Prop recordsByDayID: Record<string, RemoteMedicationRecord[]> = {};
  @Prop loadedWindowStart: number = 0;
  @Prop loadedWindowEndExclusive: number = 0;
  @Prop medicationPlans: RemoteMedicationPlan[] = [];
  @Prop medicineBoxes: RemoteMedicineBox[] = [];

  onCommit?: (date: number) => void;
  onSelectedDateChange?: (date: number) => void;

  private dateStripDays(): MedicationExecutionDateItem[] {
    const out: MedicationExecutionDateItem[] = [];
    const today = new Date();
    for (let offset = -45; offset <= 45; offset++) {
      const date = new Date(today.getTime());
      date.setDate(today.getDate() + offset);
      date.setHours(0, 0, 0, 0);
      out.push(new MedicationExecutionDateItem(date));
    }
    return out;
  }

  build() {
    Column({ space: 0 }) {
      Divider()
        .width('100%')
        .height(0.5)
        .color(MED_EXEC_DIVIDER)

      Column() {
        Polygon()
          .points([[12, 14], [0, 0], [24, 0]])
          .fill(MED_EXEC_PRIMARY_TEXT)
          .width(24)
          .height(14)
      }
      .width('100%')
      .height(22)
      .alignItems(HorizontalAlign.Center)
      .justifyContent(FlexAlign.Center)

      MedicationExecutionLegacyDateStripScrollView({
        items: this.dateStripDays(),
        selectedDate: this.selectedDate,
        itemWidth: MedicationExecutionDateStripMetrics.ITEM_WIDTH,
        itemSpacing: MedicationExecutionDateStripMetrics.ITEM_SPACING,
        recordsByDayID: this.recordsByDayID,
        loadedWindowStart: this.loadedWindowStart,
        loadedWindowEndExclusive: this.loadedWindowEndExclusive,
        medicationPlans: this.medicationPlans,
        medicineBoxes: this.medicineBoxes,
        onCommit: (date: number) => {
          if (this.onCommit) {
            this.onCommit(date);
          }
        },
        onSelectedDateChange: (date: number) => {
          if (this.onSelectedDateChange) {
            this.onSelectedDateChange(date);
          }
        }
      })
        .height(86)
    }
    .height(MedicationExecutionDateStripMetrics.STRIP_HEIGHT)
    .width('100%')
  }
}
