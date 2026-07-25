# AI Runtime 推理编排鸿蒙实现偏差纠正工单

> 工单编号：HOS-AIRUNTIME-ALIGN-0001
>
> 工单类型：iOS → HarmonyOS 业务流程、数据模型、代码结构和技术方案纠偏
>
> 审计日期：2026-07-22
>
> 参考端：`SparkClient/SparkClient`
>
> 目标端：`SparkClientHarmonyOS`
>
> 关联文档：`SparkClient/总领文档/对话、AI Runtime 与工具调用/AI Runtime 推理编排需求.md`、`SparkClientHarmonyOS/开发详细技术文档/对话、AI Runtime 与工具调用/AI Runtime 推理编排详细技术方案.md`
>
> 默认工作模式：本文维护审计与实施工单；**2026-07-22 已按 §8.1 P0-B～P0-E / 部分 P1 落地最小可运行骨架，并完成第二波：Prompt/Reasoning/ToolHub 骨架/非 chat 样例与文档事实同步**（见下方实施记录）。关闭工单仍需真机与完整验收清单。

## 实施记录（2026-07-22）

| 阶段 | 状态 | 产物摘要 |
|---|---|---|
| P0-A 文档事实 | 已做（本轮） | 详细技术方案已去掉“无 Orchestrator/非流式/Chat 未发现”等旧表述；本工单同步第二波事实 |
| P0-B Domain/Mapper/Error | 已做 | `AIRuntimeErrors` / `AIRuntimeMappers` / `AIRuntimeSseParser` / `OpenAIChatBodyEncoder` / `ScenarioPolicyResolver` |
| P0-C SSE/Provider | 已做 | Adapter 改用 Encoder+Parser；终态幂等；错误体解析；SSE 单测 |
| P0-D Chat Domain/RDB/UseCase | 已做（最小闭环） | `Features/Chat` + `chat_*` 表 + `SendChatMessageUseCase` + `ChatTabPage`/主 Tab；本轮补 SystemPrompt / 成员上下文 / deepThought 回灌；仍缺 iOS 级线程、附件、富消息块、远端同步 |
| P0-E MessageRunActor | 已做 | partial text/reasoning/tool block + 终态幂等 + generation 丢弃旧回调 |
| P1-A ToolHub | 部分（本轮加深） | Consent/Audit/SideEffectSink + `debug_echo` + `/audit_tools`；业务工具未齐 |
| P1-B Reasoning | 已做（本轮） | `RuntimeReasoningPolicy` 三分支；`RuntimeToolCallLoopStrategy` DeepSeek `reasoning_content` |
| P1-C 非 chat | 部分（本轮） | `StructuredRuntimeClient` + 医疗文档类型识别样例已装配；正式 Feature 消费仍缺 |
| P2 GGUF | 保持 | `localEngineUnavailable`，禁止伪成功 |
| 测试 | 已做（本轮） | `ChatRuntimeWave2.test.ets`（reasoning/cancel/ToolHub/Orchestrator/Structured） |

`assembleHap`：本轮已通过。

## 1. 对标范围与结论

### 1.1 对标范围

本工单不是把 Swift 文件逐行翻译成 ArkTS，而是以 iOS 当前可运行代码的业务语义为基线，纠正 HarmonyOS 以下方面的偏差：

- AI 场景配置解析、有效快照、账号隔离和运行时生命周期。
- `AIRuntimeTextRequest`、`AIRuntimeMessage`、tools、reasoning、流事件和错误模型。
- 本地/远端模型路由、Agent `baseModelName`、工具能力降级和 Provider 请求体。
- OpenAI-compatible SSE、reasoning、tool call delta、`[DONE]`、服务端包裹响应和取消。
- `ChatOrchestrator` 的历史组包、多轮工具循环、工具锁定、空输出和回退文案。
- Chat Feature 到 Runtime 的真实业务调用链、消息落库、partial 更新和账号切换清理。
- HarmonyOS 代码目录、组合根、测试、日志和现有技术方案的事实漂移。

### 1.2 事实优先级

1. iOS 当前 Swift 代码和测试。
2. HarmonyOS 当前 ArkTS 代码、组合根、测试和构建配置。
3. 服务端/后端契约；当前工作区没有可直接核验的服务端工程，因此 API 业务码和服务端实现仍需后端确认。
4. 两端已有技术文档。
5. 注释、命名和规划文字。

### 1.3 总体结论

HarmonyOS 当前状态应标记为：**Runtime 基础能力和远端流式适配器已实现，ChatOrchestrator 已由 AppContainer 装配，Chat Feature 已形成最小“主 Tab → 本地 RDB → UseCase → Orchestrator → MessageRunActor”闭环，并补齐 SystemPrompt / 成员上下文 / reasoning 三分支 / tool block 落库；但尚未达到 iOS 等价业务完整度。ToolHub 目前是联调级注册表（Consent/Audit/Sink + `debug_echo`/`/audit_tools`），真实医疗工具仍未完成；非 chat 已有 `StructuredRuntimeClient` 样例入口，正式 Feature 消费仍缺。**

已确认的 HarmonyOS 代码事实：

- `Core/AI/Runtime/AIRuntimeService.ets` 已有 `generateTextStream`、`generateText`、`cancel`、`cancelAll`、账号失效和 tools 降级。
- `OpenAICompatibleProviderAdapter.ets` 已有 `requestInStream`、`dataReceive`、SSE 行解析、文本/推理/tool call 事件、`destroy` 和非流式解析。
- `ChatOrchestrator.ets` 已有最多 30 轮循环、历史组包、reasoning 三分支、DeepSeek tool `reasoning_content`、tool call 回灌、空输出和工具锁定骨架。
- `ChatSystemPromptResolver` / `PromptLocalizer` / `RuntimeReasoningPolicy` / `RuntimeToolCallLoopStrategy` 已落地。
- `AppContainer.ets` 已装配 `AIRuntimeService`、`ChatOrchestrator`、`ToolHub`、`ChatRepository`、`MessageRunActor`、`SendChatMessageUseCase`、`StructuredRuntimeClient`；`Projects/App/MainTabsPage.ets` 已将 `ChatTabPage` 接入主 Tab，Playground 仍只是诊断入口。
- `Projects/Features/Chat` 已存在最小实现：`ChatModels.ets`、`ChatSchema.ets`、`ChatRepository.ets`、`SendChatMessageUseCase.ets`、`MessageRunActor.ets`、`MemberContextSummaryBuilder.ets`、`ChatTabPage.ets`；不能再写成“未发现 Chat Feature”，但必须标记为“最小闭环/部分实现”。
- `ToolHub/` 已含 `ToolRegistry`、`ToolConsentStore`、`ToolAuditStore`、`ToolSideEffectSink`；不是固定空数组。
- `AppDatabaseSchema.ets` 已注册 `ChatSchema.ddlStatements()`；`AppContainer.ets` 在账号切换/登出路径调用 `aiRuntimeService.invalidateAccount()`、`messageRunActor.bumpGeneration()` 和 `chatRepository.deleteAccountData()`。
- `AIRuntimeService`、Adapter、Wave2（reasoning/cancel/ToolHub/Orchestrator/Structured）测试已存在。

