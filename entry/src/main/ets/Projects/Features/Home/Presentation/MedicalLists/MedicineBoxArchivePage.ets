import { AppContainer } from '../../../../../App/AppContainer';
import { SparkMedicalQueryAPI } from '../../../../Core/Networking/API/Medical/MedicalQueryAPI';
import { RemoteMedicineBox } from '../../../../Core/Networking/API/Medical/MedicalSyncAPI';
import { SparkMedicalWorkflowAPI } from '../../../../Core/Networking/API/Medical/MedicalWorkflowAPI';
import { NotificationClient } from '../../../../Core/Notification/Application/NotificationClient';
import { FileTransferService } from '../../../../../Core/FileStorage/FileTransferService';
import { MedicalArchiveListMode } from '../../../../Core/Networking/API/Medical/MedicalArchiveModels';
import { HomeViewModel } from '../HomeViewModel';
import { MedicineBoxMode } from './MedicineBox/MedicineBoxMode';
import { FamilyMedicineCabinetViewModel } from './MedicineBox/FamilyMedicineCabinetViewModel';
import { MedicineBoxGridView } from './MedicineBox/MedicineBoxGridView';
import { MedicineBoxDraftMapping } from './MedicineBox/MedicineBoxDraftMapping';
import { MEDICAL_LIST_PAGE_BG, MedicalListPageHeaderChrome } from './Shared/MedicalListPageChrome';

/**
 * 归档药品独立页面，对齐 iOS `MedicineBoxListPage(archiveMode: .archived)`：
 * 通过工具栏"归档"入口 push 进入的独立页面，始终按 entryMemberID 查询、
 * 无成员/类型筛选、无新增按钮、无拍照上传栏；取消归档后卡片自动从列表移除。
 */
@Component
export struct MedicineBoxArchivePage {
  homeVm?: HomeViewModel;
  onBack?: () => void;
  onOpenDetail?: () => void;
  @Prop @Watch('onListRevisionChanged') listRevision: number = 0;

  @State private viewModel: FamilyMedicineCabinetViewModel =
    new FamilyMedicineCabinetViewModel(0, MedicineBoxMode.PERSONAL, []);
  @State private refreshing: boolean = false;

  private query?: SparkMedicalQueryAPI;
  private workflow?: SparkMedicalWorkflowAPI;
  private notification?: NotificationClient;
  private fileTransfer?: FileTransferService;

  aboutToAppear(): void {
    const container = AppContainer.shared();
    this.query = container?.backend.medicalQuery;
    this.workflow = container?.backend.medicalWorkflow;
    this.notification = container?.notificationClient;
    this.fileTransfer = container?.fileTransferService;

    const memberID = this.resolvedMemberID();
    this.viewModel = new FamilyMedicineCabinetViewModel(
      memberID,
      MedicineBoxMode.PERSONAL,
      [],
      this.query
    );
    this.viewModel.setArchiveMode(true);
    void this.reload(false);
  }

  onListRevisionChanged(): void {
    this.viewModel.replaceFromCache([]);
    void this.reload();
  }

  private resolvedMemberID(): number {
    const data = this.homeVm?.completeData();
    if (data && data.memberId > 0) {
      return data.memberId;
    }
    return this.homeVm?.selectedMemberID ?? 0;
  }

  private async reload(showRefreshing: boolean = true): Promise<void> {
    if (showRefreshing) {
      this.refreshing = true;
    }
    const succeeded = await this.viewModel.load();
    if (showRefreshing) {
      this.refreshing = false;
    }
    if (!succeeded && this.viewModel.errorMessage.length > 0) {
      this.notification?.error(this.viewModel.errorMessage, undefined, 'home.medical.medicine_box_archive');
    }
  }

  private openDetail(box: RemoteMedicineBox): void {
    const homeVm = this.homeVm;
    if (!homeVm || !this.onOpenDetail) {
      return;
    }
    homeVm.medicineBoxDetailTarget = MedicineBoxDraftMapping.cloneBox(box);
    homeVm.medicineBoxDetailCabinetMode = MedicineBoxMode.PERSONAL;
    homeVm.medicineBoxDetailArchiveMode = MedicalArchiveListMode.ARCHIVED;
    this.onOpenDetail();
  }

  build() {
    Column() {
      MedicalListPageHeaderChrome({
        title: '归档药品',
        onBack: () => {
          this.onBack?.();
        }
      })

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
    .backgroundColor(MEDICAL_LIST_PAGE_BG)
  }
}
