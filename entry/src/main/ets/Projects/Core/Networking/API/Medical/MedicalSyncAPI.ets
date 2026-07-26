import { SupportAPIResponseDecoder } from '../Common/SupportAPIResponseDecoder';

/**
 * 医疗 Remote DTO（SparkMedicalSyncAPI）。与 iOS MedicalSyncAPI.swift 对齐。
 * JSON wire 为 snake_case；通过显式 fromJson 解码。
 */

export type JsonMap = Record<string, Object | string | number | boolean | null>;

export function medicalAsArray(data: Object | null): Object[] {
  if (!data) {
    return [];
  }
  if (Array.isArray(data)) {
    return data as Object[];
  }
  return [];
}

export function medicalStringArray(raw: Object | string | number | boolean | null | undefined): string[] {
  if (!raw || !Array.isArray(raw)) {
    return [];
  }
  const arr = raw as Object[];
  const out: string[] = [];
  for (let i = 0; i < arr.length; i++) {
    out.push(`${arr[i]}`);
  }
  return out;
}

/** detail_data / extra → [String: String]，与 iOS RemoteMemberModuleSetting 对齐。 */
export function medicalStringMap(raw: Object | string | number | boolean | null | undefined): Record<string, string> {
  if (!raw || typeof raw !== 'object' || Array.isArray(raw)) {
    return {};
  }
  const obj = raw as Record<string, Object | string | number | boolean | null>;
  const keys = Object.keys(obj);
  const out: Record<string, string> = {};
  for (let i = 0; i < keys.length; i++) {
    const k = keys[i];
    const v = obj[k];
    if (v === null || v === undefined) {
      out[k] = '';
    } else if (typeof v === 'string') {
      out[k] = v;
    } else if (typeof v === 'number' || typeof v === 'boolean') {
      out[k] = `${v}`;
    } else {
      try {
        out[k] = JSON.stringify(v);
      } catch (_e) {
        out[k] = '';
      }
    }
  }
  return out;
}

export class RemoteManagedFile {
  id: number = 0;
  fileUuid?: string;
  originalName?: string;
  fileSize?: number;
  mimeType?: string;
  fileMd5?: string;
  businessType?: string;
  businessId?: string;
  objectKey?: string;
  storageType?: string;
  createdAt?: string;
  fileUrl?: string;

  static fromJson(data: Object | null): RemoteManagedFile {
    const obj = SupportAPIResponseDecoder.asRecord(data);
    const m = new RemoteManagedFile();
    m.id = SupportAPIResponseDecoder.num(obj, 'id', 0);
    m.fileUuid = SupportAPIResponseDecoder.optStrAny(obj, ['file_uuid', 'fileUuid']);
    m.originalName = SupportAPIResponseDecoder.optStrAny(obj, ['original_name', 'originalName']);
    m.fileSize = SupportAPIResponseDecoder.optNumAny(obj, ['file_size', 'fileSize']);
    m.mimeType = SupportAPIResponseDecoder.optStrAny(obj, ['mime_type', 'mimeType']);
    m.fileMd5 = SupportAPIResponseDecoder.optStrAny(obj, ['file_md5', 'fileMd5']);
    m.businessType = SupportAPIResponseDecoder.optStrAny(obj, ['business_type', 'businessType']);
    m.businessId = SupportAPIResponseDecoder.optStrAny(obj, ['business_id', 'businessId']);
    m.objectKey = SupportAPIResponseDecoder.optStrAny(obj, ['object_key', 'objectKey']);
    m.storageType = SupportAPIResponseDecoder.optStrAny(obj, ['storage_type', 'storageType']);
    m.createdAt = SupportAPIResponseDecoder.optStrAny(obj, ['created_at', 'createdAt']);
    m.fileUrl = SupportAPIResponseDecoder.optStrAny(obj, ['file_url', 'fileUrl']);
    return m;
  }

  static listFromJson(data: Object | null): RemoteManagedFile[] {
    const arr = medicalAsArray(data);
    const out: RemoteManagedFile[] = [];
    for (let i = 0; i < arr.length; i++) {
      out.push(RemoteManagedFile.fromJson(arr[i]));
    }
    return out;
  }
}

export class RemoteMember {
  id: number = 0;
  bindingId?: number;
  name: string = '';
  gender: string = 'unknown';
  relationship?: string;
  birthDate?: string;
  bloodType: string = '';
  allergies: string[] = [];
  chronicConditions: string[] = [];
  notes: string = '';
  avatarUrl: string = '';
  isPrimary: boolean = false;
  bindingRole?: string;
  sharedUserCount?: number;
  canShare?: boolean;
  canEdit?: boolean;
  canDelete?: boolean;
  canUnbind?: boolean;
  canManageBindings?: boolean;
  updatedAt: string = '';