已确认的关键偏差：

| 类别 | 当前问题 | 结论 |
|---|---|---|
| 文档事实 | 详细技术方案已同步第二波；矩阵若仍有旧表述需继续扫 | 以代码与本工单实施记录为准 |
| Chat 集成 | 已有完整最小链路 + SystemPrompt/成员摘要/tool block；历史仍未覆盖 contentParts、多模态、线程管理和同步 | “部分实现”，不能标记为 iOS 等价 |
| ToolHub | Consent/Audit/Sink 骨架 + `debug_echo`；真实业务工具/持久化授权仍缺 | 联调能力已存在，但不能满足 iOS 工具业务 |
| Provider | 已有 SSE，但需核对流事件、错误包裹、reasoning 厂商字段、Agent base model 和多模态编码 | 远端适配器为部分实现 |
| 数据模型 | ArkTS Runtime 模型已加宽，但 `AIRuntimeToolDefinition.parametersJson` 与 iOS 结构化 schema 仍不完全等价，role 仍是 string | 必须补显式 mapper、校验和兼容规则 |
| 取消 | 已调用 `destroy()`，但请求级 token、Adapter 事件终止、页面/账号 generation 和多轮工具取消还需端到端验证 | 不能只凭 `cancel()` 存在标记完成 |
| 非 chat | 已有 `StructuredRuntimeClient.recognizeMedicalDocumentType` 样例；医疗/营养/知识库正式 Feature 消费表仍缺 | 样例≠正式接入 |

### 1.4 纠偏目标

完成后 HarmonyOS 应达到以下可观察语义：

```text
场景配置快照
  → 精确解析 scenario / preferred model / source
  → 校验文本、多模态、tools、reasoning 能力
  → ChatOrchestrator（仅 chat）或 Feature 直连 Runtime（非 chat）
  → OpenAI-compatible SSE / 明确本地不可用
  → textDelta / reasoningDelta / toolCallDelta / completed
  → Chat 多轮工具编排或结构化 JSON 消费
  → 取消、错误、重试、partial 落库和账号清理
```

## 2. 华为端目录设计

### 2.1 当前目录与 iOS 职责映射

| iOS 当前文件/职责 | HarmonyOS 当前文件 | 当前状态 | 纠偏要求 |
|---|---|---|---|
| `Projects/Core/AI/AIConfigCenter.swift` | `Core/AI/Application/AIConfigRepository.ets`、`AIConfigResolver.ets` | 已有对应能力，但拆分语义不同 | 保持配置仓储、Resolver、Snapshot、Runtime 的单向依赖 |
| `Projects/Core/AI/ScenarioPolicyResolver.swift` | `Core/AI/Application/ScenarioPolicyResolver.ets` | 已有 | 精确 preferred、默认策略和 agent 语义必须与 iOS 一致 |
| `Projects/Core/AIRuntime/AIRuntimeService.swift` | `Core/AI/Runtime/AIRuntimeService.ets` | 已有流式骨架 | 补齐请求快照、事件生命周期、错误和 generation 校验 |
| `AIRuntimeModels.swift` | `Core/AI/Domain/AIConfigModels.ets` | 已加宽 | 继续拆出可维护的 `AIRuntimeModels.ets`，保留 JSON/领域 mapper |
| `OpenAICompatibleTextGateway.swift` | `Core/AI/Runtime/OpenAICompatibleProviderAdapter.ets` | SSE 已有 | 按 iOS 网关行为补齐 body、错误、SSE 和厂商字段 |
| `LocalGGUFTextGateway.swift` | `Core/AI/Runtime/LocalModelAdapter.ets` | 明确占位错误 | 保持失败语义，真实引擎另立工单，禁止 echo/伪成功 |
| `AIRuntimeCancellation.swift` | `Core/AI/Runtime/AIRuntimeCancellation.ets` | token 已有 | 与 HTTP destroy、Orchestrator、页面和账号切换做端到端闭环 |
| `ChatOrchestrator.swift` | `Core/AI/Runtime/ChatOrchestrator.ets` | 已接入最小 Chat + reasoning/tool 循环 | 继续补多模态上下文与业务工具 |
| `ChatOrchestratorInferenceOptions.swift` | 同名 `.ets` | 已有 | 字段、默认值和三分支 reasoning 语义对齐 |
| `ToolHub/**` | `Core/AI/Runtime/ToolHub/**` | Consent/Audit/Sink + `debug_echo` | 联调级 | 按工具调用专项补真实业务工具与持久化授权 |
| `Features/Chat/Application/SendChatMessageUseCase.swift` | `Projects/Features/Chat/Application/SendChatMessageUseCase.ets` | 最小等价链路 + SystemPrompt/成员上下文 | 已接入但不完整 | 补线程配置、附件/多模态、失败/重试和同步 |
| `MessageRunActor.swift` | `Projects/Features/Chat/Application/MessageRunActor.ets` | partial/reasoning/tool block/终态幂等/generation | 部分实现 | 补 rich block、重试和恢复 |
| `AssemblyProducts.swift` | `App/AppContainer.ets` | Runtime + Orchestrator + Chat + StructuredRuntimeClient | 继续作为唯一组合根 | 禁止页面 new Runtime/ToolHub |
| `Tests/AI/AISettingsAndResolverTests.swift` | `entry/src/test/ets/AI/*` | 含 Wave2 Orchestrator/Reasoning/ToolHub/Cancel | 有基础+Wave2 测试 | 增加真机 SSE、账号和真实入口测试 |

### 2.2 目标目录设计

