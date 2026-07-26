import { AppContainer } from '../../App/AppContainer';
import { appRouter } from '../../App/Navigation/AppRouter';
import { Member } from '../Core/Domain/Entities/Member';
import { MedicalCard, MedicalCardKind } from '../Features/Home/Domain/HomeDashboard';
import { HomeMedicalRoutes } from '../Features/Home/Presentation/HomeMedicalRoutes';
import { HomeSetupFlowHolder } from '../Features/Home/Presentation/HomeSetupFlowHolder';
import { HomeViewModel } from '../Features/Home/Presentation/HomeViewModel';
import { MedicalInfoSection } from '../Features/Home/Presentation/MedicalInfoSection';
import { MedicalDocumentUploadEntryFactory } from '../Features/MedicalDocumentUpload/Application/MedicalDocumentUploadEntryFactory';
import { MedicalDocumentKind } from '../Features/MedicalDocumentUpload/Domain/MedicalDocumentKind';
import { MedicalUploadLocalFile } from '../Features/MedicalDocumentUpload/Domain/MedicalDocumentUploadModels';
import {
  medicalDocumentUploadStartBridge
} from '../Features/MedicalDocumentUpload/Presentation/MedicalDocumentUploadStartBridge';
import { MedicalDocumentUploadHostView } from '../Features/MedicalDocumentUpload/Presentation/MedicalDocumentUploadHostView';
import { MedicalDocumentUploadViewModel } from '../Features/MedicalDocumentUpload/Presentation/MedicalDocumentUploadViewModel';
import { MemberDetailPage } from '../Features/Home/Presentation/Members/MemberDetailPage';
import { MemberEditorPage } from '../Features/Home/Presentation/Members/MemberEditorPage';
import { ManageHomeMemberUseCase } from '../Features/Home/Application/ManageHomeMemberUseCase';
import { Logger } from '../../Foundation/Logging/Logger';
import { LogFields } from '../../Foundation/Logging/LogEvent';
import { LogModule } from '../../Foundation/Logging/LogModule';
import { promptAction } from '@kit.ArkUI';

/** 首页全屏 Cover 类型。同一节点仅挂一个 bindContentCover，成员详情与 AI 上传统一由此承载。 */
enum HomeTabOverlay {
  NONE = 'none',
  MEMBER_DETAIL = 'memberDetail',
  MEDICAL_UPLOAD = 'medicalUpload'
}

/** 首页 Tab 根内容；二级页经 appRouter 压入根栈，跳转后隐藏底部 Tab。 */
@Component
export struct HomeTabPage {
  private vm?: HomeViewModel;
  private memberUseCase?: ManageHomeMemberUseCase;
  @State private memberDetailTarget: Member | undefined = undefined;
  @State private memberEditorTarget: Member | undefined = undefined;
  @State private ready: boolean = false;
  @State private tick: number = 0;
  @State private isLoading: boolean = false;
  @State private isLoadingMedical: boolean = false;
  @State private members: Member[] = [];
  @State private selectedMemberID: number = 0;
  @State private selectedMemberName: string = '';
  @State private cards: MedicalCard[] = [];
  @State private showMedical: boolean = false;
  @State private showModuleMaintenance: boolean = false;
  @State private showMemberEditorSheet: boolean = false;
  @State private isMemberEditorCreate: boolean = true;
  @State private showHomeOverlayCover: boolean = false;
  @State private activeHomeOverlay: HomeTabOverlay = HomeTabOverlay.NONE;
  @State private medicalUploadReady: boolean = false;
  @State private refreshing: boolean = false;
  @State private medicalUploadVm: MedicalDocumentUploadViewModel | undefined = undefined;

  aboutToAppear(): void {
    const container = AppContainer.shared();
    if (!container) {
      return;
    }
    this.vm = container.createHomeViewModel();
    this.ensureMedicalUploadViewModel();
    medicalDocumentUploadStartBridge.bind((files: MedicalUploadLocalFile[], kind: MedicalDocumentKind): void => {
      this.startMedicalDocumentRecognitionFromList(files, kind);
    });
    this.vm.setOnChanged(() => {
      this.syncFromViewModel();
    });
    this.ready = true;
    this.vm.loadInitialIfNeeded(true);
  }

