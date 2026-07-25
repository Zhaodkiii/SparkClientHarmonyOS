import { Logger } from '../../../../Foundation/Logging/Logger';
import { LogFields } from '../../../../Foundation/Logging/LogEvent';
import { LogModule } from '../../../../Foundation/Logging/LogModule';
import { MedicalDocumentKind } from '../Domain/MedicalDocumentKind';
import {
  MedicalDocumentTypeResolutionFactory,
  MedicalDocumentTypeResolutionSource
} from '../Domain/MedicalDocumentTypeResolverProtocol';
import { MedicalDocumentTypeResolution } from '../Domain/MedicalDocumentTypedModels';
import {
  MedicalDocumentClassifier,
  MedicalDocumentClassifierMatchResult
} from './MedicalDocumentClassifier';

/**
 * 本地规则 Resolver：委托 MedicalDocumentClassifier（对齐 iOS LocalMedicalDocumentClassifier），
 * 再按 iOS resolveByRules 解释阈值：>=30 强命中，>=10 弱命中，否则 undefined 交给 AI。
 */
export class LocalMedicalDocumentTypeResolver {
  /** 兼容旧调用：非 AUTO 走 manual；AUTO 走规则。 */
  resolve(
    selectedKind: MedicalDocumentKind,
    mergedOCRText: string
  ): MedicalDocumentTypeResolution | undefined {
    if (selectedKind !== MedicalDocumentKind.AUTO) {
      return MedicalDocumentTypeResolutionFactory.manual(selectedKind);
    }
    return this.resolveAutoOnly(mergedOCRText);
  }

  /** 仅本地规则；未命中返回 undefined，不伪造 fallback source。 */
  resolveAutoOnly(mergedOCRText: string): MedicalDocumentTypeResolution | undefined {
    const trimmed = mergedOCRText.trim();
    if (trimmed.length === 0) {
      return undefined;
    }

    const results = MedicalDocumentClassifier.classify(trimmed);
    this.logScores(results);

    // 1) 置信度 >= 30：阈值内强命中，取最高分
    const strong = LocalMedicalDocumentTypeResolver.pickBestAbove(results, 30);
    if (strong !== undefined) {
      return MedicalDocumentTypeResolutionFactory.make(
        strong.kind,
        MedicalDocumentTypeResolutionSource.LOCAL_RULES,
        'advanced_keyword_rules',
        LocalMedicalDocumentTypeResolver.normalizeConfidence(strong.confidence)
      );
    }

    // 2) 10–29：弱命中仍返回 localRules（对齐 iOS reason=advanced_keyword_rules）
    const weak = LocalMedicalDocumentTypeResolver.pickBestAbove(results, 10);
    if (weak !== undefined) {
      return MedicalDocumentTypeResolutionFactory.make(
        weak.kind,
        MedicalDocumentTypeResolutionSource.LOCAL_RULES,
        'advanced_keyword_rules',
        LocalMedicalDocumentTypeResolver.normalizeConfidence(weak.confidence)
      );
    }

    return undefined;
  }

  private logScores(results: MedicalDocumentClassifierMatchResult[]): void {
    const parts: string[] = [];
    for (let i = 0; i < results.length; i++) {
      parts.push(`${results[i].kind}:${results[i].confidence}`);
    }
    const fields = new LogFields();
    fields.operation = 'medical_document_classifier';
    fields.detail = `[${parts.join(', ')}]`;
    Logger.info('medical.upload.type.local_scores', LogModule.HOME, fields);
  }

  private static pickBestAbove(
    results: MedicalDocumentClassifierMatchResult[],
    minConfidence: number
  ): MedicalDocumentClassifierMatchResult | undefined {
    let best: MedicalDocumentClassifierMatchResult | undefined = undefined;
    for (let i = 0; i < results.length; i++) {
      const item = results[i];
      if (item.confidence < minConfidence) {
        continue;
      }
      if (best === undefined || item.confidence > best.confidence) {
        best = item;
      }
    }
    return best;
  }

  /** 对齐 iOS normalizeConfidence：0–100 → 0.0–1.0 非线性映射。 */
  static normalizeConfidence(rawScore: number): number {
    const score = Math.min(100, Math.max(0, rawScore));
    if (score >= 80) {
      return 0.9 + (score - 80) * 0.004;
    }
    if (score >= 60) {
      return 0.7 + (score - 60) * 0.01;
    }
    if (score >= 40) {
      return 0.5 + (score - 40) * 0.01;
    }
    return 0.3 + score * 0.005;
  }
}