```text
SparkClientHarmonyOS/entry/src/main/ets/
├── App/
│   ├── AppContainer.ets                         # 唯一组合根
│   ├── AppBootstrapper.ets                      # 账号登录后配置准备
│   ├── AccountSessionRuntime.ets                # 账号 generation / reset
│   └── AppLifecycleCoordinator.ets              # 前后台生命周期
├── Core/AI/
│   ├── Domain/
│   │   ├── AIConfigModels.ets                   # 配置领域模型
│   │   ├── AIRuntimeModels.ets                  # 目标：Runtime 独立模型
│   │   ├── AIRuntimeErrors.ets                  # 目标：可分类错误
│   │   └── AIRuntimeMappers.ets                 # 目标：JSON ↔ Domain
│   ├── Application/
│   │   ├── AIConfigRepository.ets
│   │   ├── AIConfigResolver.ets
│   │   ├── ScenarioPolicyResolver.ets
│   │   └── ProOverlayMaterializer.ets
│   ├── Infrastructure/
│   │   ├── AIConfigRdbStore.ets
│   │   ├── AIConfigSchema.ets
│   │   ├── AIKeyStore.ets
│   │   ├── AIConfigSeedLoader.ets
│   │   └── AIConfigFlowLog.ets
│   └── Runtime/
│       ├── AIRuntimeService.ets
│       ├── AIProviderAdapter.ets
│       ├── OpenAICompatibleProviderAdapter.ets
│       ├── OpenAIReasoningPayload.ets
│       ├── LocalModelAdapter.ets
│       ├── AIRuntimeCancellation.ets
│       ├── AIRuntimeSnapshotStore.ets
│       ├── AIRuntimeOutputLog.ets
│       ├── AIRuntimeRequestLogRedactor.ets
│       ├── ChatOrchestrator.ets
│       ├── ChatOrchestratorInferenceOptions.ets
│       ├── ChatSystemPromptResolver.ets          # 目标
│       ├── PromptLocalizer.ets
│       └── ToolHub/                              # 当前：联调级；目标：真实注册/授权/审计/执行
├── Projects/Features/Chat/                       # 当前：最小闭环，目标：iOS 等价业务
│   ├── Domain/                                   # ChatModels.ets
│   ├── Application/                              # UseCase / MessageRunActor
│   ├── Infrastructure/                           # ChatSchema / ChatRepository
│   └── Presentation/                             # ChatTabPage；尚缺 ChatDetail/线程管理
└── Tests/                                       # 当前实际位于 entry/src/test/ets，不是 main/ets/Tests
    ├── AI/
    │   ├── AIRuntimeService.test.ets
    │   ├── AIConfigResolver.test.ets
    │   ├── AIRuntimeSseParser.test.ets            # 目标
    │   ├── AIRuntimeCancellation.test.ets        # 目标
    │   └── ChatOrchestrator.test.ets              # 目标
    └── Chat/                                      # 目标
```

### 2.3 目录纠偏规则

- HarmonyOS 可以使用 ArkTS 目录命名，但业务职责必须和 iOS 一一对应；不能因为当前所有 AI 文件位于 `Core/AI` 就把 Chat、ToolHub、Runtime、配置和 UI 混成一个层。
- `AIRuntimePlaygroundPage.ets` 只能作为开发诊断入口，不得作为生产 Chat Feature 的替代入口；当前生产最小入口是 `Projects/App/MainTabsPage.ets` 中的 `ChatTabPage`。
- `Projects/Features/Chat` 当前是“最小闭环/部分实现”，不能写成“未发现”，也不能用最小闭环推断 Chat 已达到 iOS 完整能力。
- `AIConfigRepository` 负责配置快照和远端 Pro overlay；`AIRuntimeService` 只消费已解析 RuntimeSnapshot，不得重新读取 RDB 或页面配置。
- 工具执行、工具授权和工具副作用不得继续堆入 `ChatOrchestrator.ets`；应建立 `Runtime/ToolHub/` 或等价独立模块。

## 3. 分层职责与请求链路

### 3.1 iOS 基线请求链路

```text
Feature 入口
  → ChatOrchestrator（仅 chat）/非 chat Feature
  → AIRuntimeService.generateTextStream
  → AIConfigCenter.resolve(scenario, preferredModel)
  → ScenarioPolicyResolver / RuntimeOverride / effective bundle
  → tools 能力降级、reasoning 映射、Agent base model
  → LocalGGUF Gateway 或 OpenAICompatible Gateway
  → text/reasoning/toolCall/completed
  → Chat collect + ToolHub 多轮 / 业务 JSON decoder
  → MessageRunActor / Feature 结果 / UI 状态
```

### 3.2 HarmonyOS 当前实际链路

```text
AISettings Runtime Playground
  → AppContainer.chatOrchestrator 或 aiRuntimeService
  → AIRuntimeService
  → AIRuntimeSnapshotStore.get(accountId)
  → pickResolved / applyToolsDegrade
  → LocalModelAdapter 或 OpenAICompatibleProviderAdapter
  → request / requestInStream
  → AIRuntimeEvent
```

生产最小入口还包括：

```text
MainTabsPage → ChatTabPage
  → AppContainer.sendChatMessageUseCase
  → ChatRepository（线程/历史读取，消息/assistant 占位写入）
  → ChatOrchestrator → AIRuntimeService → ProviderAdapter
  → MessageRunActor → ChatRepository / ChatTabPage partial
```

当前已存在但仍不完整/未确认的业务连接：

- Chat 页面/Composer → Chat UseCase → 本地消息模型 → Orchestrator 已有最小链路，尚缺 iOS 级 ChatDetail/Composer/线程管理。
- `MessageRunActor` 已有助手占位、partial 落库和块 revision/generation；tool/rich block、终态恢复和完整测试缺失。
- iOS ChatHistory → `AIRuntimeMessage` 的完整组包，包括 LocalOCR、多模态附件、成员上下文、健康资源引用和 tool messages。
- 工具注册、授权、审计、执行器和副作用 sink。
- 医疗、营养、知识库等非 chat Feature 的真实 Runtime 消费者。

### 3.3 目标状态机

```text
uninitialized
  → seeding
  → localReady
  → refreshing
  → remoteReady / degraded
  → invalidated（账号失效/切换）

Runtime request
  → validating
  → resolved
  → started
  → streaming
  → toolLoop（仅 chat）
  → completed / failed / cancelled
```

状态要求：

- `degraded` 表示配置仍可消费但远端/Pro 刷新失败，不等于 Runtime 不可用。
- `invalidated` 后禁止启动新请求；已经运行的请求必须取消并丢弃旧 generation 的回调。
- Provider 失败不能被改写成正常 `completed`；本地模型不可用必须返回明确 `localEngineUnavailable`。
- 用户取消必须可观察到 `cancelled`，且不能在取消之后继续写 partial 或执行下一轮工具。

## 4. 核心关键技术与实现方案

### 4.1 偏差总表

