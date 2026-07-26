import { NetworkRequest, NetworkStrategy, QueryItem, RetryConfig } from '../../SupportNetworkModels';
import { SupportBackendConfiguration } from '../../SupportBackendConfiguration';
import { CacheableSupportNetworkOperation } from '../../Operations/SupportNetworkOperation';
import { SupportAPIResponseDecoder } from '../Common/SupportAPIResponseDecoder';
import { SparkMedicalResourceKind, sparkMedicalResourceKindRaw } from './SparkMedicalResourceKind';
import {
  RemoteExaminationReportWithAttachments,
  RemoteHealthExamReportWithAttachments,
  RemoteMember,
  RemoteMemberModuleSetting,
  RemoteMedicationRecord
} from './MedicalSyncAPI';
import { RemoteMedicineBox } from './MedicalSyncAPI';

const RESOURCE_COLLECTION_PATH: string = '/api/v1/medical/resources/';
/** 对齐 iOS MedicalWorkflowAPI：allowETag 时 etagTTL = 120s */
const RESOURCE_ETAG_TTL_MS: number = 120 * 1000;

/** 体检明细写入行（snake_case JSON）。 */
export class HealthExamDetailSaveRow {
  category: string = '';
  sub_category: string = '';
  item_name: string = '';
  item_code: string = '';
  result_value: string = '';
  unit: string = '';
  reference_range: string = '';
  flag: string = '';
  result_at?: string;
  modality: string = '';
  body_part: string = '';
  diagnosis: string = '';
  sort_order: number = 0;
}

/** 体检工作流保存请求体。对齐 iOS HealthExamSavePayload。 */
export class HealthExamSavePayload {
  member: number = 0;
  institution_name: string = '';
  report_no: string = '';
  exam_date?: string;
  exam_type: number = 1;
  summary?: string;
  source: number = 2;
  raw_ocr?: Record<string, string>;
  status: number = 1;
  extra: Record<string, string> = {};
  details: HealthExamDetailSaveRow[] = [];
  file_ids: number[] = [];
}

/**
 * 成员模块配置写载荷（snake_case JSON）。对齐 iOS MemberModuleSettingSavePayload + Serializer。
 */
export class MemberModuleSettingSavePayload {
  member: number = 0;
  module_code: string = '';
  is_enabled: boolean = false;
  is_completed: boolean = false;
  display_order: number = 0;
  summary_text: string = '';
  detail_data: Record<string, string> = {};
  completed_at?: string;
  extra: Record<string, string> = {};
}

/**
 * 成员创建/更新载荷（snake_case）。对齐 Django MemberSerializer。
 */
export class UpsertMemberPayload {
  name: string = '';
  relationship: string = 'self';
  gender: string = 'unknown';
  birth_date?: string;
  blood_type: string = '';
  allergies: string[] = [];
  chronic_conditions: string[] = [];
  notes: string = '';
  avatar_url: string = '';
  is_primary: boolean = false;
}

/** 药箱创建/更新请求体。字段名使用后端 snake_case 契约。 */
export class MedicineBoxWritePayload {
  member?: number;
  entry_member_id: number = 0;
  medicine_name: string = '';
  medicine_type?: string;
  brand_name: string = '';
  dosage_form: string = '';
  strength: string = '';
  dose_unit: string = '';
  total_quantity?: number;
  expire_date?: string;
  notes: string = '';
  extra: Record<string, string> = {};
  file_ids: number[] = [];
}

/** 检查/检验报告明细行。对齐 iOS MedicalReportDetailPayload。 */
export class MedicalReportDetailPayload {
  category: string = '';
  sub_category: string = '';
  item_name: string = '';
  item_code: string = '';
  result_value: string = '';
  unit: string = '';
  reference_range: string = '';
  flag: string = '';
  result_at?: string;
  modality: string = '';
  body_part: string = '';
  diagnosis: string = '';
  extra: Record<string, string> = {};
  sort_order: number = 0;
}

/** 独立新增检查报告。对齐 iOS MedicalReportSavePayload。 */
export class MedicalReportSavePayload {
  member: number = 0;
  medical_case?: number;
  category: string = '';
  sub_category: string = '';
  item_name: string = '';
  performed_at?: string;
  reported_at?: string;
  organization_name?: string;
  department_name: string = '';
  doctor_name: string = '';
  findings: string = '';
  impression: string = '';
  modality: string = '';
  body_part: string = '';
  diagnosis: string = '';
  file_ids: number[] = [];
  details: MedicalReportDetailPayload[] = [];
}

