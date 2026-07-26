import { AppSessionStore } from '../../../../App/AppSessionStore';
import { NotificationClient } from '../../../Core/Notification/Application/NotificationClient';
import { Member } from '../../../Core/Domain/Entities/Member';
import { MemberContextStore } from '../../MemberContext/Presentation/MemberContextStore';
import { LoadMembersUseCase } from '../../MemberContext/Application/LoadMembersUseCase';
import { LoadHomeMedicalOverviewUseCase } from '../Application/LoadHomeMedicalOverviewUseCase';
import { MemberModuleSetupUseCase } from '../Application/MemberModuleSetupUseCase';
import { HomeDashboard, HomeMedicalOverview, MedicalCard, MedicalCardKind } from '../Domain/HomeDashboard';
import { HomeMedicalLoadResult } from '../Domain/HomeDashboard';
import { MedicalArchiveListMode } from '../../../Core/Networking/API/Medical/MedicalArchiveModels';
import {
  RemoteExaminationReportWithAttachments,
  RemoteHealthExamReportWithAttachments,
  RemoteMemberCompleteData,
  RemoteMemberModuleSetting,
  RemoteMedicineBox
} from '../../../Core/Networking/API/Medical/MedicalSyncAPI';
import { ExaminationSubitemDetailTarget } from './MedicalLists/ExaminationReports/ExaminationReportDetailSupport';
import { MedicineBoxMode } from './MedicalLists/MedicineBox/MedicineBoxMode';
import { Logger } from '../../../../Foundation/Logging/Logger';
import { LogModule } from '../../../../Foundation/Logging/LogModule';
import { LogFields } from '../../../../Foundation/Logging/LogEvent';

export type MedicalCompleteDataMutator = (data: RemoteMemberCompleteData) => void;

export class HomeViewModel {
  private readonly sessionStore: AppSessionStore;
  private readonly loadHomeMedicalOverviewUseCase: LoadHomeMedicalOverviewUseCase;
  private readonly memberModuleSetupUseCase: MemberModuleSetupUseCase;
  private readonly loadMembersUseCase: LoadMembersUseCase;
  private readonly memberContextStore: MemberContextStore;
  private readonly notificationClient: NotificationClient;
  private onChanged?: () => void;

  dashboard?: HomeDashboard;
  selectedMemberID?: number;
  currentMemberModuleSettings: RemoteMemberModuleSetting[] = [];
  isLoading: boolean = false;
  isLoadingMedical: boolean = false;
  /** 体检详情导航目标（NavPathStack 参数载体）。 */
  healthExamDetailTarget?: RemoteHealthExamReportWithAttachments;
  healthExamDetailArchiveMode: MedicalArchiveListMode = MedicalArchiveListMode.ACTIVE;
  /** 详情删除/归档后递增，驱动列表页 @Watch 回刷。 */
  healthExamListRevision: number = 0;
  /** 检查报告详情导航目标。 */
  examinationDetailTarget?: RemoteExaminationReportWithAttachments;
  examinationDetailArchiveMode: MedicalArchiveListMode = MedicalArchiveListMode.ACTIVE;
  /** 检查报告单项 / 完整检验表明细导航目标。 */
  examinationSubitemDetailTarget?: ExaminationSubitemDetailTarget;
  examinationListRevision: number = 0;
  /** 药箱详情导航目标（NavPathStack 参数载体）。 */
  medicineBoxDetailTarget?: RemoteMedicineBox;
  medicineBoxDetailCabinetMode: MedicineBoxMode = MedicineBoxMode.FAMILY;
  medicineBoxDetailArchiveMode: MedicalArchiveListMode = MedicalArchiveListMode.ACTIVE;
  medicineBoxListRevision: number = 0;
  private initialLoadStarted: boolean = false;
  private loadGeneration: number = 0;

  constructor(
    sessionStore: AppSessionStore,
    loadHomeMedicalOverviewUseCase: LoadHomeMedicalOverviewUseCase,
    memberModuleSetupUseCase: MemberModuleSetupUseCase,
    loadMembersUseCase: LoadMembersUseCase,
    memberContextStore: MemberContextStore,
    notificationClient: NotificationClient
  ) {
    this.sessionStore = sessionStore;
    this.loadHomeMedicalOverviewUseCase = loadHomeMedicalOverviewUseCase;
    this.memberModuleSetupUseCase = memberModuleSetupUseCase;
    this.loadMembersUseCase = loadMembersUseCase;
    this.memberContextStore = memberContextStore;
    this.notificationClient = notificationClient;
  }

