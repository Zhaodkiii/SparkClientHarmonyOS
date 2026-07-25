import { SystemMessageSettingsPrompt } from '../../../../../../Core/AI/Runtime/SystemMessageSettingsPrompt';
import { PromptRepo } from '../../../../AISettings/Domain/PromptRepo';

@Component
export struct SystemMessageSettingsSheet {
  @Prop prompt: SystemMessageSettingsPrompt = new SystemMessageSettingsPrompt();
  @State private draftSessionPrompt: string = '';
  onSave: (sessionPrompt: string) => void = (_s: string) => {};
  onClose: () => void = () => {};

  aboutToAppear(): void {
    this.draftSessionPrompt = this.prompt.sessionPrompt;
  }

  private insertTemplate(repo: PromptRepo): void {
    const sep = this.draftSessionPrompt.length > 0 ? '\n\n' : '';
    this.draftSessionPrompt = `${this.draftSessionPrompt}${sep}${repo.content}`;
  }

  build() {
    Column({ space: 12 }) {
      Text('系统消息设置')
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .width('100%')
      Text(`模型：${this.prompt.modelDisplayName}`)
        .fontSize(13)
        .fontColor('#666666')
        .width('100%')
      if (this.prompt.isAgentModel) {
        Text('Agent Prompt（只读）')
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .width('100%')
        Text(this.prompt.agentPrompt && this.prompt.agentPrompt.length > 0
          ? this.prompt.agentPrompt : '无')
          .fontSize(12)
          .fontColor('#444444')
          .width('100%')
      }
      Text('默认 Prompt')
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .width('100%')
      Text(this.prompt.defaultPrompt)
        .fontSize(12)
        .fontColor('#666666')
        .width('100%')
        .maxLines(4)
      Text('会话 Prompt')
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .width('100%')
      TextArea({ text: this.draftSessionPrompt })
        .height(140)
        .width('100%')
        .onChange((v: string) => {
          this.draftSessionPrompt = v;
        })
      if (this.prompt.promptTemplates.length > 0) {
        Text('插入模板')
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .width('100%')
        ForEach(this.prompt.promptTemplates, (repo: PromptRepo) => {
          Button(repo.title)
            .fontSize(12)
            .height(32)
            .onClick(() => this.insertTemplate(repo))
        }, (repo: PromptRepo) => repo.id)
      }
      Row({ space: 12 }) {
        Button('取消')
          .layoutWeight(1)
          .onClick(() => this.onClose())
        Button('保存')
          .layoutWeight(1)
          .onClick(() => {
            this.onSave(this.draftSessionPrompt);
            this.onClose();
          })
      }
      .width('100%')
    }
    .padding(16)
    .width('100%')
    .height('100%')
  }
}
