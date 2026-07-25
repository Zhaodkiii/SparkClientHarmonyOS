/**
 * 对齐 iOS `MedicalExtractionPromptSource`（Domain/MedicalExtractionInputSource.swift）：
 * 抽取输入来源是 OCR 文本还是原始图片（走 Vision 抽取模板）。
 */
export enum MedicalExtractionPromptSource {
  OCR_TEXT = 'ocrText',
  VISION_IMAGE = 'visionImage'
}
