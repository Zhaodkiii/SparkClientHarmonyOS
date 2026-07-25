import { textRecognition } from '@kit.CoreVisionKit';
import { OCRDiagnostics } from './OCRDiagnostics';
import {
  BuiltInOCRSessionSnapshot,
  BuiltInOCRSessionState,
  OCRError,
  OCRInitRetryPolicy
} from './OCRModels';

/**
 * Vision Kit 适配。
 * 官方快递/提词器等模板：多数直接 recognizeText，不强制 init，也不因 canIUse 阻断。
 */
export interface BuiltInOCRKitAdapter {
  /** @returns true=硬初始化成功；false=软就绪 */
  initSoft(): Promise<boolean>;

  release(): Promise<void>;

  probeCapability(): string;
}

class DefaultBuiltInOCRKitAdapter implements BuiltInOCRKitAdapter {
  probeCapability(): string {
    let canUse = 'unknown';
    try {
      canUse = `${canIUse('SystemCapability.AI.OCR.TextRecognition')}`;
    } catch (error) {
      canUse = `throw:${OCRDiagnostics.errorMessage(error)}`;
    }
    return `TextRecognition=${canUse}`;
  }

  async initSoft(): Promise<boolean> {
    try {
      const result = await textRecognition.init();
      // API 可能返回 boolean 或 void；仅明确 false 视为软失败。
      if (result === false) {
        OCRDiagnostics.warn('ocr.session.init_false', 'init=false;continue=lazy');
        return false;
      }
      OCRDiagnostics.info('ocr.session.init_ok', `result=${result}`);
      return true;
    } catch (error) {
      OCRDiagnostics.warn('ocr.session.init_soft_fail',
        `error=${OCRDiagnostics.errorMessage(error)};continue=lazy_recognize`);
      return false;
    }
  }

  async release(): Promise<void> {
    try {
      await textRecognition.release();
    } catch (error) {
      OCRDiagnostics.warn('ocr.resource.release_failed',
        `phase=vision_session_release;error=${OCRDiagnostics.errorMessage(error)}`);
    }
  }
}

/**
 * Session：默认官方路径 —— 不因 canIUse/cooldown 跳过识别。
 * ensureReady 可直接 lazy ready；预热时才尝试 init。
 */
export class HarmonyBuiltInOCRSession {
  private static sharedInstance?: HarmonyBuiltInOCRSession;

  private readonly kit: BuiltInOCRKitAdapter;
  private readonly policy: OCRInitRetryPolicy;

  private state: BuiltInOCRSessionState = 'idle';
  private initTask?: Promise<void>;
  private activeUsers: number = 0;
  private lastInitStartedAtMs: number = 0;
  private lastInitFinishedAtMs: number = 0;
  private lastFailureReason: string = '';
  private consecutiveInitFailures: number = 0;
  private cooldownUntilMs: number = 0;
  private keepAliveUntilMs: number = 0;
  private keepAliveTimerId?: number;
  private hardInited: boolean = false;

  constructor(
    kit: BuiltInOCRKitAdapter = new DefaultBuiltInOCRKitAdapter(),
    policy: OCRInitRetryPolicy = OCRInitRetryPolicy.default()
  ) {
    this.kit = kit;
    this.policy = policy;
  }

  static shared(): HarmonyBuiltInOCRSession {
    if (HarmonyBuiltInOCRSession.sharedInstance === undefined) {
      HarmonyBuiltInOCRSession.sharedInstance = new HarmonyBuiltInOCRSession();
    }
    return HarmonyBuiltInOCRSession.sharedInstance;
  }

  static resetSharedForTests(): void {
    HarmonyBuiltInOCRSession.sharedInstance = undefined;
  }

  snapshot(): BuiltInOCRSessionSnapshot {
    const snap = new BuiltInOCRSessionSnapshot();
    snap.state = this.state;
    snap.lastInitStartedAtMs = this.lastInitStartedAtMs;
    snap.lastInitFinishedAtMs = this.lastInitFinishedAtMs;
    snap.lastFailureReason = this.lastFailureReason;
    snap.consecutiveInitFailures = this.consecutiveInitFailures;
    snap.cooldownUntilMs = this.cooldownUntilMs;
    snap.keepAliveUntilMs = this.keepAliveUntilMs;
    snap.activeUsers = this.activeUsers;
    return snap;
  }

