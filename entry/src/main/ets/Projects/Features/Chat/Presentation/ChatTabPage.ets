import { AppContainer } from '../../../../App/AppContainer';
import { AIRuntimeCancellationToken } from '../../../../Core/AI/Runtime/AIRuntimeCancellation';
import { ChatMessage, ChatMessageBlock, ChatThread } from '../Domain/ChatModels';
import { ChatMessageText } from '../Domain/ChatMessageText';
import { SendChatMessageUseCase } from '../Application/SendChatMessageUseCase';
import { common } from '@kit.AbilityKit';
import { ChatAttachmentPicker, ChatPickedAttachment } from './ChatAttachmentPicker';
import { ChatComposerAttachmentInput, ChatComposerAttachmentProgress } from '../Infrastructure/ChatAttachmentPreprocessor';
import { ChatPreparedAttachment } from '../Infrastructure/ChatAttachmentAssembly';
import { ChatThreadListItem } from './ChatPresentationModels';
import { ChatMessageTimelineView } from './ChatMessageTimelineView';
import { HanlinChatComposerView } from './Composer/HanlinChatComposerView';
import {
  ChatComposerAttachmentKind,
  ChatComposerAttachmentPreview,
  ChatComposerAttachmentPreviewParams,
  ChatComposerAttachmentSource,
  ChatModelReasoningContext,
  defaultModelReasoning
} from './Composer/Models/ChatComposerDraftModels';
import { HealthResourceRef } from './Composer/Models/HealthResourceRef';
import { SmallTask } from './Composer/Models/SmallTask';
import { AIScenarioRemoteModelRow } from './Composer/Models/AIScenarioRemoteModelRow';
import { Member } from '../../../Core/Domain/Entities/Member';
import { MemberContextSummaryBuilder } from '../Application/MemberContextSummaryBuilder';
import { PromptLocalizer } from '../../../../Core/AI/Runtime/PromptLocalizer';
import { SystemMessageSettingsPrompt } from '../../../../Core/AI/Runtime/SystemMessageSettingsPrompt';
import { AskReportPickerPrompt } from '../../../../Core/AI/Runtime/AskReportPickerPrompt';
import { HealthResourceToolCandidateDTO } from '../../../../Core/AI/Runtime/HealthResourceToolCandidatePrompt';
import { LocalSmallTask } from '../../../../Core/AI/Domain/AIConfigModels';
import { ToolInteractionCoordinator } from './ToolInteraction/ToolInteractionCoordinator';
import { ToolInteractionSnapshot } from './ToolInteraction/ToolInteractionSnapshot';
import { ToolInteractionPresentationSheet } from './ToolInteraction/ToolInteractionPresentationSheet';
import { ToolPreviewPrompt } from './ToolInteraction/Models/ToolPreviewPrompt';

@Component
export struct ChatTabPage {
  @Prop initialThreadId: string = '';
  @Prop showThreadSwitcher: boolean = true;
  onBack: () => void = () => {};
  @State private ready: boolean = false;
  @State private thread?: ChatThread = undefined;
  @State private threads: ChatThread[] = [];
  @State private messages: ChatMessage[] = [];
  @State private inputText: string = '';
  @State private statusText: string = '';
  @State private running: boolean = false;
  @State private streamingAnswer: string = '';
  @State private streamingReasoning: string = '';
  @State private pickedAttachments: ChatPickedAttachment[] = [];
  @State private preparedAttachments: ChatPreparedAttachment[] = [];
  @State private attachmentPreviews: ChatComposerAttachmentPreview[] = [];
  @State private attachmentStatus: string = '';
  @State private useTools: boolean = false;
  @State private useKnowledgeBase: boolean = true;
  @State private useWebSearch: boolean = true;
  @State private reasoningEnabled: boolean = false;
  @State private reasoningEffortTier: number = 1;
  @State private refreshing: boolean = false;
  @State private threadItems: ChatThreadListItem[] = [];
  @State private smallTasks: SmallTask[] = SmallTask.defaultLocalTasks();
  @State private selectedSmallTaskCode: string = '';
  @State private modelRows: AIScenarioRemoteModelRow[] = [];
  @State private members: Member[] = [];
  @State private boundMemberID: number = 0;
  @State private defaultMemberID: number = 0;
  @State private healthResourceRefs: HealthResourceRef[] = [];
  @State private selectedModelName: string | undefined = undefined;
  @State private modelReasoning: ChatModelReasoningContext = defaultModelReasoning();
  @State private toolInteractionSnapshot?: ToolInteractionSnapshot = undefined;
  private toolInteractionCoordinator: ToolInteractionCoordinator = new ToolInteractionCoordinator();
  private cancelToken?: AIRuntimeCancellationToken;
  private useCase?: SendChatMessageUseCase;
  private accountId: number = 0;

