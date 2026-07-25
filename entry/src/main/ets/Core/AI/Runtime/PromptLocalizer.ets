import { i18n } from '@kit.LocalizationKit';
import { AIPromptL10n } from './AIPromptL10n';
import { MedicalDocumentKind } from '../../../Projects/Features/MedicalDocumentUpload/Domain/MedicalDocumentKind';
import { MedicalExtractionPromptSource } from '../../../Projects/Features/MedicalDocumentUpload/Domain/MedicalExtractionInputSource';
import { MedicalExtractionRetryFeedback } from '../../../Projects/Features/MedicalDocumentUpload/Domain/MedicalExtractionRetryFeedback';
import {
  NutritionMealType,
  nutritionMealTypeLabel
} from '../../../Projects/Features/Nutrition/Domain/NutritionEnums';

/** 对齐 iOS `PromptLanguage`。 */
export enum PromptLanguage {
  ZH = 'zh',
  EN = 'en',
  JA = 'ja',
  KO = 'ko',
  FR = 'fr',
  DE = 'de',
  ES = 'es',
  PT = 'pt',
  AR = 'ar'
}

/**
 * 对齐 iOS `PromptLocalizer`：经 AIPromptL10n 读取与 iOS 完全一致的 `Prompts.strings`
 *（rawfile/ai/prompts/{zh-Hans|zh-Hant|en}/Prompts.strings）。
 */
export class PromptLocalizer {
  private readonly languageCode: string;
  private readonly l10n: AIPromptL10n;

  constructor(languageCode?: string) {
    this.languageCode = languageCode ?? '';
    this.l10n = new AIPromptL10n(languageCode);
  }

  get language(): PromptLanguage {
    let code = this.languageCode;
    if (code.length === 0) {
      try {
        code = i18n.System.getSystemLanguage() ?? 'en';
      } catch (_e) {
        code = 'en';
      }
    }
    const lower = code.toLowerCase().replace('_', '-');
    if (lower.indexOf('zh') === 0) {
      return PromptLanguage.ZH;
    }
    const lang = lower.split('-')[0];
    switch (lang) {
      case 'ja':
        return PromptLanguage.JA;
      case 'ko':
        return PromptLanguage.KO;
      case 'fr':
        return PromptLanguage.FR;
      case 'de':
        return PromptLanguage.DE;
      case 'es':
        return PromptLanguage.ES;
      case 'pt':
        return PromptLanguage.PT;
      case 'ar':
        return PromptLanguage.AR;
      default:
        return PromptLanguage.EN;
    }
  }

  chatSystemPrompt(): string {
    return this.l10n.prompt(
      'ai.prompt.chat.system',
      'You are Spark Health Assistant. Provide accurate, concise, actionable health guidance and respond in the user\'s language.\n{{CURRENT_DATE}}'
    );
  }

  /** 深度思考：在系统层追加一条简短指令。 */
  deepThinkingInstruction(): string {
    return this.l10n.prompt(
      'ai.prompt.chat.deep_thinking',
      'Think step by step: briefly outline your reasoning, then give a clear final answer.'
    );
  }

  medicalDocumentExtractionPrompt(ocrText: string): string {
    return this.l10n.promptFormat(
      'ai.prompt.medical_document.extraction.template',
      'You are a medical document extraction assistant. Extract a structured JSON object from OCR text.\n' +
        'Return JSON only and include keys:\n' +
        '{"title":"...","summary":"...","diagnosis":"...","occurredAt":"yyyy-MM-dd","rawType":"...","items":[]}\n\n' +
        'OCR text:\n%@',
      [ocrText]
    );
  }

  medicalDocumentTypeRecognitionPrompt(ocrText: string): string {
    return this.l10n.promptFormat(
      'ai.prompt.medical_document.type_recognition.template',
      'You are a medical document classifier.\n' +
        'Classify OCR text into one type only: case_document, health_exam_report, medical_report, prescription, medication_plan, medicine_box.\n' +
        'Return JSON only:\n' +
        '{"kind":"case_document|health_exam_report|medical_report|prescription|medication_plan|medicine_box","confidence":0.0-1.0,"reason":"..."}\n\n' +
        'OCR text:\n%@',
      [ocrText]
    );
  }

  medicalCaseExtractionPrompt(ocrText: string): string {
    return this.l10n.promptFormat(
      'ai.prompt.medical_case.extraction.template',
      'You are a medical case extraction assistant. Output a single JSON object only (no markdown).\n' +
        'OCR text:\n%@',
      [ocrText]
    );
  }

