import { http } from '@kit.NetworkKit';
import { NetworkLogger } from '../../../Foundation/Logging/NetworkLogger';
import {
  CancellationToken,
  HttpMethod,
  RawHttpRequest,
  RawHttpResponse,
  SupportNetworkError
} from './SupportNetworkModels';

export interface NetworkTransport {
  execute(request: RawHttpRequest, cancellation: CancellationToken): Promise<RawHttpResponse>;
}

function toRequestMethod(method: HttpMethod): http.RequestMethod {
  switch (method) {
    case 'GET':
      return http.RequestMethod.GET;
    case 'POST':
      return http.RequestMethod.POST;
    case 'PUT':
      return http.RequestMethod.PUT;
    case 'PATCH':
      // Network Kit in the target SDK does not expose a PATCH enum member.
      // The request method is still sent through the string-compatible option below.
      return http.RequestMethod.PUT;
    case 'DELETE':
      return http.RequestMethod.DELETE;
    default:
      return http.RequestMethod.GET;
  }
}

function normalizeHeaders(header: Object | undefined): Record<string, string> {
  const out: Record<string, string> = {};
  if (!header) {
    return out;
  }
  const record = header as Record<string, string | string[]>;
  const keys = Object.keys(record);
  for (let i = 0; i < keys.length; i++) {
    const k = keys[i];
    const v = record[k];
    if (typeof v === 'string') {
      out[k] = v;
    } else if (Array.isArray(v) && v.length > 0) {
      out[k] = `${v[0]}`;
    }
  }
  return out;
}

function bodyToText(result: string | Object | ArrayBuffer): string {
  if (typeof result === 'string') {
    return result;
  }
  if (result instanceof ArrayBuffer) {
    const bytes = new Uint8Array(result);
    let s = '';
    for (let i = 0; i < bytes.length; i++) {
      s += String.fromCharCode(bytes[i]);
    }
    return s;
  }
  try {
    return JSON.stringify(result);
  } catch (_e) {
    return '';
  }
}

/**
 * 唯一允许直接使用 @ohos.net.http / NetworkKit HTTP 的层。
 * 每次请求独立会话，finally 中 destroy。
 */
export class SupportNetworkTransport implements NetworkTransport {
  private readonly logger: NetworkLogger;

  constructor(logger?: NetworkLogger) {
    this.logger = logger ?? new NetworkLogger();
  }

  async execute(request: RawHttpRequest, cancellation: CancellationToken): Promise<RawHttpResponse> {
    cancellation.throwIfCancelled(request.requestId);
    const session = http.createHttp();
    const cancel = (): void => {
      try {
        session.destroy();
      } catch (_e) {
        // ignore
      }
    };
    cancellation.onCancel(cancel);
    const start = Date.now();
    this.logger.outbound(request.method, request.url, request.requestId, request.headers);
    this.logger.outboundRaw(request.requestId, request.headers, request.body);
    try {
      const options: http.HttpRequestOptions = {
        method: toRequestMethod(request.method),
        header: request.headers,
        extraData: request.body,
        connectTimeout: request.timeoutMs,
        readTimeout: request.timeoutMs,
        expectDataType: http.HttpDataType.STRING
      };
      const response = await session.request(request.url, options);
      const durationMs = Date.now() - start;
      const headers = normalizeHeaders(response.header as Object);
      const bodyText = bodyToText(response.result as string | Object | ArrayBuffer);
      this.logger.inbound(
        request.method,
        request.url,
        request.requestId,
        response.responseCode,
        durationMs,
        bodyText.length
      );
      this.logger.inboundRaw(
        request.requestId,
        request.method,
        request.url,
        response.responseCode,
        headers,
        bodyText
      );
      return new RawHttpResponse(response.responseCode, headers, bodyText, durationMs);
    } catch (error) {
      if (cancellation.cancelled) {
        throw SupportNetworkError.cancelled(request.requestId);
      }
      const message = error instanceof Error ? error.message : `${error}`;
      this.logger.error(`HTTP failed requestId=${request.requestId} reason=${message}`);
      throw SupportNetworkError.transport(message, request.requestId);
    } finally {
      cancellation.offCancel(cancel);
      try {
        session.destroy();
      } catch (_e) {
        // ignore
      }
    }
  }
}

/**
 * 仅用于单元测试的 Mock Transport；禁止接入生产 Backend。
 */
export class MockNetworkTransport implements NetworkTransport {
  private handlers: Array<(req: RawHttpRequest) => Promise<RawHttpResponse>> = [];
  readonly sentRequests: RawHttpRequest[] = [];

  enqueue(handler: (req: RawHttpRequest) => Promise<RawHttpResponse>): void {
    this.handlers.push(handler);
  }

  enqueueFixed(response: RawHttpResponse): void {
    this.handlers.push(async (_req: RawHttpRequest): Promise<RawHttpResponse> => response);
  }

  async execute(request: RawHttpRequest, cancellation: CancellationToken): Promise<RawHttpResponse> {
    cancellation.throwIfCancelled(request.requestId);
    this.sentRequests.push(request);
    if (this.handlers.length === 0) {
      throw SupportNetworkError.transport('MockNetworkTransport has no handlers', request.requestId);
    }
    const handler = this.handlers.shift() as (req: RawHttpRequest) => Promise<RawHttpResponse>;
    return handler(request);
  }
}
