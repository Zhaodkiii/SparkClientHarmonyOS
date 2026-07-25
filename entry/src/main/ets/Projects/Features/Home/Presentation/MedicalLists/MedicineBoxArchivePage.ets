import { AppContainer } from '../../../../../App/AppContainer';
import { SparkMedicalQueryAPI } from '../../../../Core/Networking/API/Medical/MedicalQueryAPI';
import { RemoteMedicineBox } from '../../../../Core/Networking/API/Medical/MedicalSyncAPI';
import { SparkMedicalWorkflowAPI } from '../../../../Core/Networking/API/Medical/MedicalWorkflowAPI';
import { NotificationClient } from '../../../../Core/Notification/Application/NotificationClient';
import { FileTransferService } from '../../../../../Core/FileStorage/FileTransferService';
import { MedicalDocumentAttachmentUploader } from './MedicalDocumentAttachmentUploader';
import { MedicineBoxArchiveMutationService } from './Shared/MedicineBoxArchiveMutationService';
import { HomeViewModel } from '../HomeViewModel';
import { MedicineBoxMode } from './MedicineBox/MedicineBoxMode';
import { MedicineBoxFormModel } from './MedicineBox/MedicineBoxFormModel';
import { FamilyMedicineCabinetViewModel } from './MedicineBox/FamilyMedicineCabinetViewModel';
import { MedicineBoxGridView } from './MedicineBox/MedicineBoxGridView';
import { MedicineBoxFormPage } from './MedicineBox/MedicineBoxFormPage';
import { MedicineBoxDetailPage } from './MedicineBox/MedicineBoxDetailPage';

/**
 * 归档药品独立页面，对齐 iOS `MedicineBoxListPage(archiveMode: .archived)`：
 * 通过工具栏"归档"入口 push 进入的独立页面，始终按 entryMemberID 查询、
 * 无成员/类型筛选、无新增按钮、无拍照上传栏；取消归档后卡片自动从列表移除。
 */
@Component
export struct MedicineBoxArchivePage {
  homeVm?: HomeViewModel;
  onBack?: () => void;

  @State private viewModel: FamilyMedicineCabinetViewModel =
    new FamilyMedicineCabinetViewModel(0, MedicineBoxMode.PERSONAL, []);
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
    this.viewModel = new FamilyMedicineCabinetViewModel(
      memberID,
      MedicineBoxMode.PERSONAL,
      [],
      this.query
    );
    this.viewModel.setArchiveMode(true);
    this.reload();
  }

  aboutToDisappear(): void {
    this.selectedBox = undefined;
    this.formTarget = undefined;
  }

  private resolvedMemberID(): number {
    const data = this.homeVm?.completeData();
    if (data && data.memberId > 0) {
      return data.memberId;
    }
    return this.homeVm?.selectedMemberID ?? 0;
  }

  private async reload(): Promise<void> {
    this.refreshing = true;
    const succeeded = await this.viewModel.load();
    this.refreshing = false;
    if (!succeeded && this.viewModel.errorMessage.length > 0) {
      this.notification?.error(this.viewModel.errorMessage, undefined, 'home.medical.medicine_box_archive');
    }
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

  private async saveModel(model: MedicineBoxFormModel, existingID?: number): Promise<void> {
    const workflow = this.workflow;
    const memberID = this.resolvedMemberID();
    if (!workflow || memberID <= 0 || existingID === undefined) {
      return;
    }
    const validation = model.validate();
    if (validation.length > 0) {
      this.viewModel.errorMessage = validation;
      return;
    }
    try {
      const payload = model.toPayload(memberID, true);
      const saved = await workflow.updateMedicineBox(existingID, payload);
      this.viewModel.upsert(saved);
      this.showForm = false;
    } catch (e) {
      this.viewModel.errorMessage = `${e}`.substring(0, 160);
      this.notification?.error(this.viewModel.errorMessage, undefined, 'home.medical.medicine_box_archive');
    }
  }

  private async deleteBox(box: RemoteMedicineBox): Promise<void> {
    const mutation = this.archiveMutation;
    if (!mutation) {
      return;
    }
    try {
      await mutation.deleteBox(box.id);
      this.viewModel.remove(box.id);
      this.showDetail = false;
    } catch (e) {
      this.viewModel.errorMessage = `${e}`.substring(0, 160);
      this.notification?.error(this.viewModel.errorMessage, undefined, 'home.medical.medicine_box_archive');
    }
  }

  private async unarchiveBox(box: RemoteMedicineBox): Promise<void> {
    const mutation = this.archiveMutation;
    if (!mutation) {
      return;
    }
    try {
      const updated = await mutation.setArchived(box.id, !box.isArchived);
      this.viewModel.upsert(updated);
      this.showDetail = false;
    } catch (e) {
      this.viewModel.errorMessage = `${e}`.substring(0, 160);
      this.notification?.error(this.viewModel.errorMessage, undefined, 'home.medical.medicine_box_archive');
    }
  }

  @Builder
  formBuilder() {
    MedicineBoxFormPage({
      existing: this.formTarget,
      entryMemberID: this.resolvedMemberID(),
      mode: MedicineBoxMode.PERSONAL,
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
        onArchive: (box: RemoteMedicineBox) => this.unarchiveBox(box)
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
        Text('归档药品')
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
        Blank()
        // 与新增/在用切换对称占位，保持标题居中
        Text(' ').fontSize(16)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 8 })

      Refresh({ refreshing: $$this.refreshing }) {
        Scroll() {
          Column({ space: 12 }) {
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

            if (!this.viewModel.isLoading && this.viewModel.filteredBoxes.length === 0) {
              Text('暂无归档药品')
                .fontSize(14)
                .fontColor('#8E8E93')
                .width('100%')
                .textAlign(TextAlign.Center)
                .padding({ top: 48, bottom: 48 })
            } else {
              MedicineBoxGridView({
                boxes: this.viewModel.filteredBoxes,
                isLoading: this.viewModel.isLoading,
                fileTransferService: this.fileTransfer,
                onSelect: (box: RemoteMedicineBox) => this.openDetail(box)
              })
                .padding({ left: 16, right: 16, bottom: 24 })
                .key(`medicine-archive-grid-${this.viewModel.revision}`)
            }
          }
          .width('100%')
          .padding({ top: 4, bottom: 24 })
        }
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
      }
      .layoutWeight(1)
      .onRefreshing(() => {
        this.reload();
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
