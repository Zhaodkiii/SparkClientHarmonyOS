import { AppContainer } from '../../../../../App/AppContainer';
import { appRouter } from '../../../../../App/Navigation/AppRouter';
import { SparkMedicalQueryAPI } from '../../../../Core/Networking/API/Medical/MedicalQueryAPI';
import { RemoteMedicineBox } from '../../../../Core/Networking/API/Medical/MedicalSyncAPI';
import { SparkMedicalWorkflowAPI } from '../../../../Core/Networking/API/Medical/MedicalWorkflowAPI';
import { NotificationClient } from '../../../../Core/Notification/Application/NotificationClient';
import { FileTransferService } from '../../../../../Core/FileStorage/FileTransferService';
import { MedicalDocumentAttachmentUploader } from './MedicalDocumentAttachmentUploader';
import { MedicalArchiveListMode } from '../../../../Core/Networking/API/Medical/MedicalArchiveModels';
import { HomeMedicalRouteSupport } from '../HomeMedicalRouteSupport';
import { HomeMedicalRoutes } from '../HomeMedicalRoutes';
import { HomeViewModel } from '../HomeViewModel';
import { MedicineBoxMode } from './MedicineBox/MedicineBoxMode';
import { MedicineBoxFormModel } from './MedicineBox/MedicineBoxFormModel';
import {
  FamilyMedicineCabinetViewModel,
  MemberFilter
} from './MedicineBox/FamilyMedicineCabinetViewModel';
import { MedicineBoxMemberFilterBar } from './MedicineBox/MedicineBoxMemberFilterBar';
import { MedicineBoxTypeTabBar } from './MedicineBox/MedicineBoxTypeTabBar';
import { MedicineBoxGridView } from './MedicineBox/MedicineBoxGridView';
import { MedicineBoxFormPage } from './MedicineBox/MedicineBoxFormPage';
import { MedicineBoxDraftMapping } from './MedicineBox/MedicineBoxDraftMapping';
import { MedicineBoxTypeCatalog } from './MedicineBox/MedicineBoxTypeCatalog';
import { MedicalAttachmentUploadListSheet } from './Shared/MedicalAttachmentUploadListSheet';
import {
  medicalAttachmentUploadConfig,
  MedicalDocumentKind
} from '../../../MedicalDocumentUpload/Domain/MedicalDocumentKind';
import { MedicalUploadLocalFile } from '../../../MedicalDocumentUpload/Domain/MedicalDocumentUploadModels';
import {
  medicalDocumentUploadStartBridge
} from '../../../MedicalDocumentUpload/Presentation/MedicalDocumentUploadStartBridge';
import {
  MEDICAL_LIST_ACCENT,
  MEDICAL_LIST_DIVIDER,
  MEDICAL_LIST_HEADER_BG,
  MEDICAL_LIST_PAGE_BG,
  MEDICAL_LIST_SEARCH_FIELD_BG
} from './Shared/MedicalListPageChrome';

/** 家庭药箱列表底部：拍照添加药品（对齐 iOS 药箱 camera-only 底栏）。 */
@Component
struct FamilyMedicineCabinetBottomExtension {
  actionTitle: string = '拍照添加药品';
  tintColor: string = '#AF52DE';
  onUpload: () => void = () => {
  };

  build() {
    Text(this.actionTitle)
      .fontSize(15)
      .fontColor(Color.White)
      .width('100%')
      .textAlign(TextAlign.Center)
      .padding({ top: 14, bottom: 14 })
      .backgroundColor(this.tintColor)
      .borderRadius(12)
      .onClick(() => {
        this.onUpload();
      })
      .margin({ left: 16, right: 16, top: 12, bottom: 12 })
  }
}

/** 药箱拍照上传 Sheet。独立组件挂载，避免 bindSheet @Builder 内 this 错位。 */
@Component
struct FamilyMedicineCabinetUploadSheetContent {
  onCancel: () => void = () => {
  };
  onConfirm: (files: MedicalUploadLocalFile[]) => void = (_files: MedicalUploadLocalFile[]) => {
  };

  build() {
    MedicalAttachmentUploadListSheet({
      documentKind: MedicalDocumentKind.MEDICINE_BOX,
      onCancel: () => {
        this.onCancel();
      },
      onConfirm: (files: MedicalUploadLocalFile[]) => {
        this.onConfirm(files);
      }
    })
  }
}

/** 列表页弹层：新建表单 / 拍照上传。同一节点仅挂一个 bindSheet。 */
enum FamilyMedicineCabinetOverlay {
  NONE = 'none',
  FORM = 'form',
  UPLOAD = 'upload'
}

/** 家庭药箱头部搜索区。作为页面 build 子组件挂载，避免 @BuilderParam this 错位。 */
@Component
struct FamilyMedicineCabinetHeaderExtension {
  @Prop searchText: string = '';
  onSearchChange: (text: string) => void = (_text: string) => {
  };