  static fromJson(data: Object | null): RemoteMember {
    const obj = SupportAPIResponseDecoder.asRecord(data);
    const m = new RemoteMember();
    m.id = SupportAPIResponseDecoder.num(obj, 'id', 0);
    m.bindingId = SupportAPIResponseDecoder.optNumAny(obj, ['binding_id', 'bindingId']);
    m.name = SupportAPIResponseDecoder.str(obj, 'name', '');
    m.gender = SupportAPIResponseDecoder.str(obj, 'gender', 'unknown');
    m.relationship = SupportAPIResponseDecoder.optStr(obj, 'relationship');
    m.birthDate = SupportAPIResponseDecoder.optStrAny(obj, ['birth_date', 'birthDate']);
    m.bloodType = SupportAPIResponseDecoder.strAny(obj, ['blood_type', 'bloodType'], '');
    m.allergies = medicalStringArray(obj['allergies']);
    m.chronicConditions = medicalStringArray(obj['chronic_conditions'] ?? obj['chronicConditions']);
    m.notes = SupportAPIResponseDecoder.str(obj, 'notes', '');
    m.avatarUrl = SupportAPIResponseDecoder.strAny(obj, ['avatar_url', 'avatarUrl'], '');
    m.isPrimary = SupportAPIResponseDecoder.boolAny(obj, ['is_primary', 'isPrimary'], false);
    m.bindingRole = SupportAPIResponseDecoder.optStrAny(obj, ['binding_role', 'bindingRole']);
    m.sharedUserCount = SupportAPIResponseDecoder.optNumAny(obj, ['shared_user_count', 'sharedUserCount']);
    m.canShare = SupportAPIResponseDecoder.optBoolAny(obj, ['can_share', 'canShare']);
    m.canEdit = SupportAPIResponseDecoder.optBoolAny(obj, ['can_edit', 'canEdit']);
    m.canDelete = SupportAPIResponseDecoder.optBoolAny(obj, ['can_delete', 'canDelete']);
    m.canUnbind = SupportAPIResponseDecoder.optBoolAny(obj, ['can_unbind', 'canUnbind']);
    m.canManageBindings = SupportAPIResponseDecoder.optBoolAny(obj, ['can_manage_bindings', 'canManageBindings']);
    m.updatedAt = SupportAPIResponseDecoder.strAny(obj, ['updated_at', 'updatedAt'], '');
    return m;
  }

  static listFromJson(data: Object | null): RemoteMember[] {
    const arr = medicalAsArray(data);
    const out: RemoteMember[] = [];
    for (let i = 0; i < arr.length; i++) {
      out.push(RemoteMember.fromJson(arr[i]));
    }
    return out;
  }
}

export class RemoteMemberModuleSetting {
  id: number = 0;
  user?: number;
  member: number = 0;
  moduleCode: string = '';
  isEnabled: boolean = false;
  isCompleted: boolean = false;
  displayOrder: number = 0;
  summaryText: string = '';
  detailData: Record<string, string> = {};
  completedAt?: string;
  extra: Record<string, string> = {};
  createdAt?: string;
  updatedAt?: string;

  static fromJson(data: Object | null): RemoteMemberModuleSetting {
    const obj = SupportAPIResponseDecoder.asRecord(data);
    const m = new RemoteMemberModuleSetting();
    m.id = SupportAPIResponseDecoder.num(obj, 'id', 0);
    m.user = SupportAPIResponseDecoder.optNum(obj, 'user');
    m.member = SupportAPIResponseDecoder.num(obj, 'member', 0);
    m.moduleCode = SupportAPIResponseDecoder.strAny(obj, ['module_code', 'moduleCode'], '');
    m.isEnabled = SupportAPIResponseDecoder.boolAny(obj, ['is_enabled', 'isEnabled'], false);
    m.isCompleted = SupportAPIResponseDecoder.boolAny(obj, ['is_completed', 'isCompleted'], false);
    m.displayOrder = SupportAPIResponseDecoder.numAny(obj, ['display_order', 'displayOrder'], 0);
    m.summaryText = SupportAPIResponseDecoder.strAny(obj, ['summary_text', 'summaryText'], '');
    m.detailData = medicalStringMap(obj['detail_data'] ?? obj['detailData']);
    m.completedAt = SupportAPIResponseDecoder.optStrAny(obj, ['completed_at', 'completedAt']);
    m.extra = medicalStringMap(obj['extra']);
    m.createdAt = SupportAPIResponseDecoder.optStrAny(obj, ['created_at', 'createdAt']);
    m.updatedAt = SupportAPIResponseDecoder.optStrAny(obj, ['updated_at', 'updatedAt']);
    return m;
  }

  static listFromJson(data: Object | null): RemoteMemberModuleSetting[] {
    const arr = medicalAsArray(data);
    const out: RemoteMemberModuleSetting[] = [];
    for (let i = 0; i < arr.length; i++) {
      out.push(RemoteMemberModuleSetting.fromJson(arr[i]));
    }
    return out;
  }
}

export class RemoteMedicalCaseSummary {
  id: number = 0;
  member: number = 0;
  recordType?: string;
  status?: number;
  title?: string;
  hospitalName?: string;
  ageAtVisit?: number;
  diagnosisSummary?: string;
  createdAt?: string;
  updatedAt?: string;
  symptoms: string[] = [];
  medications: string[] = [];
  attachments: RemoteManagedFile[] = [];
  isArchived: boolean = false;

  static fromJson(data: Object | null): RemoteMedicalCaseSummary {
    const obj = SupportAPIResponseDecoder.asRecord(data);
    const m = new RemoteMedicalCaseSummary();
    m.id = SupportAPIResponseDecoder.num(obj, 'id', 0);
    m.member = SupportAPIResponseDecoder.num(obj, 'member', 0);
    m.recordType = SupportAPIResponseDecoder.optStrAny(obj, ['record_type', 'recordType']);
    m.status = SupportAPIResponseDecoder.optNum(obj, 'status');
    m.title = SupportAPIResponseDecoder.optStr(obj, 'title');
    m.hospitalName = SupportAPIResponseDecoder.optStrAny(obj, ['hospital_name', 'hospitalName']);
    m.ageAtVisit = SupportAPIResponseDecoder.optNumAny(obj, ['age_at_visit', 'ageAtVisit']);
    m.diagnosisSummary = SupportAPIResponseDecoder.optStrAny(obj, ['diagnosis_summary', 'diagnosisSummary']);
    m.createdAt = SupportAPIResponseDecoder.optStrAny(obj, ['created_at', 'createdAt']);
    m.updatedAt = SupportAPIResponseDecoder.optStrAny(obj, ['updated_at', 'updatedAt']);
    m.symptoms = medicalStringArray(obj['symptoms']);
    m.medications = medicalStringArray(obj['medications']);
    const attachmentsRaw = obj['attachments'];
    if (attachmentsRaw) {
      m.attachments = RemoteManagedFile.listFromJson(attachmentsRaw as Object);
    }
    m.isArchived = SupportAPIResponseDecoder.boolAny(obj, ['is_archived', 'isArchived'], false);
    return m;
  }