| 编号 | 优先级 | 偏差 | iOS 事实 | HarmonyOS 现状 | 纠正结果 |
|---|---|---|---|---|---|
| D-001 | P0 | 现有方案曾误报无 Orchestrator | `ChatOrchestrator.swift` 已是聊天统一编排 | `.ets` 已存在且 AppContainer + Chat 已接入 | 文档已纠正；继续按“最小闭环≠完整 Chat”推进 |
| D-002 | P0 | Chat Feature 仅完成最小闭环 | ChatDetail → SendUseCase → MessageRunActor → Orchestrator | `ChatTabPage` → `SendChatMessageUseCase` → `ChatRepository` 已接通；缺 iOS 级线程/附件/富块/同步 | 从最小入口扩展到完整 Chat Feature，并补集成验收 |
| D-003 | P0 | ToolHub 仍非业务完整实现 | ToolHub 有工具定义、授权、执行、副作用与审计 | 已有 `ToolRegistry` + `debug_echo` + `/audit_tools`；真实业务工具、授权、审计和副作用缺失 | 分模块接入真实工具；未完成前不可标工具已对齐 |
| D-004 | P0 | 消息模型只完成最小本地 RDB | `ChatMessage` + `ChatMessageBlock` + Core Data | 已有 `chat_thread`/`chat_message`/`chat_message_block`、Repository、Schema 注册；字段和同步语义仍明显少于 iOS | 补字段、迁移版本、Mapper、线程/块一致性和服务端同步 |
| D-005 | P1 | Runtime 结构类型仍有偏差 | ToolProperty 结构化 Codable、Role enum | parametersJson 字符串、role string | 增加严格 mapper/校验和未知值策略 |
| D-006 | P1 | Agent base model 需要核验 | iOS 出站 model 使用 baseModelName | Harmony Resolver 有 baseModelName 处理，Adapter 需端到端证明 | 增加 agent 解析/HTTP body 测试 |
| D-007 | P1 | SSE 传输已接入最小 Chat，但不等于业务流完成 | iOS 网关 + Orchestrator + MessageRunActor | Adapter → Orchestrator → Chat UseCase → MessageRunActor 已存在，仍缺真机长流、tool/rich block 和恢复验收 | 补 SSE、取消、partial、持久化端到端验收 |
| D-008 | P1 | 取消语义不完整 | token、stream termination、URLSession cancel、Actor 停写 | token + destroy + softCancelled | 增加 generation、终态幂等和 UI/账号测试 |
| D-009 | P1 | 非 chat 消费者仅有样例 | 多个医疗/营养/知识 Feature 直连 Runtime | 已有 `StructuredRuntimeClient`；正式 Feature 消费表仍缺 | 按场景建立调用者和结构化输出验收 |
| D-010 | P2 | 日志/错误与 iOS 不同 | 脱敏 RequestLog、OutputLog、错误分类 | 有 OutputLog/Redactor，但失败日志仍可能 `${err}` | 统一字段白名单和错误映射 |

### 4.2 P0：纠正文档事实与实现状态

修改目标文档：`SparkClientHarmonyOS/开发详细技术文档/对话、AI Runtime 与工具调用/AI Runtime 推理编排详细技术方案.md`。

必须修正：

1. “目标端无 ChatOrchestrator”改为“当前已有 `ChatOrchestrator.ets`，已由 `AppContainer` 装配，并已被最小 `ChatTabPage` 发送链路消费；尚未达到 iOS 完整 Chat Feature，ToolHub 仍为联调级实现”。
2. “统一入口目前是非流式 `generateText`”改为“`generateTextStream` 已存在且为主路径；`generateText` 是非流式便捷封装；真实 Chat/业务接入尚未完成”。
3. “远程 Adapter 非流式 → SSE”改为“当前 Adapter 同时有 `request` 和 `requestInStream` 两条路径；需要通过真机/测试确认厂商流事件和错误边界”。
4. “无 ChatOrchestrator/ToolHub”类结论改为代码事实与接入状态分列，避免文件存在被误写成未发现，也避免最小闭环被误写成已完成。
5. 现有文档中的行号引用在代码变动后必须重新核验，新增本工单作为纠偏记录。

### 4.3 P0：Runtime 请求模型纠偏

#### 4.3.1 `AIRuntimeTextRequest`

至少保持以下字段与 iOS 语义一致：

| 字段 | iOS 语义 | HarmonyOS 当前 | 纠偏要求 |
|---|---|---|---|
| `scenario` | AIScenario | string 常量 | 允许已知 wire value，未知值必须失败或明确降级 |
| `messages` | 角色/文本/多模态/tool messages | 已有但需严格映射 | 不允许空；工具轮次 content 可为空 |
| `tools` | 结构化 tool definitions | 已有 | 不能只在 Domain 存 JSON 字符串而不验证 |
| `toolChoice` | auto/none | 已有 string | 用受限 union/解析函数，不接受任意字符串出站 |
| `reasoning` | enabled/effort/prompt fallback | 已有对象 | 补能力三分支与厂商映射测试 |
| `preferredModelName` | 精确模型选择 | 已有 | 与 Resolver 的精确匹配统一，禁止 `indexOf` 模糊命中 |
| `providerCompany` | 厂商字段 | 已有 | 只用于厂商字段策略，不作为模型身份替代 |
| `temperature/topP/maxTokens` | 请求级覆盖 | 已有部分 | 明确 request override > scenario config，范围服务端/客户端双校验 |
| `cancellationToken` | 协作取消 | 已有 | 必须与 HTTP destroy、Orchestrator 每轮检查和终态事件一致 |
| `accountId/requestId` | 账号与可观测性 | 已有扩展 | 账号从 Session 校验；requestId 必须唯一且跨 round 可追踪 |

#### 4.3.2 `AIRuntimeMessage`

必须支持：

- `system/user/assistant/tool` 四角色。
- `content` 可选；tool call assistant 轮次允许空正文。
- `contentParts` 文本 + `image_url`，保留 `spark:inline-jpeg-base64:` 约定。
- `toolCalls`、`toolCallID`、`name`。
- DeepSeek 等模型需要回灌的 `reasoningContent`。
- 明确 `contentParts` 与 `content` 的互斥/优先规则，禁止再次发生 LocalOCR/图片被纯文本覆盖。

HarmonyOS `role: string` 可作为 JSON 边界字段，但在进入 Orchestrator 前必须通过 `parseAIRuntimeRole()` 校验；不能让任意字符串进入 Provider body。

### 4.4 P0：真实 Chat Feature 完整化

HarmonyOS 已经形成以下**最小可运行链路**，但不是 iOS 等价的完整实现：

```text
MainTabsPage → ChatTabPage
  → SendChatMessageUseCase
  → 组装本地 ChatMessage
  → 写 user pending + assistant sending 占位
  → ChatOrchestrator.generateReply
  → MessageRunActor / RDB block upsert
  → completed / failed / cancelled
  → ChatSyncEngine / REST push-pull / WebSocket hint / 附件下载任务
```

已核验文件：`ChatModels.ets`、`ChatSchema.ets`、`ChatRepository.ets`、`SendChatMessageUseCase.ets`、`MessageRunActor.ets`、`ChatTabPage.ets`、`MainTabsPage.ets`、`AppDatabaseSchema.ets`。当前链路的具体缺口：

