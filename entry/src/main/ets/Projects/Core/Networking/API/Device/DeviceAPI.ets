import {
  NetworkRequest,
  NetworkStrategy,
  RetryConfig
} from '../../SupportNetworkModels';
import { SupportBackendConfiguration } from '../../SupportBackendConfiguration';
import { CacheableSupportNetworkOperation } from '../../Operations/SupportNetworkOperation';
import { SupportAPIResponseDecoder } from '../Common/SupportAPIResponseDecoder';

/** 对齐 SparkService DeviceRegisterSerializer（snake_case）。 */
export class DeviceRegistrationRequest {
  device_id: string = '';
  user_id?: number;
  push_token: string = '';
  notifications_enabled: boolean = false;
  app_version: string = '';
  build_version: string = '';
  bundle_identifier: string = '';
  bundle_id: string = '';
  platform: string = 'harmonyos';
  system_version: string = '';
  device_model: string = '';
  device_model_name: string = '';
  device_name: string = '';
  screen_size: string = '';
  screen_scale?: number;
  time_zone: string = '';
  language_code: string = '';
  region_code: string = '';
  country_code: string = '';
  is_simulator: boolean = false;
}

export class DeviceRegistrationResponse {
  deviceId?: string;
  userId?: number;
  registered?: boolean;
  created?: boolean;
  bundleId?: string;
}

/**
 * 可注入的设备登记客户端（单测 fake / 真实 DeviceAPI）。
 */
export abstract class DeviceRegisterClient {
  abstract register(
    request: DeviceRegistrationRequest,
    authenticated: boolean
  ): Promise<DeviceRegistrationResponse>;
}

/**
 * POST /api/v1/device/register/
 */
export class DeviceAPI extends DeviceRegisterClient {
  private readonly configuration: SupportBackendConfiguration;

  constructor(configuration: SupportBackendConfiguration) {
    super();
    this.configuration = configuration;
  }

  async register(request: DeviceRegistrationRequest, authenticated: boolean): Promise<DeviceRegistrationResponse> {
    const strategy = new NetworkStrategy(
      authenticated,
      false,
      authenticated ? 'device.register.auth' : 'device.register.guest',
      false,
      'normal',
      RetryConfig.disabled()
    );
    const op = new CacheableSupportNetworkOperation(
      'Device.Register',
      'DeviceAPI',
      new NetworkRequest('POST', '/api/v1/device/register/', strategy, [], {}, request)
    );
    return this.configuration.executeDecoded(op, (data: Object | null) => {
      return DeviceAPI.decodeResponse(data as Object);
    });
  }

  /** 解码服务端 data；兼容 created / registered、snake/camel。 */
  static decodeResponse(data: Object | null): DeviceRegistrationResponse {
    const obj = SupportAPIResponseDecoder.asRecord(data as Object);
    const r = new DeviceRegistrationResponse();
    r.deviceId = SupportAPIResponseDecoder.optStr(obj, 'device_id')
      ?? SupportAPIResponseDecoder.optStr(obj, 'deviceId');
    r.bundleId = SupportAPIResponseDecoder.optStr(obj, 'bundle_id')
      ?? SupportAPIResponseDecoder.optStr(obj, 'bundleId');
    const uid = SupportAPIResponseDecoder.optNum(obj, 'user_id')
      ?? SupportAPIResponseDecoder.optNum(obj, 'userId');
    if (uid !== undefined) {
      r.userId = uid;
    }
    const created = obj['created'];
    if (typeof created === 'boolean') {
      r.created = created;
    }
    const reg = obj['registered'];
    if (typeof reg === 'boolean') {
      r.registered = reg;
    } else if (r.created === true) {
      r.registered = true;
    } else if (r.created === false) {
      r.registered = false;
    }
    return r;
  }
}
