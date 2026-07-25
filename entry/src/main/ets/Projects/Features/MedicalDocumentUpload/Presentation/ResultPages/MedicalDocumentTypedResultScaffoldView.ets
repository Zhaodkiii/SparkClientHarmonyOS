import { MedicalDocumentUploadViewModel } from '../MedicalDocumentUploadViewModel';
import {
  MedicalDocumentResultActionBar,
  MedicalDocumentResultAttachmentsSection,
  MedicalDocumentResultChromeHelper,
  MedicalDocumentResultMemberBar
} from './MedicalDocumentResultSupport';
import { MedicalPreSubmitValidationNavigation } from './PreSubmitValidation/MedicalPreSubmitValidationNavigation';
import { MedicalPreSubmitValidationSummaryBanner } from './PreSubmitValidation/MedicalPreSubmitValidationSummaryBanner';

/**
 * 各类型识别结果页统一壳层：标题、横幅、成员、正文、附件、底部操作。
 * 对齐 iOS 结果页共用 scaffold 职责（0011 抽象）。
 */
@Component
export struct MedicalDocumentTypedResultScaffoldView {
  @ObjectLink viewModel: MedicalDocumentUploadViewModel;
  @Prop pageTitle: string = '';
  @Prop pageSubtitle: string = '';
  @Prop kindLabel: string = '';
  @Prop showMemberBar: boolean = true;
  @Prop showSourceAttachmentsSection: boolean = true;
  @BuilderParam body: () => void = this.emptyBody;
  private scroller: Scroller = new Scroller();

  @Builder
  emptyBody() {
  }

  private onBannerTap(index: number): void {
    MedicalPreSubmitValidationNavigation.reveal(this.viewModel, index, this.scroller);
  }

  build() {
    Column() {
      Scroll(this.scroller) {
        Column({ space: 14 }) {
          if (this.pageTitle.length > 0) {
            Text(this.pageTitle)
              .fontSize(20)
              .fontWeight(FontWeight.Medium)
              .fontColor('#1C1C1E')
              .width('100%')
          }
          if (this.pageSubtitle.length > 0) {
            Text(this.pageSubtitle)
              .fontSize(13)
              .fontColor('#8E8E93')
              .width('100%')
          }

          MedicalPreSubmitValidationSummaryBanner({
            issueLines: this.viewModel.preSubmitValidationIssueLines(),
            onIssueTap: (index: number) => this.onBannerTap(index)
          })

          if (this.showMemberBar) {
            MedicalDocumentResultMemberBar({
              memberName: this.viewModel.selectedMemberName,
              memberId: this.viewModel.selectedMemberID,
              kindLabel: this.kindLabel
            })
          }

          this.body()

          if (this.showSourceAttachmentsSection) {
            MedicalDocumentResultAttachmentsSection({
              fileNames: MedicalDocumentResultChromeHelper.fileNames(this.viewModel.selectedFiles)
            })
          }
        }
        .width('100%')
        .padding({ left: 16, right: 16, bottom: 24 })
        .alignItems(HorizontalAlign.Start)
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)

      MedicalDocumentResultActionBar({
        canSave: this.viewModel.canAttemptSave,
        isSaving: this.viewModel.isSaving,
        onReturnPicking: () => this.viewModel.returnToPickingPreservingFiles(),
        onSave: () => {
          this.viewModel.attemptSave();
        }
      })
        .padding({ left: 16, right: 16, bottom: 16 })
    }
    .width('100%')
    .height('100%')
  }
}