- `ChatTabPage` 是最小单线程页面，不等价于 iOS `ChatDetailViewModel`、线程列表、附件/图片输入、富消息 block 展示和工具交互 UI。
- `SendChatMessageUseCase` 只把历史转换为 role/text；没有恢复 `ChatMessageBlock`、`contentParts`、tool calls、tool result、reasoningContent 和结构化医疗卡片。
- 页面传入的 `memberContextSummary` 当前为空字符串；线程成员、系统提示、场景配置和上下文注入尚未达到 iOS 语义。
- 本地写入已通过 `AppRelationalDatabase.queue` 串行化，但 thread/message/blocks 尚未形成跨实体事务；`INSERT OR REPLACE` 的覆盖语义、外键一致性和崩溃恢复需要补测试。
- 当前已具备 Outbox、远端线程/消息同步、cursor、幂等键、服务端 DTO 映射、WebSocket hint、软删除/重试和附件下载任务；仍需真机网络、OSS 与完整 Chat UI 验收，不能把“编译通过”当成端到端验收。

实施要求：

1. 在现有 `Projects/Features/Chat/Domain` 基础上补齐 `ChatThread`、`ChatMessage`、`ChatMessageBlock` 的 iOS 字段映射、content parts、tool trace、rich block 和同步元数据。
2. 在现有 `ChatRepository`/`ChatSchema` 基础上补齐 RDB 迁移版本、外键/孤儿清理、thread-message-block 事务、分页、排序稳定性和服务端 DTO mapper；不得把消息数组仅放在页面 `@State`。
3. 扩展现有 `SendChatMessageUseCase`：读取线程配置、成员上下文、系统提示和历史 blocks，构造完整 Runtime history，保留本轮用户消息的多模态内容。
4. 扩展 `MessageRunActor`：同一 assistant message 的 text/reasoning/tool/rich block 更新必须有稳定 ID、revision、终态幂等和恢复策略。
5. 将 `ChatOrchestrator` 的 `onPartial` 映射到 RDB/UI 增量，且处理 tool delta、reasoning 回灌、空输出、重试和取消，而不是只在页面临时字符串中展示。
6. 账号切换/登出必须停止 Runtime、清理 Chat 状态、取消旧 generation 回调并隔离历史数据；现有清理调用需要补“失败不吞、重入、恢复”测试。

### 4.5 P0：ToolHub 从桩到真实边界

当前 ToolHub 的事实：

- `Core/AI/Runtime/ToolHub.ets` 是兼容旧 import 的 re-export 门面，实际实现已拆到 `Runtime/ToolHub/ToolHub.ets`、`ToolRegistry.ets` 和 `ToolHubModels.ets`。
- `ToolRegistry.listDefinitions()` 当前可返回 `debug_echo`，并按 `allowedToolNames` 过滤；不是固定空数组。
- `runIfNeeded()` 只有 `/audit_tools` 这条联调命令会直接返回 `audit_tools` 结果，普通输入返回 `none`。
- `execute()` 只真正执行 `debug_echo`，未注册工具返回“未注册或尚未启用”；尚无真实业务授权、审计、成员选择、医疗数据副作用和工具结果同步。

这意味着当前工具循环即便能收到模型 tool call，也不会产生 iOS 等价业务结果。纠偏必须拆出：

```text
ToolRegistry
  → ToolDefinitionProvider
  → ToolCapabilityFilter
  → Consent/Authorization
  → ToolExecutor
  → ToolAuditStore
  → ToolSideEffectSink
  → ChatMessageBlock / Domain result
```

要求：

- 工具定义必须从真实注册表生成，按 `allowedToolNames`、scenario、模型能力和用户授权过滤。
- 工具参数必须先 JSON parse/Schema validate，再进入执行器。
- 工具执行失败、等待用户输入、权限拒绝和敏感数据拒绝必须有结构化结果。
- 不允许把原始 arguments 写入普通日志或用户错误文案。
- `isAwaitingUserInput` 后必须锁定 tools，追加系统约束，禁止同一轮继续自动调用。
- 工具副作用必须通过统一 sink 写入 Chat 消息块/业务模块，不能由 Orchestrator 直接写医疗、知识或文件数据。

### 4.6 P1：远端 Provider 与 SSE 纠偏

当前 `OpenAICompatibleProviderAdapter.ets` 已实现：

- `http.createHttp()`、`request()`、`requestInStream()`。
- `dataReceive` 累加 buffer，按换行拆 SSE。
- `data: [DONE]` 处理。
- `choices[0].delta.content` → `textDelta`。
- `reasoning_content/reasoning` → `reasoningDelta`。
- `delta.tool_calls` 按 index 聚合。
- `data` 包裹响应和非包裹响应的部分兼容。
- `destroy()` 和 `finally` 清理 listener/request。

当前 Adapter 已有 `requestInStream`、`dataReceive`、SSE parser、错误体解析、`[DONE]`、tool-call 聚合和 `destroy`；仍需逐项与 iOS `OpenAICompatibleTextGateway.swift` 对齐并完成真实设备验收：

1. body 的 `model` 必须使用 Resolver 最终模型；Agent 必须验证是否已替换为 `baseModelName`。
2. `stream=true`、tools、tool_choice、temperature、top_p、max_tokens 和 reasoning 厂商字段必须按能力和请求存在性编码，不能发送空/错误字段。
3. 多模态 `image_url` 需要把 inline JPEG 约定转换为厂商可接受格式；不得把内联 base64 原文直接写入不支持的 URL 字段。
4. SSE parser 必须处理 CRLF、跨 chunk 半行、空行、注释行、多个 data 行、JSON 解析失败和最后无换行 buffer。
5. provider 错误 body 需解析 HTTP status、服务端 `code/msg/requestId`，不能只生成 `status=xxx`。
6. 非 2xx、服务端业务失败、空 choices、非法 tool call JSON、无 completed 和 provider close 都要映射为结构化错误/终态。
7. `[DONE]` 不能单独制造成功；只有完成事件和合法 response 才能完成。
8. `dataReceive` 回调中的异常必须能结束 Promise，不能只设置 aborted 后悬挂。
9. `requestInStream`、`dataReceive`、`dataEnd`、`destroy` 的生命周期要用真机日志和测试确认，不得只靠类型通过。

### 4.7 P1：本地模型语义

`LocalModelAdapter.ets` 当前明确返回 `localEngineUnavailable`，这是正确的“不可用失败语义”，但不能标记为本地推理已对齐。

后续真实 GGUF 工单必须另行定义：

- 模型文件状态、sha256、路径、空间和下载取消。
- 加载/卸载、内存峰值、前后台暂停、设备能力限制。
- 本地模型 message/contentParts 能力边界。
- 本地 stream、reasoning、tool use 是否支持。
- 取消是否能中断 native/worker 推理。
- 账号切换时本地模型是否共享但配置隔离。