  static listFromJson(data: Object | null): RemoteMedicalCaseSummary[] {
    const arr = medicalAsArray(data);
    const out: RemoteMedicalCaseSummary[] = [];
    for (let i = 0; i < arr.length; i++) {
      out.push(RemoteMedicalCaseSummary.fromJson(arr[i]));
    }
    return out;
  }
}

/** 体检/检查共用明细行。与 iOS RemoteMedExamDetail 对齐。 */
export class RemoteMedExamDetail {
  id: number = 0;
  businessType: string = '';
  businessId: number = 0;
  member: number = 0;
  category: string = '';
  subCategory: string = '';
  itemName: string = '';
  itemCode: string = '';
  resultValue?: string;
  unit: string = '';
  referenceRange: string = '';
  flag: string = '';
  resultAt?: string;
  modality: string = '';
  bodyPart: string = '';
  diagnosis?: string;
  sortOrder: number = 0;
  updatedAt?: string;

  static fromJson(data: Object | null): RemoteMedExamDetail {
    const obj = SupportAPIResponseDecoder.asRecord(data);
    const m = new RemoteMedExamDetail();
    m.id = SupportAPIResponseDecoder.num(obj, 'id', 0);
    m.businessType = SupportAPIResponseDecoder.strAny(obj, ['business_type', 'businessType'], '');
    m.businessId = SupportAPIResponseDecoder.numAny(obj, ['business_id', 'businessId'], 0);
    m.member = SupportAPIResponseDecoder.num(obj, 'member', 0);
    m.category = SupportAPIResponseDecoder.str(obj, 'category', '');
    m.subCategory = SupportAPIResponseDecoder.strAny(obj, ['sub_category', 'subCategory'], '');
    m.itemName = SupportAPIResponseDecoder.strAny(obj, ['item_name', 'itemName'], '');
    m.itemCode = SupportAPIResponseDecoder.strAny(obj, ['item_code', 'itemCode'], '');
    m.resultValue = SupportAPIResponseDecoder.optStrAny(obj, ['result_value', 'resultValue']);
    m.unit = SupportAPIResponseDecoder.str(obj, 'unit', '');
    m.referenceRange = SupportAPIResponseDecoder.strAny(obj, ['reference_range', 'referenceRange'], '');
    m.flag = SupportAPIResponseDecoder.str(obj, 'flag', '');
    m.resultAt = SupportAPIResponseDecoder.optStrAny(obj, ['result_at', 'resultAt']);
    m.modality = SupportAPIResponseDecoder.str(obj, 'modality', '');
    m.bodyPart = SupportAPIResponseDecoder.strAny(obj, ['body_part', 'bodyPart'], '');
    m.diagnosis = SupportAPIResponseDecoder.optStr(obj, 'diagnosis');
    m.sortOrder = SupportAPIResponseDecoder.numAny(obj, ['sort_order', 'sortOrder'], 0);
    m.updatedAt = SupportAPIResponseDecoder.optStrAny(obj, ['updated_at', 'updatedAt']);
    return m;
  }

  static listFromJson(data: Object | null): RemoteMedExamDetail[] {
    const arr = medicalAsArray(data);
    const out: RemoteMedExamDetail[] = [];
    for (let i = 0; i < arr.length; i++) {
      out.push(RemoteMedExamDetail.fromJson(arr[i]));
    }
    return out;
  }
}

export class RemoteHealthExamReportWithAttachments {
  id: number = 0;
  member: number = 0;
  institutionName?: string;
  reportNo?: string;
  examDate?: string;
  examType?: number;
  summary?: string;
  source?: number;
  status?: number;
  createdAt?: string;
  updatedAt?: string;
  attachments: RemoteManagedFile[] = [];
  /** 首页 complete-data 默认不含；列表懒加载后回填。false=未加载。 */
  detailsLoaded: boolean = false;
  medExamDetails: RemoteMedExamDetail[] = [];
  isArchived: boolean = false;
  archivedAt?: string;

  static fromJson(data: Object | null): RemoteHealthExamReportWithAttachments {
    const obj = SupportAPIResponseDecoder.asRecord(data);
    const m = new RemoteHealthExamReportWithAttachments();
    m.id = SupportAPIResponseDecoder.num(obj, 'id', 0);
    m.member = SupportAPIResponseDecoder.num(obj, 'member', 0);
    m.institutionName = SupportAPIResponseDecoder.optStrAny(obj, ['institution_name', 'institutionName']);
    m.reportNo = SupportAPIResponseDecoder.optStrAny(obj, ['report_no', 'reportNo']);
    m.examDate = SupportAPIResponseDecoder.optStrAny(obj, ['exam_date', 'examDate']);
    m.examType = SupportAPIResponseDecoder.optNumAny(obj, ['exam_type', 'examType']);
    m.summary = SupportAPIResponseDecoder.optStr(obj, 'summary');
    m.source = SupportAPIResponseDecoder.optNum(obj, 'source');
    m.status = SupportAPIResponseDecoder.optNum(obj, 'status');
    m.createdAt = SupportAPIResponseDecoder.optStrAny(obj, ['created_at', 'createdAt']);
    m.updatedAt = SupportAPIResponseDecoder.optStrAny(obj, ['updated_at', 'updatedAt']);
    const attachmentsRaw = obj['attachments'];
    if (attachmentsRaw) {
      m.attachments = RemoteManagedFile.listFromJson(attachmentsRaw as Object);
    }
    const detailsRaw = obj['med_exam_details'] ?? obj['medExamDetails'];
    if (detailsRaw !== undefined && detailsRaw !== null) {
      m.detailsLoaded = true;
      m.medExamDetails = RemoteMedExamDetail.listFromJson(detailsRaw as Object);
    }
    m.isArchived = SupportAPIResponseDecoder.boolAny(obj, ['is_archived', 'isArchived'], false);
    m.archivedAt = SupportAPIResponseDecoder.optStrAny(obj, ['archived_at', 'archivedAt']);
    return m;
  }

