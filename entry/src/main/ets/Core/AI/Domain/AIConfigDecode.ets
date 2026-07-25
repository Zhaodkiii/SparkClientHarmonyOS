import { SupportAPIResponseDecoder } from '../../../Projects/Core/Networking/API/Common/SupportAPIResponseDecoder';
import {
  AITrialStatus,
  ModelCapabilities,
  ProBootstrapSnapshot,
  ProScenarioBundle,
  ProScenarioModelRow,
  ProSmallTask,
  AIScenario
} from './AIConfigModels';

type JsonRec = Record<string, Object | string | number | boolean | null>;

/**
 * SparkService AI bootstrap / trial 解码。
 * 兼容 snake_case 与 camelCase；未知字段忽略；未知 scenario 保留并记诊断。
 */
export class AIConfigDecode {
  static lastUnknownScenarios: string[] = [];

  static decodeBootstrap(data: Object | null): ProBootstrapSnapshot {
    AIConfigDecode.lastUnknownScenarios = [];
    const obj = SupportAPIResponseDecoder.asRecord(data);
    const snap = new ProBootstrapSnapshot();
    snap.revision = SupportAPIResponseDecoder.strAny(obj, ['revision'], '');
    snap.trialMessage = SupportAPIResponseDecoder.optStrAny(obj, ['trialMessage', 'trial_message']);
    const trialRaw = obj['trialStatus'] ?? obj['trial_status'];
    if (trialRaw && typeof trialRaw === 'object') {
      snap.trialStatus = AIConfigDecode.decodeTrialStatus(trialRaw as Object);
    }
    snap.scenarios = AIConfigDecode.decodeScenarios(obj['scenarios']);
    snap.smallTasks = AIConfigDecode.decodeSmallTasks(obj['smallTasks'] ?? obj['small_tasks']);
    return snap;
  }

  static decodeTrialStatus(data: Object | null): AITrialStatus {
    const obj = SupportAPIResponseDecoder.asRecord(data);
    const t = new AITrialStatus();
    t.status = SupportAPIResponseDecoder.optStrAny(obj, ['status']);
    t.isActive = SupportAPIResponseDecoder.optBoolAny(obj, ['isActive', 'is_active']);
    t.grantSource = SupportAPIResponseDecoder.optStrAny(obj, ['grantSource', 'grant_source']);
    t.startedAt = SupportAPIResponseDecoder.optStrAny(obj, ['startedAt', 'started_at']);
    t.expiresAt = SupportAPIResponseDecoder.optStrAny(obj, ['expiresAt', 'expires_at']);
    t.remainingSeconds = SupportAPIResponseDecoder.optNumAny(obj, ['remainingSeconds', 'remaining_seconds']);
    t.note = SupportAPIResponseDecoder.optStrAny(obj, ['note']);
    return t;
  }

  private static decodeScenarios(raw: Object | string | number | boolean | null | undefined): ProScenarioBundle[] {
    const out: ProScenarioBundle[] = [];
    if (!raw || typeof raw !== 'object' || Array.isArray(raw)) {
      return out;
    }
    const map = raw as Record<string, Object>;
    const keys = Object.keys(map);
    for (let i = 0; i < keys.length; i++) {
      const scenario = keys[i];
      if (!AIScenario.isKnown(scenario)) {
        AIConfigDecode.lastUnknownScenarios.push(scenario);
      }
      const block = map[scenario];
      const bundle = new ProScenarioBundle();
      bundle.scenario = scenario;
      if (!block || typeof block !== 'object') {
        out.push(bundle);
        continue;
      }
      // 兼容错误文档形态：直接数组
      if (Array.isArray(block)) {
        bundle.models = AIConfigDecode.decodeModelRows(block as Object[]);
        if (bundle.models.length > 0) {
          let defaultName = bundle.models[0].name;
          for (let mi = 0; mi < bundle.models.length; mi++) {
            if (bundle.models[mi].isDefault) {
              defaultName = bundle.models[mi].name;
              break;
            }
          }
          bundle.defaultModel = defaultName;
        }
        out.push(bundle);
        continue;
      }
      const rec = SupportAPIResponseDecoder.asRecord(block as Object);
      bundle.defaultModel = SupportAPIResponseDecoder.strAny(rec, ['defaultModel', 'default_model'], '');
      const modelsRaw = rec['models'];
      if (Array.isArray(modelsRaw)) {
        bundle.models = AIConfigDecode.decodeModelRows(modelsRaw as Object[]);
      }
      out.push(bundle);
    }
    return out;
  }

