import { UserSession } from '../../../Core/Domain/Entities/UserSession';
import { SparkMedicalQueryAPI } from '../../../Core/Networking/API/Medical/MedicalQueryAPI';
import { remoteMembersToDomain } from '../../../Core/Networking/API/Medical/MedicalRemoteDTO+Domain';
import { RemoteMemberCompleteData } from '../../../Core/Networking/API/Medical/MedicalSyncAPI';
import { SelectedMemberIDStore } from '../../MemberContext/Infrastructure/SelectedMemberIDStore';
import {
  HomeMedicalLoadResult,
  HomeMedicalOverview,
  MedicalCard,
  MedicalCardKind
} from '../Domain/HomeDashboard';
import { Logger } from '../../../../Foundation/Logging/Logger';
import { LogModule } from '../../../../Foundation/Logging/LogModule';
import { LogFields } from '../../../../Foundation/Logging/LogEvent';
import { Member } from '../../../Core/Domain/Entities/Member';

/**
 * 首页医疗摘要加载：成员列表 + complete-data。与 iOS LoadHomeMedicalOverviewUseCase 对齐。
 */
export class LoadHomeMedicalOverviewUseCase {
  private readonly medicalQueryAPI: SparkMedicalQueryAPI;
  private readonly selectedMemberIDPersistence: SelectedMemberIDStore;

  constructor(medicalQueryAPI: SparkMedicalQueryAPI, selectedMemberIDPersistence: SelectedMemberIDStore) {
    this.medicalQueryAPI = medicalQueryAPI;
    this.selectedMemberIDPersistence = selectedMemberIDPersistence;
  }

  async execute(
    session: UserSession,
    selectedMemberID: number | undefined,
    refreshRemoteSnapshot: boolean
  ): Promise<HomeMedicalLoadResult> {
    const started = Date.now();
    const remotes = await this.medicalQueryAPI.listMembers();
    const members = this.sortMembers(remoteMembersToDomain(remotes));
    const resolved = await this.resolveSelectedID(session.accountId, members, selectedMemberID);

    const medical = new HomeMedicalOverview();
    if (resolved !== undefined && resolved !== null) {
      let complete: RemoteMemberCompleteData | undefined = undefined;
      try {
        complete = await this.medicalQueryAPI.fetchMemberCompleteData(resolved);
      } catch (e) {
        const fields = new LogFields();
        fields.detail = `${e}`;
        Logger.warn('home.complete_data.degraded', LogModule.HOME, fields);
        complete = undefined;
      }
      medical.completeData = complete;
      medical.cards = this.makeMedicalCards(complete);
    } else {
      medical.cards = this.emptyMedicalCards();
      medical.completeData = undefined;
    }

    const fields = new LogFields();
    fields.elapsedMs = Date.now() - started;
    fields.detail = `refreshRemote=${refreshRemoteSnapshot};member=${resolved ?? 'nil'};cards=${medical.cards.length}`;
    Logger.info('home.medical_overview.done', LogModule.HOME, fields);

    const result = new HomeMedicalLoadResult();
    result.members = members;
    result.selectedMemberID = resolved;
    result.medical = medical;
    return result;
  }

  private sortMembers(members: Member[]): Member[] {
    const copy: Member[] = [];
    for (let i = 0; i < members.length; i++) {
      copy.push(members[i]);
    }
    copy.sort((lhs: Member, rhs: Member): number => {
      if (lhs.isPrimary === rhs.isPrimary) {
        return rhs.updatedAt > lhs.updatedAt ? 1 : (rhs.updatedAt < lhs.updatedAt ? -1 : 0);
      }
      if (lhs.isPrimary && !rhs.isPrimary) {
        return -1;
      }
      if (!lhs.isPrimary && rhs.isPrimary) {
        return 1;
      }
      return 0;
    });
    return copy;
  }

  private async resolveSelectedID(
    accountID: number,
    members: Member[],
    selectedMemberID: number | undefined
  ): Promise<number | undefined> {
    if (members.length === 0) {
      return undefined;
    }
    const persisted = await this.selectedMemberIDPersistence.load(accountID);
    const preferred = selectedMemberID !== undefined ? selectedMemberID : persisted;
    if (preferred !== undefined && preferred !== null) {
      for (let i = 0; i < members.length; i++) {
        if (members[i].id === preferred) {
          return preferred;
        }
      }
    }
    return members[0].id;
  }

  private emptyMedicalCards(): MedicalCard[] {
    return [
      new MedicalCard(MedicalCardKind.MEDICAL_CASES, 0, undefined, 'doc'),
      new MedicalCard(MedicalCardKind.HEALTH_EXAM_REPORTS, 0, undefined, 'heart'),
      new MedicalCard(MedicalCardKind.MEDICAL_REPORTS, 0, undefined, 'clipboard'),
      new MedicalCard(MedicalCardKind.MEDICATION_PLANS, 0, undefined, 'calendar')
    ];
  }

  private makeMedicalCards(complete: RemoteMemberCompleteData | undefined): MedicalCard[] {
    if (!complete) {
      return this.emptyMedicalCards();
    }
    const cases = complete.medicalCases;
    const health = complete.healthExamReports;
    const exams = complete.examinationReports;
    const plans = complete.medicationPlans;

    let caseLatest: string | undefined = undefined;
    for (let i = 0; i < cases.length; i++) {
      const u = cases[i].updatedAt;
      if (u && (!caseLatest || u > caseLatest)) {
        caseLatest = u;
      }
    }
    let healthLatest: string | undefined = undefined;
    for (let i = 0; i < health.length; i++) {
      const d = health[i].examDate;
      if (d && (!healthLatest || d > healthLatest)) {
        healthLatest = d;
      }
    }
    let examLatest: string | undefined = undefined;
    for (let i = 0; i < exams.length; i++) {
      const d = exams[i].reportedAt ?? exams[i].performedAt;
      if (d && (!examLatest || d > examLatest)) {
        examLatest = d;
      }
    }
    let planLatest: string | undefined = undefined;
    let activeCount = 0;
    if (complete.medicationSummary) {
      activeCount = complete.medicationSummary.activePlanCount;
    } else {
      for (let i = 0; i < plans.length; i++) {
        if (plans[i].status === 'active') {
          activeCount += 1;
        }
      }
    }
    for (let i = 0; i < plans.length; i++) {
      const u = plans[i].updatedAt;
      if (u && (!planLatest || u > planLatest)) {
        planLatest = u;
      }
    }

    return [
      new MedicalCard(MedicalCardKind.MEDICAL_CASES, cases.length, caseLatest, 'doc'),
      new MedicalCard(MedicalCardKind.HEALTH_EXAM_REPORTS, health.length, healthLatest, 'heart'),
      new MedicalCard(MedicalCardKind.MEDICAL_REPORTS, exams.length, examLatest, 'clipboard'),
      new MedicalCard(MedicalCardKind.MEDICATION_PLANS, activeCount, planLatest, 'calendar')
    ];
  }
}
