import {
  AuthTokens,
  NetworkRequest,
  NetworkStrategy,
  RetryConfig
} from '../../SupportNetworkModels';
import { SupportBackendConfiguration } from '../../SupportBackendConfiguration';
import { CacheableSupportNetworkOperation } from '../../Operations/SupportNetworkOperation';
import { SupportAPIResponseDecoder } from '../Common/SupportAPIResponseDecoder';
import { JWTExpParser } from '../../../../../Foundation/JWTExpParser';

interface PasswordLoginPayload { identifier: string; password: string; bundle_id: string; device_id: string; }
interface AppleLoginPayload { identity_token: string; user: string; bundle_id: string; device_id: string; device_secret: string; authorization_code?: string; nonce?: string; email?: string; full_name?: string; }
interface DeviceLoginPayload { bundle_id: string; device_id: string; device_secret: string; }

export class PasswordLoginRequest {
  identifier: string;
  password: string;
  bundleId: string;
  deviceId: string;

  constructor(identifier: string, password: string, bundleId: string, deviceId: string) {
    this.identifier = identifier;
    this.password = password;
    this.bundleId = bundleId;
    this.deviceId = deviceId;
  }
}

export class AppleLoginRequest {
  identityToken: string;
  authorizationCode?: string;
  nonce?: string;
  user: string;
  email?: string;
  fullName?: string;
  bundleId: string;
  deviceId: string;
  deviceSecret: string;

  constructor(
    identityToken: string,
    user: string,
    bundleId: string,
    deviceId: string,
    deviceSecret: string,
    authorizationCode?: string,
    nonce?: string,
    email?: string,
    fullName?: string
  ) {
    this.identityToken = identityToken;
    this.user = user;
    this.bundleId = bundleId;
    this.deviceId = deviceId;
    this.deviceSecret = deviceSecret;
    this.authorizationCode = authorizationCode;
    this.nonce = nonce;
    this.email = email;
    this.fullName = fullName;
  }
}

export class DeviceLoginRequest {
  bundleId: string;
  deviceId: string;
  deviceSecret: string;

  constructor(bundleId: string, deviceId: string, deviceSecret: string) {
    this.bundleId = bundleId;
    this.deviceId = deviceId;
    this.deviceSecret = deviceSecret;
  }
}

export class LoginResult {
  userId: number;
  accessToken: string;
  refreshToken: string;
  expiresIn: number;
  tokenType: string;

  constructor(userId: number, accessToken: string, refreshToken: string, expiresIn: number, tokenType: string) {
    this.userId = userId;
    this.accessToken = accessToken;
    this.refreshToken = refreshToken;
    this.expiresIn = expiresIn;
    this.tokenType = tokenType;
  }
}

export class AuthenticatedUserContext {
  userId: number;
  email?: string;
  displayName?: string;
  isPro: boolean;
  isNewUser: boolean;
  signInMethod?: string;
  isDeviceAccount: boolean;
  accountResolution?: string;
  tokens: AuthTokens;

  constructor(
    userId: number,
    tokens: AuthTokens,
    isPro: boolean,
    isNewUser: boolean,
    isDeviceAccount: boolean,
    email?: string,
    displayName?: string,
    signInMethod?: string,
    accountResolution?: string
  ) {
    this.userId = userId;
    this.tokens = tokens;
    this.isPro = isPro;
    this.isNewUser = isNewUser;
    this.isDeviceAccount = isDeviceAccount;
    this.email = email;
    this.displayName = displayName;
    this.signInMethod = signInMethod;
    this.accountResolution = accountResolution;
  }
}

export class CurrentSessionResult {
  userId: number;
  email?: string;
  displayName?: string;
  isPro?: boolean;
  isNewUser?: boolean;
  signInMethod?: string;
  isDeviceAccount?: boolean;

  constructor(
    userId: number,
    email?: string,
    displayName?: string,
    isPro?: boolean,
    isNewUser?: boolean,
    signInMethod?: string,
    isDeviceAccount?: boolean
  ) {
    this.userId = userId;
    this.email = email;
    this.displayName = displayName;
    this.isPro = isPro;
    this.isNewUser = isNewUser;
    this.signInMethod = signInMethod;
    this.isDeviceAccount = isDeviceAccount;
  }
}

function mapLoginResult(data: Object | null): LoginResult {
  const obj = SupportAPIResponseDecoder.asRecord(data);
  return new LoginResult(
    SupportAPIResponseDecoder.numAny(obj, ['userId', 'user_id']),
    SupportAPIResponseDecoder.strAny(obj, ['accessToken', 'access_token', 'access']),
    SupportAPIResponseDecoder.strAny(obj, ['refreshToken', 'refresh_token', 'refresh']),
    SupportAPIResponseDecoder.numAny(obj, ['expiresIn', 'expires_in']),
    SupportAPIResponseDecoder.strAny(obj, ['tokenType', 'token_type'], 'Bearer')
  );
}

