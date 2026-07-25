import { MedicalDocumentKind } from './MedicalDocumentKind';
import {
  CaseRecognitionDraft,
  HealthExamRecognitionDraft,
  MedicalDocumentTypedDraftTree,
  MedicalReportRecognitionDraft,
  MedicationPlanRecognitionDraft,
  MedicineBoxRecognitionDraft,
  PrescriptionRecognitionDraft
} from './MedicalDocumentRecognitionDrafts';
import {
  MedicalPreSubmitValidationIssue,
  MedicalPreSubmitValidationResourceType
} from './MedicalPreSubmitValidationIssue';
import { MedicalPreSubmitValidationRules } from './MedicalPreSubmitValidationRules';
import { MedicalDocumentTypedExtractionOutput } from './MedicalDocumentTypedModels';
import {
  EXTRA_KEY_PAYMENT_STATUS_TEXT,
  PrescriptionFieldNormalization
} from './PrescriptionFieldNormalization';

export interface MedicalPreSubmitValidating {
  validate(output: MedicalDocumentTypedExtractionOutput): MedicalPreSubmitValidationIssue[];
}

/**
 * 保存前字段级预校验。对齐 iOS MedicalPreSubmitValidator。
 * 只返回问题列表，不改业务数据、不操作 UI。
 */
export class MedicalPreSubmitValidator implements MedicalPreSubmitValidating {
  validate(output: MedicalDocumentTypedExtractionOutput): MedicalPreSubmitValidationIssue[] {
    if (output.extractedJSON.trim().length === 0 &&
      output.typedDrafts.displayTitle().length === 0) {
      return [
        MedicalPreSubmitValidationIssue.make(
          MedicalPreSubmitValidationResourceType.CASE_DOCUMENT,
          'typed_output',
          '识别结果',
          '缺少可保存的结构化结果',
          '识别结果'
        )
      ];
    }
    return this.validateDraftTree(output.typedDrafts);
  }

  validateDraftTree(tree: MedicalDocumentTypedDraftTree): MedicalPreSubmitValidationIssue[] {
    switch (tree.kind) {
      case MedicalDocumentKind.CASE_DOCUMENT:
        return tree.caseDraft !== undefined ?
          this.validateCaseDocument(tree.caseDraft) : [
            MedicalPreSubmitValidationIssue.make(
              MedicalPreSubmitValidationResourceType.CASE_DOCUMENT,
              'medical_case',
              '病例',
              '病例草稿为空',
              '病历'
            )
          ];
      case MedicalDocumentKind.HEALTH_EXAM_REPORT:
        return tree.healthExamDraft !== undefined ?
          this.validateHealthExam(tree.healthExamDraft) : [
            MedicalPreSubmitValidationIssue.make(
              MedicalPreSubmitValidationResourceType.HEALTH_EXAM_REPORT,
              'health_exam',
              '体检报告',
              '体检草稿为空',
              '体检'
            )
          ];
      case MedicalDocumentKind.MEDICAL_REPORT:
        return this.validateMedicalReports(tree.medicalReportDrafts);
      case MedicalDocumentKind.PRESCRIPTION:
        return this.validatePrescriptions(tree.prescriptionDrafts);
      case MedicalDocumentKind.MEDICATION_PLAN:
        return this.validateMedicationPlans(tree.medicationPlanDrafts, undefined);
      case MedicalDocumentKind.MEDICINE_BOX:
        return this.validateMedicineBoxes(tree.medicineBoxDrafts);
      default:
        return [];
    }
  }

