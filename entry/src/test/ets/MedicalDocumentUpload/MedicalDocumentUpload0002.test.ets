import { describe, it, expect } from '@ohos/hypium';
import { OCRFusionSelector } from '../../../main/ets/Projects/Core/OCR/OCRFusionSelector';
import { MedicalTermsCorrector } from '../../../main/ets/Projects/Core/OCR/MedicalTermsCorrector';
import { OCRTextOutput } from '../../../main/ets/Projects/Core/OCR/OCRModels';
import { MedicalFileOCRResult } from '../../../main/ets/Projects/Features/MedicalDocumentUpload/Domain/MedicalDocumentOCRResult';
import { MedicalDocumentOCRTextMerger } from '../../../main/ets/Projects/Features/MedicalDocumentUpload/Infrastructure/MedicalDocumentOCRTextMerger';
import { LocalMedicalDocumentTypeResolver } from '../../../main/ets/Projects/Features/MedicalDocumentUpload/Infrastructure/LocalMedicalDocumentTypeResolver';
import { MedicalDocumentClassifier } from '../../../main/ets/Projects/Features/MedicalDocumentUpload/Infrastructure/MedicalDocumentClassifier';
import { MedicalDocumentKind } from '../../../main/ets/Projects/Features/MedicalDocumentUpload/Domain/MedicalDocumentKind';
import { MedicalDocumentTypeResolutionSource } from '../../../main/ets/Projects/Features/MedicalDocumentUpload/Domain/MedicalDocumentTypeResolverProtocol';
import { MedicalDocumentUploadErrorNormalizer } from '../../../main/ets/Projects/Features/MedicalDocumentUpload/Domain/MedicalDocumentUploadErrors';

export default function medicalDocumentUpload0002Test() {
  describe('HOS_MED_UPLOAD_0002', () => {
    it('text_merger_keeps_file_boundaries_and_order', 0, () => {
      const a = new MedicalFileOCRResult();
      a.displayName = 'a.jpg';
      a.text = '血常规\n\n\n白细胞';
      const b = new MedicalFileOCRResult();
      b.displayName = 'b.pdf';
      b.text = '肝功能';
      const merged = MedicalDocumentOCRTextMerger.merge([a, b]);
      expect(merged.indexOf('=== File 1: a.jpg ===') >= 0).assertTrue();
      expect(merged.indexOf('=== File 2: b.pdf ===') >= 0).assertTrue();
      expect(merged.indexOf('血常规') >= 0).assertTrue();
      expect(merged.indexOf('肝功能') >= 0).assertTrue();
      expect(merged.indexOf('\n\n\n') < 0).assertTrue();
    });

    it('terms_corrector_fixes_mri_ocr_typo', 0, () => {
      const text = MedicalTermsCorrector.shared().correct('MR1 of brain and FLA1R sequence');
      expect(text.indexOf('MRI') >= 0).assertTrue();
      expect(text.indexOf('FLAIR') >= 0).assertTrue();
    });

    it('fusion_selector_prefers_medical_rich_text', 0, () => {
      const weak = new OCRTextOutput();
      weak.engine = 'a';
      weak.text = 'hello';
      weak.confidence = 0.9;
      const strong = new OCRTextOutput();
      strong.engine = 'b';
      strong.text = '血常规 MRI mmol/L CT 报告';
      strong.confidence = 0.5;
      const best = OCRFusionSelector.selectBest([weak, strong], MedicalTermsCorrector.shared(), true);
      expect(best.selectedEngine).assertEqual('b');
      expect(best.text.indexOf('MRI') >= 0).assertTrue();
    });

    it('type_resolver_manual_kind_wins', 0, () => {
      const resolver = new LocalMedicalDocumentTypeResolver();
      const resolution = resolver.resolve(MedicalDocumentKind.PRESCRIPTION, '无关文本');
      expect(resolution !== undefined).assertTrue();
      expect(resolution!.kind).assertEqual(MedicalDocumentKind.PRESCRIPTION);
      expect(resolution!.source).assertEqual(MedicalDocumentTypeResolutionSource.MANUAL);
    });

    it('type_resolver_rules_match_lab_report', 0, () => {
      const resolver = new LocalMedicalDocumentTypeResolver();
      const resolution = resolver.resolve(
        MedicalDocumentKind.AUTO,
        '检验报告单 检查所见 诊断意见 结果 参考区间 单位 mmol/L'
      );
      expect(resolution !== undefined).assertTrue();
      expect(resolution!.kind).assertEqual(MedicalDocumentKind.MEDICAL_REPORT);
      expect(resolution!.source).assertEqual(MedicalDocumentTypeResolutionSource.LOCAL_RULES);
    });

    it('classifier_returns_six_kind_scores', 0, () => {
      const results = MedicalDocumentClassifier.classify('检验报告单 诊断意见');
      expect(results.length).assertEqual(6);
    });

    it('error_normalizer_maps_extract_pending', 0, () => {
      const stage = MedicalDocumentUploadErrorNormalizer.normalize(new Error('EXTRACT_PENDING'));
      expect(stage.stage).assertEqual('extract_pending');
      expect(stage.recoverable).assertEqual(true);
    });
  });
}
