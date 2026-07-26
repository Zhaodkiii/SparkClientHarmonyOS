import {
  MED_EXEC_PRIMARY_TEXT,
  MED_EXEC_PROGRESS_TRACK,
  MED_EXEC_SECONDARY_TEXT,
  MED_EXEC_TEAL
} from './MedicationExecutionTheme';

export class MedicationExecutionDateStripMetrics {
  static readonly ITEM_WIDTH: number = 48;
  static readonly ITEM_SPACING: number = 8;
  static readonly STRIP_HEIGHT: number = 108;
  static readonly PROGRESS_CIRCLE_DIAMETER: number = 44;
  static readonly SELECTED_WEEKDAY_BADGE_SIZE: number = 26;
}

@Component
export struct MedicationExecutionDateDot {
  @Prop date: number = Date.now();
  @Prop isSelected: boolean = false;
  @Prop isLoaded: boolean = false;
  @Prop progress: number = 0;

  private weekdayText(): string {
    const weekdays: string[] = ['周日', '周一', '周二', '周三', '周四', '周五', '周六'];
    return weekdays[new Date(this.date).getDay()];
  }

  private effectiveProgress(): number {
    if (!this.isLoaded) {
      return 0;
    }
    return Math.max(0, Math.min(this.progress, 1));
  }

  @Builder
  private weekdayLabel() {
    if (this.isSelected) {
      Text(this.weekdayText())
        .fontSize(12)
        .fontWeight(FontWeight.Medium)
        .fontColor(Color.White)
        .width(MedicationExecutionDateStripMetrics.SELECTED_WEEKDAY_BADGE_SIZE)
        .height(MedicationExecutionDateStripMetrics.SELECTED_WEEKDAY_BADGE_SIZE)
        .textAlign(TextAlign.Center)
        .backgroundColor(MED_EXEC_PRIMARY_TEXT)
        .borderRadius(MedicationExecutionDateStripMetrics.SELECTED_WEEKDAY_BADGE_SIZE / 2)
    } else {
      Text(this.weekdayText())
        .fontSize(12)
        .fontWeight(FontWeight.Medium)
        .fontColor(MED_EXEC_SECONDARY_TEXT)
        .width(MedicationExecutionDateStripMetrics.ITEM_WIDTH)
        .textAlign(TextAlign.Center)
    }
  }

  @Builder
  private progressCircle() {
    Stack() {
      Circle()
        .width(MedicationExecutionDateStripMetrics.PROGRESS_CIRCLE_DIAMETER)
        .height(MedicationExecutionDateStripMetrics.PROGRESS_CIRCLE_DIAMETER)
        .fill(MED_EXEC_PROGRESS_TRACK)

      if (this.effectiveProgress() >= 1) {
        Circle()
          .width(MedicationExecutionDateStripMetrics.PROGRESS_CIRCLE_DIAMETER)
          .height(MedicationExecutionDateStripMetrics.PROGRESS_CIRCLE_DIAMETER)
          .fill(MED_EXEC_TEAL)
      } else if (this.effectiveProgress() > 0) {
        Column() {
          Blank()
          Row()
            .width(MedicationExecutionDateStripMetrics.PROGRESS_CIRCLE_DIAMETER)
            .height(MedicationExecutionDateStripMetrics.PROGRESS_CIRCLE_DIAMETER * this.effectiveProgress())
            .backgroundColor(MED_EXEC_TEAL)
        }
        .width(MedicationExecutionDateStripMetrics.PROGRESS_CIRCLE_DIAMETER)
        .height(MedicationExecutionDateStripMetrics.PROGRESS_CIRCLE_DIAMETER)
        .clip(true)
        .borderRadius(MedicationExecutionDateStripMetrics.PROGRESS_CIRCLE_DIAMETER / 2)
      }
    }
  }

  build() {
    Column({ space: 8 }) {
      this.weekdayLabel()
      this.progressCircle()
    }
    .width(MedicationExecutionDateStripMetrics.ITEM_WIDTH)
  }
}
