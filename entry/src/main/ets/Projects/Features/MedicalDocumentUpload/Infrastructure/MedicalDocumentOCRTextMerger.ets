import { MedicalFileOCRResult } from '../Domain/MedicalDocumentOCRResult';

/**
 * 按上传顺序合并 OCR 文本，保留文件边界，供类型识别 / Prompt 使用。
 * 对齐 iOS DefaultTypedMedicalDocumentExtractor.buildMergedOCRText。
 */
export class MedicalDocumentOCRTextMerger {
  static merge(results: MedicalFileOCRResult[]): string {
    const chunks: string[] = [];
    for (let i = 0; i < results.length; i++) {
      const item = results[i];
      const header = `=== File ${i + 1}: ${item.displayName} ===`;
      const body = MedicalDocumentOCRTextMerger.normalizeBlankLines(item.text);
      chunks.push(`${header}\n${body}`);
    }
    return chunks.join('\n\n');
  }

  static normalizeBlankLines(text: string): string {
    const lines = text.replace(/\r\n/g, '\n').split('\n');
    const out: string[] = [];
    let blankRun = 0;
    for (let i = 0; i < lines.length; i++) {
      const line = lines[i].replace(/[ \t]+$/g, '');
      if (line.trim().length === 0) {
        blankRun += 1;
        if (blankRun <= 1) {
          out.push('');
        }
        continue;
      }
      blankRun = 0;
      out.push(line);
    }
    while (out.length > 0 && out[out.length - 1].length === 0) {
      out.pop();
    }
    return out.join('\n');
  }
}