  private validateCaseDocument(draft: CaseRecognitionDraft): MedicalPreSubmitValidationIssue[] {
    const issues: MedicalPreSubmitValidationIssue[] = [];
    if (MedicalPreSubmitValidationRules.isBlank(draft.title)) {
      issues.push(MedicalPreSubmitValidationIssue.make(
        MedicalPreSubmitValidationResourceType.CASE_DOCUMENT,
        'medical_case.title', '标题', '标题为空', '病历'
      ));
    }
    if (!MedicalPreSubmitValidationRules.requiresCompleteDateIfPresent(draft.occurredAt)) {
      issues.push(MedicalPreSubmitValidationIssue.make(
        MedicalPreSubmitValidationResourceType.CASE_DOCUMENT,
        'medical_case.occurred_at', '就诊日期',
        MedicalPreSubmitValidationRules.completeDateMessage(), '病历'
      ));
    }
    if (!MedicalPreSubmitValidationRules.isBlank(draft.ageAtVisit) &&
      !MedicalPreSubmitValidationRules.isValidIntegerString(draft.ageAtVisit)) {
      issues.push(MedicalPreSubmitValidationIssue.make(
        MedicalPreSubmitValidationResourceType.CASE_DOCUMENT,
        'medical_case.age_at_visit', '就诊年龄', '年龄必须是整数', '病历'
      ));
    }
    if (draft.symptom !== undefined) {
      if (MedicalPreSubmitValidationRules.isBlank(draft.symptom.name)) {
        issues.push(MedicalPreSubmitValidationIssue.make(
          MedicalPreSubmitValidationResourceType.SYMPTOM,
          'symptom.name', '症状名称', '主诉为空', '病历'
        ));
      }
      if (!MedicalPreSubmitValidationRules.requiresCompleteDateIfPresent(draft.symptom.startedAt)) {
        issues.push(MedicalPreSubmitValidationIssue.make(
          MedicalPreSubmitValidationResourceType.SYMPTOM,
          'symptom.started_at', '症状开始时间',
          MedicalPreSubmitValidationRules.completeDateMessage(), '病历'
        ));
      }
    }
    if (draft.visit !== undefined &&
      !MedicalPreSubmitValidationRules.requiresCompleteDateIfPresent(draft.visit.visitedAt)) {
      issues.push(MedicalPreSubmitValidationIssue.make(
        MedicalPreSubmitValidationResourceType.VISIT,
        'visit.visited_at', '就诊时间',
        MedicalPreSubmitValidationRules.completeDateMessage(), '病历'
      ));
    }
    if (draft.examinationReports !== undefined) {
      for (let i = 0; i < draft.examinationReports.length; i++) {
        this.appendExaminationReportIssues(issues, draft.examinationReports[i], i);
      }
    }
    if (draft.prescriptions !== undefined) {
      for (let i = 0; i < draft.prescriptions.length; i++) {
        this.appendPrescriptionIssues(issues, draft.prescriptions[i], i);
      }
    }
    return issues;
  }

  private validateHealthExam(draft: HealthExamRecognitionDraft): MedicalPreSubmitValidationIssue[] {
    const issues: MedicalPreSubmitValidationIssue[] = [];
    if (MedicalPreSubmitValidationRules.isBlank(draft.institutionName)) {
      issues.push(MedicalPreSubmitValidationIssue.make(
        MedicalPreSubmitValidationResourceType.HEALTH_EXAM_REPORT,
        'health_exam.institution_name', '体检机构', '机构名为空', '体检'
      ));
    }
    if (!MedicalPreSubmitValidationRules.requiresCompleteDateIfPresent(draft.examDate)) {
      issues.push(MedicalPreSubmitValidationIssue.make(
        MedicalPreSubmitValidationResourceType.HEALTH_EXAM_REPORT,
        'health_exam.exam_date', '体检日期',
        MedicalPreSubmitValidationRules.completeDateMessage(), '体检'
      ));
    }
    for (let i = 0; i < draft.items.length; i++) {
      const item = draft.items[i];
      if (MedicalPreSubmitValidationRules.isBlank(item.itemName)) {
        issues.push(MedicalPreSubmitValidationIssue.make(
          MedicalPreSubmitValidationResourceType.HEALTH_EXAM_REPORT,
          `health_exam.items[${i}].item_name`, '项目名称', '项目名缺失', '体检', i
        ));
      }
      if (MedicalPreSubmitValidationRules.isBlank(item.resultValue)) {
        issues.push(MedicalPreSubmitValidationIssue.make(
          MedicalPreSubmitValidationResourceType.HEALTH_EXAM_REPORT,
          `health_exam.items[${i}].result_value`, '结果值', '结果值为空', '体检', i
        ));
      }
    }
    return issues;
  }

  private validateMedicalReports(
    drafts: MedicalReportRecognitionDraft[]
  ): MedicalPreSubmitValidationIssue[] {
    const issues: MedicalPreSubmitValidationIssue[] = [];
    if (drafts.length === 0) {
      issues.push(MedicalPreSubmitValidationIssue.make(
        MedicalPreSubmitValidationResourceType.EXAMINATION_REPORT,
        'examination_reports', '检查报告', '报告列表为空', '检查报告'
      ));
      return issues;
    }
    for (let i = 0; i < drafts.length; i++) {
      this.appendExaminationReportIssues(issues, drafts[i], i);
    }
    return issues;
  }