  aboutToAppear(): void {
    this.toolInteractionCoordinator.setOnChanged((snapshot?: ToolInteractionSnapshot) => {
      this.toolInteractionSnapshot = snapshot;
    });
    this.bootstrap();
  }

  private async bootstrap(): Promise<void> {
    const container = AppContainer.shared();
    if (!container) {
      this.statusText = '应用未就绪';
      this.ready = true;
      return;
    }
    this.useCase = container.sendChatMessageUseCase;
    this.accountId = container.accountRuntime.activeAccountId ?? 0;
    if (this.accountId <= 0) {
      this.statusText = '请先登录';
      this.ready = true;
      return;
    }
    try {
      await container.chatRepository.normalizeLegacyIdentifiers(this.accountId);
      const defaultThread = await this.useCase.ensureDefaultThread(this.accountId);
      this.threads = await container.chatRepository.listThreads(this.accountId);
      this.threadItems = this.threads.map((value: ChatThread): ChatThreadListItem => ChatThreadListItem.from(value));
      let thread = defaultThread;
      if (this.initialThreadId.length > 0) {
        const selected = this.threads.find((value: ChatThread): boolean => value.clientId === this.initialThreadId);
        if (selected) thread = selected;
      }
      this.thread = thread;
      this.messages = await container.chatRepository.listMessages(this.accountId, thread.clientId);
      this.refreshMemberContext();
      await this.refreshChatModelPicker();
      await container.chatSyncSupervisor.pullThreadMessagesIncrementalOnOpen(thread.threadId || thread.clientId);
      void container.chatSyncEngine.pushSingleThread(thread.threadId || thread.clientId);
      this.messages = await container.chatRepository.listMessages(this.accountId, thread.clientId);
      this.statusText = '';
    } catch (err) {
      this.statusText = `加载失败`;
    }
    this.ready = true;
  }

  /**
   * 对齐 iOS ChatDetailViewModel.refreshChatModelPicker：
   * 从 Runtime chat 场景（local+pro 合并后的统一消费）填充选择器。
   */
  private async refreshChatModelPicker(): Promise<void> {
    const container = AppContainer.shared();
    if (!container || this.accountId <= 0) {
      this.modelRows = [];
      return;
    }
    try {
      let runtime = container.aiConfigRepository.currentRuntime(this.accountId);
      if (!runtime) {
        runtime = await container.aiConfigRepository.buildRuntime(this.accountId);
      }
      this.modelRows = AIScenarioRemoteModelRow.fromChatRuntime(runtime);
      const preferred = this.thread?.preferredModelName;
      if (preferred !== undefined && preferred.length > 0) {
        const stillValid = this.modelRows.some(
          (row: AIScenarioRemoteModelRow): boolean => row.name === preferred
        );
        if (stillValid) {
          this.applyModelSelection(preferred, false);
          return;
        }
      }
      // 线程无显式选择或已失效：保持「默认」芯片（undefined），发送侧走 Runtime 默认解析
      this.applyModelSelection(undefined, false);
    } catch (_e) {
      this.modelRows = [];
      this.statusText = '模型列表加载失败';
    }
  }

  private refreshMemberContext(): void {
    const container = AppContainer.shared();
    if (!container) {
      return;
    }
    const store = container.memberContextStore;
    this.members = store.context.members.slice();
    const selected = MemberContextSummaryBuilder.selectedMemberId(store) ?? 0;
    this.defaultMemberID = selected;
    if (this.boundMemberID <= 0) {
      this.boundMemberID = selected;
    }
  }

