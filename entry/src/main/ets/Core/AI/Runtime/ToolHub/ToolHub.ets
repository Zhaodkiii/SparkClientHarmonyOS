import { AIRuntimeToolDefinition } from '../../Domain/AIConfigModels';
import {
  allSparkToolNames,
  DEBUG_ECHO_TOOL_NAME,
  SparkToolName,
  sparkToolNameFromRaw,
  isKnowledgeTool,
  isWebSearchTool
} from './Models/SparkToolName';
import {
  ToolAuditStatus,
  ToolAuditEvent,
  ToolExecutionContext,
  ToolExecutionResult,
  ToolHubRunResult,
  ToolInteractionCoordinating,
  ToolInvocation,
  ToolSideEffectRecord
} from './Models/ToolingModels';
import { ToolAuditStore } from './Audit/ToolAuditStore';
import { AppleHealthToolConsentPolicy } from './Consent/AppleHealthToolConsentPolicy';
import { HealthUnavailableExecutors } from './Executors/HealthUnavailableExecutors';
import { ToolSideEffect, ToolSideEffectSink } from './ToolSideEffectSink';
import { Logger } from '../../../../Foundation/Logging/Logger';
import { LogModule } from '../../../../Foundation/Logging/LogModule';
import { LogFields } from '../../../../Foundation/Logging/LogEvent';
import { PromptLocalizer } from '../PromptLocalizer';

class MedicalRiskNoticePayload {
  riskLevel: string = '';
  message: string = '';
}

/**
 * 对齐 iOS ToolHub：Schema / 路由 / Consent / 审计 / 执行。
 * 系统健康读取：鸿蒙端默认明确返回未接入，不伪造设备健康数据。
 */
export class ToolHub {
  private readonly auditStore: ToolAuditStore;
  private readonly consentPolicy: AppleHealthToolConsentPolicy;
  private readonly sideEffects: ToolSideEffectSink;
  private readonly localizer: PromptLocalizer = new PromptLocalizer();
  private toolInteractionCoordinator?: ToolInteractionCoordinating;
  /** 内存画布：标题 → 正文 */
  readonly canvasStore: Map<string, string> = new Map();

  constructor(
    auditStore?: ToolAuditStore,
    consentPolicy?: AppleHealthToolConsentPolicy,
    sideEffects?: ToolSideEffectSink,
    coordinator?: ToolInteractionCoordinating
  ) {
    this.auditStore = auditStore ?? new ToolAuditStore();
    this.consentPolicy = consentPolicy ?? new AppleHealthToolConsentPolicy();
    this.sideEffects = sideEffects ?? new ToolSideEffectSink();
    this.toolInteractionCoordinator = coordinator;
  }

  configureAuditPersistence(handler: (event: ToolAuditEvent) => Promise<void>): void {
    this.auditStore.setPersistence(handler);
  }

  get sink(): ToolSideEffectSink {
    return this.sideEffects;
  }

  get audits(): ToolAuditStore {
    return this.auditStore;
  }

  setInteractionCoordinator(coordinator: ToolInteractionCoordinating | undefined): void {
    this.toolInteractionCoordinator = coordinator;
  }

  async runIfNeeded(
    userInput: string,
    memberID: number | undefined,
    allowedToolNames: string[] | undefined,
    threadID: string | undefined
  ): Promise<ToolHubRunResult> {
    const trimmed = userInput.trim();
    if (trimmed.length === 0) {
      return ToolHubRunResult.none();
    }
    if (trimmed === '/audit_tools') {
      return ToolHubRunResult.executed(await this.handleAuditTools());
    }
    const invocation = this.parseToolInvocation(trimmed);
    if (!invocation) {
      return ToolHubRunResult.none();
    }
    if (allowedToolNames && allowedToolNames.length > 0) {
      let allowed = false;
      const want = ToolHub.normalizeToolName(invocation.name);
      for (let i = 0; i < allowedToolNames.length; i++) {
        if (ToolHub.normalizeToolName(allowedToolNames[i]) === want) {
          allowed = true;
          break;
        }
      }
      if (!allowed) {
        return ToolHubRunResult.none();
      }
    }
    const context = new ToolExecutionContext();
    context.memberID = memberID;
    context.threadID = threadID;
    const result = await this.execute(invocation, context);
    this.appendAudit(invocation, context, result);
    return ToolHubRunResult.executed(result);
  }