  private appendExaminationReportIssues(
    issues: MedicalPreSubmitValidationIssue[],
    draft: MedicalReportRecognitionDraft,
    index: number
  ): void {
    if (MedicalPreSubmitValidationRules.isBlank(draft.title)) {
      issues.push(MedicalPreSubmitValidationIssue.make(
        MedicalPreSubmitValidationResourceType.EXAMINATION_REPORT,
        `examination_reports[${index}].item_name`, '报告标题', '报告标题为空', '检查报告', index
      ));
    }
    if (!MedicalPreSubmitValidationRules.requiresCompleteDateIfPresent(draft.date)) {
      issues.push(MedicalPreSubmitValidationIssue.make(
        MedicalPreSubmitValidationResourceType.EXAMINATION_REPORT,
        `examination_reports[${index}].performed_at`, '检查日期',
        MedicalPreSubmitValidationRules.completeDateMessage(), '检查报告', index
      ));
    }
    if (!MedicalPreSubmitValidationRules.isValidExaminationCategory(draft.category)) {
      issues.push(MedicalPreSubmitValidationIssue.make(
        MedicalPreSubmitValidationResourceType.EXAMINATION_REPORT,
        `examination_reports[${index}].category`, '报告分类', '分类值不在白名单', '检查报告', index
      ));
    }
    const lab = MedicalPreSubmitValidationRules.isLaboratoryCategory(draft.category);
    for (let m = 0; m < draft.details.length; m++) {
      const detail = draft.details[m];
      if (MedicalPreSubmitValidationRules.isBlank(detail.itemName)) {
        issues.push(MedicalPreSubmitValidationIssue.make(
          MedicalPreSubmitValidationResourceType.EXAMINATION_REPORT,
          `examination_reports[${index}].details[${m}].item_name`,
          '明细项目', '明细项名称缺失', '检查报告', index
        ));
      }
      if (lab && MedicalPreSubmitValidationRules.isBlank(detail.resultValue)) {
        issues.push(MedicalPreSubmitValidationIssue.make(
          MedicalPreSubmitValidationResourceType.EXAMINATION_REPORT,
          `examination_reports[${index}].details[${m}].result_value`,
          '明细结果', '检验结果值为空', '检查报告', index
        ));
      }
    }
  }

  private validatePrescriptions(
    drafts: PrescriptionRecognitionDraft[]
  ): MedicalPreSubmitValidationIssue[] {
    const issues: MedicalPreSubmitValidationIssue[] = [];
    if (drafts.length === 0) {
      issues.push(MedicalPreSubmitValidationIssue.make(
        MedicalPreSubmitValidationResourceType.PRESCRIPTION,
        'prescriptions', '处方', '处方批次为空', '处方'
      ));
      return issues;
    }
    for (let i = 0; i < drafts.length; i++) {
      this.appendPrescriptionIssues(issues, drafts[i], i);
    }
    return issues;
  }

  private appendPrescriptionIssues(
    issues: MedicalPreSubmitValidationIssue[],
    draft: PrescriptionRecognitionDraft,
    index: number
  ): void {
    if (!MedicalPreSubmitValidationRules.requiresCompleteDateIfPresent(draft.prescribedAt)) {
      issues.push(MedicalPreSubmitValidationIssue.make(
        MedicalPreSubmitValidationResourceType.PRESCRIPTION,
        `prescriptions[${index}].prescribed_at`, '开方日期',
        MedicalPreSubmitValidationRules.completeDateMessage(), '处方', index
      ));
    }
    // 规范化后状态应在白名单；若仍残留支付类文本则用 resolved 后状态判断
    const status = PrescriptionFieldNormalization.resolvedLifecycleStatus(draft.status);
    if (draft.status !== undefined && draft.status.trim().length > 0 &&
      !MedicalPreSubmitValidationRules.isValidPrescriptionStatus(status) &&
      (draft.extra === undefined || !draft.extra.has(EXTRA_KEY_PAYMENT_STATUS_TEXT))) {
      // 已规范化的草稿 status 应为 active/completed/cancelled
      if (!MedicalPreSubmitValidationRules.isValidPrescriptionStatus(draft.status)) {
        issues.push(MedicalPreSubmitValidationIssue.make(
          MedicalPreSubmitValidationResourceType.PRESCRIPTION,
          `prescriptions[${index}].status`, '处方状态', '状态不在白名单', '处方', index
        ));
      }
    }
    const plans = draft.medicationPlans ?? [];
    this.appendMedicationPlanIssues(issues, plans, index);
  }