  build() {
    TextInput({
      text: this.searchText,
      placeholder: '搜索药品名称、品牌、规格'
    })
      .height(36)
      .fontSize(14)
      .backgroundColor(MEDICAL_LIST_SEARCH_FIELD_BG)
      .borderRadius(10)
      .padding({ left: 12, right: 12 })
      .margin({ left: 16, right: 16, bottom: 8 })
      .onChange((value: string) => {
        this.onSearchChange(value);
      })
  }
}

/** 家庭药箱头部右侧操作区。独立组件挂载，避免 @BuilderParam this 错位。 */
@Component
struct FamilyMedicineCabinetHeaderTrailing {
  onOpenArchive: () => void = () => {};
  onOpenCreate: () => void = () => {};

  build() {
    Row({ space: 12 }) {
      Text('归档')
        .fontSize(13)
        .fontColor(MEDICAL_LIST_ACCENT)
        .onClick(() => {
          this.onOpenArchive();
        })
      SymbolGlyph($r('sys.symbol.plus'))
        .fontSize(22)
        .fontColor([MEDICAL_LIST_ACCENT])
        .onClick(() => {
          this.onOpenCreate();
        })
    }
  }
}

/**
 * 家庭/个人药箱统一页面（对齐 iOS FamilyMedicineCabinetPage）。
 * 通过 mode 区分家庭汇总与个人成员药箱；人员筛选仅家庭模式展示。
 */
@Component
export struct FamilyMedicineCabinetPage {
  homeVm?: HomeViewModel;
  onBack?: () => void;
  onOpenDetail?: () => void;
  @Prop entryMemberID: number = 0;
  @Prop mode: MedicineBoxMode = MedicineBoxMode.FAMILY;
  @Prop @Watch('onListRevisionChanged') listRevision: number = 0;

  @State private viewModel: FamilyMedicineCabinetViewModel =
    new FamilyMedicineCabinetViewModel(0, MedicineBoxMode.FAMILY, []);
  @State private refreshing: boolean = false;
  @State private formTarget?: RemoteMedicineBox = undefined;
  @State private showOverlaySheet: boolean = false;
  @State private activeOverlay: FamilyMedicineCabinetOverlay = FamilyMedicineCabinetOverlay.NONE;

  private query?: SparkMedicalQueryAPI;
  private workflow?: SparkMedicalWorkflowAPI;
  private notification?: NotificationClient;
  private fileTransfer?: FileTransferService;
  private attachmentUploader?: MedicalDocumentAttachmentUploader;

  aboutToAppear(): void {
    const container = AppContainer.shared();
    this.query = container?.backend.medicalQuery;
    this.workflow = container?.backend.medicalWorkflow;
    this.notification = container?.notificationClient;
    this.fileTransfer = container?.fileTransferService;
    if (container) {
      this.attachmentUploader = new MedicalDocumentAttachmentUploader(
        container.fileTransferService,
        (): number | undefined => container.accountRuntime.activeAccountId,
        (): number => container.sessionStore.generation
      );
    }

    const memberID = this.resolvedMemberID();
    const cached = this.initialBoxesFromCache();
    this.viewModel = new FamilyMedicineCabinetViewModel(
      memberID,
      this.mode,
      cached,
      this.query
    );

    const shouldAutoLoad = this.mode === MedicineBoxMode.FAMILY
      ? FamilyMedicineCabinetViewModel.shouldLoadFamilyMedicineOnAppear(
        this.homeVm?.completeData()?.familyMedicineBoxes
      )
      : cached.length === 0;
    if (shouldAutoLoad || cached.length > 0) {
      // 有缓存也允许后台刷新一次，与 iOS .task / refreshable 语义接近
      this.reloadAndNotifyParent(false);
    }
  }

  aboutToDisappear(): void {
    this.formTarget = undefined;
  }

  onListRevisionChanged(): void {
    this.syncFromHomeCache();
  }

  private syncFromHomeCache(): void {
    this.viewModel.replaceFromCache(this.initialBoxesFromCache());
  }

  private resolvedMemberID(): number {
    if (this.entryMemberID > 0) {
      return this.entryMemberID;
    }
    const data = this.homeVm?.completeData();
    if (data && data.memberId > 0) {
      return data.memberId;
    }
    return this.homeVm?.selectedMemberID ?? 0;
  }

  private initialBoxesFromCache(): RemoteMedicineBox[] {
    const data = this.homeVm?.completeData();
    if (!data) {
      return [];
    }
    if (this.mode === MedicineBoxMode.FAMILY) {
      return data.familyMedicineBoxes ?? [];
    }
    return data.medicineBoxes ?? [];
  }

  private navigationTitle(): string {
    return this.mode === MedicineBoxMode.FAMILY ? '家庭药箱' : '个人药箱';
  }

