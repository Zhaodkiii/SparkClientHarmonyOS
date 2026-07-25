import { MedicalDocumentKind } from '../Domain/MedicalDocumentKind';
import {
  MedicalAttachmentInput
} from '../../Home/Presentation/MedicalLists/MedicalDocumentAttachmentUploader';
import {
  MedicalDocumentUploadEntry,
  MedicalDocumentUploadEntrySource
} from '../Domain/MedicalDocumentUploadModels';

/**
 * 入口参数归一化（工单 T3）。
 * 首页 / 相机 / 聊天 / 外部 PDF 统一产出 MedicalDocumentUploadEntry。
 */
export class MedicalDocumentUploadEntryFactory {
  static home(
    memberId: number,
    memberName: string = '',
    preferredKind?: MedicalDocumentKind
  ): MedicalDocumentUploadEntry {
    const entry = new MedicalDocumentUploadEntry();
    entry.source = MedicalDocumentUploadEntrySource.HOME;
    entry.memberId = memberId;
    entry.memberName = memberName;
    entry.preferredKind = preferredKind;
    return entry;
  }

  static secondCamera(
    memberId: number,
    capturedFiles: MedicalAttachmentInput[],
    memberName: string = ''
  ): MedicalDocumentUploadEntry {
    const entry = new MedicalDocumentUploadEntry();
    entry.source = MedicalDocumentUploadEntrySource.SECOND_CAMERA;
    entry.memberId = memberId;
    entry.memberName = memberName;
    entry.initialFiles = capturedFiles.slice();
    return entry;
  }

  static chat(
    memberId: number,
    memberName: string = '',
    initialFiles: MedicalAttachmentInput[] = []
  ): MedicalDocumentUploadEntry {
    const entry = new MedicalDocumentUploadEntry();
    entry.source = MedicalDocumentUploadEntrySource.CHAT;
    entry.memberId = memberId;
    entry.memberName = memberName;
    entry.initialFiles = initialFiles.slice();
    return entry;
  }

  static externalPdf(
    memberId: number,
    files: MedicalAttachmentInput[],
    memberName: string = ''
  ): MedicalDocumentUploadEntry {
    const entry = new MedicalDocumentUploadEntry();
    entry.source = MedicalDocumentUploadEntrySource.EXTERNAL_PDF;
    entry.memberId = memberId;
    entry.memberName = memberName;
    entry.initialFiles = files.slice();
    return entry;
  }
}
