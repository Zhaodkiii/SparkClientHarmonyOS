# AI Prompt 底座与工具交互对齐 iOS 补齐工单

> 工单编号：HOS-AIRUNTIME-PROMPT-ALIGN-0002
>
> 工单类型：iOS → HarmonyOS Prompt Runtime、Chat Prompt Interaction 纠偏与补齐
>
> 审计日期：2026-07-24
>
> 参考端：`SparkClient/SparkClient`
>
> 目标端：`SparkClientHarmonyOS`
>
> 当前进度基线：阶段 1 为 85% - 90%；阶段 2 为 30% - 40%。
>
> 目标：不逐行照搬 SwiftUI/Swift API，而是对齐 iOS 的业务语义，使用 HarmonyOS ArkTS、rawfile、Navigation、AppStorage/RDB、组件化页面和现有 `Core/AI` 分层实现。

## 1. 范围与结论

本工单只覆盖用户本次指定的两个阶段：

| 阶段 | 当前完成度 | 已完成 | 未完成重点 |
|---|---:|---|---|
| 阶段 1：AI Runtime 提示词底座 | 85% - 90% | `PromptLocalizer.ets` 已扩展到 527 行；`Prompts.strings` 三语言 rawfile 已存在；`ChatSystemPromptResolver.ets`、`AIPromptKeywords.ets` 已存在；聊天发送链路已调用 resolver | 小任务对象拼装未接入真实链路；`AIPromptL10n` 只读 `Prompts.strings`，没有对齐 iOS `ToolPrompts.strings` 的 `tool()` 读取；日期本地化资源 key 与 iOS 命名存在差异；缺少针对 prompt 读取、fallback、日期替换、小任务拼装的单测 |
| 阶段 2：对话/工具调用展示 Prompt | 30% - 40% | `ToolHub`、工具审计、工具 block、健康资料引用 block、问报告按钮/预览 strip 有部分骨架 | `SystemMessageSettingsPrompt`、`HealthResourceToolCandidatePrompt`、`AskReportPickerPrompt`、`ToolPreviewPrompt` 的 ArkTS 载荷模型未迁；`ToolPrompts.strings` 三语言 rawfile 未建；`ToolInteractionCoordinator` 队列和 Sheet 容器未迁；系统提示词设置、工具预览、健康资料候选确认、问报告 picker 未形成 iOS 等价交互 |

总判断：阶段 1 的底座代码已经接近可用，但还有“接线完整度”和“资源表完整度”缺口。阶段 2 目前更多是聊天/工具骨架已有，展示型 prompt 载荷、交互协调器和 Sheet UI 仍需系统补齐。

## 2. 代码事实

### 2.1 HarmonyOS 已有实现

| 能力 | 当前文件 | 事实 |
|---|---|---|
| Prompt 本地化仓库 | `entry/src/main/ets/Core/AI/Runtime/PromptLocalizer.ets` | 已读取 `rawfile/ai/prompts/{zh-Hans,zh-Hant,en}/Prompts.strings`，覆盖聊天、医疗、营养、Vision、retry、工具锁定、空输出等文案 |
| Prompt rawfile 读取 | `entry/src/main/ets/Core/AI/Runtime/AIPromptL10n.ets` | 已支持 `prompt()`、`promptFormat()`、`promptIfExists()`，但只面向 `Prompts.strings` |
| 系统提示词解析 | `entry/src/main/ets/Core/AI/Runtime/ChatSystemPromptResolver.ets` | 已支持 `smallTaskPrompt > agentPrompt > sessionPrompt > defaultPrompt` 和 `{{CURRENT_DATE}}` 替换 |
| 关键字工具 | `entry/src/main/ets/Core/AI/Runtime/AIPromptKeywords.ets` | 已支持 `currentDate`、`contains()`、`setting()` |
| 聊天链路接入 | `entry/src/main/ets/Projects/Features/Chat/Application/SendChatMessageUseCase.ets` | 已调用 `promptResolver.resolve(sessionPrompt, agentPrompt, undefined)`，小任务 prompt 当前未传入 |
| 小任务管理 | `entry/src/main/ets/Projects/Features/AISettings/Presentation/SmallTasks/*` | 已有列表、编辑、静态 Prompt 插入抽屉，但没有把小任务对象拼成最终 system prompt |
| 工具调用骨架 | `entry/src/main/ets/Core/AI/Runtime/ToolHub/*` | 已有 ToolHub、Consent、Audit、SideEffect、工具 block，但展示型交互缺 UI 载荷和统一 coordinator |

