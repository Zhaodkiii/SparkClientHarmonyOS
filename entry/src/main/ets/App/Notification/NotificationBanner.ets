@Component
export struct NotificationBannerView {
  @Prop json: string = '';
  onClose?: () => void;
  onTap?: () => void;

  build() {
    if (this.json.length > 0) {
      Row() {
        Column({ space: 4 }) {
          if (this.titleText().length > 0) {
            Text(this.titleText())
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .fontColor(Color.White)
              .width('100%')
          }
          Text(this.messageText())
            .fontSize(13)
            .fontColor(Color.White)
            .width('100%')
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        .onClick(() => {
          if (this.onTap) {
            this.onTap();
          }
        })

        Text('✕')
          .fontSize(16)
          .fontColor(Color.White)
          .padding(8)
          .onClick(() => {
            if (this.onClose) {
              this.onClose();
            }
          })
      }
      .width('94%')
      .padding({ left: 14, right: 8, top: 12, bottom: 12 })
      .borderRadius(12)
      .backgroundColor(this.bgColor())
      .shadow({ radius: 10, color: '#33000000' })
    }
  }

  private titleText(): string {
    try {
      const obj = JSON.parse(this.json) as Record<string, string>;
      return obj['title'] ?? '';
    } catch (_e) {
      return '';
    }
  }

  private messageText(): string {
    try {
      const obj = JSON.parse(this.json) as Record<string, string>;
      return obj['message'] ?? '';
    } catch (_e) {
      return this.json;
    }
  }

  private bgColor(): ResourceColor {
    try {
      const obj = JSON.parse(this.json) as Record<string, string>;
      const level = obj['level'] ?? 'warning';
      if (level === 'error') {
        return '#C92A2A';
      }
      if (level === 'warning') {
        return '#E67700';
      }
      return '#1C7ED6';
    } catch (_e) {
      return '#1C7ED6';
    }
  }
}