  static listFromJson(data: Object | null): RemoteHealthExamReportWithAttachments[] {
    const arr = medicalAsArray(data);
    const out: RemoteHealthExamReportWithAttachments[] = [];
    for (let i = 0; i < arr.length; i++) {
      out.push(RemoteHealthExamReportWithAttachments.fromJson(arr[i]));
    }
    return out;
  }

  clone(): RemoteHealthExamReportWithAttachments {
    const copy = new RemoteHealthExamReportWithAttachments();
    copy.id = this.id;
    copy.member = this.member;
    copy.institutionName = this.institutionName;
    copy.reportNo = this.reportNo;
    copy.examDate = this.examDate;
    copy.examType = this.examType;
    copy.summary = this.summary;
    copy.source = this.source;
    copy.status = this.status;
    copy.createdAt = this.createdAt;
    copy.updatedAt = this.updatedAt;
    copy.attachments = this.attachments.slice();
    copy.detailsLoaded = this.detailsLoaded;
    copy.medExamDetails = this.medExamDetails.slice();
    copy.isArchived = this.isArchived;
    copy.archivedAt = this.archivedAt;
    return copy;
  }
}

export class RemoteExaminationReportWithAttachments {
  id: number = 0;
  member: number = 0;
  medicalRecord?: number;
  category?: string;
  subCategory?: string;
  itemName?: string;
  performedAt?: string;
  reportedAt?: string;
  organizationName?: string;
  departmentName?: string;
  doctorName?: string;
  findings?: string;
  impression?: string;
  source?: number;
  status?: number;
  createdAt?: string;
  updatedAt?: string;
  attachments: RemoteManagedFile[] = [];
  /** 首页 complete-data 默认不含；列表懒加载后回填。false=未加载。 */
  detailsLoaded: boolean = false;
  medExamDetails: RemoteMedExamDetail[] = [];
  isArchived: boolean = false;
  archivedAt?: string;

  static fromJson(data: Object | null): RemoteExaminationReportWithAttachments {
    const obj = SupportAPIResponseDecoder.asRecord(data);
    const m = new RemoteExaminationReportWithAttachments();
    m.id = SupportAPIResponseDecoder.num(obj, 'id', 0);
    m.member = SupportAPIResponseDecoder.num(obj, 'member', 0);
    m.medicalRecord = SupportAPIResponseDecoder.optNumAny(obj, ['medical_record', 'medicalRecord']);
    m.category = SupportAPIResponseDecoder.optStr(obj, 'category');
    m.subCategory = SupportAPIResponseDecoder.optStrAny(obj, ['sub_category', 'subCategory']);
    m.itemName = SupportAPIResponseDecoder.optStrAny(obj, ['item_name', 'itemName']);
    m.performedAt = SupportAPIResponseDecoder.optStrAny(obj, ['performed_at', 'performedAt']);
    m.reportedAt = SupportAPIResponseDecoder.optStrAny(obj, ['reported_at', 'reportedAt']);
    m.organizationName = SupportAPIResponseDecoder.optStrAny(obj, ['organization_name', 'organizationName']);
    m.departmentName = SupportAPIResponseDecoder.optStrAny(obj, ['department_name', 'departmentName']);
    m.doctorName = SupportAPIResponseDecoder.optStrAny(obj, ['doctor_name', 'doctorName']);
    m.findings = SupportAPIResponseDecoder.optStr(obj, 'findings');
    m.impression = SupportAPIResponseDecoder.optStr(obj, 'impression');
    m.source = SupportAPIResponseDecoder.optNum(obj, 'source');
    m.status = SupportAPIResponseDecoder.optNum(obj, 'status');
    m.createdAt = SupportAPIResponseDecoder.optStrAny(obj, ['created_at', 'createdAt']);
    m.updatedAt = SupportAPIResponseDecoder.optStrAny(obj, ['updated_at', 'updatedAt']);
    const attachmentsRaw = obj['attachments'];
    if (attachmentsRaw) {
      m.attachments = RemoteManagedFile.listFromJson(attachmentsRaw as Object);
    }
    const detailsRaw = obj['med_exam_details'] ?? obj['medExamDetails'];
    if (detailsRaw !== undefined && detailsRaw !== null) {
      m.detailsLoaded = true;
      m.medExamDetails = RemoteMedExamDetail.listFromJson(detailsRaw as Object);
    }
    m.isArchived = SupportAPIResponseDecoder.boolAny(obj, ['is_archived', 'isArchived'], false);
    m.archivedAt = SupportAPIResponseDecoder.optStrAny(obj, ['archived_at', 'archivedAt']);
    return m;
  }