  healthExamExtractionPrompt(ocrText: string): string {
    return this.l10n.promptFormat(
      'ai.prompt.health_exam.extraction.template',
      this.medicalDocumentExtractionPrompt('%@'),
      [ocrText]
    );
  }

  medicalReportExtractionPrompt(ocrText: string): string {
    return this.l10n.promptFormat(
      'ai.prompt.medical_report.extraction.template',
      this.medicalDocumentExtractionPrompt('%@'),
      [ocrText]
    );
  }

  prescriptionExtractionPrompt(ocrText: string): string {
    return this.l10n.promptFormat(
      'ai.prompt.prescription.extraction.template',
      this.medicalDocumentExtractionPrompt('%@'),
      [ocrText]
    );
  }

  medicationExtractionPrompt(ocrText: string): string {
    return this.l10n.promptFormat(
      'ai.prompt.medication.extraction.template',
      this.medicalDocumentExtractionPrompt('%@'),
      [ocrText]
    );
  }

  medicineBoxExtractionPrompt(ocrText: string): string {
    return this.l10n.promptFormat(
      'ai.prompt.medicine_box.extraction.template',
      'You are a medication box extraction assistant. Extract an array of medicine box inventory items from OCR text.\n' +
        'Return JSON array only.\n\nOCR text:\n%@',
      [ocrText]
    );
  }

  nutritionFoodDescriptionPrompt(mealType: NutritionMealType): string {
    const mealLabel = nutritionMealTypeLabel(mealType, this.language === PromptLanguage.ZH);
    return this.l10n.promptFormat(
      'ai.prompt.nutrition.food_description.template',
      'You are a food photo description assistant. Describe visible foods, portions, cooking methods, and ingredients in natural language.\n' +
        'Respond in the user\'s language. Do not output JSON.\nMeal context: %@',
      [mealLabel]
    );
  }

  nutritionIntakeExtractionPrompt(mealType: NutritionMealType, sourceText: string): string {
    return this.l10n.promptFormat(
      'ai.prompt.nutrition.intake_extraction.template',
      'You are a nutrition intake extraction assistant. Return one JSON object only (camelCase keys, no markdown).\n' +
        'Default mealType: %@\n\nInput:\n%@',
      [mealType, sourceText]
    );
  }

  nutritionExtractionRetryCorrectionPrompt(errorSummary: string, outputPreview: string): string {
    const notAvailable = this.nutritionExtractionNotAvailableLabel();
    const template = this.l10n.prompt(
      'ai.prompt.nutrition.extraction.retry_correction.template',
      '[Retry correction]\nThe previous nutrition extraction JSON failed to decode.\n- Error: %@\n- Previous output preview: %@\n\n' +
        'Return pure JSON only with camelCase keys. Do not use markdown or explanatory text.'
    );
    return AIPromptL10n.format(template, [
      errorSummary.length === 0 ? notAvailable : errorSummary,
      outputPreview.length === 0 ? notAvailable : outputPreview
    ]);
  }

  nutritionExtractionNotAvailableLabel(): string {
    return this.l10n.prompt('ai.prompt.nutrition.extraction.not_available', 'N/A');
  }

  medicalExtractionRetryCorrectionPrompt(
    kind: MedicalDocumentKind,
    feedback: MedicalExtractionRetryFeedback,
    source?: MedicalExtractionPromptSource
  ): string {
    const resolvedSource = source ?? MedicalExtractionPromptSource.OCR_TEXT;
    if (resolvedSource === MedicalExtractionPromptSource.VISION_IMAGE) {
      return this.medicalExtractionVisionRetryCorrectionPrompt(kind, feedback);
    }
    return this.medicalExtractionOCRRetryCorrectionPrompt(kind, feedback);
  }

  private medicalExtractionOCRRetryCorrectionPrompt(
    kind: MedicalDocumentKind,
    feedback: MedicalExtractionRetryFeedback
  ): string {
    const kindLabel = this.localizedMedicalDocumentKindLabel(kind);
    const fieldPath = feedback.fieldPath ?? this.notAvailableLabel();
    const expectedType = feedback.expectedType ?? this.notAvailableLabel();
    const actualType = feedback.actualType ?? this.notAvailableLabel();
    const rawMessage = feedback.rawMessage.length === 0 ? this.notAvailableLabel() : feedback.rawMessage;
    const suggestion = feedback.suggestion ?? this.notAvailableLabel();
    const template = this.l10n.prompt(
      'ai.prompt.medical_extraction.retry_correction.template',
      '[Retry correction]\nThe previous structured extraction failed:\n' +
        '- Document type: %@\n- Invalid field: %@\n- Expected type: %@\n- Previous actual type: %@\n' +
        '- Error: %@\n- Fix suggestion: %@\n\nPlease return pure JSON that follows the original schema.'
    );
    const body = AIPromptL10n.format(template, [
      kindLabel, fieldPath, expectedType, actualType, rawMessage, suggestion
    ]);
    return this.truncatedCorrectionBlock(body, 2500);
  }