  private validateMedicationPlans(
    plans: MedicationPlanRecognitionDraft[],
    prescriptionIndex: number | undefined
  ): MedicalPreSubmitValidationIssue[] {
    const issues: MedicalPreSubmitValidationIssue[] = [];
    this.appendMedicationPlanIssues(issues, plans, prescriptionIndex);
    return issues;
  }

  private appendMedicationPlanIssues(
    issues: MedicalPreSubmitValidationIssue[],
    plans: MedicationPlanRecognitionDraft[],
    prescriptionIndex: number | undefined
  ): void {
    for (let n = 0; n < plans.length; n++) {
      const plan = plans[n];
      const prefix = prescriptionIndex !== undefined ?
        `prescriptions[${prescriptionIndex}].medication_plans[${n}]` :
        `medication_plans[${n}]`;
      const drugName = plan.medicineName ?? plan.medicineBox?.medicineName ?? plan.brandName;
      if (MedicalPreSubmitValidationRules.isBlank(drugName)) {
        issues.push(MedicalPreSubmitValidationIssue.make(
          MedicalPreSubmitValidationResourceType.MEDICATION_PLAN,
          `${prefix}.drug_name`, '药品名称', '药名为空', '用药计划', n, prescriptionIndex
        ));
      }
      if (!MedicalPreSubmitValidationRules.requiresCompleteDateIfPresent(plan.startDate)) {
        issues.push(MedicalPreSubmitValidationIssue.make(
          MedicalPreSubmitValidationResourceType.MEDICATION_PLAN,
          `${prefix}.start_date`, '开始日期',
          MedicalPreSubmitValidationRules.completeDateMessage(), '用药计划', n, prescriptionIndex
        ));
      }
      const doseUnit = plan.doseUnit ?? plan.medicineBox?.doseUnit;
      if (!MedicalPreSubmitValidationRules.isBlank(doseUnit) &&
        MedicalPreSubmitValidationRules.isBlank(plan.dosePerTime)) {
        issues.push(MedicalPreSubmitValidationIssue.make(
          MedicalPreSubmitValidationResourceType.MEDICATION_PLAN,
          `${prefix}.dose_per_time`, '单次用量', '已有剂量单位但缺少单次用量', '用药计划',
          n, prescriptionIndex
        ));
      }
      if (MedicalPreSubmitValidationRules.isBlank(plan.frequencyType) ||
        !MedicalPreSubmitValidationRules.isValidFrequencyType(plan.frequencyType)) {
        issues.push(MedicalPreSubmitValidationIssue.make(
          MedicalPreSubmitValidationResourceType.MEDICATION_PLAN,
          `${prefix}.frequency_type`, '频次类型', '频次类型无效', '用药计划', n, prescriptionIndex
        ));
      }
      if (!MedicalPreSubmitValidationRules.isValidDecimalString(plan.doseValue)) {
        issues.push(MedicalPreSubmitValidationIssue.make(
          MedicalPreSubmitValidationResourceType.MEDICATION_PLAN,
          `${prefix}.dose_value`, '剂量数值', '剂量必须是合法数字', '用药计划', n, prescriptionIndex
        ));
      }
      if (!MedicalPreSubmitValidationRules.isValidMedicationPlanStatus(plan.status) &&
        !MedicalPreSubmitValidationRules.isBlank(plan.status)) {
        // 透传中文未知状态：对齐 iOS 预检对非法 status 的阻断（白名单）
        const lower = (plan.status ?? '').toLowerCase();
        if (['active', 'paused', 'completed', 'cancelled'].indexOf(lower) < 0 &&
          plan.status !== '执行中' && plan.status !== '生效' &&
          plan.status !== '有效' && plan.status !== '进行中') {
          issues.push(MedicalPreSubmitValidationIssue.make(
            MedicalPreSubmitValidationResourceType.MEDICATION_PLAN,
            `${prefix}.status`, '计划状态', '状态不在白名单', '用药计划', n, prescriptionIndex
          ));
        }
      }
      if (!MedicalPreSubmitValidationRules.isValidEveryNDays(plan.frequencyType, plan.everyNDays)) {
        issues.push(MedicalPreSubmitValidationIssue.make(
          MedicalPreSubmitValidationResourceType.MEDICATION_PLAN,
          `${prefix}.every_n_days`, '间隔天数', '间隔天数须为 1–365', '用药计划',
          n, prescriptionIndex
        ));
      }
      if (!MedicalPreSubmitValidationRules.isValidWeeklyWeekdays(
        plan.frequencyType, plan.weeklyWeekdays
      )) {
        issues.push(MedicalPreSubmitValidationIssue.make(
          MedicalPreSubmitValidationResourceType.MEDICATION_PLAN,
          `${prefix}.weekly_weekdays`, '每周星期', '星期值须在 1–7', '用药计划',
          n, prescriptionIndex
        ));
      }
      if (!MedicalPreSubmitValidationRules.requiresCompleteDateIfPresent(plan.endDate)) {
        issues.push(MedicalPreSubmitValidationIssue.make(
          MedicalPreSubmitValidationResourceType.MEDICATION_PLAN,
          `${prefix}.end_date`, '结束日期',
          MedicalPreSubmitValidationRules.completeDateMessage(), '用药计划', n, prescriptionIndex
        ));
      }
      if (!MedicalPreSubmitValidationRules.isEndDateNotBeforeStart(plan.startDate, plan.endDate)) {
        issues.push(MedicalPreSubmitValidationIssue.make(
          MedicalPreSubmitValidationResourceType.MEDICATION_PLAN,
          `${prefix}.end_date`, '结束日期', '结束日期不能早于开始日期', '用药计划',
          n, prescriptionIndex
        ));
      }
      if (!MedicalPreSubmitValidationRules.isValidReminderTimes(plan.reminderTimes)) {
        issues.push(MedicalPreSubmitValidationIssue.make(
          MedicalPreSubmitValidationResourceType.MEDICATION_PLAN,
          `${prefix}.reminder_times`, '提醒时间', '提醒时间须为 HH:mm', '用药计划',
          n, prescriptionIndex
        ));
      }
      if (plan.medicineBox !== undefined &&
        !MedicalPreSubmitValidationRules.requiresCompleteDateIfPresent(plan.medicineBox.expireDate)) {
        issues.push(MedicalPreSubmitValidationIssue.make(
          MedicalPreSubmitValidationResourceType.MEDICATION_PLAN,
          `${prefix}.medicine_box.expire_date`, '药箱有效期',
          MedicalPreSubmitValidationRules.completeDateMessage(), '用药计划', n, prescriptionIndex
        ));
      }
      const confirmed = plan.extra?.get('confirmed_medicine_box_id');
      const unlinked = plan.extra?.get('medicine_box_unlinked');
      if (confirmed !== undefined && confirmed.length > 0 &&
        plan.medicineBox !== undefined && unlinked !== 'true') {
        // 同时有确认绑定 ID 与内联药箱草稿时提示冲突（对齐 iOS）
        issues.push(MedicalPreSubmitValidationIssue.make(
          MedicalPreSubmitValidationResourceType.MEDICATION_PLAN,
          `${prefix}.medicine_box`, '药箱绑定', '不能同时绑定已有药箱并保留新建药箱草稿',
          '用药计划', n, prescriptionIndex
        ));
      }
    }
  }