  static listFromJson(data: Object | null): RemoteExaminationReportWithAttachments[] {
    const arr = medicalAsArray(data);
    const out: RemoteExaminationReportWithAttachments[] = [];
    for (let i = 0; i < arr.length; i++) {
      out.push(RemoteExaminationReportWithAttachments.fromJson(arr[i]));
    }
    return out;
  }

  clone(): RemoteExaminationReportWithAttachments {
    const copy = new RemoteExaminationReportWithAttachments();
    copy.id = this.id;
    copy.member = this.member;
    copy.medicalRecord = this.medicalRecord;
    copy.category = this.category;
    copy.subCategory = this.subCategory;
    copy.itemName = this.itemName;
    copy.performedAt = this.performedAt;
    copy.reportedAt = this.reportedAt;
    copy.organizationName = this.organizationName;
    copy.departmentName = this.departmentName;
    copy.doctorName = this.doctorName;
    copy.findings = this.findings;
    copy.impression = this.impression;
    copy.source = this.source;
    copy.status = this.status;
    copy.createdAt = this.createdAt;
    copy.updatedAt = this.updatedAt;
    copy.attachments = this.attachments.slice();
    copy.detailsLoaded = this.detailsLoaded;
    copy.medExamDetails = this.medExamDetails.slice();
    copy.isArchived = this.isArchived;
    copy.archivedAt = this.archivedAt;
    return copy;
  }
}

/** 用药计划提醒时间点。对齐 iOS ReminderTime。 */
export class RemoteReminderTime {
  time: string = '';
  dose?: number;
  doseText?: string;

  static fromJson(data: Object | null): RemoteReminderTime {
    const obj = SupportAPIResponseDecoder.asRecord(data);
    const item = new RemoteReminderTime();
    item.time = SupportAPIResponseDecoder.strAny(obj, ['time'], '');
    item.dose = SupportAPIResponseDecoder.optNum(obj, 'dose');
    item.doseText = SupportAPIResponseDecoder.optStrAny(obj, ['dose_text', 'doseText']);
    return item;
  }

  static listFromJson(data: Object | null): RemoteReminderTime[] {
    const arr = medicalAsArray(data);
    const out: RemoteReminderTime[] = [];
    for (let i = 0; i < arr.length; i++) {
      out.push(RemoteReminderTime.fromJson(arr[i]));
    }
    return out;
  }
}

export class RemoteMedicationPlan {
  id: number = 0;
  member: number = 0;
  medicalCase?: number;
  medicineBox?: number;
  prescription?: number;
  drugName: string = '';
  dosePerTime: string = '';
  doseValue?: number;
  doseUnit: string = '';
  frequencyType: string = 'daily';
  everyNDays?: number;
  weeklyWeekdays: number[] = [];
  frequencyText: string = '';
  reminderTimes: RemoteReminderTime[] = [];
  startDate: string = '';
  endDate?: string;
  instructions: string = '';
  status: string = '';
  updatedAt: string = '';
  reminderEnabled: boolean = false;
  extra: Record<string, string> = {};
  attachments: RemoteManagedFile[] = [];
  isArchived: boolean = false;

  static fromJson(data: Object | null): RemoteMedicationPlan {
    const obj = SupportAPIResponseDecoder.asRecord(data);
    const m = new RemoteMedicationPlan();
    m.id = SupportAPIResponseDecoder.num(obj, 'id', 0);
    m.member = SupportAPIResponseDecoder.num(obj, 'member', 0);
    m.medicalCase = SupportAPIResponseDecoder.optNumAny(obj, ['medical_case', 'medicalCase']);
    m.medicineBox = SupportAPIResponseDecoder.optNumAny(obj, ['medicine_box', 'medicineBox']);
    m.prescription = SupportAPIResponseDecoder.optNumAny(obj, ['prescription']);
    m.drugName = SupportAPIResponseDecoder.strAny(obj, ['drug_name', 'drugName'], '');
    m.dosePerTime = SupportAPIResponseDecoder.strAny(obj, ['dose_per_time', 'dosePerTime'], '');
    m.doseValue = SupportAPIResponseDecoder.optNumAny(obj, ['dose_value', 'doseValue']);
    m.doseUnit = SupportAPIResponseDecoder.strAny(obj, ['dose_unit', 'doseUnit'], '');
    m.frequencyType = SupportAPIResponseDecoder.strAny(obj, ['frequency_type', 'frequencyType'], 'daily');
    m.everyNDays = SupportAPIResponseDecoder.optNumAny(obj, ['every_n_days', 'everyNDays']);
    m.weeklyWeekdays = RemoteMedicationPlan.parseIntArray(obj['weekly_weekdays'] ?? obj['weeklyWeekdays']);
    m.frequencyText = SupportAPIResponseDecoder.strAny(obj, ['frequency_text', 'frequencyText'], '');
    m.reminderTimes = RemoteReminderTime.listFromJson(
      obj['reminder_times'] ?? obj['reminderTimes']
    );
    m.startDate = SupportAPIResponseDecoder.strAny(obj, ['start_date', 'startDate'], '');
    m.endDate = SupportAPIResponseDecoder.optStrAny(obj, ['end_date', 'endDate']);
    m.instructions = SupportAPIResponseDecoder.strAny(obj, ['instructions'], '');
    m.status = SupportAPIResponseDecoder.str(obj, 'status', '');
    m.updatedAt = SupportAPIResponseDecoder.strAny(obj, ['updated_at', 'updatedAt'], '');
    m.reminderEnabled = SupportAPIResponseDecoder.boolAny(obj, ['reminder_enabled', 'reminderEnabled'], false);
    m.extra = medicalStringMap(obj['extra']);
    m.attachments = RemoteManagedFile.listFromJson(obj['attachments']);
    m.isArchived = SupportAPIResponseDecoder.boolAny(obj, ['is_archived', 'isArchived'], false);
    return m;
  }

