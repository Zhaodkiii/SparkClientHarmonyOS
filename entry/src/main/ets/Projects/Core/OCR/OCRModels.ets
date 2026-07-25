import { image } from '@kit.ImageKit';

/** 对齐 iOS OCRRequestOptions。 */
export class OCRRequestOptions {
  preferMedicalPreset: boolean = true;
  applyPreprocess: boolean = true;
  correctMedicalTerms: boolean = true;
  topCandidatesCount: number = 3;
  useTiling: boolean = false;

  static medicalDefault(): OCRRequestOptions {
    const options = new OCRRequestOptions();
    options.preferMedicalPreset = true;
    options.applyPreprocess = true;
    options.correctMedicalTerms = true;
    options.topCandidatesCount = 3;
    options.useTiling = false;
    return options;
  }

  static fastPreview(): OCRRequestOptions {
    const options = new OCRRequestOptions();
    options.preferMedicalPreset = false;
    options.applyPreprocess = false;
    options.correctMedicalTerms = false;
    options.topCandidatesCount = 1;
    options.useTiling = false;
    return options;
  }
}

/** 识别语言策略。 */
export type OCRLanguageStrategyKind = 'system' | 'codes';

export class OCRLanguageStrategy {
  kind: OCRLanguageStrategyKind = 'system';
  codes: string[] = [];

  static system(): OCRLanguageStrategy {
    const strategy = new OCRLanguageStrategy();
    strategy.kind = 'system';
    return strategy;
  }

  static withCodes(codes: string[]): OCRLanguageStrategy {
    const strategy = new OCRLanguageStrategy();
    strategy.kind = 'codes';
    strategy.codes = codes.slice();
    return strategy;
  }

  resolvedCodes(): string[] {
    if (this.kind === 'codes' && this.codes.length > 0) {
      return OCRLanguageStrategy.normalizeCodes(this.codes);
    }
    return ['zh-Hans', 'en-US'];
  }

  private static normalizeCodes(codes: string[]): string[] {
    const out: string[] = [];
    const seen = new Set<string>();
    for (let i = 0; i < codes.length; i++) {
      const code = codes[i].trim();
      if (code.length === 0 || seen.has(code)) {
        continue;
      }
      seen.add(code);
      out.push(code);
    }
    return out;
  }
}

/** 对齐 iOS OCRConfiguration。 */
export class OCRConfiguration {
  language: OCRLanguageStrategy = OCRLanguageStrategy.system();
  recognitionLevelRaw: string = 'accurate';
  useLanguageCorrection: boolean = false;
  pdfRenderScale: number = 2.0;
  thumbnailMaxSide: number = 1600;
  enableAliyunOCR: boolean = false;
  enableLocalServerOCR: boolean = false;
  localServerBaseURL: string = '';
  localServerTimeoutMs: number = 10000;
  localServerAuthToken: string = '';
  /** PDF 复制到沙箱时的缓存目录；由 AppContainer 注入。 */
  cacheDir: string = '';
}

/** 传给引擎的识别提示。 */
export class OCRRecognitionHints {
  languages: string[] = ['zh-Hans', 'en-US'];
  recognitionLevelRaw: string = 'accurate';
  topCandidatesCount: number = 3;
  useLanguageCorrection: boolean = false;
  /** 是否启用朝向检测；医疗单据默认 false，对齐官方示例默认值。 */
  enableDirectionDetection: boolean = false;

  static from(configuration: OCRConfiguration, topCandidatesCount: number): OCRRecognitionHints {
    const hints = new OCRRecognitionHints();
    hints.languages = configuration.language.resolvedCodes();
    hints.recognitionLevelRaw = configuration.recognitionLevelRaw;
    hints.topCandidatesCount = Math.max(1, topCandidatesCount);
    hints.useLanguageCorrection = configuration.useLanguageCorrection;
    hints.enableDirectionDetection = false;
    return hints;
  }
}

/** 单引擎输出。 */
export class OCRTextOutput {
  engine: string = '';
  text: string = '';
  confidence?: number;
  elapsedMs?: number;
}

/** 融合后的最终识别结果。 */
export class OCRRecognition {
  text: string = '';
  selectedEngine: string = '';
  outputs: OCRTextOutput[] = [];
}

/** 引擎协议：URI / PixelMap 双入口，对齐医疗上传与聊天 OCR。 */
export interface OCRTextEngine {
  name: string;

  recognizeFromUri(uri: string, hints: OCRRecognitionHints): Promise<OCRTextOutput>;

  recognizePixelMap(pixelMap: image.PixelMap, hints: OCRRecognitionHints): Promise<OCRTextOutput>;
}

/** 文档提取器调用编排器时的最小识别面，避免循环依赖。 */
export interface OCRImageRecognizing {
  recognizeFromUri(uri: string, options?: OCRRequestOptions): Promise<OCRRecognition>;

  recognizePixelMap(pixelMap: image.PixelMap, options?: OCRRequestOptions): Promise<OCRRecognition>;
}

/** 阿里云 OCR 临时凭证。 */
export class OCRAliyunCredentials {
  accessKeyId: string = '';
  accessKeySecret: string = '';
  securityToken: string = '';
}

export interface OCRCredentialsProvider {
  fetchAliyunOCRCredentials(): Promise<OCRAliyunCredentials>;
}

