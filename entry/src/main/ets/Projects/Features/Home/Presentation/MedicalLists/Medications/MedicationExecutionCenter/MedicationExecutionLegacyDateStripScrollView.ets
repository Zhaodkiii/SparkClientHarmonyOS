import {
  RemoteMedicationPlan,
  RemoteMedicationRecord,
  RemoteMedicineBox
} from '../../../../../../Core/Networking/API/Medical/MedicalSyncAPI';
import { medicationIsSameDay } from './MedicationExecutionDateUtils';
import { MedicationExecutionDateDot } from './MedicationExecutionDateDot';
import { MedicationExecutionDateItem } from './MedicationExecutionModels';
import { MedicationExecutionPlanner } from './MedicationExecutionPlanner';
import { MedicationExecutionRecordCache } from './MedicationExecutionRecordCache';
import { MedicationExecutionDateStripScrollMath } from './MedicationExecutionDateStripScrollMath';

/**
 * legacy 日期条横向滚动容器。对齐 iOS MedicationExecutionLegacyDateStripScrollView：
 * 三角固定于视口中心，滚动列表把选中项吸附到三角下方。
 */
@Component
export struct MedicationExecutionLegacyDateStripScrollView {
  @Prop items: MedicationExecutionDateItem[] = [];
  @Prop @Watch('onSelectedDatePropChanged') selectedDate: number = Date.now();
  @Prop itemWidth: number = 48;
  @Prop itemSpacing: number = 8;
  @Prop recordsByDayID: Record<string, RemoteMedicationRecord[]> = {};
  @Prop loadedWindowStart: number = 0;
  @Prop loadedWindowEndExclusive: number = 0;
  @Prop medicationPlans: RemoteMedicationPlan[] = [];
  @Prop medicineBoxes: RemoteMedicineBox[] = [];

  onCommit?: (date: number) => void;
  onSelectedDateChange?: (date: number) => void;

  private scroller: Scroller = new Scroller();
  @State private displayedDate: number = Date.now();
  @State private viewportWidth: number = 0;

  private isProgrammaticScroll: boolean = false;
  private isUserDragging: boolean = false;
  private pendingCommitTimer: number = -1;
  private programmaticScrollTimer: number = -1;
  private alignCenterTimer: number = -1;
  private hasInitialAligned: boolean = false;

  aboutToAppear(): void {
    this.displayedDate = this.selectedDate;
  }

  private itemPitch(): number {
    return MedicationExecutionDateStripScrollMath.itemPitch(this.itemWidth, this.itemSpacing);
  }

  private centerInset(): number {
    return MedicationExecutionDateStripScrollMath.centerInset(this.viewportWidth, this.itemWidth);
  }

  private selectedIndex(): number {
    for (let i = 0; i < this.items.length; i++) {
      if (medicationIsSameDay(this.items[i].date, new Date(this.selectedDate))) {
        return i;
      }
    }
    return 0;
  }

  private centeredOffsetFor(index: number): number {
    return MedicationExecutionDateStripScrollMath.centeredOffsetFor(index, this.itemPitch());
  }

  private indexForOffset(offsetX: number): number {
    return MedicationExecutionDateStripScrollMath.centeredIndexForOffset(
      offsetX,
      this.itemPitch(),
      this.items.length
    );
  }

  private beginProgrammaticScrollGuard(animated: boolean): void {
    if (this.programmaticScrollTimer >= 0) {
      clearTimeout(this.programmaticScrollTimer);
    }
    this.isProgrammaticScroll = true;
    const delayMs = animated ? 200 : 48;
    this.programmaticScrollTimer = setTimeout(() => {
      this.isProgrammaticScroll = false;
      this.programmaticScrollTimer = -1;
    }, delayMs);
  }

  private scrollToIndex(index: number, animated: boolean): void {
    if (this.items.length === 0 || this.viewportWidth <= 0) {
      return;
    }
    const safeIndex = Math.min(Math.max(index, 0), this.items.length - 1);
    const x = this.centeredOffsetFor(safeIndex);
    this.beginProgrammaticScrollGuard(animated);
    this.scroller.scrollTo({ xOffset: x, yOffset: 0, animation: animated });
  }

  private alignSelectedDateToCenter(animated: boolean): void {
    if (this.alignCenterTimer >= 0) {
      clearTimeout(this.alignCenterTimer);
      this.alignCenterTimer = -1;
    }
    if (this.viewportWidth <= 0 || this.items.length === 0) {
      return;
    }
    const runAlign = () => {
      this.scrollToIndex(this.selectedIndex(), animated);
    };
    if (this.hasInitialAligned) {
      runAlign();
      return;
    }
    this.alignCenterTimer = setTimeout(() => {
      runAlign();
      this.hasInitialAligned = true;
      this.alignCenterTimer = -1;
    }, 48);
  }

