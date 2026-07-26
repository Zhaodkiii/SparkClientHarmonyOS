import { FileTransferService } from '../../../../../../../Core/FileStorage/FileTransferService';
import { MedicationExecutionDose } from './MedicationExecutionModels';
import {
  MED_EXEC_ACCENT,
  MED_EXEC_AS_NEEDED_BG,
  MED_EXEC_CARD_BG,
  MED_EXEC_CARD_RADIUS,
  MED_EXEC_GRADIENT_END,
  MED_EXEC_GRADIENT_START,
  MED_EXEC_PRIMARY_TEXT,
  MED_EXEC_TEAL
} from './MedicationExecutionTheme';
import { MedicationImageGlyph } from '../../MedicineBox/MedicationImageGlyph';

@Component
export struct MedicationExecutionPendingCard {
  @Prop timeText: string = '';
  @Prop doses: MedicationExecutionDose[] = [];
  fileTransferService?: FileTransferService;
  onAdd?: () => void;

  build() {
    Row({ space: 16 }) {
      Column({ space: 12 }) {
        Text(this.timeText)
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(MED_EXEC_PRIMARY_TEXT)

        ForEach(this.doses, (dose: MedicationExecutionDose) => {
          Row({ space: 12 }) {
            MedicationImageGlyph({
              seed: dose.plan.id,
              attachmentId: dose.imageAttachment?.id ?? 0,
              attachment: dose.imageAttachment,
              fileTransferService: this.fileTransferService
            })
              .width(36)
              .height(36)

            Column({ space: 2 }) {
              Text(dose.displayName())
                .fontSize(17)
                .fontWeight(FontWeight.Medium)
                .fontColor(MED_EXEC_PRIMARY_TEXT)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
              Text(dose.plannedDose)
                .fontSize(12)
                .fontColor('#8E8E93')
            }
            .alignItems(HorizontalAlign.Start)
          }
        }, (dose: MedicationExecutionDose) => dose.id)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Row() {
        SymbolGlyph($r('sys.symbol.plus'))
          .fontSize(22)
          .fontWeight(FontWeight.Medium)
          .fontColor([MED_EXEC_ACCENT])
      }
      .width(44)
      .height(44)
      .justifyContent(FlexAlign.Center)
      .onClick(() => {
        if (this.onAdd) {
          this.onAdd();
        }
      })
    }
    .padding(18)
    .backgroundColor(MED_EXEC_CARD_BG)
    .borderRadius(MED_EXEC_CARD_RADIUS)
    .width('100%')
  }
}

@Component
export struct MedicationExecutionAsNeededCard {
  onAdd?: () => void;

  build() {
    Row() {
      Text('按需用药')
        .fontSize(17)
        .fontWeight(FontWeight.Medium)
        .fontColor(MED_EXEC_PRIMARY_TEXT)
      Blank()
      Row() {
        SymbolGlyph($r('sys.symbol.plus'))
          .fontSize(22)
          .fontWeight(FontWeight.Medium)
          .fontColor([MED_EXEC_ACCENT])
      }
      .width(44)
      .height(44)
      .justifyContent(FlexAlign.Center)
      .onClick(() => {
        if (this.onAdd) {
          this.onAdd();
        }
      })
    }
    .padding({ left: 18, right: 10 })
    .constraintSize({ minHeight: 64 })
    .backgroundColor(MED_EXEC_AS_NEEDED_BG)
    .borderRadius(MED_EXEC_CARD_RADIUS)
    .width('100%')
  }
}

@Component
export struct MedicationExecutionAllDoneCard {
  build() {
    Row({ space: 16 }) {
      Text('已记录今天的所有定时用药')
        .fontSize(17)
        .fontWeight(FontWeight.Medium)
        .fontColor(Color.White)
        .lineHeight(24)
        .layoutWeight(1)

      Stack({ alignContent: Alignment.Center }) {
        SymbolGlyph($r('sys.symbol.calendar'))
          .fontSize(34)
          .fontColor(['#FFFFFFE6'])
        SymbolGlyph($r('sys.symbol.checkmark_circle_fill'))
          .fontSize(16)
          .fontColor(['#FFFFFFE6'])
          .margin({ left: 18, top: 14 })
      }
      .width(44)
      .height(44)
    }
    .padding(20)
    .linearGradient({
      angle: 90,
      colors: [[MED_EXEC_GRADIENT_START, 0], [MED_EXEC_GRADIENT_END, 1]]
    })
    .borderRadius(MED_EXEC_CARD_RADIUS)
    .shadow({
      radius: 12,
      color: '#14000000',
      offsetX: 0,
      offsetY: 4
    })
    .width('100%')
  }
}

@Component
export struct MedicationExecutionCompletedGroup {
  @Prop timeText: string = '';
  @Prop doses: MedicationExecutionDose[] = [];
  onTap?: () => void;

  private completedLabel(dose: MedicationExecutionDose): string {
    if (dose.status === 'skipped') {
      return `${dose.displayName()}（已跳过）`;
    }
    return dose.displayName();
  }

  build() {
    Row({ space: 14 }) {
      Text(this.timeText)
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor(MED_EXEC_PRIMARY_TEXT)
        .width(64)

      Column({ space: 10 }) {
        ForEach(this.doses, (dose: MedicationExecutionDose) => {
          Row({ space: 8 }) {
            SymbolGlyph(
              dose.status === 'taken'
                ? $r('sys.symbol.checkmark_circle_fill')
                : $r('sys.symbol.xmark_circle_fill')
            )
              .fontSize(18)
              .fontColor([dose.status === 'taken' ? MED_EXEC_TEAL : '#8E8E93'])
            Text(this.completedLabel(dose))
              .fontSize(17)
              .fontWeight(FontWeight.Medium)
              .fontColor(MED_EXEC_PRIMARY_TEXT)
          }
        }, (dose: MedicationExecutionDose) => dose.id)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      SymbolGlyph($r('sys.symbol.chevron_forward'))
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor(['#C7C7CC'])
    }
    .padding({ top: 14, bottom: 14 })
    .width('100%')
    .onClick(() => {
      if (this.onTap) {
        this.onTap();
      }
    })
  }
}
