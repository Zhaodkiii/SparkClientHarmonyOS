/**
 * 应用环境配置；Base URL 与 iOS SupportAppEnvironment 对齐。
 */
export enum BackendEnvironmentKind {
  DEBUG = 'debug',
  STAGING = 'staging',
  PRODUCTION = 'production'
}

export class BackendEnvironment {
  readonly kind: BackendEnvironmentKind;
  readonly apiBaseURL: string;
  readonly defaultTimeoutMs: number;
  readonly diagnosticsEnabled: boolean;

  constructor(
    kind: BackendEnvironmentKind,
    apiBaseURL: string,
    defaultTimeoutMs: number = 60000,
    diagnosticsEnabled: boolean = false
  ) {
    this.kind = kind;
    this.apiBaseURL = apiBaseURL;
    this.defaultTimeoutMs = defaultTimeoutMs;
    this.diagnosticsEnabled = diagnosticsEnabled;
  }

  static debug(): BackendEnvironment {
    return new BackendEnvironment(
      BackendEnvironmentKind.DEBUG,
      'http://39.106.39.110:2026',
      60000,
      true
    );
  }

  static staging(): BackendEnvironment {
    return new BackendEnvironment(
      BackendEnvironmentKind.STAGING,
      'https://api.dreamwhale.top',
      60000,
      true
    );
  }

  static production(): BackendEnvironment {
    return new BackendEnvironment(
      BackendEnvironmentKind.PRODUCTION,
      'https://api.dreamwhale.top',
      60000,
      false
    );
  }

  /**
   * 当前进程环境：默认 debug。后续可由构建变体切换。
   */
  static current(): BackendEnvironment {
    return BackendEnvironment.debug();
  }

  /** 开放端分享站点根地址。对齐 iOS `openWebBaseURL` / `shareWebBaseURL`。 */
  shareWebBaseURL(): string {
    if (this.kind === BackendEnvironmentKind.DEBUG) {
      return 'http://39.106.39.110:2028';
    }
    return 'https://share.dreamwhale.top';
  }
}
