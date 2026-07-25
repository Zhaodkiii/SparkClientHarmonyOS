import { connection } from '@kit.NetworkKit';
import { NetworkLogger } from './Logging/NetworkLogger';

export type NetworkPathStatus = 'unknown' | 'satisfied' | 'unsatisfied';

export type NetworkPathListener = (status: NetworkPathStatus, hasEvaluated: boolean) => void;

/**
 * 网络路径监听：初始 unknown，首次评估前不得当作离线。
 */
export class NetworkPathMonitor {
  private status: NetworkPathStatus = 'unknown';
  private hasEvaluatedPath: boolean = false;
  private netConnection?: connection.NetConnection;
  private listeners: NetworkPathListener[] = [];
  private readonly logger: NetworkLogger;

  constructor(logger?: NetworkLogger) {
    this.logger = logger ?? new NetworkLogger();
  }

  get currentStatus(): NetworkPathStatus {
    return this.status;
  }

  get hasEvaluated(): boolean {
    return this.hasEvaluatedPath;
  }

  subscribe(listener: NetworkPathListener): void {
    this.listeners.push(listener);
    listener(this.status, this.hasEvaluatedPath);
  }

  unsubscribe(listener: NetworkPathListener): void {
    const idx = this.listeners.indexOf(listener);
    if (idx >= 0) {
      this.listeners.splice(idx, 1);
    }
  }

  start(): void {
    if (this.netConnection) {
      return;
    }
    try {
      this.netConnection = connection.createNetConnection();
      this.netConnection.register(() => {
        // registered
      });
      this.netConnection.on('netAvailable', (_data: connection.NetHandle) => {
        this.update('satisfied');
      });
      this.netConnection.on('netLost', (_data: connection.NetHandle) => {
        this.update('unsatisfied');
      });
      this.netConnection.on('netUnavailable', () => {
        this.update('unsatisfied');
      });
      // 尝试读取当前默认网络
      connection.getDefaultNet().then((handle: connection.NetHandle) => {
        if (handle && handle.netId !== undefined) {
          this.update('satisfied');
        } else {
          this.update('unsatisfied');
        }
      }).catch(() => {
        this.update('unknown');
        this.hasEvaluatedPath = true;
        this.emit();
      });
    } catch (e) {
      this.logger.warn(`NetworkPathMonitor start failed: ${e}`);
      this.hasEvaluatedPath = true;
    }
  }

  stop(): void {
    if (!this.netConnection) {
      return;
    }
    try {
      this.netConnection.unregister(() => {
        // unregistered
      });
    } catch (_e) {
      // ignore
    }
    this.netConnection = undefined;
  }

  private update(status: NetworkPathStatus): void {
    this.status = status;
    this.hasEvaluatedPath = true;
    this.emit();
  }

  private emit(): void {
    const copy = this.listeners.slice();
    for (let i = 0; i < copy.length; i++) {
      try {
        copy[i](this.status, this.hasEvaluatedPath);
      } catch (_e) {
        // ignore
      }
    }
  }
}
