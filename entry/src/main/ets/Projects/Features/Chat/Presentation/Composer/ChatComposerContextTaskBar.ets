import { SmallTask, TaskSource } from './Models/SmallTask';
import { ComposerTheme } from './Models/ComposerTheme';

/** 小任务胶囊条，对标 iOS ChatComposerContextTaskBar。 */
@Component
export struct ChatComposerContextTaskBar {
  @Prop boundMemberID: number = 0;
  @Prop isSending: boolean = false;
  @Prop smallTasks: SmallTask[] = [];
  onAskReport: () => void = () => {};
  onSmallTaskTapped: (task: SmallTask) => void = () => {};

  private shouldShowAskReportButton(): boolean {
    return this.boundMemberID > 0 && !this.isSending;
  }

  private hasContent(): boolean {
    return this.shouldShowAskReportButton() || this.smallTasks.length > 0;
  }

  private tintFor(task: SmallTask): string {
    return task.source === TaskSource.LOCAL ? ComposerTheme.systemOrange : ComposerTheme.systemBlue;
  }

  private glyphFor(task: SmallTask): string {
    const name = task.name;
    if (name.indexOf('睡眠') >= 0) {
      return '▰';
    }
    if (name.indexOf('饮食') >= 0) {
      return '●';
    }
    if (name.indexOf('运动') >= 0) {
      return '♟';
    }
    return '✦';
  }

  build() {
    if (!this.hasContent()) {
      Column() {}
    } else {
      Row({ space: 5 }) {
        if (this.shouldShowAskReportButton()) {
          Row({ space: 7 }) {
            Text('⌕').fontSize(14).fontColor(ComposerTheme.systemTeal)
            Text('问报告')
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .fontColor(ComposerTheme.systemTeal)
              .maxLines(1)
          }
          .height(34)
          .padding({ left: 12, right: 12 })
          .backgroundColor(ComposerTheme.withOpacity(ComposerTheme.systemTeal, 0.12))
          .borderRadius(17)
          .border({ width: 1, color: ComposerTheme.withOpacity(ComposerTheme.systemTeal, 0.18) })
          .opacity(this.isSending ? 0.5 : 1)
          .onClick(() => {
            if (!this.isSending) {
              this.onAskReport();
            }
          })
        }

        Blank()

        if (this.smallTasks.length > 0) {
          Scroll() {
            Row({ space: 10 }) {
              ForEach(this.smallTasks, (task: SmallTask) => {
                Row({ space: 7 }) {
                  Text(this.glyphFor(task))
                    .fontSize(14)
                    .fontColor(this.tintFor(task))
                  Text(task.name)
                    .fontSize(13)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(this.tintFor(task))
                    .maxLines(1)
                }
                .height(34)
                .padding({ left: 12, right: 12 })
                .backgroundColor(ComposerTheme.withOpacity(this.tintFor(task), 0.12))
                .borderRadius(17)
                .border({ width: 1, color: ComposerTheme.withOpacity(this.tintFor(task), 0.18) })
                .onClick(() => this.onSmallTaskTapped(task))
              }, (task: SmallTask) => task.code)
            }
          }
          .scrollable(ScrollDirection.Horizontal)
          .scrollBar(BarState.Off)
          .layoutWeight(1)
        }
      }
      .width('100%')
      .padding({ left: 8, right: 8 })
    }
  }
}