### 2.2 iOS 参考能力

| iOS 文件 | 参考职责 | HarmonyOS 当前状态 |
|---|---|---|
| `Projects/Core/AIRuntime/PromptLocalizer.swift` | `Prompts.strings` 多语言 prompt 仓库 | 主体已迁，需补单测和边界对齐 |
| `Projects/Core/AIRuntime/AIPromptL10n.swift` | 同时读取 `Prompts` 与 `ToolPrompts` | `ToolPrompts` 读取未迁 |
| `Projects/Core/AIRuntime/ChatSystemPromptResolver.swift` | 接收 `SmallTask` 对象并拼装 `【小任务】/【任务简介】/【任务设定 / Prompt】/【允许工具】` | Harmony 只接收 `smallTaskPrompt?: string`，真实调用传 `undefined` |
| `Projects/Core/AIRuntime/SystemMessageSettingsPrompt.swift` | 会话系统消息设置 Sheet 载荷 | 未迁 |
| `Projects/Core/AIRuntime/HealthResourceToolCandidatePrompt.swift` | 健康资料工具候选确认 Sheet 载荷 | 未迁 |
| `Projects/Core/AIRuntime/AskReportPickerPrompt.swift` | 手动“问报告”选择器载荷 | 未迁 |
| `Projects/Features/Chat/Presentation/ToolInteraction/Models/ToolPreviewPrompt.swift` | 工具详情 Sheet 载荷和参数展示文本 | 未迁 |
| `Projects/App/Resources/*/ToolPrompts.strings` | 工具 schema、参数、摘要文案 | 未迁到 Harmony rawfile |

## 3. 阶段 1 未完成项与实现方案

### 3.1 小任务系统提示词对象拼装未接入

当前问题：

`ChatSystemPromptResolver.ets` 只接收 `smallTaskPrompt?: string`，没有接收 `LocalSmallTask` 对象。`SendChatMessageUseCase.ets` 调用时第三个参数固定为 `undefined`，所以“小任务优先级”在真实聊天链路里没有发挥作用。

目标行为：

与 iOS 一致，小任务被选中时最终 system prompt 必须由小任务对象拼装，格式稳定：

```text
【小任务】
<task.name>

【任务简介】
<task.brief 或 无>

【任务设定 / Prompt】
<task.prompt>

【允许工具】
<task.toolList 逗号拼接>
```

实现方案：

1. 在 `ChatSystemPromptResolver.ets` 引入 `LocalSmallTask` 类型。
2. 新增 `resolveWithTask(sessionPrompt, agentPrompt, smallTask?: LocalSmallTask)`，保留现有 `resolve()` 作为兼容入口。
3. 新增 `makeSmallTaskSystemPrompt(task: LocalSmallTask)`，使用 HarmonyOS ArkTS 字符串模板拼接。
4. 在聊天发送链路中从当前线程/输入上下文取选中的小任务 code，解析为 `LocalSmallTask` 后传入 resolver。
5. 如果当前聊天 UI 还没有“选中的小任务”状态，应先在 `ChatTabPage` 或 Composer ViewModel 增加 `selectedSmallTaskCode?: string`，发送时传给 UseCase。

关键代码示例：

```ts
// entry/src/main/ets/Core/AI/Runtime/ChatSystemPromptResolver.ets
import { LocalSmallTask } from '../Domain/AIConfigModels';

export class ChatSystemPromptResolver {
  resolveWithTask(
    sessionPrompt?: string,
    agentPrompt?: string,
    smallTask?: LocalSmallTask
  ): string {
    let resolved = this.defaultPrompt;
    if (smallTask) {
      resolved = ChatSystemPromptResolver.makeSmallTaskSystemPrompt(smallTask);
    } else if (agentPrompt && agentPrompt.trim().length > 0) {
      resolved = agentPrompt.trim();
    } else if (sessionPrompt && sessionPrompt.trim().length > 0) {
      resolved = sessionPrompt.trim();
    }
    return ChatSystemPromptResolver.replaceDateKeyword(resolved);
  }

  private static makeSmallTaskSystemPrompt(task: LocalSmallTask): string {
    const blocks: string[] = [
      `【小任务】\n${task.name}`,
      `【任务简介】\n${task.brief && task.brief.length > 0 ? task.brief : '无'}`,
      `【任务设定 / Prompt】\n${task.prompt}`
    ];
    if (task.toolList && task.toolList.length > 0) {
      blocks.push(`【允许工具】\n${task.toolList.join(', ')}`);
    }
    return blocks.join('\n\n');
  }
}
```