在该工单完成前：选择本地模型必须得到明确错误和 UI 可见降级，禁止 echo、伪造文本或把“占位结果”写入聊天历史。

### 4.8 P1：取消、并发、账号和生命周期

当前已有 token 与 Adapter `destroy`，但必须补成以下闭环：

```text
用户点击停止 / 页面离开 / 账号切换 / 登出
  → cancel token
  → AIRuntimeService.cancel(requestId)
  → Adapter.destroy()
  → SSE Promise settle
  → emit cancelled 一次
  → Orchestrator 不再进入下一轮
  → MessageRunActor 停止 partial，写中断状态
  → request generation 失效，旧回调丢弃
```

要求：

- 一个 requestId 只能有一个终态：completed、failed 或 cancelled。
- 取消后到达的 dataReceive 必须被丢弃。
- `cancelAll()` 必须只取消当前账号/当前 Runtime 代际，不误伤新账号请求。
- 同一 requestId 不能被第二次调用覆盖 active request map。
- Orchestrator 每轮、每个 tool call 前后都检查 token。
- `onPartial` 需要检查 accountId/threadId/generation，防止旧账号内容写入新页面。
- 前后台恢复要决定继续、取消或重新发起请求，不能自动重复执行工具副作用。

### 4.9 P1：Reasoning 与 Agent 模型

对齐规则：

| 模型能力 | 用户设置 | Runtime 行为 |
|---|---|---|
| 支持且可控 | 开/关 | 使用用户开关和 effortTier |
| 支持但不可控 | 任意 | 强制原生开启，避免发送不支持的开关字段 |
| 不支持 | 用户开启 | `usePromptFallback=true`，仅在产品允许时使用提示降级 |

必须验证：

- `AIRuntimeReasoningOptions` 的 effort 0–3 与 iOS 完全一致。
- `OpenAIReasoningPayload.ets` 的 provider 字段、值域和冲突字段与 iOS `OpenAIReasoningPayload.swift` 对齐。
- DeepSeek assistant tool-call 轮次回灌 `reasoning_content`。
- reasoning delta 与最终 reasoningText 不重复拼接。
- 日志只记录长度/耗时/能力，不记录完整思考内容。
- Agent 目录/配置使用 agent 名，实际 HTTP `model` 使用 `baseModelName`；增加 payload 断言。

### 4.10 P2：非 chat 场景接入矩阵

以 iOS `AI Runtime 推理编排需求.md` 的真实调用表为基线，HarmonyOS 必须逐项定位调用方：

| iOS 场景 | iOS 调用方 | HarmonyOS 当前 | 目标 |
|---|---|---|---|
| 医疗文档类型识别 | `DefaultMedicalDocumentTypeResolver` | `StructuredRuntimeClient.recognizeMedicalDocumentType` 样例 | 直连 Runtime；正式 Feature 仍需接入 |
| 医疗结构化抽取 | `DefaultMedicalDocumentRecognizer` | 未接正式 Feature | SSE/非流式 JSON decoder 对齐 |
| 体检/病例/处方/用药抽取 | `DefaultTypedMedicalDocumentExtractor` | 未接正式 Feature | 每个 scenario 有请求/输出测试 |
| 营养结构化识别 | `NutritionIntakeStructuredExtractor` | 未接正式 Feature | 不经过 ChatOrchestrator |
| 图片描述 | `NutritionFoodImageDescriber` | 未接正式 Feature | 多模态 parts 和能力门禁 |
| 知识库润色/翻译 | Knowledge use cases | 未接正式 Feature | 复用 Runtime，不复制 Provider HTTP |
| ToolHub 内部二次抽取 | `ToolHub+Shared.swift` | ToolHub 桩 | 工具执行与 Runtime 分层 |

非 chat 场景不得强行绑定 ChatThread、ChatOrchestrator 30 轮工具循环或聊天 UI 状态；应由调用方自行消费结构化结果并管理业务回写。

### 4.11 日志、错误和可观测性

HarmonyOS 当前 `AIRuntimeService.ets:214` 使用 `${err}` 记录失败详情，需收敛到 iOS `AIRuntimeRequestLogRedactor` 语义：

- 记录 scenario、source、model、provider、requestId、阶段、耗时、消息数量、tool 数量和错误类别。
- 不记录 API Key、Authorization、完整请求 body、用户输入、模型输出、reasoning、医疗数据或完整 tool arguments。
- 错误至少区分：配置缺失、能力不支持、HTTP、服务端业务码、解码、空输出、取消、本地引擎不可用、会话失效。
- 同一请求只能记录一次 begin 和一次终态；流式事件只记录计数/长度。
- 需要 requestId 与后端 request ID 的关联字段，但不能把 request ID 当作用户可见错误正文。

## 5. 接口契约与数据模型

### 5.1 Runtime 配置模型对照

| 模型 | iOS | HarmonyOS 当前 | 纠偏 |
|---|---|---|---|
| Provider | provider/company/requestUrl/apiKey 来源 | `LocalProvider` + `RuntimeProviderRef` + `secretRef` | 保持 key 只在 HUKS/密文文件，Runtime 只取内存短暂值 |
| Model | name/display/baseModel/capabilities/source | `LocalModel` / `AIResolvedConfig` | `baseModelName` 必须贯穿 Resolver → Adapter body |
| Scenario binding | scenario/default/model/temp/maxTokens | `LocalScenarioBinding` | 默认、偏好、Pro overlay 和 runtime override 顺序要有测试 |
| Snapshot | 有效 bundle + runtime override | `AIConfigSnapshot` + `RuntimeSnapshot` | 发布使用不可变替换和 generation |
| Reasoning | 对象 | 已有对象 | 增加 provider 兼容/回传测试 |
| Tools | 结构化 property | `parametersJson` | 至少提供 JSON Schema parse/validate mapper |

### 5.2 请求与响应事件

目标事件协议：

```text
started(requestId)
textDelta(requestId, deltaText)
reasoningDelta(requestId, reasoningDelta)
toolCall(requestId, index, id, name, argumentsDelta)
completed(requestId, response)
failed(requestId, errorCode, errorMessage, response?)
cancelled(requestId, response?)
```

必须补充的响应字段：

```text
requestId
modelId / modelName / source
text
reasoningText
toolCalls
finishReason
usage.promptTokens / completionTokens / totalTokens
errorCode / errorMessage
isDegraded
```

事件与最终响应的规则：

- `completed` 只出现一次；无正文但有合法 tool calls 时仍是可供 Orchestrator 处理的完成结果。
- `failed/cancelled` 不再追加 completed。
- Provider 解析到错误包裹时不应把错误 JSON 当正文 delta。
- 所有事件携带 requestId；Chat 层另带 threadId/assistantMessageClientId 做持久化关联。

