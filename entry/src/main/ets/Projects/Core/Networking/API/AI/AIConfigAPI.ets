import { NetworkRequest, NetworkStrategy, QueryItem, RetryConfig } from '../../SupportNetworkModels';
import { SupportBackendConfiguration } from '../../SupportBackendConfiguration';
import { CacheableSupportNetworkOperation } from '../../Operations/SupportNetworkOperation';
import { SupportAPIResponseDecoder } from '../Common/SupportAPIResponseDecoder';
import { AIConfigDecode } from '../../../../../Core/AI/Domain/AIConfigDecode';
import {
  AITrialStatus,
  ProBootstrapSnapshot
} from '../../../../../Core/AI/Domain/AIConfigModels';

interface TrialApplyPayload { note: string; }
interface ProviderConnectionPayload { request_url: string; api_key: string; model: string; }

export class AIConfigBootstrapResult extends ProBootstrapSnapshot {
}

export class AITrialStatusResult extends AITrialStatus {
}

export class AITrialApplyResult {
  submitted?: boolean;
  applicationId?: number;
  sequence?: number;
  status?: string;
  message?: string;
}

export class ProviderTestResult {
  ok?: boolean;
  reachable?: boolean;
  message?: string;

  get isReachable(): boolean {
    return this.reachable ?? this.ok ?? false;
  }
}

export class AIConfigAPI {
  private readonly configuration: SupportBackendConfiguration;

  constructor(configuration: SupportBackendConfiguration) {
    this.configuration = configuration;
  }

  async bootstrap(clientVersion?: string): Promise<AIConfigBootstrapResult> {
    const query: QueryItem[] = [new QueryItem('platform', 'harmonyos')];
    // client_version 必须来自真实包版本；缺省仍写入稳定默认值，避免无 query。
    const version = (clientVersion && clientVersion.length > 0) ? clientVersion : '1.0.0';
    query.push(new QueryItem('client_version', version));
    const op = new CacheableSupportNetworkOperation(
      'AIConfig.Bootstrap',
      'AIConfigAPI',
      new NetworkRequest(
        'GET',
        '/api/v1/ai/config/bootstrap/',
        new NetworkStrategy(true, true, 'ai.config.bootstrap', true, 'normal', RetryConfig.defaultConfig(), 60000),
        query
      )
    );
    return this.configuration.executeDecoded(op, (data) => {
      const decoded = AIConfigDecode.decodeBootstrap(data);
      const result = new AIConfigBootstrapResult();
      result.revision = decoded.revision;
      result.scenarios = decoded.scenarios;
      result.smallTasks = decoded.smallTasks;
      result.trialStatus = decoded.trialStatus;
      result.trialMessage = decoded.trialMessage;
      result.etag = decoded.etag;
      return result;
    });
  }

  async trialStatus(): Promise<AITrialStatusResult> {
    const op = new CacheableSupportNetworkOperation(
      'AI.TrialStatus',
      'AIConfigAPI',
      new NetworkRequest(
        'GET',
        '/api/v1/ai/trial/status/',
        new NetworkStrategy(true, false, 'ai.trial.status', true)
      )
    );
    return this.configuration.executeDecoded(op, (data) => {
      const decoded = AIConfigDecode.decodeTrialStatus(data);
      const result = new AITrialStatusResult();
      result.status = decoded.status;
      result.isActive = decoded.isActive;
      result.grantSource = decoded.grantSource;
      result.startedAt = decoded.startedAt;
      result.expiresAt = decoded.expiresAt;
      result.remainingSeconds = decoded.remainingSeconds;
      result.note = decoded.note;
      return result;
    });
  }

  async applyTrial(note: string): Promise<AITrialApplyResult> {
    const body: TrialApplyPayload = { note: note };
    const op = new CacheableSupportNetworkOperation(
      'AI.TrialApply',
      'AIConfigAPI',
      new NetworkRequest(
        'POST',
        '/api/v1/ai/trial/apply/',
        new NetworkStrategy(true, false, 'ai.trial.apply', false, 'high', RetryConfig.disabled()),
        [],
        {},
        body
      )
    );
    return this.configuration.executeDecoded(op, (data) => {
      const obj = SupportAPIResponseDecoder.asRecord(data);
      const r = new AITrialApplyResult();
      r.submitted = SupportAPIResponseDecoder.optBoolAny(obj, ['submitted']);
      r.applicationId = SupportAPIResponseDecoder.optNumAny(obj, ['applicationId', 'application_id']);
      r.sequence = SupportAPIResponseDecoder.optNumAny(obj, ['sequence']);
      r.status = SupportAPIResponseDecoder.optStrAny(obj, ['status']);
      r.message = SupportAPIResponseDecoder.optStrAny(obj, ['message']);
      return r;
    });
  }

  async testProviderConnection(requestUrl: string, apiKey: string, model: string): Promise<ProviderTestResult> {
    const body: ProviderConnectionPayload = { request_url: requestUrl, api_key: apiKey, model: model };
    const op = new CacheableSupportNetworkOperation(
      'AI.TestProvider',
      'AIConfigAPI',
      new NetworkRequest(
        'POST',
        '/api/v1/ai/providers/test-connection/',
        new NetworkStrategy(true, false, undefined, false, 'high', RetryConfig.disabled()),
        [],
        {},
        body
      )
    );
    return this.configuration.executeDecoded(op, (data) => {
      const obj = SupportAPIResponseDecoder.asRecord(data);
      const r = new ProviderTestResult();
      r.ok = SupportAPIResponseDecoder.optBool(obj, 'ok');
      r.reachable = SupportAPIResponseDecoder.optBool(obj, 'reachable');
      r.message = SupportAPIResponseDecoder.optStr(obj, 'message');
      return r;
    });
  }
}
