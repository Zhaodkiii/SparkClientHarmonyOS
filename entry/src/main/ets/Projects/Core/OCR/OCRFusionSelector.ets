import { OCRRecognition, OCRTextOutput } from './OCRModels';
import { MedicalTermsCorrector } from './MedicalTermsCorrector';

/**
 * 多引擎结果融合，对齐 iOS OCRFusionSelector。
 * 评分：置信度 40 + 有效长度 30 + 数字密度 10 + 医学词 20。
 */
export class OCRFusionSelector {
  private static readonly MEDICAL_HINTS: string[] = [
    'MRI', 'CT', '血常规', 'mmol/L', 'T1WI', 'T2WI', 'DWI', 'AFP', 'CEA'
  ];

  static selectBest(
    outputs: OCRTextOutput[],
    corrector?: MedicalTermsCorrector,
    applyCorrection: boolean = true
  ): OCRRecognition {
    const normalized: OCRTextOutput[] = [];
    for (let i = 0; i < outputs.length; i++) {
      const source = outputs[i];
      const item = new OCRTextOutput();
      item.engine = source.engine;
      item.confidence = source.confidence;
      item.elapsedMs = source.elapsedMs;
      if (applyCorrection && corrector !== undefined) {
        item.text = corrector.correct(source.text);
      } else {
        item.text = source.text;
      }
      normalized.push(item);
    }

    let best = normalized.length > 0 ? normalized[0] : new OCRTextOutput();
    if (normalized.length === 0) {
      best.engine = 'none';
      best.text = '';
    } else {
      let bestScore = OCRFusionSelector.score(best);
      for (let i = 1; i < normalized.length; i++) {
        const candidate = normalized[i];
        const candidateScore = OCRFusionSelector.score(candidate);
        if (candidateScore > bestScore) {
          best = candidate;
          bestScore = candidateScore;
        }
      }
    }

    const recognition = new OCRRecognition();
    recognition.text = best.text;
    recognition.selectedEngine = best.engine.length > 0 ? best.engine : 'none';
    recognition.outputs = normalized;
    return recognition;
  }

  private static score(output: OCRTextOutput): number {
    const text = output.text;
    if (text.length === 0) {
      return 0;
    }
    const nonWhitespace = text.replace(/\s/g, '').length;
    let numberCount = 0;
    for (let i = 0; i < text.length; i++) {
      const code = text.charCodeAt(i);
      if (code >= 48 && code <= 57) {
        numberCount += 1;
      }
    }
    let medicalTermHits = 0;
    const lower = text.toLowerCase();
    for (let i = 0; i < OCRFusionSelector.MEDICAL_HINTS.length; i++) {
      const term = OCRFusionSelector.MEDICAL_HINTS[i];
      if (lower.indexOf(term.toLowerCase()) >= 0) {
        medicalTermHits += 1;
      }
    }
    const confidencePart = (output.confidence !== undefined ? output.confidence : 0.6) * 40;
    const textLengthPart = Math.min(nonWhitespace, 1200) / 1200 * 30;
    const numberDensityPart = Math.min(numberCount, 80) / 80 * 10;
    const medicalPart = Math.min(medicalTermHits, 10) / 10 * 20;
    return confidencePart + textLengthPart + numberDensityPart + medicalPart;
  }
}
