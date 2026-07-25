import { HarmonyBuiltInOCRSession } from './HarmonyBuiltInOCRSession';
import { OCRDiagnostics } from './OCRDiagnostics';

/**
 * 上传页打开 / Host 出现时后台预热内置 OCR，缩短用户点击后的 init 等待。
 * 失败不抛到 UI。
 */
export class OCRWarmupCoordinator {
  private static sharedInstance?: OCRWarmupCoordinator;
  private readonly session: HarmonyBuiltInOCRSession;
  private lastWarmupAtMs: number = 0;
  private readonly minIntervalMs: number = 15_000;

  constructor(session: HarmonyBuiltInOCRSession = HarmonyBuiltInOCRSession.shared()) {
    this.session = session;
  }

  static shared(): OCRWarmupCoordinator {
    if (OCRWarmupCoordinator.sharedInstance === undefined) {
      OCRWarmupCoordinator.sharedInstance = new OCRWarmupCoordinator();
    }
    return OCRWarmupCoordinator.sharedInstance;
  }

  /** 火即忘预热；同窗口内去重。 */
  prewarm(reason: string): void {
    const now = Date.now();
    if (now - this.lastWarmupAtMs < this.minIntervalMs && this.session.isReady()) {
      OCRDiagnostics.info('ocr.warmup.throttled', `reason=${reason}`);
      return;
    }
    this.lastWarmupAtMs = now;
    void this.session.prewarm(reason);
  }
}
