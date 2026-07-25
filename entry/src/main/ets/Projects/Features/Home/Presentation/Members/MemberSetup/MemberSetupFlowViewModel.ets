import { Member } from '../../../../../Core/Domain/Entities/Member';
import { ManageHomeMemberUseCase } from '../../../Application/ManageHomeMemberUseCase';
import { MemberModuleSetupUseCase } from '../../../Application/MemberModuleSetupUseCase';
import { MemberRelationshipCatalog } from '../MemberRelationshipCatalog';
import {
  MemberSetupDraft,
  MemberSetupFlowMode,
  MemberSetupModule,
  MemberSetupStep
} from './MemberSetupDraft';
import { RemoteMemberModuleSetting } from '../../../../../Core/Networking/API/Medical/MedicalSyncAPI';

/**
 * 成员建档 / 模块维护流程 VM。与 iOS MemberSetupFlowViewModel 核心路径对齐
 * （create 默认开通 medical；maintain 勾选后 finish 写 enabled=true）。
 */
export class MemberSetupFlowViewModel {
  mode: MemberSetupFlowMode = 'create';
  step: MemberSetupStep = 'nameBirth';
  draft: MemberSetupDraft = new MemberSetupDraft();
  createdMember?: Member;
  selectedModuleCodes: string[] = [];
  completedModuleCodes: string[] = [];
  alertMessage: string = '';
  isSavingMember: boolean = false;
  isPersistingModules: boolean = false;
  isLoadingExistingModules: boolean = false;
  private didLoadExistingModules: boolean = false;
  private onChanged?: () => void;

  private readonly manageHomeMemberUseCase: ManageHomeMemberUseCase;
  private readonly memberModuleSetupUseCase: MemberModuleSetupUseCase;

  constructor(
    mode: MemberSetupFlowMode,
    manageHomeMemberUseCase: ManageHomeMemberUseCase,
    memberModuleSetupUseCase: MemberModuleSetupUseCase,
    maintainMember?: Member
  ) {
    this.mode = mode;
    this.manageHomeMemberUseCase = manageHomeMemberUseCase;
    this.memberModuleSetupUseCase = memberModuleSetupUseCase;
    if (mode === 'maintain' && maintainMember) {
      this.createdMember = maintainMember;
      this.draft.name = maintainMember.name;
      this.draft.birthDate = maintainMember.birthDate;
      this.draft.relationshipCode = MemberRelationshipCatalog.compatibleCode(maintainMember.relationship);
      this.draft.gender = MemberRelationshipCatalog.isSelectableGender(maintainMember.gender)
        ? maintainMember.gender.toLowerCase()
        : MemberRelationshipCatalog.UNSET_GENDER;
      this.step = 'modules';
    }
  }

  setOnChanged(cb: () => void): void {
    this.onChanged = cb;
  }

  private notify(): void {
    if (this.onChanged) {
      this.onChanged();
    }
  }

  get canAdvanceFromBasicInfo(): boolean {
    return this.draft.name.trim().length > 0;
  }

  get canAdvanceFromRelationship(): boolean {
    return MemberRelationshipCatalog.isSelectableGender(this.draft.gender);
  }

  get canFinish(): boolean {
    return this.visibleSelectedCount() > 0
      && !this.isPersistingModules
      && !this.isLoadingExistingModules;
  }

  private visibleSelectedCount(): number {
    let n = 0;
    const visible = MemberSetupModule.allVisible();
    for (let i = 0; i < visible.length; i++) {
      if (this.isModuleSelected(visible[i].rawValue)) {
        n += 1;
      }
    }
    return n;
  }

  isModuleSelected(code: string): boolean {
    return this.selectedModuleCodes.indexOf(code) >= 0;
  }

  isModuleCompleted(code: string): boolean {
    return this.completedModuleCodes.indexOf(code) >= 0;
  }

  goToBirthDate(): void {
    if (!this.canAdvanceFromBasicInfo) {
      return;
    }
    this.step = 'birthDate';
    this.notify();
  }

  goToRelationship(): void {
    this.step = 'relationship';
    this.notify();
  }

  backFromBirthDate(): void {
    this.step = 'nameBirth';
    this.notify();
  }

  backFromRelationship(): void {
    this.step = 'birthDate';
    this.notify();
  }

  setName(name: string): void {
    this.draft.name = name;
    this.notify();
  }

  setBirthDate(value: string): void {
    this.draft.birthDate = value.length > 0 ? value : undefined;
    this.notify();
  }

  selectRelationship(code: string): void {
    this.draft.relationshipCode = code;
    const opt = MemberRelationshipCatalog.option(code);
    if (opt.inferredGender && opt.inferredGender.length > 0) {
      this.draft.gender = opt.inferredGender;
    } else if (code === 'self' || code === 'other') {
      this.draft.gender = MemberRelationshipCatalog.UNSET_GENDER;
    }
    this.notify();
  }

