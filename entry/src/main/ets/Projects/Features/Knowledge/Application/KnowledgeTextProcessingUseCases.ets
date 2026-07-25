import {
  AIRuntimeEvent,
  AIRuntimeMessage,
  AIRuntimeResponse,
  AIRuntimeTextRequest,
  AIScenario
} from '../../../../Core/AI/Domain/AIConfigModels';
import { AIRuntimeService } from '../../../../Core/AI/Runtime/AIRuntimeService';
import { ChatAttachmentOCRAdapter } from '../../Chat/Infrastructure/ChatAttachmentPreprocessor';
import { KnowledgeUseCaseSupport } from './KnowledgeUseCases';

/**
 * 使用 `AIScenario.OPTIMIZATION_TEXT` 润色正文；对齐 iOS PolishKnowledgeTextUseCase。
 */
export class PolishKnowledgeTextUseCase {
  private readonly runtime: AIRuntimeService;

  constructor(runtime: AIRuntimeService) {
    this.runtime = runtime;
  }

  async execute(accountId: number, text: string): Promise<string> {
    KnowledgeUseCaseSupport.requireAccount(accountId);
    const trimmed = text.trim();
    if (trimmed.length === 0) {
      return text;
    }
    const request = KnowledgeTextProcessingSupport.makeRequest(
      accountId,
      AIScenario.OPTIMIZATION_TEXT,
      [KnowledgeTextProcessingSupport.userMessage(trimmed)]
    );
    return await KnowledgeTextProcessingSupport.collectResponseText(this.runtime, request);
  }
}

/**
 * 使用聊天场景 + system 提示做翻译（首版固定译为中文）；对齐 iOS TranslateKnowledgeTextUseCase。
 */
export class TranslateKnowledgeTextUseCase {
  private readonly runtime: AIRuntimeService;

  constructor(runtime: AIRuntimeService) {
    this.runtime = runtime;
  }

  async execute(
    accountId: number,
    text: string,
    targetLanguageDescription: string = '中文'
  ): Promise<string> {
    KnowledgeUseCaseSupport.requireAccount(accountId);
    const trimmed = text.trim();
    if (trimmed.length === 0) {
      return text;
    }
    const system =
      `You are a professional translator. Translate the user's text into ${targetLanguageDescription}. ` +
        'Output only the translated text, with no explanations or quotes.';
    const request = KnowledgeTextProcessingSupport.makeRequest(
      accountId,
      AIScenario.CHAT,
      [
        KnowledgeTextProcessingSupport.systemMessage(system),
        KnowledgeTextProcessingSupport.userMessage(trimmed)
      ]
    );
    return await KnowledgeTextProcessingSupport.collectResponseText(this.runtime, request);
  }
}

/**
 * 为本地智能体自动生成 system prompt；对齐 iOS AutoFillAgentPromptUseCase。
 */
export class AutoFillAgentPromptUseCase {
  private readonly runtime: AIRuntimeService;

  constructor(runtime: AIRuntimeService) {
    this.runtime = runtime;
  }

  async execute(accountId: number, displayName: string, baseModelName: string): Promise<string> {
    KnowledgeUseCaseSupport.requireAccount(accountId);
    const name = displayName.trim();
    const model = baseModelName.trim();
    const prompt =
      '请为一个本地智能体生成可直接保存的 system prompt。\n' +
        `智能体名称：${name.length > 0 ? name : '未命名智能体'}\n` +
        `基座模型：${model.length > 0 ? model : '未指定'}\n\n` +
        '要求：\n' +
        '1. 使用中文。\n' +
        '2. 明确角色定位、能力边界、交流风格、输出规则和安全约束。\n' +
        '3. 适合作为系统提示词直接注入模型。\n' +
        '4. 不要输出解释、标题、引号或 Markdown 包装。';
    const request = KnowledgeTextProcessingSupport.makeRequest(
      accountId,
      AIScenario.OPTIMIZATION_TEXT,
      [KnowledgeTextProcessingSupport.userMessage(prompt)]
    );
    return await KnowledgeTextProcessingSupport.collectResponseText(this.runtime, request);
  }
}

/**
 * 从相册/相机图片识别文字；对齐 iOS OCRKnowledgeImageUseCase。
 * 与 iOS 差异：入参为 sourceUri（鸿蒙 picker / 相机返回 URI），复用 Chat 侧 OCR 适配器。
 */
export class OCRKnowledgeImageUseCase {
  private readonly ocr: ChatAttachmentOCRAdapter;

  constructor(ocr: ChatAttachmentOCRAdapter) {
    this.ocr = ocr;
  }

  async execute(sourceUri: string): Promise<string> {
    const uri = sourceUri.trim();
    if (uri.length === 0) {
      throw new Error('OCR 图片路径为空。');
    }
    return await this.ocr.recognizeImage(uri);
  }
}

class KnowledgeTextProcessingSupport {
  static makeRequest(
    accountId: number,
    scenario: string,
    messages: AIRuntimeMessage[]
  ): AIRuntimeTextRequest {
    const request = new AIRuntimeTextRequest();
    request.requestId = `knowledge_text_${Date.now()}`;
    request.accountId = accountId;
    request.scenario = scenario;
    request.stream = true;
    request.toolChoice = 'none';
    request.tools = [];
    request.messages = messages;
    return request;
  }

  static userMessage(content: string): AIRuntimeMessage {
    const msg = new AIRuntimeMessage();
    msg.role = 'user';
    msg.content = content;
    return msg;
  }

  static systemMessage(content: string): AIRuntimeMessage {
    const msg = new AIRuntimeMessage();
    msg.role = 'system';
    msg.content = content;
    return msg;
  }

  static async collectResponseText(
    runtime: AIRuntimeService,
    request: AIRuntimeTextRequest
  ): Promise<string> {
    let bufferedText = '';
    const response: AIRuntimeResponse = await runtime.generateTextStream(
      request,
      (ev: AIRuntimeEvent) => {
        if (ev.kind === 'textDelta' && ev.deltaText) {
          bufferedText += ev.deltaText;
        }
      }
    );
    if (response.errorCode && response.errorCode.length > 0) {
      throw new Error(response.errorMessage ?? response.errorCode);
    }
    if (response.text.length > 0) {
      return response.text;
    }
    return bufferedText;
  }
}
