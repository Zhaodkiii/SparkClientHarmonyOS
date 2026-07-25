import {
  HealthResourceToolCandidateDTO,
  HealthResourceToolCandidatePrompt
} from '../../../../../../Core/AI/Runtime/HealthResourceToolCandidatePrompt';

@Component
export struct HealthResourceCandidateSheet {
  @Prop prompt: HealthResourceToolCandidatePrompt = new HealthResourceToolCandidatePrompt();
  @State private selectedKeys: string[] = [];
  onConfirm: (selected: HealthResourceToolCandidateDTO[]) => void =
    (_s: HealthResourceToolCandidateDTO[]) => {};
  onClose: () => void = () => {};

  private cacheKey(c: HealthResourceToolCandidateDTO): string {
    return `${c.resourceType}:${c.memberId}:${c.resourceId}`;
  }

  private toggle(c: HealthResourceToolCandidateDTO): void {
    const key = this.cacheKey(c);
    const idx = this.selectedKeys.indexOf(key);
    if (idx >= 0) {
      const next = this.selectedKeys.slice();
      next.splice(idx, 1);
      this.selectedKeys = next;
      return;
    }
    if (this.selectedKeys.length >= this.prompt.maxSelectable) {
      if (this.prompt.maxSelectable === 1) {
        this.selectedKeys = [key];
      }
      return;
    }
    this.selectedKeys = this.selectedKeys.concat([key]);
  }

  private isSelected(c: HealthResourceToolCandidateDTO): boolean {
    return this.selectedKeys.indexOf(this.cacheKey(c)) >= 0;
  }

  private confirm(): void {
    const selected: HealthResourceToolCandidateDTO[] = [];
    for (let i = 0; i < this.prompt.candidates.length; i++) {
      const c = this.prompt.candidates[i];
      if (this.isSelected(c)) {
        selected.push(c);
      }
    }
    this.onConfirm(selected);
    this.onClose();
  }

  build() {
    Column({ space: 12 }) {
      Text('选择健康资料')
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .width('100%')
      Text(`最多选择 ${this.prompt.maxSelectable} 项`)
        .fontSize(12)
        .fontColor('#666666')
        .width('100%')
      if (this.prompt.candidates.length === 0) {
        Text('暂无候选资料')
          .fontSize(14)
          .fontColor('#999999')
          .width('100%')
          .margin({ top: 24 })
      } else {
        List({ space: 8 }) {
          ForEach(this.prompt.candidates, (c: HealthResourceToolCandidateDTO) => {
            ListItem() {
              Row({ space: 8 }) {
                Checkbox()
                  .select(this.isSelected(c))
                  .onChange((_v: boolean) => this.toggle(c))
                Column({ space: 4 }) {
                  Text(c.title)
                    .fontSize(14)
                    .width('100%')
                  Text(c.matchReason.length > 0 ? c.matchReason : c.resourceType)
                    .fontSize(12)
                    .fontColor('#666666')
                    .width('100%')
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Start)
              }
              .width('100%')
              .padding(8)
              .onClick(() => this.toggle(c))
            }
          }, (c: HealthResourceToolCandidateDTO) => this.cacheKey(c))
        }
        .layoutWeight(1)
        .width('100%')
      }
      Row({ space: 12 }) {
        Button('取消')
          .layoutWeight(1)
          .onClick(() => this.onClose())
        Button('确认')
          .layoutWeight(1)
          .enabled(this.selectedKeys.length > 0)
          .onClick(() => this.confirm())
      }
      .width('100%')
    }
    .padding(16)
    .width('100%')
    .height('100%')
  }
}
