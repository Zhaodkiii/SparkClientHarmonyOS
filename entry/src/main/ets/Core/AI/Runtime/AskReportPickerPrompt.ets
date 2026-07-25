/** 对齐 iOS AskReportPickerPrompt：手动「问报告」选择器载荷。 */
export class AskReportPickerPrompt {
  id: string = '';
  threadID: string = '';
  memberID: number = 0;

  static create(threadID: string, memberID: number): AskReportPickerPrompt {
    const p = new AskReportPickerPrompt();
    p.id = `${Date.now()}_${Math.floor(Math.random() * 100000)}`;
    p.threadID = threadID;
    p.memberID = memberID;
    return p;
  }
}