发送链路示例：

```ts
// entry/src/main/ets/Projects/Features/Chat/Application/SendChatMessageUseCase.ets
const selectedTask = selectedSmallTaskCode
  ? AIConfigSmallTaskSelector.find(runtime.smallTasks, selectedSmallTaskCode)
  : undefined;

const systemPrompt = this.promptResolver.resolveWithTask(
  sessionPrompt ?? thread.rolePrompt,
  agentPrompt ?? resolved.systemProvision,
  selectedTask
);
```

### 3.2 `ToolPrompts.strings` 读取能力缺失

当前问题：

iOS `AIPromptL10n` 提供 `tool(_:)`，用于读取 `ToolPrompts.strings`。HarmonyOS 当前 `AIPromptL10n.ets` 只处理 `Prompts.strings`，导致工具 schema、参数说明、工具摘要文案无法走同一套多语言仓库。

目标行为：

HarmonyOS 增加：

```text
rawfile/ai/prompts/zh-Hans/ToolPrompts.strings
rawfile/ai/prompts/zh-Hant/ToolPrompts.strings
rawfile/ai/prompts/en/ToolPrompts.strings
```

并在 `AIPromptL10n.ets` 增加 `tool()`、`toolFormat()`、`toolIfExists()`。

关键代码示例：

```ts
// entry/src/main/ets/Core/AI/Runtime/AIPromptL10n.ets
tool(key: string, fallback?: string): string {
  return this.localizedString('ToolPrompts.strings', key, fallback ?? key);
}

toolFormat(key: string, fallback: string, args: string[]): string {
  return AIPromptL10n.format(this.tool(key, fallback), args);
}
```

资源读取实现应复用当前 `Prompts.strings` 的 parser，不新增第二套字符串解析逻辑。若当前 parser 的方法名固定为 `prompt()`，建议将内部读取方法抽成：

```ts
private localizedString(fileName: string, key: string, fallback: string): string
```

### 3.3 日期指令资源 key 与本地化缺口

当前问题：

iOS 使用 `ai_runtime.prompt.current_date_instruction_format`。HarmonyOS 当前读取的是 `ai_runtime_prompt_current_date_instruction_format`。两端资源 key 不一致，未来跨端对照容易漂移。

目标行为：

HarmonyOS 允许兼容两个 key，优先使用 iOS 稳定 key，其次使用现有 Harmony key，最后 fallback 英文。

关键代码示例：

```ts
private static readDateInstructionTemplate(fallback: string): string {
  const ctx = ChatSystemPromptResolver.context;
  if (!ctx) {
    return fallback;
  }
  const keys: string[] = [
    'ai_runtime.prompt.current_date_instruction_format',
    'ai_runtime_prompt_current_date_instruction_format'
  ];
  for (let i = 0; i < keys.length; i++) {
    const value = ctx.resourceManager.getStringByNameSync(keys[i]);
    if (value && value.length > 0 && value !== keys[i]) {
      return value;
    }
  }
  return fallback;
}
```

### 3.4 阶段 1 单测缺失

需要新增测试：

| 测试文件 | 用例 |
|---|---|
| `entry/src/test/ets/AI/PromptLocalizer.test.ets` | 三语言 key 读取、缺失 fallback、`%@` format、多行 prompt 保真 |
| `entry/src/test/ets/AI/ChatSystemPromptResolver.test.ets` | 默认、会话、Agent、小任务优先级；日期替换；空白 prompt 过滤 |
| `entry/src/test/ets/AI/AIPromptKeywords.test.ets` | `contains()`、`setting()` 开关行添加/移除、重复关键字去重 |

验收标准：

| 编号 | 验收项 |
|---|---|
| P1-1 | 选择小任务发送消息时，Runtime request 的首条 system message 包含 `【小任务】`、`【任务简介】`、`【任务设定 / Prompt】` |
| P1-2 | 未选择小任务时，仍保持 Agent > 会话 > 默认的优先级 |
| P1-3 | `{{CURRENT_DATE}}` 被替换为设备当前日期，格式 `yyyy-MM-dd` |
| P1-4 | `Prompts.strings` 缺 key 时回退 fallback，不崩溃 |
| P1-5 | `ToolPrompts.strings` 可通过 `AIPromptL10n.tool()` 读取 |

