import {
  RemoteExaminationReportWithAttachments,
  RemoteHealthExamReportWithAttachments,
  RemoteMedicalCaseSummary,
  RemoteMedicationPlan,
  RemoteMedicineBox,
  RemotePrescription
} from '../../../Core/Networking/API/Medical/MedicalSyncAPI';
import { HomeViewModel } from './HomeViewModel';

/**
 * 首页医疗列表注入与字段回写接线。与 iOS HomeMedicalRouteSupport 对齐。
 * 无状态；权威缓存仍在 HomeViewModel。
 */
export class HomeMedicalRouteSupport {
  static patchMedicalCases(homeVm: HomeViewModel, cases: RemoteMedicalCaseSummary[]): void {
    homeVm.updateMedicalCompleteData((data) => {
      data.medicalCases = cases;
    });
  }

  static patchHealthExamReports(
    homeVm: HomeViewModel,
    reports: RemoteHealthExamReportWithAttachments[]
  ): void {
    homeVm.updateMedicalCompleteData((data) => {
      data.healthExamReports = reports;
    });
  }

  static removeHealthExamReport(homeVm: HomeViewModel, reportID: number): void {
    homeVm.updateMedicalCompleteData((data) => {
      const next: RemoteHealthExamReportWithAttachments[] = [];
      for (let i = 0; i < data.healthExamReports.length; i++) {
        if (data.healthExamReports[i].id !== reportID) {
          next.push(data.healthExamReports[i]);
        }
      }
      data.healthExamReports = next;
    });
  }

  static patchExaminationReports(
    homeVm: HomeViewModel,
    reports: RemoteExaminationReportWithAttachments[]
  ): void {
    homeVm.updateMedicalCompleteData((data) => {
      data.examinationReports = reports;
    });
  }

  static removeExaminationReport(homeVm: HomeViewModel, reportID: number): void {
    homeVm.updateMedicalCompleteData((data) => {
      const next: RemoteExaminationReportWithAttachments[] = [];
      for (let i = 0; i < data.examinationReports.length; i++) {
        if (data.examinationReports[i].id !== reportID) {
          next.push(data.examinationReports[i]);
        }
      }
      data.examinationReports = next;
    });
  }

  static replaceExaminationReport(
    homeVm: HomeViewModel,
    report: RemoteExaminationReportWithAttachments
  ): void {
    homeVm.updateMedicalCompleteData((data) => {
      const next: RemoteExaminationReportWithAttachments[] = [];
      let replaced = false;
      for (let i = 0; i < data.examinationReports.length; i++) {
        if (data.examinationReports[i].id === report.id) {
          next.push(report.clone());
          replaced = true;
        } else {
          next.push(data.examinationReports[i]);
        }
      }
      if (!replaced) {
        next.push(report.clone());
      }
      data.examinationReports = next;
    });
  }

  static patchMedicationPlans(homeVm: HomeViewModel, plans: RemoteMedicationPlan[]): void {
    homeVm.updateMedicalCompleteData((data) => {
      data.medicationPlans = plans;
    });
  }

  static patchPrescriptions(homeVm: HomeViewModel, prescriptions: RemotePrescription[]): void {
    homeVm.updateMedicalCompleteData((data) => {
      data.prescriptions = prescriptions;
    });
  }

  static patchMedicineBoxes(homeVm: HomeViewModel, boxes: RemoteMedicineBox[]): void {
    homeVm.updateMedicalCompleteData((data) => {
      data.medicineBoxes = boxes;
    });
  }

  static patchFamilyMedicineBoxes(homeVm: HomeViewModel, boxes: RemoteMedicineBox[]): void {
    homeVm.updateMedicalCompleteData((data) => {
      data.familyMedicineBoxes = boxes;
    });
  }
}
