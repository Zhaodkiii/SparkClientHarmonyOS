import {
  AIRuntimeEvent,
  AIRuntimeMessage,
  AIRuntimeTextRequest,
  AIRuntimeResponse,
  AIScenario
} from '../Domain/AIConfigModels';
import { AIRuntimeService } from './AIRuntimeService';
import { AIRuntimeCancellationToken } from './AIRuntimeCancellation';

/**
 * 非 chat 场景直连 Runtime（对齐 iOS Extractor 直连 generateTextStream）。
 * 禁止经 ChatOrchestrator。
 */
export class StructuredRuntimeClient {
  private readonly runtime: AIRuntimeService;

  constructor(runtime: AIRuntimeService) {
    this.runtime = runtime;
  }

  async generateStructuredText(
    accountId: number,
    scenario: string,
    systemPrompt: string,
    userPrompt: string,
    cancellationToken?: AIRuntimeCancellationToken,
    preferredModelName?: string
  ): Promise<AIRuntimeResponse> {
    if (!AIScenario.isKnown(scenario)) {
      const fail = new AIRuntimeResponse();
      fail.errorCode = 'invalidScenario';
      fail.errorMessage = `unknown scenario: ${scenario}`;
      fail.finishReason = 'error';
      fail.requestId = `struct_${Date.now()}`;
      fail.createdAt = new Date().toISOString();
      return fail;
    }
    const req = new AIRuntimeTextRequest();
    req.requestId = `struct_${Date.now()}`;
    req.accountId = accountId;
    req.scenario = scenario;
    req.stream = true;
    req.toolChoice = 'none';
    req.tools = [];
    req.preferredModelName = preferredModelName;
    req.cancellationToken = cancellationToken;

    const sys = new AIRuntimeMessage();
    sys.role = 'system';
    sys.content = systemPrompt;
    const user = new AIRuntimeMessage();
    user.role = 'user';
    user.content = userPrompt;
    req.messages = [sys, user];

    let text = '';
    const resp = await this.runtime.generateTextStream(req, (ev: AIRuntimeEvent) => {
      if (ev.kind === 'textDelta' && ev.deltaText) {
        text += ev.deltaText;
      }
    });
    if (resp.text.length === 0 && text.length > 0) {
      resp.text = text;
    }
    return resp;
  }

  async recognizeMedicalDocumentType(
    accountId: number,
    ocrOrText: string,
    cancellationToken?: AIRuntimeCancellationToken
  ): Promise<AIRuntimeResponse> {
    return this.generateStructuredText(
      accountId,
      AIScenario.MEDICAL_DOCUMENT_TYPE_RECOGNITION,
      '你是医疗文档类型识别器。只输出文档类型标签，不要解释。',
      ocrOrText,
      cancellationToken
    );
  }
}
