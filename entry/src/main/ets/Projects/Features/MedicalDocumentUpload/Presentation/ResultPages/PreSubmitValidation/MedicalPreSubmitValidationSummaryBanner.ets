import { MedicalPreSubmitValidationIssue } from '../../../Domain/MedicalPreSubmitValidationIssue';

/**
 * 预提交问题摘要横幅。对齐 iOS MedicalPreSubmitValidationSummaryBanner。
 */
@Component
export struct MedicalPreSubmitValidationSummaryBanner {
  @Prop issueLines: string[] = [];
  @Prop maxVisible: number = 5;
  onIssueTap: (index: number) => void = (_index: number) => {};

  private visibleLines(): string[] {
    if (this.issueLines.length <= this.maxVisible) {
      return this.issueLines;
    }
    return this.issueLines.slice(0, this.maxVisible);
  }

  build() {
    if (this.issueLines.length === 0) {
      Column() {}
    } else {
      Column({ space: 8 }) {
        Text(`保存前校验未通过（${this.issueLines.length}）`)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor('#C93400')
          .width('100%')
        ForEach(this.visibleLines(), (line: string, index: number) => {
          Text(`${index + 1}. ${line}`)
            .fontSize(13)
            .fontColor('#C93400')
            .width('100%')
            .onClick(() => this.onIssueTap(index))
        }, (line: string, index: number): string => `banner-${index}-${line}`)
        if (this.issueLines.length > this.maxVisible) {
          Text(`还有 ${this.issueLines.length - this.maxVisible} 项…`)
            .fontSize(12)
            .fontColor('#8E8E93')
            .width('100%')
        }
      }
      .width('100%')
      .padding(14)
      .backgroundColor('#FFF5F2')
      .borderRadius(12)
      .border({ width: 1, color: '#FFD0C2' })
    }
  }
}

export class MedicalPreSubmitValidationSummaryBannerHelper {
  static lines(issues: MedicalPreSubmitValidationIssue[]): string[] {
    return issues.map((issue: MedicalPreSubmitValidationIssue): string => issue.summaryLine());
  }
}
