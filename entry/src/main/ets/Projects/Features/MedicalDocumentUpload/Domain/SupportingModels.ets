/**
 * 上传模块支撑模型入口（re-export + L10n）。
 * Kind / FlowStep / Progress 已按后端契约落在 Domain；文件模型继续用 MedicalAttachmentInput。
 */
export {
  MedicalDocumentKind,
  medicalDocumentKindAllCases,
  medicalDocumentKindPickerLabel,
  medicalDocumentKindSymbol
} from './MedicalDocumentKind';

export {
  MedicalDocumentUploadFlowStep,
  MedicalDocumentUploadFlowStepKind,
  MedicalDocumentUploadStepOutcome
} from './MedicalDocumentUploadFlowStep';

export {
  MedicalDocumentUploadProgress,
  MedicalDocumentUploadProgressStep,
  medicalUploadPipelineOrder,
  medicalUploadPipelineSteps
} from './MedicalDocumentUploadProgress';

export {
  MedicalDocumentUploadEntry,
  MedicalDocumentUploadEntrySource,
  MedicalDocumentUploadStage,
  MedicalDocumentUploadCapabilities,
  MedicalUploadLocalFile,
  MedicalDocumentOCRInput,
  UploadedMedicalDocumentFile
} from './MedicalDocumentUploadModels';

export {
  MedicalDocumentTypeResolution,
  MedicalDocumentTypedExtractionOutput,
  MedicalDocumentTypedEnvelope,
  MedicalPreSubmitValidationIssue
} from './MedicalDocumentTypedModels';

export {
  MedicalDocumentTypeResolutionSource,
  MedicalDocumentTypeResolutionFactory,
  medicalDocumentTypeSourceLabel
} from './MedicalDocumentTypeResolverProtocol';

export {
  MedicalDocumentOCRResult,
  MedicalFileOCRResult
} from './MedicalDocumentOCRResult';

export {
  MedicalDocumentOCRRequest
} from './MedicalDocumentOCRModels';

/**
 * 对应参考包 `L10n.text(key)`。
 * 优先返回中文文案，后续可换成 resourceManager 按 name 查表。
 */
export class MedicalUploadL10n {
  static text(key: string, fallback?: string): string {
    switch (key) {
      case 'medical.upload.title':
        return 'AI 上传报告';
      case 'medical.upload.result.case.nav_title':
        return '病例';
      case 'medical.upload.result.health_exam.nav_title':
        return '体检报告';
      case 'medical.upload.result.medical_report.nav_title':
        return '检查报告';
      case 'common.prescription':
        return '处方';
      case 'common.medicationPlan':
        return '服药计划';
      case 'home.medical.list.medicine_box.title':
        return '药品';
      case 'medical.upload.current_member':
        return '当前成员';
      case 'medical.upload.member.not_selected':
        return '请选择成员';
      case 'medical.upload.picking.summary.title':
        return '已选择文件';
      case 'medical.upload.picking.report_type':
        return '报告类型';
      case 'medical.upload.picking.add_files':
        return '继续添加文件';
      case 'medical.upload.picking.clear':
        return '清空';
      case 'medical.upload.start':
        return '开始识别';
      case 'medical.upload.picking.tip.auto_type':
        return '默认自动识别报告类型，也可手动指定。';
      case 'medical.upload.picking.tip.formats':
        return '支持图片和 PDF，最多选择 9 个文件。';
      case 'medical.upload.processing.title':
        return '正在识别…';
      case 'medical.upload.status.processing':
        return '处理中';
      case 'medical.upload.status.failed':
        return '识别失败';
      case 'medical.upload.error.no_member':
        return '请先选择成员';
      case 'medical.upload.error.no_files':
        return '请先上传报告文件';
      case 'medical.upload.error.confirm':
        return '知道了';
      case 'common.cancel':
        return '取消';
      case 'common.done':
        return '完成';
      case 'common.error':
        return '错误';
      case 'medical.upload.ocr.pending':
        return '文件已上传，识别服务待接入';
      case 'medical.upload.ocr.failed':
        return 'OCR 识别失败，请重试或更换文件';
      case 'medical.upload.ocr.warming':
        return '系统 OCR 正在启动…';
      case 'medical.upload.ocr.recognizing':
        return '正在识别文字…';
      case 'medical.upload.ocr.unavailable':
        return '系统 OCR 暂不可用，请稍后重试';
      case 'medical.upload.ocr.init_timeout':
        return '系统 OCR 初始化超时，请稍后重试';
      case 'medical.upload.ocr.image_read_failed':
        return '无法读取图片，请重新选择原图或授权相册访问';
      case 'medical.upload.ocr.image_format_failed':
        return '图片格式暂不支持或文件损坏，请换一张原图';
      case 'medical.upload.ocr.engine_unavailable':
        return '系统 OCR 暂不可用，请稍后重试';
      case 'medical.upload.ocr.empty_output':
        return '未识别到可用文字，请换清晰图片或手动录入';
      case 'medical.upload.extract.pending':
        return '类型已识别，结构化抽取待接入';
      case 'medical.upload.action.retry':
        return '重试上传';
      case 'medical.upload.action.retry_save':
        return '重试保存';
      case 'medical.upload.action.return_picking':
        return '返回文件选择';
      case 'medical.upload.action.reselect':
        return '重新选择';
      case 'medical.upload.action.cancel':
        return '取消';
      case 'medical.upload.processing.preparing':
        return '正在准备上传识别流程';
      case 'medical.upload.result.pending':
        return '识别结果页面待接入';
      case 'medical.upload.result.member.title':
        return '保存成员';
      case 'medical.upload.result.member.subtitle':
        return '确认保存到该成员';
      case 'medical.upload.result.medical_report.member.subtitle':
        return '确认保存到该成员的检查报告';
      case 'medical.upload.result.medical_report.stats.title':
        return '检查报告统计';
      case 'medical.upload.result.member.switch':
        return '切换';
      case 'medical.upload.result.member.picker_title':
        return '选择保存成员';
      case 'medical.upload.result.member.current':
        return '当前';
      case 'medical.upload.result.medicine_box.member.title':
        return '确认成员';
      case 'medical.upload.result.medicine_box.member.subtitle':
        return '保存后会加入该成员的药箱';
      case 'medical.upload.result.medicine_box.total_count':
        return '药品数量';
      case 'medical.upload.result.medicine_box.section.title':
        return '药箱药品';
      case 'medical.upload.result.medicine_box.section.subtitle':
        return '可逐条编辑识别结果后保存';
      case 'medical.upload.result.medicine_box.empty':
        return '暂无药品';
      case 'medical.upload.presubmit.value.not_filled':
        return '未填写';
      default:
        return fallback ?? key;
    }
  }

  static format(key: string, ...args: Array<string | number>): string {
    if (key === 'medical.upload.picking.image_count') {
      return `${args[0]} 张图片`;
    }
    if (key === 'medical.upload.picking.document_count') {
      return `${args[0]} 个 PDF`;
    }
    return MedicalUploadL10n.text(key);
  }
}
