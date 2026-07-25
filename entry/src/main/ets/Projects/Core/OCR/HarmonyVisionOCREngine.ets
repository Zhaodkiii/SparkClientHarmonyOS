import { image } from '@kit.ImageKit';
import {
  OCRError,
  OCRRecognitionHints,
  OCRTextEngine,
  OCRTextOutput
} from './OCRModels';
import { HarmonyBuiltInOCREngine } from './HarmonyBuiltInOCREngine';

/**
 * 兼容旧类名：内部委托 HarmonyBuiltInOCREngine（安全 fd 读图 + session）。
 * 修复真机 `Cannot read property release of undefined`。
 */
export class HarmonyVisionOCREngine implements OCRTextEngine {
  readonly name: string = 'vision';
  private readonly builtin: HarmonyBuiltInOCREngine;

  constructor(builtin: HarmonyBuiltInOCREngine = new HarmonyBuiltInOCREngine()) {
    this.builtin = builtin;
  }

  async recognizeFromUri(uri: string, hints: OCRRecognitionHints): Promise<OCRTextOutput> {
    try {
      return await this.builtin.recognizeFromUri(uri, hints);
    } catch (error) {
      if (error instanceof OCRError) {
        throw new OCRError(error.code, error.detail, error.phase);
      }
      throw new OCRError('engineUnavailable', `${error}`, 'vision_from_uri');
    }
  }

  async recognizePixelMap(pixelMap: image.PixelMap, hints: OCRRecognitionHints): Promise<OCRTextOutput> {
    return await this.builtin.recognizePixelMap(pixelMap, hints);
  }
}
