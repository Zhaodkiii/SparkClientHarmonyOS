/**
 * 用药执行中心视觉 token。对齐 iOS systemGroupedBackground / secondarySystemGroupedBackground 语义。
 */
export const MED_EXEC_PAGE_BG: string = '#F2F2F7';
export const MED_EXEC_CARD_BG: string = '#FFFFFF';
export const MED_EXEC_NAV_BG: string = '#FFFFFF';
export const MED_EXEC_PRIMARY_TEXT: string = '#1C1C1E';
export const MED_EXEC_SECONDARY_TEXT: string = '#8E8E93';
export const MED_EXEC_ACCENT: string = '#007AFF';
export const MED_EXEC_TEAL: string = '#30B0C7';
export const MED_EXEC_DIVIDER: string = '#E5E5EA';
export const MED_EXEC_PROGRESS_TRACK: string = '#E5E5EA';
export const MED_EXEC_AS_NEEDED_BG: string = '#E8F7F9';
export const MED_EXEC_GRADIENT_START: string = '#007AFF';
export const MED_EXEC_GRADIENT_END: string = '#5856D6';

export const MED_EXEC_PAGE_HORIZONTAL: number = 20;
export const MED_EXEC_SECTION_SPACING: number = 24;
export const MED_EXEC_CARD_RADIUS: number = 24;
export const MED_EXEC_DATE_TITLE_SIZE: number = 34;
export const MED_EXEC_SECTION_TITLE_SIZE: number = 22;
export const MED_EXEC_NAV_TITLE_SIZE: number = 17;
export const MED_EXEC_NAV_SIDE_WIDTH: number = 72;

@Component
export struct MedicationExecutionNavBar {
  @Prop showMedicineBoxTrail: boolean = true;
  onBack?: () => void;
  onOpenMedicineBox?: () => void;

  build() {
    Column({ space: 0 }) {
      Row() {
        Text('‹ 返回')
          .fontSize(16)
          .fontColor(MED_EXEC_ACCENT)
          .width(MED_EXEC_NAV_SIDE_WIDTH)
          .onClick(() => {
            if (this.onBack) {
              this.onBack();
            }
          })

        Text('用药')
          .fontSize(MED_EXEC_NAV_TITLE_SIZE)
          .fontWeight(FontWeight.Medium)
          .fontColor(MED_EXEC_PRIMARY_TEXT)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
          .textAlign(TextAlign.Center)

        if (this.showMedicineBoxTrail) {
          Text('药箱')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor(MED_EXEC_ACCENT)
            .width(MED_EXEC_NAV_SIDE_WIDTH)
            .textAlign(TextAlign.End)
            .onClick(() => {
              if (this.onOpenMedicineBox) {
                this.onOpenMedicineBox();
              }
            })
        } else {
          Blank()
            .width(MED_EXEC_NAV_SIDE_WIDTH)
        }
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 10, bottom: 10 })

      Divider()
        .width('100%')
        .height(0.5)
        .color(MED_EXEC_DIVIDER)
    }
    .width('100%')
    .backgroundColor(MED_EXEC_NAV_BG)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])
  }
}