### 5.3 Provider 请求体目标

```json
{
  "model": "最终实际模型名或 agent baseModelName",
  "messages": [
    {"role":"system","content":"..."},
    {"role":"user","content":"..."},
    {"role":"assistant","tool_calls":[]},
    {"role":"tool","tool_call_id":"...","name":"...","content":"..."}
  ],
  "stream": true,
  "temperature": 0.7,
  "top_p": 1.0,
  "max_tokens": 4096,
  "tools": [],
  "tool_choice": "auto"
}
```

字段规则：

- 可选字段不存在时不编码空值，除非厂商契约要求显式 null。
- `tools` 只有模型支持且本轮有工具定义时出站；降级必须同时 `tools=[]` 和 `tool_choice=none`。
- 多模态 `content` 必须是 parts 数组；纯文本才是 string。
- assistant tool-call 轮次必须带 tool calls 和必要的 reasoning 回传；tool 结果必须带 `tool_call_id`。
- 所有 request body 先由可测试 encoder 生成，再交给 HTTP Adapter；业务层不得自行 JSON.stringify 一套不同结构。

### 5.4 账号、配置和密钥生命周期

HarmonyOS 已有 `AIKeyStore`：RDB 只保存 `secretRef`，密钥通过 HUKS 加密文件保存；该边界必须保留。

账号切换流程目标：

```text
旧账号请求停止
  → AIRuntimeService.cancelAll()
  → 旧 Runtime generation 失效
  → SnapshotStore.invalidate/clear(oldAccount)
  → Chat/Feature 页面状态清理
  → 激活新账号
  → RDB 加载/Pro overlay 合并
  → publish RuntimeSnapshot
  → 允许新请求
```

禁止：

- 用 `accountId=0` 作为可发送的访客 Runtime 账号。
- 旧账号异步 callback 在新账号页面消费。
- 在 Preferences、日志或 request body 中保存/输出 API Key。
- 页面直接从 RDB 读取 provider secret。

## 6. iOS-HarmonyOS 功能对照矩阵

| 能力 | iOS 当前事实 | HarmonyOS 当前事实 | 对齐状态 | 工单任务 |
|---|---|---|---|---|
| 配置快照 | `AIConfigCenter` + Resolver + RuntimeStore | Repository + Resolver + SnapshotStore | 部分对齐 | 补 generation、默认顺序和异常 |
| Runtime 统一入口 | `generateTextStream` | 已有 `generateTextStream` | 代码部分对齐/文档过时 | 修正文档并补真实调用 |
| 精确 preferred | 精确 model/agent 解析 | Runtime 精确，Resolver 仍需复核 | 待验收 | 完成 Resolver/Agent 测试 |
| Tools 降级 | 清空 tools + none + 日志 | 已有 Service 层降级 | 部分对齐 | 验证 Provider body 不出 tools |
| Tools 出站 | 结构化 definitions | `ToolRegistry` 当前仅出站 `debug_echo`，真实业务定义未接 | 联调级/未对齐业务 | ToolHub 注册/授权/执行 |
| SSE | URLSession bytes/SSE | requestInStream/dataReceive | 部分对齐 | 真机、半行、错误、终态测试 |
| Reasoning | provider builder + DeepSeek 回灌 | builder/model 字段已有 | 部分对齐 | 厂商矩阵与多轮回灌 |
| Agent base model | HTTP 使用 base model | Resolver 有替换逻辑 | 待验收 | body 断言和 Pro overlay 测试 |
| 取消 | token + stream termination | token + destroy + soft set | 部分对齐 | generation、终态一次性、账号测试 |
| 本地 GGUF | 路由已接但 iOS 占位 | 明确不可用错误 | 语义对齐 | 保持失败，不伪造成功 |
| ChatOrchestrator | 已完整使用 | 已装配并被最小 Chat UseCase 调用 | 部分对齐 | 补完整上下文、附件、tool/rich block、同步 |
| Chat 消息模型 | ChatMessage/Block/Core Data | `ChatThread/Message/Block` + 三表 RDB + Repository | 最小本地对齐/服务端未对齐 | 补字段、迁移、Mapper、Outbox/同步 |
| MessageRunActor | 串行 partial/block 副作用 | partial/reasoning、revision、generation 已有 | 部分对齐 | 补 tool/rich block、终态、重试、恢复 |
| 非 chat 调用 | 医疗/营养/知识等多方调用 | `StructuredRuntimeClient` 样例；正式消费表未齐 | 部分对齐 | 场景逐项接入 |
| 测试 | AI resolver + Chat/Runtime 测试 | Resolver、Service、SSE Parser 基础测试；缺 Chat 集成测试 | 部分对齐 | 增加 Chat、ToolHub、RDB、真机和集成测试 |

## 7. 示例工程与官方文档参考结论

### 7.1 本地 HarmonyOS 示例

可参考但不可直接复制：

| 示例 | 可借鉴 | 禁止复制 |
|---|---|---|
| `SparkClientHarmonyOS/开发详细技术文档/agc-template-market-harmonyos-demos-main/MovieTVAndLivestreamingTemplate/LiveStreaming` | HTTP 拦截器、事件监听、请求生命周期分层 | Mock Adapter、完整 body/header 日志、Preferences 明文 Token |
| `.../NewsTemplate/News/commons/network` | 独立网络模块/HAR 边界 | 将示例 API 当 SparkService 契约 |
| `.../ToolsTemplate/AIOffice` | AI/工具页面交互参考 | Mock AI 结果、演示 prompt、示例数据 |

### 7.2 官方能力参考

