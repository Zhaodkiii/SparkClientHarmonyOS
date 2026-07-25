import { FileTransferError } from '../../../../Core/FileStorage/FileStorageModels';
import { OCRError } from '../../../Core/OCR/OCRModels';
import {
  MedicalDocumentStructuredExtractionError
} from './MedicalDocumentStructuredExtractionError';

/** 上传业务错误阶段（工单 4.5）。 */
export type MedicalDocumentUploadErrorStage =
  'file_pick' | 'file_read' | 'sts' | 'oss_upload' | 'file_register' | 'business_bind' |
  'ocr_pending' | 'ocr_failed' | 'type_pending' | 'extract_pending' | 'extract_failed';

export class MedicalDocumentUploadStageError {
  stage: MedicalDocumentUploadErrorStage = 'oss_upload';
  code: string = 'medical.upload.failed';
  message: string = '';
  recoverable: boolean = true;
  /** OCR 失败阶段，便于日志与 UI 归因。 */
  ocrPhase: string = '';
  /** 抽取字段路径（若有）。 */
  fieldPath: string = '';
}

/**
 * 将公共 FileTransfer / 本地校验 / OCR 错误映射为 AI 上传报告业务阶段错误。
 * 不吞掉原错误细节；OCR 优先使用 OCRError.userMessage()，不展示完整 URI。
 */
export class MedicalDocumentUploadErrorNormalizer {
  static normalize(error: Object | Error, fallbackMessage: string = ''): MedicalDocumentUploadStageError {
    const result = new MedicalDocumentUploadStageError();

    if (error instanceof Error && error.message === 'OCR_PENDING') {
      result.stage = 'ocr_pending';
      result.code = 'medical.upload.ocr.pending';
      result.message = fallbackMessage.length > 0 ? fallbackMessage : '文件已上传，识别服务待接入';
      result.recoverable = true;
      return result;
    }
    if (error instanceof Error && error.message === 'EXTRACT_PENDING') {
      result.stage = 'extract_pending';
      result.code = 'medical.upload.extract.pending';
      result.message = fallbackMessage.length > 0 ? fallbackMessage : '类型已识别，结构化抽取待接入';
      result.recoverable = true;
      return result;
    }

    if (error instanceof MedicalDocumentStructuredExtractionError) {
      result.stage = error.code === 'cancelled' ? 'extract_pending' : 'extract_failed';
      result.code = `medical.upload.extract.${error.code}`;
      result.message = error.message.length > 0 ? error.message :
        (fallbackMessage.length > 0 ? fallbackMessage : '结构化抽取失败');
      result.recoverable = error.retryable;
      result.fieldPath = error.fieldPath;
      return result;
    }

    if (error instanceof OCRError) {
      result.stage = 'ocr_failed';
      result.code = 'medical.upload.ocr.failed';
      result.message = error.userMessage();
      result.ocrPhase = error.phase;
      result.recoverable = true;
      return result;
    }

    if (error instanceof Error &&
      (error.name === 'OCRError' ||
        error.message.indexOf('emptyOutput') >= 0 ||
        error.message.indexOf('invalidDocumentURL') >= 0 ||
        error.message.indexOf('invalidImage') >= 0 ||
        error.message.indexOf('engineUnavailable') >= 0 ||
        error.message.indexOf('no_ocr_engine_output') >= 0)) {
      result.stage = 'ocr_failed';
      result.code = 'medical.upload.ocr.failed';
      result.message = MedicalDocumentUploadErrorNormalizer.mapOcrDetailMessage(
        error.message,
        fallbackMessage
      );
      result.recoverable = true;
      return result;
    }

    if (error instanceof FileTransferError) {
      result.message = error.safeMessage.length > 0 ? error.safeMessage :
        (fallbackMessage.length > 0 ? fallbackMessage : error.message);
      switch (error.code) {
        case 'sourceInvalid':
        case 'localIoFailed':
          result.stage = 'file_read';
          result.code = 'medical.upload.file_read_failed';
          break;
        case 'credentialsExpired':
        case 'unauthorized':
          result.stage = 'sts';
          result.code = 'medical.upload.sts_failed';
          break;
        case 'registrationPending':
        case 'unknownRegistrationOutcome':
          result.stage = 'file_register';
          result.code = 'medical.upload.file_register_pending';
          result.message = fallbackMessage.length > 0 ? fallbackMessage :
            '文件已上传到 OSS，但文件中心登记未完成，可重试恢复。';
          result.recoverable = true;
          break;
        case 'ossRejected':
        case 'ossAccessDenied':
        case 'ossRequestInvalid':
        case 'ossRequestValidationUnknown':
        case 'ossConfigurationInvalid':
        case 'ossConflict':
        case 'ossTransientFailure':
        case 'ossClockSkew':
        case 'networkUnavailable':
          result.stage = 'oss_upload';
          result.code = `medical.upload.${error.code}`;
          break;
        default:
          result.stage = 'oss_upload';
          result.code = `medical.upload.${error.code}`;
          break;
      }
      result.recoverable = error.userCanRetry;
      return result;
    }

    if (error instanceof Error) {
      if (error.message === 'accountRequired') {
        result.stage = 'sts';
        result.code = 'medical.upload.account_required';
        result.message = '请先登录后再上传';
        result.recoverable = false;
        return result;
      }
      if (error.message === 'attachmentSourceInvalid') {
        result.stage = 'file_read';
        result.code = 'medical.upload.source_invalid';
        result.message = '文件无效，请重新选择';
        result.recoverable = true;
        return result;
      }
      if (error.message === 'file_pick_cancelled') {
        result.stage = 'file_pick';
        result.code = 'medical.upload.file_pick_cancelled';
        result.message = '已取消选择文件';
        result.recoverable = true;
        return result;
      }
      result.message = error.message.length > 0 ? error.message :
        (fallbackMessage.length > 0 ? fallbackMessage : '上传失败，请稍后重试');
    } else if (fallbackMessage.length > 0) {
      result.message = fallbackMessage;
    } else {
      result.message = '上传失败，请稍后重试';
    }
    return result;
  }