  private syncAttachmentPreviews(): void {
    const previews: ChatComposerAttachmentPreview[] = [];
    for (let i = 0; i < this.pickedAttachments.length; i++) {
      const picked = this.pickedAttachments[i];
      const kind = picked.input.kind === 'image'
        ? ChatComposerAttachmentKind.IMAGE
        : (picked.input.kind === 'pdf' || picked.input.originalName.toLowerCase().endsWith('.pdf')
          ? ChatComposerAttachmentKind.PDF
          : ChatComposerAttachmentKind.FILE);
      const params: ChatComposerAttachmentPreviewParams = {
        id: picked.input.previewId,
        source: ChatComposerAttachmentSource.PHOTO_LIBRARY,
        kind: kind,
        sourceUri: picked.input.sourceUri,
        displayName: picked.input.originalName,
        mimeType: picked.input.mimeType
      };
      previews.push(ChatComposerAttachmentPreview.create(params));
    }
    this.attachmentPreviews = previews;
  }

  private resolveSelectedModelName(): string | undefined {
    if (this.selectedModelName !== undefined && this.selectedModelName.length > 0) {
      return this.selectedModelName;
    }
    return this.thread?.preferredModelName;
  }

  private async reloadMessages(): Promise<void> {
    const container = AppContainer.shared();
    if (!container || !this.thread) {
      return;
    }
    this.messages = await container.chatRepository.listMessages(this.accountId, this.thread.clientId);
    this.threads = await container.chatRepository.listThreads(this.accountId);
    this.threadItems = this.threads.map((value: ChatThread): ChatThreadListItem => ChatThreadListItem.from(value));
  }

  /** 主气泡：优先 denormalized text，空则从 timeline text block 回退。 */
  private displayMessageText(m: ChatMessage): string {
    const text = ChatMessageText.fromMessage(m);
    if (text.length > 0) {
      return text;
    }
    return m.deliveryStatus === 'sending' ? '…' : '';
  }

  private async refreshCurrentThread(): Promise<void> {
    const container = AppContainer.shared();
    if (!container || !this.thread || this.running) return;
    this.refreshing = true;
    this.statusText = '正在刷新消息…';
    try {
      await container.chatSyncSupervisor.pullThreadMessagesIncrementalOnOpen(this.thread.threadId || this.thread.clientId);
      void container.chatSyncEngine.pushSingleThread(this.thread.threadId || this.thread.clientId);
      await this.reloadMessages();
      this.statusText = '';
    } catch (_e) {
      this.statusText = '消息刷新失败';
    } finally {
      this.refreshing = false;
    }
  }

  private async syncCurrentThread(): Promise<void> {
    const container = AppContainer.shared();
    if (!container || this.running) return;
    this.statusText = '正在同步…';
    try {
      await container.chatSyncSupervisor.syncNowWithPull();
      await this.reloadMessages();
      this.statusText = '';
    } catch (_e) {
      this.statusText = '同步失败';
    }
  }

  private async selectThread(thread: ChatThread): Promise<void> {
    if (this.running) return;
    this.thread = thread;
    await this.refreshChatModelPicker();
    await this.reloadMessages();
    const container = AppContainer.shared();
    if (container) {
      await container.chatSyncSupervisor.pullThreadMessagesIncrementalOnOpen(thread.threadId || thread.clientId);
      void container.chatSyncEngine.pushSingleThread(thread.threadId || thread.clientId);
      await this.reloadMessages();
    }
  }

  private async createThread(): Promise<void> {
    if (!this.useCase || this.accountId <= 0 || this.running) return;
    const container = AppContainer.shared();
    if (!container) return;
    const thread = await container.createThreadUseCase.execute(this.accountId);
    this.thread = thread;
    await this.refreshChatModelPicker();
    await this.reloadMessages();
  }

  private async retryMessage(message: ChatMessage): Promise<void> {
    if (this.running || message.deliveryStatus !== 'failed' && message.deliveryStatus !== 'cancelled') return;
    const container = AppContainer.shared();
    if (!container) return;
    await container.retryFailedMessageUseCase.execute(this.accountId, message.clientId);
    await this.reloadMessages();
    await container.chatSyncSupervisor.syncNow();
  }

  private onCancel(): void {
    if (this.cancelToken) {
      this.cancelToken.cancel();
    }
    this.running = false;
    this.statusText = '已停止';
  }

