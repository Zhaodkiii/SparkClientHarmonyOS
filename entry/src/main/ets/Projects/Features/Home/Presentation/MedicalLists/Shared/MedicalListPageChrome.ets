/**
 * 医疗二级页统一头部 / 底部 Chrome。
 * 以检查报告列表页为样本：白底延伸至系统安全区，不叠加 topRectHeight（避免与 expandSafeArea 双重避让）。
 */

export const MEDICAL_LIST_PAGE_BG: string = '#F2F2F7';
export const MEDICAL_LIST_HEADER_BG: string = '#FFFFFF';
export const MEDICAL_LIST_ACCENT: string = '#0A84FF';
export const MEDICAL_LIST_DIVIDER: string = '#E5E5EA';
export const MEDICAL_LIST_SEARCH_FIELD_BG: string = '#F2F2F7';

/** 上传/全屏流程头部左侧按钮样式。 */
export enum MedicalUploadHeaderLeadingStyle {
  CLOSE = 'close',
  CANCEL = 'cancel'
}

/**
 * AI 上传 / 识别流程统一头部：× 或「取消」+ 居中标题 + 白底延伸至顶部安全区。
 * ContentCover / Sheet 全屏页需叠加 topRectHeight，避免按钮落入状态栏；白底仍由 expandSafeArea 延伸。
 */
@Component
export struct MedicalUploadPageHeaderChrome {
  title: string = '';
  titleFontSize: number = 18;
  showDivider: boolean = true;
  leadingStyle: MedicalUploadHeaderLeadingStyle = MedicalUploadHeaderLeadingStyle.CLOSE;
  onLeading?: () => void;
  @StorageProp('topRectHeight') private topRectHeightPx: number = 0;

  private leadingWidth(): number {
    return this.leadingStyle === MedicalUploadHeaderLeadingStyle.CANCEL ? 58 : 44;
  }

  private topSafeInset(): number {
    if (this.topRectHeightPx > 0) {
      return this.getUIContext().px2vp(this.topRectHeightPx);
    }
    return 24;
  }

  build() {
    Column({ space: 0 }) {
      Row() {
        if (this.leadingStyle === MedicalUploadHeaderLeadingStyle.CANCEL) {
          Text('取消')
            .width(this.leadingWidth())
            .fontSize(16)
            .fontColor(MEDICAL_LIST_ACCENT)
            .onClick(() => {
              if (this.onLeading) {
                this.onLeading();
              }
            })
        } else {
          Text('×')
            .width(this.leadingWidth())
            .height(44)
            .fontSize(28)
            .fontColor('#1C1C1E')
            .textAlign(TextAlign.Center)
            .onClick(() => {
              if (this.onLeading) {
                this.onLeading();
              }
            })
        }
        Text(this.title)
          .layoutWeight(1)
          .fontSize(this.titleFontSize)
          .fontWeight(FontWeight.Medium)
          .fontColor('#1C1C1E')
          .textAlign(TextAlign.Center)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Blank().width(this.leadingWidth())
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: this.topSafeInset() + 12, bottom: 8 })

      if (this.showDivider) {
        Divider()
          .width('100%')
          .height(0.5)
          .color(MEDICAL_LIST_DIVIDER)
      }
    }
    .width('100%')
    .backgroundColor(MEDICAL_LIST_HEADER_BG)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])
  }
}

@Builder
function medicalListPageEmptyBuilder() {
}

@Builder
function medicalListPageDefaultTrailingBuilder() {
  Blank().width(28)
}

@Builder
function medicalListPageDefaultDetailTrailingBuilder() {
  Blank().width(44)
}

/**
 * 列表式导航栏：返回 | 居中标题 | 右侧操作（对称 Blank 保持标题居中）。
 */
@Component
export struct MedicalListPageHeaderChrome {
  title: string = '';
  titleFontSize: number = 18;
  showDivider: boolean = true;
  onBack?: () => void;
  /** 简单右侧文字按钮；与 trailing @BuilderParam 二选一，优先 trailingText。 */
  trailingText: string = '';
  onTrailing?: () => void;
  @BuilderParam trailing: () => void = medicalListPageDefaultTrailingBuilder;
  @BuilderParam body: () => void = medicalListPageEmptyBuilder;