/** 用药计划 bundle 内嵌药箱。 */
export class MedicationPlanMedicineBoxPayload {
  medicine_type?: string;
  medicine_name: string = '';
  brand_name: string = '';
  dosage_form: string = '';
  strength: string = '';
  dose_unit: string = '';
  total_quantity?: number;
  expire_date?: string;
  notes: string = '';
  extra: Record<string, string> = {};
  file_ids: number[] = [];
}

/** 提醒时间点（网络层）。 */
export class ReminderTimeNetworkPayload {
  time: string = '';
  dose?: number;
  dose_text?: string;
}

/** 用药计划 bundle 明细项。对齐 iOS MedicationPlanBundleItemPayload。 */
export class MedicationPlanBundleItemNetworkPayload {
  medicine_box_id?: number;
  medicine_box?: MedicationPlanMedicineBoxPayload;
  drug_name: string = '';
  dose_per_time: string = '';
  dose_value?: string;
  dose_unit: string = '';
  frequency_type: string = 'daily';
  every_n_days?: number;
  weekly_weekdays: number[] = [];
  frequency_text: string = '';
  reminder_times: ReminderTimeNetworkPayload[] = [];
  start_date: string = '';
  end_date?: string;
  instructions: string = '';
  reminder_enabled: boolean = false;
  status: string = 'active';
  extra: Record<string, string> = {};
  file_ids: number[] = [];
}

/** 处方摘要（bundle 内嵌）。 */
export class PrescriptionNetworkPayload {
  medical_case?: number;
  prescriber_name?: string;
  institution_name?: string;
  prescribed_at?: string;
  diagnosis?: string;
  prescription_no?: string;
  status: string = 'active';
  extra: Record<string, string> = {};
}

/** 用药计划 bundle 保存。 */
export class MedicationPlanBundleSavePayload {
  member: number = 0;
  medical_case?: number;
  prescription_id?: number;
  prescription?: PrescriptionNetworkPayload;
  items: MedicationPlanBundleItemNetworkPayload[] = [];
  file_ids: number[] = [];
}

export class MedicationPlanBundleSaveResponse {
  id: number = 0;
  prescription_id?: number;
}

/** 批量处方保存中的单条处方。 */
export class PrescriptionBatchItemPayload {
  medical_case?: number;
  prescriber_name?: string;
  institution_name?: string;
  prescribed_at?: string;
  diagnosis?: string;
  prescription_no?: string;
  status: string = 'active';
  extra: Record<string, string> = {};
  medication_plans: MedicationPlanBundleItemNetworkPayload[] = [];
  source_file_ids: number[] = [];
}

export class PrescriptionBatchSavePayload {
  member: number = 0;
  prescriptions: PrescriptionBatchItemPayload[] = [];
}

export class PrescriptionBatchSaveResponse {
  member_id: number = 0;
  prescription_ids: number[] = [];
  medicine_box_ids: number[] = [];
  medication_plan_ids: number[] = [];
}

/**
 * 统一医疗资源工作流 API。与 iOS SparkMedicalWorkflowAPI 对齐。
 */
export class SparkMedicalWorkflowAPI {
  private readonly configuration: SupportBackendConfiguration;

  constructor(configuration: SupportBackendConfiguration) {
    this.configuration = configuration;
  }

  async listMembers(): Promise<RemoteMember[]> {
    return this.listRemoteMembers(SparkMedicalResourceKind.MEMBERS);
  }

  async listRemoteMembers(kind: SparkMedicalResourceKind): Promise<RemoteMember[]> {
    const query: QueryItem[] = [new QueryItem('kind', sparkMedicalResourceKindRaw(kind))];
    const strategy = this.listStrategy(kind);
    const op = new CacheableSupportNetworkOperation(
      'Medical.Resource.ListMembers',
      'MedicalWorkflowAPI',
      new NetworkRequest('GET', RESOURCE_COLLECTION_PATH, strategy, query)
    );
    return this.configuration.executeDecoded(op, (data: Object | null) => RemoteMember.listFromJson(data));
  }

  async listResourceRaw(kind: SparkMedicalResourceKind, extraQuery: QueryItem[]): Promise<Object | null> {
    const query: QueryItem[] = [new QueryItem('kind', sparkMedicalResourceKindRaw(kind))];
    for (let i = 0; i < extraQuery.length; i++) {
      query.push(extraQuery[i]);
    }
    const strategy = this.listStrategy(kind);
    const op = new CacheableSupportNetworkOperation(
      'Medical.Resource.List',
      'MedicalWorkflowAPI',
      new NetworkRequest('GET', RESOURCE_COLLECTION_PATH, strategy, query)
    );
    return this.configuration.executeDecoded(op, (data: Object | null) => data);
  }

