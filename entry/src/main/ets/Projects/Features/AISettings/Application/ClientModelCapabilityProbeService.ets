import { http } from '@kit.NetworkKit';
import {
  ModelCapabilityProbeProgressItem,
  ModelCapabilityProbeStatus,
  ModelCapabilityProbeStep,
  ModelCapabilityProbeSummary
} from './AddOnlineModelModels';

export type ProbeProgressCallback =
  (step: ModelCapabilityProbeStep, status: ModelCapabilityProbeStatus, message: string) => void;

/**
 * 对标 iOS ClientModelCapabilityProbeService（OpenAI 兼容 Chat Completions）。
 * ArkTS 禁止未标注类型的 object/array 字面量，请求体一律用 Record + Object[] 组装。
 */
export class ClientModelCapabilityProbeService {
  async probe(
    modelName: string,
    endpoint: string,
    apiKey: string,
    onUpdate: ProbeProgressCallback
  ): Promise<ModelCapabilityProbeSummary> {
    const model = modelName.trim();
    const url = endpoint.trim();
    const key = apiKey.trim();
    if (model.length === 0 || url.length === 0 || key.length === 0) {
      throw new Error('请先填写模型名、请求地址和 API Key');
    }
    const chatUrl = ClientModelCapabilityProbeService.normalizeChatCompletionsURL(url);

    const connectivityOK = await this.runStep(ModelCapabilityProbeStep.CONNECTIVITY, onUpdate, async () => {
      await this.requestChatCompletion(
        chatUrl,
        key,
        ClientModelCapabilityProbeService.textBody(model, "Reply only 'pong'.", 16)
      );
    });

    let supportsText = false;
    if (connectivityOK) {
      supportsText = await this.runStep(ModelCapabilityProbeStep.TEXT, onUpdate, async () => {
        await this.requestChatCompletion(
          chatUrl,
          key,
          ClientModelCapabilityProbeService.textBody(model, 'Write one short sentence about health.', 32)
        );
      });
    } else {
      onUpdate(ModelCapabilityProbeStep.TEXT, ModelCapabilityProbeStatus.SKIPPED, '连通性失败，已跳过');
    }

    let supportsMultimodal = false;
    if (supportsText) {
      supportsMultimodal = await this.runStep(ModelCapabilityProbeStep.MULTIMODAL, onUpdate, async () => {
        await this.requestChatCompletion(
          chatUrl,
          key,
          ClientModelCapabilityProbeService.multimodalBody(model)
        );
      });
    } else {
      onUpdate(ModelCapabilityProbeStep.MULTIMODAL, ModelCapabilityProbeStatus.SKIPPED, '文本能力不可用');
    }

    let supportsReasoning = false;
    if (supportsText) {
      supportsReasoning = await this.runStep(ModelCapabilityProbeStep.REASONING, onUpdate, async () => {
        const body = ClientModelCapabilityProbeService.textBody(
          model,
          'What is 122 + 57? Return only the number.',
          16
        );
        body['temperature'] = 0;
        await this.requestChatCompletion(chatUrl, key, body);
      });
    } else {
      onUpdate(ModelCapabilityProbeStep.REASONING, ModelCapabilityProbeStatus.SKIPPED, '文本能力不可用');
    }

    let supportsToolUse = false;
    if (supportsText) {
      supportsToolUse = await this.runStep(ModelCapabilityProbeStep.TOOL_USE, onUpdate, async () => {
        const payload = await this.requestChatCompletion(
          chatUrl,
          key,
          ClientModelCapabilityProbeService.toolBody(model)
        );
        if (!ClientModelCapabilityProbeService.hasToolCalls(payload)) {
          throw new Error('未返回 tool_calls');
        }
      });
    } else {
      onUpdate(ModelCapabilityProbeStep.TOOL_USE, ModelCapabilityProbeStatus.SKIPPED, '文本能力不可用');
    }

    const supportsImageGen = await this.runStep(ModelCapabilityProbeStep.IMAGE_GEN, onUpdate, async () => {
      if (chatUrl.indexOf('/chat/completions') < 0) {
        throw new Error('当前 endpoint 不支持生图探测');
      }
      const imageUrl = chatUrl.replace('/chat/completions', '/images/generations');
      await this.requestJSON(imageUrl, key, ClientModelCapabilityProbeService.imageBody(model));
    });

    const summary = new ModelCapabilityProbeSummary();
    summary.supportsText = supportsText;
    summary.supportsMultimodal = supportsMultimodal;
    summary.supportsReasoning = supportsReasoning;
    summary.reasoningControllable = supportsReasoning;
    summary.supportsToolUse = supportsToolUse;
    summary.supportsImageGen = supportsImageGen;
    return summary;
  }

