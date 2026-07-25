import { image } from '@kit.ImageKit';
import { Logger } from '../../../Foundation/Logging/Logger';
import { LogFields } from '../../../Foundation/Logging/LogEvent';
import { LogModule } from '../../../Foundation/Logging/LogModule';
import { HarmonyBuiltInOCREngine } from './HarmonyBuiltInOCREngine';
import { HarmonyBuiltInOCRSession } from './HarmonyBuiltInOCRSession';
import { MedicalImagePreprocessor } from './MedicalImagePreprocessor';
import { MedicalTermsCorrector } from './MedicalTermsCorrector';
import { OCRDiagnostics } from './OCRDiagnostics';
import { OCRDocumentExtractor } from './OCRDocumentExtractor';
import { OCRFallbackPolicy } from './OCRFallbackPolicy';
import { OCRFusionSelector } from './OCRFusionSelector';
import { OCRMockFallback } from './OCRMockFallback';
import {
  OCRConfiguration,
  OCRError,
  OCRErrorCode,
  OCRRecognition,
  OCRRecognitionHints,
  OCRRequestOptions,
  OCRTextEngine,
  OCRTextOutput
} from './OCRModels';

class OCREngineAttempt {
  engine: string = '';
  output?: OCRTextOutput;
  failure?: string;
}

/**
 * OCR 编排器：始终尝试 Vision（不再 cooldown/canIUse 跳过）。
 */
export class OCROrchestrator {
  private readonly config: OCRConfiguration;
  private readonly visionEngine: OCRTextEngine;
  private readonly aliyunEngine?: OCRTextEngine;
  private readonly localServerEngine?: OCRTextEngine;
  private readonly session: HarmonyBuiltInOCRSession;

  constructor(
    config: OCRConfiguration = new OCRConfiguration(),
    visionEngine: OCRTextEngine = new HarmonyBuiltInOCREngine(),
    aliyunEngine?: OCRTextEngine,
    localServerEngine?: OCRTextEngine,
    session: HarmonyBuiltInOCRSession = HarmonyBuiltInOCRSession.shared()
  ) {
    this.config = config;
    this.visionEngine = visionEngine;
    this.aliyunEngine = aliyunEngine;
    this.localServerEngine = localServerEngine;
    this.session = session;
  }

  async recognizeFromUri(
    uri: string,
    options: OCRRequestOptions = OCRRequestOptions.medicalDefault()
  ): Promise<OCRRecognition> {
    const hints = OCRRecognitionHints.from(this.config, options.topCandidatesCount);
    this.session.clearBlockingState('orchestrator_before_uri');
    OCRDiagnostics.info('ocr.orchestrator.start',
      `build=ocr-fix-20260724-v3;uri=${OCRDiagnostics.uriFingerprint(uri)};` +
        `skipBuiltin=${this.session.shouldSkipBuiltinOCR()};` +
        `state=${this.session.snapshot().state}`);

    const tasks: Array<Promise<OCREngineAttempt>> = [];
    // 永远跑 Vision：官方模板不因 canIUse 假阴性跳过。
    tasks.push(this.runEngine(this.visionEngine.name, (): Promise<OCRTextOutput> =>
      this.visionEngine.recognizeFromUri(uri, hints)));

    if (this.config.enableAliyunOCR && this.aliyunEngine !== undefined) {
      const engine = this.aliyunEngine;
      tasks.push(this.runEngine(engine.name, (): Promise<OCRTextOutput> =>
        engine.recognizeFromUri(uri, hints)));
    }
    if (this.config.enableLocalServerOCR && this.localServerEngine !== undefined) {
      const engine = this.localServerEngine;
      tasks.push(this.runEngine(engine.name, (): Promise<OCRTextOutput> =>
        engine.recognizeFromUri(uri, hints)));
    }

    return this.collectAndFuse(await Promise.all(tasks), options);
  }

  async recognizePixelMap(
    pixelMap: image.PixelMap,
    options: OCRRequestOptions = OCRRequestOptions.medicalDefault()
  ): Promise<OCRRecognition> {
    const working = options.applyPreprocess ?
      MedicalImagePreprocessor.shared().preprocess(pixelMap) : pixelMap;
    const hints = OCRRecognitionHints.from(this.config, options.topCandidatesCount);
    this.session.clearBlockingState('orchestrator_before_pixel');
    OCRDiagnostics.info('ocr.orchestrator.start',
      `input=pixelMap;skipBuiltin=${this.session.shouldSkipBuiltinOCR()}`);

    const attempt = await this.runEngine(this.visionEngine.name, (): Promise<OCRTextOutput> =>
      this.visionEngine.recognizePixelMap(working, hints));
    return this.collectAndFuse([attempt], options);
  }