  async executeToolCall(
    name: string,
    argumentsJson: string,
    memberID: number | undefined,
    threadID: string | undefined,
    toolCallId?: string,
    assistantMessageClientId?: string,
    requestId?: string,
    providerCompany?: string,
    modelName?: string,
    endpoint?: string,
    privacyPolicyURL?: string,
    accountId: number = 0
  ): Promise<ToolExecutionResult> {
    const invocation = new ToolInvocation();
    invocation.name = name;
    invocation.arguments = this.parseArguments(argumentsJson);
    const context = new ToolExecutionContext();
    context.memberID = memberID;
    context.threadID = threadID;
    context.assistantMessageClientID = assistantMessageClientId;
    context.pendingToolCallID = toolCallId;
    context.requestId = requestId;
    context.providerCompany = providerCompany;
    context.modelName = modelName;
    context.endpoint = endpoint;
    context.privacyPolicyURL = privacyPolicyURL;
    context.accountID = accountId;

    let result = await this.execute(invocation, context);
    result = await this.applyModelEgressConsentIfNeeded(invocation, context, result);
    result = result
      .withToolCallID(toolCallId)
      .withAnchorToolCallID(toolCallId)
      .withInvocationArgumentsIfMissing(invocation.arguments);
    this.appendAudit(invocation, context, result);
    this.emitChatSideEffects(result, toolCallId, assistantMessageClientId, accountId);
    return result;
  }

  listToolDefinitions(
    allowedToolNames: string[] | undefined,
    useKnowledgeBag: boolean = true,
    useWebSearch: boolean = true
  ): AIRuntimeToolDefinition[] {
    const defs = this.buildAllDefinitions();
    const out: AIRuntimeToolDefinition[] = [];
    for (let i = 0; i < defs.length; i++) {
      const name = defs[i].name;
      if (!useKnowledgeBag && isKnowledgeTool(name)) {
        continue;
      }
      if (!useWebSearch && isWebSearchTool(name)) {
        continue;
      }
      if (allowedToolNames && allowedToolNames.length > 0) {
        let ok = false;
        const want = ToolHub.normalizeToolName(name);
        for (let j = 0; j < allowedToolNames.length; j++) {
          if (ToolHub.normalizeToolName(allowedToolNames[j]) === want) {
            ok = true;
            break;
          }
        }
        if (!ok) {
          continue;
        }
      }
      out.push(defs[i]);
    }
    return out;
  }

  private async handleAuditTools(): Promise<ToolExecutionResult> {
    const text = this.auditStore.summaryText();
    const names = allSparkToolNames().concat([DEBUG_ECHO_TOOL_NAME]);
    const header = `已注册工具（${names.length}）：\n${names.join('\n')}\n\n`;
    return ToolExecutionResult.make('audit_tools', header + text, false, true);
  }

  parseToolInvocation(input: string): ToolInvocation | undefined {
    if (input === '/tool list') {
      const inv = new ToolInvocation();
      inv.name = 'tool_list';
      return inv;
    }
    if (input.startsWith('/tool ')) {
      const remainder = input.substring(6).trim();
      if (remainder.length === 0) {
        return undefined;
      }
      const spaceIdx = remainder.indexOf(' ');
      const name = spaceIdx < 0 ? remainder : remainder.substring(0, spaceIdx);
      const inv = new ToolInvocation();
      inv.name = name;
      if (spaceIdx >= 0) {
        inv.arguments = this.parseArguments(remainder.substring(spaceIdx + 1));
      }
      return inv;
    }
    return undefined;
  }

  parseArguments(raw: string): Record<string, string> {
    const trimmed = raw.trim();
    const empty: Record<string, string> = {};
    if (trimmed.length === 0) {
      return empty;
    }
    if (trimmed.startsWith('{')) {
      try {
        const parsed: Object = JSON.parse(trimmed) as Object;
        return this.flattenJSONObject(parsed as Record<string, Object>);
      } catch (_err) {
        // fallthrough
      }
    }
    const args: Record<string, string> = {};
    const parts = trimmed.split(' ');
    for (let i = 0; i < parts.length; i++) {
      const part = parts[i];
      const eq = part.indexOf('=');
      if (eq > 0) {
        args[part.substring(0, eq)] = part.substring(eq + 1);
      }
    }
    if (Object.keys(args).length === 0) {
      args['query'] = trimmed;
      args['content'] = trimmed;
      args['title'] = trimmed.substring(0, Math.min(20, trimmed.length));
      args['raw_text'] = trimmed;
    }
    return args;
  }

