import { MedicalDocumentUploadStage } from '../Domain/MedicalDocumentUploadModels';
import { MedicalDocumentUploadPickingView } from './MedicalDocumentUploadPickingView';
import { MedicalDocumentUploadProgressView } from './MedicalDocumentUploadProgressView';
import { MedicalDocumentResultRouterView } from './ResultPages/MedicalDocumentResultRouterView';
import { MedicalDocumentUploadViewModel } from './MedicalDocumentUploadViewModel';
import { Logger } from '../../../../Foundation/Logging/Logger';
import { LogFields } from '../../../../Foundation/Logging/LogEvent';
import { LogModule } from '../../../../Foundation/Logging/LogModule';
import { AppNotificationHost } from '../../../../App/Notification/AppNotificationHost';
import {
  ExaminationReportDetailMode,
  ExaminationReportDetailPage
} from '../../Home/Presentation/MedicalLists/ExaminationReports/ExaminationReportDetailPage';
import {
  MedicalReportCardDetailTarget,
  MedicalReportResultSupport
} from './ResultPages/MedicalReportRecognitionResult/MedicalReportResultSupport';
import { MedicalReportRecognitionResultRoutes } from
  './ResultPages/MedicalReportRecognitionResult/MedicalReportRecognitionResultRoutes';
import { MedicalReportRecognitionDraft } from '../Domain/MedicalDocumentRecognitionDrafts';

/**
 * 病历上传根容器。对齐参考包 / iOS `MedicalDocumentUploadHostView`：
 * picking → processing（进度/手选类型）→ result。
 * 统一 Navigation 推栈：对齐 iOS 同一个 NavigationStack —— 栈根承载 picking/processing/result
 *（自绘 “×/AI 上传报告” 头部），报告卡片详情作为 push 目标；推入后系统 Navigation 会整屏顶掉栈根内容
 *（含头部），因此详情页自身头部（‹ 返回/编辑/删除）不会再与宿主头部叠加出现双头部。
 * ContentCover 内用 Stack，避免 Column.layoutWeight 把正文压成 0 高。
 * 内嵌 AppNotificationHost，保证全屏 Cover 上仍可见统一 banner。
 */
@Component
export struct MedicalDocumentUploadHostView {
  @ObjectLink viewModel: MedicalDocumentUploadViewModel;
  @StorageProp('topRectHeight') private topRectHeightPx: number = 0;
  onClose: () => void = () => {};

  /** 宿主统一导航栈：栈根 = 上传流程；push 目标 = 报告卡片本地草稿详情。 */
  private hostStack: NavPathStack = new NavPathStack();

  aboutToAppear(): void {
    const fields = new LogFields();
    fields.operation = 'medical_upload_host_view';
    fields.detail = `stage=${this.viewModel.stage};member=${this.viewModel.selectedMemberID};` +
      `files=${this.viewModel.selectedFiles.length};` +
      `ocr=${this.viewModel.capabilities.ocr};save=${this.viewModel.capabilities.save}`;
    Logger.info('medical.upload.host_view.appeared', LogModule.HOME, fields);
    this.viewModel.onDismissRequested = (): void => this.closeUploadPage();
    this.viewModel.medicalUploadNavStack = this.hostStack;
    // 打开上传页后后台预热系统 OCR，缩短点击识别时的 init 等待。
    this.viewModel.prewarmOCR('host_appeared');
  }

  aboutToDisappear(): void {
    this.viewModel.releaseOCRSession('host_disappeared');
  }

  private topSafeInset(): number {
    return this.topRectHeightPx > 0 ? this.getUIContext().px2vp(this.topRectHeightPx) : 24;
  }

  private closeUploadPage(): void {
    const fields = new LogFields();
    fields.operation = 'medical_upload_host_close';
    fields.detail = `stage=${this.viewModel.stage}`;
    Logger.info('medical.upload.host.close_tap', LogModule.HOME, fields);
    // 由 HomeTab onClose 统一 dismiss + 关闭 ContentCover，避免重复 reset。
    this.onClose();
  }

