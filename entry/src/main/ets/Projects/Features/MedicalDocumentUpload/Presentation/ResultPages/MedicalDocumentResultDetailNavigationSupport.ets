import { MedicalDocumentUploadViewModel } from '../MedicalDocumentUploadViewModel';

/**
 * 结果页详情导航上下文桩。对齐 iOS MedicalDocumentResultDetailNavigationSupport。
 * 正式 Home 详情桥接将在保存 receipt 接线后补齐。
 */
export class MedicalDocumentResultDetailNavigationContext {
  memberId: number = 0;
  viewModel: MedicalDocumentUploadViewModel | undefined = undefined;

  constructor(memberId: number, viewModel: MedicalDocumentUploadViewModel) {
    this.memberId = memberId;
    this.viewModel = viewModel;
  }
}

export class MedicalDocumentResultDetailNavigationSupport {
  static makeContext(
    memberId: number,
    viewModel: MedicalDocumentUploadViewModel
  ): MedicalDocumentResultDetailNavigationContext | undefined {
    if (memberId <= 0) {
      return undefined;
    }
    return new MedicalDocumentResultDetailNavigationContext(memberId, viewModel);
  }

  /** 保存 receipt 就绪后跳转业务详情的占位出口。 */
  static shouldOpenDetailAfterSave(viewModel: MedicalDocumentUploadViewModel): boolean {
    return viewModel.saveReceipt !== undefined;
  }
}
