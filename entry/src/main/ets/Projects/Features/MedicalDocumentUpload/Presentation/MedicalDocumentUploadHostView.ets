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
  MEDICAL_LIST_PAGE_BG,
  MedicalUploadPageHeaderChrome
} from '../../Home/Presentation/MedicalLists/Shared/MedicalListPageChrome';
import {
  MedicalReportCardDetailTarget,
  MedicalReportResultSupport
} from './ResultPages/MedicalReportRecognitionResult/MedicalReportResultSupport';
import { MedicalReportRecognitionResultRoutes } from
  './ResultPages/MedicalReportRecognitionResult/MedicalReportRecognitionResultRoutes';
import { MedicalReportRecognitionDraft, MedicineBoxRecognitionDraft } from '../Domain/MedicalDocumentRecognitionDrafts';
import { MedicineBoxDetailMode } from '../../Home/Presentation/MedicalLists/MedicineBox/MedicineBoxDetailMode';
import { MedicineBoxDetailPage } from '../../Home/Presentation/MedicalLists/MedicineBox/MedicineBoxDetailPage';
import {
  MedicineBoxCardDetailTarget,
  MedicineBoxRecognitionResultRoutes
} from './ResultPages/MedicineBoxRecognitionResult/MedicineBoxRecognitionResultRoutes';
import { MedicineBoxRecognitionResultSupport } from
  './ResultPages/MedicineBoxRecognitionResult/MedicineBoxRecognitionResultSupport';

/**
 * 病历上传根容器。对齐参考包 / iOS `MedicalDocumentUploadHostView`：
 * picking → processing（进度/手选类型）→ result。
 * 统一 Navigation 推栈：对齐 iOS 同一个 NavigationStack —— 栈根承载 picking/processing/result
 *（自绘 “×/AI 上传报告” 头部），报告卡片详情作为 push 目标；推入后系统 Navigation 会整屏顶掉栈根内容
 *（含头部），因此详情页自身头部（‹ 返回/编辑/删除）不会再与宿主头部叠加出现双头部。
 * ContentCover 内用 Column 承载统一头部 + 正文，避免 Stack 叠层与 magic top padding。
 * 内嵌 AppNotificationHost，保证全屏 Cover 上仍可见统一 banner。
 */
@Component
export struct MedicalDocumentUploadHostView {
  @ObjectLink viewModel: MedicalDocumentUploadViewModel;
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

  private medicineBoxDetailTarget(): MedicineBoxCardDetailTarget | undefined {
    return this.viewModel.medicineBoxCardDetailTarget;
  }

  private popDetail(): void {
    this.viewModel.clearMedicalReportCardDetail();
    this.viewModel.clearMedicineBoxCardDetail();
    if (this.hostStack.size() > 0) {
      this.hostStack.pop();
    }
  }

  @Builder
  private pageMap(name: string) {
    NavDestination() {
      if (name === MedicalReportRecognitionResultRoutes.LOCAL_DRAFT_DETAIL) {
        this.MedicalReportLocalDraftDetailPage()
      } else if (name === MedicineBoxRecognitionResultRoutes.LOCAL_DRAFT_DETAIL) {
        this.MedicineBoxLocalDraftDetailPage()
      }
    }
    .hideTitleBar(true)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
    .onBackPressed(() => {
      // 系统手势/返回键先清空导航目标，再走默认 pop，避免与 popDetail() 重复 pop。
      this.viewModel.clearMedicalReportCardDetail();
      this.viewModel.clearMedicineBoxCardDetail();
      return false;
    })
  }

  @Builder
  private MedicalReportLocalDraftDetailPage() {
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

  @Builder
  private MedicineBoxLocalDraftDetailPage() {
    if (this.medicineBoxDetailTarget()) {
      MedicineBoxDetailPage({
        detailMode: MedicineBoxDetailMode.LOCAL_DRAFT,
        initialBox: MedicineBoxRecognitionResultSupport.remoteBoxForCard(
          this.viewModel,
          this.medicineBoxDetailTarget()!.index,
          this.viewModel.selectedMemberID
        ),
        entryMemberID: this.viewModel.selectedMemberID,
        memberOptions: this.viewModel.members(),
        allowsHouseholdPublic: false,
        sourceBoxDraft: MedicineBoxRecognitionResultSupport.draftForCard(
          this.viewModel,
          this.medicineBoxDetailTarget()!.index
        ),
        onBack: () => {
          this.popDetail();
        },
        onLocalDraftSaved: (draft: MedicineBoxRecognitionDraft) => {
          MedicineBoxRecognitionResultSupport.updateBoxDraftAt(
            this.viewModel,
            this.medicineBoxDetailTarget()!.index,
            draft
          );
        },
        onLocalDraftDeleted: () => {
          MedicineBoxRecognitionResultSupport.deleteBoxDraft(
            this.viewModel,
            this.medicineBoxDetailTarget()!.index
          );
          this.popDetail();
        }
      })
    }
  }

  @Builder
  private stageContent() {
    if (this.viewModel.stage === MedicalDocumentUploadStage.PICKING) {
      MedicalDocumentUploadPickingView({ viewModel: this.viewModel })
        .width('100%')
        .height('100%')
    } else if (this.viewModel.stage === MedicalDocumentUploadStage.PROCESSING) {
      MedicalDocumentUploadProgressView({ viewModel: this.viewModel })
        .width('100%')
        .height('100%')
    } else {
      MedicalDocumentResultRouterView({ viewModel: this.viewModel })
        .width('100%')
        .height('100%')
    }
  }

  build() {
    Navigation(this.hostStack) {
      Column() {
        MedicalUploadPageHeaderChrome({
          title: this.viewModel.hostBarTitle(),
          onLeading: () => {
            this.closeUploadPage();
          }
        })

        Stack({ alignContent: Alignment.TopStart }) {
          Column() {
            this.stageContent()
          }
          .width('100%')
          .height('100%')
          .justifyContent(FlexAlign.Start)

          Column() {
            AppNotificationHost()
          }
          .width('100%')
          .hitTestBehavior(HitTestMode.Transparent)
          .zIndex(20)
        }
        .layoutWeight(1)
        .width('100%')
        .alignContent(Alignment.TopStart)
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Start)
    }
    .width('100%')
    .height('100%')
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
    .backgroundColor(MEDICAL_LIST_PAGE_BG)
    .hideTitleBar(true)
    .mode(NavigationMode.Stack)
    .navDestination(this.pageMap)
  }
}