  /** POST /api/v1/medical/workflows/health-exams/save/ → data.id */
  async saveHealthExam(payload: HealthExamSavePayload): Promise<number> {
    return this.postWorkflowId('/api/v1/medical/workflows/health-exams/save/',
      'Medical.Workflow.HealthExamSave', payload as Object);
  }

  /** POST /api/v1/medical/workflows/medical-reports/create/ → data.id */
  async createMedicalReport(payload: MedicalReportSavePayload): Promise<number> {
    return this.postWorkflowId('/api/v1/medical/workflows/medical-reports/create/',
      'Medical.Workflow.MedicalReportCreate', payload as Object);
  }

  /** POST /api/v1/medical/workflows/medication-plans/save/ */
  async saveMedicationPlanBundleResponse(
    payload: MedicationPlanBundleSavePayload
  ): Promise<MedicationPlanBundleSaveResponse> {
    const path = '/api/v1/medical/workflows/medication-plans/save/';
    const strategy = new NetworkStrategy(
      true,
      false,
      `medical.workflow.${path}`,
      false,
      'high',
      RetryConfig.disabled()
    );
    const op = new CacheableSupportNetworkOperation(
      'Medical.Workflow.MedicationPlanBundleSave',
      'MedicalWorkflowAPI',
      new NetworkRequest('POST', path, strategy, [], {}, payload as Object)
    );
    return this.configuration.executeDecoded(op, (data: Object | null) => {
      const obj = SupportAPIResponseDecoder.asRecord(data);
      const out = new MedicationPlanBundleSaveResponse();
      out.id = SupportAPIResponseDecoder.num(obj, 'id', 0);
      const rx = SupportAPIResponseDecoder.num(obj, 'prescription_id', 0);
      out.prescription_id = rx > 0 ? rx : undefined;
      return out;
    });
  }

  /** POST /api/v1/medical/workflows/prescriptions/batch-save/ */
  async savePrescriptionsBatch(
    payload: PrescriptionBatchSavePayload
  ): Promise<PrescriptionBatchSaveResponse> {
    const path = '/api/v1/medical/workflows/prescriptions/batch-save/';
    const strategy = new NetworkStrategy(
      true,
      false,
      `medical.workflow.${path}`,
      false,
      'high',
      RetryConfig.disabled()
    );
    const op = new CacheableSupportNetworkOperation(
      'Medical.Workflow.PrescriptionBatchSave',
      'MedicalWorkflowAPI',
      new NetworkRequest('POST', path, strategy, [], {}, payload as Object)
    );
    return this.configuration.executeDecoded(op, (data: Object | null) => {
      const obj = SupportAPIResponseDecoder.asRecord(data);
      const out = new PrescriptionBatchSaveResponse();
      out.member_id = SupportAPIResponseDecoder.num(obj, 'member_id', 0);
      out.prescription_ids = SparkMedicalWorkflowAPI.readIdArray(obj, 'prescription_ids');
      out.medicine_box_ids = SparkMedicalWorkflowAPI.readIdArray(obj, 'medicine_box_ids');
      out.medication_plan_ids = SparkMedicalWorkflowAPI.readIdArray(obj, 'medication_plan_ids');
      return out;
    });
  }

  private async postWorkflowId(path: string, name: string, body: Object): Promise<number> {
    const strategy = new NetworkStrategy(
      true,
      false,
      `medical.workflow.${path}`,
      false,
      'high',
      RetryConfig.disabled()
    );
    const op = new CacheableSupportNetworkOperation(
      name,
      'MedicalWorkflowAPI',
      new NetworkRequest('POST', path, strategy, [], {}, body)
    );
    return this.configuration.executeDecoded(op, (data: Object | null) => {
      const obj = SupportAPIResponseDecoder.asRecord(data);
      return SupportAPIResponseDecoder.num(obj, 'id', 0);
    });
  }

  async deleteResource(kind: SparkMedicalResourceKind, id: number): Promise<void> {
    const query: QueryItem[] = [new QueryItem('kind', sparkMedicalResourceKindRaw(kind))];
    const strategy = new NetworkStrategy(
      true,
      false,
      `medical.resource.delete.${sparkMedicalResourceKindRaw(kind)}.${id}`,
      false,
      'high',
      RetryConfig.disabled()
    );
    const op = new CacheableSupportNetworkOperation(
      'Medical.Resource.Delete',
      'MedicalWorkflowAPI',
      new NetworkRequest('DELETE', this.resourceItemPath(id), strategy, query)
    );
    await this.configuration.executeDecoded(op, (_data: Object | null) => {
      return true;
    });
  }