  private uploadBarConfig() {
    return medicalAttachmentUploadConfig(MedicalDocumentKind.MEDICINE_BOX);
  }

  private showsUploadBar(): boolean {
    return !this.viewModel.archiveMode;
  }

  private handleBoxSaved(box: RemoteMedicineBox): void {
    if (this.viewModel.archiveMode || !box.isArchived) {
      this.viewModel.upsert(box);
    } else {
      this.viewModel.remove(box.id);
    }
    this.notifyParentIfPersonal();
    this.notifyParentCompleteDataIfFamily();
  }

  private openDetail(box: RemoteMedicineBox): void {
    const homeVm = this.homeVm;
    if (!homeVm || !this.onOpenDetail) {
      return;
    }
    homeVm.medicineBoxDetailTarget = MedicineBoxDraftMapping.cloneBox(box);
    homeVm.medicineBoxDetailCabinetMode = this.mode;
    homeVm.medicineBoxDetailArchiveMode = this.viewModel.archiveMode
      ? MedicalArchiveListMode.ARCHIVED
      : MedicalArchiveListMode.ACTIVE;
    this.onOpenDetail();
  }

  private notifyParentIfPersonal(): void {
    if (this.mode !== MedicineBoxMode.PERSONAL) {
      return;
    }
    const vm = this.homeVm;
    if (vm) {
      HomeMedicalRouteSupport.patchMedicineBoxes(vm, this.viewModel.boxesForHomeCacheSync);
    }
  }

  private notifyParentCompleteDataIfFamily(): void {
    if (this.mode !== MedicineBoxMode.FAMILY) {
      return;
    }
    const vm = this.homeVm;
    if (vm) {
      HomeMedicalRouteSupport.patchFamilyMedicineBoxes(vm, this.viewModel.boxesForFamilyHomeCacheSync);
    }
  }

  private async reloadAndNotifyParent(showRefreshing: boolean = true): Promise<void> {
    if (showRefreshing) {
      this.refreshing = true;
    }
    const succeeded = await this.viewModel.load();
    if (showRefreshing) {
      this.refreshing = false;
    }
    if (succeeded) {
      this.notifyParentIfPersonal();
      this.notifyParentCompleteDataIfFamily();
    } else if (this.viewModel.errorMessage.length > 0) {
      this.notification?.error(this.viewModel.errorMessage, undefined, 'home.medical.medicine_box');
    }
  }

  private openCreate(): void {
    this.formTarget = undefined;
    this.activeOverlay = FamilyMedicineCabinetOverlay.FORM;
    this.showOverlaySheet = true;
  }

  private openUploadSheet(): void {
    this.activeOverlay = FamilyMedicineCabinetOverlay.UPLOAD;
    this.showOverlaySheet = true;
  }

  private startMedicineBoxRecognition(files: MedicalUploadLocalFile[]): void {
    if (files.length === 0) {
      return;
    }
    this.dismissOverlaySheet();
    const didStart = medicalDocumentUploadStartBridge.start(files, MedicalDocumentKind.MEDICINE_BOX);
    if (!didStart) {
      this.notification?.error('上传模块暂不可用，请稍后重试', undefined, 'home.medical.medicine_box.upload');
    }
  }

  private dismissOverlaySheet(): void {
    this.showOverlaySheet = false;
  }

  private onOverlaySheetDisappear(): void {
    this.showOverlaySheet = false;
    this.activeOverlay = FamilyMedicineCabinetOverlay.NONE;
    this.formTarget = undefined;
  }

  private openArchive(): void {
    appRouter.jumpPage(HomeMedicalRoutes.MEDICINE_BOX_ARCHIVE);
  }

  private async saveModel(model: MedicineBoxFormModel, existingID?: number): Promise<void> {
    const workflow = this.workflow;
    const memberID = this.resolvedMemberID();
    if (!workflow || memberID <= 0) {
      return;
    }
    const validation = model.validate();
    if (validation.length > 0) {
      this.viewModel.errorMessage = validation;
      return;
    }
    try {
      const payload = model.toPayload(memberID, this.mode === MedicineBoxMode.PERSONAL);
      const saved = existingID === undefined
        ? await workflow.createMedicineBox(payload)
        : await workflow.updateMedicineBox(existingID, payload);
      this.handleBoxSaved(saved);
      this.dismissOverlaySheet();
    } catch (e) {
      this.viewModel.errorMessage = `${e}`.substring(0, 160);
      this.notification?.error(this.viewModel.errorMessage, undefined, 'home.medical.medicine_box');
    }
  }

