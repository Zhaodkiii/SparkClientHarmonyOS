import { appRouter } from './AppRouter';
import { AppContainer } from '../AppContainer';
import { Member } from '../../Projects/Core/Domain/Entities/Member';
import { RemoteExaminationReportWithAttachments, RemoteMedicineBox } from '../../Projects/Core/Networking/API/Medical/MedicalSyncAPI';
import { MedicalArchiveListMode } from '../../Projects/Core/Networking/API/Medical/MedicalArchiveModels';
import { ChatRoutes } from '../../Projects/Features/Chat/Presentation/ChatRoutes';
import { ChatTabPage } from '../../Projects/Features/Chat/Presentation/ChatTabPage';
import { AccountManagementPage } from '../../Projects/Features/AccountManagement/Presentation/AccountManagementPage';
import { AISettingsPage } from '../../Projects/Features/AISettings/Presentation/AISettingsPage';
import { SettingsRoutes } from '../../Projects/Features/Settings/SettingsRoutes';
import { HomeMedicalRoutes } from '../../Projects/Features/Home/Presentation/HomeMedicalRoutes';
import { HomeMedicalRouteSupport } from '../../Projects/Features/Home/Presentation/HomeMedicalRouteSupport';
import { HomeViewModel } from '../../Projects/Features/Home/Presentation/HomeViewModel';
import { HomeSetupFlowHolder } from '../../Projects/Features/Home/Presentation/HomeSetupFlowHolder';
import { HomeMedicalListPage } from '../../Projects/Features/Home/Presentation/MedicalLists/HomeMedicalListPage';
import { FamilyMedicineCabinetPage } from '../../Projects/Features/Home/Presentation/MedicalLists/FamilyMedicineCabinetPage';
import { MedicineBoxArchivePage } from '../../Projects/Features/Home/Presentation/MedicalLists/MedicineBoxArchivePage';
import { MedicineBoxMode } from '../../Projects/Features/Home/Presentation/MedicalLists/MedicineBox/MedicineBoxMode';
import { HealthExamReportsListPage } from '../../Projects/Features/Home/Presentation/MedicalLists/HealthExamReports/HealthExamReportsListPage';
import { HealthExamReportDetailPage } from '../../Projects/Features/Home/Presentation/MedicalLists/HealthExamReports/HealthExamReportDetailPage';
import { ExaminationReportsListPage } from '../../Projects/Features/Home/Presentation/MedicalLists/ExaminationReports/ExaminationReportsListPage';
import { ExaminationReportDetailPage } from '../../Projects/Features/Home/Presentation/MedicalLists/ExaminationReports/ExaminationReportDetailPage';
import { ExaminationReportCategoryDetailPage } from '../../Projects/Features/Home/Presentation/MedicalLists/ExaminationReports/ExaminationReportCategoryDetailPage';
import { MedicationExecutionCenterPage } from '../../Projects/Features/Home/Presentation/MedicalLists/Medications/MedicationExecutionCenter/MedicationExecutionCenterPage';
import { MedicineBoxDetailPage } from '../../Projects/Features/Home/Presentation/MedicalLists/MedicineBox/MedicineBoxDetailPage';
import { MedicineBoxDraftMapping } from '../../Projects/Features/Home/Presentation/MedicalLists/MedicineBox/MedicineBoxDraftMapping';
import { MemberSetupFlowPage } from '../../Projects/Features/Home/Presentation/Members/MemberSetup/MemberSetupFlowPage';
import { MemberSetupFlowViewModel } from '../../Projects/Features/Home/Presentation/Members/MemberSetup/MemberSetupFlowViewModel';

function isHomeRoute(name: string): boolean {
  return name.indexOf('home.') === 0;
}

@Builder
export function AppRootNavDestinationBuilder(name: string) {
  if (name === SettingsRoutes.ACCOUNT) {
    AccountManagementPage({
      onRequestClearSettingsNav: () => {
        appRouter.popPage();
      }
    });
  } else if (name === SettingsRoutes.AI) {
    NavDestination() {
      AISettingsPage({
        onClose: () => {
          appRouter.popPage();
        }
      });
    }
    .hideTitleBar(true)
    .onBackPressed(() => {
      appRouter.popPage();
      return true;
    })
  } else if (name === ChatRoutes.DETAIL) {
    ChatDetailRootPage()
  } else if (isHomeRoute(name)) {
    HomeSecondaryRootPage({ routeName: name })
  } else {
    NavDestination() {
      Text(`未知路由: ${name}`)
        .fontSize(14)
        .fontColor('#888888')
    }
    .hideTitleBar(true)
    .onBackPressed(() => {
      appRouter.popPage();
      return true;
    })
  }
}