  async setHealthExamArchived(
    id: number,
    archived: boolean
  ): Promise<RemoteHealthExamReportWithAttachments> {
    const body: Record<string, boolean> = {};
    body['is_archived'] = archived;
    const query: QueryItem[] = [
      new QueryItem('kind', sparkMedicalResourceKindRaw(SparkMedicalResourceKind.HEALTH_EXAM_REPORTS))
    ];
    const strategy = new NetworkStrategy(
      true,
      false,
      `medical.resource.patch.${sparkMedicalResourceKindRaw(SparkMedicalResourceKind.HEALTH_EXAM_REPORTS)}.${id}`,
      false,
      'high',
      RetryConfig.disabled()
    );
    const op = new CacheableSupportNetworkOperation(
      'Medical.Resource.SetArchived',
      'MedicalWorkflowAPI',
      new NetworkRequest('PATCH', this.resourceItemPath(id), strategy, query, {}, body)
    );
    return this.configuration.executeDecoded(op, (data: Object | null) =>
      RemoteHealthExamReportWithAttachments.fromJson(data)
    );
  }

  async setExaminationArchived(
    id: number,
    archived: boolean
  ): Promise<RemoteExaminationReportWithAttachments> {
    const body: Record<string, boolean> = {};
    body['is_archived'] = archived;
    const query: QueryItem[] = [
      new QueryItem('kind', sparkMedicalResourceKindRaw(SparkMedicalResourceKind.EXAMINATION_REPORTS))
    ];
    const strategy = new NetworkStrategy(
      true,
      false,
      `medical.resource.patch.${sparkMedicalResourceKindRaw(SparkMedicalResourceKind.EXAMINATION_REPORTS)}.${id}`,
      false,
      'high',
      RetryConfig.disabled()
    );
    const op = new CacheableSupportNetworkOperation(
      'Medical.Resource.SetExaminationArchived',
      'MedicalWorkflowAPI',
      new NetworkRequest('PATCH', this.resourceItemPath(id), strategy, query, {}, body)
    );
    return this.configuration.executeDecoded(op, (data: Object | null) =>
      RemoteExaminationReportWithAttachments.fromJson(data)
    );
  }

  /** POST /api/v1/medical/resources/?kind=... */
  async createResource(
    kind: SparkMedicalResourceKind,
    body: Object
  ): Promise<Object | null> {
    const query: QueryItem[] = [new QueryItem('kind', sparkMedicalResourceKindRaw(kind))];
    const strategy = new NetworkStrategy(
      true,
      false,
      `medical.resource.create.${sparkMedicalResourceKindRaw(kind)}`,
      false,
      'high',
      RetryConfig.disabled()
    );
    const op = new CacheableSupportNetworkOperation(
      'Medical.Resource.Create',
      'MedicalWorkflowAPI',
      new NetworkRequest('POST', RESOURCE_COLLECTION_PATH, strategy, query, {}, body)
    );
    return this.configuration.executeDecoded(op, (data: Object | null) => data);
  }

  /** PATCH /api/v1/medical/resources/{id}/?kind=... */
  async updateResource(
    kind: SparkMedicalResourceKind,
    id: number,
    body: Object
  ): Promise<Object | null> {
    const query: QueryItem[] = [new QueryItem('kind', sparkMedicalResourceKindRaw(kind))];
    const strategy = new NetworkStrategy(
      true,
      false,
      `medical.resource.update.${sparkMedicalResourceKindRaw(kind)}.${id}`,
      false,
      'high',
      RetryConfig.disabled()
    );
    const op = new CacheableSupportNetworkOperation(
      'Medical.Resource.Update',
      'MedicalWorkflowAPI',
      new NetworkRequest('PATCH', this.resourceItemPath(id), strategy, query, {}, body)
    );
    return this.configuration.executeDecoded(op, (data: Object | null) => data);
  }

  /** PUT /api/v1/medical/resources/{id}/?kind=... */
  async replaceResource(
    kind: SparkMedicalResourceKind,
    id: number,
    body: Object
  ): Promise<Object | null> {
    const query: QueryItem[] = [new QueryItem('kind', sparkMedicalResourceKindRaw(kind))];
    const strategy = new NetworkStrategy(
      true,
      false,
      `medical.resource.replace.${sparkMedicalResourceKindRaw(kind)}.${id}`,
      false,
      'high',
      RetryConfig.disabled()
    );
    const op = new CacheableSupportNetworkOperation(
      'Medical.Resource.Replace',
      'MedicalWorkflowAPI',
      new NetworkRequest('PUT', this.resourceItemPath(id), strategy, query, {}, body)
    );
    return this.configuration.executeDecoded(op, (data: Object | null) => data);
  }

