import { http } from '@kit.NetworkKit';

/**
 * OpenAI 兼容 `POST .../embeddings` 客户端抽象；对齐 iOS KnowledgeEmbeddingClient。
 */
export interface KnowledgeEmbeddingClient {
  embed(texts: string[], modelName: string, apiKey: string, endpointURL: string): Promise<number[][]>;
}

export class EmbeddingHTTPError extends Error {
  code: string;

  constructor(code: string, message: string) {
    super(message);
    this.code = code;
  }
}

/**
 * 对齐 iOS OpenAICompatibleEmbeddingClient：
 * - 普通 embeddings：批量 `input: string[]`
 * - 火山 multimodal embeddings：逐条 `input: [{ type, text }]`
 */
export class OpenAICompatibleEmbeddingClient implements KnowledgeEmbeddingClient {
  async embed(texts: string[], modelName: string, apiKey: string, endpointURL: string): Promise<number[][]> {
    if (texts.length === 0) {
      return [];
    }

    const isVolcMultimodal = endpointURL.indexOf('/embeddings/multimodal') >= 0;
    if (isVolcMultimodal) {
      const out: number[][] = [];
      for (let i = 0; i < texts.length; i++) {
        const body: Record<string, Object | string | Object[]> = {
          'model': modelName,
          'input': [
            {
              'type': 'text',
              'text': texts[i]
            } as Object
          ]
        };
        const vec = await this.requestSingleEmbedding(endpointURL, apiKey, body);
        out.push(vec);
      }
      return out;
    }

    const body: Record<string, Object | string | number | string[]> = {
      'model': modelName,
      'input': texts,
      'encoding_format': 'float'
    };
    if (modelName !== 'BAAI/bge-m3') {
      body['dimensions'] = 1024;
    }
    return await this.requestBatchEmbeddings(endpointURL, apiKey, body, texts.length);
  }

  private async requestBatchEmbeddings(
    url: string,
    apiKey: string,
    body: Record<string, Object | string | number | string[]>,
    expectedCount: number
  ): Promise<number[][]> {
    const data = await this.postJSON(url, apiKey, body);
    const parsed = this.parseEmbeddingDataArray(data);
    if (parsed.length !== expectedCount) {
      throw new EmbeddingHTTPError(
        'countMismatch',
        `嵌入数量不一致：期望 ${expectedCount}，实际 ${parsed.length}。`
      );
    }
    return parsed;
  }

  private async requestSingleEmbedding(
    url: string,
    apiKey: string,
    body: Record<string, Object | string | Object[]>
  ): Promise<number[]> {
    const data = await this.postJSON(url, apiKey, body);
    const parsed = this.parseEmbeddingDataArray(data);
    if (parsed.length === 0) {
      throw new EmbeddingHTTPError('emptyPayload', '嵌入响应为空。');
    }
    return parsed[0];
  }

  private async postJSON(
    url: string,
    apiKey: string,
    body: Record<string, Object | string | number | string[] | Object[]>
  ): Promise<Record<string, Object>> {
    const httpRequest = http.createHttp();
    try {
      const headers: Record<string, string> = {
        'Content-Type': 'application/json',
        'Accept': 'application/json'
      };
      const trimmedKey = apiKey.trim();
      if (trimmedKey.length > 0) {
        headers['Authorization'] = `Bearer ${trimmedKey}`;
      }
      const result = await httpRequest.request(url, {
        method: http.RequestMethod.POST,
        header: headers,
        extraData: JSON.stringify(body),
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 30000,
        readTimeout: 60000
      });
      const code = result.responseCode;
      const textBody = `${result.result ?? ''}`;
      if (code !== 200) {
        const preview = textBody.length > 400 ? textBody.substring(0, 400) : textBody;
        throw new EmbeddingHTTPError('status', `嵌入请求失败（${code}）：${preview}`);
      }
      try {
        return JSON.parse(textBody) as Record<string, Object>;
      } catch (_e) {
        throw new EmbeddingHTTPError('parseFailed', '无法解析嵌入响应。');
      }
    } finally {
      httpRequest.destroy();
    }
  }

  private parseEmbeddingDataArray(jsonObject: Record<string, Object>): number[][] {
    const dataField = jsonObject['data'];
    if (Array.isArray(dataField)) {
      const out: number[][] = [];
      for (let i = 0; i < dataField.length; i++) {
        const dict = dataField[i] as Record<string, Object>;
        out.push(this.parseEmbeddingRow(dict, i));
      }
      return out;
    }
    if (dataField !== undefined && dataField !== null && typeof dataField === 'object') {
      const dict = dataField as Record<string, Object>;
      return [this.parseEmbeddingRow(dict, 0)];
    }
    throw new EmbeddingHTTPError('parseFailed', '无法解析嵌入响应。');
  }

  private parseEmbeddingRow(dict: Record<string, Object>, idx: number): number[] {
    const embedding = dict['embedding'];
    const asNumbers = OpenAICompatibleEmbeddingClient.asNumberArray(embedding);
    if (asNumbers !== undefined && asNumbers.length > 0) {
      return asNumbers;
    }
    if (embedding !== undefined && embedding !== null && typeof embedding === 'object' && !Array.isArray(embedding)) {
      const embeddingObject = embedding as Record<string, Object>;
      const textEmbedding = OpenAICompatibleEmbeddingClient.asNumberArray(embeddingObject['text_embedding']);
      if (textEmbedding !== undefined && textEmbedding.length > 0) {
        return textEmbedding;
      }
      const vector = OpenAICompatibleEmbeddingClient.asNumberArray(embeddingObject['vector']);
      if (vector !== undefined && vector.length > 0) {
        return vector;
      }
    }
    throw new EmbeddingHTTPError('parseFailedRow', `无法解析嵌入行 ${idx}。`);
  }

  private static asNumberArray(value: Object | undefined | null): number[] | undefined {
    if (!Array.isArray(value) || value.length === 0) {
      return undefined;
    }
    const out: number[] = [];
    for (let i = 0; i < value.length; i++) {
      const item = value[i];
      if (typeof item === 'number') {
        out.push(item as number);
      } else if (typeof item === 'string') {
        const n = Number(item);
        if (Number.isNaN(n)) {
          return undefined;
        }
        out.push(n);
      } else {
        return undefined;
      }
    }
    return out;
  }
}
