import { AskReportPickerPrompt } from '../../../../../../Core/AI/Runtime/AskReportPickerPrompt';
import { HealthResourceRef } from '../../Composer/Models/HealthResourceRef';

/**
 * 问报告选择器 Sheet。
 * 健康资料列表数据源未完全迁移前：空态 + 手动标题占位，不写假业务数据。
 */
@Component
export struct AskReportPickerSheet {
  @Prop prompt: AskReportPickerPrompt = new AskReportPickerPrompt();
  @State private draftTitle: string = '';
  onConfirm: (refs: HealthResourceRef[]) => void = (_r: HealthResourceRef[]) => {};
  onClose: () => void = () => {};

  private confirmManual(): void {
    const title = this.draftTitle.trim();
    if (title.length === 0) {
      return;
    }
    const ref = HealthResourceRef.fromRaw(
      'manual',
      Date.now(),
      this.prompt.memberID,
      title,
      '手动问报告',
      '报告'
    );
    this.onConfirm([ref]);
    this.onClose();
  }

  build() {
    Column({ space: 12 }) {
      Text('问报告')
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .width('100%')
      Text(`成员 ID：${this.prompt.memberID > 0 ? this.prompt.memberID : '未绑定'}`)
        .fontSize(12)
        .fontColor('#666666')
        .width('100%')
      Text('健康资料列表数据源待接入。可先输入标题作为引用占位。')
        .fontSize(13)
        .fontColor('#888888')
        .width('100%')
      TextInput({ text: this.draftTitle, placeholder: '报告标题' })
        .width('100%')
        .onChange((v: string) => {
          this.draftTitle = v;
        })
      Row({ space: 12 }) {
        Button('取消')
          .layoutWeight(1)
          .onClick(() => this.onClose())
        Button('添加引用')
          .layoutWeight(1)
          .enabled(this.draftTitle.trim().length > 0)
          .onClick(() => this.confirmManual())
      }
      .width('100%')
    }
    .padding(16)
    .width('100%')
    .height('100%')
  }
}
