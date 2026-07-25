import {
  AIRuntimeEvent,
  AIRuntimeMessage,
  AIRuntimeReasoningOptions,
  AIRuntimeResponse,
  AIRuntimeTextRequest,
  AIRuntimeToolCall,
  AIScenario
} from '../Domain/AIConfigModels';
import { AIRuntimeService } from './AIRuntimeService';
import { AIRuntimeCancellationToken, AIRuntimeCancelledError } from './AIRuntimeCancellation';
import { ChatOrchestratorInferenceOptions } from './ChatOrchestratorInferenceOptions';
import { PromptLocalizer } from './PromptLocalizer';
import { ToolHub } from './ToolHub/ToolHub';
import { ToolExecutionResult } from './ToolHub/Models/ToolingModels';
import { Logger } from '../../../Foundation/Logging/Logger';
import { LogModule } from '../../../Foundation/Logging/LogModule';
import { LogFields } from '../../../Foundation/Logging/LogEvent';
import {
  ChatModelReasoningContext,
  RuntimeReasoningPolicy
} from './RuntimeReasoningPolicy';
import { RuntimeToolCallLoopStrategy } from './RuntimeToolCallLoopStrategy';

export class ChatAssistantPartialDelta {
  answer: string = '';
  reasoning?: string;
  toolName?: string;
  toolContent?: string;
  toolArguments?: string;
  toolCallID?: string;
}

export class ChatOrchestratorOutput {
  text: string = '';
  reasoningText?: string;
  finishReason?: string;
  kind: string = 'text';
  toolName?: string;
  toolContent?: string;
  errorCode?: string;
}

export type ChatPartialHandler = (delta: ChatAssistantPartialDelta) => void;

/**
 * 对齐 iOS ChatOrchestrator：仅聊天路径使用。
 * 医疗/营养等非聊天场景禁止经此入口，应直连 AIRuntimeService / StructuredRuntimeClient。
 */
export class ChatOrchestrator {
  private readonly runtimeService: AIRuntimeService;
  private readonly toolHub: ToolHub;
  private readonly localizer: PromptLocalizer = new PromptLocalizer();
  private static readonly MAX_TOOL_ROUNDS: number = 30;

  constructor(runtimeService: AIRuntimeService, toolHub?: ToolHub) {
    this.runtimeService = runtimeService;
    this.toolHub = toolHub ?? new ToolHub();
  }

  get hub(): ToolHub {
    return this.toolHub;
  }