  private static parseIntArray(raw: Object | null | undefined): number[] {
    if (!Array.isArray(raw)) {
      return [];
    }
    const out: number[] = [];
    for (let i = 0; i < raw.length; i++) {
      const value = Number(raw[i]);
      if (!Number.isNaN(value)) {
        out.push(value);
      }
    }
    return out;
  }

  static listFromJson(data: Object | null): RemoteMedicationPlan[] {
    const arr = medicalAsArray(data);
    const out: RemoteMedicationPlan[] = [];
    for (let i = 0; i < arr.length; i++) {
      out.push(RemoteMedicationPlan.fromJson(arr[i]));
    }
    return out;
  }
}

export class RemoteMedicineBox {
  id: number = 0;
  member?: number;
  medicineName: string = '';
  medicineType?: string;
  brandName: string = '';
  dosageForm: string = '';
  strength: string = '';
  doseUnit: string = '';
  totalQuantity?: number;
  expireDate?: string;
  notes: string = '';
  extra: Record<string, string> = {};
  attachments: RemoteManagedFile[] = [];
  updatedAt: string = '';
  isArchived: boolean = false;
  archivedAt?: string;

  static fromJson(data: Object | null): RemoteMedicineBox {
    const obj = SupportAPIResponseDecoder.asRecord(data);
    const m = new RemoteMedicineBox();
    m.id = SupportAPIResponseDecoder.num(obj, 'id', 0);
    m.member = SupportAPIResponseDecoder.optNum(obj, 'member');
    m.medicineName = SupportAPIResponseDecoder.strAny(obj, ['medicine_name', 'medicineName'], '');
    m.medicineType = SupportAPIResponseDecoder.optStrAny(obj, ['medicine_type', 'medicineType']);
    m.brandName = SupportAPIResponseDecoder.strAny(obj, ['brand_name', 'brandName'], '');
    m.dosageForm = SupportAPIResponseDecoder.strAny(obj, ['dosage_form', 'dosageForm'], '');
    m.strength = SupportAPIResponseDecoder.strAny(obj, ['strength'], '');
    m.doseUnit = SupportAPIResponseDecoder.strAny(obj, ['dose_unit', 'doseUnit'], '');
    m.totalQuantity = SupportAPIResponseDecoder.optNumAny(obj, ['total_quantity', 'totalQuantity']);
    m.expireDate = SupportAPIResponseDecoder.optStrAny(obj, ['expire_date', 'expireDate']);
    m.notes = SupportAPIResponseDecoder.strAny(obj, ['notes'], '');
    m.extra = medicalStringMap(obj['extra']);
    m.attachments = RemoteManagedFile.listFromJson(obj['attachments']);
    m.updatedAt = SupportAPIResponseDecoder.strAny(obj, ['updated_at', 'updatedAt'], '');
    m.isArchived = SupportAPIResponseDecoder.boolAny(obj, ['is_archived', 'isArchived'], false);
    m.archivedAt = SupportAPIResponseDecoder.optStrAny(obj, ['archived_at', 'archivedAt']);
    return m;
  }

  static listFromJson(data: Object | null): RemoteMedicineBox[] {
    const arr = medicalAsArray(data);
    const out: RemoteMedicineBox[] = [];
    for (let i = 0; i < arr.length; i++) {
      out.push(RemoteMedicineBox.fromJson(arr[i]));
    }
    return out;
  }
}

export class RemotePrescription {
  id: number = 0;
  member: number = 0;
  status: string = '';
  updatedAt: string = '';
  isArchived: boolean = false;

  static fromJson(data: Object | null): RemotePrescription {
    const obj = SupportAPIResponseDecoder.asRecord(data);
    const m = new RemotePrescription();
    m.id = SupportAPIResponseDecoder.num(obj, 'id', 0);
    m.member = SupportAPIResponseDecoder.num(obj, 'member', 0);
    m.status = SupportAPIResponseDecoder.str(obj, 'status', '');
    m.updatedAt = SupportAPIResponseDecoder.strAny(obj, ['updated_at', 'updatedAt'], '');
    m.isArchived = SupportAPIResponseDecoder.boolAny(obj, ['is_archived', 'isArchived'], false);
    return m;
  }

  static listFromJson(data: Object | null): RemotePrescription[] {
    const arr = medicalAsArray(data);
    const out: RemotePrescription[] = [];
    for (let i = 0; i < arr.length; i++) {
      out.push(RemotePrescription.fromJson(arr[i]));
    }
    return out;
  }
}

export class RemoteMedicationRecord {
  id: number = 0;
  member: number = 0;
  plan: number = 0;
  status: string = '';
  scheduledAt: string = '';
  takenAt?: string;
  plannedDose: string = '';
  actualDose: string = '';
  doseSequence: number = 0;
  timezone: string = '';
  notes: string = '';
  extra: Record<string, string> = {};
  updatedAt: string = '';

