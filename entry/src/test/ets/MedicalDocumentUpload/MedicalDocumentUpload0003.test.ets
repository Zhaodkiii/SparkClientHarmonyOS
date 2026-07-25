import { describe, it, expect } from '@ohos/hypium';
import { MedicalDocumentKind } from '../../../main/ets/Projects/Features/MedicalDocumentUpload/Domain/MedicalDocumentKind';
import {
  MedicalDocumentTypeResolutionFactory,
  MedicalDocumentTypeResolutionSource
} from '../../../main/ets/Projects/Features/MedicalDocumentUpload/Domain/MedicalDocumentTypeResolverProtocol';
import { DefaultMedicalDocumentTypeResolver } from '../../../main/ets/Projects/Features/MedicalDocumentUpload/Infrastructure/DefaultMedicalDocumentTypeResolver';
import { LocalMedicalDocumentTypeResolver } from '../../../main/ets/Projects/Features/MedicalDocumentUpload/Infrastructure/LocalMedicalDocumentTypeResolver';
import { MedicalDocumentTypeResponseDecoder } from '../../../main/ets/Projects/Features/MedicalDocumentUpload/Infrastructure/MedicalDocumentTypeResponseDecoder';
import { ResolveMedicalDocumentTypeUseCase } from '../../../main/ets/Projects/Features/MedicalDocumentUpload/Application/ResolveMedicalDocumentTypeUseCase';

export default function medicalDocumentUpload0003Test() {
  describe('HOS_MED_UPLOAD_0003', () => {
    it('manual_selection_wins_over_ocr_text', 0, async () => {
      const useCase = new ResolveMedicalDocumentTypeUseCase(
        new DefaultMedicalDocumentTypeResolver(new LocalMedicalDocumentTypeResolver())
      );
      const resolution = await useCase.execute(
        MedicalDocumentKind.PRESCRIPTION,
        '这是一份体检报告 总检结论 体检中心'
      );
      expect(resolution.kind).assertEqual(MedicalDocumentKind.PRESCRIPTION);
      expect(resolution.source).assertEqual(MedicalDocumentTypeResolutionSource.MANUAL);
      expect(resolution.confidence).assertEqual(1);
      expect(resolution.reason).assertEqual('manual_selected');
    });

    it('local_rules_match_six_kinds', 0, () => {
      const local = new LocalMedicalDocumentTypeResolver();
      const cases: Array<[MedicalDocumentKind, string]> = [
        [MedicalDocumentKind.CASE_DOCUMENT, '门诊病历 主诉 现病史 既往史 体格检查 初步诊断'],
        [MedicalDocumentKind.HEALTH_EXAM_REPORT, '健康体检 体检报告 体检中心 总检结论 总结建议 一般检查'],
        [MedicalDocumentKind.MEDICAL_REPORT, '检验报告单 检查所见 诊断意见 结果 参考区间 单位 mmol/L'],
        [MedicalDocumentKind.PRESCRIPTION, '处方笺 处方号 用法 用量 药品名称 每日'],
        [MedicalDocumentKind.MEDICATION_PLAN, '用药计划 服药计划 开始日期 提醒时间 每日 疗程'],
        [MedicalDocumentKind.MEDICINE_BOX, '药盒 国药准字 生产批号 有效期至 规格 说明书']
      ];
      for (let i = 0; i < cases.length; i++) {
        const hit = local.resolveAutoOnly(cases[i][1]);
        expect(hit !== undefined).assertTrue();
        expect(hit!.kind).assertEqual(cases[i][0]);
        expect(hit!.source).assertEqual(MedicalDocumentTypeResolutionSource.LOCAL_RULES);
      }
    });

    it('classifier_prefers_case_over_report_on_history_structure', 0, () => {
      const local = new LocalMedicalDocumentTypeResolver();
      const hit = local.resolveAutoOnly(
        '门诊病历 主诉：咳嗽 现病史：三天 既往史无 体格检查正常 初步诊断 处理意见'
      );
      expect(hit !== undefined).assertTrue();
      expect(hit!.kind).assertEqual(MedicalDocumentKind.CASE_DOCUMENT);
    });

    it('classifier_mutual_exclusion_prescription_vs_box', 0, () => {
      const local = new LocalMedicalDocumentTypeResolver();
      const rx = local.resolveAutoOnly('处方笺 处方号 用法 用量 药品名称 医师签名 药师签名');
      expect(rx !== undefined).assertTrue();
      expect(rx!.kind).assertEqual(MedicalDocumentKind.PRESCRIPTION);

      const box = local.resolveAutoOnly('药盒 国药准字 批准文号 生产批号 有效期至 适应症 禁忌');
      expect(box !== undefined).assertTrue();
      expect(box!.kind).assertEqual(MedicalDocumentKind.MEDICINE_BOX);
    });

    it('decoder_accepts_fenced_json_and_whitelist', 0, () => {
      const decoder = new MedicalDocumentTypeResponseDecoder();
      const raw = '```json\n{"kind":"health_exam_report","confidence":0.82,"reason":"title_match"}\n```';
      const decoded = decoder.decode(raw);
      expect(decoded !== undefined).assertTrue();
      expect(decoded!.kind).assertEqual(MedicalDocumentKind.HEALTH_EXAM_REPORT);
      expect(decoded!.source).assertEqual(MedicalDocumentTypeResolutionSource.AI);
      expect(decoded!.reason).assertEqual('title_match');

      const unknown = decoder.decode('{"kind":"unknown_type","confidence":0.9}');
      expect(unknown === undefined).assertTrue();
    });

    it('default_resolver_falls_back_to_ai_default_without_client', 0, async () => {
      const resolver = new DefaultMedicalDocumentTypeResolver(new LocalMedicalDocumentTypeResolver());
      const resolution = await resolver.resolve(
        MedicalDocumentKind.AUTO,
        '一段无法分类的普通说明文字 abc xyz'
      );
      expect(resolution.kind).assertEqual(MedicalDocumentKind.MEDICAL_REPORT);
      expect(resolution.source).assertEqual(MedicalDocumentTypeResolutionSource.AI);
      expect(resolution.reason).assertEqual('ai_fallback_default');
      expect(resolution.confidence < 0.5).assertTrue();
    });

    it('empty_ocr_text_throws', 0, async () => {
      const resolver = new DefaultMedicalDocumentTypeResolver();
      let threw = false;
      try {
        await resolver.resolve(MedicalDocumentKind.AUTO, '   ');
      } catch (_e) {
        threw = true;
      }
      expect(threw).assertTrue();
    });

    it('factory_ai_fallback_default_shape', 0, () => {
      const fallback = MedicalDocumentTypeResolutionFactory.aiFallbackDefault();
      expect(fallback.source).assertEqual(MedicalDocumentTypeResolutionSource.AI);
      expect(fallback.reason).assertEqual('ai_fallback_default');
      expect(fallback.kind).assertEqual(MedicalDocumentKind.MEDICAL_REPORT);
    });
  });
}
