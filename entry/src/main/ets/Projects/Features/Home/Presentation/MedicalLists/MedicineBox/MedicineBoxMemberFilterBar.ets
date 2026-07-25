import {
  MemberFilter,
  MemberFilterOption
} from './FamilyMedicineCabinetViewModel';

/** 对齐 iOS `MedicineBoxMemberFilterBar` */
@Component
export struct MedicineBoxMemberFilterBar {
  @Prop options: MemberFilterOption[] = [];
  @Prop selectedKey: string = 'all';
  onSelect?: (filter: MemberFilter) => void;

  build() {
    Scroll() {
      Row({ space: 8 }) {
        ForEach(this.options, (option: MemberFilterOption) => {
          Text(option.title)
            .fontSize(13)
            .fontWeight(this.selectedKey === option.filter.key() ? FontWeight.Medium : FontWeight.Regular)
            .fontColor(this.selectedKey === option.filter.key() ? '#AF52DE' : '#3C3C43')
            .padding({ left: 14, right: 14, top: 8, bottom: 8 })
            .backgroundColor(this.selectedKey === option.filter.key() ? '#AF52DE26' : '#F2F2F7')
            .borderRadius(18)
            .onClick(() => this.onSelect?.(option.filter))
        }, (option: MemberFilterOption): string => `member-filter-${option.filter.key()}`)
      }
      .padding({ left: 16, right: 16 })
    }
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Off)
    .width('100%')
  }
}