  setOnChanged(cb: () => void): void {
    this.onChanged = cb;
  }

  private notify(): void {
    if (this.onChanged) {
      this.onChanged();
    }
  }

  cardTitle(kind: MedicalCardKind): string {
    if (kind === MedicalCardKind.MEDICAL_CASES) {
      return '病例记录';
    }
    if (kind === MedicalCardKind.HEALTH_EXAM_REPORTS) {
      return '体检报告';
    }
    if (kind === MedicalCardKind.MEDICAL_REPORTS) {
      return '检查报告';
    }
    return '服药计划';
  }

  /** 对齐 iOS medicalCardSubtitle(for:)。 */
  cardSubtitle(kind: MedicalCardKind): string {
    if (kind === MedicalCardKind.MEDICAL_CASES) {
      return '最近就诊';
    }
    if (kind === MedicalCardKind.HEALTH_EXAM_REPORTS) {
      return '年度体检';
    }
    if (kind === MedicalCardKind.MEDICAL_REPORTS) {
      return '专项检查';
    }
    return '执行中的规则';
  }

  get shouldShowMedicalSection(): boolean {
    return this.isModuleEnabled('medical');
  }

  get shouldShowNutritionSection(): boolean {
    return this.isModuleEnabled('nutrition');
  }

  get shouldShowModuleMaintenanceSection(): boolean {
    return this.selectedMemberID !== undefined
      && !this.shouldShowMedicalSection
      && !this.shouldShowNutritionSection;
  }

  /** 对齐 iOS：仅认 is_enabled；空 settings / 失败清空 = 默认不开通。 */
  private isModuleEnabled(moduleCode: string): boolean {
    for (let i = 0; i < this.currentMemberModuleSettings.length; i++) {
      const s = this.currentMemberModuleSettings[i];
      if (s.moduleCode === moduleCode && s.isEnabled) {
        return true;
      }
    }
    return false;
  }

  /** SetupFlow 写回后立即刷新分区，避免等完整 load。 */
  applyModuleSettings(settings: RemoteMemberModuleSetting[]): void {
    this.currentMemberModuleSettings = settings;
    this.notify();
  }

  /**
   * 列表/药箱字段级回写。无 dashboard 或 completeData 时静默忽略（对齐 iOS）。
   * 已知缺口：不重算 cards。
   */
  updateMedicalCompleteData(mutator: MedicalCompleteDataMutator): void {
    const dash = this.dashboard;
    if (!dash || !dash.medical.completeData) {
      return;
    }
    mutator(dash.medical.completeData);
    this.notify();
  }

  bumpHealthExamListRevision(): void {
    this.healthExamListRevision += 1;
    this.notify();
  }

  clearHealthExamDetailTarget(): void {
    this.healthExamDetailTarget = undefined;
  }

  bumpExaminationListRevision(): void {
    this.examinationListRevision += 1;
    this.notify();
  }

  clearExaminationDetailTarget(): void {
    this.examinationDetailTarget = undefined;
  }

  clearExaminationSubitemDetailTarget(): void {
    this.examinationSubitemDetailTarget = undefined;
  }

  bumpMedicineBoxListRevision(): void {
    this.medicineBoxListRevision += 1;
    this.notify();
  }

  clearMedicineBoxDetailTarget(): void {
    this.medicineBoxDetailTarget = undefined;
  }

  async loadInitialIfNeeded(syncRemote: boolean = true): Promise<void> {
    if (this.initialLoadStarted && this.dashboard) {
      return;
    }
    this.initialLoadStarted = true;
    await this.load(syncRemote);
  }

