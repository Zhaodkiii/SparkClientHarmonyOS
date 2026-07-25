import { UserSession } from '../Projects/Core/Domain/Entities/UserSession';
import { RestoreSessionUseCase } from '../Projects/Features/Auth/Application/RestoreSessionUseCase';
import { AccountSessionRuntime } from './AccountSessionRuntime';

export type SessionState = 'loading' | 'signedOut' | 'signedIn';

export const SESSION_STATE_KEY: string = 'app.sessionState';
export const SESSION_GENERATION_KEY: string = 'app.sessionGeneration';

/**
 * 根会话状态源。恢复经 RestoreSessionUseCase；UI 通过 AppStorage 订阅。
 * enterSignedIn 只表示认证完成，不表示账号准备完成。
 */
export class AppSessionStore {
  private restoreUseCase?: RestoreSessionUseCase;
  private runtime?: AccountSessionRuntime;
  private onSignedInHook?: (session: UserSession) => void;
  private state: SessionState = 'loading';
  private generationValue: number = 0;
  private restoreStarted: boolean = false;
  private currentSession?: UserSession;

  constructor() {
    this.publish();
  }

  configure(restoreUseCase: RestoreSessionUseCase, runtime: AccountSessionRuntime): void {
    this.restoreUseCase = restoreUseCase;
    this.runtime = runtime;
  }

  setOnSignedIn(hook: (session: UserSession) => void): void {
    this.onSignedInHook = hook;
  }

  get sessionState(): SessionState {
    return this.state;
  }

  get generation(): number {
    return this.generationValue;
  }

  get session(): UserSession | undefined {
    return this.currentSession;
  }

  /**
   * 冷启动只恢复一次：快照 + Token 联合；临时刷新失败可保留快照。
   */
  async restoreIfNeeded(): Promise<void> {
    if (this.restoreStarted && this.state !== 'loading') {
      return;
    }
    this.restoreStarted = true;
    if (!this.restoreUseCase) {
      this.state = 'signedOut';
      this.currentSession = undefined;
      this.publish();
      return;
    }
    try {
      const session = await this.restoreUseCase.execute();
      if (session) {
        this.currentSession = session;
        this.state = 'signedIn';
        if (this.runtime) {
          await this.runtime.onSignedIn(session);
        }
      } else {
        this.currentSession = undefined;
        this.state = 'signedOut';
      }
    } catch (_e) {
      this.currentSession = undefined;
      this.state = 'signedOut';
    }
    this.publish();
  }

  enterSignedIn(session?: UserSession): void {
    this.generationValue += 1;
    this.state = 'signedIn';
    if (session) {
      this.currentSession = session;
    }
    this.publish();
    if (session && this.onSignedInHook) {
      this.onSignedInHook(session);
    }
  }

  /**
   * 主动退出：递增 generation 并回到 signedOut。
   */
  signOut(): void {
    if (this.state === 'signedOut') {
      this.currentSession = undefined;
      this.publish();
      return;
    }
    this.generationValue += 1;
    this.state = 'signedOut';
    this.currentSession = undefined;
    this.publish();
  }

  /**
   * 鉴权失效：generation 一致时生效；并清快照。
   */
  handleAuthInvalidated(eventGeneration: number): boolean {
    if (eventGeneration !== this.generationValue) {
      return false;
    }
    if (this.state === 'signedOut') {
      return false;
    }
    this.generationValue += 1;
    this.state = 'signedOut';
    this.currentSession = undefined;
    this.publish();
    if (this.runtime) {
      this.runtime.onAuthInvalidated().catch(() => {
        // ignore
      });
    }
    return true;
  }

  /** 仅测试：强制写入状态 */
  setStateForTests(state: SessionState, generation?: number, session?: UserSession): void {
    this.state = state;
    if (generation !== undefined) {
      this.generationValue = generation;
    }
    this.currentSession = session;
    this.publish();
  }

  private publish(): void {
    try {
      AppStorage.setOrCreate(SESSION_STATE_KEY, this.state as string);
      AppStorage.setOrCreate(SESSION_GENERATION_KEY, this.generationValue);
    } catch (_e) {
      // 纯单测环境可能无 AppStorage
    }
  }
}