  flattenJSONObject(obj: Record<string, Object>): Record<string, string> {
    const out: Record<string, string> = {};
    const keys = Object.keys(obj);
    for (let i = 0; i < keys.length; i++) {
      const key = keys[i];
      const value = obj[key];
      if (value === null || value === undefined) {
        continue;
      }
      if (typeof value === 'object' && !Array.isArray(value)) {
        const inner = this.flattenJSONObject(value as Record<string, Object>);
        const innerKeys = Object.keys(inner);
        for (let j = 0; j < innerKeys.length; j++) {
          out[`${key}.${innerKeys[j]}`] = inner[innerKeys[j]];
        }
      } else if (Array.isArray(value)) {
        out[key] = JSON.stringify(value);
      } else if (typeof value === 'boolean') {
        out[key] = value ? 'true' : 'false';
      } else {
        out[key] = `${value}`;
      }
    }
    return out;
  }

  async execute(invocation: ToolInvocation, context: ToolExecutionContext): Promise<ToolExecutionResult> {
    if (invocation.name === 'tool_list') {
      const names = allSparkToolNames().concat([DEBUG_ECHO_TOOL_NAME]);
      return ToolExecutionResult.make(
        'tool_list',
        `已接入工具（${names.length}）：\n${names.join('\n')}`,
        false,
        true
      );
    }
    if (invocation.name === DEBUG_ECHO_TOOL_NAME) {
      const message = invocation.arguments['message'] ?? '';
      return ToolExecutionResult.make(
        DEBUG_ECHO_TOOL_NAME,
        message.length > 0 ? message : 'debug_echo: empty message',
        false,
        true
      );
    }

    const tool = sparkToolNameFromRaw(invocation.name);
    if (!tool) {
      return ToolExecutionResult.make(invocation.name, `未识别工具：${invocation.name}`, false, true);
    }

    switch (tool) {
      case SparkToolName.FETCH_STEP_DETAILS:
      case SparkToolName.FETCH_ENERGY_DETAILS:
      case SparkToolName.FETCH_NUTRITION_DETAILS:
      case SparkToolName.FETCH_SLEEP_DETAILS:
      case SparkToolName.FETCH_WORKOUT_DETAILS:
      case SparkToolName.MAKE_NUTRITION_DATA:
        return HealthUnavailableExecutors.run(tool);
      case SparkToolName.CREATE_CANVAS:
        return this.runCreateCanvas(invocation);
      case SparkToolName.EDIT_CANVAS:
        return this.runEditCanvas(invocation);
      case SparkToolName.GENERATE_CHAT_TITLE:
        return ToolExecutionResult.make(
          tool,
          `建议标题：健康咨询 ${new Date().toISOString().substring(0, 10)}`,
          false,
          true
        );
      case SparkToolName.GET_CURRENT_MEMBER:
        return ToolExecutionResult.make(
          tool,
          context.memberID !== undefined
            ? `当前成员 ID=${context.memberID}`
            : '当前未选择成员',
          false,
          false
        );
      case SparkToolName.SHOW_MEDICAL_RISK_NOTICE: {
        const level = invocation.arguments['risk_level'] ?? 'medium';
        const message = invocation.arguments['message'] ?? '请结合专业医疗建议理解本结果。';
        const side = new ToolSideEffectRecord();
        side.type = 'medicalRiskNotice';
        side.text = message;
        const riskPayload = new MedicalRiskNoticePayload();
        riskPayload.riskLevel = level;
        riskPayload.message = message;
        side.jsonPayload = JSON.stringify(riskPayload);
        return ToolExecutionResult.make(tool, `已插入医疗风险提示（${level}）`, false, true, false, [side]);
      }
      default:
        return this.unsupported(tool, '鸿蒙端尚未接入该业务能力，未执行写入或网络副作用。');
    }
  }

  private runCreateCanvas(invocation: ToolInvocation): ToolExecutionResult {
    const title = invocation.arguments['title'] ?? '未命名画布';
    const content = invocation.arguments['content'] ?? '';
    this.canvasStore.set(title, content);
    return ToolExecutionResult.make(SparkToolName.CREATE_CANVAS, `已创建画布《${title}》`, false, true);
  }

  private runEditCanvas(invocation: ToolInvocation): ToolExecutionResult {
    const title = invocation.arguments['title'] ?? '';
    const current = this.canvasStore.get(title) ?? '';
    this.canvasStore.set(title, current);
    return ToolExecutionResult.make(SparkToolName.EDIT_CANVAS, `已更新画布《${title}》`, false, true);
  }

  private placeholder(tool: string, text: string): ToolExecutionResult {
    return ToolExecutionResult.make(tool, `[${tool}] ${text}`, false, true, false);
  }