  private syncFromViewModel(): void {
    const vm = this.vm;
    if (!vm) {
      return;
    }
    this.isLoading = vm.isLoading;
    this.isLoadingMedical = vm.isLoadingMedical;
    this.members = vm.membersForUi();
    this.selectedMemberID = vm.selectedMemberID ?? 0;
    this.selectedMemberName = vm.dashboard?.selectedMember?.name ?? '';
    this.cards = vm.cardsForUi();
    this.showMedical = vm.shouldShowMedicalSection;
    this.showModuleMaintenance = vm.shouldShowModuleMaintenanceSection;
    this.tick += 1;
  }

  private openFamilyMedicineCabinet(): void {
    if (this.selectedMemberID <= 0) {
      return;
    }
    appRouter.jumpPage(HomeMedicalRoutes.FAMILY_CABINET);
  }

  private openMedicalAIReport(): void {
    // 对齐 iOS HomeView.fullScreenCover + presentUploadPage()。
    const openFields = new LogFields();
    openFields.operation = 'medical_upload_entry';
    openFields.detail =
      `ready=${this.medicalUploadReady};hasVm=${this.medicalUploadVm !== undefined};` +
      `cover=${this.showHomeOverlayCover}`;
    Logger.info('medical.upload.home.open_tap', LogModule.HOME, openFields);

    const vm = this.ensureMedicalUploadViewModel();
    if (!vm) {
      const missFields = new LogFields();
      missFields.operation = 'medical_upload_entry';
      missFields.detail = 'AppContainer.shared() missing or upload VM create failed';
      Logger.error('medical.upload.home.open_failed', LogModule.HOME, missFields);
      promptAction.showToast({ message: '上传模块暂不可用，请稍后重试' });
      return;
    }
    const entry = MedicalDocumentUploadEntryFactory.home(
      this.selectedMemberID,
      this.selectedMemberName
    );
    vm.prepareForEntry(entry);
    this.openHomeOverlay(HomeTabOverlay.MEDICAL_UPLOAD);

    const okFields = new LogFields();
    okFields.operation = 'medical_upload_entry';
    okFields.detail =
      `memberID=${vm.selectedMemberID};files=${vm.selectedFiles.length};` +
      `source=${entry.source};stage=${vm.stage};cover=true;` +
      `ocrCap=${vm.capabilities.ocr}`;
    Logger.info('medical.upload.home.open_ok', LogModule.HOME, okFields);
    // 打开上传页后立即后台预热 OCR（与 Host aboutToAppear 互相去重）。
    vm.prewarmOCR('upload_open');
  }

  private startMedicalDocumentRecognitionFromList(
    files: MedicalUploadLocalFile[],
    kind: MedicalDocumentKind
  ): void {
    if (files.length === 0) {
      promptAction.showToast({ message: '请先选择文件' });
      return;
    }
    const vm = this.ensureMedicalUploadViewModel();
    if (!vm) {
      promptAction.showToast({ message: '上传模块暂不可用，请稍后重试' });
      return;
    }
    vm.prepareAndStart(
      files.map((file: MedicalUploadLocalFile) => file.toAttachment()),
      kind
    );
    this.openHomeOverlay(HomeTabOverlay.MEDICAL_UPLOAD);
  }

  private openHomeOverlay(overlay: HomeTabOverlay): void {
    this.activeHomeOverlay = overlay;
    this.showHomeOverlayCover = true;
  }

  private dismissHomeOverlay(): void {
    this.showHomeOverlayCover = false;
  }

  private clearHomeOverlay(): void {
    this.activeHomeOverlay = HomeTabOverlay.NONE;
  }

  /**
   * 上传页通过 fullScreenCover 展示，但依赖必须在点击时也能完成装配。
   * 避免 aboutToAppear 时容器尚未完成初始化导致入口永久失效。
   */
  private ensureMedicalUploadViewModel(): MedicalDocumentUploadViewModel | undefined {
    if (this.medicalUploadVm) {
      return this.medicalUploadVm;
    }
    const container = AppContainer.shared();
    if (!container) {
      return undefined;
    }
    this.medicalUploadVm = container.createMedicalDocumentUploadViewModel();
    this.medicalUploadReady = true;
    // 不在 VM 变更时重建 ContentCover；上传页通过 @ObjectLink 观察同一个 ViewModel。
    // 重建全屏 Cover 会触发 Host appeared→disappeared，并可能丢失正在选择的文件。
    return this.medicalUploadVm;
  }

