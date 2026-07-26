import { SparkMedicalQueryAPI } from '../../../../../Core/Networking/API/Medical/MedicalQueryAPI';
import { MedicalArchiveQuery } from '../../../../../Core/Networking/API/Medical/MedicalArchiveModels';
import { RemoteMedicineBox } from '../../../../../Core/Networking/API/Medical/MedicalSyncAPI';
import { Member } from '../../../../../Core/Domain/Entities/Member';
import { Logger } from '../../../../../../Foundation/Logging/Logger';
import { LogFields } from '../../../../../../Foundation/Logging/LogEvent';
import { LogModule } from '../../../../../../Foundation/Logging/LogModule';
import { MedicineBoxMode } from './MedicineBoxMode';
import { MedicineBoxTypeCatalog } from './MedicineBoxTypeCatalog';

/** 对齐 iOS `FamilyMedicineCabinetViewModel.MemberFilter` */
export class MemberFilter {
  kind: string = 'all';
  memberID: number = 0;

  static all(): MemberFilter {
    const filter = new MemberFilter();
    filter.kind = 'all';
    return filter;
  }

  static householdPublic(): MemberFilter {
    const filter = new MemberFilter();
    filter.kind = 'public';
    return filter;
  }

  static member(id: number): MemberFilter {
    const filter = new MemberFilter();
    filter.kind = 'member';
    filter.memberID = id;
    return filter;
  }

  key(): string {
    if (this.kind === 'member') {
      return `member:${this.memberID}`;
    }
    return this.kind;
  }

  equals(other: MemberFilter): boolean {
    return this.key() === other.key();
  }
}

export class MemberFilterOption {
  filter: MemberFilter = MemberFilter.all();
  title: string = '';
}

/**
 * 对齐 iOS `FamilyMedicineCabinetViewModel`：
 * 加载、筛选、upsert/remove、首页缓存同步列表。
 */
@Observed
export class FamilyMedicineCabinetViewModel {
  entryMemberID: number = 0;
  mode: MedicineBoxMode = MedicineBoxMode.FAMILY;
  archiveMode: boolean = false;

  allBoxes: RemoteMedicineBox[] = [];
  isLoading: boolean = false;
  errorMessage: string = '';
  searchText: string = '';
  selectedTypeTab: string = '';
  memberFilter: MemberFilter = MemberFilter.all();
  /** 驱动 UI 刷新的修订号（@Observed 数组就地修改时兜底） */
  revision: number = 0;

  private medicalQueryAPI?: SparkMedicalQueryAPI;

  constructor(
    entryMemberID: number,
    mode: MedicineBoxMode,
    initialBoxes: RemoteMedicineBox[],
    medicalQueryAPI?: SparkMedicalQueryAPI
  ) {
    this.entryMemberID = entryMemberID;
    this.mode = mode;
    this.medicalQueryAPI = medicalQueryAPI;
    this.allBoxes = FamilyMedicineCabinetViewModel.sortedByUpdatedAt(initialBoxes);
  }

  get showsMemberFilter(): boolean {
    return this.mode === MedicineBoxMode.FAMILY && !this.archiveMode;
  }

  static shouldLoadFamilyMedicineOnAppear(cachedBoxes?: RemoteMedicineBox[]): boolean {
    return !cachedBoxes || cachedBoxes.length === 0;
  }

  static sortedByUpdatedAt(boxes: RemoteMedicineBox[]): RemoteMedicineBox[] {
    const copy: RemoteMedicineBox[] = [];
    for (let i = 0; i < boxes.length; i++) {
      copy.push(boxes[i]);
    }
    copy.sort((a: RemoteMedicineBox, b: RemoteMedicineBox): number => {
      return (b.updatedAt ?? '').localeCompare(a.updatedAt ?? '');
    });
    return copy;
  }

  get boxesForHomeCacheSync(): RemoteMedicineBox[] {
    return FamilyMedicineCabinetViewModel.sortedByUpdatedAt(this.allBoxes);
  }

  get boxesForFamilyHomeCacheSync(): RemoteMedicineBox[] {
    return this.boxesForHomeCacheSync;
  }

  get filteredBoxes(): RemoteMedicineBox[] {
    let items: RemoteMedicineBox[] = [];
    for (let i = 0; i < this.allBoxes.length; i++) {
      const box = this.allBoxes[i];
      if (!this.archiveMode && box.isArchived) {
        continue;
      }
      if (this.archiveMode && !box.isArchived) {
        continue;
      }
      items.push(box);
    }

    if (this.mode === MedicineBoxMode.FAMILY && !this.archiveMode) {
      if (this.memberFilter.kind === 'public') {
        const next: RemoteMedicineBox[] = [];
        for (let i = 0; i < items.length; i++) {
          if (items[i].member === undefined) {
            next.push(items[i]);
          }
        }
        items = next;
      } else if (this.memberFilter.kind === 'member') {
        const wanted = this.memberFilter.memberID;
        const next: RemoteMedicineBox[] = [];
        for (let i = 0; i < items.length; i++) {
          if (items[i].member === wanted) {
            next.push(items[i]);
          }
        }
        items = next;
      }
    }

    const typeKey = MedicineBoxTypeCatalog.storedValue(this.selectedTypeTab);
    if (typeKey.length > 0) {
      const next: RemoteMedicineBox[] = [];
      for (let i = 0; i < items.length; i++) {
        if (MedicineBoxTypeCatalog.storedValue(items[i].medicineType) === typeKey) {
          next.push(items[i]);
        }
      }
      items = next;
    }

    const query = this.searchText.trim().toLowerCase();
    if (query.length > 0) {
      const next: RemoteMedicineBox[] = [];
      for (let i = 0; i < items.length; i++) {
        const box = items[i];
        const haystack =
          `${box.medicineName} ${box.brandName} ${box.strength} ${box.dosageForm}`.toLowerCase();
        if (haystack.indexOf(query) >= 0) {
          next.push(box);
        }
      }
      items = next;
    }

    return FamilyMedicineCabinetViewModel.sortedByUpdatedAt(items);
  }