  private static mapOcrDetailMessage(raw: string, fallbackMessage: string): string {
    // 优先级：init 超时 / cooldown > 读图 > 识别 > 无文字。
    if (raw.indexOf('timeout') >= 0 || raw.indexOf('timed out') >= 0 ||
      raw.indexOf('init_timeout') >= 0 || raw.indexOf('vision_init') >= 0 ||
      raw.indexOf('builtin_ocr_cooldown') >= 0) {
      if (raw.indexOf('cooldown') >= 0 && raw.indexOf('timeout') < 0 &&
        raw.indexOf('timed out') < 0 && raw.indexOf('init_timeout') < 0 &&
        raw.indexOf('vision_init') < 0) {
        return '系统 OCR 暂不可用，请稍后重试';
      }
      return '系统 OCR 初始化超时，请稍后重试';
    }
    if (raw.indexOf('image_source') >= 0 || raw.indexOf('open_file') >= 0 ||
      raw.indexOf('uri_to_pixel') >= 0 || raw.indexOf('empty_uri') >= 0) {
      return '无法读取图片，请重新选择原图或授权相册访问';
    }
    if (raw.indexOf('pixel_map') >= 0 || raw.indexOf('create_pixel_map') >= 0) {
      return '图片格式暂不支持或文件损坏，请换一张原图';
    }
    if (raw.indexOf('init_failed') >= 0) {
      return '系统 OCR 初始化失败，请重试';
    }
    if (raw.indexOf('vision_recognize') >= 0 || raw.indexOf('recognize_failed') >= 0) {
      return '系统 OCR 识别失败，请换清晰图片后重试';
    }
    if (raw.indexOf('emptyOutput') >= 0 || raw.indexOf('no_ocr_engine_output') >= 0) {
      return '未识别到可用文字，请换清晰图片或手动录入';
    }
    if (fallbackMessage.length > 0 && fallbackMessage.indexOf('/') < 0 &&
      fallbackMessage.indexOf('file://') < 0 && fallbackMessage.indexOf('content://') < 0) {
      return fallbackMessage;
    }
    return 'OCR 识别失败，请重试或更换文件';
  }
}