  isReady(): boolean {
    return this.state === 'ready';
  }

  isHardInited(): boolean {
    return this.hardInited && this.state === 'ready';
  }

  /**
   * 永远不跳过内置 OCR。
   * 真机 canIUse 可能误报 false，但 recognizeText 仍可用（官方快递模板即如此）。
   */
  shouldSkipBuiltinOCR(): boolean {
    return false;
  }

  clearBlockingState(reason: string): void {
    this.cooldownUntilMs = 0;
    this.consecutiveInitFailures = 0;
    if (this.state === 'cooldown' || this.state === 'failed') {
      this.transitionTo('idle', reason);
    }
    OCRDiagnostics.info('ocr.session.clear_block',
      `reason=${reason};cap=${this.kit.probeCapability()};state=${this.state}`);
  }

  async prewarm(reason: string): Promise<void> {
    OCRDiagnostics.info('ocr.warmup.start',
      `reason=${reason};cap=${this.kit.probeCapability()};state=${this.state}`);
    if (this.state === 'ready' || this.state === 'warming') {
      OCRDiagnostics.info('ocr.warmup.skip_already', `reason=${reason};state=${this.state}`);
      return;
    }
    try {
      // 预热尝试硬 init；失败则 lazy ready，不阻断后续 OCR。
      await this.ensureReady(true);
      await this.releaseWhenIdle();
      OCRDiagnostics.info('ocr.warmup.ok',
        `reason=${reason};state=${this.state};hardInited=${this.hardInited}`);
    } catch (error) {
      OCRDiagnostics.warn('ocr.warmup.failed',
        `reason=${reason};error=${OCRDiagnostics.errorMessage(error)}`);
    }
  }