export type OCRErrorCode =
  'invalidImage' |
  'invalidDocumentURL' |
  'engineUnavailable' |
  'transport' |
  'response' |
  'emptyOutput';

/** 内置 OCR Session 显式状态（HOS-MED-UPLOAD-0005）。 */
export type BuiltInOCRSessionState =
  'idle' | 'warming' | 'ready' | 'failed' | 'cooldown';

export class BuiltInOCRSessionSnapshot {
  state: BuiltInOCRSessionState = 'idle';
  lastInitStartedAtMs: number = 0;
  lastInitFinishedAtMs: number = 0;
  lastFailureReason: string = '';
  consecutiveInitFailures: number = 0;
  cooldownUntilMs: number = 0;
  keepAliveUntilMs: number = 0;
  activeUsers: number = 0;
}

/** init 超时后同次 OCR 最多重试一次。 */
export class OCRInitRetryPolicy {
  allowOneRetry: boolean = true;
  retryDelayMs: number = 600;
  cooldownAfterFailures: number = 2;
  cooldownMs: number = 60_000;
  keepAliveMs: number = 60_000;

  static default(): OCRInitRetryPolicy {
    return new OCRInitRetryPolicy();
  }

  static warmupDefault(): OCRInitRetryPolicy {
    const policy = new OCRInitRetryPolicy();
    policy.allowOneRetry = false;
    return policy;
  }
}

/** 判断 init 超时 / 熔断相关错误。 */
export class OCRInitFailureClassifier {
  static isTimeout(error: Object | Error | string | undefined): boolean {
    const msg = OCRInitFailureClassifier.messageOf(error).toLowerCase();
    return msg.indexOf('timed out') >= 0 ||
      msg.indexOf('timeout') >= 0 ||
      msg.indexOf('init_timeout') >= 0 ||
      msg.indexOf('run timed out') >= 0;
  }

  static isInitFailure(error: Object | Error | string | undefined): boolean {
    const msg = OCRInitFailureClassifier.messageOf(error).toLowerCase();
    return msg.indexOf('vision_init') >= 0 ||
      msg.indexOf('init_failed') >= 0 ||
      msg.indexOf('builtin_ocr_cooldown') >= 0 ||
      OCRInitFailureClassifier.isTimeout(error);
  }

  static messageOf(error: Object | Error | string | undefined): string {
    if (error === undefined || error === null) {
      return '';
    }
    if (typeof error === 'string') {
      return error;
    }
    if (error instanceof Error) {
      return error.message;
    }
    try {
      return `${error}`;
    } catch (_e) {
      return '';
    }
  }
}

export class OCRError extends Error {
  code: OCRErrorCode;
  detail: string;
  phase: string;
  rootCause: string;

  constructor(
    code: OCRErrorCode,
    detail: string = '',
    phase: string = '',
    rootCause: string = ''
  ) {
    super(detail.length > 0 ? `${code}:${detail}` : code);
    this.code = code;
    this.detail = detail;
    this.phase = phase;
    this.rootCause = rootCause;
    this.name = 'OCRError';
  }

  /** 用户可见文案；不泄露完整 URI。 */
  userMessage(): string {
    const d = `${this.detail}|${this.phase}|${this.rootCause}`;
    if (this.code === 'invalidImage') {
      if (d.indexOf('empty_uri') >= 0) {
        return '图片路径无效，请重新选择文件';
      }
      if (d.indexOf('image_source') >= 0 || d.indexOf('open_file') >= 0 ||
        d.indexOf('uri_to_pixel') >= 0 || d.indexOf('image_uri') >= 0) {
        return '无法读取图片，请重新选择原图或授权相册访问';
      }
      if (d.indexOf('pixel_map') >= 0 || d.indexOf('create_pixel_map') >= 0) {
        return '图片格式暂不支持或文件损坏，请换一张原图';
      }
      return '图片读取失败，请重新选择';
    }
    if (this.code === 'engineUnavailable' ||
      d.indexOf('vision_init') >= 0 ||
      d.indexOf('init_timeout') >= 0 ||
      d.indexOf('builtin_ocr_cooldown') >= 0) {
      if (d.indexOf('timeout') >= 0 || d.indexOf('timed out') >= 0 ||
        d.indexOf('init_timeout') >= 0) {
        return '系统 OCR 初始化超时，请稍后重试';
      }
      if (d.indexOf('cooldown') >= 0) {
        return '系统 OCR 暂不可用，请稍后重试';
      }
      if (d.indexOf('init') >= 0) {
        return '系统 OCR 初始化失败，请重试';
      }
      if (d.indexOf('recognize') >= 0) {
        return '系统 OCR 识别失败，请换清晰图片后重试';
      }
      if (this.code === 'engineUnavailable') {
        return '系统 OCR 暂不可用，请稍后重试';
      }
    }
    if (this.code === 'emptyOutput') {
      // emptyOutput 里若夹带 vision_init，优先展示初始化失败，勿误导为“无文字”。
      if (d.indexOf('vision_init') >= 0 || d.indexOf('init_timeout') >= 0 ||
        d.indexOf('cooldown') >= 0) {
        return '系统 OCR 初始化超时，请稍后重试';
      }
      return '未识别到可用文字，请换清晰图片或手动录入';
    }
    if (this.code === 'invalidDocumentURL') {
      return '文档读取失败，请重新选择文件';
    }
    return 'OCR 识别失败，请重试或更换文件';
  }
}
