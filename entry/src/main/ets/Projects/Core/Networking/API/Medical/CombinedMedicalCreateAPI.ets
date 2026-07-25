import { NetworkRequest, NetworkStrategy, RetryConfig } from '../../SupportNetworkModels';
import { SupportBackendConfiguration } from '../../SupportBackendConfiguration';
import { CacheableSupportNetworkOperation } from '../../Operations/SupportNetworkOperation';
import { SupportAPIResponseDecoder } from '../Common/SupportAPIResponseDecoder';
import { MedicationPlanBundleItemNetworkPayload } from './MedicalWorkflowAPI';

/** 组合创建 — 成员（带可选 id）。 */
export class CombinedMemberRequest {
  id?: number;
  name?: string;
  gender?: string;
  birth_date?: string;
  relationship?: string;
  extra?: Record<string, string>;
}

export class CombinedMedicalCaseRequest {
  title: string = '';
  hospital_name?: string;
  diagnosis_summary?: string;
  age_at_visit?: number;
  extra?: Record<string, string>;
  source_file_ids?: number[];
}

export class CombinedSymptomRequest {
  name: string = '';
  code?: string;
  severity?: string;
  started_at?: string;
  duration_value?: number;
  duration_unit?: string;
  body_part?: string;
  notes?: string;
  source_file_ids?: number[];
}

export class CombinedVisitRequest {
  visit_type?: string;
  visited_at?: string;
  department?: string;
  doctor_name?: string;
  visit_no?: string;
  notes?: string;
  source_file_ids?: number[];
}

export class CombinedSurgeryRequest {
  procedure_name: string = '';
  procedure_code?: string;
  site?: string;
  performed_at?: string;
  surgeon?: string;
  anesthesia_type?: string;
  incision_level?: string;
  asa_class?: string;
  notes?: string;
  source_file_ids?: number[];
}

export class CombinedFollowUpRequest {
  planned_at?: string;
  completed_at?: string;
  status?: string;
  method?: string;
  outcome?: string;
  next_action?: string;
  source_file_ids?: number[];
}

export class CombinedExaminationDetailRequest {
  category: string = '';
  sub_category?: string;
  item_name?: string;
  item_code?: string;
  result_value: string = '';
  unit?: string;
  reference_range?: string;
  flag?: string;
  result_at?: string;
  modality?: string;
  body_part?: string;
  diagnosis?: string;
  sort_order?: number;
  extra?: Record<string, string>;
}

export class CombinedExaminationReportRequest {
  category: string = '';
  item_name?: string;
  findings?: string;
  impression?: string;
  performed_at?: string;
  organization_name?: string;
  doctor_name?: string;
  details?: CombinedExaminationDetailRequest[];
  source_file_ids?: number[];
}

export class CombinedPrescriptionRequest {
  medical_case?: number;
  prescriber_name?: string;
  institution_name?: string;
  prescribed_at?: string;
  diagnosis?: string;
  prescription_no?: string;
  status?: string;
  extra?: Record<string, string>;
  medication_plans: MedicationPlanBundleItemNetworkPayload[] = [];
  source_file_ids?: number[];
}

/** POST /api/v1/medical/combined-create/ 请求体。 */
export class CombinedMedicalCreateRequest {
  member: CombinedMemberRequest = new CombinedMemberRequest();
  medical_case: CombinedMedicalCaseRequest = new CombinedMedicalCaseRequest();
  symptom?: CombinedSymptomRequest;
  visit?: CombinedVisitRequest;
  surgery?: CombinedSurgeryRequest;
  follow_up?: CombinedFollowUpRequest;
  examination_reports?: CombinedExaminationReportRequest[];
  prescriptions?: CombinedPrescriptionRequest[];
  source_file_ids?: number[];
}

export class CombinedMedicalCreateResponse {
  member_id: number = 0;
  medical_case_id: number = 0;
  symptom_id?: number;
  visit_id?: number;
  surgery_id?: number;
  follow_up_id?: number;
  examination_report_ids: number[] = [];
  prescription_ids: number[] = [];
  medicine_box_ids: number[] = [];
  medication_plan_ids: number[] = [];
  created_at: string = '';
}

/**
 * 组合医疗创建 API。对齐 iOS SparkCombinedMedicalCreateAPI。
 */
export class SparkCombinedMedicalCreateAPI {
  private readonly configuration: SupportBackendConfiguration;

  constructor(configuration: SupportBackendConfiguration) {
    this.configuration = configuration;
  }

  isConfigured(): boolean {
    return this.configuration !== undefined;
  }

  /** POST /api/v1/medical/combined-create/ */
  async createCombinedMedical(
    request: CombinedMedicalCreateRequest
  ): Promise<CombinedMedicalCreateResponse> {
    const path = '/api/v1/medical/combined-create/';
    const strategy = new NetworkStrategy(
      true,
      false,
      'medical.combined-create',
      false,
      'high',
      RetryConfig.defaultConfig()
    );
    const op = new CacheableSupportNetworkOperation(
      'CombinedMedical.Create',
      'CombinedMedicalCreateAPI',
      new NetworkRequest('POST', path, strategy, [], {}, request as Object)
    );
    return this.configuration.executeDecoded(op, (data: Object | null) => {
      const obj = SupportAPIResponseDecoder.asRecord(data);
      const out = new CombinedMedicalCreateResponse();
      out.member_id = SupportAPIResponseDecoder.num(obj, 'member_id', 0);
      out.medical_case_id = SupportAPIResponseDecoder.num(obj, 'medical_case_id', 0);
      const symptom = SupportAPIResponseDecoder.num(obj, 'symptom_id', 0);
      out.symptom_id = symptom > 0 ? symptom : undefined;
      const visit = SupportAPIResponseDecoder.num(obj, 'visit_id', 0);
      out.visit_id = visit > 0 ? visit : undefined;
      const surgery = SupportAPIResponseDecoder.num(obj, 'surgery_id', 0);
      out.surgery_id = surgery > 0 ? surgery : undefined;
      const followUp = SupportAPIResponseDecoder.num(obj, 'follow_up_id', 0);
      out.follow_up_id = followUp > 0 ? followUp : undefined;
      out.examination_report_ids = SparkCombinedMedicalCreateAPI.readIds(obj, 'examination_report_ids');
      out.prescription_ids = SparkCombinedMedicalCreateAPI.readIds(obj, 'prescription_ids');
      out.medicine_box_ids = SparkCombinedMedicalCreateAPI.readIds(obj, 'medicine_box_ids');
      out.medication_plan_ids = SparkCombinedMedicalCreateAPI.readIds(obj, 'medication_plan_ids');
      out.created_at = SupportAPIResponseDecoder.str(obj, 'created_at', '');
      return out;
    });
  }

  private static readIds(
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
}