  async ensureReadyWithRetry(_policy: OCRInitRetryPolicy = this.policy): Promise<void> {
    this.clearBlockingState('ensure_ready_clear');
    const maxAttempts = _policy.allowOneRetry ? 2 : 1;
    let lastError: Object | Error | undefined = undefined;
    for (let attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        if (attempt > 0) {
          await this.delay(_policy.retryDelayMs);
          await this.forceReset('init_retry');
          OCRDiagnostics.info('ocr.session.init_retry', `attempt=${attempt}`);
        }
        // 官方通用文字识别要求先 init 再 recognizeText。识别主路径不能 lazy ready。
        await this.ensureReady(true);
        if (this.hardInited && this.state === 'ready') {
          return;
        }
        throw new OCRError('engineUnavailable', 'vision_init_failed:not_hard_inited', 'vision_init', 'init_failed');
      } catch (error) {
        lastError = error;
        if (attempt + 1 >= maxAttempts) {
          break;
        }
      }
    }
    throw this.normalizeInitError(lastError);
  }

  /**
   * @param tryHardInit true=预热时尝试 init；false=直接 lazy ready 后走 recognizeText
   */
  async ensureReady(tryHardInit: boolean = false): Promise<void> {
    this.cancelKeepAliveTimer();
    this.activeUsers += 1;
    OCRDiagnostics.info('ocr.session.ensure_ready',
      `tryHardInit=${tryHardInit};state=${this.state};hardInited=${this.hardInited};` +
        `activeUsers=${this.activeUsers};cap=${this.kit.probeCapability()}`);

    if (this.state === 'ready' && (!tryHardInit || this.hardInited)) {
      return;
    }

    if (this.state === 'ready' && tryHardInit && !this.hardInited) {
      this.transitionTo('idle', 'hard_init_required');
      this.initTask = undefined;
    }

    if (!tryHardInit) {
      this.hardInited = false;
      this.transitionTo('ready', 'lazy_no_init');
      OCRDiagnostics.info('ocr.session.ready_lazy',
        'mode=official_recognize_without_init');
      return;
    }

    if (this.initTask === undefined) {
      this.initTask = this.initInternalSoft();
    }
    try {
      await this.initTask;
    } catch (error) {
      this.activeUsers = Math.max(0, this.activeUsers - 1);
      throw this.normalizeInitError(error);
    }
  }

  async releaseWhenIdle(): Promise<void> {
    this.activeUsers = Math.max(0, this.activeUsers - 1);
    OCRDiagnostics.info('ocr.session.release_when_idle',
      `activeUsers=${this.activeUsers};hardInited=${this.hardInited};state=${this.state}`);
    if (this.activeUsers > 0 || this.state !== 'ready') {
      return;
    }
    if (!this.hardInited) {
      return;
    }
    this.scheduleReleaseAfter(this.policy.keepAliveMs);
  }

  async releaseNow(reason: string = 'manual'): Promise<void> {
    this.cancelKeepAliveTimer();
    this.activeUsers = 0;
    if (this.hardInited) {
      await this.kit.release();
      this.hardInited = false;
      OCRDiagnostics.info('ocr.session.released', `reason=${reason}`);
    }
    this.initTask = undefined;
    this.transitionTo('idle', reason);
  }

  async forceReset(reason: string): Promise<void> {
    this.cancelKeepAliveTimer();
    this.initTask = undefined;
    if (this.hardInited) {
      await this.kit.release();
      this.hardInited = false;
    }
    this.transitionTo('idle', reason);
    OCRDiagnostics.info('ocr.session.reset', `reason=${reason};state=${this.state}`);
  }

  private async initInternalSoft(): Promise<void> {
    this.transitionTo('warming', 'init_start');
    this.lastInitStartedAtMs = Date.now();
    const hardOk = await this.kit.initSoft();
    this.lastInitFinishedAtMs = Date.now();
    const elapsed = this.lastInitFinishedAtMs - this.lastInitStartedAtMs;

    if (hardOk) {
      this.hardInited = true;
      this.consecutiveInitFailures = 0;
      this.lastFailureReason = '';
      this.transitionTo('ready', 'init_ok');
      OCRDiagnostics.info('ocr.session.ready', `initMs=${elapsed};mode=hard`);
      return;
    }

    this.hardInited = false;
    this.consecutiveInitFailures += 1;
    this.lastFailureReason = 'init_soft_failed';
    this.transitionTo('failed', 'init_failed');
    this.initTask = undefined;
    OCRDiagnostics.warn('ocr.session.init_failed',
      `elapsedMs=${elapsed};failures=${this.consecutiveInitFailures};mode=strict_before_recognize`);
    throw new OCRError('engineUnavailable', 'vision_init_failed:init_soft_failed', 'vision_init', 'init_failed');
  }

  private normalizeInitError(error: Object | Error | undefined): OCRError {
    if (error instanceof OCRError) {
      return new OCRError(error.code, error.detail, error.phase, error.rootCause);
    }
    return new OCRError(
      'engineUnavailable',
      `vision_init_failed:${OCRDiagnostics.errorMessage(error)}`,
      'vision_init',
      'init_failed'
    );
  }

  private delay(ms: number): Promise<void> {
    return new Promise<void>((resolve: () => void) => {
      setTimeout(resolve, ms);
    });
  }

  private scheduleReleaseAfter(ms: number): void {
    this.cancelKeepAliveTimer();
    this.keepAliveUntilMs = Date.now() + ms;
    this.keepAliveTimerId = setTimeout((): void => {
      this.keepAliveTimerId = undefined;
      if (this.activeUsers > 0 || this.state !== 'ready' || !this.hardInited) {
        return;
      }
      void this.kit.release().then((): void => {
        this.hardInited = false;
        this.transitionTo('idle', 'keep_alive_expired');
        this.initTask = undefined;
        this.keepAliveUntilMs = 0;
      });
    }, ms);
    OCRDiagnostics.info('ocr.session.keepalive_scheduled', `ms=${ms}`);
  }

  private cancelKeepAliveTimer(): void {
    if (this.keepAliveTimerId !== undefined) {
      clearTimeout(this.keepAliveTimerId);
      this.keepAliveTimerId = undefined;
    }
    this.keepAliveUntilMs = 0;
  }

  private transitionTo(next: BuiltInOCRSessionState, reason: string): void {
    const from = this.state;
    if (from === next) {
      return;
    }
    this.state = next;
    OCRDiagnostics.info('ocr.session.state', `from=${from};to=${next};reason=${reason}`);
  }
}
