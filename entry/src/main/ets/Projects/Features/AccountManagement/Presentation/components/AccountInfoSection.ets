import { AccountProfile } from '../../Domain/AccountProfile';

@Component
export struct AccountInfoSection {
  @Prop profile: AccountProfile | undefined = undefined;

  build() {
    Column() {
      Text($r('app.string.account_section_info'))
        .fontSize(13)
        .fontColor($r('sys.color.font_secondary'))
        .width('100%')
        .margin({ bottom: 8 })

      Column() {
        this.infoRow($r('app.string.account_field_id'), `${this.profile?.accountId ?? '-'}`)
        Divider().color('#F0F0F0')
        this.infoRow($r('app.string.account_field_contact'), this.maskedContact())
        Divider().color('#F0F0F0')
        this.infoRow($r('app.string.account_field_signin_method'), this.profile?.signInMethodDescription() ?? '-')
        Divider().color('#F0F0F0')
        this.infoRow($r('app.string.account_field_signin_time'), this.formatTime())
      }
      .width('100%')
      .padding({ left: 16, right: 16 })
      .backgroundColor(Color.White)
      .borderRadius(12)
    }
    .width('100%')
  }

  @Builder
  infoRow(label: Resource, value: string) {
    Row() {
      Text(label)
        .fontSize(15)
        .fontColor($r('sys.color.font_secondary'))
      Blank()
      Text(value)
        .fontSize(15)
        .maxLines(2)
        .textAlign(TextAlign.End)
        .constraintSize({ maxWidth: '60%' })
    }
    .width('100%')
    .padding({ top: 14, bottom: 14 })
  }

  private maskedContact(): string {
    const contact = this.profile?.contact ?? '';
    if (contact.length === 0) {
      return '-';
    }
    if (contact.indexOf('@') >= 0) {
      const at = contact.indexOf('@');
      const local = contact.substring(0, at);
      const domain = contact.substring(at);
      if (local.length <= 2) {
        return `*${domain}`;
      }
      return `${local.substring(0, 1)}***${local.substring(local.length - 1)}${domain}`;
    }
    if (contact.length <= 4) {
      return '****';
    }
    return `${contact.substring(0, 3)}****${contact.substring(contact.length - 2)}`;
  }

  private formatTime(): string {
    const ms = this.profile?.signedInAtMs;
    if (ms === undefined || ms <= 0) {
      return '-';
    }
    const d = new Date(ms);
    const y = d.getFullYear();
    const m = this.pad2(d.getMonth() + 1);
    const day = this.pad2(d.getDate());
    const hh = this.pad2(d.getHours());
    const mm = this.pad2(d.getMinutes());
    return `${y}-${m}-${day} ${hh}:${mm}`;
  }

  private pad2(n: number): string {
    return n < 10 ? `0${n}` : `${n}`;
  }
}