  private static decodeModelRows(rows: Object[]): ProScenarioModelRow[] {
    const out: ProScenarioModelRow[] = [];
    for (let i = 0; i < rows.length; i++) {
      const row = rows[i];
      if (!row || typeof row !== 'object') {
        continue;
      }
      out.push(AIConfigDecode.decodeModelRow(SupportAPIResponseDecoder.asRecord(row)));
    }
    return out;
  }

  private static decodeModelRow(obj: JsonRec): ProScenarioModelRow {
    const m = new ProScenarioModelRow();
    m.name = SupportAPIResponseDecoder.strAny(obj, ['name'], '');
    m.displayName = SupportAPIResponseDecoder.strAny(obj, ['displayName', 'display_name'], m.name);
    m.identity = SupportAPIResponseDecoder.strAny(obj, ['identity'], 'model');
    m.baseModelName = SupportAPIResponseDecoder.optStrAny(obj, ['baseModelName', 'base_model_name']);
    m.company = SupportAPIResponseDecoder.strAny(obj, ['company'], '');
    m.endpoint = SupportAPIResponseDecoder.optStrAny(obj, ['endpoint', 'requestUrl', 'request_url']);
    const key = SupportAPIResponseDecoder.optStrAny(obj, ['apiKey', 'api_key', 'key']);
    if (key && key.length > 0) {
      m.apiKey = key;
    }
    m.capabilities = ModelCapabilities.fromRecord(obj);
    m.priceTier = SupportAPIResponseDecoder.optStrAny(obj, ['priceTier', 'price_tier']);
    m.systemProvision = SupportAPIResponseDecoder.optStrAny(obj, ['systemProvision', 'system_provision']);
    m.icon = SupportAPIResponseDecoder.optStrAny(obj, ['icon']);
    m.briefDescription = SupportAPIResponseDecoder.optStrAny(obj, ['briefDescription', 'brief_description']);
    m.aiScenarios = AIConfigDecode.stringList(obj['aiScenarios'] ?? obj['ai_scenarios']);
    m.aiToolScenarios = AIConfigDecode.stringList(obj['aiToolScenarios'] ?? obj['ai_tool_scenarios']);
    m.relatedTaskCodes = AIConfigDecode.stringList(obj['relatedTaskCodes'] ?? obj['related_task_codes']);
    m.source = SupportAPIResponseDecoder.strAny(obj, ['source'], 'pro');
    m.isDefault = SupportAPIResponseDecoder.boolAny(obj, ['isDefault', 'is_default'], false);
    m.temperature = SupportAPIResponseDecoder.optNumAny(obj, ['temperature']);
    m.maxTokens = SupportAPIResponseDecoder.optNumAny(obj, ['maxTokens', 'max_tokens']);
    m.isTrial = SupportAPIResponseDecoder.boolAny(obj, ['isTrial', 'is_trial'], false);
    return m;
  }

  private static decodeSmallTasks(raw: Object | string | number | boolean | null | undefined): ProSmallTask[] {
    const out: ProSmallTask[] = [];
    if (!Array.isArray(raw)) {
      return out;
    }
    const arr = raw as Object[];
    for (let i = 0; i < arr.length; i++) {
      const item = arr[i];
      if (!item || typeof item !== 'object') {
        continue;
      }
      const obj = SupportAPIResponseDecoder.asRecord(item);
      const t = new ProSmallTask();
      t.code = SupportAPIResponseDecoder.strAny(obj, ['code'], '');
      t.name = SupportAPIResponseDecoder.strAny(obj, ['name'], t.code);
      t.brief = SupportAPIResponseDecoder.optStrAny(obj, ['brief']);
      t.prompt = SupportAPIResponseDecoder.strAny(obj, ['prompt'], '');
      t.icon = SupportAPIResponseDecoder.optStrAny(obj, ['icon']);
      t.toolList = AIConfigDecode.stringList(obj['toolList'] ?? obj['tool_list']);
      t.source = SupportAPIResponseDecoder.strAny(obj, ['source'], 'Service');
      t.isDeleted = SupportAPIResponseDecoder.boolAny(obj, ['isDeleted', 'is_deleted'], false);
      if (t.code.length > 0) {
        out.push(t);
      }
    }
    return out;
  }

  private static stringList(raw: Object | string | number | boolean | null | undefined): string[] {
    if (!Array.isArray(raw)) {
      return [];
    }
    const arr = raw as Object[];
    const out: string[] = [];
    for (let i = 0; i < arr.length; i++) {
      const v = arr[i];
      if (v !== null && v !== undefined) {
        out.push(`${v}`);
      }
    }
    return out;
  }
}