  @Builder
  private homeOverlayCoverBuilder() {
    if (this.activeHomeOverlay === HomeTabOverlay.MEMBER_DETAIL && this.memberDetailTarget) {
      MemberDetailPage({
        member: this.memberDetailTarget,
        memberUseCase: this.memberUseCase,
        onClose: () => {
          this.dismissHomeOverlay();
        },
        onEdit: () => {
          this.dismissHomeOverlay();
          if (this.memberDetailTarget) {
            this.openMemberEditor(this.memberDetailTarget);
          }
        },
        onMaintainModules: () => {
          if (this.memberDetailTarget) {
            this.dismissHomeOverlay();
            this.openMaintainModulesFor(this.memberDetailTarget);
          }
        },
        onDeleted: () => {
          this.handleMemberDeleted();
        }
      })
        .width('100%')
        .height('100%')
    } else if (this.activeHomeOverlay === HomeTabOverlay.MEDICAL_UPLOAD) {
      if (this.medicalUploadReady && this.medicalUploadVm) {
        MedicalDocumentUploadHostView({
          viewModel: this.medicalUploadVm,
          onClose: () => {
            Logger.info('medical.upload.home.cover_close', LogModule.HOME);
            this.medicalUploadVm?.dismiss();
            this.dismissHomeOverlay();
          }
        })
          .width('100%')
          .height('100%')
      } else {
        Text('上传模块未装配')
          .width('100%')
          .height('100%')
          .fontSize(14)
          .fontColor('#888888')
          .textAlign(TextAlign.Center)
      }
    }
  }

  private async onPullRefresh(): Promise<void> {
    if (this.refreshing || this.isLoading || this.isLoadingMedical) {
      this.refreshing = false;
      return;
    }
    this.refreshing = true;
    try {
      await this.vm?.refresh();
    } finally {
      this.refreshing = false;
    }
  }

  private openMedicalList(kind: MedicalCardKind): void {
    const route = HomeMedicalRoutes.fromCardKind(kind);
    this.vm?.logMedicalListNavigation(kind);
    appRouter.jumpPage(route);
  }

  private memberUseCaseForPage(): ManageHomeMemberUseCase | undefined {
    const container = AppContainer.shared();
    if (!container) {
      return undefined;
    }
    if (!this.memberUseCase) {
      this.memberUseCase = new ManageHomeMemberUseCase(container.backend.medicalMember);
    }
    return this.memberUseCase;
  }

  private openCreateMember(): void {
    this.memberEditorTarget = undefined;
    this.isMemberEditorCreate = true;
    this.memberUseCaseForPage();
    this.showMemberEditorSheet = true;
  }

  private openMemberDetail(member: Member): void {
    const fields = new LogFields();
    fields.code = member.id;
    fields.operation = 'open_member_detail';
    fields.detail = `before target=${this.memberDetailTarget?.id ?? 'none'}, cover=${this.showHomeOverlayCover}`;
    Logger.info('member.detail.open_requested', LogModule.HOME, fields);
    this.memberDetailTarget = member;
    this.memberUseCaseForPage();
    this.openHomeOverlay(HomeTabOverlay.MEMBER_DETAIL);
    const stateFields = new LogFields();
    stateFields.code = member.id;
    stateFields.operation = 'open_member_detail';
    stateFields.detail = `after target=${this.memberDetailTarget?.id ?? 'none'}, cover=${this.showHomeOverlayCover}, useCase=${this.memberUseCase !== undefined}`;
    Logger.info('member.detail.state_updated', LogModule.HOME, stateFields);
  }

  private openMemberAction(member: Member): void {
    const fields = new LogFields();
    fields.code = member.id;
    fields.operation = 'show_member_action_dialog';
    fields.detail = `nameLength=${member.name.length}`;
    Logger.info('member.action.dialog_requested', LogModule.HOME, fields);
    promptAction.showDialog({
      title: member.name.length > 0 ? member.name : '成员操作',
      message: '可查看成员资料、编辑档案或维护健康模块。',
      buttons: [{ text: '取消', color: '#0A84FF' }, { text: '查看详情', color: '#0A84FF' }]
    }).then((result) => {
      const resultFields = new LogFields();
      resultFields.code = member.id;
      resultFields.operation = 'show_member_action_dialog';
      resultFields.detail = `buttonIndex=${result.index}`;
      Logger.info('member.action.dialog_result', LogModule.HOME, resultFields);
      if (result.index === 1) {
        this.openMemberDetail(member);
      }
    }).catch((error: Object) => {
      const errorFields = new LogFields();
      errorFields.code = member.id;
      errorFields.operation = 'show_member_action_dialog';
      errorFields.detail = `error=${String(error)}`;
      Logger.error('member.action.dialog_failed', LogModule.HOME, errorFields);
    });
  }

