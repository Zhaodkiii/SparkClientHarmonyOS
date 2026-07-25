import { AIScenarioRemoteModelRow } from './Models/AIScenarioRemoteModelRow';

/**
 * 模型横滑选择行，对标 iOS ChatComposerModelPickerRow。
 * 数据源应为 Runtime chat 场景（local+pro 合并后的统一消费）。
 */
@Component
export struct ChatComposerModelPickerRow {
  @Prop @Watch('onSelectionChanged') models: AIScenarioRemoteModelRow[] = [];
  /** 未选择具体模型时传 undefined，对应「默认」。 */
  @Prop @Watch('onSelectionChanged') selectedModelName: string | undefined = undefined;
  onSelect: (name: string | undefined) => void = (_name: string | undefined) => {};

  private scroller: Scroller = new Scroller();

  aboutToAppear(): void {
    this.scrollSelectedIntoView();
  }

  private onSelectionChanged(): void {
    this.scrollSelectedIntoView();
  }

  /** 0 = 默认芯片；其后为 models 下标 + 1 */
  private selectedIndex(): number {
    if (this.selectedModelName === undefined) {
      return 0;
    }
    for (let i = 0; i < this.models.length; i++) {
      if (this.models[i].name === this.selectedModelName) {
        return i + 1;
      }
    }
    return 0;
  }

  private scrollSelectedIntoView(): void {
    if (this.models.length === 0) {
      return;
    }
    const index = this.selectedIndex();
    setTimeout(() => {
      try {
        this.scroller.scrollToIndex(index, true, ScrollAlign.CENTER);
      } catch (_e) {
        // ignore
      }
    }, 32);
  }

  private handleSelect(name: string | undefined): void {
    if (this.selectedModelName === name) {
      return;
    }
    this.onSelect(name);
  }

  build() {
    if (this.models.length === 0) {
      Row({ space: 8 }) {
        LoadingProgress().width(16).height(16)
        Text('模型加载中…')
          .fontSize(12)
          .fontColor($r('app.color.text_secondary'))
      }
      .height(36)
      .width('100%')
      .padding({ left: 12, right: 12 })
      .justifyContent(FlexAlign.Start)
    } else {
      List({ space: 6, scroller: this.scroller }) {
        ListItem() {
          this.modelButton(
            '默认',
            this.selectedModelName === undefined,
            $r('sys.symbol.star_fill'),
            () => {
              this.handleSelect(undefined);
            }
          )
        }

        ForEach(this.models, (row: AIScenarioRemoteModelRow) => {
          ListItem() {
            this.modelButton(
              row.displayTitle,
              this.selectedModelName === row.name,
              row.composerIconResource,
              () => {
                this.handleSelect(row.name);
              }
            )
          }
        }, (row: AIScenarioRemoteModelRow) => row.id)
      }
      .listDirection(Axis.Horizontal)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
      .nestedScroll({
        scrollForward: NestedScrollMode.SELF_FIRST,
        scrollBackward: NestedScrollMode.SELF_FIRST
      })
      .width('100%')
      .height(44)
      .padding({ left: 12, right: 12 })
      .borderRadius(20)
    }
  }

  @Builder
  private modelButton(title: string, isSelected: boolean, icon: Resource, action: () => void) {
    Row({ space: 6 }) {
      SymbolGlyph(icon)
        .fontSize(20)
        .fontColor([isSelected ? $r('app.color.accent_color') : $r('app.color.gray')])

      if (isSelected) {
        Text(title)
          .fontSize(12)
          .fontColor($r('app.color.accent_color'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .constraintSize({ maxWidth: 140 })
      }
    }
    .padding(10)
    .height(36)
    .backgroundColor(isSelected ? 'rgba(0,122,255,0.12)' : $r('app.color.secondary_fill'))
    .borderRadius(20)
    .animation({ duration: 360, curve: Curve.Friction })
    .onClick(() => action())
  }
}
