import { AuthTokens, NetworkRequest, NetworkStrategy } from '../../SupportNetworkModels';
import { SupportBackendConfiguration } from '../../SupportBackendConfiguration';
import { CacheableSupportNetworkOperation } from '../../Operations/SupportNetworkOperation';
import { SupportAPIResponseDecoder } from '../Common/SupportAPIResponseDecoder';
import { JWTExpParser } from '../../../../../Foundation/JWTExpParser';

interface PhoneOTPRequestPayload { phone_number: string; provider_uid: string; bundle_id: string; device_id: string; scene: string; user_id?: number; }
interface EmailOTPRequestPayload { email: string; provider_uid: string; bundle_id: string; device_id: string; scene: string; }
interface PhoneOTPVerifyPayload { otp_id: string; phone_number: string; code: string; bundle_id: string; device_id: string; device_secret: string; }
interface EmailOTPVerifyPayload { otp_id: string; email: string; code: string; bundle_id: string; device_id: string; device_secret: string; }

export class PhoneOTPRequest {
  phoneNumber: string;
  providerUid: string;
  bundleId: string;
  deviceId: string;
  scene: string;
  userId?: number;

  constructor(
    phoneNumber: string,
    bundleId: string,
    deviceId: string,
    scene: string = 'login',
    providerUid: string = '',
    userId?: number
  ) {
    this.phoneNumber = phoneNumber;
    this.bundleId = bundleId;
    this.deviceId = deviceId;
    this.scene = scene;
    this.providerUid = providerUid;
    this.userId = userId;
  }
}

export class EmailOTPRequest {
  email: string;
  providerUid: string;
  bundleId: string;
  deviceId: string;
  scene: string;

  constructor(email: string, bundleId: string, deviceId: string, scene: string = 'login', providerUid: string = '') {
    this.email = email;
    this.bundleId = bundleId;
    this.deviceId = deviceId;
    this.scene = scene;
    this.providerUid = providerUid;
  }
}

export class PhoneOTPVerifyRequest {
  otpId: string;
  phoneNumber: string;
  code: string;
  bundleId: string;
  deviceId: string;
  deviceSecret: string;

  constructor(
    otpId: string,
    phoneNumber: string,
    code: string,
    bundleId: string,
    deviceId: string,
    deviceSecret: string
  ) {
    this.otpId = otpId;
    this.phoneNumber = phoneNumber;
    this.code = code;
    this.bundleId = bundleId;
    this.deviceId = deviceId;
    this.deviceSecret = deviceSecret;
  }
}

export class EmailOTPVerifyRequest {
  otpId: string;
  email: string;
  code: string;
  bundleId: string;
  deviceId: string;
  deviceSecret: string;

  constructor(otpId: string, email: string, code: string, bundleId: string, deviceId: string, deviceSecret: string) {
    this.otpId = otpId;
    this.email = email;
    this.code = code;
    this.bundleId = bundleId;
    this.deviceId = deviceId;
    this.deviceSecret = deviceSecret;
  }
}

export class OTPRequestResponse {
  otpId: string;
  expiresIn?: number;

  constructor(otpId: string, expiresIn?: number) {
    this.otpId = otpId;
    this.expiresIn = expiresIn;
  }
}

export class PhoneOTPVerifyResult {
  userId: number;
  accessToken: string;
  refreshToken: string;
  expiresIn: number;
  tokenType: string;
  phoneNumber: string;
  otpId: string;
  displayName?: string;
  isPro?: boolean;
  isNewUser?: boolean;
  signInMethod?: string;
  isDeviceAccount?: boolean;
  accountResolution?: string;

  constructor(
    userId: number,
    accessToken: string,
    refreshToken: string,
    expiresIn: number,
    tokenType: string,
    phoneNumber: string,
    otpId: string
  ) {
    this.userId = userId;
    this.accessToken = accessToken;
    this.refreshToken = refreshToken;
    this.expiresIn = expiresIn;
    this.tokenType = tokenType;
    this.phoneNumber = phoneNumber;
    this.otpId = otpId;
  }
}

function needsAuthForScene(scene: string, userId?: number): boolean {
  if (userId !== undefined) {
    return true;
  }
  return scene === 'identity_bind' || scene === 'identity_change' || scene === 'account_deactivation';
}

export class OTPAPI {
  private readonly configuration: SupportBackendConfiguration;

  constructor(configuration: SupportBackendConfiguration) {
    this.configuration = configuration;
  }