## 4. 阶段 2 未完成项与实现方案

### 4.1 展示型 Prompt 载荷模型未迁

目标目录：

```text
entry/src/main/ets/Core/AI/Runtime/
├── SystemMessageSettingsPrompt.ets
├── HealthResourceToolCandidatePrompt.ets
└── AskReportPickerPrompt.ets

entry/src/main/ets/Projects/Features/Chat/Presentation/ToolInteraction/Models/
└── ToolPreviewPrompt.ets
```

ArkTS 模型示例：

```ts
// entry/src/main/ets/Core/AI/Runtime/SystemMessageSettingsPrompt.ets
import { PromptRepo } from '../../../Projects/Features/AISettings/Domain/PromptRepo';

export class SystemMessageSettingsPrompt {
  id: string = '';
  threadID: string = '';
  sessionPrompt: string = '';
  defaultPrompt: string = '';
  modelDisplayName: string = '';
  isAgentModel: boolean = false;
  agentPrompt?: string;
  promptTemplates: PromptRepo[] = [];

  static create(input: Partial<SystemMessageSettingsPrompt>): SystemMessageSettingsPrompt {
    const p = new SystemMessageSettingsPrompt();
    p.id = input.id ?? `${Date.now()}_${Math.random()}`;
    p.threadID = input.threadID ?? '';
    p.sessionPrompt = input.sessionPrompt ?? '';
    p.defaultPrompt = input.defaultPrompt ?? '';
    p.modelDisplayName = input.modelDisplayName ?? '';
    p.isAgentModel = input.isAgentModel ?? false;
    p.agentPrompt = input.agentPrompt;
    p.promptTemplates = input.promptTemplates ?? [];
    return p;
  }
}
```

```ts
// entry/src/main/ets/Core/AI/Runtime/HealthResourceToolCandidatePrompt.ets
import { HealthResourceToolCandidateDTO } from './ToolHub/Models/ToolingModels';

export class HealthResourceToolCandidatePrompt {
  id: string = '';
  threadID: string = '';
  candidates: HealthResourceToolCandidateDTO[] = [];
  maxSelectable: number = 1;

  static create(threadID: string, candidates: HealthResourceToolCandidateDTO[], maxSelectable: number): HealthResourceToolCandidatePrompt {
    const p = new HealthResourceToolCandidatePrompt();
    p.id = `${Date.now()}_${Math.random()}`;
    p.threadID = threadID;
    p.candidates = candidates;
    p.maxSelectable = Math.max(1, maxSelectable);
    return p;
  }
}
```

```ts
// entry/src/main/ets/Core/AI/Runtime/AskReportPickerPrompt.ets
export class AskReportPickerPrompt {
  id: string = '';
  threadID: string = '';
  memberID: number = 0;

  static create(threadID: string, memberID: number): AskReportPickerPrompt {
    const p = new AskReportPickerPrompt();
    p.id = `${Date.now()}_${Math.random()}`;
    p.threadID = threadID;
    p.memberID = memberID;
    return p;
  }
}
```

```ts
// entry/src/main/ets/Projects/Features/Chat/Presentation/ToolInteraction/Models/ToolPreviewPrompt.ets
export class ToolPreviewPrompt {
  id: string = '';
  toolName: string = '';
  toolContent: string = '';
  toolArguments?: Record<string, string>;
  toolCallID?: string;
  threadID: string = '';
  sourceClientMessageID: string = '';
  relatedBlockIDs: string[] = [];

  static displayText(toolArguments: Record<string, string>): string {
    return Object.keys(toolArguments)
      .sort()
      .map((key: string) => {
        const value = (toolArguments[key] ?? '').trim();
        return value.length === 0 ? key : `${key}: ${value}`;
      })
      .join('\n');
  }
}
```

注意：如果 Harmony 现有 `HealthResourceRef` / Tool DTO 命名不同，不新增重复 DTO，应在现有 `ToolingModels.ets` 或 `Composer/Models/HealthResourceRef.ets` 上扩展 mapper。

### 4.2 `ToolInteractionCoordinator` 队列未迁

当前问题：

iOS 使用统一 coordinator 管理工具预览、系统提示词设置、健康资料候选确认、问报告 picker。HarmonyOS 当前页面中分散处理，缺少统一活动 Sheet 状态和完成回调。

目标目录：

