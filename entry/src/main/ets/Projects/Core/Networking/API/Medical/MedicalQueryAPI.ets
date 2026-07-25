import { NetworkRequest, NetworkStrategy, QueryItem, RetryConfig } from '../../SupportNetworkModels';
import { SupportBackendConfiguration } from '../../SupportBackendConfiguration';
import { CacheableSupportNetworkOperation } from '../../Operations/SupportNetworkOperation';
import { SparkMedicalWorkflowAPI, MemberModuleSettingSavePayload } from './MedicalWorkflowAPI';
import { SparkMedicalResourceKind, sparkMedicalResourceKindRaw } from './SparkMedicalResourceKind';
import { MedicalArchiveQuery } from './MedicalArchiveModels';
import {
  RemoteExaminationReportWithAttachments,
  RemoteHealthExamReportWithAttachments,
  RemoteMedicalCaseSummary,
  RemoteMedExamDetail,
  RemoteMedicationPlan,
  RemoteMedicineBox,
  RemoteMember,
  RemoteMemberCompleteData,
  RemoteMemberModuleSetting,
  RemotePrescription
} from './MedicalSyncAPI';

/**
 * 医疗按需查询 API。与 iOS SparkMedicalQueryAPI 对齐。
 */
export class SparkMedicalQueryAPI {
  private readonly configuration: SupportBackendConfiguration;
  private readonly resources: SparkMedicalWorkflowAPI;

  constructor(configuration: SupportBackendConfiguration, workflow?: SparkMedicalWorkflowAPI) {
    this.configuration = configuration;
    this.resources = workflow ?? new SparkMedicalWorkflowAPI(configuration);
  }

  get workflowAPI(): SparkMedicalWorkflowAPI {
    return this.resources;
  }

  async listMembers(): Promise<RemoteMember[]> {
    return this.resources.listMembers();
  }

  async fetchMemberCompleteData(memberID: number): Promise<RemoteMemberCompleteData> {
    const path = `/api/v1/medical/members/${memberID}/complete-data/`;
    const strategy = new NetworkStrategy(
      true,
      true,
      `medical.query.${path}`,
      true,
      'normal',
      RetryConfig.defaultConfig(),
      86400 * 1000
    );
    const op = new CacheableSupportNetworkOperation(
      'Medical.CompleteData',
      'MedicalQueryAPI',
      new NetworkRequest('GET', path, strategy)
    );
    return this.configuration.executeDecoded(op, (data: Object | null) => RemoteMemberCompleteData.fromJson(data));
  }

  async listMemberModuleSettings(memberID: number, moduleCode?: string): Promise<RemoteMemberModuleSetting[]> {
    const extra: QueryItem[] = [new QueryItem('member_id', `${memberID}`)];
    if (moduleCode && moduleCode.length > 0) {
      extra.push(new QueryItem('module_code', moduleCode));
    }
    const raw = await this.resources.listResourceRaw(SparkMedicalResourceKind.MEMBER_MODULE_SETTINGS, extra);
    return RemoteMemberModuleSetting.listFromJson(raw);
  }

  async createMemberModuleSetting(
    payload: MemberModuleSettingSavePayload
  ): Promise<RemoteMemberModuleSetting> {
    return this.resources.createMemberModuleSetting(payload);
  }

  async updateMemberModuleSetting(
    id: number,
    payload: MemberModuleSettingSavePayload
  ): Promise<RemoteMemberModuleSetting> {
    return this.resources.updateMemberModuleSetting(id, payload);
  }

  async listMedicalCaseSummaries(
    memberID?: number,
    archived: MedicalArchiveQuery = MedicalArchiveQuery.ACTIVE
  ): Promise<RemoteMedicalCaseSummary[]> {
    const raw = await this.resources.listResourceRaw(
      SparkMedicalResourceKind.CASES,
      this.archivedQuery(this.memberQuery(memberID), archived)
    );
    return RemoteMedicalCaseSummary.listFromJson(raw);
  }

  async listHealthExamReportsWithAttachments(
    memberID?: number,
    archived: MedicalArchiveQuery = MedicalArchiveQuery.ACTIVE
  ): Promise<RemoteHealthExamReportWithAttachments[]> {
    const raw = await this.resources.listResourceRaw(
      SparkMedicalResourceKind.HEALTH_EXAM_REPORTS,
      this.archivedQuery(this.memberQuery(memberID), archived)
    );
    return RemoteHealthExamReportWithAttachments.listFromJson(raw);
  }