  async requestPhoneOTP(request: PhoneOTPRequest): Promise<OTPRequestResponse> {
    const body: PhoneOTPRequestPayload = {
      phone_number: request.phoneNumber,
      provider_uid: request.providerUid,
      bundle_id: request.bundleId,
      device_id: request.deviceId,
      scene: request.scene
    };
    if (request.userId !== undefined) {
      body.user_id = request.userId;
    }
    const op = new CacheableSupportNetworkOperation(
      'OTP.PhoneRequest',
      'OTPAPI',
      new NetworkRequest(
        'POST',
        '/api/v1/otp/phone/request/',
        new NetworkStrategy(needsAuthForScene(request.scene, request.userId)),
        [],
        {},
        body
      )
    );
    return this.configuration.executeDecoded(op, (data) => {
      const obj = SupportAPIResponseDecoder.asRecord(data);
      return new OTPRequestResponse(
        SupportAPIResponseDecoder.strAny(obj, ['otpId', 'otp_id']),
        SupportAPIResponseDecoder.optNumAny(obj, ['expiresIn', 'expires_in'])
      );
    });
  }

  async requestEmailOTP(request: EmailOTPRequest): Promise<OTPRequestResponse> {
    const body: EmailOTPRequestPayload = { email: request.email, provider_uid: request.providerUid, bundle_id: request.bundleId, device_id: request.deviceId, scene: request.scene };
    const op = new CacheableSupportNetworkOperation(
      'OTP.EmailRequest',
      'OTPAPI',
      new NetworkRequest(
        'POST',
        '/api/v1/otp/email/request/',
        new NetworkStrategy(needsAuthForScene(request.scene)),
        [],
        {},
        body
      )
    );
    return this.configuration.executeDecoded(op, (data) => {
      const obj = SupportAPIResponseDecoder.asRecord(data);
      return new OTPRequestResponse(
        SupportAPIResponseDecoder.strAny(obj, ['otpId', 'otp_id']),
        SupportAPIResponseDecoder.optNumAny(obj, ['expiresIn', 'expires_in'])
      );
    });
  }

  async verifyPhoneOTP(request: PhoneOTPVerifyRequest): Promise<PhoneOTPVerifyResult> {
    const body: PhoneOTPVerifyPayload = { otp_id: request.otpId, phone_number: request.phoneNumber, code: request.code, bundle_id: request.bundleId, device_id: request.deviceId, device_secret: request.deviceSecret };
    const op = new CacheableSupportNetworkOperation(
      'OTP.PhoneVerify',
      'OTPAPI',
      new NetworkRequest('POST', '/api/v1/otp/phone/verify/', new NetworkStrategy(), [], {}, body)
    );
    const result = await this.configuration.executeDecoded(op, (data) => {
      const obj = SupportAPIResponseDecoder.asRecord(data);
      const r = new PhoneOTPVerifyResult(
        SupportAPIResponseDecoder.numAny(obj, ['userId', 'user_id']),
        SupportAPIResponseDecoder.strAny(obj, ['accessToken', 'access_token', 'access']),
        SupportAPIResponseDecoder.strAny(obj, ['refreshToken', 'refresh_token', 'refresh']),
        SupportAPIResponseDecoder.numAny(obj, ['expiresIn', 'expires_in']),
        SupportAPIResponseDecoder.strAny(obj, ['tokenType', 'token_type'], 'Bearer'),
        SupportAPIResponseDecoder.strAny(obj, ['phoneNumber', 'phone_number']),
        SupportAPIResponseDecoder.strAny(obj, ['otpId', 'otp_id'])
      );
      r.displayName = SupportAPIResponseDecoder.optStrAny(obj, ['displayName', 'display_name']);
      r.isPro = SupportAPIResponseDecoder.optBoolAny(obj, ['isPro', 'is_pro']);
      r.isNewUser = SupportAPIResponseDecoder.optBoolAny(obj, ['isNewUser', 'is_new_user']);
      r.signInMethod = SupportAPIResponseDecoder.optStrAny(obj, ['signInMethod', 'sign_in_method']);
      r.isDeviceAccount = SupportAPIResponseDecoder.optBoolAny(obj, ['isDeviceAccount', 'is_device_account']);
      r.accountResolution = SupportAPIResponseDecoder.optStrAny(obj, ['accountResolution', 'account_resolution']);
      return r;
    });
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
    this.configuration.deviceCache.setAccountScope(`${result.userId}`);
    return result;
  }

  async verifyEmailOTP(request: EmailOTPVerifyRequest): Promise<AuthTokens> {
    const body: EmailOTPVerifyPayload = { otp_id: request.otpId, email: request.email, code: request.code, bundle_id: request.bundleId, device_id: request.deviceId, device_secret: request.deviceSecret };
    const op = new CacheableSupportNetworkOperation(
      'OTP.EmailVerify',
      'OTPAPI',
      new NetworkRequest('POST', '/api/v1/otp/email/verify/', new NetworkStrategy(), [], {}, body)
    );
    const tokens = await this.configuration.executeDecoded(op, (data) => {
      const obj = SupportAPIResponseDecoder.asRecord(data);
      return SupportAPIResponseDecoder.tokensFromLogin(obj);
    });
    const jwtExp = JWTExpParser.parseExpMs(tokens.accessToken);
    if (jwtExp !== undefined) {
      tokens.expiresAtMs = Math.min(tokens.expiresAtMs, jwtExp);
    }
    await this.configuration.engine.tokenProvider().setTokens(tokens);
    return tokens;
  }
}