  static fromJson(data: Object | null): RemoteMedicationRecord {
    const obj = SupportAPIResponseDecoder.asRecord(data);
    const m = new RemoteMedicationRecord();
    m.id = SupportAPIResponseDecoder.num(obj, 'id', 0);
    m.member = SupportAPIResponseDecoder.num(obj, 'member', 0);
    m.plan = SupportAPIResponseDecoder.num(obj, 'plan', 0);
    m.status = SupportAPIResponseDecoder.str(obj, 'status', '');
    m.scheduledAt = SupportAPIResponseDecoder.strAny(obj, ['scheduled_at', 'scheduledAt'], '');
    m.takenAt = SupportAPIResponseDecoder.optStrAny(obj, ['taken_at', 'takenAt']);
    m.plannedDose = SupportAPIResponseDecoder.strAny(obj, ['planned_dose', 'plannedDose'], '');
    m.actualDose = SupportAPIResponseDecoder.strAny(obj, ['actual_dose', 'actualDose'], '');
    m.doseSequence = SupportAPIResponseDecoder.numAny(obj, ['dose_sequence', 'doseSequence'], 0);
    m.timezone = SupportAPIResponseDecoder.strAny(obj, ['timezone'], '');
    m.notes = SupportAPIResponseDecoder.strAny(obj, ['notes'], '');
    m.extra = medicalStringMap(obj['extra']);
    m.updatedAt = SupportAPIResponseDecoder.strAny(obj, ['updated_at', 'updatedAt'], '');
    return m;
  }

  static listFromJson(data: Object | null): RemoteMedicationRecord[] {
    const arr = medicalAsArray(data);
    const out: RemoteMedicationRecord[] = [];
    for (let i = 0; i < arr.length; i++) {
      out.push(RemoteMedicationRecord.fromJson(arr[i]));
    }
    return out;
  }
}

export class RemoteMedicationSummary {
  todayTotal: number = 0;
  todayTaken: number = 0;
  todaySkipped: number = 0;
  adherenceRate: number = 0;
  activePlanCount: number = 0;
  lowStockCount: number = 0;
  expiringSoonCount: number = 0;

  static fromJson(data: Object | null): RemoteMedicationSummary {
    const obj = SupportAPIResponseDecoder.asRecord(data);
    const m = new RemoteMedicationSummary();
    m.todayTotal = SupportAPIResponseDecoder.numAny(obj, ['today_total', 'todayTotal'], 0);
    m.todayTaken = SupportAPIResponseDecoder.numAny(obj, ['today_taken', 'todayTaken'], 0);
    m.todaySkipped = SupportAPIResponseDecoder.numAny(obj, ['today_skipped', 'todaySkipped'], 0);
    m.adherenceRate = SupportAPIResponseDecoder.numAny(obj, ['adherence_rate', 'adherenceRate'], 0);
    m.activePlanCount = SupportAPIResponseDecoder.numAny(obj, ['active_plan_count', 'activePlanCount'], 0);
    m.lowStockCount = SupportAPIResponseDecoder.numAny(obj, ['low_stock_count', 'lowStockCount'], 0);
    m.expiringSoonCount = SupportAPIResponseDecoder.numAny(obj, ['expiring_soon_count', 'expiringSoonCount'], 0);
    return m;
  }
}

export class RemoteSymptom {
  id: number = 0;
  member: number = 0;
  name: string = '';
  updatedAt: string = '';

  static fromJson(data: Object | null): RemoteSymptom {
    const obj = SupportAPIResponseDecoder.asRecord(data);
    const m = new RemoteSymptom();
    m.id = SupportAPIResponseDecoder.num(obj, 'id', 0);
    m.member = SupportAPIResponseDecoder.num(obj, 'member', 0);
    m.name = SupportAPIResponseDecoder.str(obj, 'name', '');
    m.updatedAt = SupportAPIResponseDecoder.strAny(obj, ['updated_at', 'updatedAt'], '');
    return m;
  }

  static listFromJson(data: Object | null): RemoteSymptom[] {
    const arr = medicalAsArray(data);
    const out: RemoteSymptom[] = [];
    for (let i = 0; i < arr.length; i++) {
      out.push(RemoteSymptom.fromJson(arr[i]));
    }
    return out;
  }
}

export class RemoteVisit {
  id: number = 0;
  member: number = 0;
  medicalCase: number = 0;
  updatedAt: string = '';

  static fromJson(data: Object | null): RemoteVisit {
    const obj = SupportAPIResponseDecoder.asRecord(data);
    const m = new RemoteVisit();
    m.id = SupportAPIResponseDecoder.num(obj, 'id', 0);
    m.member = SupportAPIResponseDecoder.num(obj, 'member', 0);
    m.medicalCase = SupportAPIResponseDecoder.numAny(obj, ['medical_case', 'medicalCase'], 0);
    m.updatedAt = SupportAPIResponseDecoder.strAny(obj, ['updated_at', 'updatedAt'], '');
    return m;
  }

  static listFromJson(data: Object | null): RemoteVisit[] {
    const arr = medicalAsArray(data);
    const out: RemoteVisit[] = [];
    for (let i = 0; i < arr.length; i++) {
      out.push(RemoteVisit.fromJson(arr[i]));
    }
    return out;
  }
}

export class RemoteSurgery {
  id: number = 0;
  member: number = 0;
  procedureName: string = '';
  updatedAt?: string;

  static fromJson(data: Object | null): RemoteSurgery {
    const obj = SupportAPIResponseDecoder.asRecord(data);
    const m = new RemoteSurgery();
    m.id = SupportAPIResponseDecoder.num(obj, 'id', 0);
    m.member = SupportAPIResponseDecoder.num(obj, 'member', 0);
    m.procedureName = SupportAPIResponseDecoder.strAny(obj, ['procedure_name', 'procedureName'], '');
    m.updatedAt = SupportAPIResponseDecoder.optStrAny(obj, ['updated_at', 'updatedAt']);
    return m;
  }

  static listFromJson(data: Object | null): RemoteSurgery[] {
    const arr = medicalAsArray(data);
    const out: RemoteSurgery[] = [];
    for (let i = 0; i < arr.length; i++) {
      out.push(RemoteSurgery.fromJson(arr[i]));
    }
    return out;
  }
}