  async createMemberModuleSetting(
    payload: MemberModuleSettingSavePayload
  ): Promise<RemoteMemberModuleSetting> {
    const raw = await this.createResource(
      SparkMedicalResourceKind.MEMBER_MODULE_SETTINGS,
      payload as Object
    );
    return RemoteMemberModuleSetting.fromJson(raw);
  }

  async updateMemberModuleSetting(
    id: number,
    payload: MemberModuleSettingSavePayload
  ): Promise<RemoteMemberModuleSetting> {
    const raw = await this.updateResource(
      SparkMedicalResourceKind.MEMBER_MODULE_SETTINGS,
      id,
      payload as Object
    );
    return RemoteMemberModuleSetting.fromJson(raw);
  }

  async createMember(payload: UpsertMemberPayload): Promise<RemoteMember> {
    const raw = await this.createResource(SparkMedicalResourceKind.MEMBERS, payload as Object);
    return RemoteMember.fromJson(raw);
  }

  async createMedicineBox(payload: MedicineBoxWritePayload): Promise<RemoteMedicineBox> {
    const raw = await this.createResource(SparkMedicalResourceKind.MEDICINE_BOXES, payload as Object);
    return RemoteMedicineBox.fromJson(raw);
  }

  async updateMedicineBox(id: number, payload: MedicineBoxWritePayload): Promise<RemoteMedicineBox> {
    const raw = await this.updateResource(SparkMedicalResourceKind.MEDICINE_BOXES, id, payload as Object);
    return RemoteMedicineBox.fromJson(raw);
  }

  async createMedicationRecord(body: Object): Promise<RemoteMedicationRecord> {
    const raw = await this.createResource(SparkMedicalResourceKind.MEDICATION_RECORDS, body);
    return RemoteMedicationRecord.fromJson(raw);
  }

  async updateMedicationRecord(id: number, body: Object): Promise<RemoteMedicationRecord> {
    const raw = await this.updateResource(SparkMedicalResourceKind.MEDICATION_RECORDS, id, body);
    return RemoteMedicationRecord.fromJson(raw);
  }

  async setMedicineBoxArchived(id: number, archived: boolean): Promise<RemoteMedicineBox> {
    const body: Record<string, boolean> = {};
    body['is_archived'] = archived;
    const query: QueryItem[] = [
      new QueryItem('kind', sparkMedicalResourceKindRaw(SparkMedicalResourceKind.MEDICINE_BOXES))
    ];
    const strategy = new NetworkStrategy(
      true,
      false,
      `medical.resource.patch.${sparkMedicalResourceKindRaw(SparkMedicalResourceKind.MEDICINE_BOXES)}.${id}`,
      false,
      'high',
      RetryConfig.disabled()
    );
    const op = new CacheableSupportNetworkOperation(
      'Medical.Resource.SetMedicineBoxArchived',
      'MedicalWorkflowAPI',
      new NetworkRequest('PATCH', this.resourceItemPath(id), strategy, query, {}, body)
    );
    return this.configuration.executeDecoded(op, (data: Object | null) => RemoteMedicineBox.fromJson(data));
  }

  async replaceMember(id: number, payload: UpsertMemberPayload): Promise<RemoteMember> {
    const raw = await this.replaceResource(SparkMedicalResourceKind.MEMBERS, id, payload as Object);
    return RemoteMember.fromJson(raw);
  }

  private static readIdArray(
    obj: Record<string, Object | string | number | boolean | null>,
    key: string
  ): number[] {
    const raw = obj[key];
    if (!Array.isArray(raw)) {
      return [];
    }
    const out: number[] = [];
    for (let i = 0; i < raw.length; i++) {
      const n = Number(raw[i]);
      if (!(n !== n) && n > 0) {
        out.push(n);
      }
    }
    return out;
  }

  private resourceItemPath(id: number): string {
    return `${RESOURCE_COLLECTION_PATH}${id}/`;
  }

  private listStrategy(kind: SparkMedicalResourceKind): NetworkStrategy {
    return new NetworkStrategy(
      true,
      true,
      `medical.resource.list.${sparkMedicalResourceKindRaw(kind)}`,
      true,
      'normal',
      RetryConfig.defaultConfig(),
      RESOURCE_ETAG_TTL_MS
    );
  }
}