@Component
struct ChatDetailRootPage {
  private threadId(): string {
    const param = appRouter.latestParam(ChatRoutes.DETAIL);
    return param !== undefined ? `${param}` : '';
  }

  build() {
    NavDestination() {
      ChatTabPage({
        initialThreadId: this.threadId(),
        showThreadSwitcher: false,
        onBack: () => {
          appRouter.popPage();
        }
      })
    }
    .hideTitleBar(true)
    .onBackPressed(() => {
      appRouter.popPage();
      return true;
    })
  }
}

@Component
struct HomeSecondaryRootPage {
  @Prop routeName: string = '';
  private homeVm?: HomeViewModel;
  private setupFlowVm?: MemberSetupFlowViewModel;
  @State private healthExamListRevision: number = 0;
  @State private examinationListRevision: number = 0;
  @State private medicineBoxListRevision: number = 0;
  @State private setupReady: boolean = false;

  aboutToAppear(): void {
    const container = AppContainer.shared();
    this.homeVm = container?.createHomeViewModel();
    if (this.routeName === HomeMedicalRoutes.MEMBER_SETUP_CREATE
      || this.routeName === HomeMedicalRoutes.MEMBER_SETUP_MAINTAIN) {
      this.setupFlowVm = HomeSetupFlowHolder.peek();
      this.setupReady = this.setupFlowVm !== undefined;
    }
    if (this.homeVm) {
      this.healthExamListRevision = this.homeVm.healthExamListRevision;
      this.examinationListRevision = this.homeVm.examinationListRevision;
      this.medicineBoxListRevision = this.homeVm.medicineBoxListRevision;
    }
  }

  private pop(): void {
    appRouter.popPage();
  }

  private handleHealthExamDeleted(reportID: number): void {
    const homeVm = this.homeVm;
    if (!homeVm) {
      return;
    }
    HomeMedicalRouteSupport.removeHealthExamReport(homeVm, reportID);
    homeVm.bumpHealthExamListRevision();
    this.healthExamListRevision = homeVm.healthExamListRevision;
  }

  private handleHealthExamArchiveChanged(reportID: number, isArchived: boolean): void {
    const homeVm = this.homeVm;
    if (!homeVm) {
      return;
    }
    if (isArchived) {
      HomeMedicalRouteSupport.removeHealthExamReport(homeVm, reportID);
    }
    homeVm.bumpHealthExamListRevision();
    this.healthExamListRevision = homeVm.healthExamListRevision;
  }

  private handleExaminationDeleted(reportID: number): void {
    const homeVm = this.homeVm;
    if (!homeVm) {
      return;
    }
    HomeMedicalRouteSupport.removeExaminationReport(homeVm, reportID);
    homeVm.bumpExaminationListRevision();
    this.examinationListRevision = homeVm.examinationListRevision;
  }

  private handleExaminationArchiveChanged(reportID: number, isArchived: boolean): void {
    const homeVm = this.homeVm;
    if (!homeVm) {
      return;
    }
    if (isArchived) {
      HomeMedicalRouteSupport.removeExaminationReport(homeVm, reportID);
    }
    homeVm.bumpExaminationListRevision();
    this.examinationListRevision = homeVm.examinationListRevision;
  }

  private handleExaminationSaved(report: RemoteExaminationReportWithAttachments): void {
    const homeVm = this.homeVm;
    if (!homeVm) {
      return;
    }
    HomeMedicalRouteSupport.replaceExaminationReport(homeVm, report);
    homeVm.bumpExaminationListRevision();
    this.examinationListRevision = homeVm.examinationListRevision;
  }

  private handleMedicineBoxDeleted(boxID: number): void {
    const homeVm = this.homeVm;
    if (!homeVm) {
      return;
    }
    if (homeVm.medicineBoxDetailCabinetMode === MedicineBoxMode.FAMILY) {
      HomeMedicalRouteSupport.removeFamilyMedicineBox(homeVm, boxID);
    } else {
      HomeMedicalRouteSupport.removeMedicineBox(homeVm, boxID);
    }
    homeVm.bumpMedicineBoxListRevision();
    this.medicineBoxListRevision = homeVm.medicineBoxListRevision;
  }

  private handleMedicineBoxArchiveChanged(boxID: number, isArchived: boolean): void {
    const homeVm = this.homeVm;
    if (!homeVm) {
      return;
    }
    const belongsInList = homeVm.medicineBoxDetailArchiveMode === MedicalArchiveListMode.ARCHIVED
      ? isArchived
      : !isArchived;
    if (!belongsInList) {
      this.handleMedicineBoxDeleted(boxID);
    }
  }

