import { AIRuntimeCancellationToken } from '../../../../Core/AI/Runtime/AIRuntimeCancellation';
import { Logger } from '../../../../Foundation/Logging/Logger';
import { LogFields } from '../../../../Foundation/Logging/LogEvent';
import { LogModule } from '../../../../Foundation/Logging/LogModule';
import { MedicalAttachmentInput } from '../../Home/Presentation/MedicalLists/MedicalDocumentAttachmentUploader';
import { MedicalDocumentKind } from '../Domain/MedicalDocumentKind';
import { MedicalDocumentOCRResult } from '../Domain/MedicalDocumentOCRResult';
import {
  MedicalDocumentStructuredExtractionError
} from '../Domain/MedicalDocumentStructuredExtractionError';
import {
  MedicalDocumentStructuredExtractionRequest
} from '../Domain/MedicalDocumentStructuredExtractionRequest';
import {
  MedicalDocumentTypeResolution,
  MedicalDocumentTypedExtractionOutput
} from '../Domain/MedicalDocumentTypedModels';
import { MedicalDocumentOCRRequest } from '../Domain/MedicalDocumentOCRModels';
import {
  MedicalDocumentExtractionErrorNormalizer
} from '../Infrastructure/MedicalDocumentExtractionErrorNormalizer';
import {
  MedicalDocumentStructuredJSONDecoder
} from '../Infrastructure/MedicalDocumentStructuredJSONDecoder';
import {
  MedicalDocumentStructuredPromptFactory
} from '../Infrastructure/MedicalDocumentStructuredPromptFactory';
import {
  MedicalDocumentStructuredRuntimeGenerating
} from '../Infrastructure/MedicalDocumentStructuredRuntimeClient';
import {
  MedicalDocumentTypedResultMapper
} from '../Infrastructure/MedicalDocumentTypedResultMapper';
import { MedicalDocumentOCRUseCase } from './MedicalDocumentOCRUseCase';
import { ResolveMedicalDocumentTypeUseCase } from './ResolveMedicalDocumentTypeUseCase';

/**
 * 抽取统一入口：OCR / 类型识别 / 结构化抽取。
 * 对齐 iOS ExtractTypedMedicalDocumentUseCase + DefaultTypedMedicalDocumentExtractor。
 */
export class ExtractTypedMedicalDocumentUseCase {
  private readonly ocrUseCase: MedicalDocumentOCRUseCase;
  private readonly resolveTypeUseCase: ResolveMedicalDocumentTypeUseCase;
  private readonly promptFactory?: MedicalDocumentStructuredPromptFactory;
  private readonly runtimeClient?: MedicalDocumentStructuredRuntimeGenerating;
  private readonly decoder: MedicalDocumentStructuredJSONDecoder;
  private readonly errorNormalizer: MedicalDocumentExtractionErrorNormalizer;

  constructor(
    ocrUseCase: MedicalDocumentOCRUseCase,
    resolveTypeUseCase: ResolveMedicalDocumentTypeUseCase,
    promptFactory?: MedicalDocumentStructuredPromptFactory,
    runtimeClient?: MedicalDocumentStructuredRuntimeGenerating,
    decoder: MedicalDocumentStructuredJSONDecoder = new MedicalDocumentStructuredJSONDecoder(),
    errorNormalizer: MedicalDocumentExtractionErrorNormalizer =
      new MedicalDocumentExtractionErrorNormalizer()
  ) {
    this.ocrUseCase = ocrUseCase;
    this.resolveTypeUseCase = resolveTypeUseCase;
    this.promptFactory = promptFactory;
    this.runtimeClient = runtimeClient;
    this.decoder = decoder;
    this.errorNormalizer = errorNormalizer;
  }

  get isExtractionReady(): boolean {
    return this.promptFactory !== undefined && this.runtimeClient !== undefined;
  }

  async mergeOCRText(
    files: MedicalAttachmentInput[],
    reRecognizeAll: boolean = false
  ): Promise<MedicalDocumentOCRResult> {
    const request = new MedicalDocumentOCRRequest();
    request.files = files;
    request.reRecognizeAll = reRecognizeAll;
    return await this.ocrUseCase.execute(request);
  }

  async resolveType(
    selectedKind: MedicalDocumentKind,
    mergedOCRText: string
  ): Promise<MedicalDocumentTypeResolution> {
    return await this.resolveTypeUseCase.execute(selectedKind, mergedOCRText);
  }

  /**
   * 结构化抽取主路径。未装配 Runtime 时抛 EXTRACT_PENDING（兼容旧测试）。
   */
  async extractStructured(
    request: MedicalDocumentStructuredExtractionRequest,
    cancellationToken?: AIRuntimeCancellationToken
  ): Promise<MedicalDocumentTypedExtractionOutput> {
    if (this.promptFactory === undefined || this.runtimeClient === undefined) {
      throw new Error('EXTRACT_PENDING');
    }

    const kind = request.typeResolution?.kind ?? request.selectedKind;
    const resolvedKind = kind === MedicalDocumentKind.AUTO ?
      MedicalDocumentKind.MEDICAL_REPORT : kind;

    this.log('medical.upload.extract.start',
      `kind=${resolvedKind};ocrLen=${request.mergedOCRText.length};session=${request.uploadSessionId}`);

    if (request.mergedOCRText.trim().length === 0) {
      throw MedicalDocumentStructuredExtractionError.emptyInput(resolvedKind);
    }

    try {
      cancellationToken?.checkCancellation();
      const bundle = this.promptFactory.build(request);
      this.log('medical.upload.extract.prompt_ready',
        `scenario=${bundle.scenario};promptLen=${bundle.prompt.length}`);

      const runtime = await this.runtimeClient.generate(
        bundle,
        cancellationToken,
        request.preferredModelName
      );
      cancellationToken?.checkCancellation();

      if (runtime.errorCode.length > 0) {
        throw this.errorNormalizer.normalizeRuntime(resolvedKind, runtime);
      }
      if (runtime.text.trim().length === 0) {
        throw this.errorNormalizer.normalizeEmptyOutput(resolvedKind, runtime.text);
      }

      const decoded = this.decoder.decode(runtime.text);
      if (!decoded.ok) {
        this.log('medical.upload.extract.decode_failed',
          `field=${decoded.fieldPath};msg=${decoded.errorMessage}`);
        throw this.errorNormalizer.normalizeDecode(resolvedKind, decoded, runtime.text);
      }

      this.log('medical.upload.extract.decode_success',
        `jsonLen=${decoded.canonicalJSON.length};isArray=${decoded.isArray}`);
      return MedicalDocumentTypedResultMapper.map(request, resolvedKind, decoded, runtime.text);
    } catch (error) {
      if (error instanceof Error && error.name === 'AIRuntimeCancelledError') {
        throw new MedicalDocumentStructuredExtractionError('cancelled', '已取消抽取', '', false);
      }
      if (error instanceof MedicalDocumentStructuredExtractionError) {
        if (error.feedback !== undefined) {
          this.log('medical.upload.extract.retry_feedback',
            `code=${error.code};field=${error.fieldPath};suggestion=${error.feedback.suggestion ?? ''}`);
        }
        this.log('medical.upload.extract.error_presented',
          `code=${error.code};retryable=${error.retryable}`);
        throw error;
      }
      throw this.errorNormalizer.normalizeUnknown(resolvedKind, error as Object | Error);
    }
  }

  private log(event: string, detail: string): void {
    const fields = new LogFields();
    fields.operation = 'medical_document_extract';
    fields.detail = detail;
    Logger.info(event, LogModule.HOME, fields);
  }
}
