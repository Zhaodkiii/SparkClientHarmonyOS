import {
  RemoteExaminationReportWithAttachments,
  RemoteHealthExamReportWithAttachments,
  RemoteMedicalCaseSummary,
  RemoteMedicationPlan,
  RemoteMedicationRecord,
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

  static patchTodayMedicationRecords(homeVm: HomeViewModel, records: RemoteMedicationRecord[]): void {
    homeVm.updateMedicalCompleteData((data) => {
      data.todayMedicationRecords = records;
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

  static upsertMedicineBox(homeVm: HomeViewModel, box: RemoteMedicineBox): void {
    homeVm.updateMedicalCompleteData((data) => {
      const next: RemoteMedicineBox[] = [];
      let replaced = false;
      for (let i = 0; i < data.medicineBoxes.length; i++) {
        if (data.medicineBoxes[i].id === box.id) {
          next.push(box);
          replaced = true;
        } else {
          next.push(data.medicineBoxes[i]);
        }
      }
      if (!replaced) {
        next.push(box);
      }
      data.medicineBoxes = next;
    });
  }

  static removeMedicineBox(homeVm: HomeViewModel, boxID: number): void {
    homeVm.updateMedicalCompleteData((data) => {
      const next: RemoteMedicineBox[] = [];
      for (let i = 0; i < data.medicineBoxes.length; i++) {
        if (data.medicineBoxes[i].id !== boxID) {
          next.push(data.medicineBoxes[i]);
        }
      }
      data.medicineBoxes = next;
    });
  }

  static upsertFamilyMedicineBox(homeVm: HomeViewModel, box: RemoteMedicineBox): void {
    homeVm.updateMedicalCompleteData((data) => {
      const source = data.familyMedicineBoxes ?? [];
      const next: RemoteMedicineBox[] = [];
      let replaced = false;
      for (let i = 0; i < source.length; i++) {
        if (source[i].id === box.id) {
          next.push(box);
          replaced = true;
        } else {
          next.push(source[i]);
        }
      }
      if (!replaced) {
        next.push(box);
      }
      data.familyMedicineBoxes = next;
    });
  }

  static removeFamilyMedicineBox(homeVm: HomeViewModel, boxID: number): void {
    homeVm.updateMedicalCompleteData((data) => {
      const source = data.familyMedicineBoxes ?? [];
      const next: RemoteMedicineBox[] = [];
      for (let i = 0; i < source.length; i++) {
        if (source[i].id !== boxID) {
          next.push(source[i]);
        }
      }
      data.familyMedicineBoxes = next;
    });
  }
}