  private medicalExtractionVisionRetryCorrectionPrompt(
    kind: MedicalDocumentKind,
    feedback: MedicalExtractionRetryFeedback
  ): string {
    const kindLabel = this.localizedMedicalDocumentKindLabel(kind);
    const fieldPath = feedback.fieldPath ?? this.notAvailableLabel();
    const expectedType = feedback.expectedType ?? this.notAvailableLabel();
    const actualType = feedback.actualType ?? this.notAvailableLabel();
    const rawMessage = feedback.rawMessage.length === 0 ? this.notAvailableLabel() : feedback.rawMessage;
    const suggestion = feedback.suggestion ?? this.notAvailableLabel();

    let template = this.l10n.promptIfExists('ai.prompt.medical_extraction.vision.retry_correction.template');
    if (template === undefined) {
      const ocrTemplate = this.l10n.prompt(
        'ai.prompt.medical_extraction.retry_correction.template',
        '[Retry correction]\nThe previous structured extraction failed:\n' +
          '- Document type: %@\n- Invalid field: %@\n- Expected type: %@\n- Previous actual type: %@\n' +
          '- Error: %@\n- Fix suggestion: %@\n\nPlease return pure JSON that follows the original schema.'
      );
      template = this.adaptOCRRetryTemplateToVision(ocrTemplate);
    }
    const body = AIPromptL10n.format(template, [
      kindLabel, fieldPath, expectedType, actualType, rawMessage, suggestion
    ]);
    return this.truncatedCorrectionBlock(body, 2500);
  }

  medicalCaseVisionExtractionPrompt(): string {
    return this.visionExtractionPrompt(
      'ai.prompt.medical_case.vision.extraction.template',
      'ai.prompt.medical_case.extraction.template',
      'You are a medical case extraction assistant. Output a single JSON object only (no markdown).\nOCR text:\n%@'
    );
  }

  healthExamVisionExtractionPrompt(): string {
    return this.visionExtractionPrompt(
      'ai.prompt.health_exam.vision.extraction.template',
      'ai.prompt.health_exam.extraction.template',
      this.medicalDocumentExtractionPrompt('%@')
    );
  }

  medicalReportVisionExtractionPrompt(): string {
    return this.visionExtractionPrompt(
      'ai.prompt.medical_report.vision.extraction.template',
      'ai.prompt.medical_report.extraction.template',
      this.medicalDocumentExtractionPrompt('%@')
    );
  }

  prescriptionVisionExtractionPrompt(): string {
    return this.visionExtractionPrompt(
      'ai.prompt.prescription.vision.extraction.template',
      'ai.prompt.prescription.extraction.template',
      this.medicalDocumentExtractionPrompt('%@')
    );
  }

  medicationVisionExtractionPrompt(): string {
    return this.visionExtractionPrompt(
      'ai.prompt.medication.vision.extraction.template',
      'ai.prompt.medication.extraction.template',
      this.medicalDocumentExtractionPrompt('%@')
    );
  }

  medicineBoxVisionExtractionPrompt(): string {
    return this.visionExtractionPrompt(
      'ai.prompt.medicine_box.vision.extraction.template',
      'ai.prompt.medicine_box.extraction.template',
      'You are a medication box extraction assistant. Extract an array of medicine box inventory items from OCR text.\nReturn JSON array only.\nOCR text:\n%@'
    );
  }

  medicalDocumentVisionExtractionPrompt(): string {
    return this.visionExtractionPrompt(
      'ai.prompt.medical_document.vision.extraction.template',
      'ai.prompt.medical_document.extraction.template',
      'You are a medical document extraction assistant. Extract a structured JSON object from OCR text.\n' +
        'Return JSON only and include keys:\n' +
        '{"title":"...","summary":"...","diagnosis":"...","occurredAt":"yyyy-MM-dd","rawType":"...","items":[]}\n\n' +
        'OCR text:\n%@'
    );
  }

