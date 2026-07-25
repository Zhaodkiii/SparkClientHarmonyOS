import { AppContainer } from '../../../../../App/AppContainer';
import {
  AIScenario,
  AIRuntimeMessage,
  AIRuntimeTextRequest,
  AIRuntimeEvent
} from '../../../../../Core/AI/Domain/AIConfigModels';
import { AIRuntimeCancellationToken } from '../../../../../Core/AI/Runtime/AIRuntimeCancellation';
import { ChatOrchestrator, ChatAssistantPartialDelta } from '../../../../../Core/AI/Runtime/ChatOrchestrator';
import { ChatOrchestratorInferenceOptions } from '../../../../../Core/AI/Runtime/ChatOrchestratorInferenceOptions';
import { AISettingsUiTokens } from '../AISettingsUiTokens';
import { AISettingsNavHeader } from '../components/AISettingsNavHeader';

/**
 * AI Runtime 联调页：Chat 走 Orchestrator，非聊天场景直连 Runtime。
 * 禁止 Feature 自建厂商 HTTP。
 */
@Component
export struct AIRuntimePlaygroundPage {
  stack: NavPathStack = new NavPathStack();
  onBack: () => void = () => {
  };
  @State private inputText: string = '用一句话介绍你自己';
  @State private outputText: string = '';
  @State private reasoningText: string = '';
  @State private statusText: string = '';
  @State private running: boolean = false;
  private cancelToken?: AIRuntimeCancellationToken;
  private activeRequestId: string = '';

  private doBack(): void {
    if (this.running) {
      this.onCancel();
    }
    if (this.onBack) {
      this.onBack();
    } else {
      this.stack.pop();
    }
  }

  private onCancel(): void {
    if (this.cancelToken) {
      this.cancelToken.cancel();
    }
    const container = AppContainer.shared();
    if (container && this.activeRequestId.length > 0) {
      container.aiRuntimeService.cancel(this.activeRequestId);
    }
    this.running = false;
    this.statusText = '已取消';
  }

  private async onSendChat(): Promise<void> {
    if (this.running) {
      return;
    }
    const container = AppContainer.shared();
    if (!container) {
      this.statusText = 'AppContainer 未就绪';
      return;
    }
    const prompt = this.inputText.trim();
    if (prompt.length === 0) {
      this.statusText = '请输入内容';
      return;
    }

    this.running = true;
    this.outputText = '';
    this.reasoningText = '';
    this.statusText = 'ChatOrchestrator 推理中…';
    this.cancelToken = new AIRuntimeCancellationToken();
    this.activeRequestId = '';

    const orchestrator: ChatOrchestrator = container.chatOrchestrator;
    const accountId = container.accountRuntime.activeAccountId ?? 0;
    const inference = ChatOrchestratorInferenceOptions.defaultOptions();
    inference.useTools = false;

    try {
      const result = await orchestrator.generateReply(
        prompt,
        [],
        '',
        accountId,
        inference,
        undefined,
        undefined,
        undefined,
        undefined,
        undefined,
        undefined,
        undefined,
        undefined,
        this.cancelToken,
        (delta: ChatAssistantPartialDelta) => {
          this.outputText = delta.answer;
          this.reasoningText = delta.reasoning ?? '';
        }
      );
      if (result.errorCode) {
        this.statusText = `失败：${result.errorCode}`;
        if (result.text.length > 0) {
          this.outputText = result.text;
        }
      } else {
        this.outputText = result.text;
        this.reasoningText = result.reasoningText ?? '';
        this.statusText = `完成 · ${result.finishReason ?? 'stop'} · via Orchestrator`;
      }
    } catch (err) {
      this.statusText = `异常：${err}`;
    } finally {
      this.running = false;
      this.cancelToken = undefined;
    }
  }

