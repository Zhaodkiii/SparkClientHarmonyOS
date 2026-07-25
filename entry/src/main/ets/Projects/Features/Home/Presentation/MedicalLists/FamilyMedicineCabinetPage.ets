import { AppContainer } from '../../../../../App/AppContainer';
import { appRouter } from '../../../../../App/Navigation/AppRouter';
import { SparkMedicalQueryAPI } from '../../../../Core/Networking/API/Medical/MedicalQueryAPI';
import { RemoteMedicineBox } from '../../../../Core/Networking/API/Medical/MedicalSyncAPI';
import { SparkMedicalWorkflowAPI } from '../../../../Core/Networking/API/Medical/MedicalWorkflowAPI';
import { NotificationClient } from '../../../../Core/Notification/Application/NotificationClient';
import { FileTransferService } from '../../../../../Core/FileStorage/FileTransferService';
import { MedicalDocumentAttachmentUploader } from './MedicalDocumentAttachmentUploader';
import { MedicineBoxArchiveMutationService } from './Shared/MedicineBoxArchiveMutationService';
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
import { MedicineBoxDetailPage } from './MedicineBox/MedicineBoxDetailPage';

/**
 * 家庭/个人药箱统一页面（对齐 iOS FamilyMedicineCabinetPage）。
 * 通过 mode 区分家庭汇总与个人成员药箱；人员筛选仅家庭模式展示。
 */
@Component
export struct FamilyMedicineCabinetPage {
  homeVm?: HomeViewModel;
  onBack?: () => void;
  @Prop entryMemberID: number = 0;
  @Prop mode: MedicineBoxMode = MedicineBoxMode.FAMILY;

  @State private viewModel: FamilyMedicineCabinetViewModel =
    new FamilyMedicineCabinetViewModel(0, MedicineBoxMode.FAMILY, []);
  @State private refreshing: boolean = false;
  @State private selectedBox?: RemoteMedicineBox = undefined;
  @State private formTarget?: RemoteMedicineBox = undefined;
  @State private showDetail: boolean = false;
  @State private showForm: boolean = false;

  private query?: SparkMedicalQueryAPI;
  private workflow?: SparkMedicalWorkflowAPI;
  private notification?: NotificationClient;
  private fileTransfer?: FileTransferService;
  private attachmentUploader?: MedicalDocumentAttachmentUploader;
  private archiveMutation?: MedicineBoxArchiveMutationService;

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
    if (this.workflow) {
      this.archiveMutation = new MedicineBoxArchiveMutationService(this.workflow);
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
      this.reloadAndNotifyParent();
    }
  }

  aboutToDisappear(): void {
    this.selectedBox = undefined;
    this.formTarget = undefined;
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

  private handleBoxSaved(box: RemoteMedicineBox): void {
    this.viewModel.upsert(box);
    this.notifyParentIfPersonal();
    this.notifyParentCompleteDataIfFamily();
  }

  private handleBoxDeleted(id: number): void {
    this.viewModel.remove(id);
    this.notifyParentIfPersonal();
    this.notifyParentCompleteDataIfFamily();
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

  private async reloadAndNotifyParent(): Promise<void> {
    this.refreshing = true;
    const succeeded = await this.viewModel.load();
    this.refreshing = false;
    if (succeeded) {
      this.notifyParentIfPersonal();
      this.notifyParentCompleteDataIfFamily();
    } else if (this.viewModel.errorMessage.length > 0) {
      this.notification?.error(this.viewModel.errorMessage, undefined, 'home.medical.medicine_box');
    }
  }

  private openCreate(): void {
    this.formTarget = undefined;
    this.showForm = true;
  }

  private openEdit(box: RemoteMedicineBox): void {
    this.formTarget = box;
    this.showDetail = false;
    this.showForm = true;
  }

  private openDetail(box: RemoteMedicineBox): void {
    this.selectedBox = box;
    this.showDetail = true;
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
      this.showForm = false;
    } catch (e) {
      this.viewModel.errorMessage = `${e}`.substring(0, 160);
      this.notification?.error(this.viewModel.errorMessage, undefined, 'home.medical.medicine_box');
    }
  }

  private async deleteBox(box: RemoteMedicineBox): Promise<void> {
    const mutation = this.archiveMutation;
    if (!mutation) {
      return;
    }
    try {
      await mutation.deleteBox(box.id);
      this.handleBoxDeleted(box.id);
      this.showDetail = false;
    } catch (e) {
      this.viewModel.errorMessage = `${e}`.substring(0, 160);
      this.notification?.error(this.viewModel.errorMessage, undefined, 'home.medical.medicine_box');
    }
  }

  private async archiveBox(box: RemoteMedicineBox): Promise<void> {
    const mutation = this.archiveMutation;
    if (!mutation) {
      return;
    }
    try {
      const updated = await mutation.setArchived(box.id, !box.isArchived);
      this.handleBoxSaved(updated);
      this.showDetail = false;
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
      members: this.homeVm?.membersForUi() ?? [],
      workflow: this.workflow,
      attachmentUploader: this.attachmentUploader,
      onClose: () => this.showForm = false,
      onSave: (model: MedicineBoxFormModel, id?: number) => this.saveModel(model, id)
    })
  }

  @Builder
  detailBuilder() {
    if (this.selectedBox) {
      MedicineBoxDetailPage({
        box: this.selectedBox,
        workflow: this.workflow,
        fileTransferService: this.fileTransfer,
        onBack: () => this.showDetail = false,
        onEdit: (box: RemoteMedicineBox) => this.openEdit(box),
        onDelete: (box: RemoteMedicineBox) => this.deleteBox(box),
        onArchive: (box: RemoteMedicineBox) => this.archiveBox(box)
      })
    }
  }

  build() {
    Column() {
      Row() {
        Text('‹ 返回')
          .fontSize(16)
          .fontColor('#0A84FF')
          .onClick(() => this.onBack?.())
        Blank()
        Text(this.navigationTitle())
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
        Blank()
        Text('归档')
          .fontSize(13)
          .fontColor('#0A84FF')
          .onClick(() => this.openArchive())
        SymbolGlyph($r('sys.symbol.plus'))
          .fontSize(22)
          .fontColor(['#0A84FF'])
          .margin({ left: 16 })
          .onClick(() => this.openCreate())
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 8 })

      TextInput({
        text: this.viewModel.searchText,
        placeholder: '搜索药品名称、品牌、规格'
      })
        .height(40)
        .margin({ left: 16, right: 16, bottom: 8 })
        .backgroundColor('#FFFFFF')
        .borderRadius(12)
        .onChange((value: string) => this.viewModel.setSearchText(value))

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
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F2F2F7')
    .bindSheet($$this.showForm, this.formBuilder(), {
      height: SheetSize.LARGE,
      dragBar: true,
      showClose: false,
      backgroundColor: '#F7F7F8',
      onDisappear: () => this.showForm = false
    })
    .bindContentCover($$this.showDetail, this.detailBuilder(), {
      modalTransition: ModalTransition.DEFAULT,
      onDisappear: () => {
        this.showDetail = false;
        this.selectedBox = undefined;
      }
    })
  }
}