  private openMemberEditor(member: Member): void {
    this.memberEditorTarget = member;
    this.isMemberEditorCreate = false;
    this.memberUseCaseForPage();
    this.showMemberEditorSheet = true;
  }

  private async handleMemberSaved(member: Member): Promise<void> {
    const homeVm = this.vm;
    if (!homeVm) return;
    this.memberDetailTarget = member;
    await homeVm.reloadMembers();
    await homeVm.selectMember(member.id);
    this.showMemberEditorSheet = false;
  }

  private async handleMemberDeleted(): Promise<void> {
    const homeVm = this.vm;
    if (!homeVm) return;
    this.memberDetailTarget = undefined;
    this.dismissHomeOverlay();
    await homeVm.refresh();
  }

  private openMaintainModules(): void {
    const container = AppContainer.shared();
    const homeVm = this.vm;
    if (!container || !homeVm) {
      return;
    }
    const members = homeVm.membersForUi();
    let target: Member | undefined = undefined;
    for (let i = 0; i < members.length; i++) {
      if (members[i].id === this.selectedMemberID) {
        target = members[i];
        break;
      }
    }
    if (!target) {
      return;
    }
    HomeSetupFlowHolder.set(container.createMemberSetupFlowViewModel('maintain', target));
    appRouter.jumpPage(HomeMedicalRoutes.MEMBER_SETUP_MAINTAIN);
  }

  private openMaintainModulesFor(member: Member): void {
    const container = AppContainer.shared();
    if (!container) return;
    HomeSetupFlowHolder.set(container.createMemberSetupFlowViewModel('maintain', member));
    appRouter.jumpPage(HomeMedicalRoutes.MEMBER_SETUP_MAINTAIN);
  }

  @Builder
  memberEditorSheetBuilder() {
    if (this.isMemberEditorCreate) {
      MemberEditorPage({
        mode: 'create',
        memberUseCase: this.memberUseCase,
        onClose: () => this.showMemberEditorSheet = false,
        onSaved: (member: Member) => this.handleMemberSaved(member)
      })
    } else if (this.memberEditorTarget) {
      MemberEditorPage({
        mode: 'edit',
        member: this.memberEditorTarget,
        memberUseCase: this.memberUseCase,
        onClose: () => this.showMemberEditorSheet = false,
        onSaved: (member: Member) => this.handleMemberSaved(member)
      })
    }
  }

