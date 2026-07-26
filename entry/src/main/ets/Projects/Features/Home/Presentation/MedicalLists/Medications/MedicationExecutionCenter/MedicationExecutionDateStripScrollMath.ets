/**
 * 日期条居中滚动数学。对齐 iOS legacy 视觉结果，但适配 ArkUI 实现：
 * iOS 用 UIScrollView.contentInset；鸿蒙用 Row 左右 padding，因此 scrollTo 偏移量为 index * pitch。
 */
export class MedicationExecutionDateStripScrollMath {
  static itemPitch(itemWidth: number, itemSpacing: number): number {
    return itemWidth + itemSpacing;
  }

  /** 左右 padding，使首尾日期项可滚到视口中心。 */
  static centerInset(viewportWidth: number, itemWidth: number): number {
    return Math.max((viewportWidth - itemWidth) / 2, 0);
  }

  /** 将 index 对应日期项中心滚到视口中心所需的 xOffset（Row 已含左右 padding）。 */
  static centeredOffsetFor(index: number, itemPitch: number): number {
    return Math.max(0, index * itemPitch);
  }

  /** 由当前滚动偏移反推视口中心下的日期项 index。 */
  static centeredIndexForOffset(
    offsetX: number,
    itemPitch: number,
    itemCount: number
  ): number {
    if (itemCount <= 0) {
      return 0;
    }
    const raw = Math.round(offsetX / itemPitch);
    return Math.min(Math.max(raw, 0), itemCount - 1);
  }
}