  private async onSend(): Promise<void> {
    if (this.running || !this.useCase || !this.thread) {
      return;
    }
    const prompt = this.inputText.trim();
    if (prompt.length === 0 && this.preparedAttachments.length === 0) {
      return;
    }
    if (this.pickedAttachments.length !== this.preparedAttachments.length) {
      this.attachmentStatus = '附件仍在预处理，请完成后再发送';
      return;
    }
    this.running = true;
    this.streamingAnswer = '';
    this.streamingReasoning = '';
    this.statusText = '生成中…';
    this.inputText = '';
    this.cancelToken = new AIRuntimeCancellationToken();
    const container = AppContainer.shared();
    if (!container) {
      this.statusText = '应用未就绪';
      this.running = false;
      return;
    }
    try {
      const result = await this.useCase.execute(
        this.accountId,
        this.thread.clientId,
        prompt,
        this.resolveSelectedModelName(),
        this.cancelToken,
        (_aid: string, answer: string, reasoning: string) => {
          this.streamingAnswer = answer;
          this.streamingReasoning = reasoning;
        },
        undefined,
        undefined,
        this.reasoningEnabled,
        false,
        this.attachmentsJson(),
        this.useTools,
        this.reasoningEffortTier,
        this.useKnowledgeBase,
        this.useWebSearch,
        undefined,
        this.resolveSelectedSmallTask()
      );
      if (result.errorCode) {
        this.statusText = result.errorCode === 'cancelled' ? '已停止' : `失败：${result.errorCode}`;
      } else {
        this.statusText = '';
      }
      await this.reloadMessages();
      // Outbox / thread-push 由 ChatSyncSupervisor 防抖旁路上送，对齐 iOS，不在此阻塞 syncNow。
      this.streamingAnswer = '';
      this.streamingReasoning = '';
      this.pickedAttachments = [];
      this.preparedAttachments = [];
      this.attachmentPreviews = [];
      this.healthResourceRefs = [];
      this.selectedSmallTaskCode = '';
      this.attachmentStatus = '';
    } catch (_e) {
      this.statusText = '发送异常';
      await this.reloadMessages();
    } finally {
      this.running = false;
      this.cancelToken = undefined;
    }
  }

  private attachmentsJson(): string {
    const values: Object[] = [];
    for (let i = 0; i < this.preparedAttachments.length; i++) {
      values.push(this.preparedAttachments[i].attachment as Object);
    }
    return JSON.stringify(values);
  }

  private async pickImages(): Promise<void> {
    await this.pickAttachments('image');
  }

  private async pickFiles(): Promise<void> {
    await this.pickAttachments('file');
  }

  private async pickAttachments(kind: 'image' | 'file'): Promise<void> {
    if (this.running) return;
    try {
      const context = getContext(this) as common.UIAbilityContext;
      const picked = kind === 'image'
        ? await ChatAttachmentPicker.pickImages(context)
        : await ChatAttachmentPicker.pickDocuments(context);
      for (let i = 0; i < picked.length; i++) {
        this.pickedAttachments = this.pickedAttachments.concat([picked[i]]);
        this.syncAttachmentPreviews();
        await this.prepareAttachment(picked[i].input);
      }
    } catch (_e) {
      this.attachmentStatus = '未能打开附件选择器';
    }
  }

  private async prepareAttachment(input: ChatComposerAttachmentInput): Promise<void> {
    const container = AppContainer.shared();
    if (!container) return;
    this.attachmentStatus = `正在处理 ${input.originalName}`;
    try {
      const prepared = await container.chatAttachmentPreprocessor.prepare(
        input,
        (progress: ChatComposerAttachmentProgress) => {
          this.attachmentStatus = `${input.originalName} ${Math.round(progress.progress * 100)}%`;
        }
      );
      this.preparedAttachments = this.preparedAttachments.concat([prepared]);
      this.attachmentStatus = `${this.preparedAttachments.length} 个附件已就绪`;
    } catch (_e) {
      this.attachmentStatus = `${input.originalName} 处理失败，请移除后重试`;
    }
  }

  private removeAttachmentById(id: string): void {
    const index = this.pickedAttachments.findIndex(
      (item: ChatPickedAttachment): boolean => item.input.previewId === id
    );
    if (index < 0) {
      return;
    }
    const picked = this.pickedAttachments.slice();
    picked.splice(index, 1);
    this.pickedAttachments = picked;
    if (index < this.preparedAttachments.length) {
      const prepared = this.preparedAttachments.slice();
      prepared.splice(index, 1);
      this.preparedAttachments = prepared;
    }
    this.syncAttachmentPreviews();
  }