```text
entry/src/main/ets/Projects/Features/Chat/Presentation/ToolInteraction/
├── ToolInteractionCoordinator.ets
├── ToolInteractionSnapshot.ets
├── ToolInteractionPresentationSheet.ets
├── Sheets/
│   ├── ToolPreviewSheet.ets
│   ├── SystemMessageSettingsSheet.ets
│   ├── HealthResourceCandidateSheet.ets
│   └── AskReportPickerSheet.ets
└── Models/
    └── ToolPreviewPrompt.ets
```

关键代码示例：

```ts
// ToolInteractionSnapshot.ets
import { SystemMessageSettingsPrompt } from '../../../../../Core/AI/Runtime/SystemMessageSettingsPrompt';
import { HealthResourceToolCandidatePrompt } from '../../../../../Core/AI/Runtime/HealthResourceToolCandidatePrompt';
import { AskReportPickerPrompt } from '../../../../../Core/AI/Runtime/AskReportPickerPrompt';
import { ToolPreviewPrompt } from './Models/ToolPreviewPrompt';

export type ToolInteractionKind =
  | 'toolPreview'
  | 'systemMessageSettings'
  | 'healthResourceCandidates'
  | 'askReportPicker';

export class ToolInteractionSnapshot {
  kind: ToolInteractionKind = 'toolPreview';
  toolPreview?: ToolPreviewPrompt;
  systemMessageSettings?: SystemMessageSettingsPrompt;
  healthResourceCandidates?: HealthResourceToolCandidatePrompt;
  askReportPicker?: AskReportPickerPrompt;
}
```

```ts
// ToolInteractionCoordinator.ets
export type ToolInteractionChanged = (snapshot?: ToolInteractionSnapshot) => void;

export class ToolInteractionCoordinator {
  private active?: ToolInteractionSnapshot;
  private onChanged?: ToolInteractionChanged;

  setOnChanged(handler: ToolInteractionChanged): void {
    this.onChanged = handler;
  }

  current(): ToolInteractionSnapshot | undefined {
    return this.active;
  }

  present(snapshot: ToolInteractionSnapshot): void {
    this.active = snapshot;
    this.onChanged?.(this.active);
  }

  dismiss(): void {
    this.active = undefined;
    this.onChanged?.(undefined);
  }
}
```

Sheet 容器示例：

```ts
// ToolInteractionPresentationSheet.ets
@Component
export struct ToolInteractionPresentationSheet {
  @Prop snapshot?: ToolInteractionSnapshot;
  onDismiss: () => void = () => {};

  build() {
    if (!this.snapshot) {
      Blank()
    } else if (this.snapshot.kind === 'toolPreview' && this.snapshot.toolPreview) {
      ToolPreviewSheet({ prompt: this.snapshot.toolPreview, onClose: this.onDismiss })
    } else if (this.snapshot.kind === 'systemMessageSettings' && this.snapshot.systemMessageSettings) {
      SystemMessageSettingsSheet({ prompt: this.snapshot.systemMessageSettings, onClose: this.onDismiss })
    } else if (this.snapshot.kind === 'healthResourceCandidates' && this.snapshot.healthResourceCandidates) {
      HealthResourceCandidateSheet({ prompt: this.snapshot.healthResourceCandidates, onClose: this.onDismiss })
    } else if (this.snapshot.kind === 'askReportPicker' && this.snapshot.askReportPicker) {
      AskReportPickerSheet({ prompt: this.snapshot.askReportPicker, onClose: this.onDismiss })
    } else {
      Blank()
    }
  }
}
```

### 4.3 系统提示词设置 Sheet 未迁

目标行为：

用户在聊天详情页打开系统消息设置时，应看到当前会话 prompt、默认 prompt、当前模型名、是否 Agent、Agent prompt 只读预览、PromptRepo 模板插入能力。保存后更新线程 `rolePrompt`，下一轮发送进入 `ChatSystemPromptResolver`。

实现方案：

1. 新建 `SystemMessageSettingsSheet.ets`。
2. 从 Chat 当前线程、resolved model 和 prompt repo 构造 `SystemMessageSettingsPrompt`。
3. Sheet 中使用 `TextArea` 编辑 `sessionPrompt`。
4. Agent prompt 只展示，不直接覆盖 agent。
5. 保存调用 `ChatRepository.updateThreadGenerationConfig()` 或新增专用 `updateThreadRolePrompt()`，避免重复传 generation 参数。

