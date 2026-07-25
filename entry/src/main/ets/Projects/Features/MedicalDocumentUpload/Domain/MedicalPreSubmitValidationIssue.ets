/**
 * 预提交校验问题模型。对齐 iOS MedicalPreSubmitValidationIssue。
 */

export enum MedicalPreSubmitValidationSeverity {
  BLOCKING = 'blocking',
  WARNING = 'warning'
}

export enum MedicalPreSubmitValidationResourceType {
  CASE_DOCUMENT = 'caseDocument',
  SYMPTOM = 'symptom',
  VISIT = 'visit',
  SURGERY = 'surgery',
  FOLLOW_UP = 'followUp',
  HEALTH_EXAM_REPORT = 'healthExamReport',
  EXAMINATION_REPORT = 'examinationReport',
  PRESCRIPTION = 'prescription',
  MEDICATION_PLAN = 'medicationPlan',
  MEDICINE_BOX = 'medicineBox'
}

export class MedicalPreSubmitValidationSectionID {
  static readonly CASE_HISTORY: string = 'preSubmitValidation.section.caseHistory';
  static readonly EXAMINATION_REPORTS: string = 'preSubmitValidation.section.examinationReports';
  static readonly TREATMENT_PLAN: string = 'preSubmitValidation.section.treatmentPlan';
  static readonly MEDICATION_LIST: string = 'preSubmitValidation.section.medicationList';
  static readonly MEDICINE_BOX_LIST: string = 'preSubmitValidation.section.medicineBoxList';
  static readonly HEALTH_EXAM_GROUPS: string = 'preSubmitValidation.section.healthExamGroups';
}

export class MedicalPreSubmitValidationIssue {
  id: string = '';
  resourceType: MedicalPreSubmitValidationResourceType =
    MedicalPreSubmitValidationResourceType.CASE_DOCUMENT;
  fieldPath: string = '';
  fieldKey: string = '';
  fieldLabel: string = '';
  message: string = '';
  severity: MedicalPreSubmitValidationSeverity = MedicalPreSubmitValidationSeverity.BLOCKING;
  sectionTitle: string = '';
  cardIndex?: number;
  prescriptionIndex?: number;

  /** 兼容旧三字段模型：blocking 映射 severity。 */
  get blocking(): boolean {
    return this.severity === MedicalPreSubmitValidationSeverity.BLOCKING;
  }

  set blocking(value: boolean) {
    this.severity = value ?
      MedicalPreSubmitValidationSeverity.BLOCKING :
      MedicalPreSubmitValidationSeverity.WARNING;
  }

  scrollTargetID(): string {
    return MedicalPreSubmitValidationIssue.makeScrollTargetID(
      this.resourceType,
      this.fieldKey,
      this.cardIndex,
      this.prescriptionIndex
    );
  }

  collapseSectionID(): string | undefined {
    switch (this.resourceType) {
      case MedicalPreSubmitValidationResourceType.CASE_DOCUMENT:
      case MedicalPreSubmitValidationResourceType.SYMPTOM:
      case MedicalPreSubmitValidationResourceType.VISIT:
      case MedicalPreSubmitValidationResourceType.SURGERY:
      case MedicalPreSubmitValidationResourceType.FOLLOW_UP:
        return MedicalPreSubmitValidationSectionID.CASE_HISTORY;
      case MedicalPreSubmitValidationResourceType.EXAMINATION_REPORT:
        return MedicalPreSubmitValidationSectionID.EXAMINATION_REPORTS;
      case MedicalPreSubmitValidationResourceType.PRESCRIPTION:
        return MedicalPreSubmitValidationSectionID.TREATMENT_PLAN;
      case MedicalPreSubmitValidationResourceType.MEDICATION_PLAN:
        return this.prescriptionIndex !== undefined ?
          MedicalPreSubmitValidationSectionID.TREATMENT_PLAN :
          MedicalPreSubmitValidationSectionID.MEDICATION_LIST;
      case MedicalPreSubmitValidationResourceType.MEDICINE_BOX:
        return MedicalPreSubmitValidationSectionID.MEDICINE_BOX_LIST;
      case MedicalPreSubmitValidationResourceType.HEALTH_EXAM_REPORT:
        return undefined;
      default:
        return undefined;
    }
  }

  summaryLine(): string {
    if (this.fieldLabel.length > 0) {
      return `${this.fieldLabel}：${this.message}`;
    }
    return this.message;
  }

  static make(
    resourceType: MedicalPreSubmitValidationResourceType,
    fieldKey: string,
    fieldLabel: string,
    message: string,
    sectionTitle: string,
    cardIndex?: number,
    prescriptionIndex?: number
  ): MedicalPreSubmitValidationIssue {
    const issue = new MedicalPreSubmitValidationIssue();
    issue.id = `psv_${Date.now()}_${Math.floor(Math.random() * 100000)}`;
    issue.resourceType = resourceType;
    issue.fieldPath = fieldKey;
    issue.fieldKey = fieldKey;
    issue.fieldLabel = fieldLabel;
    issue.message = message;
    issue.severity = MedicalPreSubmitValidationSeverity.BLOCKING;
    issue.sectionTitle = sectionTitle;
    issue.cardIndex = cardIndex;
    issue.prescriptionIndex = prescriptionIndex;
    return issue;
  }

  static makeScrollTargetID(
    resourceType: MedicalPreSubmitValidationResourceType,
    fieldKey: string,
    cardIndex?: number,
    prescriptionIndex?: number
  ): string {
    if (prescriptionIndex !== undefined && cardIndex !== undefined &&
      resourceType === MedicalPreSubmitValidationResourceType.MEDICATION_PLAN) {
      return `preSubmitValidation.card.medicationPlan.${prescriptionIndex}.${cardIndex}`;
    }
    if (resourceType === MedicalPreSubmitValidationResourceType.HEALTH_EXAM_REPORT &&
      cardIndex !== undefined) {
      return `preSubmitValidation.card.healthExamReport.item.${cardIndex}`;
    }
    if (cardIndex !== undefined &&
      (resourceType === MedicalPreSubmitValidationResourceType.EXAMINATION_REPORT ||
        resourceType === MedicalPreSubmitValidationResourceType.MEDICINE_BOX ||
        resourceType === MedicalPreSubmitValidationResourceType.PRESCRIPTION ||
        resourceType === MedicalPreSubmitValidationResourceType.MEDICATION_PLAN)) {
      return `preSubmitValidation.card.${resourceType}.${cardIndex}`;
    }
    return `preSubmitValidation.field.${fieldKey}`;
  }

  static blockingIssues(issues: MedicalPreSubmitValidationIssue[]): MedicalPreSubmitValidationIssue[] {
    return issues.filter((item: MedicalPreSubmitValidationIssue): boolean => item.blocking);
  }

  static issuesForFieldKey(
    issues: MedicalPreSubmitValidationIssue[],
    fieldKey: string
  ): MedicalPreSubmitValidationIssue[] {
    return issues.filter((item: MedicalPreSubmitValidationIssue): boolean =>
      item.fieldKey === fieldKey
    );
  }
}
