/** 单文件 OCR 结果，供合并与断点恢复。 */
export class MedicalFileOCRResult {
  localId: string = '';
  displayName: string = '';
  engine: string = '';
  text: string = '';
  confidence?: number;
  rawText: string = '';
}

/** OCR 用例输出：合并文本 + 单文件结果 + 纠错文本。 */
export class MedicalDocumentOCRResult {
  mergedOCRText: string = '';
  fileResults: MedicalFileOCRResult[] = [];
  selectedEngine: string = '';
  correctedText: string = '';
  rawMergedOCRText: string = '';
}