  async recognizeDocument(
    filePathOrUri: string,
    mimeType: string = '',
    options: OCRRequestOptions = OCRRequestOptions.medicalDefault()
  ): Promise<OCRRecognition> {
    OCRDiagnostics.info('ocr.orchestrator.document',
      `mime=${mimeType};${OCRDiagnostics.uriFingerprint(filePathOrUri)}`);
    const extractor = new OCRDocumentExtractor(this.config);
    return extractor.extractText(filePathOrUri, this, options, mimeType);
  }

  private async runEngine(
    engineName: string,
    work: () => Promise<OCRTextOutput>
  ): Promise<OCREngineAttempt> {
    const attempt = new OCREngineAttempt();
    attempt.engine = engineName;
    const started = Date.now();
    OCRDiagnostics.info('ocr.engine.run_start', `engine=${engineName}`);
    try {
      attempt.output = await work();
      OCRDiagnostics.info('ocr.engine.run_ok',
        `engine=${engineName};elapsedMs=${Date.now() - started};` +
          `textLen=${attempt.output.text.length}`);
    } catch (error) {
      const phase = error instanceof OCRError && error.phase.length > 0 ? error.phase : 'unknown';
      const root = error instanceof OCRError && error.rootCause.length > 0 ?
        `;rootCause=${error.rootCause}` : '';
      attempt.failure = `${phase}:${OCRDiagnostics.errorMessage(error)}${root}`;
      OCRDiagnostics.warn('ocr.engine.run_failed',
        `engine=${engineName};phase=${phase};elapsedMs=${Date.now() - started};` +
          `error=${OCRDiagnostics.errorMessage(error)}`);
      this.logEngineFailure(engineName, phase, error);
    }
    return attempt;
  }

  private collectAndFuse(
    attempts: OCREngineAttempt[],
    options: OCRRequestOptions
  ): OCRRecognition {
    const outputs: OCRTextOutput[] = [];
    const failures: string[] = [];
    for (let i = 0; i < attempts.length; i++) {
      const item = attempts[i];
      if (item.output !== undefined) {
        outputs.push(item.output);
      } else if (item.failure !== undefined) {
        failures.push(`${item.engine}:${item.failure}`);
      }
    }

    if (outputs.length === 0) {
      const summary = failures.length > 0 ? failures.join('|') : 'none';
      const rootCause = OCRFallbackPolicy.classifyRootCause(failures);
      // 临时：模拟器 OCR 不可用时返回固定检验报告文本，联调类型识别。
      if (OCRMockFallback.ENABLED) {
        const mock = OCRMockFallback.buildRecognition();
        OCRDiagnostics.warn('ocr.mock.fallback_used',
          `reason=${rootCause};failures=${summary};engine=${mock.selectedEngine};textLen=${mock.text.length}`);
        return mock;
      }
      let code: OCRErrorCode = 'emptyOutput';
      let phase = 'orchestrator_collect';
      if (rootCause === 'init_timeout' || rootCause === 'builtin_cooldown') {
        code = 'engineUnavailable';
        phase = 'vision_init';
      } else if (rootCause === 'engine_unavailable') {
        code = 'engineUnavailable';
        phase = 'vision_recognize';
      }
      const detail =
        `no_ocr_engine_output;rootCause=${rootCause};` +
          `fallbackAvailable=${OCRFallbackPolicy.hasRemoteFallback(this.config)};` +
          `failures=${summary}`;
      const fields = new LogFields();
      fields.operation = 'ocr_orchestrator';
      fields.detail = `code=${code};${detail}`;
      Logger.warn('ocr.recognize.failed', LogModule.OCR, fields);
      throw new OCRError(code, detail, phase, rootCause);
    }

    const best = OCRFusionSelector.selectBest(
      outputs,
      MedicalTermsCorrector.shared(),
      options.correctMedicalTerms
    );
    this.logComplete(best, outputs, failures);
    return best;
  }

  private logComplete(best: OCRRecognition, outputs: OCRTextOutput[], failures: string[]): void {
    const fields = new LogFields();
    fields.operation = 'ocr_orchestrator';
    const engines: string[] = [];
    for (let i = 0; i < outputs.length; i++) {
      engines.push(outputs[i].engine);
    }
    fields.detail =
      `selected=${best.selectedEngine};engines=${engines.join(',')};` +
        `textLen=${best.text.length};failures=${failures.length}`;
    Logger.info('ocr.recognize.complete', LogModule.OCR, fields);
  }

  private logEngineFailure(engine: string, phase: string, error: Object | Error): void {
    const fields = new LogFields();
    fields.operation = 'ocr_orchestrator';
    fields.detail =
      `engine=${engine};phase=${phase};error=${OCRDiagnostics.errorMessage(error)}`;
    Logger.warn('ocr.engine.failed', LogModule.OCR, fields);
  }
}