  async retrieveHealthExamReportWithAttachments(
    id: number
  ): Promise<RemoteHealthExamReportWithAttachments> {
    const query: QueryItem[] = [
      new QueryItem('kind', sparkMedicalResourceKindRaw(SparkMedicalResourceKind.HEALTH_EXAM_REPORTS))
    ];
    const path = `/api/v1/medical/resources/${id}/`;
    const strategy = new NetworkStrategy(
      true,
      false,
      `medical.resource.retrieve.health-exam-reports.${id}`,
      true,
      'normal',
      RetryConfig.defaultConfig()
    );
    const op = new CacheableSupportNetworkOperation(
      'Medical.Resource.RetrieveHealthExam',
      'MedicalQueryAPI',
      new NetworkRequest('GET', path, strategy, query)
    );
    return this.configuration.executeDecoded(op, (data: Object | null) =>
      RemoteHealthExamReportWithAttachments.fromJson(data)
    );
  }

  async listMedExamDetails(
    memberID?: number,
    businessType?: string,
    businessID?: number
  ): Promise<RemoteMedExamDetail[]> {
    const q: QueryItem[] = this.memberQuery(memberID);
    if (businessType !== undefined && businessType.length > 0) {
      q.push(new QueryItem('business_type', businessType));
    }
    if (businessID !== undefined && businessID !== null) {
      q.push(new QueryItem('business_id', `${businessID}`));
    }
    const raw = await this.resources.listResourceRaw(SparkMedicalResourceKind.MED_EXAM_DETAILS, q);
    return RemoteMedExamDetail.listFromJson(raw);
  }

  async listExaminationReportsWithAttachments(
    memberID?: number,
    archived: MedicalArchiveQuery = MedicalArchiveQuery.ACTIVE
  ): Promise<RemoteExaminationReportWithAttachments[]> {
    const raw = await this.resources.listResourceRaw(
      SparkMedicalResourceKind.EXAMINATION_REPORTS,
      this.archivedQuery(this.memberQuery(memberID), archived)
    );
    return RemoteExaminationReportWithAttachments.listFromJson(raw);
  }

  async listMedicationPlans(
    memberID?: number,
    archived: MedicalArchiveQuery = MedicalArchiveQuery.ACTIVE
  ): Promise<RemoteMedicationPlan[]> {
    const raw = await this.resources.listResourceRaw(
      SparkMedicalResourceKind.MEDICATION_PLANS,
      this.archivedQuery(this.memberQuery(memberID), archived)
    );
    return RemoteMedicationPlan.listFromJson(raw);
  }

  async listPrescriptions(
    memberID?: number,
    archived: MedicalArchiveQuery = MedicalArchiveQuery.ACTIVE
  ): Promise<RemotePrescription[]> {
    const raw = await this.resources.listResourceRaw(
      SparkMedicalResourceKind.PRESCRIPTIONS,
      this.archivedQuery(this.memberQuery(memberID), archived)
    );
    return RemotePrescription.listFromJson(raw);
  }

  async listMedicineBoxes(
    memberID?: number,
    archived: MedicalArchiveQuery = MedicalArchiveQuery.ACTIVE
  ): Promise<RemoteMedicineBox[]> {
    const raw = await this.resources.listResourceRaw(
      SparkMedicalResourceKind.MEDICINE_BOXES,
      this.archivedQuery(this.memberQuery(memberID), archived)
    );
    return RemoteMedicineBox.listFromJson(raw);
  }

  /** 家庭药箱汇总。与 iOS listFamilyMedicineCabinet 对齐。 */
  async listFamilyMedicineCabinet(memberID: number): Promise<RemoteMedicineBox[]> {
    const path = '/api/v1/medical/medicine-cabinet/summary/';
    const strategy = new NetworkStrategy(
      true,
      true,
      `medical.query.${path}`,
      true,
      'normal',
      RetryConfig.defaultConfig(),
      120 * 1000
    );
    const op = new CacheableSupportNetworkOperation(
      'Medical.FamilyMedicineCabinet',
      'MedicalQueryAPI',
      new NetworkRequest('GET', path, strategy, [new QueryItem('member_id', `${memberID}`)])
    );
    return this.configuration.executeDecoded(op, (data: Object | null) => RemoteMedicineBox.listFromJson(data));
  }

  private memberQuery(memberID?: number): QueryItem[] {
    const query: QueryItem[] = [];
    if (memberID !== undefined && memberID !== null) {
      query.push(new QueryItem('member_id', `${memberID}`));
    }
    return query;
  }

  private archivedQuery(base: QueryItem[], archived: MedicalArchiveQuery): QueryItem[] {
    const query: QueryItem[] = [];
    for (let i = 0; i < base.length; i++) {
      query.push(base[i]);
    }
    query.push(new QueryItem('archived', `${archived}`));
    return query;
  }
}