  @Builder
  memberChip(member: Member) {
    Row({ space: 8 }) {
      Text(member.name.length > 0 ? member.name.substring(0, 1) : '#')
        .fontSize(12)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.selectedMemberID === member.id ? '#0A84FF' : '#0A84FF')
        .width(28)
        .height(28)
        .textAlign(TextAlign.Center)
        .padding({ top: 7 })
        .backgroundColor(this.selectedMemberID === member.id ? '#DCEEFF' : '#EAF3FF')
        .borderRadius(14)
      Text(member.name.length > 0 ? member.name : `#${member.id}`)
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.selectedMemberID === member.id ? Color.White : '#1C1C1E')
        .maxLines(1)
      if (this.selectedMemberID === member.id) {
        Text('⋯').fontSize(16).fontColor(Color.White)
      }
    }
    .padding({ left: 10, right: 12, top: 7, bottom: 7 })
    .backgroundColor(this.selectedMemberID === member.id ? '#0A84FF' : '#F2F2F7')
    .borderRadius(22)
    .onClick(() => {
      if (this.selectedMemberID === member.id) {
        this.openMemberAction(member);
      } else {
        this.vm?.selectMember(member.id);
      }
    })
  }

  @Builder
  memberSelectorBar() {
    Row({ space: 8 }) {
      Scroll() {
        Row({ space: 12 }) {
          ForEach(this.members, (member: Member) => {
            this.memberChip(member)
          }, (member: Member): string => `${member.id}-${this.tick}`)
        }
        .padding({ left: 16, right: 8, top: 8, bottom: 8 })
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .layoutWeight(1)

      Text('+')
        .fontSize(22)
        .fontWeight(FontWeight.Medium)
        .fontColor('#1C1C1E')
        .width(40)
        .height(40)
        .textAlign(TextAlign.Center)
        .padding({ top: 6 })
        .backgroundColor('#F2F2F7')
        .borderRadius(20)
        .margin({ right: 16 })
        .onClick(() => this.openCreateMember())
    }
    .width('100%')
    .backgroundColor(Color.White)
  }

  @Builder
  homeRootContent() {
    if (!this.ready) {
      Text($r('app.string.home_loading'))
        .fontSize(16)
        .fontColor('#666666')
    } else {
      Column() {
        this.memberSelectorBar()
        Refresh({ refreshing: $$this.refreshing }) {
          Scroll() {
            Column({ space: 20 }) {
          Row() {
            Text($r('app.string.home_title'))
              .fontSize(22)
              .fontWeight(FontWeight.Bold)
              .layoutWeight(1)
            if (this.isLoading || this.isLoadingMedical) {
              LoadingProgress()
                .width(24)
                .height(24)
            } else {
              Text($r('app.string.home_refresh'))
                .fontSize(14)
                .fontColor('#0A84FF')
                .onClick(() => {
                  this.vm?.refresh();
                })
            }
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 8 })

          if (this.members.length === 0 && !this.isLoading) {
            Text($r('app.string.home_members_empty'))
              .fontSize(14)
              .fontColor('#888888')
              .width('100%')
              .padding({ left: 16, right: 16 })
          }

          if (this.members.length === 0 && !this.isLoading) {
            Button($r('app.string.home_members_add'))
              .margin({ left: 16, right: 16 })
              .onClick(() => {
                this.openCreateMember();
              })
          }

          if (this.selectedMemberName.length > 0) {
            Text(`${this.selectedMemberName}`)
              .fontSize(13)
              .fontColor('#666666')
              .width('100%')
              .padding({ left: 16, right: 16 })
          }

          if (this.showMedical) {
            MedicalInfoSection({
              cards: this.cards,
              selectedMemberID: this.selectedMemberID,
              revision: this.tick,
              homeVm: this.vm,
              onOpenFamilyCabinet: () => {
                this.openFamilyMedicineCabinet();
              },
              onOpenMedicalList: (kind: MedicalCardKind) => {
                this.openMedicalList(kind);
              },
              onAIReport: () => {
                this.openMedicalAIReport();
              }
            })
          }

          if (this.showModuleMaintenance) {
            Column({ space: 8 }) {
              Text($r('app.string.home_module_maintenance'))
                .fontSize(14)
                .fontColor('#888888')
                .width('100%')
              Text($r('app.string.home_module_maintenance_action'))
                .fontSize(14)
                .fontColor('#0A84FF')
                .onClick(() => {
                  this.openMaintainModules();
                })
            }
            .alignItems(HorizontalAlign.Start)
            .width('100%')
            .padding({ left: 16, right: 16 })
          }

          Blank().height(24)
        }
          .width('100%')
          .padding({ left: 16, right: 16, top: 12, bottom: 24 })
          }
          .layoutWeight(1)
          .scrollBar(BarState.Off)
          .edgeEffect(EdgeEffect.Spring)
        }
        .layoutWeight(1)
        .onRefreshing(() => {
          this.onPullRefresh();
        })
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#F2F2F7')
    }
  }

  build() {
    Stack() {
      // bindSheet 与 bindContentCover 不可挂在同一节点；Sheet 仅承载成员编辑。
      Stack() {
        this.homeRootContent()
      }
      .bindSheet($$this.showMemberEditorSheet, this.memberEditorSheetBuilder(), {
        height: SheetSize.LARGE,
        dragBar: true,
        showClose: false,
        backgroundColor: '#F7F7F8',
        onDisappear: () => {
          this.showMemberEditorSheet = false;
        }
      })
      .width('100%')
      .height('100%')
    }
    .bindContentCover($$this.showHomeOverlayCover, this.homeOverlayCoverBuilder(), {
      modalTransition: ModalTransition.DEFAULT,
      backgroundColor: '#F2F7F8',
      onDisappear: () => {
        this.clearHomeOverlay();
      }
    })
    .width('100%')
    .height('100%')
    .backgroundColor(Color.White)
  }
}