  private async onDirectRuntime(): Promise<void> {
    if (this.running) {
      return;
    }
    const container = AppContainer.shared();
    if (!container) {
      this.statusText = 'AppContainer 未就绪';
      return;
    }
    const prompt = this.inputText.trim();
    if (prompt.length === 0) {
      this.statusText = '请输入内容';
      return;
    }

    this.running = true;
    this.outputText = '';
    this.reasoningText = '';
    this.statusText = '直连 AIRuntimeService…';
    const token = new AIRuntimeCancellationToken();
    this.cancelToken = token;

    const msg = new AIRuntimeMessage();
    msg.role = 'user';
    msg.content = prompt;
    const request = new AIRuntimeTextRequest();
    request.requestId = `pg_${Date.now()}`;
    request.accountId = container.accountRuntime.activeAccountId ?? 0;
    request.scenario = AIScenario.REPORT_INTERPRETATION;
    request.stream = true;
    request.messages = [msg];
    request.cancellationToken = token;
    this.activeRequestId = request.requestId;

    try {
      const response = await container.aiRuntimeService.generateTextStream(
        request,
        (ev: AIRuntimeEvent) => {
          if (ev.kind === 'textDelta' && ev.deltaText) {
            this.outputText += ev.deltaText;
          } else if (ev.kind === 'reasoningDelta' && ev.reasoningDelta) {
            this.reasoningText += ev.reasoningDelta;
          }
        }
      );
      if (response.errorCode) {
        this.statusText = `失败：${response.errorCode}`;
        if (response.errorMessage && this.outputText.length === 0) {
          this.outputText = response.errorMessage;
        }
      } else {
        if (this.outputText.length === 0) {
          this.outputText = response.text;
        }
        this.statusText =
          `完成 · ${response.finishReason} · ${response.modelName || response.modelId} · direct Runtime`;
      }
    } catch (err) {
      this.statusText = `异常：${err}`;
    } finally {
      this.running = false;
      this.cancelToken = undefined;
    }
  }

  build() {
    Column() {
      AISettingsNavHeader({
        title: $r('app.string.ai_settings_hub_runtime'),
        onBack: () => {
          this.doBack();
        }
      })

      Column() {
        Text($r('app.string.ai_settings_runtime_hint'))
          .fontSize(13)
          .fontColor(AISettingsUiTokens.textSecondary)
          .width('100%')
          .margin({ bottom: 12 })

        TextArea({ text: this.inputText, placeholder: '输入提示词' })
          .height(96)
          .width('100%')
          .padding(12)
          .backgroundColor(AISettingsUiTokens.cardBackground)
          .borderRadius(12)
          .enabled(!this.running)
          .onChange((v: string) => {
            this.inputText = v;
          })

        Row() {
          Button(this.running ? $r('app.string.ai_settings_runtime_cancel') : $r('app.string.ai_settings_runtime_send'))
            .layoutWeight(1)
            .onClick(() => {
              if (this.running) {
                this.onCancel();
              } else {
                this.onSendChat();
              }
            })
          Button($r('app.string.ai_settings_runtime_direct'))
            .layoutWeight(1)
            .margin({ left: 8 })
            .enabled(!this.running)
            .onClick(() => {
              this.onDirectRuntime();
            })
        }
        .width('100%')
        .margin({ top: 12 })

        Text(this.statusText)
          .fontSize(12)
          .fontColor(AISettingsUiTokens.textSecondary)
          .width('100%')
          .margin({ top: 12, bottom: 8 })

        Scroll() {
          Column() {
            if (this.reasoningText.length > 0) {
              Text($r('app.string.ai_settings_runtime_reasoning'))
                .fontSize(12)
                .fontColor(AISettingsUiTokens.textSecondary)
                .width('100%')
                .margin({ bottom: 4 })
              Text(this.reasoningText)
                .fontSize(13)
                .fontColor(AISettingsUiTokens.textSecondary)
                .width('100%')
                .margin({ bottom: 12 })
            }
            Text(this.outputText.length > 0 ? this.outputText : $r('app.string.ai_settings_runtime_empty'))
              .fontSize(15)
              .fontColor(AISettingsUiTokens.textPrimary)
              .width('100%')
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
        }
        .layoutWeight(1)
        .width('100%')
        .scrollBar(BarState.Off)
      }
      .layoutWeight(1)
      .width('100%')
      .padding({
        left: AISettingsUiTokens.pagePaddingH,
        right: AISettingsUiTokens.pagePaddingH,
        bottom: 24
      })
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(AISettingsUiTokens.pageBackground)
  }
}