  private async runStep(
    step: ModelCapabilityProbeStep,
    onUpdate: ProbeProgressCallback,
    action: () => Promise<void>
  ): Promise<boolean> {
    onUpdate(step, ModelCapabilityProbeStatus.RUNNING, '');
    try {
      await action();
      onUpdate(step, ModelCapabilityProbeStatus.SUCCESS, '');
      return true;
    } catch (err) {
      const msg = `${err}`;
      const firstLine = msg.split('\n')[0];
      const short = firstLine.length > 80 ? firstLine.substring(0, 80) : firstLine;
      onUpdate(step, ModelCapabilityProbeStatus.FAILED, short);
      return false;
    }
  }

  private async requestChatCompletion(
    endpoint: string,
    apiKey: string,
    body: Record<string, Object | string | number | boolean | Object[]>
  ): Promise<Record<string, Object>> {
    return this.requestJSON(endpoint, apiKey, body);
  }

  private async requestJSON(
    endpoint: string,
    apiKey: string,
    body: Record<string, Object | string | number | boolean | Object[]>
  ): Promise<Record<string, Object>> {
    const httpRequest = http.createHttp();
    try {
      const headers: Record<string, string> = {};
      headers['Content-Type'] = 'application/json';
      headers['Authorization'] = `Bearer ${apiKey}`;
      headers['Accept'] = 'application/json';
      const result = await httpRequest.request(endpoint, {
        method: http.RequestMethod.POST,
        header: headers,
        extraData: JSON.stringify(body),
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 20000,
        readTimeout: 45000
      });
      const code = result.responseCode;
      const raw = `${result.result ?? ''}`;
      if (code < 200 || code >= 300) {
        const trimmed = raw.trim();
        throw new Error(trimmed.length > 0 ? `HTTP ${code}: ${trimmed}` : `HTTP ${code}`);
      }
      try {
        return JSON.parse(raw) as Record<string, Object>;
      } catch (_e) {
        throw new Error('响应不是合法 JSON');
      }
    } finally {
      httpRequest.destroy();
    }
  }

  private static textMessage(content: string): Record<string, string> {
    const msg: Record<string, string> = {};
    msg['role'] = 'user';
    msg['content'] = content;
    return msg;
  }

  private static textBody(
    model: string,
    content: string,
    maxTokens: number
  ): Record<string, Object | string | number | boolean | Object[]> {
    const messages: Object[] = [];
    messages.push(ClientModelCapabilityProbeService.textMessage(content));
    const body: Record<string, Object | string | number | boolean | Object[]> = {};
    body['model'] = model;
    body['messages'] = messages;
    body['max_tokens'] = maxTokens;
    return body;
  }