  private visionExtractionPrompt(dedicatedKey: string, ocrKey: string, englishOCRFallback: string): string {
    const dedicated = this.l10n.promptIfExists(dedicatedKey);
    if (dedicated !== undefined) {
      return dedicated;
    }
    const ocrTemplate = this.l10n.prompt(ocrKey, englishOCRFallback);
    return this.adaptOCRTemplateToVisionPrompt(ocrTemplate);
  }

  private adaptOCRTemplateToVisionPrompt(template: string): string {
    let text = this.stripOCRInputSection(template);
    text = this.replaceOCRSourcePhrases(text);
    return `${this.visionExtractionHeader()}\n\n${text.trim()}`;
  }

  private adaptOCRRetryTemplateToVision(template: string): string {
    if (this.language === PromptLanguage.ZH) {
      return template
        .replace(/原始 OCR 事实/g, '图片中可见事实')
        .replace(/OCR 事实/g, '图片中可见事实')
        .replace(/OCR事实/g, '图片中可见事实');
    }
    return template
      .replace(/OCR facts/g, 'visible facts in the image(s)')
      .replace(/without changing OCR facts/g, 'without changing visible facts in the image(s)');
  }

  private stripOCRInputSection(template: string): string {
    let text = template;
    const tailPatterns: string[] = [
      '\n\nOCR文本：\n%@',
      '\nOCR文本：\n%@',
      '\n\nOCR text:\n%@',
      '\nOCR text:\n%@',
      'OCR文本：\n%@',
      'OCR text:\n%@',
      '\nOCR文本：\n',
      '\nOCR text:\n'
    ];
    for (let i = 0; i < tailPatterns.length; i++) {
      text = text.split(tailPatterns[i]).join('');
    }
    if (text.endsWith('\n%@')) {
      text = text.substring(0, text.length - 3);
    }
    return text;
  }

  private replaceOCRSourcePhrases(text: string): string {
    if (this.language === PromptLanguage.ZH) {
      return text
        .split('纸质病历OCR文本').join('纸质病历图片')
        .split('体检报告/OCR文本').join('体检报告图片')
        .split('中文OCR文本').join('中文医疗单据图片')
        .split('处方 / 医嘱 / OCR 文本').join('处方/医嘱图片')
        .split('处方/医嘱/药品说明/OCR文本').join('处方/医嘱/药品说明图片')
        .split('药盒、药瓶、泡罩、标签、说明书 OCR 文本').join('药盒、药瓶、泡罩、标签、说明书图片')
        .split('从 OCR 文本中').join('从图片中可见内容')
        .split('OCR 文本').join('图片中可见内容')
        .split('OCR文本').join('图片中可见内容');
    }
    return text
      .split('from OCR text').join('from visible image content')
      .split('OCR text').join('visible image content');
  }

  private visionExtractionHeader(): string {
    if (this.language === PromptLanguage.ZH) {
      return '【图片视觉抽取】\n' +
        '请根据提供的医疗单据图片中可见内容抽取结构化信息，不要编造图片中看不到的内容。\n' +
        '请保留表格行列对应关系：项目名、结果值、单位、参考范围必须来自同一行或明确关联区域。\n' +
        '若提供多张图片，请按顺序视为同一份文档的续页并合并抽取。';
    }
    return '[Vision extraction]\n' +
      'Extract structured data only from visible content in the provided medical document image(s). Do not invent hidden facts.\n' +
      'Preserve table row/column alignment for names, values, units, and reference ranges.\n' +
      'If multiple images are provided, treat them in order as pages of the same document.';
  }

  medicalExtractionRetrySuggestion(field: string): string {
    const key = `ai.prompt.medical_extraction.retry.suggestion.${field}`;
    return this.l10n.prompt(key, this.fallbackRetrySuggestion(field));
  }

  medicalExtractionRetrySuggestionTypeMismatch(expected: string, actual: string): string {
    return this.l10n.promptFormat(
      'ai.prompt.medical_extraction.retry.suggestion.type_mismatch',
      'Expected type %@ but got %@. Return schema-compatible JSON types.',
      [expected, actual]
    );
  }