export class RemoteFollowUp {
  id: number = 0;
  member: number = 0;
  medicalCase: number = 0;
  status: string = '';
  updatedAt: string = '';

  static fromJson(data: Object | null): RemoteFollowUp {
    const obj = SupportAPIResponseDecoder.asRecord(data);
    const m = new RemoteFollowUp();
    m.id = SupportAPIResponseDecoder.num(obj, 'id', 0);
    m.member = SupportAPIResponseDecoder.num(obj, 'member', 0);
    m.medicalCase = SupportAPIResponseDecoder.numAny(obj, ['medical_case', 'medicalCase'], 0);
    m.status = SupportAPIResponseDecoder.str(obj, 'status', '');
    m.updatedAt = SupportAPIResponseDecoder.strAny(obj, ['updated_at', 'updatedAt'], '');
    return m;
  }

  static listFromJson(data: Object | null): RemoteFollowUp[] {
    const arr = medicalAsArray(data);
    const out: RemoteFollowUp[] = [];
    for (let i = 0; i < arr.length; i++) {
      out.push(RemoteFollowUp.fromJson(arr[i]));
    }
    return out;
  }
}

/** complete-data 聚合响应 */
export class RemoteMemberCompleteData {
  memberId: number = 0;
  member: RemoteMember = new RemoteMember();
  memberModuleSettings: RemoteMemberModuleSetting[] = [];
  medicalCases: RemoteMedicalCaseSummary[] = [];
  healthExamReports: RemoteHealthExamReportWithAttachments[] = [];
  examinationReports: RemoteExaminationReportWithAttachments[] = [];
  medicineBoxes: RemoteMedicineBox[] = [];
  familyMedicineBoxes?: RemoteMedicineBox[];
  prescriptions: RemotePrescription[] = [];
  medicationPlans: RemoteMedicationPlan[] = [];
  todayMedicationRecords: RemoteMedicationRecord[] = [];
  medicationSummary?: RemoteMedicationSummary;
  symptoms: RemoteSymptom[] = [];
  visits: RemoteVisit[] = [];
  surgeries: RemoteSurgery[] = [];
  followUps: RemoteFollowUp[] = [];

  static fromJson(data: Object | null): RemoteMemberCompleteData {
    const obj = SupportAPIResponseDecoder.asRecord(data);
    const m = new RemoteMemberCompleteData();
    m.memberId = SupportAPIResponseDecoder.numAny(obj, ['member_id', 'memberId'], 0);
    const memberRaw = obj['member'];
    if (memberRaw) {
      m.member = RemoteMember.fromJson(memberRaw as Object);
    }
    const settingsRaw = obj['member_module_settings'] ?? obj['memberModuleSettings'];
    if (settingsRaw) {
      m.memberModuleSettings = RemoteMemberModuleSetting.listFromJson(settingsRaw as Object);
    }
    const casesRaw = obj['medical_cases'] ?? obj['medicalCases'];
    if (casesRaw) {
      m.medicalCases = RemoteMedicalCaseSummary.listFromJson(casesRaw as Object);
    }
    const hexRaw = obj['health_exam_reports'] ?? obj['healthExamReports'];
    if (hexRaw) {
      m.healthExamReports = RemoteHealthExamReportWithAttachments.listFromJson(hexRaw as Object);
    }
    const examRaw = obj['examination_reports'] ?? obj['examinationReports'];
    if (examRaw) {
      m.examinationReports = RemoteExaminationReportWithAttachments.listFromJson(examRaw as Object);
    }
    const boxesRaw = obj['medicine_boxes'] ?? obj['medicineBoxes'];
    if (boxesRaw) {
      m.medicineBoxes = RemoteMedicineBox.listFromJson(boxesRaw as Object);
    }
    const familyRaw = obj['family_medicine_boxes'] ?? obj['familyMedicineBoxes'];
    if (familyRaw) {
      m.familyMedicineBoxes = RemoteMedicineBox.listFromJson(familyRaw as Object);
    }
    const rxRaw = obj['prescriptions'];
    if (rxRaw) {
      m.prescriptions = RemotePrescription.listFromJson(rxRaw as Object);
    }
    const plansRaw = obj['medication_plans'] ?? obj['medicationPlans'];
    if (plansRaw) {
      m.medicationPlans = RemoteMedicationPlan.listFromJson(plansRaw as Object);
    }
    const todayRaw = obj['today_medication_records'] ?? obj['todayMedicationRecords'];
    if (todayRaw) {
      m.todayMedicationRecords = RemoteMedicationRecord.listFromJson(todayRaw as Object);
    }
    const summaryRaw = obj['medication_summary'] ?? obj['medicationSummary'];
    if (summaryRaw) {
      m.medicationSummary = RemoteMedicationSummary.fromJson(summaryRaw as Object);
    }
    const symptomsRaw = obj['symptoms'];
    if (symptomsRaw) {
      m.symptoms = RemoteSymptom.listFromJson(symptomsRaw as Object);
    }
    const visitsRaw = obj['visits'];
    if (visitsRaw) {
      m.visits = RemoteVisit.listFromJson(visitsRaw as Object);
    }
    const surgeriesRaw = obj['surgeries'];
    if (surgeriesRaw) {
      m.surgeries = RemoteSurgery.listFromJson(surgeriesRaw as Object);
    }
    const followUpsRaw = obj['follow_ups'] ?? obj['followUps'];
    if (followUpsRaw) {
      m.followUps = RemoteFollowUp.listFromJson(followUpsRaw as Object);
    }
    return m;
  }
}
