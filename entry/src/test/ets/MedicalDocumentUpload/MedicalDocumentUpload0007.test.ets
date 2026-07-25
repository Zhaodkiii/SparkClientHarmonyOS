import { describe, it, expect } from '@ohos/hypium';
import { OCRMockFallback } from '../../../main/ets/Projects/Core/OCR/OCRMockFallback';
import { MedicalDocumentKind } from '../../../main/ets/Projects/Features/MedicalDocumentUpload/Domain/MedicalDocumentKind';
import {
  MedicalDocumentTypeResolutionFactory,
  MedicalDocumentTypeResolutionSource
} from '../../../main/ets/Projects/Features/MedicalDocumentUpload/Domain/MedicalDocumentTypeResolverProtocol';
import { MedicalDocumentTypeResolution } from '../../../main/ets/Projects/Features/MedicalDocumentUpload/Domain/MedicalDocumentTypedModels';
import { DefaultMedicalDocumentTypeResolver } from '../../../main/ets/Projects/Features/MedicalDocumentUpload/Infrastructure/DefaultMedicalDocumentTypeResolver';
import { LocalMedicalDocumentTypeResolver } from '../../../main/ets/Projects/Features/MedicalDocumentUpload/Infrastructure/LocalMedicalDocumentTypeResolver';
import { MedicalDocumentTypeResponseDecoder } from '../../../main/ets/Projects/Features/MedicalDocumentUpload/Infrastructure/MedicalDocumentTypeResponseDecoder';
import { MedicalDocumentUploadViewModel } from '../../../main/ets/Projects/Features/MedicalDocumentUpload/Presentation/MedicalDocumentUploadViewModel';

/**
 * HOS-MED-UPLOAD-0007：OCR / 类型判定偏差复核验收。
 */
export default function medicalDocumentUpload0007Test() {
  describe('HOS_MED_UPLOAD_0007', () => {
    it('mock_fallback_disabled_by_default', 0, () => {
      expect(OCRMockFallback.ENABLED).assertFalse();
    });

    it('ai_fallback_default_matches_ios_confidence_0_4', 0, () => {
      const fallback = MedicalDocumentTypeResolutionFactory.aiFallbackDefault();
      expect(fallback.kind).assertEqual(MedicalDocumentKind.MEDICAL_REPORT);
      expect(fallback.source).assertEqual(MedicalDocumentTypeResolutionSource.AI);
      expect(fallback.reason).assertEqual('ai_fallback_default');
      expect(fallback.confidence).assertEqual(0.4);
    });

    it('weak_local_hit_uses_advanced_keyword_rules_reason', 0, () => {
      const local = new LocalMedicalDocumentTypeResolver();
      // 弱特征：分数落在 10–29，仍返回 localRules，reason 与 iOS 一致。
      const hit = local.resolveAutoOnly('检验报告 结果');
      expect(hit !== undefined).assertTrue();
      expect(hit!.source).assertEqual(MedicalDocumentTypeResolutionSource.LOCAL_RULES);
      expect(hit!.reason).assertEqual('advanced_keyword_rules');
      expect(hit!.confidence < 0.5).assertTrue();
    });

    it('decoder_missing_confidence_defaults_to_0_5_and_rejects_unknown_kind', 0, () => {
      const decoder = new MedicalDocumentTypeResponseDecoder();
      const decoded = decoder.decode('{"kind":"prescription","reason":"rx_title"}');
      expect(decoded !== undefined).assertTrue();
      expect(decoded!.kind).assertEqual(MedicalDocumentKind.PRESCRIPTION);
      expect(decoded!.confidence).assertEqual(0.5);

      const fenced = decoder.decode('```json\n{"kind":"medicine_box","confidence":1.5}\n```');
      expect(fenced !== undefined).assertTrue();
      expect(fenced!.confidence).assertEqual(1);

      const unknown = decoder.decode('{"kind":"invented_type","confidence":0.9}');
      expect(unknown === undefined).assertTrue();
    });

    it('low_confidence_requires_manual_confirmation', 0, () => {
      const weak = MedicalDocumentTypeResolutionFactory.make(
        MedicalDocumentKind.MEDICAL_REPORT,
        MedicalDocumentTypeResolutionSource.LOCAL_RULES,
        'advanced_keyword_rules',
        0.35
      );
      expect(MedicalDocumentUploadViewModel.shouldRequireManualTypeConfirmation(weak)).assertTrue();

      const fallback = MedicalDocumentTypeResolutionFactory.aiFallbackDefault();
      expect(MedicalDocumentUploadViewModel.shouldRequireManualTypeConfirmation(fallback)).assertTrue();

      const strong = MedicalDocumentTypeResolutionFactory.make(
        MedicalDocumentKind.HEALTH_EXAM_REPORT,
        MedicalDocumentTypeResolutionSource.LOCAL_RULES,
        'advanced_keyword_rules',
        0.72
      );
      expect(MedicalDocumentUploadViewModel.shouldRequireManualTypeConfirmation(strong)).assertFalse();

      const manual = MedicalDocumentTypeResolutionFactory.manual(MedicalDocumentKind.PRESCRIPTION);
      expect(MedicalDocumentUploadViewModel.shouldRequireManualTypeConfirmation(manual)).assertFalse();
    });

    it('manual_then_local_then_ai_fallback_chain', 0, async () => {
      const resolver = new DefaultMedicalDocumentTypeResolver(new LocalMedicalDocumentTypeResolver());
      const manual = await resolver.resolve(
        MedicalDocumentKind.CASE_DOCUMENT,
        '无关文本'
      );
      expect(manual.source).assertEqual(MedicalDocumentTypeResolutionSource.MANUAL);
      expect(manual.reason).assertEqual('manual_selected');

      const local = await resolver.resolve(
        MedicalDocumentKind.AUTO,
        '健康体检 体检报告 体检中心 总检结论 总结建议 一般检查'
      );
      expect(local.source).assertEqual(MedicalDocumentTypeResolutionSource.LOCAL_RULES);
      expect(local.kind).assertEqual(MedicalDocumentKind.HEALTH_EXAM_REPORT);

      const fallback = await resolver.resolve(
        MedicalDocumentKind.AUTO,
        '一段无法分类的普通说明文字 abc xyz'
      );
      expect(fallback.reason).assertEqual('ai_fallback_default');
      expect(fallback.confidence).assertEqual(0.4);
    });

    it('normalize_confidence_matches_ios_bands', 0, () => {
      expect(LocalMedicalDocumentTypeResolver.normalizeConfidence(10)).assertEqual(0.35);
      expect(LocalMedicalDocumentTypeResolver.normalizeConfidence(30)).assertEqual(0.45);
      expect(LocalMedicalDocumentTypeResolver.normalizeConfidence(40)).assertEqual(0.5);
      expect(LocalMedicalDocumentTypeResolver.normalizeConfidence(60)).assertEqual(0.7);
      expect(LocalMedicalDocumentTypeResolver.normalizeConfidence(80)).assertEqual(0.9);
    });

    it('resolution_model_keeps_source_reason_fields', 0, () => {
      const resolution: MedicalDocumentTypeResolution =
        MedicalDocumentTypeResolutionFactory.aiFallbackDefault();
      expect(resolution.sourceLabel.length > 0).assertTrue();
      expect(resolution.kindLabel.length > 0).assertTrue();
      expect(resolution.reason).assertEqual('ai_fallback_default');
    });
  });
}