  async generateReply(
    userInput: string,
    history: AIRuntimeMessage[],
    memberContextSummary: string,
    accountId: number,
    inference: ChatOrchestratorInferenceOptions = ChatOrchestratorInferenceOptions.defaultOptions(),
    systemPrompt?: string,
    preferredModelName?: string,
    providerCompanyUppercased?: string,
    temperature?: number,
    topP?: number,
    maxTokens?: number,
    memberID?: number,
    threadID?: string,
    cancellationToken?: AIRuntimeCancellationToken,
    onPartial?: ChatPartialHandler,
    modelReasoning: ChatModelReasoningContext = ChatModelReasoningContext.unknown(),
    assistantMessageClientId?: string
  ): Promise<ChatOrchestratorOutput> {
    if (cancellationToken) {
      cancellationToken.checkCancellation();
    }

    const begin = new LogFields();
    begin.detail =
      `对话编排开始 history=${history.length} inputLen=${userInput.length}` +
      ` tools=${inference.useTools} reasoning=${inference.reasoningEnabled}`;
    Logger.debug('ai.chat.begin', LogModule.AI_CONFIG, begin);

    if (inference.useTools) {
      if (cancellationToken) {
        cancellationToken.checkCancellation();
      }
      const hubHit = await this.toolHub.runIfNeeded(
        userInput,
        memberID,
        inference.allowedToolNames,
        threadID
      );
      if (hubHit.kind === 'executed' && hubHit.executed) {
        const out = new ChatOrchestratorOutput();
        out.text = hubHit.executed.outputText;
        out.kind = 'tool';
        out.toolName = hubHit.executed.toolName;
        out.toolContent = hubHit.executed.outputText;
        return out;
      }
    }

    const reasoning = RuntimeReasoningPolicy.build(inference, modelReasoning);
    const toolLoopStrategy = new RuntimeToolCallLoopStrategy(
      providerCompanyUppercased,
      preferredModelName,
      reasoning.isEnabled,
      reasoning.usePromptFallback
    );

    let loopMessages = ChatOrchestrator.buildMessages(
      history,
      systemPrompt,
      memberContextSummary,
      userInput,
      reasoning
    );
    const baseTools = inference.useTools
      ? this.toolHub.listToolDefinitions(
        inference.allowedToolNames,
        inference.useKnowledgeBag,
        inference.useWebSearch
      )
      : [];
    let activeTools = baseTools;
    let activeToolChoice = inference.useTools && baseTools.length > 0 ? 'auto' : 'none';
    let roundToolLocked = false;
    let loopMemberID = memberID;
    const executedTools: ToolExecutionResult[] = [];
    const toolLockedNotice = this.localizer.toolLockedNotice();

    for (let round = 1; round <= ChatOrchestrator.MAX_TOOL_ROUNDS; round++) {
      if (cancellationToken) {
        cancellationToken.checkCancellation();
      }

      const request = new AIRuntimeTextRequest();
      request.requestId = `chat_${Date.now()}_${round}`;
      request.accountId = accountId;
      request.scenario = AIScenario.CHAT;
      request.messages = loopMessages;
      request.tools = activeTools;
      request.toolChoice = activeToolChoice;
      request.reasoning = reasoning;
      request.stream = true;
      request.preferredModelName = preferredModelName;
      request.providerCompanyUppercased = providerCompanyUppercased;
      request.temperature = temperature;
      request.topP = topP;
      request.maxTokens = maxTokens;
      request.cancellationToken = cancellationToken;

      let answerAcc = '';
      let reasoningAcc = '';
      let response: AIRuntimeResponse;
      try {
        response = await this.runtimeService.generateTextStream(request, (ev: AIRuntimeEvent) => {
          if (ev.kind === 'textDelta' && ev.deltaText) {
            answerAcc += ev.deltaText;
            if (onPartial) {
              const d = new ChatAssistantPartialDelta();
              d.answer = answerAcc;
              d.reasoning = reasoningAcc.length > 0 ? reasoningAcc : undefined;
              onPartial(d);
            }
          } else if (ev.kind === 'reasoningDelta' && ev.reasoningDelta) {
            reasoningAcc += ev.reasoningDelta;
            if (onPartial) {
              const d = new ChatAssistantPartialDelta();
              d.answer = answerAcc;
              d.reasoning = reasoningAcc;
              onPartial(d);
            }
          } else if (ev.kind === 'toolCall' && ev.toolCallDelta && onPartial) {
            const d = new ChatAssistantPartialDelta();
            d.answer = answerAcc;
            d.reasoning = reasoningAcc.length > 0 ? reasoningAcc : undefined;
            d.toolName = ev.toolCallDelta.name;
            d.toolCallID = ev.toolCallDelta.id;
            d.toolArguments = ev.toolCallDelta.argumentsDelta;
            onPartial(d);
          }
        });
      } catch (err) {
        if (err instanceof AIRuntimeCancelledError) {
          throw err;
        }
        const fail = new LogFields();
        fail.detail = `AI 推理路径失败 requestId=${request.requestId}`;
        Logger.error('ai.chat.failed', LogModule.AI_CONFIG, fail);
        throw new Error('chat inference failed');
      }

      if (response.errorCode === 'cancelled') {
        throw new AIRuntimeCancelledError();
      }
      if (response.errorCode) {
        const out = new ChatOrchestratorOutput();
        out.errorCode = response.errorCode;
        out.text = response.errorMessage ?? this.localizer.emptyOutputUserMessage();
        out.kind = 'error';
        out.finishReason = response.finishReason;
        return out;
      }

      const text = (response.text || answerAcc).trim();
      const reasoningText = (response.reasoningText || reasoningAcc).trim();

      if (!response.hasToolCalls) {
        if (text.length === 0) {
          const warn = new LogFields();
          warn.detail = 'AI 返回空文本，转为 emptyOutput';
          Logger.warn('ai.chat.empty_output', LogModule.AI_CONFIG, warn);
          const out = new ChatOrchestratorOutput();
          out.errorCode = 'emptyOutput';
          out.text = this.localizer.emptyOutputUserMessage();
          out.kind = 'error';
          return out;
        }
        const out = new ChatOrchestratorOutput();
        out.text = text;
        out.reasoningText = reasoningText.length > 0 ? reasoningText : undefined;
        out.finishReason = response.finishReason;
        out.kind = 'text';
        if (executedTools.length > 0) {
          out.toolName = executedTools[executedTools.length - 1].toolName;
          out.toolContent = executedTools[executedTools.length - 1].outputText;
        }
        return out;
      }

      if (!inference.useTools || activeTools.length === 0) {
        loopMessages.push(ChatOrchestrator.assistantToolMessage(
          response.toolCalls,
          text,
          toolLoopStrategy.reasoningContentForAssistantToolMessage(
            reasoningText.length > 0 ? reasoningText : undefined,
            response.toolCalls
          )
        ));
        const lock = new AIRuntimeMessage();
        lock.role = 'system';
        lock.content = toolLockedNotice;
        loopMessages.push(lock);
        continue;
      }

      const info = new LogFields();
      info.detail = `模型返回 tool_calls round=${round} count=${response.toolCalls.length}`;
      Logger.info('ai.chat.tool_calls', LogModule.AI_CONFIG, info);

      loopMessages.push(ChatOrchestrator.assistantToolMessage(
        response.toolCalls,
        text,
        toolLoopStrategy.reasoningContentForAssistantToolMessage(
          reasoningText.length > 0 ? reasoningText : undefined,
          response.toolCalls
        )
      ));

      for (let i = 0; i < response.toolCalls.length; i++) {
        if (cancellationToken) {
          cancellationToken.checkCancellation();
        }
        const call = response.toolCalls[i];
        if (onPartial) {
          const d = new ChatAssistantPartialDelta();
          d.answer = text;
          d.reasoning = reasoningText.length > 0 ? reasoningText : undefined;
          d.toolName = call.name;
          d.toolCallID = call.id;
          d.toolArguments = call.arguments;
          onPartial(d);
        }
        const toolResult = await this.toolHub.executeToolCall(
          call.name,
          call.arguments,
          loopMemberID,
          threadID,
          call.id,
          assistantMessageClientId,
          request.requestId,
          providerCompanyUppercased,
          preferredModelName,
          undefined,
          undefined,
          accountId
        );
        executedTools.push(toolResult);
        if (toolResult.resolvedMemberID !== undefined) {
          loopMemberID = toolResult.resolvedMemberID;
        }
        const toolMsg = new AIRuntimeMessage();
        toolMsg.role = 'tool';
        toolMsg.content = toolResult.outputText;
        toolMsg.toolCallID = call.id;
        toolMsg.name = call.name;
        loopMessages.push(toolMsg);

        if (onPartial) {
          const done = new ChatAssistantPartialDelta();
          done.answer = text;
          done.reasoning = reasoningText.length > 0 ? reasoningText : undefined;
          done.toolName = call.name;
          done.toolCallID = call.id;
          done.toolContent = toolResult.outputText;
          onPartial(done);
        }

        if (toolResult.isAwaitingUserInput) {
          roundToolLocked = true;
          activeTools = [];
          activeToolChoice = 'none';
          const lock = new AIRuntimeMessage();
          lock.role = 'system';
          lock.content = toolLockedNotice;
          loopMessages.push(lock);
          break;
        }
      }

      if (roundToolLocked) {
        roundToolLocked = false;
        continue;
      }
    }

    const warn = new LogFields();
    warn.detail = '工具调用超过最大轮次，回退兜底文案';
    Logger.warn('ai.chat.max_rounds', LogModule.AI_CONFIG, warn);
    const fallback = new ChatOrchestratorOutput();
    fallback.text = this.localizer.fallbackAssistantText();
    fallback.finishReason = 'length';
    fallback.kind = 'text';
    return fallback;
  }