  private localizedMedicalDocumentKindLabel(kind: MedicalDocumentKind): string {
    switch (kind) {
      case MedicalDocumentKind.AUTO:
        return this.l10n.prompt('ai.prompt.medical_extraction.retry.kind.auto', 'auto');
      case MedicalDocumentKind.CASE_DOCUMENT:
        return this.l10n.prompt('ai.prompt.medical_extraction.retry.kind.case_document', 'case document');
      case MedicalDocumentKind.HEALTH_EXAM_REPORT:
        return this.l10n.prompt('ai.prompt.medical_extraction.retry.kind.health_exam_report', 'health exam report');
      case MedicalDocumentKind.MEDICAL_REPORT:
        return this.l10n.prompt('ai.prompt.medical_extraction.retry.kind.medical_report', 'medical report');
      case MedicalDocumentKind.PRESCRIPTION:
        return this.l10n.prompt('ai.prompt.medical_extraction.retry.kind.prescription', 'prescription');
      case MedicalDocumentKind.MEDICATION_PLAN:
        return this.l10n.prompt('ai.prompt.medical_extraction.retry.kind.medication_plan', 'medication plan');
      case MedicalDocumentKind.MEDICINE_BOX:
        return this.l10n.prompt('ai.prompt.medical_extraction.retry.kind.medicine_box', 'medicine box');
      default:
        return kind;
    }
  }

  private notAvailableLabel(): string {
    return this.l10n.prompt('ai.prompt.medical_extraction.retry.not_available', 'N/A');
  }

  private fallbackRetrySuggestion(field: string): string {
    switch (field) {
      case 'extra':
        return '`extra` must be a JSON object. Use `{}` when unknown. Do not use `""`.';
      case 'items':
        return '`items` must be an array. Use `[]` when no item is available.';
      case 'medicines':
        return '`medicines` must be an array of medicine objects.';
      case 'indicators':
        return '`indicators` must be an array of exam indicator objects.';
      case 'sortOrder':
        return 'Use integer number for `sortOrder`, not string.';
      case 'date':
        return 'Use `yyyy-MM-dd` when visible; otherwise use the schema-compatible empty value.';
      case 'json_shape':
        return 'Return pure JSON only. Do not wrap the payload in Markdown or prose.';
      case 'generic_type':
        return 'Match the schema field types exactly.';
      default:
        return 'Return JSON that matches the original schema and field types.';
    }
  }

  private truncatedCorrectionBlock(text: string, limit: number): string {
    const trimmed = text.trim();
    if (trimmed.length <= limit) {
      return trimmed;
    }
    return trimmed.substring(0, limit);
  }

  taskExtractionPrompt(userInput: string): string {
    return this.l10n.promptFormat(
      'ai.prompt.task.extraction.template',
      'You are a task extraction assistant.\nReturn JSON only with keys:\n' +
        '{"task_type":"medical|exercise|diet|unknown","target_metric":"...","time_info":{},"action":"...","intensity_or_value":"...","confidence":0.0}\n' +
        'Input:\n%@',
      [userInput]
    );
  }

  contextSummaryHeader(recordCount: number): string {
    return this.l10n.promptFormat(
      'ai.prompt.context.header',
      'Recent medical context for member (latest %d records):',
      [recordCount]
    );
  }

  contextLine(dateText: string, title: string, summary: string): string {
    return this.l10n.promptFormat(
      'ai.prompt.context.line',
      '- [%@] %@: %@',
      [dateText, title, summary]
    );
  }

  fallbackAssistantText(): string {
    return this.l10n.prompt(
      'ai.prompt.fallback.assistant',
      'I can\'t provide a valid response right now. Please try again shortly.'
    );
  }

  newThreadTitle(): string {
    return this.l10n.prompt('ai.prompt.thread.new_title', 'New Chat');
  }

  consentBlockedHint(reason?: string): string {
    const defaultReason = this.l10n.prompt(
      'ai.prompt.consent.blocked.default_reason',
      'Sensitive information was not forwarded to the model.'
    );
    return this.l10n.promptFormat(
      'ai.prompt.consent.blocked.template',
      '[ConsentGate] %@',
      [reason && reason.length > 0 ? reason : defaultReason]
    );
  }

  /** 鸿蒙专用：对齐 ChatOrchestrator 工具锁提示（iOS 内联于编排层）。 */
  toolLockedNotice(): string {
    if (this.language === PromptLanguage.ZH) {
      return '本轮对话内已禁止继续调用工具。请基于现有信息直接完成回复，不要再发起工具调用。';
    }
    return 'Tool calling is locked for this turn. Complete the reply with existing information and do not invoke more tools.';
  }

  /** 鸿蒙专用：空模型输出提示。 */
  emptyOutputUserMessage(): string {
    if (this.language === PromptLanguage.ZH) {
      return '模型未返回可用内容，请重试。';
    }
    return 'The model returned no usable content. Please try again.';
  }

  /** 对齐 iOS ToolPrompts 读取入口，供 ToolHub schema/展示文案使用。 */
  toolText(key: string, fallback?: string): string {
    return this.l10n.tool(key, fallback);
  }
}