  async load(syncRemote: boolean = true): Promise<void> {
    const session = this.sessionStore.session;
    if (!session || this.sessionStore.sessionState !== 'signedIn') {
      return;
    }
    const gen = ++this.loadGeneration;
    this.isLoading = true;
    this.notify();
    Logger.info('home.load.start', LogModule.HOME);
    try {
      await this.memberContextStore.bindAccount(session.accountId);
      this.isLoadingMedical = true;
      this.notify();
      let medicalResult: HomeMedicalLoadResult;
      try {
        medicalResult = await this.loadHomeMedicalOverviewUseCase.execute(
          session,
          this.selectedMemberID,
          syncRemote
        );
      } catch (e) {
        this.isLoadingMedical = false;
        const message = `${e}`;
        this.notificationClient.error(message, undefined, 'home.dashboard');
        const failFields = new LogFields();
        failFields.detail = message;
        Logger.warn('home.load.medical_failed', LogModule.HOME, failFields);
        this.notify();
        return;
      }
      if (gen !== this.loadGeneration) {
        return;
      }
      this.isLoadingMedical = false;

      const medical: HomeMedicalOverview = medicalResult.medical;
      if (medical.completeData
        && this.dashboard?.medical.completeData
        && this.dashboard.medical.completeData.memberId === medical.completeData.memberId
        && this.dashboard.medical.completeData.familyMedicineBoxes) {
        medical.completeData.familyMedicineBoxes = this.dashboard.medical.completeData.familyMedicineBoxes;
      }

      const loaded = new HomeDashboard(session);
      loaded.members = medicalResult.members;
      loaded.selectedMemberID = medicalResult.selectedMemberID;
      loaded.medical = medical;
      this.dashboard = loaded;
      this.selectedMemberID = loaded.selectedMember?.id;
      await this.memberContextStore.update(loaded.members, loaded.selectedMemberID);
      await this.loadCurrentMemberModuleSettings();
      Logger.info('home.load.done', LogModule.HOME);
    } finally {
      if (gen === this.loadGeneration) {
        this.isLoading = false;
        this.isLoadingMedical = false;
      }
      this.notify();
    }
  }

  async refresh(): Promise<void> {
    await this.load(true);
  }

  /**
   * 仅刷新成员列表，保留既有 medical.completeData（对齐 iOS reloadMembers）。
   */
  async reloadMembers(): Promise<void> {
    const session = this.sessionStore.session;
    if (!session || this.sessionStore.sessionState !== 'signedIn') {
      return;
    }
    const members = await this.loadMembersUseCase.execute();
    const resolved = this.resolveSelectedMemberID(members);
    this.selectedMemberID = resolved;
    await this.memberContextStore.update(members, resolved);
    if (this.dashboard) {
      this.dashboard.members = members;
      this.dashboard.selectedMemberID = resolved;
    }
    this.notify();
    Logger.info('home.reload_members.done', LogModule.HOME);
  }

  private resolveSelectedMemberID(members: Member[]): number | undefined {
    if (members.length === 0) {
      return undefined;
    }
    if (this.selectedMemberID !== undefined && this.selectedMemberID !== null) {
      for (let i = 0; i < members.length; i++) {
        if (members[i].id === this.selectedMemberID) {
          return this.selectedMemberID;
        }
      }
    }
    return members[0].id;
  }

  async selectMember(memberID: number | undefined): Promise<void> {
    this.selectedMemberID = memberID;
    this.notify();
    await this.memberContextStore.select(memberID);
    await this.load(false);
  }

  async switchMemberAndLoad(memberID: number): Promise<void> {
    this.selectedMemberID = memberID;
    this.notify();
    await this.memberContextStore.select(memberID);
    await this.load(true);
  }

  private async loadCurrentMemberModuleSettings(): Promise<void> {
    const memberID = this.selectedMemberID;
    if (memberID === undefined || memberID === null) {
      this.currentMemberModuleSettings = [];
      return;
    }
    try {
      this.currentMemberModuleSettings = await this.memberModuleSetupUseCase.loadModuleSettings(memberID);
      Logger.info('home.module_settings.refreshed', LogModule.HOME);
    } catch (e) {
      this.currentMemberModuleSettings = [];
      const fields = new LogFields();
      fields.detail = `${e}`;
      Logger.warn('home.module_settings.failed', LogModule.HOME, fields);
    }
  }

  membersForUi(): Member[] {
    if (this.dashboard) {
      return this.dashboard.members;
    }
    return this.memberContextStore.context.members;
  }

  cardsForUi(): MedicalCard[] {
    return this.dashboard?.medical.cards ?? [];
  }

  completeData(): RemoteMemberCompleteData | undefined {
    return this.dashboard?.medical.completeData;
  }

  logMedicalListNavigation(kind: MedicalCardKind): void {
    const fields = new LogFields();
    fields.detail = `kind=${kind};member=${this.selectedMemberID ?? 'nil'}`;
    Logger.info('home.medical_list.navigate', LogModule.HOME, fields);
  }
}