  private static buildMessages(
    history: AIRuntimeMessage[],
    systemPrompt: string | undefined,
    memberContextSummary: string,
    userInput: string,
    reasoning: AIRuntimeReasoningOptions
  ): AIRuntimeMessage[] {
    const out: AIRuntimeMessage[] = [];
    if (systemPrompt && systemPrompt.length > 0) {
      const sys = new AIRuntimeMessage();
      sys.role = 'system';
      sys.content = systemPrompt;
      out.push(sys);
    }
    if (memberContextSummary.length > 0) {
      const ctx = new AIRuntimeMessage();
      ctx.role = 'system';
      ctx.content = `成员健康上下文：\n${memberContextSummary}`;
      out.push(ctx);
    }
    if (reasoning.isEnabled && reasoning.usePromptFallback) {
      const think = new AIRuntimeMessage();
      think.role = 'system';
      think.content = '请在回复前进行简要思考，再给出最终答案。';
      out.push(think);
    }
    for (let i = 0; i < history.length; i++) {
      out.push(history[i]);
    }
    const user = new AIRuntimeMessage();
    user.role = 'user';
    user.content = userInput;
    out.push(user);
    return out;
  }

  private static assistantToolMessage(
    toolCalls: AIRuntimeToolCall[],
    text: string,
    reasoningContent: string | undefined
  ): AIRuntimeMessage {
    const msg = new AIRuntimeMessage();
    msg.role = 'assistant';
    msg.content = text.length > 0 ? text : undefined;
    msg.toolCalls = toolCalls;
    msg.reasoningContent = reasoningContent;
    return msg;
  }
}
