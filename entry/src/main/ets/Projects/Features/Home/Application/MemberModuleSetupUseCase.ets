import { SparkMedicalQueryAPI } from '../../../Core/Networking/API/Medical/MedicalQueryAPI';
import { MemberModuleSettingSavePayload } from '../../../Core/Networking/API/Medical/MedicalWorkflowAPI';
import { RemoteMemberModuleSetting } from '../../../Core/Networking/API/Medical/MedicalSyncAPI';
import { MemberSetupModule } from '../Presentation/Members/MemberSetup/MemberSetupDraft';
import {
  MemberModuleSectionProgressCodec,
  MemberModuleSectionProgressRecord,
  MemberModuleSectionStatus
} from '../Presentation/Members/MemberSetup/MemberModuleSectionProgress';
import { Logger } from '../../../../Foundation/Logging/Logger';
import { LogModule } from '../../../../Foundation/Logging/LogModule';
import { LogFields } from '../../../../Foundation/Logging/LogEvent';

/**
 * 成员健康模块配置用例。与 iOS MemberModuleSetupUseCase 对齐。
 */
export class MemberModuleSetupUseCase {
  private readonly medicalQueryAPI: SparkMedicalQueryAPI;

  constructor(medicalQueryAPI: SparkMedicalQueryAPI) {
    this.medicalQueryAPI = medicalQueryAPI;
  }

  async loadModuleSettings(memberID: number): Promise<RemoteMemberModuleSetting[]> {
    const settings = await this.medicalQueryAPI.listMemberModuleSettings(memberID);
    settings.sort((a: RemoteMemberModuleSetting, b: RemoteMemberModuleSetting): number => {
      return a.displayOrder - b.displayOrder;
    });
    const fields = new LogFields();
    fields.detail = `memberID=${memberID} count=${settings.length}`;
    Logger.info('member.module_settings.load.ok', LogModule.HOME, fields);
    return settings;
  }

  async saveModuleSetting(
    memberID: number,
    moduleCode: string,
    isEnabled: boolean,
    isCompleted: boolean,
    displayOrder: number,
    summaryText: string,
    detailData?: Record<string, string>,
    completedAt?: string,
    extra?: Record<string, string>
  ): Promise<RemoteMemberModuleSetting> {
    const payload = new MemberModuleSettingSavePayload();
    payload.member = memberID;
    payload.module_code = moduleCode;
    payload.is_enabled = isEnabled;
    payload.is_completed = isCompleted;
    payload.display_order = displayOrder;
    payload.summary_text = summaryText;
    payload.detail_data = detailData ?? {};
    payload.completed_at = completedAt;
    payload.extra = extra ?? {};

    const existingList = await this.medicalQueryAPI.listMemberModuleSettings(memberID, moduleCode);
    let saved: RemoteMemberModuleSetting;
    if (existingList.length > 0) {
      saved = await this.medicalQueryAPI.updateMemberModuleSetting(existingList[0].id, payload);
    } else {
      saved = await this.medicalQueryAPI.createMemberModuleSetting(payload);
    }
    const fields = new LogFields();
    fields.detail = `memberID=${memberID} moduleCode=${moduleCode} settingID=${saved.id}`;
    Logger.info('member.module_settings.save.ok', LogModule.HOME, fields);
    return saved;
  }

  async markModuleSelected(
    memberID: number,
    module: MemberSetupModule
  ): Promise<RemoteMemberModuleSetting> {
    const existingList = await this.medicalQueryAPI.listMemberModuleSettings(memberID, module.rawValue);
    const existing = existingList.length > 0 ? existingList[0] : undefined;
    return this.saveModuleSetting(
      memberID,
      module.rawValue,
      true,
      existing ? existing.isCompleted : false,
      module.displayOrder,
      existing ? existing.summaryText : '',
      existing ? existing.detailData : {},
      existing ? existing.completedAt : undefined,
      existing ? existing.extra : {}
    );
  }

  async saveSectionProgress(
    memberID: number,
    module: MemberSetupModule,
    sectionCode: string,
    status: MemberModuleSectionStatus,
    summary: string
  ): Promise<RemoteMemberModuleSetting> {
    const existingList = await this.medicalQueryAPI.listMemberModuleSettings(memberID, module.rawValue);
    const existing = existingList.length > 0 ? existingList[0] : undefined;
    const progressMap = MemberModuleSectionProgressCodec.decode(existing ? existing.extra : undefined);
    const record = new MemberModuleSectionProgressRecord();
    record.sectionCode = sectionCode;
    record.summary = summary;
    record.status = status;
    progressMap[sectionCode] = record;

    const isModuleCompleted = this.isModuleCompleted(progressMap);
    const mergedExtra = MemberModuleSectionProgressCodec.mergeIntoExtra(
      existing ? existing.extra : undefined,
      progressMap
    );
    let completedAt: string | undefined = undefined;
    if (isModuleCompleted) {
      completedAt = existing && existing.completedAt && existing.completedAt.length > 0
        ? existing.completedAt
        : new Date().toISOString();
    }

    return this.saveModuleSetting(
      memberID,
      module.rawValue,
      true,
      isModuleCompleted,
      module.displayOrder,
      summary.length > 0 ? summary : (existing ? existing.summaryText : module.title),
      existing ? existing.detailData : {},
      completedAt,
      mergedExtra
    );
  }

  async sectionProgressMap(
    memberID: number,
    module: MemberSetupModule
  ): Promise<Record<string, MemberModuleSectionProgressRecord>> {
    const existingList = await this.medicalQueryAPI.listMemberModuleSettings(memberID, module.rawValue);
    const existing = existingList.length > 0 ? existingList[0] : undefined;
    return MemberModuleSectionProgressCodec.decode(existing ? existing.extra : undefined);
  }

  private isModuleCompleted(progressMap: Record<string, MemberModuleSectionProgressRecord>): boolean {
    const keys = Object.keys(progressMap);
    for (let i = 0; i < keys.length; i++) {
      if (progressMap[keys[i]].status === MemberModuleSectionStatus.COMPLETED) {
        return true;
      }
    }
    return false;
  }
}
