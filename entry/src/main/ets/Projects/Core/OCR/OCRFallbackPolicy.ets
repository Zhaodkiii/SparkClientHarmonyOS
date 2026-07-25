import { HarmonyBuiltInOCRSession } from './HarmonyBuiltInOCRSession';
import { OCRConfiguration, OCRInitFailureClassifier } from './OCRModels';

export type OCRFallbackRootCause =
  'none' |
  'init_timeout' |
  'builtin_cooldown' |
  'engine_unavailable' |
  'empty_text';

/**
 * 内置 OCR 失败后的降级策略。
 * 注意：永远不因 canIUse/cooldown 建议跳过 Vision。
 */
export class OCRFallbackPolicy {
  static shouldSkipBuiltinVision(
    _session: HarmonyBuiltInOCRSession = HarmonyBuiltInOCRSession.shared()
  ): boolean {
    return false;
  }

  static hasRemoteFallback(config: OCRConfiguration): boolean {
    return config.enableAliyunOCR || config.enableLocalServerOCR;
  }

  static classifyRootCause(failures: string[]): OCRFallbackRootCause {
    if (failures.length === 0) {
      return 'none';
    }
    const joined = failures.join('|').toLowerCase();
    if (joined.indexOf('capability') >= 0) {
      return 'engine_unavailable';
    }
    if (joined.indexOf('builtin_ocr_cooldown') >= 0) {
      return 'builtin_cooldown';
    }
    if (joined.indexOf('vision_init') >= 0 ||
      joined.indexOf('init_timeout') >= 0 ||
      OCRInitFailureClassifier.isTimeout(joined)) {
      // init 软失败后仍会走 recognize；若最终失败更可能是识别阶段。
      if (joined.indexOf('vision_recognize') >= 0 || joined.indexOf('recognize_') >= 0) {
        return 'engine_unavailable';
      }
      return 'init_timeout';
    }
    if (joined.indexOf('engineunavailable') >= 0 || joined.indexOf('vision_recognize') >= 0) {
      return 'engine_unavailable';
    }
    return 'empty_text';
  }
}
