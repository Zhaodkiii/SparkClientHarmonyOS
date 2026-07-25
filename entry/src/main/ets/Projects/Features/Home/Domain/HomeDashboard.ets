import { UserSession } from '../../../Core/Domain/Entities/UserSession';
import { Member } from '../../../Core/Domain/Entities/Member';
import { RemoteMemberCompleteData } from '../../../Core/Networking/API/Medical/MedicalSyncAPI';

export enum MedicalCardKind {
  MEDICAL_CASES = 'medicalCases',
  HEALTH_EXAM_REPORTS = 'healthExamReports',
  MEDICAL_REPORTS = 'medicalReports',
  MEDICATION_PLANS = 'medicationPlans'
}

export class MedicalCard {
  id: MedicalCardKind;
  count: number;
  latestDate?: string;
  symbol: string;

  constructor(id: MedicalCardKind, count: number, latestDate: string | undefined, symbol: string) {
    this.id = id;
    this.count = count;
    this.latestDate = latestDate;
    this.symbol = symbol;
  }
}

export class HomeMedicalOverview {
  cards: MedicalCard[] = [];
  completeData?: RemoteMemberCompleteData;
}

export class HomeDashboard {
  session: UserSession;
  members: Member[] = [];
  selectedMemberID?: number;
  medical: HomeMedicalOverview = new HomeMedicalOverview();

  constructor(session: UserSession) {
    this.session = session;
  }

  get selectedMember(): Member | undefined {
    if (this.members.length === 0) {
      return undefined;
    }
    if (this.selectedMemberID === undefined || this.selectedMemberID === null) {
      return this.members[0];
    }
    for (let i = 0; i < this.members.length; i++) {
      if (this.members[i].id === this.selectedMemberID) {
        return this.members[i];
      }
    }
    return this.members[0];
  }
}

export class HomeMedicalLoadResult {
  members: Member[] = [];
  selectedMemberID?: number;
  medical: HomeMedicalOverview = new HomeMedicalOverview();
}
