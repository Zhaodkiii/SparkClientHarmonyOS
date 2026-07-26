import { MedicalCardKind } from '../Domain/HomeDashboard';

/** 首页医疗列表路由名。与 iOS HomeMedicalListRoute 对齐。 */
export class HomeMedicalRoutes {
  static readonly MEDICAL_CASES: string = 'home.medical.cases';
  static readonly HEALTH_EXAM_REPORTS: string = 'home.medical.healthExam';
  static readonly HEALTH_EXAM_DETAIL: string = 'home.medical.healthExam.detail';
  static readonly EXAMINATION_REPORTS: string = 'home.medical.examination';
  static readonly EXAMINATION_REPORTS_ARCHIVE: string = 'home.medical.examination.archive';
  static readonly EXAMINATION_DETAIL: string = 'home.medical.examination.detail';
  static readonly EXAMINATION_SUBITEM_DETAIL: string = 'home.medical.examination.subitem';
  static readonly MEDICATION_PLANS: string = 'home.medical.medication';
  static readonly FAMILY_CABINET: string = 'home.medical.familyCabinet';
  static readonly PERSONAL_CABINET: string = 'home.medical.personalCabinet';
  static readonly MEDICINE_BOX_ARCHIVE: string = 'home.medical.medicineBoxArchive';
  static readonly MEDICINE_BOX_DETAIL: string = 'home.medical.medicineBox.detail';
  static readonly MEMBER_SETUP_CREATE: string = 'home.member.setup.create';
  static readonly MEMBER_SETUP_MAINTAIN: string = 'home.member.setup.maintain';
  static readonly MEMBER_DETAIL: string = 'home.member.detail';
  static readonly MEMBER_EDITOR_CREATE: string = 'home.member.editor.create';
  static readonly MEMBER_EDITOR_EDIT: string = 'home.member.editor.edit';

  static fromCardKind(kind: MedicalCardKind): string {
    if (kind === MedicalCardKind.MEDICAL_CASES) {
      return HomeMedicalRoutes.MEDICAL_CASES;
    }
    if (kind === MedicalCardKind.HEALTH_EXAM_REPORTS) {
      return HomeMedicalRoutes.HEALTH_EXAM_REPORTS;
    }
    if (kind === MedicalCardKind.MEDICAL_REPORTS) {
      return HomeMedicalRoutes.EXAMINATION_REPORTS;
    }
    return HomeMedicalRoutes.MEDICATION_PLANS;
  }

  static titleForRoute(route: string): string {
    if (route === HomeMedicalRoutes.MEDICAL_CASES) {
      return '病历';
    }
    if (route === HomeMedicalRoutes.HEALTH_EXAM_REPORTS) {
      return '体检';
    }
    if (route === HomeMedicalRoutes.HEALTH_EXAM_DETAIL) {
      return '体检详情';
    }
    if (route === HomeMedicalRoutes.EXAMINATION_REPORTS) {
      return '检查';
    }
    if (route === HomeMedicalRoutes.EXAMINATION_REPORTS_ARCHIVE) {
      return '归档检查';
    }
    if (route === HomeMedicalRoutes.EXAMINATION_DETAIL) {
      return '检查详情';
    }
    if (route === HomeMedicalRoutes.EXAMINATION_SUBITEM_DETAIL) {
      return '检查明细';
    }
    if (route === HomeMedicalRoutes.FAMILY_CABINET) {
      return '家庭药箱';
    }
    if (route === HomeMedicalRoutes.PERSONAL_CABINET) {
      return '个人药箱';
    }
    if (route === HomeMedicalRoutes.MEDICINE_BOX_ARCHIVE) {
      return '归档药品';
    }
    if (route === HomeMedicalRoutes.MEDICINE_BOX_DETAIL) {
      return '药品详情';
    }
    if (route === HomeMedicalRoutes.MEMBER_SETUP_CREATE) {
      return '添加成员';
    }
    if (route === HomeMedicalRoutes.MEMBER_SETUP_MAINTAIN) {
      return '模块维护';
    }
    if (route === HomeMedicalRoutes.MEMBER_DETAIL) {
      return '成员详情';
    }
    if (route === HomeMedicalRoutes.MEMBER_EDITOR_CREATE) {
      return '添加成员';
    }
    if (route === HomeMedicalRoutes.MEMBER_EDITOR_EDIT) {
      return '编辑成员';
    }
    return '用药';
  }
}
