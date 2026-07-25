import { describe, it, expect } from '@ohos/hypium';
import {
  BuiltInOCRKitAdapter,
  HarmonyBuiltInOCRSession
} from '../../../main/ets/Projects/Core/OCR/HarmonyBuiltInOCRSession';
import {
  OCRInitFailureClassifier,
  OCRInitRetryPolicy
} from '../../../main/ets/Projects/Core/OCR/OCRModels';

class MockKitAdapter implements BuiltInOCRKitAdapter {
  initCalls: number = 0;
  releaseCalls: number = 0;
  softFail: boolean = false;

  probeCapability(): string {
    return 'TextRecognition=mock';
  }

  async initSoft(): Promise<boolean> {
    this.initCalls += 1;
    return !this.softFail;
  }

  async release(): Promise<void> {
    this.releaseCalls += 1;
  }
}

export default function medicalDocumentUpload0005Test() {
  describe('HOS_MED_UPLOAD_0005', () => {
    it('classifier_detects_init_timeout', 0, () => {
      expect(OCRInitFailureClassifier.isTimeout(
        'Run timed out, please try again later.'
      )).assertTrue();
    });

    it('should_never_skip_builtin_ocr', 0, () => {
      const session = new HarmonyBuiltInOCRSession(new MockKitAdapter());
      expect(session.shouldSkipBuiltinOCR()).assertFalse();
    });

    it('ensure_ready_lazy_does_not_call_init', 0, async () => {
      const kit = new MockKitAdapter();
      const session = new HarmonyBuiltInOCRSession(kit, OCRInitRetryPolicy.default());
      await session.ensureReadyWithRetry();
      expect(session.snapshot().state).assertEqual('ready');
      expect(kit.initCalls).assertEqual(0);
      expect(session.isHardInited()).assertFalse();
      await session.releaseWhenIdle();
    });

    it('prewarm_may_call_init_but_soft_fail_still_ready', 0, async () => {
      const kit = new MockKitAdapter();
      kit.softFail = true;
      const session = new HarmonyBuiltInOCRSession(kit, OCRInitRetryPolicy.default());
      await session.prewarm('test');
      expect(session.snapshot().state).assertEqual('ready');
      expect(kit.initCalls).assertEqual(1);
      expect(session.shouldSkipBuiltinOCR()).assertFalse();
    });
  });
}
