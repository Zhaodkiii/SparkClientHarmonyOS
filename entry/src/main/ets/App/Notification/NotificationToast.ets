@Component
export struct NotificationToastView {
  @Prop json: string = '';

  build() {
    if (this.json.length > 0) {
      Column() {
        Text(this.messageText())
          .fontSize(14)
          .fontColor(Color.White)
          .textAlign(TextAlign.Center)
      }
      .width('92%')
      .padding({ left: 16, right: 16, top: 12, bottom: 12 })
      .borderRadius(10)
      .backgroundColor(this.bgColor())
      .shadow({ radius: 8, color: '#33000000' })
    }
  }

  private messageText(): string {
    try {
      const obj = JSON.parse(this.json) as Record<string, string>;
      const title = obj['title'] ?? '';
      const message = obj['message'] ?? '';
      if (title.length > 0) {
        return `${title}\n${message}`;
      }
      return message;
    } catch (_e) {
      return this.json;
    }
  }

  private bgColor(): ResourceColor {
    try {
      const obj = JSON.parse(this.json) as Record<string, string>;
      const level = obj['level'] ?? 'info';
      if (level === 'success') {
        return '#2B8A3E';
      }
      if (level === 'error') {
        return '#C92A2A';
      }
      if (level === 'warning') {
        return '#E67700';
      }
      return '#343A40';
    } catch (_e) {
      return '#343A40';
    }
  }
}