  @Builder
  formBuilder() {
    MedicineBoxFormPage({
      existing: this.formTarget,
      entryMemberID: this.resolvedMemberID(),
      mode: this.mode,
      allowsHouseholdPublic: this.mode === MedicineBoxMode.FAMILY,
      members: this.homeVm?.membersForUi() ?? [],
      typeOptions: MedicineBoxTypeCatalog.options(this.viewModel.filteredBoxes),
      workflow: this.workflow,
      attachmentUploader: this.attachmentUploader,
      onClose: () => this.dismissOverlaySheet(),
      onSave: (model: MedicineBoxFormModel, id?: number) => this.saveModel(model, id)
    })
  }

  @Builder
  overlaySheetContent() {
    if (this.activeOverlay === FamilyMedicineCabinetOverlay.FORM) {
      this.formBuilder()
    } else if (this.activeOverlay === FamilyMedicineCabinetOverlay.UPLOAD) {
      FamilyMedicineCabinetUploadSheetContent({
        onCancel: () => {
          this.dismissOverlaySheet();
        },
        onConfirm: (files: MedicalUploadLocalFile[]) => {
          this.startMedicineBoxRecognition(files);
        }
      })
    }
  }

  build() {
    Column() {
      Column({ space: 0 }) {
        Row() {
          Text('‹ 返回')
            .fontSize(16)
            .fontColor(MEDICAL_LIST_ACCENT)
            .onClick(() => {
              this.onBack?.();
            })
          Blank()
          Text(this.navigationTitle())
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
            .fontColor('#1C1C1E')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Blank()
          FamilyMedicineCabinetHeaderTrailing({
            onOpenArchive: (): void => {
              this.openArchive();
            },
            onOpenCreate: (): void => {
              this.openCreate();
            }
          })
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 12, bottom: 8 })
        FamilyMedicineCabinetHeaderExtension({
          searchText: this.viewModel.searchText,
          onSearchChange: (value: string) => {
            this.viewModel.setSearchText(value);
          }
        })
        Divider()
          .width('100%')
          .height(0.5)
          .color(MEDICAL_LIST_DIVIDER)
      }
      .width('100%')
      .backgroundColor(MEDICAL_LIST_HEADER_BG)
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])

      Refresh({ refreshing: $$this.refreshing }) {
        Scroll() {
          Column({ space: 12 }) {
            if (this.viewModel.showsMemberFilter) {
              MedicineBoxMemberFilterBar({
                options: this.viewModel.memberFilterOptions(this.homeVm?.membersForUi() ?? []),
                selectedKey: this.viewModel.memberFilter.key(),
                onSelect: (filter: MemberFilter) => this.viewModel.setMemberFilter(filter)
              })
            }

            MedicineBoxTypeTabBar({
              typeOptions: this.viewModel.medicineTypeOptions(),
              selectedTypeTab: this.viewModel.selectedTypeTab,
              onSelect: (value: string) => this.viewModel.setSelectedTypeTab(value)
            })

            if (this.viewModel.isLoading && this.viewModel.allBoxes.length === 0) {
              LoadingProgress().width(32).height(32).margin({ top: 40 })
            }

            if (this.viewModel.errorMessage.length > 0) {
              Text(this.viewModel.errorMessage)
                .fontSize(13)
                .fontColor('#D93025')
                .width('100%')
                .padding({ left: 16, right: 16 })
            }

            MedicineBoxGridView({
              boxes: this.viewModel.filteredBoxes,
              isLoading: this.viewModel.isLoading,
              fileTransferService: this.fileTransfer,
              onSelect: (box: RemoteMedicineBox) => this.openDetail(box)
            })
              .padding({ left: 16, right: 16, bottom: 24 })
              .key(`medicine-grid-${this.viewModel.revision}`)
          }
          .width('100%')
          .padding({ top: 4, bottom: 24 })
        }
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
      }
      .layoutWeight(1)
      .onRefreshing(() => {
        this.reloadAndNotifyParent();
      })

      if (this.showsUploadBar()) {
        Column({ space: 0 }) {
          Divider()
            .width('100%')
            .height(0.5)
            .color(MEDICAL_LIST_DIVIDER)
          FamilyMedicineCabinetBottomExtension({
            actionTitle: this.uploadBarConfig().listCameraAddActionTitle,
            tintColor: this.uploadBarConfig().tintColor,
            onUpload: () => {
              this.openUploadSheet();
            }
          })
        }
        .width('100%')
        .backgroundColor(MEDICAL_LIST_HEADER_BG)
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(MEDICAL_LIST_PAGE_BG)
    .bindSheet($$this.showOverlaySheet, this.overlaySheetContent, {
      height: SheetSize.LARGE,
      dragBar: this.activeOverlay === FamilyMedicineCabinetOverlay.FORM,
      showClose: false,
      backgroundColor: this.activeOverlay === FamilyMedicineCabinetOverlay.FORM ? '#F7F7F8' : '#F2F2F7',
      onDisappear: () => {
        this.onOverlaySheetDisappear();
      }
    })
  }
}