  private detailTarget(): MedicalReportCardDetailTarget | undefined {
    return this.viewModel.medicalReportCardDetailTarget;
  }

  private popDetail(): void {
    this.viewModel.clearMedicalReportCardDetail();
    if (this.hostStack.size() > 0) {
      this.hostStack.pop();
    }
  }

  @Builder
  private pageMap(name: string) {
    NavDestination() {
      if (name === MedicalReportRecognitionResultRoutes.LOCAL_DRAFT_DETAIL) {
        this.LocalDraftDetailPage()
      }
    }
    .hideTitleBar(true)
    .onBackPressed(() => {
      // 系统手势/返回键先清空导航目标，再走默认 pop，避免与 popDetail() 重复 pop。
      this.viewModel.clearMedicalReportCardDetail();
      return false;
    })
  }

  @Builder
  private LocalDraftDetailPage() {
    if (this.detailTarget()) {
      ExaminationReportDetailPage({
        detailMode: ExaminationReportDetailMode.LOCAL_DRAFT,
        initialReport: MedicalReportResultSupport.remoteReportForCard(
          this.viewModel,
          this.detailTarget()!.index
        ),
        sourceReportDraft: MedicalReportResultSupport.draftForCard(
          this.viewModel,
          this.detailTarget()!.index
        ),
        useReportCategory: true,
        reportCategory: this.detailTarget()!.category,
        localAttachmentNames: MedicalReportResultSupport.localAttachmentNamesForCard(
          this.viewModel,
          this.detailTarget()!.index
        ),
        onBack: () => {
          this.popDetail();
        },
        onLocalDraftSaved: (draft: MedicalReportRecognitionDraft) => {
          MedicalReportResultSupport.updateReportDraftAt(
            this.viewModel,
            this.detailTarget()!.index,
            draft
          );
        },
        onLocalDraftDeleted: () => {
          MedicalReportResultSupport.deleteReport(this.viewModel, this.detailTarget()!.index);
          this.popDetail();
        }
      })
    }
  }

  build() {
    Navigation(this.hostStack) {
      Stack({ alignContent: Alignment.TopStart }) {
        if (this.viewModel.stage === MedicalDocumentUploadStage.PICKING) {
          MedicalDocumentUploadPickingView({ viewModel: this.viewModel })
            .width('100%')
            .height('100%')
            .padding({ top: this.topSafeInset() + 54 })
        } else if (this.viewModel.stage === MedicalDocumentUploadStage.PROCESSING) {
          MedicalDocumentUploadProgressView({ viewModel: this.viewModel })
            .width('100%')
            .height('100%')
        } else {
          this.ResultBody()
        }

        // 通知层在标题栏下方；空白区域必须穿透，否则会挡住左上角关闭。
        Column() {
          AppNotificationHost()
        }
        .width('100%')
        .padding({ top: this.topSafeInset() + 48 })
        .zIndex(20)
        .hitTestBehavior(HitTestMode.Transparent)

        this.CustomTitleBar()
      }
      .width('100%')
      .height('100%')
    }
    .width('100%')
    .height('100%')
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    .backgroundColor('#F2F2F7')
    .hideTitleBar(true)
    .mode(NavigationMode.Stack)
    .navDestination(this.pageMap)
  }

  @Builder
  private CustomTitleBar() {
    Row() {
      Text('×')
        .width(44)
        .height(44)
        .fontSize(28)
        .fontColor('#333333')
        .textAlign(TextAlign.Center)
        .onClick(() => this.closeUploadPage())
      Text(this.viewModel.hostBarTitle())
        .layoutWeight(1)
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .textAlign(TextAlign.Center)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      Blank().width(44)
    }
    .width('100%')
    .padding({ top: this.topSafeInset(), left: 16, right: 16, bottom: 10 })
    .backgroundColor(Color.White)
    // 高于通知层，保证关闭按钮始终可点。
    .zIndex(30)
  }

  @Builder
  private ResultBody() {
    Column() {
      MedicalDocumentResultRouterView({ viewModel: this.viewModel })
    }
    .width('100%')
    .height('100%')
    .padding({ top: this.topSafeInset() + 54 })
  }
}