  medicineTypeOptions(): string[] {
    return MedicineBoxTypeCatalog.options(this.allBoxes);
  }

  memberFilterOptions(members: Member[]): MemberFilterOption[] {
    const options: MemberFilterOption[] = [];
    const all = new MemberFilterOption();
    all.filter = MemberFilter.all();
    all.title = '全部';
    options.push(all);

    const publicOpt = new MemberFilterOption();
    publicOpt.filter = MemberFilter.householdPublic();
    publicOpt.title = '家庭公共';
    options.push(publicOpt);

    const memberIDs: number[] = [];
    for (let i = 0; i < this.allBoxes.length; i++) {
      const memberID = this.allBoxes[i].member;
      if (memberID !== undefined && memberIDs.indexOf(memberID) < 0) {
        memberIDs.push(memberID);
      }
    }
    memberIDs.sort((a: number, b: number): number => a - b);

    for (let i = 0; i < memberIDs.length; i++) {
      const id = memberIDs[i];
      let name = `成员${id}`;
      for (let j = 0; j < members.length; j++) {
        if (members[j].id === id) {
          name = members[j].name.length > 0 ? members[j].name : name;
          break;
        }
      }
      const opt = new MemberFilterOption();
      opt.filter = MemberFilter.member(id);
      opt.title = name;
      options.push(opt);
    }
    return options;
  }

  setMemberFilter(filter: MemberFilter): void {
    this.memberFilter = filter;
    this.bump();
  }

  setSelectedTypeTab(tab: string): void {
    this.selectedTypeTab = tab;
    this.bump();
  }

  setSearchText(text: string): void {
    this.searchText = text;
    this.bump();
  }

  setArchiveMode(value: boolean): void {
    this.archiveMode = value;
    this.memberFilter = MemberFilter.all();
    this.selectedTypeTab = '';
    this.bump();
  }

  replaceFromCache(boxes: RemoteMedicineBox[]): void {
    this.allBoxes = FamilyMedicineCabinetViewModel.sortedByUpdatedAt(boxes);
    this.revision += 1;
  }

  upsert(box: RemoteMedicineBox): void {
    if (!this.archiveMode && box.isArchived) {
      this.remove(box.id);
      return;
    }
    if (this.archiveMode && !box.isArchived) {
      this.remove(box.id);
      return;
    }
    const next: RemoteMedicineBox[] = [];
    let found = false;
    for (let i = 0; i < this.allBoxes.length; i++) {
      if (this.allBoxes[i].id === box.id) {
        next.push(box);
        found = true;
      } else {
        next.push(this.allBoxes[i]);
      }
    }
    if (!found) {
      next.unshift(box);
    }
    this.allBoxes = FamilyMedicineCabinetViewModel.sortedByUpdatedAt(next);
    this.bump();
  }

  remove(id: number): void {
    const next: RemoteMedicineBox[] = [];
    for (let i = 0; i < this.allBoxes.length; i++) {
      if (this.allBoxes[i].id !== id) {
        next.push(this.allBoxes[i]);
      }
    }
    this.allBoxes = next;
    this.bump();
  }

  clearError(): void {
    this.errorMessage = '';
    this.bump();
  }

  async load(): Promise<boolean> {
    const query = this.medicalQueryAPI;
    if (!query || this.entryMemberID <= 0) {
      this.errorMessage = '未选中成员，无法加载药箱';
      this.bump();
      return false;
    }
    if (this.isLoading) {
      return false;
    }
    this.isLoading = true;
    this.errorMessage = '';
    this.bump();
    const requestMemberID = this.entryMemberID;
    try {
      let result: RemoteMedicineBox[] = [];
      if (this.archiveMode || this.mode === MedicineBoxMode.PERSONAL) {
        result = await query.listMedicineBoxes(
          requestMemberID,
          this.archiveMode ? MedicalArchiveQuery.ARCHIVED : MedicalArchiveQuery.ACTIVE
        );
      } else {
        result = await query.listFamilyMedicineCabinet(requestMemberID);
      }
      if (requestMemberID !== this.entryMemberID) {
        this.isLoading = false;
        this.bump();
        return false;
      }
      this.allBoxes = FamilyMedicineCabinetViewModel.sortedByUpdatedAt(result);
      this.isLoading = false;
      this.bump();
      const fields = new LogFields();
      fields.operation = this.mode === MedicineBoxMode.FAMILY ? 'family_load' : 'personal_load';
      fields.code = requestMemberID;
      fields.detail = `count=${result.length} archive=${this.archiveMode}`;
      Logger.info('home.medicine_box.load_ok', LogModule.HOME, fields);
      return true;
    } catch (e) {
      this.isLoading = false;
      this.errorMessage = `${e}`.substring(0, 160);
      this.bump();
      const fields = new LogFields();
      fields.operation = this.mode === MedicineBoxMode.FAMILY ? 'family_load_failed' : 'personal_load_failed';
      fields.code = requestMemberID;
      fields.detail = `archive=${this.archiveMode}`;
      Logger.warn('home.medicine_box.load_failed', LogModule.HOME, fields);
      return false;
    }
  }

  private bump(): void {
    this.revision += 1;
  }
}
