import { MedicalCard, MedicalCardKind } from '../Domain/HomeDashboard';
import { HomeViewModel } from './HomeViewModel';
import { promptAction } from '@kit.ArkUI';

/**
 * 首页医疗信息板块：标题行 + 两列卡片网格 + AI 智能整理报告入口。
 * 对齐 iOS HomeView.medicalInfoSection / medicalCard / medicalAIReportButton。
 */
@Component
export struct MedicalInfoSection {
  @Prop cards: MedicalCard[] = [];
  @Prop selectedMemberID: number = 0;
  /** 驱动 ForEach 刷新键，与 HomeTabPage.tick 同步。 */
  @Prop revision: number = 0;
  homeVm?: HomeViewModel;
  onOpenFamilyCabinet: () => void = () => {
  };
  onOpenMedicalList: (kind: MedicalCardKind) => void = (_kind: MedicalCardKind) => {
  };
  onAIReport: () => void = () => {
  };

  private cardTitle(kind: MedicalCardKind): string {
    return this.homeVm?.cardTitle(kind) ?? '医疗';
  }

  private cardSubtitle(kind: MedicalCardKind): string {
    return this.homeVm?.cardSubtitle(kind) ?? '';
  }

  private formatLatest(latest?: string): string {
    if (!latest || latest.length === 0) {
      return '';
    }
    if (latest.length >= 10) {
      const y = latest.substring(0, 4);
      const m = parseInt(latest.substring(5, 7), 10);
      const d = parseInt(latest.substring(8, 10), 10);
      if (!isNaN(m) && !isNaN(d) && m > 0 && d > 0) {
        return `${y}年${m}月${d}日`;
      }
      return latest.substring(0, 10);
    }
    return latest;
  }

  private openAIReport(): void {
    // 页面本身负责展示“未选择成员”状态；入口不能静默吞掉点击事件。
    // 这样才能与 iOS fullScreenCover 的行为一致，并允许用户进入页面后完成上下文选择。
    this.onAIReport();
  }

  @Builder
  medicalCardIcon(card: MedicalCard) {
    // 符号语义对齐 iOS SF Symbol；仅使用工程内已验证可用的 sys.symbol
    if (card.id === MedicalCardKind.MEDICAL_CASES) {
      SymbolGlyph($r('sys.symbol.doc_text'))
        .fontSize(22)
        .fontColor(['#0A84FF'])
        .fontWeight(FontWeight.Medium)
    } else if (card.id === MedicalCardKind.HEALTH_EXAM_REPORTS) {
      SymbolGlyph($r('sys.symbol.checkmark_circle_fill'))
        .fontSize(22)
        .fontColor(['#0A84FF'])
        .fontWeight(FontWeight.Medium)
    } else if (card.id === MedicalCardKind.MEDICAL_REPORTS) {
      SymbolGlyph($r('sys.symbol.square_stack_3d'))
        .fontSize(22)
        .fontColor(['#0A84FF'])
        .fontWeight(FontWeight.Medium)
    } else {
      SymbolGlyph($r('sys.symbol.clock_fill'))
        .fontSize(22)
        .fontColor(['#0A84FF'])
        .fontWeight(FontWeight.Medium)
    }
  }

  @Builder
  medicalCard(card: MedicalCard) {
    Column({ space: 10 }) {
      this.medicalCardIcon(card)

      Text(this.cardTitle(card.id))
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor('#1C1C1E')
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Text(this.cardSubtitle(card.id))
        .fontSize(11)
        .fontColor('#8E8E93')
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Blank()

      Row() {
        Text(`${card.count}`)
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1C1C1E')

        Blank()

        if (card.latestDate && card.latestDate.length > 0) {
          Text(this.formatLatest(card.latestDate))
            .fontSize(11)
            .fontColor('#8E8E93')
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Bottom)
    }
    .width('100%')
    .constraintSize({ minHeight: 142 })
    .alignItems(HorizontalAlign.Start)
    .padding(16)
    .backgroundColor('#FFFFFF')
    .borderRadius(24)
    .border({ width: 1, color: '#D9D9DE' })
    .onClick(() => {
      this.onOpenMedicalList(card.id);
    })
  }

  @Builder
  medicalAIReportButton() {
    // 对齐 iOS：白底 + 蓝紫描边 + 蓝紫文案（sparkles）
    Row({ space: 6 }) {
      SymbolGlyph($r('sys.symbol.star_fill'))
        .fontSize(16)
        .fontColor(['#0A84FF'])
      Text($r('app.string.home_medical_ai_report'))
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor('#5856D6')
    }
    .width('100%')
    .justifyContent(FlexAlign.Center)
    .padding({ top: 12, bottom: 12 })
    .backgroundColor('#F2F2F7')
    .borderRadius(12)
    .border({
      width: 1,
      color: '#7B6CF0'
    })
    .opacity(1)
    .onClick(() => {
      this.openAIReport();
    })
  }

  build() {
    Column({ space: 12 }) {
      Row() {
        Row({ space: 6 }) {
          // 对齐 iOS cross.case：医疗箱语义，使用已验证系统符号
          SymbolGlyph($r('sys.symbol.doc_text'))
            .fontSize(18)
            .fontColor(['#1C1C1E'])
            .fontWeight(FontWeight.Medium)
          Text($r('app.string.home_medical_section'))
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .fontColor('#1C1C1E')
        }

        Blank()

        if (this.selectedMemberID > 0) {
          Row({ space: 4 }) {
            // 对齐 iOS cross.vial.fill：家庭药箱入口（系统符号近似）
            SymbolGlyph($r('sys.symbol.plus_circle_fill'))
              .fontSize(14)
              .fontColor(['#0A84FF'])
            Text($r('app.string.home_medical_family_cabinet'))
              .fontSize(12)
              .fontWeight(FontWeight.Medium)
              .fontColor('#0A84FF')
          }
          .padding({ left: 4, right: 2, top: 4, bottom: 4 })
          .onClick(() => {
            this.onOpenFamilyCabinet();
          })
        }
      }
      .width('100%')

      GridRow({ columns: 2, gutter: { x: 12, y: 12 } }) {
        ForEach(this.cards, (card: MedicalCard) => {
          GridCol() {
            this.medicalCard(card)
          }
        }, (card: MedicalCard): string => `${card.id}-${card.count}-${card.latestDate ?? ''}-${this.revision}`)
      }
      .width('100%')

      this.medicalAIReportButton()
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}

/** 上传页尚未落地时的默认 AI 入口行为。 */
export function showMedicalAIReportPlaceholder(): void {
  try {
    promptAction.showToast({ message: 'AI 智能整理报告即将开放', duration: 2000 });
  } catch (e) {
    // ignore toast failures
  }
}