  private onSmallTaskTapped(task: SmallTask): void {
    if (this.running) {
      return;
    }
    this.selectedSmallTaskCode = task.code;
    const prompt = task.prompt.trim().length > 0 ? task.prompt : task.name;
    this.inputText = prompt;
  }

  private resolveSelectedSmallTask(): LocalSmallTask | undefined {
    if (this.selectedSmallTaskCode.length === 0) {
      return undefined;
    }
    for (let i = 0; i < this.smallTasks.length; i++) {
      if (this.smallTasks[i].code === this.selectedSmallTaskCode) {
        return this.smallTasks[i].toLocalSmallTask();
      }
    }
    return undefined;
  }

  private onPresentAskReportPicker(): void {
    if (!this.thread) {
      this.statusText = '请先选择会话';
      return;
    }
    const memberID = this.boundMemberID > 0 ? this.boundMemberID : this.defaultMemberID;
    const prompt = AskReportPickerPrompt.create(this.thread.clientId, memberID);
    this.toolInteractionCoordinator.present(ToolInteractionSnapshot.askReportPicker(prompt));
  }

  private presentSystemMessageSettings(): void {
    if (!this.thread) {
      return;
    }
    const prompt = SystemMessageSettingsPrompt.create(
      this.thread.clientId,
      this.thread.rolePrompt,
      new PromptLocalizer().chatSystemPrompt(),
      this.resolveSelectedModelName() ?? '默认模型',
      false,
      undefined,
      []
    );
    this.toolInteractionCoordinator.present(ToolInteractionSnapshot.systemMessageSettings(prompt));
  }

  private async saveSessionPrompt(sessionPrompt: string): Promise<void> {
    if (!this.thread) {
      return;
    }
    const container = AppContainer.shared();
    if (!container) {
      return;
    }
    await container.chatRepository.updateThreadRolePrompt(
      this.accountId,
      this.thread.clientId,
      sessionPrompt
    );
    this.thread.rolePrompt = sessionPrompt;
    this.statusText = '会话 Prompt 已保存';
  }

  private onOpenToolDetail(block: ChatMessageBlock, message: ChatMessage): void {
    if (!this.thread) {
      return;
    }
    let args: Record<string, string> | undefined = undefined;
    let output = block.text;
    if (block.payloadJson && block.payloadJson.length > 0) {
      try {
        const obj = JSON.parse(block.payloadJson) as Record<string, Object>;
        const textObj = obj['text'];
        if (typeof textObj === 'string' && textObj.length > 0) {
          output = textObj;
        }
        const argObj = obj['arguments'];
        if (argObj && typeof argObj === 'object') {
          const rec: Record<string, string> = {};
          const keys = Object.keys(argObj as Object);
          for (let i = 0; i < keys.length; i++) {
            rec[keys[i]] = `${(argObj as Record<string, Object>)[keys[i]]}`;
          }
          args = rec;
        }
      } catch (_e) {
        // keep raw text
      }
    }
    const preview = ToolPreviewPrompt.create(
      block.toolName ?? 'tool',
      output,
      this.thread.clientId,
      message.clientId,
      [block.blockId],
      args,
      block.toolCallId
    );
    this.toolInteractionCoordinator.present(ToolInteractionSnapshot.toolPreview(preview));
  }

  private onAskReportConfirmed(refs: HealthResourceRef[]): void {
    if (refs.length === 0) {
      return;
    }
    this.healthResourceRefs = this.healthResourceRefs.concat(refs);
  }

  private onHealthCandidatesConfirmed(_selected: HealthResourceToolCandidateDTO[]): void {
    // 工具候选确认回填留给 ToolHub 执行链路；关闭 Sheet 即可保持聊天状态
  }

  private dismissToolInteraction(): void {
    this.toolInteractionCoordinator.dismiss();
  }

  private applyModelSelection(name: string | undefined, persist: boolean): void {
    const normalized = (name !== undefined && name.length > 0) ? name : undefined;
    if (this.selectedModelName === normalized && !persist) {
      this.updateModelReasoning(normalized);
      return;
    }
    if (this.selectedModelName === normalized && persist) {
      return;
    }
    this.selectedModelName = normalized;
    if (this.thread) {
      this.thread.preferredModelName = normalized;
    }
    this.updateModelReasoning(normalized);
    if (persist) {
      void this.persistSelectedChatModel(normalized);
    }
  }