function mapAuthContext(data: Object | null, defaultSignIn: string, defaultDevice: boolean): AuthenticatedUserContext {
  const obj = SupportAPIResponseDecoder.asRecord(data);
  let tokens = SupportAPIResponseDecoder.tokensFromLogin(obj);
  const jwtExp = JWTExpParser.parseExpMs(tokens.accessToken);
  if (jwtExp !== undefined) {
    tokens.expiresAtMs = Math.min(tokens.expiresAtMs, jwtExp);
  }
  return new AuthenticatedUserContext(
    SupportAPIResponseDecoder.numAny(obj, ['userId', 'user_id']),
    tokens,
    SupportAPIResponseDecoder.boolAny(obj, ['isPro', 'is_pro'], false),
    SupportAPIResponseDecoder.boolAny(obj, ['isNewUser', 'is_new_user'], false),
    SupportAPIResponseDecoder.boolAny(obj, ['isDeviceAccount', 'is_device_account'], defaultDevice),
    SupportAPIResponseDecoder.optStr(obj, 'email'),
    SupportAPIResponseDecoder.optStrAny(obj, ['displayName', 'display_name']),
    SupportAPIResponseDecoder.optStrAny(obj, ['signInMethod', 'sign_in_method']) ?? defaultSignIn,
    SupportAPIResponseDecoder.optStrAny(obj, ['accountResolution', 'account_resolution'])
  );
}

export class AuthAPI {
  private readonly configuration: SupportBackendConfiguration;

  constructor(configuration: SupportBackendConfiguration) {
    this.configuration = configuration;
  }

  async passwordLogin(request: PasswordLoginRequest): Promise<LoginResult> {
    const body: PasswordLoginPayload = {
      identifier: request.identifier, password: request.password, bundle_id: request.bundleId, device_id: request.deviceId
    };
    const op = new CacheableSupportNetworkOperation(
      'Auth.PasswordLogin',
      'AuthAPI',
      new NetworkRequest('POST', '/api/v1/auth/password/login/', new NetworkStrategy(), [], {}, body)
    );
    const result = await this.configuration.executeDecoded(op, mapLoginResult);
    const tokens = new AuthTokens(
      result.accessToken,
      result.refreshToken,
      Date.now() + result.expiresIn * 1000,
      result.tokenType
    );
    const jwtExp = JWTExpParser.parseExpMs(tokens.accessToken);
    if (jwtExp !== undefined) {
      tokens.expiresAtMs = Math.min(tokens.expiresAtMs, jwtExp);
    }
    await this.configuration.engine.tokenProvider().setTokens(tokens);
    return result;
  }

  async appleLogin(request: AppleLoginRequest): Promise<AuthenticatedUserContext> {
    const body: AppleLoginPayload = {
      identity_token: request.identityToken,
      user: request.user,
      bundle_id: request.bundleId,
      device_id: request.deviceId,
      device_secret: request.deviceSecret
    };
    if (request.authorizationCode) {
      body.authorization_code = request.authorizationCode;
    }
    if (request.nonce) {
      body.nonce = request.nonce;
    }
    if (request.email) {
      body.email = request.email;
    }
    if (request.fullName) {
      body.full_name = request.fullName;
    }
    const op = new CacheableSupportNetworkOperation(
      'Auth.AppleLogin',
      'AuthAPI',
      new NetworkRequest('POST', '/api/v1/auth/apple/login/', new NetworkStrategy(), [], {}, body)
    );
    const ctx = await this.configuration.executeDecoded(op, (d) => mapAuthContext(d, 'apple', false));
    await this.configuration.engine.tokenProvider().setTokens(ctx.tokens);
    return ctx;
  }

  async deviceLogin(request: DeviceLoginRequest): Promise<AuthenticatedUserContext> {
    const body: DeviceLoginPayload = { bundle_id: request.bundleId, device_id: request.deviceId, device_secret: request.deviceSecret };
    const op = new CacheableSupportNetworkOperation(
      'Auth.DeviceLogin',
      'AuthAPI',
      new NetworkRequest('POST', '/api/v1/auth/device/login/', new NetworkStrategy(), [], {}, body)
    );
    const ctx = await this.configuration.executeDecoded(op, (d) => mapAuthContext(d, 'device', true));
    await this.configuration.engine.tokenProvider().setTokens(ctx.tokens);
    this.configuration.deviceCache.setAccountScope(`${ctx.userId}`);
    return ctx;
  }

  async currentSession(): Promise<CurrentSessionResult> {
    const op = new CacheableSupportNetworkOperation(
      'Auth.CurrentSession',
      'AuthAPI',
      new NetworkRequest(
        'GET',
        '/api/v1/auth/session/',
        new NetworkStrategy(true, false, undefined, true)
      )
    );
    return this.configuration.executeDecoded(op, (data) => {
      const obj = SupportAPIResponseDecoder.asRecord(data);
      return new CurrentSessionResult(
        SupportAPIResponseDecoder.numAny(obj, ['userId', 'user_id']),
        SupportAPIResponseDecoder.optStr(obj, 'email'),
        SupportAPIResponseDecoder.optStrAny(obj, ['displayName', 'display_name']),
        SupportAPIResponseDecoder.optBoolAny(obj, ['isPro', 'is_pro']),
        SupportAPIResponseDecoder.optBoolAny(obj, ['isNewUser', 'is_new_user']),
        SupportAPIResponseDecoder.optStrAny(obj, ['signInMethod', 'sign_in_method']),
        SupportAPIResponseDecoder.optBoolAny(obj, ['isDeviceAccount', 'is_device_account'])
      );
    });
  }

  async logout(): Promise<void> {
    const op = new CacheableSupportNetworkOperation(
      'Auth.Logout',
      'AuthAPI',
      new NetworkRequest(
        'POST',
        '/api/v1/auth/logout/',
        new NetworkStrategy(true, false, undefined, false, 'normal', RetryConfig.disabled())
      )
    );
    try {
      await this.configuration.execute(op);
    } catch (_e) {
      // 无论结果均本地清理
    }
    await this.configuration.engine.tokenProvider().clearTokens();
    await this.configuration.deviceCache.clearAllNonSensitive();
  }
}
