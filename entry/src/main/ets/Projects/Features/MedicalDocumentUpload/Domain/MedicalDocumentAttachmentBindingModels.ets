import { MedicalDocumentKind } from './MedicalDocumentKind';

/**
 * 附件与业务结果匹配 / 绑定相关模型。
 * 对齐 iOS MedicalDocumentAttachmentBinding + MedicalDocumentSaveReceipt。
 * 0010：绑定编排复用 typedDrafts，不另起平行草稿事实源。
 */

/** 保存成功回执（供服务端业务绑定使用）。 */
export class MedicalDocumentSaveReceipt {
  recordID: number = 0;
  savedAt: string = '';
  isSuccess: boolean = false;
  kind: MedicalDocumentKind = MedicalDocumentKind.MEDICAL_REPORT;
  message: string = '';
}

/** 抽取后本地匹配摘要（无网络）。 */
export class MedicalDocumentAttachmentMatchSummary {
  kind: MedicalDocumentKind = MedicalDocumentKind.MEDICAL_REPORT;
  matchedLocalFileIds: string[] = [];
  unmatchedLocalFileIds: string[] = [];
  targetNodeCount: number = 0;
}

/**
 * 保存前准备好的附件绑定载荷（file_ids 已解析为远端 Int）。
 * 真正落库由 SaveUseCase 消费。
 */
export class MedicalDocumentPreparedAttachmentBinding {
  kind: MedicalDocumentKind = MedicalDocumentKind.MEDICAL_REPORT;
  /** 全部分配到草稿节点的本地文件 ID（previewId）。 */
  matchedLocalFileIds: string[] = [];
  /** 对应远端 file id。 */
  remoteFileIds: number[] = [];
  /** 业务类型字符串（与 PATCH files/business/update 一致）。 */
  businessType: string = '';
  /** 体检 / 药箱等保存载荷可直接使用的 file_ids。 */
  fileIdsForSave: number[] = [];
}

export interface MedicalDocumentAttachmentBinding {
  bind(
    remoteFileIds: number[],
    kind: MedicalDocumentKind,
    receipt: MedicalDocumentSaveReceipt
  ): Promise<void>;
}

/** kind → 服务端 business_type。对齐 iOS DefaultMedicalDocumentAttachmentBinder。 */
export class MedicalDocumentAttachmentBusinessTypes {
  static forKind(kind: MedicalDocumentKind): string {
    switch (kind) {
      case MedicalDocumentKind.AUTO:
        return 'medical_document';
      case MedicalDocumentKind.CASE_DOCUMENT:
        return 'medical_case';
      case MedicalDocumentKind.HEALTH_EXAM_REPORT:
        return 'health_exam_report';
      case MedicalDocumentKind.MEDICAL_REPORT:
        return 'examination_report';
      case MedicalDocumentKind.PRESCRIPTION:
        return 'prescription_batch';
      case MedicalDocumentKind.MEDICATION_PLAN:
        return 'medication_plan';
      case MedicalDocumentKind.MEDICINE_BOX:
        return 'medicine_box';
      default:
        return 'medical_document';
    }
  }
}

export class MedicalDocumentAttachmentIdUtils {
  static appendUnique(ids: string[], value: string): string[] {
    if (value.length === 0) {
      return ids;
    }
    if (ids.indexOf(value) >= 0) {
      return ids;
    }
    const next = ids.slice();
    next.push(value);
    return next;
  }

  static uniqueNumbers(ids: number[]): number[] {
    const out: number[] = [];
    for (let i = 0; i < ids.length; i++) {
      const id = ids[i];
      if (id > 0 && out.indexOf(id) < 0) {
        out.push(id);
      }
    }
    return out;
  }
}