  setGender(gender: string): void {
    this.draft.gender = gender;
    this.notify();
  }

  toggleModule(module: MemberSetupModule): void {
    if (!module.isVisibleInSetup) {
      return;
    }
    const idx = this.selectedModuleCodes.indexOf(module.rawValue);
    if (idx >= 0) {
      this.selectedModuleCodes.splice(idx, 1);
      const cIdx = this.completedModuleCodes.indexOf(module.rawValue);
      if (cIdx >= 0) {
        this.completedModuleCodes.splice(cIdx, 1);
      }
    } else {
      this.selectedModuleCodes.push(module.rawValue);
    }
    this.notify();
  }

  async createMember(): Promise<boolean> {
    if (!this.canAdvanceFromRelationship || this.isSavingMember) {
      return false;
    }
    this.isSavingMember = true;
    this.alertMessage = '';
    this.notify();
    try {
      const member = await this.manageHomeMemberUseCase.create(
        this.draft.name.trim(),
        this.draft.relationshipCode,
        this.draft.gender,
        this.draft.birthDate
      );
      this.createdMember = member;
      return true;
    } catch (e) {
      this.alertMessage = `添加成员失败：${e}`;
      return false;
    } finally {
      this.isSavingMember = false;
      this.notify();
    }
  }

  async enableDefaultMedicalModuleForCreatedMember(): Promise<boolean> {
    const member = this.createdMember;
    if (!member || this.isPersistingModules) {
      return false;
    }
    this.selectedModuleCodes = [MemberSetupModule.MEDICAL.rawValue];
    const cIdx = this.completedModuleCodes.indexOf(MemberSetupModule.MEDICAL.rawValue);
    if (cIdx >= 0) {
      this.completedModuleCodes.splice(cIdx, 1);
    }
    this.isPersistingModules = true;
    this.notify();
    try {
      await this.memberModuleSetupUseCase.saveModuleSetting(
        member.id,
        MemberSetupModule.MEDICAL.rawValue,
        true,
        false,
        MemberSetupModule.MEDICAL.displayOrder,
        '',
        {},
        undefined,
        {}
      );
      return true;
    } catch (e) {
      this.alertMessage = `${e}`;
      return false;
    } finally {
      this.isPersistingModules = false;
      this.notify();
    }
  }

  async loadExistingModuleSettingsIfNeeded(): Promise<void> {
    if (this.mode !== 'maintain' || this.didLoadExistingModules) {
      return;
    }
    const member = this.createdMember;
    if (!member) {
      return;
    }
    this.didLoadExistingModules = true;
    this.isLoadingExistingModules = true;
    this.notify();
    try {
      const settings = await this.memberModuleSetupUseCase.loadModuleSettings(member.id);
      this.applySettings(settings);
    } catch (e) {
      this.alertMessage = `模块配置加载失败：${e}`;
    } finally {
      this.isLoadingExistingModules = false;
      this.notify();
    }
  }

  private applySettings(settings: RemoteMemberModuleSetting[]): void {
    const selected: string[] = [];
    const completed: string[] = [];
    for (let i = 0; i < settings.length; i++) {
      const s = settings[i];
      const module = MemberSetupModule.fromRaw(s.moduleCode);
      if (!module || !module.isVisibleInSetup) {
        continue;
      }
      if (s.isEnabled) {
        selected.push(module.rawValue);
        if (s.isCompleted) {
          completed.push(module.rawValue);
        }
      }
    }
    this.selectedModuleCodes = selected;
    this.completedModuleCodes = completed;
  }

  async finish(): Promise<boolean> {
    const member = this.createdMember;
    if (!member || this.isPersistingModules) {
      return false;
    }
    this.isPersistingModules = true;
    this.alertMessage = '';
    this.notify();
    try {
      const visible = MemberSetupModule.allVisible();
      for (let i = 0; i < visible.length; i++) {
        const module = visible[i];
        if (!this.isModuleSelected(module.rawValue)) {
          continue;
        }
        const isCompleted = this.isModuleCompleted(module.rawValue);
        await this.memberModuleSetupUseCase.saveModuleSetting(
          member.id,
          module.rawValue,
          true,
          isCompleted,
          module.displayOrder,
          isCompleted ? module.title : '',
          {},
          isCompleted ? new Date().toISOString() : undefined,
          {}
        );
      }
      return true;
    } catch (e) {
      this.alertMessage = `${e}`;
      return false;
    } finally {
      this.isPersistingModules = false;
      this.notify();
    }
  }

  clearAlert(): void {
    this.alertMessage = '';
    this.notify();
  }
}
