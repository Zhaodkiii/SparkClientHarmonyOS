import { MedicalUploadL10n } from '../Domain/SupportingModels';

/**
 * Typed 抽取结果页：承接结构化草稿与预提交问题列表。
 */
@Component
export struct MedicalDocumentTypedResultPage {
  @Prop typedOutputJson: string = '';
  @Prop typeLabel: string = '';
  @Prop ocrPreview: string = '';
  @Prop resultTitle: string = '';
  @Prop resultSummary: string = '';
  @Prop warningText: string = '';
  @Prop payloadPreview: string = '';
  @Prop hasExtractedJson: boolean = false;
  /** 预提交校验问题摘要行（已格式化）。 */
  @Prop validationIssueLines: string[] = [];
  @Prop canAttemptSave: boolean = false;
  onReturnPicking: () => void = () => {};
  onAttemptSave: () => void = () => {};

  build() {
    Scroll() {
      Column({ space: 14 }) {
        Text(this.hasExtractedJson ?
          '识别结果待确认' : MedicalUploadL10n.text('medical.upload.result.pending'))
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor('#1C1C1E')
          .width('100%')

        if (this.typeLabel.length > 0) {
          Text(`识别类型：${this.typeLabel}`)
            .fontSize(15)
            .fontColor('#1C1C1E')
            .width('100%')
        }

        if (this.resultTitle.length > 0) {
          Text(this.resultTitle)
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor('#1C1C1E')
            .width('100%')
        }

        if (this.resultSummary.length > 0) {
          Text(this.resultSummary)
            .fontSize(14)
            .fontColor('#3C3C43')
            .width('100%')
        }

        if (this.validationIssueLines.length > 0) {
          Text('保存前校验未通过')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor('#C93400')
            .width('100%')
            .margin({ top: 4 })
          ForEach(this.validationIssueLines, (line: string, index: number) => {
            Text(`${index + 1}. ${line}`)
              .fontSize(13)
              .fontColor('#C93400')
              .width('100%')
          }, (line: string, index: number): string => `${index}-${line}`)
        } else if (this.warningText.length > 0) {
          Text(`待完善字段：${this.warningText}`)
            .fontSize(13)
            .fontColor('#C93400')
            .width('100%')
        }

        if (this.hasExtractedJson) {
          Text('结构化 JSON')
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor('#8E8E93')
            .width('100%')
            .margin({ top: 8 })
          Text(this.payloadPreview.length > 0 ? this.payloadPreview : this.typedOutputJson)
            .fontSize(12)
            .fontColor('#636366')
            .width('100%')
        } else if (this.ocrPreview.length > 0) {
          Text(this.ocrPreview.substring(0, 600) + (this.ocrPreview.length > 600 ? '…' : ''))
            .fontSize(13)
            .fontColor('#8E8E93')
            .width('100%')
        }

        Row({ space: 12 }) {
          Button(MedicalUploadL10n.text('medical.upload.action.return_picking'))
            .layoutWeight(1)
            .height(44)
            .fontColor('#333333')
            .backgroundColor('#E9E9ED')
            .onClick(() => this.onReturnPicking())
          if (this.canAttemptSave) {
            Button('校验并保存')
              .layoutWeight(1)
              .height(44)
              .fontColor(Color.White)
              .backgroundColor('#0A84FF')
              .onClick(() => this.onAttemptSave())
          }
        }
        .width('100%')
        .margin({ top: 12 })
      }
      .width('100%')
      .padding({ left: 24, right: 24, bottom: 32 })
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
  }
}