  private handleMedicineBoxSaved(box: RemoteMedicineBox): void {
    const homeVm = this.homeVm;
    if (!homeVm) {
      return;
    }
    const belongsInList = homeVm.medicineBoxDetailArchiveMode === MedicalArchiveListMode.ARCHIVED
      ? box.isArchived
      : !box.isArchived;
    if (belongsInList) {
      if (homeVm.medicineBoxDetailCabinetMode === MedicineBoxMode.FAMILY) {
        HomeMedicalRouteSupport.upsertFamilyMedicineBox(homeVm, box);
      } else {
        HomeMedicalRouteSupport.upsertMedicineBox(homeVm, box);
      }
    } else if (homeVm.medicineBoxDetailCabinetMode === MedicineBoxMode.FAMILY) {
      HomeMedicalRouteSupport.removeFamilyMedicineBox(homeVm, box.id);
    } else {
      HomeMedicalRouteSupport.removeMedicineBox(homeVm, box.id);
    }
    homeVm.medicineBoxDetailTarget = MedicineBoxDraftMapping.cloneBox(box);
    homeVm.bumpMedicineBoxListRevision();
    this.medicineBoxListRevision = homeVm.medicineBoxListRevision;
  }

  private async handleSetupFinished(member: Member): Promise<void> {
    const homeVm = this.homeVm;
    if (!homeVm) {
      return;
    }
    await homeVm.selectMember(member.id);
  }