  build() {
    Column({ space: 0 }) {
      Row() {
        Text('‹ 返回')
          .fontSize(16)
          .fontColor(MEDICAL_LIST_ACCENT)
          .onClick(() => {
            if (this.onBack) {
              this.onBack();
            }
          })
        Blank()
        Text(this.title)
          .fontSize(this.titleFontSize)
          .fontWeight(FontWeight.Medium)
          .fontColor('#1C1C1E')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Blank()
        if (this.trailingText.length > 0) {
          Text(this.trailingText)
            .fontSize(14)
            .fontColor(MEDICAL_LIST_ACCENT)
            .onClick(() => {
              if (this.onTrailing) {
                this.onTrailing();
              }
            })
        } else {
          this.trailing()
        }
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 8 })

      this.body()

      if (this.showDivider) {
        Divider()
          .width('100%')
          .height(0.5)
          .color(MEDICAL_LIST_DIVIDER)
      }
    }
    .width('100%')
    .backgroundColor(MEDICAL_LIST_HEADER_BG)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])
  }
}

/**
 * 白底头部导航行（不含背景与安全区）。与扩展子组件、Divider 一起包在外层 Column 内。
 */
@Component
export struct MedicalListPageHeaderSection {
  title: string = '';
  titleFontSize: number = 18;
  onBack?: () => void;
  trailingText: string = '';
  onTrailing?: () => void;
  @BuilderParam trailing: () => void = medicalListPageDefaultTrailingBuilder;

  build() {
    Row() {
      Text('‹ 返回')
        .fontSize(16)
        .fontColor(MEDICAL_LIST_ACCENT)
        .onClick(() => {
          if (this.onBack) {
            this.onBack();
          }
        })
      Blank()
      Text(this.title)
        .fontSize(this.titleFontSize)
        .fontWeight(FontWeight.Medium)
        .fontColor('#1C1C1E')
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      Blank()
      if (this.trailingText.length > 0) {
        Text(this.trailingText)
          .fontSize(14)
          .fontColor(MEDICAL_LIST_ACCENT)
          .onClick(() => {
            if (this.onTrailing) {
              this.onTrailing();
            }
          })
      } else {
        this.trailing()
      }
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 8 })
  }
}

/**
 * 详情式导航栏：固定宽度返回区 + 居中标题 + 固定宽度右侧区（菜单/归档等）。
 */
@Component
export struct MedicalDetailPageHeaderChrome {
  title: string = '';
  titleFontSize: number = 17;
  showDivider: boolean = true;
  onBack?: () => void;
  @BuilderParam trailing: () => void = medicalListPageDefaultDetailTrailingBuilder;
  @BuilderParam body: () => void = medicalListPageEmptyBuilder;

  build() {
    Column({ space: 0 }) {
      Row() {
        Text('‹ 返回')
          .fontSize(16)
          .fontColor(MEDICAL_LIST_ACCENT)
          .width(64)
          .onClick(() => {
            if (this.onBack) {
              this.onBack();
            }
          })
        Text(this.title)
          .fontSize(this.titleFontSize)
          .fontWeight(FontWeight.Medium)
          .fontColor('#1C1C1E')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
        Row() {
          this.trailing()
        }
        .width(64)
        .justifyContent(FlexAlign.End)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 8 })

      this.body()

      if (this.showDivider) {
        Divider()
          .width('100%')
          .height(0.5)
          .color(MEDICAL_LIST_DIVIDER)
      }
    }
    .width('100%')
    .backgroundColor(MEDICAL_LIST_HEADER_BG)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])
  }
}

/** 头部内统一搜索框样式（灰底圆角，置于白底头部内）。 */
@Component
export struct MedicalListPageSearchField {
  placeholder: string = '';
  @Prop value: string = '';
  onValueChange?: (text: string) => void;

  build() {
    TextInput({ text: this.value, placeholder: this.placeholder })
      .height(36)
      .fontSize(14)
      .backgroundColor(MEDICAL_LIST_SEARCH_FIELD_BG)
      .borderRadius(10)
      .padding({ left: 12, right: 12 })
      .margin({ left: 16, right: 16, bottom: 8 })
      .onChange((text: string) => {
        this.onValueChange?.(text);
      })
  }
}

/** 底部操作区：白底延伸至底部安全区。 */
@Component
export struct MedicalListPageBottomChrome {
  showTopDivider: boolean = true;
  @BuilderParam body: () => void = medicalListPageEmptyBuilder;

  build() {
    Column({ space: 0 }) {
      if (this.showTopDivider) {
        Divider()
          .width('100%')
          .height(0.5)
          .color(MEDICAL_LIST_DIVIDER)
      }
      this.body()
    }
    .width('100%')
    .backgroundColor(MEDICAL_LIST_HEADER_BG)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
  }
}
