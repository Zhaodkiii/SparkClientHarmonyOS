import { describe, it, expect } from '@ohos/hypium';
import { AIScenario } from '../../../main/ets/Core/AI/Domain/AIConfigModels';
import { AIRuntimeCancellationToken } from '../../../main/ets/Core/AI/Runtime/AIRuntimeCancellation';
import { ExtractTypedMedicalDocumentUseCase } from '../../../main/ets/Projects/Features/MedicalDocumentUpload/Application/ExtractTypedMedicalDocumentUseCase';
import { MedicalDocumentOCRUseCase } from '../../../main/ets/Projects/Features/MedicalDocumentUpload/Application/MedicalDocumentOCRUseCase';
import { ResolveMedicalDocumentTypeUseCase } from '../../../main/ets/Projects/Features/MedicalDocumentUpload/Application/ResolveMedicalDocumentTypeUseCase';
import { MedicalDocumentKind } from '../../../main/ets/Projects/Features/MedicalDocumentUpload/Domain/MedicalDocumentKind';
import { MedicalExtractionPromptSource } from '../../../main/ets/Projects/Features/MedicalDocumentUpload/Domain/MedicalExtractionInputSource';
import {
  MedicalDocumentStructuredExtractionError
} from '../../../main/ets/Projects/Features/MedicalDocumentUpload/Domain/MedicalDocumentStructuredExtractionError';
import {
  MedicalDocumentStructuredExtractionRequest
} from '../../../main/ets/Projects/Features/MedicalDocumentUpload/Domain/MedicalDocumentStructuredExtractionRequest';
import {
  MedicalDocumentTypeResolution
} from '../../../main/ets/Projects/Features/MedicalDocumentUpload/Domain/MedicalDocumentTypedModels';
import {
  MedicalDocumentTypeResolutionSource
} from '../../../main/ets/Projects/Features/MedicalDocumentUpload/Domain/MedicalDocumentTypeResolverProtocol';
import {
  MedicalDocumentExtractionErrorNormalizer
} from '../../../main/ets/Projects/Features/MedicalDocumentUpload/Infrastructure/MedicalDocumentExtractionErrorNormalizer';
import {
  MedicalDocumentStructuredJSONDecoder
} from '../../../main/ets/Projects/Features/MedicalDocumentUpload/Infrastructure/MedicalDocumentStructuredJSONDecoder';
import {
  MedicalDocumentStructuredPromptBundle,
  MedicalDocumentStructuredPromptFactory
} from '../../../main/ets/Projects/Features/MedicalDocumentUpload/Infrastructure/MedicalDocumentStructuredPromptFactory';
import {
  MedicalDocumentStructuredRuntimeGenerating,
  MedicalDocumentStructuredRuntimeResult
} from '../../../main/ets/Projects/Features/MedicalDocumentUpload/Infrastructure/MedicalDocumentStructuredRuntimeClient';
import {
  MedicalDocumentTypedResultMapper
} from '../../../main/ets/Projects/Features/MedicalDocumentUpload/Infrastructure/MedicalDocumentTypedResultMapper';

/** 测试用 Runtime：固定返回 JSON / 错误。 */
class StubRuntimeClient implements MedicalDocumentStructuredRuntimeGenerating {
  next: MedicalDocumentStructuredRuntimeResult = new MedicalDocumentStructuredRuntimeResult();

  async generate(
    _bundle: MedicalDocumentStructuredPromptBundle,
    _cancellationToken?: AIRuntimeCancellationToken,
    _preferredModelName?: string
  ): Promise<MedicalDocumentStructuredRuntimeResult> {
    return this.next;
  }
}

