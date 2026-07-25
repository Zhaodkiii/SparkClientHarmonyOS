/**
 * 会话失效去重广播；供后续 AppSessionStore / 路由订阅。
 */
export type SessionInvalidationListener = (source: string) => void;

export class SessionInvalidation {
  private static isInvalidating: boolean = false;
  private static listeners: SessionInvalidationListener[] = [];

  static subscribe(listener: SessionInvalidationListener): void {
    SessionInvalidation.listeners.push(listener);
  }

  static unsubscribe(listener: SessionInvalidationListener): void {
    const idx = SessionInvalidation.listeners.indexOf(listener);
    if (idx >= 0) {
      SessionInvalidation.listeners.splice(idx, 1);
    }
  }

  static resetForTests(): void {
    SessionInvalidation.isInvalidating = false;
    SessionInvalidation.listeners = [];
  }

  static get invalidating(): boolean {
    return SessionInvalidation.isInvalidating;
  }

  /**
   * 仅在确定鉴权失效时调用。返回 true 表示本次实际触发。
   */
  static postIfNeeded(
    statusCode: number | undefined,
    backendCode: number | undefined,
    message: string,
    source: string
  ): boolean {
    if (!SessionInvalidation.shouldInvalidate(statusCode, backendCode, message)) {
      return false;
    }
    if (SessionInvalidation.isInvalidating) {
      return false;
    }
    SessionInvalidation.isInvalidating = true;
    const copy = SessionInvalidation.listeners.slice();
    for (let i = 0; i < copy.length; i++) {
      try {
        copy[i](source);
      } catch (_e) {
        // ignore
      }
    }
    return true;
  }

  static clearInvalidatingFlag(): void {
    SessionInvalidation.isInvalidating = false;
  }

  static shouldInvalidate(
    statusCode: number | undefined,
    backendCode: number | undefined,
    message: string
  ): boolean {
    // Permission failures must never be converted into a login-state change.
    // This guard intentionally precedes the business-code/message checks and
    // mirrors AuthSessionInvalidation on iOS.
    if (statusCode === 403) {
      return false;
    }
    if (statusCode === 401) {
      return true;
    }
    if (backendCode !== undefined && backendCode >= 40100 && backendCode <= 40199) {
      return true;
    }
    const lower = (message ?? '').trim().toLowerCase();
    if (
      lower.indexOf('token_not_valid') >= 0 ||
      lower.indexOf('device_session_revoked') >= 0 ||
      lower.indexOf('device_session_replaced') >= 0 ||
      lower.indexOf('device_session_not_found') >= 0 ||
      lower.indexOf('device_mismatch') >= 0 ||
      lower.indexOf('authentication_failed') >= 0 ||
      lower.indexOf('not_authenticated') >= 0 ||
      lower.indexOf('invalid_token') >= 0 ||
      lower.indexOf('token_expired') >= 0 ||
      lower.indexOf('given token not valid') >= 0
    ) {
      return true;
    }
    return false;
  }
}