关键代码示例：

```ts
private presentSystemMessageSettings(): void {
  const prompt = SystemMessageSettingsPrompt.create({
    threadID: this.currentThread.clientId,
    sessionPrompt: this.currentThread.rolePrompt,
    defaultPrompt: new PromptLocalizer().chatSystemPrompt(),
    modelDisplayName: this.currentModelDisplayName,
    isAgentModel: this.currentModelIdentity === 'agent',
    agentPrompt: this.currentAgentPrompt,
    promptTemplates: this.promptRepo
  });
  this.toolInteractionCoordinator.present(ToolInteractionSnapshots.systemMessageSettings(prompt));
}
```

### 4.4 工具预览 Sheet 未迁

目标行为：

点击聊天中的工具 block 时，弹出工具详情，展示工具名、参数、输出、toolCallID、关联 block。参数用 `ToolPreviewPrompt.displayText()` 稳定排序，避免 UI 每次顺序跳动。

关键代码示例：

```ts
private presentToolPreview(block: ChatMessageBlock, message: ChatMessage): void {
  const payload = ToolBlockPayload.decode(block.payloadJson);
  const prompt = new ToolPreviewPrompt();
  prompt.id = `${Date.now()}_${Math.random()}`;
  prompt.toolName = payload.toolName;
  prompt.toolContent = payload.outputText;
  prompt.toolArguments = payload.arguments;
  prompt.toolCallID = payload.toolCallID;
  prompt.threadID = message.threadClientId;
  prompt.sourceClientMessageID = message.clientId;
  prompt.relatedBlockIDs = [block.blockId];
  this.toolInteractionCoordinator.present(ToolInteractionSnapshots.toolPreview(prompt));
}
```

### 4.5 健康资料候选确认与问报告 Picker 未迁

目标行为：

与 iOS 一致，AI 工具或用户手动“问报告”需要选择健康资料时，进入统一 Sheet 队列：

| 入口 | 载荷 | 完成后 |
|---|---|---|
| 工具候选确认 | `HealthResourceToolCandidatePrompt` | 返回用户选择的 `HealthResourceToolCandidateDTO[]` 给工具调用流程 |
| 手动问报告 | `AskReportPickerPrompt` | 返回 `HealthResourceRef[]`，追加到 composer 的健康资料引用列表 |

HarmonyOS 当前已有 `HealthResourceRef`、引用预览条和 `onPresentAskReportPicker()` 入口，但 picker 内容和统一 coordinator 未完成。

实现步骤：

1. 新建 `AskReportPickerPrompt.ets` 并接入 `ChatTabPage.onPresentAskReportPicker()`。
2. 新建 `AskReportPickerSheet.ets`，复用现有 Medical/HealthExam/Medication 数据源；若数据源未完成，先做 repository 接口和空态，不写假数据。
3. 选择后把 `HealthResourceRef[]` 写回 `ChatTabPage.healthResourceRefs`。
4. 发送时继续使用现有附件/健康资料 block 逻辑，确保用户消息入库后能渲染 `healthResourceReference`。

### 4.6 `ToolPrompts.strings` 未迁

目标资源：

```text
entry/src/main/resources/rawfile/ai/prompts/zh-Hans/ToolPrompts.strings
entry/src/main/resources/rawfile/ai/prompts/zh-Hant/ToolPrompts.strings
entry/src/main/resources/rawfile/ai/prompts/en/ToolPrompts.strings
```

迁移规则：

| 规则 | 说明 |
|---|---|
| key 保持 iOS 一致 | 例如 `tool.summary.*`、`tool.param.*`、`tool.result.*` |
| 表名语义保持一致 | `Prompts.strings` 管模型 system/extraction prompt；`ToolPrompts.strings` 管工具 schema/工具展示文案 |
| fallback 不得为空 | 缺失 key 时返回 key 或英文 fallback，不能让工具 schema 出现空 description |
| 工具定义集中读取 | `ToolHub.buildAllDefinitions()` 通过 `PromptLocalizer` 或 `AIPromptL10n.tool()` 获取说明 |

工具定义示例：

```ts
private makeFetchHealthSummaryDefinition(): AIRuntimeToolDefinition {
  const d = new AIRuntimeToolDefinition();
  d.name = 'fetch_health_summary';
  d.description = this.localizer.toolText(
    'tool.summary.fetch_health_summary',
    'Fetch recent health summary for the selected member.'
  );
  d.parametersJson = JSON.stringify({
    type: 'object',
    properties: {
      memberId: {
        type: 'string',
        description: this.localizer.toolText('tool.param.member_id', 'Member ID')
      }
    },
    required: ['memberId']
  });
  return d;
}
```

