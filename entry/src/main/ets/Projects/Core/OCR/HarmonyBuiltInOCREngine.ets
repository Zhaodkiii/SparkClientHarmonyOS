import { image } from '@kit.ImageKit';
import { textRecognition } from '@kit.CoreVisionKit';
import { HarmonyBuiltInOCRSession } from './HarmonyBuiltInOCRSession';
import { OCRDiagnostics } from './OCRDiagnostics';
import { OCRImageSourceAdapter, SafeOCRResourceRelease } from './OCRImageSourceAdapter';
import {
  OCRError,
  OCRInitFailureClassifier,
  OCRInitRetryPolicy,
  OCRRecognitionHints,
  OCRTextEngine,
  OCRTextOutput
} from './OCRModels';

function delayMs(ms: number): Promise<void> {
  return new Promise<void>((resolve: () => void) => {
    setTimeout(resolve, ms);
  });
}

/**
 * 官方主路径：ensureReady(lazy) → RGBA PixelMap → recognizeText。
 * 不因 canIUse/init 失败跳过。
 */
export class HarmonyBuiltInOCREngine implements OCRTextEngine {
  readonly name: string = 'vision';
  private readonly session: HarmonyBuiltInOCRSession;
  private readonly imageSourceAdapter: OCRImageSourceAdapter;
  private readonly retryPolicy: OCRInitRetryPolicy;

  constructor(
    session: HarmonyBuiltInOCRSession = HarmonyBuiltInOCRSession.shared(),
    imageSourceAdapter: OCRImageSourceAdapter = new OCRImageSourceAdapter(),
    retryPolicy: OCRInitRetryPolicy = OCRInitRetryPolicy.default()
  ) {
    this.session = session;
    this.imageSourceAdapter = imageSourceAdapter;
    this.retryPolicy = retryPolicy;
  }

  async recognizeFromUri(uri: string, hints: OCRRecognitionHints): Promise<OCRTextOutput> {
    if (uri.length === 0) {
      throw new OCRError('invalidImage', 'empty_uri', 'image_uri');
    }
    OCRDiagnostics.info('ocr.engine.uri_start', OCRDiagnostics.uriFingerprint(uri));
    const opened = await this.imageSourceAdapter.openPixelMap(uri);
    try {
      return await this.recognizePixelMap(opened.pixelMap, hints);
    } finally {
      opened.releaseSafely();
    }
  }

  async recognizePixelMap(pixelMap: image.PixelMap, hints: OCRRecognitionHints): Promise<OCRTextOutput> {
    await this.session.ensureReadyWithRetry(this.retryPolicy);
    const working = await this.imageSourceAdapter.ensureRgba8888(pixelMap);
    const ownedWorking = working !== pixelMap;
    const started = Date.now();
    try {
      let infoW = 0;
      let infoH = 0;
      let infoFmt = -1;
      try {
        const info = await working.getImageInfo();
        infoW = info.size.width;
        infoH = info.size.height;
        infoFmt = info.pixelFormat as number;
      } catch (_e) {
        // ignore probe errors
      }
      OCRDiagnostics.info('ocr.engine.before_recognize',
        `w=${infoW};h=${infoH};fmt=${infoFmt};dirDetect=${hints.enableDirectionDetection}`);
      return await this.recognizeWithRetry(working, hints, started);
    } finally {
      if (ownedWorking) {
        SafeOCRResourceRelease.pixelMap(working, 'ocr_rgba_working');
      }
      await this.session.releaseWhenIdle();
    }
  }

  private async recognizeWithRetry(
    pixelMap: image.PixelMap,
    hints: OCRRecognitionHints,
    started: number
  ): Promise<OCRTextOutput> {
    const maxAttempts = 2;
    let lastError: Object | Error | undefined = undefined;
    for (let attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        if (attempt > 0) {
          await delayMs(400);
          OCRDiagnostics.info('ocr.builtin.recognize_retry', `index=${attempt}`);
        }
        const visionInfo: textRecognition.VisionInfo = {
          pixelMap: pixelMap
        };
        const config: textRecognition.TextRecognitionConfiguration = {
          isDirectionDetectionSupported: hints.enableDirectionDetection
        };
        OCRDiagnostics.info('ocr.builtin.recognize_call', `attempt=${attempt}`);
        const result = await textRecognition.recognizeText(visionInfo, config);
        const text = (result.value ?? '').trim();
        const output = new OCRTextOutput();
        output.engine = this.name;
        output.text = text;
        output.confidence = text.length > 0 ? 0.75 : 0;
        output.elapsedMs = Date.now() - started;
        OCRDiagnostics.info('ocr.builtin.recognize_ok',
          `engine=${this.name};textLen=${text.length};elapsedMs=${output.elapsedMs};attempt=${attempt}`);
        return output;
      } catch (error) {
        lastError = error;
        OCRDiagnostics.warn('ocr.builtin.recognize_failed',
          `attempt=${attempt};timeout=${OCRInitFailureClassifier.isTimeout(error)};` +
            `error=${OCRDiagnostics.errorMessage(error)}`);
        if (!OCRInitFailureClassifier.isTimeout(error) || attempt + 1 >= maxAttempts) {
          break;
        }
      }
    }

    if (lastError instanceof OCRError) {
      throw new OCRError(lastError.code, lastError.detail, lastError.phase, lastError.rootCause);
    }
    throw new OCRError(
      'engineUnavailable',
      `vision_recognize_failed:${OCRDiagnostics.errorMessage(lastError)}`,
      'vision_recognize',
      OCRInitFailureClassifier.isTimeout(lastError) ? 'recognize_timeout' : 'recognize_failed'
    );
  }
}
