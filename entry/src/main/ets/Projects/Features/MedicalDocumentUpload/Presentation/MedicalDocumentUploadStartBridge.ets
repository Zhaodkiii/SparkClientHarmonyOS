import { MedicalDocumentKind } from '../Domain/MedicalDocumentKind';
import { MedicalUploadLocalFile } from '../Domain/MedicalDocumentUploadModels';

type MedicalDocumentUploadStartHandler = (
  files: MedicalUploadLocalFile[],
  kind: MedicalDocumentKind
) => void;

/**
 * 根 HomeTabPage 持有全屏上传 Host，二级医疗列表页只负责产出本地文件。
 * 通过这个轻量桥接近 iOS `MedicalListBottomActionBar.onUploadConfirmed` 的职责边界。
 */
export class MedicalDocumentUploadStartBridge {
  private handler?: MedicalDocumentUploadStartHandler;

  bind(handler: MedicalDocumentUploadStartHandler): void {
    this.handler = handler;
  }

  unbind(handler: MedicalDocumentUploadStartHandler): void {
    if (this.handler === handler) {
      this.handler = undefined;
    }
  }

  start(files: MedicalUploadLocalFile[], kind: MedicalDocumentKind): boolean {
    if (!this.handler) {
      return false;
    }
    this.handler(files.slice(), kind);
    return true;
  }
}

export const medicalDocumentUploadStartBridge: MedicalDocumentUploadStartBridge =
  new MedicalDocumentUploadStartBridge();
