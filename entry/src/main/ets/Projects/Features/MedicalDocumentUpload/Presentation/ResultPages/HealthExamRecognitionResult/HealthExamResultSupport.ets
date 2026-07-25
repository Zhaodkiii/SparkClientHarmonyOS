import {
  HealthExamRecognitionDraft,
  MedicalReportItem
} from '../../../Domain/MedicalDocumentRecognitionDrafts';
import { MedicalDocumentKind } from '../../../Domain/MedicalDocumentKind';
import { MedicalDocumentUploadViewModel } from '../../MedicalDocumentUploadViewModel';

export class HealthExamRiskCounts {
  high: number = 0;
  medium: number = 0;
  low: number = 0;
}

export class HealthExamResultSupport {
  static ensureDraft(viewModel: MedicalDocumentUploadViewModel): HealthExamRecognitionDraft {
    const tree = viewModel.ensureTypedDraftTree(MedicalDocumentKind.HEALTH_EXAM_REPORT);
    if (tree.healthExamDraft === undefined) {
      tree.healthExamDraft = new HealthExamRecognitionDraft();
    }
    return tree.healthExamDraft;
  }

  static err(viewModel: MedicalDocumentUploadViewModel, fieldKey: string): string {
    return viewModel.preSubmitIssueMessage(fieldKey);
  }

  static riskCounts(draft: HealthExamRecognitionDraft): HealthExamRiskCounts {
    const counts = new HealthExamRiskCounts();
    const items = draft.items;
    for (let i = 0; i < items.length; i++) {
      const flag = (items[i].flag ?? '').toUpperCase();
      if (flag === 'H' || flag === 'HIGH' || flag.indexOf('高') >= 0) {
        counts.high += 1;
      } else if (flag === 'M' || flag === 'MID' || flag.indexOf('中') >= 0) {
        counts.medium += 1;
      } else if (flag === 'L' || flag === 'LOW' || flag.indexOf('低') >= 0) {
        counts.low += 1;
      }
    }
    return counts;
  }

  static visibleItems(draft: HealthExamRecognitionDraft, filterMode: string): MedicalReportItem[] {
    const items = draft.items;
    if (filterMode === 'all') {
      return items;
    }
    const out: MedicalReportItem[] = [];
    for (let i = 0; i < items.length; i++) {
      const flag = (items[i].flag ?? '').toUpperCase();
      const abnormal = flag.length > 0 && flag !== 'N' && flag !== 'NORMAL' &&
        flag.indexOf('正常') < 0;
      if (filterMode === 'abnormal' && abnormal) {
        out.push(items[i]);
      } else if (filterMode === 'normal' && !abnormal) {
        out.push(items[i]);
      }
    }
    return out;
  }
}
