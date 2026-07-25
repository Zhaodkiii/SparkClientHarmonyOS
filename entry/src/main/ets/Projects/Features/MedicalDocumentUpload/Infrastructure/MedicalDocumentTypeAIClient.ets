import {
  AIRuntimeMessage,
  AIRuntimeReasoningOptions,
  AIRuntimeTextRequest,
  AIScenario
} from '../../../../Core/AI/Domain/AIConfigModels';
import { AIRuntimeCancellationToken } from '../../../../Core/AI/Runtime/AIRuntimeCancellation';
import { AIRuntimeService } from '../../../../Core/AI/Runtime/AIRuntimeService';
import { PromptLocalizer } from '../../../../Core/AI/Runtime/PromptLocalizer';
import { Logger } from '../../../../Foundation/Logging/Logger';
import { LogFields } from '../../../../Foundation/Logging/LogEvent';
import { LogModule } from '../../../../Foundation/Logging/LogModule';
import { MedicalDocumentTypeResolution } from '../Domain/MedicalDocumentTypedModels';
import { MedicalDocumentTypeResponseDecoder } from './MedicalDocumentTypeResponseDecoder';

/**
 * 医疗文档类型 AI 客户端：复用 Core Prompt + AIRuntime，不另起 Prompt 常量。
 */
export class MedicalDocumentTypeAIClient {
  private readonly runtimeService: AIRuntimeService;
  private readonly promptLocalizer: PromptLocalizer;
  private readonly decoder: MedicalDocumentTypeResponseDecoder;
  private readonly accountIdProvider: () => number | undefined;

  constructor(
    runtimeService: AIRuntimeService,
    accountIdProvider: () => number | undefined,
    promptLocalizer: PromptLocalizer = new PromptLocalizer(),
    decoder: MedicalDocumentTypeResponseDecoder = new MedicalDocumentTypeResponseDecoder()
  ) {
    this.runtimeService = runtimeService;
    this.accountIdProvider = accountIdProvider;
    this.promptLocalizer = promptLocalizer;
    this.decoder = decoder;
  }

  async recognize(
    mergedOCRText: string,
    cancellationToken?: AIRuntimeCancellationToken
  ): Promise<MedicalDocumentTypeResolution | undefined> {
    const accountId = this.accountIdProvider();
    if (accountId === undefined || accountId <= 0) {
      this.log('medical.upload.type.ai_skip', 'account_missing');
      return undefined;
    }
    if (mergedOCRText.trim().length === 0) {
      return undefined;
    }
    cancellationToken?.checkCancellation();

    const prompt = this.promptLocalizer.medicalDocumentTypeRecognitionPrompt(mergedOCRText);
    const request = new AIRuntimeTextRequest();
    request.requestId = `med_type_${Date.now()}`;
    request.accountId = accountId;
    request.scenario = AIScenario.MEDICAL_DOCUMENT_TYPE_RECOGNITION;
    request.stream = false;
    request.toolChoice = 'none';
    request.tools = [];
    request.reasoning = AIRuntimeReasoningOptions.disabled();
    request.cancellationToken = cancellationToken;

    const user = new AIRuntimeMessage();
    user.role = 'user';
    user.content = prompt;
    request.messages = [user];

    try {
      const response = await this.runtimeService.generateText(request);
      cancellationToken?.checkCancellation();
      if (response.errorCode !== undefined && response.errorCode.length > 0) {
        this.log('medical.upload.type.ai_failed',
          `code=${response.errorCode};msg=${response.errorMessage ?? ''}`);
        return undefined;
      }
      const text = (response.text ?? '').trim();
      if (text.length === 0) {
        this.log('medical.upload.type.ai_empty', 'empty_text');
        return undefined;
      }
      const decoded = this.decoder.decode(text);
      if (decoded === undefined) {
        this.log('medical.upload.type.ai_decode_failed', `textLen=${text.length}`);
      } else {
        this.log('medical.upload.type.ai_ok',
          `kind=${decoded.kind};confidence=${decoded.confidence};reason=${decoded.reason}`);
      }
      return decoded;
    } catch (error) {
      if (error instanceof Error && error.name === 'AIRuntimeCancelledError') {
        throw error;
      }
      this.log('medical.upload.type.ai_exception',
        error instanceof Error ? error.message : `${error}`);
      return undefined;
    }
  }

  private log(event: string, detail: string): void {
    const fields = new LogFields();
    fields.operation = 'medical_document_type_ai';
    fields.detail = detail;
    Logger.info(event, LogModule.HOME, fields);
  }
}
