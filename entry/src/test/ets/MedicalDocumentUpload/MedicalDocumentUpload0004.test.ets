import { describe, it, expect } from '@ohos/hypium';
import { image } from '@kit.ImageKit';
import {
  OCRConfiguration,
  OCRError,
  OCRRecognitionHints,
  OCRTextEngine,
  OCRTextOutput
} from '../../../main/ets/Projects/Core/OCR/OCRModels';
import { OCROrchestrator } from '../../../main/ets/Projects/Core/OCR/OCROrchestrator';
import { OCRDiagnostics } from '../../../main/ets/Projects/Core/OCR/OCRDiagnostics';
import { SafeOCRResourceRelease } from '../../../main/ets/Projects/Core/OCR/OCRImageSourceAdapter';
import { MedicalDocumentUploadErrorNormalizer } from '../../../main/ets/Projects/Features/MedicalDocumentUpload/Domain/MedicalDocumentUploadErrors';

class MockFailOCREngine implements OCRTextEngine {
  readonly name: string;
  private readonly error: OCRError;

  constructor(name: string, error: OCRError) {
    this.name = name;
    this.error = error;
  }

  async recognizeFromUri(_uri: string, _hints: OCRRecognitionHints): Promise<OCRTextOutput> {
    throw this.error;
  }

  async recognizePixelMap(_pixelMap: image.PixelMap, _hints: OCRRecognitionHints): Promise<OCRTextOutput> {
    throw this.error;
  }
}

class MockOkOCREngine implements OCRTextEngine {
  readonly name: string;
  private readonly text: string;

  constructor(name: string, text: string) {
    this.name = name;
    this.text = text;
  }

  async recognizeFromUri(_uri: string, _hints: OCRRecognitionHints): Promise<OCRTextOutput> {
    const output = new OCRTextOutput();
    output.engine = this.name;
    output.text = this.text;
    output.confidence = 0.8;
    return output;
  }

  async recognizePixelMap(_pixelMap: image.PixelMap, _hints: OCRRecognitionHints): Promise<OCRTextOutput> {
    return this.recognizeFromUri('', new OCRRecognitionHints());
  }
}

export default function medicalDocumentUpload0004Test() {
  describe('HOS_MED_UPLOAD_0004', () => {
    it('safe_release_tolerates_undefined_source_and_pixel_map', 0, () => {
      let threw = false;
      try {
        SafeOCRResourceRelease.imageSource(undefined, 'test_source');
        SafeOCRResourceRelease.pixelMap(undefined, 'test_pixel');
        SafeOCRResourceRelease.file(undefined, 'test_file');
      } catch (_e) {
        threw = true;
      }
      expect(threw).assertFalse();
    });

    it('uri_fingerprint_does_not_leak_full_path', 0, () => {
      const fp = OCRDiagnostics.uriFingerprint(
        'file://media/Photo/screenshot_20260724_201307_com.huawei.hmos.browser.jpg'
      );
      expect(fp.indexOf('kind=file') >= 0).assertTrue();
      expect(fp.indexOf('browser.jpg') >= 0).assertTrue();
      expect(fp.indexOf('file://media/Photo') < 0).assertTrue();
    });

    it('ocr_error_user_message_maps_image_source_phase', 0, () => {
      const err = new OCRError('invalidImage', 'image_source_undefined', 'image_source_create');
      expect(err.userMessage().indexOf('无法读取图片') >= 0).assertTrue();
      expect(err.userMessage().indexOf('file://') < 0).assertTrue();
    });

    it('ocr_error_user_message_maps_empty_output', 0, () => {
      const err = new OCRError(
        'emptyOutput',
        'no_ocr_engine_output;failures=vision:release of undefined',
        'orchestrator_collect'
      );
      expect(err.userMessage().indexOf('未识别到可用文字') >= 0).assertTrue();
    });

    it('error_normalizer_prefers_ocr_user_message', 0, () => {
      const err = new OCRError('engineUnavailable', 'vision_init_failed:x', 'vision_init');
      const stage = MedicalDocumentUploadErrorNormalizer.normalize(err);
      expect(stage.stage).assertEqual('ocr_failed');
      expect(stage.ocrPhase).assertEqual('vision_init');
      expect(stage.message.indexOf('初始化失败') >= 0).assertTrue();
      expect(stage.recoverable).assertTrue();
    });

    it('orchestrator_isolates_failed_engine_and_uses_fallback', 0, async () => {
      const config = new OCRConfiguration();
      config.enableAliyunOCR = true;
      const vision = new MockFailOCREngine(
        'vision',
        new OCRError('invalidImage', 'image_source_undefined', 'image_source_create')
      );
      const aliyun = new MockOkOCREngine('aliyun', '血常规 白细胞 参考区间');
      const orchestrator = new OCROrchestrator(config, vision, aliyun);
      const result = await orchestrator.recognizeFromUri('mock://browser-screenshot.jpg');
      expect(result.selectedEngine).assertEqual('aliyun');
      expect(result.text.indexOf('血常规') >= 0).assertTrue();
    });

    it('orchestrator_empty_output_includes_failure_summary', 0, async () => {
      const vision = new MockFailOCREngine(
        'vision',
        new OCRError('engineUnavailable', 'vision_recognize_failed:x', 'vision_recognize')
      );
      const orchestrator = new OCROrchestrator(new OCRConfiguration(), vision);
      let code = '';
      let detail = '';
      let phase = '';
      try {
        await orchestrator.recognizeFromUri('mock://blank.jpg');
      } catch (error) {
        if (error instanceof OCRError) {
          code = error.code;
          detail = error.detail;
          phase = error.phase;
        }
      }
      expect(code).assertEqual('emptyOutput');
      expect(detail.indexOf('no_ocr_engine_output') >= 0).assertTrue();
      expect(detail.indexOf('vision:') >= 0).assertTrue();
      expect(phase).assertEqual('orchestrator_collect');
    });
  });
}