  private unsupported(tool: string, text: string): ToolExecutionResult {
    return ToolExecutionResult.make(tool, `[${tool}] ${text}`, false, true, false);
  }

  private async applyModelEgressConsentIfNeeded(
    invocation: ToolInvocation,
    context: ToolExecutionContext,
    result: ToolExecutionResult
  ): Promise<ToolExecutionResult> {
    if (!this.consentPolicy.requiresConsent(result, context.providerCompany)) {
      return result;
    }
    if (!this.toolInteractionCoordinator) {
      const f = new LogFields();
      f.detail = `Consent 无 Coordinator，阻止 tool=${result.toolName}`;
      Logger.warn('ai.tool.consent_blocked', LogModule.AI_CONFIG, f);
      return this.modelEgressDeniedResult(result.toolName, '授权交互未装配，已阻止敏感工具结果发送给第三方模型。');
    }
    const callArguments = JSON.stringify(invocation.arguments);
    const decision = await this.toolInteractionCoordinator.requestConsentDecision(
      context.threadID,
      result,
      callArguments,
      context.providerCompany,
      context.modelName,
      context.endpoint,
      context.privacyPolicyURL
    );
    if (decision.kind === 'success' && decision.decision) {
      if (!decision.decision.allowed) {
        return this.modelEgressDeniedResult(result.toolName, '用户未授权将该工具结果发送给第三方模型。');
      }
      if (decision.decision.rememberTool) {
        this.consentPolicy.rememberAllowed(result.toolName);
      }
      return result;
    }
    if (decision.kind === 'conflict') {
      return this.modelEgressDeniedResult(result.toolName, '授权交互繁忙，已阻止敏感工具结果发送给模型。');
    }
    return this.modelEgressDeniedResult(result.toolName, '用户未授权将该工具结果发送给第三方模型。');
  }

  private modelEgressDeniedResult(toolName: string, reason: string): ToolExecutionResult {
    return ToolExecutionResult.make(toolName, this.localizer.consentBlockedHint(reason), false, true);
  }

  private appendAudit(
    invocation: ToolInvocation,
    context: ToolExecutionContext,
    result: ToolExecutionResult
  ): void {
    const lower = result.outputText.toLowerCase();
    const status = (lower.indexOf('阻止') >= 0 || lower.indexOf('未授权') >= 0 || lower.indexOf('consent') >= 0)
      ? ToolAuditStatus.DENIED
      : (lower.indexOf('失败') >= 0 || lower.indexOf('fail') >= 0)
        ? ToolAuditStatus.FAILED
        : ToolAuditStatus.SUCCESS;
    const input = JSON.stringify(invocation.arguments);
    this.auditStore.record(
      invocation.name,
      status,
      input,
      result.outputText,
      context.memberID,
      context.requestId,
      context.threadID,
      context.accountID
    );
  }

  private emitChatSideEffects(
    result: ToolExecutionResult,
    toolCallId: string | undefined,
    assistantMessageClientId: string | undefined,
    accountId: number
  ): void {
    const effect = new ToolSideEffect();
    effect.kind = 'chatBlock';
    effect.toolName = result.toolName;
    effect.toolCallId = toolCallId ?? '';
    effect.text = result.outputText;
    effect.assistantMessageClientId = assistantMessageClientId;
    effect.accountId = accountId;
    this.sideEffects.emit(effect);
    for (let i = 0; i < result.sideEffects.length; i++) {
      const item = result.sideEffects[i];
      const se = new ToolSideEffect();
      se.kind = item.type;
      se.toolName = result.toolName;
      se.toolCallId = toolCallId ?? '';
      se.text = item.text ?? item.jsonPayload ?? '';
      se.assistantMessageClientId = assistantMessageClientId;
      se.accountId = accountId;
      this.sideEffects.emit(se);
    }
  }

  private buildAllDefinitions(): AIRuntimeToolDefinition[] {
    const list: AIRuntimeToolDefinition[] = [];
    const echo = new AIRuntimeToolDefinition();
    echo.name = DEBUG_ECHO_TOOL_NAME;
    echo.summary = '回显受控 message 字段，用于 Runtime/ToolHub 联调';
    echo.parametersJson =
      '{"type":"object","properties":{"message":{"type":"string","description":"回显文本"}},"required":["message"]}';
    list.push(echo);

    const names = allSparkToolNames();
    for (let i = 0; i < names.length; i++) {
      const name = names[i];
      const d = new AIRuntimeToolDefinition();
      d.name = name;
      d.summary = this.toolSummary(name);
      d.parametersJson = this.parametersJsonFor(name);
      list.push(d);
    }
    return list;
  }

