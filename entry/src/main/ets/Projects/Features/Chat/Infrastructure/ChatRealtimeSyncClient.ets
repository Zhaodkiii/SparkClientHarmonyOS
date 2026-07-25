import { webSocket } from '@kit.NetworkKit';
import { AuthTokenProvider } from '../../../Core/Networking/AuthTokenProvider';

export type ChatSyncHintHandler = (cursor?: string) => void;

/** WebSocket 只做变更提示；消息正文永远通过 REST pull 补齐。 */
export class ChatRealtimeSyncClient {
  private readonly tokenProvider: AuthTokenProvider;
  private readonly baseURL: string;
  private socket?: webSocket.WebSocket;
  private running: boolean = false;
  private reconnectTimer?: number;
  private reconnectAttempt: number = 0;
  private hintHandler?: ChatSyncHintHandler;

  constructor(tokenProvider: AuthTokenProvider, baseURL: string) {
    this.tokenProvider = tokenProvider;
    this.baseURL = baseURL;
  }

  async start(handler: ChatSyncHintHandler): Promise<void> {
    this.hintHandler = handler;
    if (this.running) return;
    this.running = true;
    this.reconnectAttempt = 0;
    await this.connect();
  }

  async stop(): Promise<void> {
    this.running = false;
    if (this.reconnectTimer !== undefined) {
      clearTimeout(this.reconnectTimer);
      this.reconnectTimer = undefined;
    }
    if (this.socket) {
      try { this.socket.close(); } catch (_e) { /* ignore */ }
      this.socket = undefined;
    }
  }

  private async connect(): Promise<void> {
    if (!this.running) return;
    const auth = await this.tokenProvider.authorizationHeaderValue();
    const token = auth.indexOf(' ') >= 0 ? auth.substring(auth.indexOf(' ') + 1) : auth;
    const wsUrl = this.toWebSocketURL(this.baseURL) + `?token=${encodeURIComponent(token)}`;
    const socket = webSocket.createWebSocket();
    this.socket = socket;
    socket.on('open', (_err: Object, _value: Object) => {
      this.reconnectAttempt = 0;
    });
    socket.on('message', (_err: Object, value: string | ArrayBuffer) => {
      const raw = typeof value === 'string' ? value : this.arrayBufferToString(value);
      this.handleMessage(raw);
    });
    socket.on('close', (_err: Object, _value: webSocket.CloseResult) => {
      if (this.running) this.scheduleReconnect();
    });
    socket.on('error', (_err: Object) => {
      if (this.running) this.scheduleReconnect();
    });
    await new Promise<void>((resolve, reject) => {
      socket.connect(wsUrl, (err: Object, _value: boolean) => {
        if (err) reject(new Error('chat websocket connect failed'));
        else resolve();
      });
    });
  }

  private handleMessage(raw: string): void {
    try {
      const parsed = JSON.parse(raw) as Record<string, Object | string | number | boolean | null>;
      const type = `${parsed['type'] ?? parsed['event'] ?? ''}`;
      if (type === 'chat.sync.updated') {
        const cursor = parsed['cursor'];
        this.hintHandler?.(cursor === null || cursor === undefined ? undefined : `${cursor}`);
      }
    } catch (_e) {
      // 非法 hint 不影响后续 REST cursor。
    }
  }

  private scheduleReconnect(): void {
    if (!this.running || this.reconnectTimer !== undefined) return;
    const attempt = this.reconnectAttempt;
    this.reconnectAttempt += 1;
    const delay = Math.min(30000, Math.max(1000, Math.pow(2, attempt) * 1000));
    this.reconnectTimer = setTimeout(() => {
      this.reconnectTimer = undefined;
      this.connect().catch(() => this.scheduleReconnect());
    }, delay);
  }

  private toWebSocketURL(value: string): string {
    const normalized = value.endsWith('/') ? value.substring(0, value.length - 1) : value;
    const switched = normalized.startsWith('https://') ? `wss://${normalized.substring(8)}` : `ws://${normalized.substring(7)}`;
    return `${switched}/ws/chat/sync/`;
  }

  private arrayBufferToString(value: ArrayBuffer): string {
    const bytes = new Uint8Array(value); let out = '';
    for (let i = 0; i < bytes.length; i++) out += String.fromCharCode(bytes[i]);
    return out;
  }
}