  private updateModelReasoning(name: string | undefined): void {
    const matched = name === undefined
      ? undefined
      : this.modelRows.find((row: AIScenarioRemoteModelRow): boolean => row.name === name);
    if (matched) {
      this.modelReasoning = ChatModelReasoningContext.make(
        matched.supportsReasoning || matched.supportsDeepReasoning,
        matched.reasoningControllable,
        matched.providerCompany
      );
    } else {
      this.modelReasoning = defaultModelReasoning();
    }
  }

  private async persistSelectedChatModel(name: string | undefined): Promise<void> {
    const container = AppContainer.shared();
    if (!container || !this.thread || this.accountId <= 0) {
      return;
    }
    const thread = this.thread;
    try {
      await container.chatRepository.updateThreadGenerationConfig(
        this.accountId,
        thread.clientId,
        name,
        thread.temperature,
        thread.topP,
        thread.maxTokens,
        thread.maxMessages,
        thread.rolePrompt
      );
    } catch (_e) {
      this.statusText = '模型选择保存失败';
    }
  }

  private onSelectModel(name: string | undefined): void {
    this.applyModelSelection(name, true);
  }

  private onSetMemberBinding(memberID: number): void {
    this.boundMemberID = memberID;
  }

  private onRemoveHealthResourceRef(ref: HealthResourceRef): void {
    this.healthResourceRefs = this.healthResourceRefs.filter(
      (item: HealthResourceRef): boolean => item.id !== ref.id
    );
  }

  private onClearHealthResourceRefs(): void {
    this.healthResourceRefs = [];
  }

  private onPickCamera(): void {
    this.attachmentStatus = '自定义相机待接入 CameraKit';
  }