  private toolSummary(toolName: string): string {
    const key = `tool.summary.${toolName}`;
    return this.localizer.toolText(key, `工具 ${toolName}`);
  }

  private parametersJsonFor(toolName: string): string {
    const tool = sparkToolNameFromRaw(toolName);
    if (!tool) {
      return '{"type":"object","properties":{"query":{"type":"string"}}}';
    }
    switch (tool) {
      case SparkToolName.FETCH_STEP_DETAILS:
      case SparkToolName.FETCH_ENERGY_DETAILS:
      case SparkToolName.FETCH_NUTRITION_DETAILS:
      case SparkToolName.FETCH_SLEEP_DETAILS:
        return '{"type":"object","properties":{"start_date":{"type":"string","format":"date"},"end_date":{"type":"string","format":"date"}},"required":["start_date","end_date"]}';
      case SparkToolName.FETCH_WORKOUT_DETAILS:
        return '{"type":"object","properties":{"start_date":{"type":"string","format":"date"},"end_date":{"type":"string","format":"date"},"types":{"type":"array","items":{"type":"string"}},"max_items":{"type":"integer"}},"required":["start_date","end_date"]}';
      case SparkToolName.MAKE_NUTRITION_DATA:
        return '{"type":"object","properties":{"protein":{"type":"number"},"carbohydrates":{"type":"number"},"fat":{"type":"number"},"energy":{"type":"number"}},"required":["protein","carbohydrates","fat","energy"]}';
      case SparkToolName.GENERATE_STRUCTURED_HEALTH_CARD:
        return '{"type":"object","properties":{"report_type":{"type":"string"},"raw_text":{"type":"string"}},"required":["report_type","raw_text"]}';
      case SparkToolName.GET_HEALTH_RESOURCE_REFERENCE:
        return '{"type":"object","properties":{"resource_type":{"type":"string"},"resource_id":{"type":"integer"}},"required":["resource_type","resource_id"]}';
      case SparkToolName.SEARCH_KNOWLEDGE_BAG:
      case SparkToolName.SEARCH_ONLINE:
      case SparkToolName.SEARCH_ARXIV_PAPERS:
        return '{"type":"object","properties":{"query":{"type":"string"}},"required":["query"]}';
      case SparkToolName.CREATE_KNOWLEDGE_DOCUMENT:
        return '{"type":"object","properties":{"title":{"type":"string"},"content":{"type":"string"}},"required":["title","content"]}';
      case SparkToolName.READ_WEB_PAGE:
      case SparkToolName.EXTRACT_REMOTE_FILE_CONTENT:
        return '{"type":"object","properties":{"url":{"type":"string"}},"required":["url"]}';
      case SparkToolName.CREATE_CANVAS:
        return '{"type":"object","properties":{"title":{"type":"string"},"content":{"type":"string"},"type":{"type":"string"}},"required":["title","content","type"]}';
      case SparkToolName.EDIT_CANVAS:
        return '{"type":"object","properties":{"title":{"type":"string"},"patterns":{"type":"array","items":{"type":"string"}},"replacements":{"type":"array","items":{"type":"string"}}},"required":["patterns","replacements"]}';
      case SparkToolName.SHOW_MEDICAL_RISK_NOTICE:
        return '{"type":"object","properties":{"risk_level":{"type":"string"},"message":{"type":"string"}},"required":["risk_level","message"]}';
      case SparkToolName.GENERATE_TASK:
        return '{"type":"object","properties":{"user_input":{"type":"string"}},"required":["user_input"]}';
      case SparkToolName.QUERY_MEMBER_PROFILE:
        return '{"type":"object","properties":{"query_type":{"type":"string"}},"required":["query_type"]}';
      case SparkToolName.SHOW_CUSTOM_MESSAGE_CARD:
        return '{"type":"object","properties":{"card_type":{"type":"string"}},"required":["card_type"]}';
      case SparkToolName.SAVE_MEMORY:
        return '{"type":"object","properties":{"content":{"type":"string"}},"required":["content"]}';
      case SparkToolName.RETRIEVE_MEMORY:
        return '{"type":"object","properties":{"keyword":{"type":"string"}},"required":["keyword"]}';
      case SparkToolName.UPDATE_MEMORY:
        return '{"type":"object","properties":{"originalContent":{"type":"string"},"updatedContent":{"type":"string"}},"required":["originalContent","updatedContent"]}';
      default:
        return '{"type":"object","properties":{}}';
    }
  }

  private static normalizeToolName(value: string): string {
    return value.trim().toLowerCase();
  }
}
