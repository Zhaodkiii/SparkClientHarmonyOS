import { SessionInvalidation } from '../Projects/Core/Networking/SessionInvalidation';
import { AppSessionStore } from './AppSessionStore';
import { AppLifecycleCoordinator } from './AppLifecycleCoordinator';
import { Logger } from '../Foundation/Logging/Logger';
import { LogModule } from '../Foundation/Logging/LogModule';

/**
 * 系统级路由事件入口：鉴权失效转交生命周期；深链预留。
 */
export class RouteCoordinator {
  private readonly sessionStore: AppSessionStore;
  private readonly lifecycle?: AppLifecycleCoordinator;
  private readonly onInvalidated: (source: string) => void;
  private started: boolean = false;

  constructor(sessionStore: AppSessionStore, lifecycle?: AppLifecycleCoordinator) {
    this.sessionStore = sessionStore;
    this.lifecycle = lifecycle;
    this.onInvalidated = (source: string): void => {
      this.handleAuthInvalidated(source);
    };
  }

  start(): void {
    if (this.started) {
      return;
    }
    this.started = true;
    SessionInvalidation.subscribe(this.onInvalidated);
  }

  stop(): void {
    if (!this.started) {
      return;
    }
    SessionInvalidation.unsubscribe(this.onInvalidated);
    this.started = false;
  }

  /**
   * 优先转交 AppLifecycleCoordinator；无 lifecycle 时回退直接清会话（单测兼容）。
   */
  handleAuthInvalidated(source: string): void {
    if (this.lifecycle) {
      this.lifecycle.handleServerAuthInvalidation(source).catch(() => {
        SessionInvalidation.clearInvalidatingFlag();
      });
      return;
    }
    const gen = this.sessionStore.generation;
    const applied = this.sessionStore.handleAuthInvalidated(gen);
    SessionInvalidation.clearInvalidatingFlag();
    if (applied) {
      Logger.info('route.auth_invalidated', LogModule.ROUTING);
    } else {
      Logger.debug('route.auth_invalidated_ignored', LogModule.ROUTING);
    }
  }

  onDeepLink(_uri: string): void {
    Logger.debug('route.deeplink_reserved', LogModule.ROUTING);
  }
}
