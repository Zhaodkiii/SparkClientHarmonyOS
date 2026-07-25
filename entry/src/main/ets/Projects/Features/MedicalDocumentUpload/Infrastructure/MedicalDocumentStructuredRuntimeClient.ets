import {
  AIRuntimeMessage,
  AIRuntimeReasoningOptions,
  AIRuntimeTextRequest
} from '../../../../Core/AI/Domain/AIConfigModels';
import { AIRuntimeCancellationToken } from '../../../../Core/AI/Runtime/AIRuntimeCancellation';
import { AIRuntimeService } from '../../../../Core/AI/Runtime/AIRuntimeService';
import { Logger } from '../../../../Foundation/Logging/Logger';
import { LogFields } from '../../../../Foundation/Logging/LogEvent';
import { LogModule } from '../../../../Foundation/Logging/LogModule';
import { MedicalDocumentStructuredPromptBundle } from './MedicalDocumentStructuredPromptFactory';

/** Runtime 抽取原始结果。 */
export class MedicalDocumentStructuredRuntimeResult {
  text: string = '';
  requestId: string = '';
  errorCode: string = '';
  errorMessage: string = '';
}

/** 抽取 Runtime 协议：便于单测 stub。 */
export interface MedicalDocumentStructuredRuntimeGenerating {
  generate(
    bundle: MedicalDocumentStructuredPromptBundle,
    cancellationToken?: AIRuntimeCancellationToken,
    preferredModelName?: string
  ): Promise<MedicalDocumentStructuredRuntimeResult>;
}

/**
 * 医疗结构化抽取 Runtime 客户端：直连 AIRuntimeService，禁止经 ChatOrchestrator。
 */
export class MedicalDocumentStructuredRuntimeClient implements MedicalDocumentStructuredRuntimeGenerating {
  private readonly runtimeService: AIRuntimeService;
  private readonly accountIdProvider: () => number | undefined;

  constructor(
    runtimeService: AIRuntimeService,
    accountIdProvider: () => number | undefined
  ) {
    this.runtimeService = runtimeService;
    this.accountIdProvider = accountIdProvider;
  }

  async generate(
    bundle: MedicalDocumentStructuredPromptBundle,
    cancellationToken?: AIRuntimeCancellationToken,
    preferredModelName: string = ''
  ): Promise<MedicalDocumentStructuredRuntimeResult> {
    const result = new MedicalDocumentStructuredRuntimeResult();
    const accountId = this.accountIdProvider();
    if (accountId === undefined || accountId <= 0) {
      result.errorCode = 'account_missing';
      result.errorMessage = '请先登录后再抽取';
      return result;
    }
    cancellationToken?.checkCancellation();

    const request = new AIRuntimeTextRequest();
    request.requestId = `med_extract_${Date.now()}`;
    request.accountId = accountId;
    request.scenario = bundle.scenario;
    request.stream = false;
    request.toolChoice = 'none';
    request.tools = [];
    request.reasoning = AIRuntimeReasoningOptions.disabled();
    request.cancellationToken = cancellationToken;
    if (preferredModelName.length > 0) {
      request.preferredModelName = preferredModelName;
    }

    const user = new AIRuntimeMessage();
    user.role = 'user';
    user.content = bundle.prompt;
    request.messages = [user];

    this.log('medical.upload.extract.runtime_start',
      `scenario=${bundle.scenario};kind=${bundle.kind};promptLen=${bundle.prompt.length}`);

    try {
      const response = await this.runtimeService.generateText(request);
      cancellationToken?.checkCancellation();
      result.requestId = response.requestId.length > 0 ? response.requestId : request.requestId;
      if (response.errorCode !== undefined && response.errorCode.length > 0) {
        result.errorCode = response.errorCode;
        result.errorMessage = response.errorMessage ?? 'AI 抽取失败';
        this.log('medical.upload.extract.runtime_failed',
          `code=${result.errorCode};msg=${result.errorMessage}`);
        return result;
      }
      result.text = (response.text ?? '').trim();
      this.log('medical.upload.extract.runtime_success',
        `textLen=${result.text.length};requestId=${result.requestId}`);
      return result;
    } catch (error) {
      if (error instanceof Error && error.name === 'AIRuntimeCancelledError') {
        throw error;
      }
      result.errorCode = 'runtime_exception';
      result.errorMessage = error instanceof Error ? error.message : `${error}`;
      this.log('medical.upload.extract.runtime_exception', result.errorMessage);
      return result;
    }
  }

  private log(event: string, detail: string): void {
    const fields = new LogFields();
    fields.operation = 'medical_document_extract_runtime';
    fields.detail = detail;
    Logger.info(event, LogModule.HOME, fields);
  }
}
