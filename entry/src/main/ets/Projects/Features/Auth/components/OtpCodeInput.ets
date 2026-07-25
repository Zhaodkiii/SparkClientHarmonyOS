@Component
export struct OtpCodeInput {
  @Prop code: string = '';
  @Prop focusKey: string = 'authOtpHiddenInput';
  onCodeChange?: (value: string) => void;
  private readonly length: number = 6;
  @State private isFocused: boolean = false;

  build() {
    Stack() {
      Row({ space: 8 }) {
        ForEach(this.boxes(), (ch: string, index: number) => {
          Text(ch.length > 0 ? ch : '')
            .width(44)
            .height(52)
            .fontSize(22)
            .fontWeight(FontWeight.Medium)
            .textAlign(TextAlign.Center)
            .border({
              width: this.isActive(index) ? 2 : 1.5,
              color: this.isActive(index) ? '#0A84FF' : '#CED4DA',
              radius: 10
            })
            .backgroundColor('#F8F9FA')
        }, (ch: string, index: number) => `${index}_${ch}`)
      }
      .justifyContent(FlexAlign.Center)
      .width('100%')

      TextInput({ text: this.code })
        .type(InputType.Number)
        .maxLength(this.length)
        .width('100%')
        .height(56)
        .opacity(0.01)
        .id(this.focusKey)
        .defaultFocus(true)
        .focusOnTouch(true)
        .enableKeyboardOnFocus(true)
        .onFocus(() => {
          this.isFocused = true;
        })
        .onBlur(() => {
          this.isFocused = false;
        })
        .onChange((value: string) => {
          const next = value.replace(/[^\d]/g, '').substring(0, this.length);
          if (this.onCodeChange && next !== this.code) {
            this.onCodeChange(next);
          }
        })
    }
    .width('100%')
    .height(56)
    .onAppear(() => {
      this.focusInput();
    })
    .onClick(() => {
      this.focusInput();
    })
  }

  private boxes(): string[] {
    const arr: string[] = [];
    for (let i = 0; i < this.length; i++) {
      arr.push(i < this.code.length ? this.code.charAt(i) : '');
    }
    return arr;
  }

  private isActive(index: number): boolean {
    return this.isFocused && this.code.length === index && this.code.length < this.length;
  }

  private focusInput(): void {
    setTimeout(() => {
      focusControl.requestFocus(this.focusKey);
    }, 50);
  }
}
