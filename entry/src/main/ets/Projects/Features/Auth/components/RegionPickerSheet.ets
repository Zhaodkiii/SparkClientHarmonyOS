import { PhoneRegion } from '../PhoneRegion';

@Component
export struct RegionPickerSheet {
  @Prop selectedCode: string = 'CN';
  onSelect?: (region: PhoneRegion) => void;
  private regions: PhoneRegion[] = PhoneRegion.commonRegions();

  build() {
    Column() {
      Text($r('app.string.auth_region_picker_title'))
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .margin({ top: 16, bottom: 12 })

      List() {
        ForEach(this.regions, (item: PhoneRegion) => {
          ListItem() {
            Row() {
              Text(item.displayLabel(true))
                .fontSize(16)
                .layoutWeight(1)
              if (item.code === this.selectedCode) {
                Text('✓')
                  .fontSize(16)
                  .fontColor('#3A86FF')
              }
            }
            .width('100%')
            .padding({ left: 20, right: 20, top: 14, bottom: 14 })
            .onClick(() => {
              if (this.onSelect) {
                this.onSelect(item);
              }
            })
          }
        }, (item: PhoneRegion) => item.code)
      }
      .width('100%')
      .layoutWeight(1)
      .divider({ strokeWidth: 0.5, color: '#E9ECEF' })
    }
    .width('100%')
    .height('100%')
  }
}