  private validateMedicineBoxes(
    boxes: MedicineBoxRecognitionDraft[]
  ): MedicalPreSubmitValidationIssue[] {
    const issues: MedicalPreSubmitValidationIssue[] = [];
    for (let i = 0; i < boxes.length; i++) {
      const box = boxes[i];
      if (MedicalPreSubmitValidationRules.isBlank(box.medicineName)) {
        issues.push(MedicalPreSubmitValidationIssue.make(
          MedicalPreSubmitValidationResourceType.MEDICINE_BOX,
          `medicine_boxes[${i}].medicine_name`, '药品名称', '药名缺失', '药箱', i
        ));
      }
      if (!MedicalPreSubmitValidationRules.requiresCompleteDateIfPresent(box.expireDate)) {
        issues.push(MedicalPreSubmitValidationIssue.make(
          MedicalPreSubmitValidationResourceType.MEDICINE_BOX,
          `medicine_boxes[${i}].expire_date`, '有效期',
          MedicalPreSubmitValidationRules.completeDateMessage(), '药箱', i
        ));
      }
      if (!MedicalPreSubmitValidationRules.isNonNegativeNumber(box.totalQuantity)) {
        issues.push(MedicalPreSubmitValidationIssue.make(
          MedicalPreSubmitValidationResourceType.MEDICINE_BOX,
          `medicine_boxes[${i}].total_quantity`, '总数量', '数量必须非负', '药箱', i
        ));
      }
    }
    return issues;
  }
}