- [HarmonyOS 开发文档中心](https://developer.huawei.com/consumer/cn/doc/)：按目标 API Level 复核 API 签名。
- [发送网络请求（ArkTS）](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/http-request)：验证 HTTP session、请求、超时、监听、取消和销毁语义。
- [Universal Keystore Kit ArkTS API](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/universal-keystore-arkts)：验证 API Key 的密钥保护边界。

官方文档只能支撑 HarmonyOS 平台 API 能力，不能替代 iOS 业务流程、SparkService 字段或 ToolHub 业务契约。

## 8. 实施拆分与验收

### 8.1 工单分期

| 阶段 | 任务 | 产物 | 完成门槛 |
|---|---|---|---|
| P0-A | 纠正文档事实、更新目录映射和状态表 | HarmonyOS 技术方案修订 | 文档不再写“无 Orchestrator/非流式” |
| P0-B | Runtime Domain/Mapper/错误模型收敛 | `AIRuntimeModels`、mapper、error | 请求/响应/事件字段可单测 |
| P0-C | SSE/Provider 端到端稳定 | Adapter + fake server/fixture | 真流文本、reasoning、tool、错误、取消可验收 |
| P0-D | Chat Domain/RDB/Repository/UseCase | Chat Feature 基础骨架 | 能从真实 Chat 页面发送并读本地消息 |
| P0-E | MessageRunActor/partial 落库 | 消息块稳定 ID/revision | 停止/失败/重试不重复写入 |
| P1-A | ToolHub 注册/授权/审计/执行 | ToolHub 专题实现 | 至少一个真实工具完成完整回路 |
| P1-B | 多轮工具和健康副作用 | Orchestrator + sink | 工具结果、等待用户、tool lock 对齐 |
| P1-C | 非 chat Feature 接入 | 调用方矩阵和实现 | 医疗/营养至少一条真实路径完成 |
| P1-D | 账号/前后台/路由恢复 | lifecycle + generation | 账号切换无旧回调污染 |
| P2-A | 本地 GGUF | 独立工单 | 引擎可用前保持明确失败 |
| P2-B | 性能/观测/跨端兼容 | 指标、日志、fixture | 长流、超时、大 payload 可诊断 |

### 8.2 最低自动化测试

- Resolver：preferred 精确命中、未知模型失败、默认优先级、Agent base model、Pro overlay、账号隔离。
- Request encoder：纯文本、多模态、tool assistant、tool result、reasoning、可选字段缺省。
- SSE：跨 chunk 半行、CRLF、`[DONE]`、data 包裹、reasoning、多个 tool index、空 choices、错误 JSON。
- Provider：2xx/4xx/5xx、业务失败、空响应、超时、destroy、监听清理、重复终态。
- Runtime：无消息、无模型、能力拒绝、tools 降级、取消、cancelAll、session invalidated。
- Orchestrator：纯文本、空输出、tool loop、多工具、30 轮上限、等待用户输入锁定、reasoning 回灌。
- Chat：消息创建、assistant 占位、partial 更新、失败状态、取消、重试、block revision、账号切换。
- 集成：真实 Chat 入口 → Runtime → Provider fake server → RDB/UI 状态，不能只测 Playground。

### 8.3 逐条验收标准

- [ ] 现有 HarmonyOS 详细技术方案的实现状态与当前代码一致。
- [ ] 生产入口通过 `AppContainer` 获取 Runtime/Orchestrator，不由页面自行 new。
- [x] 最小真实 Chat Feature 已通过 `MainTabsPage` → `ChatTabPage` → `SendChatMessageUseCase` 接入统一链路；仍需补完整 Chat 能力验收。
- [ ] Chat Feature 达到 iOS 等价：线程管理、附件/多模态、rich blocks、tool 交互、远端同步和恢复均有证据。
- [ ] 文本、reasoning、tool call 和 completed 事件与 iOS 可观察语义一致。
- [ ] 不支持 tools 的模型请求体中没有 tools，且明确 `tool_choice=none`。
- [ ] Agent 对外 HTTP model 使用 base model，日志仍保留 agent identity。
- [ ] 取消后 HTTP 结束、Promise settle、终态事件和消息状态均一致，且不再产生 partial。
- [ ] ToolHub 未完成前，任何“工具已对齐”结论均不得通过验收。
- [x] Chat 消息和 blocks 已有最小持久化模型、账号字段、Schema 注册和 Repository；仍需迁移版本、事务、完整字段和测试。
- [ ] Chat 消息与服务端线程/消息契约完成 DTO、cursor、幂等和冲突同步验收。
- [ ] 非 chat 场景不经过 ChatOrchestrator，且有独立结构化输出/错误处理。
- [ ] API Key 不出现在 RDB 明文、Preferences、日志和 UI 错误中。
- [ ] 真机验证 SSE、网络断开、前后台、账号切换、登出和重新登录。

## 9. 风险与待确认项

### 9.1 当前无法从目标工作区确认的事项

- SparkService AI 配置、Pro overlay、模型能力和错误码的服务端真实 Serializer/Service 实现。
- HarmonyOS 是否已有未被 `rg` 搜索路径覆盖的 Chat 分支或外部 HAR。
- HarmonyOS 当前 `requestInStream` 在目标 API Level/设备上的完整事件与 destroy 行为。
- 工具权限、审计、副作用和医疗数据访问的后端契约。
- HarmonyOS Chat 消息 RDB 目标表、迁移版本和与服务端同步 API。

这些事项必须以真实后端源码、目标端完整工程或真机实验确认，不能从 iOS 文档直接推断“已实现”。

### 9.2 高风险项

| 风险 | 后果 | 防护 |
|---|---|---|
| 把骨架当成完成 | Chat/工具上线后运行链路断裂 | 以真实入口和集成测试为验收门槛 |
| SSE 只测整包 | 长流、工具和 reasoning 丢失 | chunk fixture + 真机流式测试 |
| 取消只改 Set | 请求仍占网络/配额，继续写数据 | token + destroy + generation + 终态幂等 |
| ToolHub 空桩进入生产 | 用户看到“工具未启用”或产生错误医疗结论 | 工具能力未完成时明确禁用真实入口 |
| 本地 RDB 被误认为已同步 | 页面看似可用，但多端/重装/后台管理不可见 | Outbox + API DTO + cursor + 幂等/冲突验收 |
| 账号 generation 缺失 | A 账号结果写入 B 账号 | 账号/请求/线程 generation 门禁 |
| 直接复制 Demo | Mock、日志和不安全存储进入生产 | 只借分层，逐项安全审计 |
| 文档状态漂移 | 后续开发按旧事实走偏 | 每次代码变更同步更新状态表和证据 |

### 9.3 交付顺序约束

不得先做 UI 视觉或真实工具数量扩展，再补 Runtime 基础一致性。推荐顺序：

```text
文档事实纠偏
  → Runtime Domain/Mapper/Error
  → SSE/取消/Provider
  → Chat 消息持久化与真实入口
  → Orchestrator 端到端
  → ToolHub 一个真实工具闭环
  → 非 chat 场景
  → 更多工具、GGUF 和性能优化
```

### 9.4 关闭工单所需证据

关闭本工单前必须附：

1. 修订后的 HarmonyOS 技术方案和文件级目录映射。
2. `assembleHap` 通过记录；文档纠偏不以“能编译”替代业务验收。
3. Runtime 单元测试、SSE fixture 测试、取消测试和 Orchestrator 测试结果。
4. 真机日志：开始、首个 delta、reasoning/tool delta、completed/failed/cancelled、destroy 和清理。
5. 真实 Chat 入口的端到端录像或测试记录，证明不依赖 Playground。
6. 账号切换/登出、无模型、无网、服务端错误、工具等待用户和重试场景记录。
7. 若服务端契约未确认，保留待确认项，不得以客户端假设关闭接口偏差。