  build() {
    NavDestination() {
      if (this.routeName === HomeMedicalRoutes.FAMILY_CABINET
        || this.routeName === HomeMedicalRoutes.PERSONAL_CABINET) {
        FamilyMedicineCabinetPage({
          homeVm: this.homeVm,
          listRevision: this.medicineBoxListRevision,
          mode: this.routeName === HomeMedicalRoutes.PERSONAL_CABINET
            ? MedicineBoxMode.PERSONAL
            : MedicineBoxMode.FAMILY,
          onBack: () => {
            this.pop();
          },
          onOpenDetail: () => {
            appRouter.jumpPage(HomeMedicalRoutes.MEDICINE_BOX_DETAIL);
          }
        })
      } else if (this.routeName === HomeMedicalRoutes.MEDICINE_BOX_ARCHIVE) {
        MedicineBoxArchivePage({
          homeVm: this.homeVm,
          listRevision: this.medicineBoxListRevision,
          onBack: () => {
            this.pop();
          },
          onOpenDetail: () => {
            appRouter.jumpPage(HomeMedicalRoutes.MEDICINE_BOX_DETAIL);
          }
        })
      } else if (this.routeName === HomeMedicalRoutes.MEDICINE_BOX_DETAIL) {
        MedicineBoxDetailPage({
          homeVm: this.homeVm,
          initialBox: this.homeVm?.medicineBoxDetailTarget ?? new RemoteMedicineBox(),
          entryMemberID: this.homeVm?.completeData()?.memberId ?? this.homeVm?.selectedMemberID ?? 0,
          memberOptions: this.homeVm?.membersForUi() ?? [],
          allowsHouseholdPublic: (this.homeVm?.medicineBoxDetailCabinetMode ?? MedicineBoxMode.FAMILY)
            === MedicineBoxMode.FAMILY,
          cabinetMode: this.homeVm?.medicineBoxDetailCabinetMode ?? MedicineBoxMode.FAMILY,
          archiveListMode: this.homeVm?.medicineBoxDetailArchiveMode ?? MedicalArchiveListMode.ACTIVE,
          onBack: () => {
            this.homeVm?.clearMedicineBoxDetailTarget();
            this.pop();
          },
          onSaved: (box: RemoteMedicineBox) => {
            this.handleMedicineBoxSaved(box);
          },
          onDeleted: (boxID: number) => {
            this.handleMedicineBoxDeleted(boxID);
            this.homeVm?.clearMedicineBoxDetailTarget();
            this.pop();
          },
          onArchiveStateChanged: (boxID: number, isArchived: boolean) => {
            this.handleMedicineBoxArchiveChanged(boxID, isArchived);
          }
        })
      } else if (this.routeName === HomeMedicalRoutes.HEALTH_EXAM_REPORTS) {
        HealthExamReportsListPage({
          homeVm: this.homeVm,
          listRevision: this.healthExamListRevision,
          onBack: () => {
            this.pop();
          },
          onOpenDetail: () => {
            appRouter.jumpPage(HomeMedicalRoutes.HEALTH_EXAM_DETAIL);
          }
        })
      } else if (this.routeName === HomeMedicalRoutes.HEALTH_EXAM_DETAIL) {
        HealthExamReportDetailPage({
          homeVm: this.homeVm,
          onBack: () => {
            this.homeVm?.clearHealthExamDetailTarget();
            this.pop();
          },
          onDeleted: (reportID: number) => {
            this.handleHealthExamDeleted(reportID);
          },
          onArchiveStateChanged: (reportID: number, isArchived: boolean) => {
            this.handleHealthExamArchiveChanged(reportID, isArchived);
          }
        })
      } else if (this.routeName === HomeMedicalRoutes.EXAMINATION_REPORTS) {
        ExaminationReportsListPage({
          homeVm: this.homeVm,
          listRevision: this.examinationListRevision,
          archiveMode: MedicalArchiveListMode.ACTIVE,
          onBack: () => {
            this.pop();
          },
          onOpenDetail: () => {
            appRouter.jumpPage(HomeMedicalRoutes.EXAMINATION_DETAIL);
          },
          onOpenArchive: () => {
            appRouter.jumpPage(HomeMedicalRoutes.EXAMINATION_REPORTS_ARCHIVE);
          }
        })
      } else if (this.routeName === HomeMedicalRoutes.EXAMINATION_REPORTS_ARCHIVE) {
        ExaminationReportsListPage({
          homeVm: this.homeVm,
          archiveMode: MedicalArchiveListMode.ARCHIVED,
          onBack: () => {
            this.pop();
          },
          onOpenDetail: () => {
            appRouter.jumpPage(HomeMedicalRoutes.EXAMINATION_DETAIL);
          }
        })
      } else if (this.routeName === HomeMedicalRoutes.EXAMINATION_DETAIL) {
        ExaminationReportDetailPage({
          homeVm: this.homeVm,
          onBack: () => {
            this.homeVm?.clearExaminationDetailTarget();
            this.pop();
          },
          onOpenSubitemDetail: () => {
            appRouter.jumpPage(HomeMedicalRoutes.EXAMINATION_SUBITEM_DETAIL);
          },
          onDeleted: (reportID: number) => {
            this.handleExaminationDeleted(reportID);
          },
          onArchiveStateChanged: (reportID: number, isArchived: boolean) => {
            this.handleExaminationArchiveChanged(reportID, isArchived);
          },
          onSaved: (report: RemoteExaminationReportWithAttachments) => {
            this.handleExaminationSaved(report);
          }
        })
      } else if (this.routeName === HomeMedicalRoutes.EXAMINATION_SUBITEM_DETAIL) {
        ExaminationReportCategoryDetailPage({
          homeVm: this.homeVm,
          onBack: () => {
            this.homeVm?.clearExaminationSubitemDetailTarget();
            this.pop();
          }
        })
      } else if (this.routeName === HomeMedicalRoutes.MEDICATION_PLANS) {
        MedicationExecutionCenterPage({
          homeVm: this.homeVm,
          onBack: () => {
            this.pop();
          },
          onOpenPersonalCabinet: () => {
            appRouter.jumpPage(HomeMedicalRoutes.PERSONAL_CABINET);
          }
        })
      } else if (this.routeName === HomeMedicalRoutes.MEMBER_SETUP_CREATE
        || this.routeName === HomeMedicalRoutes.MEMBER_SETUP_MAINTAIN) {
        if (this.setupReady && this.setupFlowVm) {
          MemberSetupFlowPage({
            flowVm: this.setupFlowVm,
            onClose: () => {
              HomeSetupFlowHolder.clear();
              this.setupFlowVm = undefined;
              this.setupReady = false;
              this.pop();
            },
            onFinished: (member: Member) => {
              this.handleSetupFinished(member);
            }
          })
        } else {
          Text('流程未初始化')
            .fontSize(14)
            .fontColor('#888888')
        }
      } else {
        HomeMedicalListPage({
          route: this.routeName,
          homeVm: this.homeVm,
          onBack: () => {
            this.pop();
          },
          onOpenFamilyCabinet: () => {
            appRouter.jumpPage(HomeMedicalRoutes.FAMILY_CABINET);
          },
          onOpenPersonalCabinet: () => {
            appRouter.jumpPage(HomeMedicalRoutes.PERSONAL_CABINET);
          }
        })
      }
    }
    .hideTitleBar(true)
    .onShown(() => {
      const homeVm = this.homeVm;
      if (!homeVm) {
        return;
      }
      this.healthExamListRevision = homeVm.healthExamListRevision;
      this.examinationListRevision = homeVm.examinationListRevision;
      this.medicineBoxListRevision = homeVm.medicineBoxListRevision;
    })
    .onBackPressed(() => {
      if (this.routeName === HomeMedicalRoutes.MEMBER_SETUP_CREATE
        || this.routeName === HomeMedicalRoutes.MEMBER_SETUP_MAINTAIN) {
        HomeSetupFlowHolder.clear();
      }
      this.pop();
      return true;
    })
  }
}
