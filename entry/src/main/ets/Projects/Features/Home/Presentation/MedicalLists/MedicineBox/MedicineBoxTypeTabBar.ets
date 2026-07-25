/** 对齐 iOS `MedicineBoxTypeTabBar` */
@Component
export struct MedicineBoxTypeTabBar {
  @Prop typeOptions: string[] = [];
  @Prop selectedTypeTab: string = '';
  onSelect?: (value: string) => void;

  build() {
    Scroll() {
      Row({ space: 8 }) {
        this.typeChip('全部', '')
        ForEach(this.typeOptions, (type: string) => {
          this.typeChip(type, type)
        }, (type: string): string => `medicine-type-${type}`)
      }
      .padding({ left: 16, right: 16 })
    }
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Off)
    .width('100%')
  }

  @Builder
  typeChip(title: string, value: string) {
    Text(title)
      .fontSize(13)
      .fontWeight(this.selectedTypeTab === value ? FontWeight.Medium : FontWeight.Regular)
      .fontColor(this.selectedTypeTab === value ? '#0A84FF' : '#3C3C43')
      .padding({ left: 14, right: 14, top: 8, bottom: 8 })
      .backgroundColor(this.selectedTypeTab === value ? '#0A84FF26' : '#F2F2F7')
      .borderRadius(18)
      .onClick(() => this.onSelect?.(value))
  }
}