  private onSelectedDatePropChanged(): void {
    if (this.isUserDragging || this.isProgrammaticScroll) {
      return;
    }
    this.displayedDate = this.selectedDate;
    this.alignSelectedDateToCenter(false);
  }

  private highlightAtOffset(offsetX: number): void {
    if (this.isProgrammaticScroll) {
      return;
    }
    const index = this.indexForOffset(offsetX);
    if (!this.items[index]) {
      return;
    }
    const nextDate = this.items[index].date.getTime();
    if (nextDate === this.displayedDate) {
      return;
    }
    this.displayedDate = nextDate;
    if (this.onSelectedDateChange) {
      this.onSelectedDateChange(nextDate);
    }
  }

  private commitAtIndex(index: number): void {
    if (!this.items[index]) {
      return;
    }
    const committed = this.items[index].date.getTime();
    this.displayedDate = committed;
    if (this.onSelectedDateChange) {
      this.onSelectedDateChange(committed);
    }
    if (this.onCommit) {
      this.onCommit(committed);
    }
  }

  private scheduleSnap(): void {
    if (this.pendingCommitTimer >= 0) {
      clearTimeout(this.pendingCommitTimer);
    }
    this.pendingCommitTimer = setTimeout(() => {
      const offset = this.scroller.currentOffset().xOffset;
      const index = this.indexForOffset(offset);
      this.scrollToIndex(index, false);
      this.commitAtIndex(index);
      this.isUserDragging = false;
      this.pendingCommitTimer = -1;
    }, 80);
  }

  private isDateInLoadedWindow(day: number): boolean {
    if (this.loadedWindowStart <= 0 || this.loadedWindowEndExclusive <= 0) {
      return false;
    }
    const dayStart = new Date(day);
    dayStart.setHours(0, 0, 0, 0);
    return dayStart.getTime() >= this.loadedWindowStart
      && dayStart.getTime() < this.loadedWindowEndExclusive;
  }

  @Builder
  private dateDot(item: MedicationExecutionDateItem) {
    MedicationExecutionDateDot({
      date: item.date.getTime(),
      isSelected: medicationIsSameDay(item.date, new Date(this.selectedDate)),
      isLoaded: this.isDateInLoadedWindow(item.date.getTime()),
      progress: MedicationExecutionPlanner.progress(
        this.medicationPlans,
        this.medicineBoxes,
        MedicationExecutionRecordCache.recordsFor(item.date, this.recordsByDayID),
        item.date
      )
    })
  }

  build() {
    Scroll(this.scroller) {
      Row({ space: this.itemSpacing }) {
        ForEach(this.items, (item: MedicationExecutionDateItem) => {
          Button({ type: ButtonType.Normal }) {
            this.dateDot(item)
          }
          .width(this.itemWidth)
          .height('100%')
          .backgroundColor(Color.Transparent)
          .onClick(() => {
            let index = -1;
            for (let i = 0; i < this.items.length; i++) {
              if (this.items[i].id === item.id) {
                index = i;
                break;
              }
            }
            if (index < 0) {
              return;
            }
            this.scrollToIndex(index, true);
            setTimeout(() => {
              this.commitAtIndex(index);
            }, 200);
          })
        }, (item: MedicationExecutionDateItem) => item.id)
      }
      .padding({
        left: this.centerInset(),
        right: this.centerInset()
      })
      .height('100%')
    }
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Off)
    .nestedScroll({
      scrollForward: NestedScrollMode.SELF_FIRST,
      scrollBackward: NestedScrollMode.SELF_FIRST
    })
    .width('100%')
    .height('100%')
    .onAreaChange((_old, next) => {
      const width = next.width as number;
      if (width <= 0) {
        return;
      }
      const widthChanged = Math.abs(width - this.viewportWidth) > 0.5;
      this.viewportWidth = width;
      if (widthChanged || !this.hasInitialAligned) {
        this.alignSelectedDateToCenter(false);
      }
    })
    .onScrollStart(() => {
      this.isUserDragging = true;
    })
    .onScroll(() => {
      this.highlightAtOffset(this.scroller.currentOffset().xOffset);
    })
    .onScrollStop(() => {
      this.scheduleSnap();
    })
  }
}