  build() {
    Column() {
      Row() {
        Button('<')
          .fontSize(22)
          .fontColor('#3973B9')
          .backgroundColor('#00000000')
          .width(44)
          .height(44)
          .accessibilityText('返回会话列表')
          .onClick(() => { this.onBack(); })
        Text(this.thread?.title ?? '对话')
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .maxLines(1)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
        Button('⋯')
          .fontSize(24)
          .fontColor('#3973B9')
          .backgroundColor('#00000000')
          .width(52)
          .height(44)
          .accessibilityText('会话操作')
          .bindMenu([
            { value: '刷新消息', action: () => { this.refreshCurrentThread(); } },
            { value: '同步会话', action: () => { this.syncCurrentThread(); } },
            { value: '新建对话', action: () => { this.createThread(); } },
            { value: '系统消息设置', action: () => { this.presentSystemMessageSettings(); } }
          ])
      }
      .width('100%')
      .height(56)
      .padding({ left: 8, right: 8 })
      .backgroundColor('#F6F8FB')
      .border({ width: { bottom: 1 }, color: '#E5EDF5' })

      if (!this.ready) {
        Text($r('app.string.ai_settings_loading'))
          .fontSize(14)
          .fontColor('#888')
          .margin(16)
      } else {
        if (this.showThreadSwitcher) {
        Scroll() {
          Row() {
              ForEach(this.threadItems, (item: ChatThreadListItem) => {
              Button(item.title)
                .fontSize(12)
                .backgroundColor(item.id === this.thread?.clientId ? '#DCEBFF' : '#FFFFFF')
                .fontColor('#245B9E')
                .margin({ right: 8 })
                .onClick(() => {
                  const selected = this.threads.find((thread: ChatThread): boolean => thread.clientId === item.id);
                  if (selected) this.selectThread(selected);
                })
            }, (item: ChatThreadListItem) => item.id)
          }
          .padding({ left: 12, right: 12 })
        }
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)
        .height(42)
        }

        Refresh({ refreshing: $$this.refreshing }) {
        List() {
          ForEach(this.messages, (m: ChatMessage) => {
            ListItem() {
              Column() {
                Text(m.role === 'user' ? '我' : '助手')
                  .fontSize(12)
                  .fontColor('#888')
                Text(this.displayMessageText(m))
                  .fontSize(15)
                  .fontColor('#222')
                  .margin({ top: 4 })
                ChatMessageTimelineView({
                  blocks: m.blocks,
                  isUser: m.role === 'user',
                  onOpenToolDetail: (b: ChatMessageBlock) => this.onOpenToolDetail(b, m)
                })
                  .margin({ top: 8 })
                if (m.deliveryStatus === 'failed' || m.deliveryStatus === 'cancelled') {
                  Text(m.errorCode ?? m.deliveryStatus)
                    .fontSize(12)
                    .fontColor('#C62828')
                    .margin({ top: 4 })
                  Button('重试同步')
                    .fontSize(12)
                    .margin({ top: 4 })
                    .onClick(() => { this.retryMessage(m); })
                }
              }
              .width('100%')
              .alignItems(m.role === 'user' ? HorizontalAlign.End : HorizontalAlign.Start)
              .padding(12)
            }
          }, (m: ChatMessage) => `${m.clientId}_${m.updatedAt}_${m.deliveryStatus}`)

          if (this.running && this.streamingAnswer.length > 0) {
            ListItem() {
              Column() {
                Text('助手')
                  .fontSize(12)
                  .fontColor('#888')
                if (this.streamingReasoning.length > 0) {
                  Text(this.streamingReasoning)
                    .fontSize(12)
                    .fontColor('#666')
                    .margin({ top: 4 })
                }
                Text(this.streamingAnswer)
                  .fontSize(15)
                  .fontColor('#222')
                  .margin({ top: 4 })
              }
              .width('100%')
              .alignItems(HorizontalAlign.Start)
              .padding(12)
            }
          }
        }
        .width('100%')
        .height('100%')
        .edgeEffect(EdgeEffect.Spring)
        .layoutWeight(1)
        }
        .layoutWeight(1)
        .onRefreshing(() => { this.refreshCurrentThread(); })

        if (this.statusText.length > 0) {
          Text(this.statusText)
            .fontSize(12)
            .fontColor('#888')
            .width('100%')
            .padding({ left: 16, right: 16, bottom: 4 })
        }

        HanlinChatComposerView({
          draft: $inputText,
          useTools: $useTools,
          useKnowledgeBase: $useKnowledgeBase,
          useWebSearch: $useWebSearch,
          reasoningEnabled: $reasoningEnabled,
          reasoningEffortTier: $reasoningEffortTier,
          running: this.running,
          attachments: this.attachmentPreviews,
          preparedAttachmentCount: this.preparedAttachments.length,
          attachmentStatus: this.attachmentStatus,
          healthResourceRefs: this.healthResourceRefs,
          modelReasoning: this.modelReasoning,
          members: this.members,
          boundMemberID: this.boundMemberID,
          defaultMemberID: this.defaultMemberID,
          smallTasks: this.smallTasks,
          modelRows: this.modelRows,
          selectedModelName: this.selectedModelName,
          canOpenCamera: false,
          onSend: () => { this.onSend(); },
          onCancel: () => { this.onCancel(); },
          onPickImages: () => { this.pickImages(); },
          onPickCamera: () => { this.onPickCamera(); },
          onPickFiles: () => { this.pickFiles(); },
          onRemoveAttachment: (id: string) => { this.removeAttachmentById(id); },
          onSetMemberBinding: (memberID: number) => { this.onSetMemberBinding(memberID); },
          onRemoveHealthResourceRef: (ref: HealthResourceRef) => { this.onRemoveHealthResourceRef(ref); },
          onClearHealthResourceRefs: () => { this.onClearHealthResourceRefs(); },
          onSmallTaskTapped: (task: SmallTask) => { this.onSmallTaskTapped(task); },
          onPresentAskReportPicker: () => { this.onPresentAskReportPicker(); },
          onSelectModel: (name: string | undefined) => { this.onSelectModel(name); }
        })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FFFFFF')
    .bindSheet(this.toolInteractionSnapshot !== undefined, this.toolInteractionSheetBuilder, {
      height: SheetSize.LARGE,
      dragBar: true,
      showClose: true,
      onDisappear: () => { this.dismissToolInteraction(); }
    })
  }

  @Builder
  toolInteractionSheetBuilder() {
    ToolInteractionPresentationSheet({
      snapshot: this.toolInteractionSnapshot,
      onDismiss: () => { this.dismissToolInteraction(); },
      onSaveSessionPrompt: (sessionPrompt: string) => { void this.saveSessionPrompt(sessionPrompt); },
      onHealthCandidatesConfirmed: (selected: HealthResourceToolCandidateDTO[]) => {
        this.onHealthCandidatesConfirmed(selected);
      },
      onAskReportConfirmed: (refs: HealthResourceRef[]) => { this.onAskReportConfirmed(refs); }
    })
  }
}