## 5. 推荐实施顺序

| 优先级 | 内容 | 原因 |
|---|---|---|
| P0 | 补 `AIPromptL10n.tool()` 和三语言 `ToolPrompts.strings` | 后续 ToolHub schema 和 UI 文案都依赖它 |
| P0 | 改造 `ChatSystemPromptResolver` 支持 `LocalSmallTask` 对象拼装，并接入发送链路 | 阶段 1 当前最大真实链路缺口 |
| P0 | 新增 `SystemMessageSettingsPrompt.ets` 和系统提示词设置 Sheet | 对话系统提示词是用户可见核心能力 |
| P1 | 新增 `ToolPreviewPrompt.ets`、`ToolInteractionCoordinator.ets`、ToolPreview Sheet | 工具 block 已存在，缺详情展示 |
| P1 | 新增 `AskReportPickerPrompt.ets` 和 AskReport Picker Sheet | 当前问报告入口已有，但选择器未闭环 |
| P1 | 新增 `HealthResourceToolCandidatePrompt.ets` 和候选确认 Sheet | 工具主动候选选择依赖它 |
| P2 | 补测试、日志、异常和空态 | 降低后续迁移 PromptRepo、医疗/营养工厂时的回归风险 |

## 6. 验收清单

| 编号 | 验收项 | 状态要求 |
|---|---|---|
| A1 | `PromptLocalizer` 继续读取三语言 `Prompts.strings` | 单测覆盖 |
| A2 | `AIPromptL10n.tool()` 能读取三语言 `ToolPrompts.strings` | 单测覆盖 |
| A3 | 小任务选中后最终 system prompt 包含小任务结构化块 | Runtime request 可观测 |
| A4 | 小任务未选中时保持 Agent > 会话 > 默认优先级 | 单测覆盖 |
| A5 | `{{CURRENT_DATE}}` 替换使用当前设备日期 | 单测覆盖 |
| B1 | 系统提示词设置 Sheet 能展示默认、会话、Agent prompt，并保存会话 prompt | 手动验收 |
| B2 | 工具 block 点击能打开工具预览 Sheet，参数稳定排序展示 | 手动验收 |
| B3 | 手动问报告能打开 picker，选择后回填 composer 健康资料引用 | 手动验收 |
| B4 | 健康资料工具候选确认能限制最大选择数，取消时不中断聊天状态 | 手动验收 |
| B5 | 所有新增 sheet 关闭后清理 coordinator active 状态，避免重复弹层 | 单测或手动验收 |

## 7. 非目标

本工单不实现以下内容：

| 内容 | 原因 |
|---|---|
| PromptRepo 完整仓库 CRUD 页面 | 属于阶段 3，应另开 AI 设置 PromptRepo 工单 |
| MedicalPromptFactory / NutritionPromptFactory 独立迁移 | 属于阶段 4，应随医疗文书、营养业务模块迁移 |
| MemoryPromptBuilder | 属于阶段 5，依赖 Memory 检索能力 |
| 真实健康工具完整执行器 | 属于 ToolHub 业务工具工单，本工单只补 prompt 资源和展示交互载荷 |

## 8. 风险与注意事项

| 风险 | 处理 |
|---|---|
| `PromptLocalizer.ets` 已承载医疗/营养工厂职责，继续膨胀会变难维护 | 本工单只补底座和交互缺口，不再往 `PromptLocalizer` 塞新的 Feature 工厂 |
| HarmonyOS 没有 Swift 的 `Identifiable/Codable/Sendable` 语义 | 使用 class DTO + 明确 `static create()` / mapper / JSON encode decode |
| Sheet 队列可能和 Navigation 栈冲突 | 工具交互统一使用 `ToolInteractionCoordinator` 持有 active snapshot，页面只渲染当前 snapshot |
| 工具 prompt key 缺失导致 schema description 为空 | `tool()` 必须有 fallback，测试覆盖缺 key |
| 小任务 prompt 拼装与工具授权不一致 | `【允许工具】` 只影响 system prompt 文案，实际可调用工具仍以 `ChatOrchestratorInferenceOptions.allowedToolNames` 和 ToolHub 授权为准 |