export default function medicalDocumentUpload0006Test() {
  describe('HOS_MED_UPLOAD_0006', () => {
    it('prompt_factory_switches_scenario_by_kind', 0, () => {
      const factory = new MedicalDocumentStructuredPromptFactory();
      const kinds: Array<[MedicalDocumentKind, string]> = [
        [MedicalDocumentKind.CASE_DOCUMENT, AIScenario.MEDICAL_CASE_EXTRACTION],
        [MedicalDocumentKind.HEALTH_EXAM_REPORT, AIScenario.HEALTH_EXAM_EXTRACTION],
        [MedicalDocumentKind.MEDICAL_REPORT, AIScenario.MEDICAL_REPORT_EXTRACTION],
        [MedicalDocumentKind.PRESCRIPTION, AIScenario.PRESCRIPTION_EXTRACTION],
        [MedicalDocumentKind.MEDICATION_PLAN, AIScenario.MEDICATION_EXTRACTION],
        [MedicalDocumentKind.MEDICINE_BOX, AIScenario.MEDICINE_BOX_EXTRACTION]
      ];
      for (let i = 0; i < kinds.length; i++) {
        const request = new MedicalDocumentStructuredExtractionRequest();
        request.selectedKind = kinds[i][0];
        request.mergedOCRText = '样本 OCR 文本 主诉 诊断';
        request.promptSource = MedicalExtractionPromptSource.OCR_TEXT;
        const bundle = factory.build(request);
        expect(bundle.scenario).assertEqual(kinds[i][1]);
        expect(bundle.prompt.length > 0).assertTrue();
      }
    });

    it('decoder_accepts_object_and_fenced_json', 0, () => {
      const decoder = new MedicalDocumentStructuredJSONDecoder();
      const ok = decoder.decode('```json\n{"title":"体检报告","summary":"大致正常"}\n```');
      expect(ok.ok).assertTrue();
      expect(ok.isArray).assertFalse();
      expect(ok.objectFields.get('title')).assertEqual('体检报告');

      const arr = decoder.decode('[{"name":"阿莫西林"},{"name":"布洛芬"}]');
      expect(arr.ok).assertTrue();
      expect(arr.isArray).assertTrue();

      const bad = decoder.decode('不是 JSON');
      expect(bad.ok).assertFalse();
      expect(bad.fieldPath).assertEqual('root');
    });

    it('error_normalizer_builds_retry_feedback', 0, () => {
      const normalizer = new MedicalDocumentExtractionErrorNormalizer();
      const decode = new MedicalDocumentStructuredJSONDecoder().decode('broken');
      const err = normalizer.normalizeDecode(
        MedicalDocumentKind.PRESCRIPTION,
        decode,
        'broken output preview'
      );
      expect(err.code).assertEqual('invalid_json');
      expect(err.retryable).assertTrue();
      expect(err.feedback !== undefined).assertTrue();
      expect(err.feedback!.kind).assertEqual(MedicalDocumentKind.PRESCRIPTION);
      expect((err.feedback!.aiOutputPreview ?? '').length > 0).assertTrue();

      const runtime = new MedicalDocumentStructuredRuntimeResult();
      runtime.errorCode = 'timeout';
      runtime.errorMessage = 'timeout';
      const runtimeErr = normalizer.normalizeRuntime(MedicalDocumentKind.MEDICAL_REPORT, runtime);
      expect(runtimeErr.code).assertEqual('runtime_failed');
      expect(runtimeErr.retryable).assertTrue();
    });

    it('typed_mapper_fills_payload_and_preview', 0, () => {
      const request = new MedicalDocumentStructuredExtractionRequest();
      request.memberId = 12;
      request.uploadSessionId = 'sess_1';
      request.mergedOCRText = '体检报告 OCR';
      request.promptSource = MedicalExtractionPromptSource.OCR_TEXT;
      const resolution = new MedicalDocumentTypeResolution();
      resolution.kind = MedicalDocumentKind.HEALTH_EXAM_REPORT;
      resolution.kindLabel = '体检报告';
      resolution.source = MedicalDocumentTypeResolutionSource.LOCAL_RULES;
      resolution.confidence = 0.9;
      request.typeResolution = resolution;

      const decode = new MedicalDocumentStructuredJSONDecoder().decode(
        '{"title":"年度体检","summary":"血脂偏高","diagnosis":"高脂血症"}'
      );
      const output = MedicalDocumentTypedResultMapper.map(
        request,
        MedicalDocumentKind.HEALTH_EXAM_REPORT,
        decode,
        '{"title":"年度体检"}'
      );
      expect(output.typedResult.title).assertEqual('年度体检');
      expect(output.typedResult.summary).assertEqual('血脂偏高');
      expect(output.extractedJSON.indexOf('年度体检') >= 0).assertTrue();
      expect(output.payloadPreview.indexOf('"kind"') >= 0).assertTrue();
      expect(output.envelope.memberID).assertEqual(12);
    });

    it('extract_use_case_throws_pending_without_runtime', 0, async () => {
      const useCase = new ExtractTypedMedicalDocumentUseCase(
        undefined as Object as MedicalDocumentOCRUseCase,
        undefined as Object as ResolveMedicalDocumentTypeUseCase
      );
      expect(useCase.isExtractionReady).assertFalse();
      const request = new MedicalDocumentStructuredExtractionRequest();
      request.mergedOCRText = '有 OCR';
      request.selectedKind = MedicalDocumentKind.MEDICAL_REPORT;
      let message = '';
      try {
        await useCase.extractStructured(request);
      } catch (e) {
        message = e instanceof Error ? e.message : `${e}`;
      }
      expect(message).assertEqual('EXTRACT_PENDING');
    });

    it('extract_use_case_rejects_empty_ocr_and_accepts_json', 0, async () => {
      const runtime = new StubRuntimeClient();
      const useCase = new ExtractTypedMedicalDocumentUseCase(
        undefined as Object as MedicalDocumentOCRUseCase,
        undefined as Object as ResolveMedicalDocumentTypeUseCase,
        new MedicalDocumentStructuredPromptFactory(),
        runtime
      );
      expect(useCase.isExtractionReady).assertTrue();

      const emptyReq = new MedicalDocumentStructuredExtractionRequest();
      emptyReq.mergedOCRText = '   ';
      emptyReq.selectedKind = MedicalDocumentKind.PRESCRIPTION;
      let emptyCode = '';
      try {
        await useCase.extractStructured(emptyReq);
      } catch (e) {
        if (e instanceof MedicalDocumentStructuredExtractionError) {
          emptyCode = e.code;
        }
      }
      expect(emptyCode).assertEqual('empty_input');

      runtime.next = new MedicalDocumentStructuredRuntimeResult();
      runtime.next.text = '{"title":"处方","summary":"阿莫西林"}';
      const okReq = new MedicalDocumentStructuredExtractionRequest();
      okReq.mergedOCRText = '处方笺 药品名称 用法用量';
      okReq.selectedKind = MedicalDocumentKind.PRESCRIPTION;
      const output = await useCase.extractStructured(okReq);
      expect(output.typedResult.title).assertEqual('处方');
      expect(output.extractedJSON.indexOf('阿莫西林') >= 0).assertTrue();
    });
  });
}