  private static multimodalBody(
    model: string
  ): Record<string, Object | string | number | boolean | Object[]> {
    const textPart: Record<string, string> = {};
    textPart['type'] = 'text';
    textPart['text'] = 'Describe this image in one sentence.';

    const imageUrlObj: Record<string, string> = {};
    imageUrlObj['url'] =
      'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR4nGNgYAAAAAMAASsJTYQAAAAASUVORK5CYII=';

    const imagePart: Record<string, Object | string> = {};
    imagePart['type'] = 'image_url';
    imagePart['image_url'] = imageUrlObj;

    const contentParts: Object[] = [];
    contentParts.push(textPart);
    contentParts.push(imagePart);

    const message: Record<string, Object | string | Object[]> = {};
    message['role'] = 'user';
    message['content'] = contentParts;

    const messages: Object[] = [];
    messages.push(message);

    const body: Record<string, Object | string | number | boolean | Object[]> = {};
    body['model'] = model;
    body['messages'] = messages;
    body['max_tokens'] = 48;
    return body;
  }

  private static toolBody(
    model: string
  ): Record<string, Object | string | number | boolean | Object[]> {
    const timezoneProp: Record<string, string> = {};
    timezoneProp['type'] = 'string';
    timezoneProp['description'] = 'IANA timezone';

    const properties: Record<string, Object> = {};
    properties['timezone'] = timezoneProp;

    const required: string[] = [];
    required.push('timezone');

    const parameters: Record<string, Object | string | string[]> = {};
    parameters['type'] = 'object';
    parameters['properties'] = properties;
    parameters['required'] = required;

    const fn: Record<string, Object | string> = {};
    fn['name'] = 'get_time';
    fn['description'] = 'Return current time';
    fn['parameters'] = parameters;

    const tool: Record<string, Object | string> = {};
    tool['type'] = 'function';
    tool['function'] = fn;

    const tools: Object[] = [];
    tools.push(tool);

    const messages: Object[] = [];
    messages.push(
      ClientModelCapabilityProbeService.textMessage(
        'Please call tool get_time and use timezone Asia/Shanghai.'
      )
    );

    const body: Record<string, Object | string | number | boolean | Object[]> = {};
    body['model'] = model;
    body['messages'] = messages;
    body['tools'] = tools;
    body['tool_choice'] = 'auto';
    body['max_tokens'] = 48;
    return body;
  }

  private static imageBody(
    model: string
  ): Record<string, Object | string | number | boolean | Object[]> {
    const body: Record<string, Object | string | number | boolean | Object[]> = {};
    body['model'] = model;
    body['prompt'] = 'A minimal logo with blue spark.';
    body['size'] = '512x512';
    return body;
  }

  private static normalizeChatCompletionsURL(endpoint: string): string {
    let path = endpoint.trim();
    const q = path.indexOf('?');
    if (q >= 0) {
      path = path.substring(0, q);
    }
    if (path.endsWith('/chat/completions') || path.endsWith('/messages') || path.endsWith('/responses')) {
      return path;
    }
    if (path.endsWith('/')) {
      path = path.substring(0, path.length - 1);
    }
    if (path.endsWith('/v1')) {
      return path + '/chat/completions';
    }
    return path + '/chat/completions';
  }

  private static hasToolCalls(payload: Record<string, Object>): boolean {
    const choices = payload['choices'];
    if (!Array.isArray(choices) || choices.length === 0) {
      return false;
    }
    const first = choices[0] as Record<string, Object>;
    const message = first['message'] as Record<string, Object> | undefined;
    if (!message) {
      return false;
    }
    const toolCalls = message['tool_calls'];
    return Array.isArray(toolCalls) && toolCalls.length > 0;
  }
}

/** 供 UI 整体替换 @State 数组用 */
export function replaceProbeItem(
  items: ModelCapabilityProbeProgressItem[],
  step: ModelCapabilityProbeStep,
  status: ModelCapabilityProbeStatus,
  message: string
): ModelCapabilityProbeProgressItem[] {
  const next: ModelCapabilityProbeProgressItem[] = [];
  for (let i = 0; i < items.length; i++) {
    if (items[i].step === step) {
      next.push(new ModelCapabilityProbeProgressItem(step, status, message));
    } else {
      next.push(items[i]);
    }
  }
  return next;
}
