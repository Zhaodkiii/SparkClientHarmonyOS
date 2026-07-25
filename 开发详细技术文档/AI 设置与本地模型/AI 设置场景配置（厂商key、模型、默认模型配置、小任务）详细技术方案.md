# SparkClientHarmonyOS｜AI 设置场景配置（厂商key、模型、默认模型配置、小任务）详细技术方案

> 本文以 iOS 参考文档 [AI 设置场景配置（厂商key、模型、默认模型配置、小任务）](../../../SparkClient/总领文档/AI 设置与本地模型/AI 设置场景配置（厂商key、模型、默认模型配置、小任务）.md) 和 HarmonyOS 当前工程为基线，描述厂商 Key、模型目录、默认模型、场景绑定、小任务、智能体和相关 UI 的跨端对齐方案。代码事实、后端事实和目标设计分开记录。

## 1. 对标范围与结论

### 1.1 事实范围

| 端/层 | 事实来源 | 当前结论 |
| --- | --- | --- |
| iOS 参考端 | `SparkClient/Projects/Features/AISettings/`、`Projects/Core/AI/`、Core Data 模型和 AI 测试 | 已具备账号级 Provider、模型、场景绑定、小任务、Pro overlay、默认解析和设置 UI。 |
| HarmonyOS 目标端 | `entry/src/main/ets/Core/AI/`、`Core/Storage/`、`Projects/Features/AISettings/`、`App/AppContainer.ets` | 已具备 AI 领域模型、RDB 表/读写、rawfile seed、HUKS 密钥封装、Repository、Resolver、Runtime、AI 设置首页和账号启动接入；完整 Provider/模型/Agent/小任务页面与生产安全收口仍在完善。 |
| SparkService 后端 | `SparkService/ai_config/urls.py`、`views.py`、`models.py`、`services.py`、`tests.py`、`backoffice-web/src/api/modules/ai.ts` | 后端是 AI 配置、Pro 试用、模型目录和后台管理的唯一契约来源。 |
| 视觉参考 | iOS AI 设置 UI 文档及新增截图 | HarmonyOS 目标为深色/浅色均可用的卡片化设置页，交互语义与 iOS 对齐，不复制 SwiftUI API。 |

### 1.2 结论

1. HarmonyOS 当前为“本地配置主链路已落地、页面和生产边界部分实现”。`AppBootstrapper` 已执行 seed、读取本地快照、构建 Runtime 和远端 refresh；当前 AI 设置页仍是聚合验证页，不等于 iOS 截图中的完整多页面 UI 已完成。
2. 厂商 API Key 属于敏感凭证，HarmonyOS 只能保存 HUKS 引用或由安全密钥服务封装的密文；不得保存明文到 Preferences、RDB、普通文件、日志或错误文案。
3. `SparkService` 当前 bootstrap 返回 Pro 场景和服务端小任务；非 Pro 返回空场景并带试用状态。用户本地 Provider、模型、绑定、小任务需要 HarmonyOS 本地 Repository 独立维护，再由 Resolver 合并。
4. 设置页面必须在账号准备完成后加载；账号切换、退出和鉴权失效时清理旧账号的运行时快照、选择状态和敏感引用。
5. 当前后端测试与当前 `views.py` 存在契约漂移：测试仍断言旧版 `api_keys`、`all_models` 等 bootstrap 字段，而当前视图注释和实现只返回 `scenarios`、`smallTasks`、`trial_status`/`trial_message` 等字段。HarmonyOS 不得凭旧测试补造字段，需先由后端统一契约。

## 2. 华为端目录设计

### 2.1 参考端到目标端映射

| 参考端目录/文件 | 参考端职责 | HarmonyOS 当前目录/文件 | HarmonyOS 目标目录/文件 | 状态 | 说明 |
| --- | --- | --- | --- | --- | --- |
| `Features/AISettings/Presentation/Root/AISettingsView.swift` | AI 设置首页 | `Projects/Features/AISettings/Presentation/AISettingsPage.ets`、`AISettingsViewModel.ets` | 同当前路径增量完善 | 部分实现 | 当前页面已接入加载、刷新、保存、放弃、Provider Key、连通性、绑定默认、小任务展示；仍需拆分为截图对应的导航页面。 |
| `Features/AISettings/Presentation/Providers/*` | Provider 列表、编辑、连通性测试、试用卡片 | `AISettingsPage.ets` 已有聚合入口，完整 Providers 子页面未完成 | `Projects/Features/AISettings/Presentation/Providers/*` | 部分实现 | Key 编辑使用 `secretRef`；需补齐新增、自定义 Provider、隐私政策、模型管理页面。 |
| `Features/AISettings/Presentation/Models/*` | 模型目录、在线模型、本地模型、Agent 编辑 | 领域模型与 Runtime 已存在，完整 Models UI 未完成 | `Projects/Features/AISettings/Presentation/Models/*` | 部分实现 | 统一模型/Agent 列表，按 `identity` 筛选；本地文件服务目前仅有元数据和校验约定。 |
| `Features/AISettings/Presentation/Preferences/*` | 默认模型和场景来源选择 | `AISettingsViewModel.setScenarioDefault()` 已有基础行为 | `Projects/Features/AISettings/Presentation/Preferences/*` | 部分实现 | 需补齐 local/Pro 来源选择、场景详情和空态。 |
| `Features/AISettings/Presentation/Root/SmallTask*` | 小任务列表和编辑 | `AISettingsPage.ets` 仅展示小任务 | `Projects/Features/AISettings/Presentation/SmallTasks/*` | 部分实现 | Repository 模型已有，CRUD、Prompt、工具多选、引用清理待补齐。 |
| `Domain/AISettingsSnapshot.swift` | 聚合快照、偏好、试用状态 | `Core/AI/Domain/AIConfigModels.ets` | `Projects/Features/AISettings/Domain/*` 或继续统一到 `Core/AI/Domain` | 已部分实现 | 当前 `AIConfigSnapshot` 已承载 Provider/Model/Binding/Task/File/Preferences；不要重复创建第二份快照模型。 |
| `Infrastructure/DefaultAISettingsRepository.swift` | Core Data/UserDefaults 持久化 | `Core/AI/Application/AIConfigRepository.ets`、`Core/AI/Infrastructure/AIConfigRdbStore.ets` | 同现有 `Core/AI` 边界增量维护 | 已部分实现 | 目录数据进入 RDB，Key 进入 HUKS；`AISettingsKVAdapter` 当前只是占位镜像。 |
| `Core/Networking/API/AI/AIConfigAPI.swift` | bootstrap、试用、Provider 测试 | `Projects/Core/Networking/API/AI/AIConfigAPI.ets` | 同当前路径增量维护 | 部分对齐 | 已有四个请求入口，字段解码需要按后端最终契约收敛。 |
| `Core/AI/AIConfigCenter.swift` | 预热、刷新、Runtime cache | `Core/AI/Application/AIConfigRepository.ets`、`Core/AI/Runtime/AIRuntimeSnapshotStore.ets`、`AIRuntimeService.ets` | 同现有 `Core/AI` 边界增量维护 | 已部分实现 | 已有 Repository/Resolver/Runtime；后续不要创建平行 `Projects/Core/AI` 实现。 |

### 2.2 目标目录树

```text
entry/src/main/ets/
├── App/
│   ├── AppBootstrapper.ets                         # 当前：账号级 AI bootstrap 入口
│   ├── AppContainer.ets                            # 当前：SupportBackend/Bootstrapper 组合根
│   ├── AppSessionStore.ets                         # 当前：账号会话状态
│   └── RouteCoordinator.ets                        # 当前：根路由与失效回登录
├── Core/
│   ├── AI/
│   │   ├── Domain/
│   │   │   ├── AIConfigModels.ets                  # 目标：Runtime DTO 与领域模型
│   │   │   ├── AIScenario.ets                      # 目标：与后端 scenario key 对齐
│   │   │   └── AIConfigErrors.ets                  # 目标：字段/合并/运行时错误
│   │   ├── Application/
│   │   │   ├── AIConfigCenter.ets                  # 目标：预热、刷新、generation
│   │   │   ├── AIConfigResolver.ets                # 目标：Local + Pro 合并
│   │   │   └── AIRuntimeConfigStore.ets            # 目标：内存 runtime snapshot
│   │   ├── Infrastructure/
│   │   │   ├── AIConfigDatabase.ets                # 目标：RDB 初始化/迁移/关闭
│   │   │   ├── AIConfigRdbStore.ets                # 目标：账号级事务 CRUD
│   │   │   ├── AIConfigSchema.ets                  # 目标：表、索引、schema version
│   │   │   ├── AIConfigMappers.ets                 # 目标：RDB row <-> domain
│   │   │   ├── AIConfigRepository.ets              # 目标：快照读取/保存/远端刷新
│   │   │   ├── AIKeyStore.ets                      # 目标：HUKS alias/secretRef
│   │   │   ├── LocalModelFileStore.ets             # 目标：模型文件 metadata/路径
│   │   │   └── AIConfigSeedLoader.ets              # 目标：rawfile 种子初始化
│   │   └── Runtime/
│   │       ├── AIRuntimeService.ets               # 目标：统一 Provider/Local 路由
│   │       ├── AIProviderAdapter.ets               # 目标：云端 Provider 适配
│   │       └── LocalModelAdapter.ets               # 目标：本地模型适配，占位前不得宣称可推理
│   └── Networking/
│       └── SupportBackend.ets                      # 当前：统一 HTTP/API 组合根
├── Foundation/
│   ├── Security/
│   │   ├── SecureTokenStore.ets                   # 当前：会话凭证，不与 API Key 混用
│   │   └── HuksAesGcmCipher.ets                   # 当前：安全存储基础能力
│   ├── Logging/
│   │   ├── Logger.ets                             # 当前：hilog 门面
│   │   └── ErrorLogger.ets                        # 当前：错误分类/脱敏
│   └── L10n/L10n.ets                              # 当前：资源文案访问
├── Projects/Core/Networking/API/AI/
│   └── AIConfigAPI.ets                             # 当前：bootstrap/trial/test API
└── Projects/Features/AISettings/
    ├── Domain/
    │   ├── AISettingsSnapshot.ets                 # 目标：账号级编辑快照
    │   ├── AISettingsDomainModels.ets              # 目标：Provider/Model/Task/Binding
    │   ├── AISettingsRepository.ets                # 目标：Repository 接口
    │   └── AISettingsPresentationModels.ets        # 目标：UI 脱敏展示模型
    ├── Application/
    │   ├── LoadAISettingsUseCase.ets               # 目标：加载本地+远端快照
    │   ├── SaveAISettingsUseCase.ets               # 目标：事务保存并重建 runtime
    │   ├── ProviderUseCases.ets                    # 目标：Provider CRUD/测试
    │   ├── ModelCatalogUseCases.ets                # 目标：模型/Agent CRUD
    │   └── SmallTaskUseCases.ets                   # 目标：小任务 CRUD/引用清理
    ├── Infrastructure/
    │   └── DefaultAISettingsRepository.ets         # 目标：组合 RDB/HUKS/API
    └── Presentation/
        ├── AISettingsPage.ets                     # 目标：AI 设置首页
        ├── AISettingsViewModel.ets                 # 目标：页面状态与命令
        ├── components/
        │   ├── AISettingsCard.ets                  # 目标：深色/浅色分组卡片
        │   ├── AISettingsRow.ets                   # 目标：图标/标题/副标题/chevron
        │   ├── AIModelRow.ets                      # 目标：模型能力 badge/Toggle/info
        │   ├── PromptEditor.ets                    # 目标：Prompt 输入、工具、语音
        │   ├── EmptyState.ets                      # 目标：空态/错误态/加载态
        │   └── ConfirmDialog.ets                   # 目标：删除/危险操作确认
        ├── Providers/
        │   ├── ProvidersPage.ets                   # 目标：模型密钥列表
        │   ├── ProviderEditorPage.ets              # 目标：编辑 Provider
        │   ├── AddCustomProviderPage.ets           # 目标：新增自定义 Provider
        │   ├── ProviderModelManagementPage.ets     # 目标：已添加/远端模型
        │   ├── AITrialCard.ets                     # 目标：Pro 试用卡片
        │   └── ProviderPrivacyPolicyPage.ets       # 目标：隐私政策 ArkWeb
        ├── Models/
        │   ├── ModelsPage.ets                      # 目标：全部/模型/智能体
        │   ├── ModelsAdvancedPage.ets              # 目标：高级目录编辑/排序
        │   ├── AddOnlineModelPage.ets              # 目标：添加在线模型
        │   ├── EditModelPage.ets                   # 目标：编辑普通模型
        │   ├── AgentEditorPage.ets                 # 目标：新建/编辑智能体
        │   ├── LocalModelDownloadPage.ets          # 目标：下载/导入本地模型
        │   ├── ModelCapabilityProbePage.ets        # 目标：能力探测结果
        │   └── ModelIconPickerPage.ets             # 目标：图标选择
        ├── Preferences/
        │   ├── DefaultModelPreferencesPage.ets     # 目标：默认模型配置
        │   ├── ScenarioModelCard.ets               # 目标：场景模型卡片
        │   ├── ScenarioBindingPage.ets             # 目标：模型使用场景
        │   ├── ToolSelectionPage.ets               # 目标：工具多选
        │   └── SmallTaskSelectionPage.ets          # 目标：关联小任务多选
        └── SmallTasks/
            ├── SmallTasksPage.ets                  # 目标：小任务列表
            ├── SmallTaskEditorPage.ets             # 目标：新建/编辑小任务
            ├── PromptInputDrawerPage.ets           # 目标：Prompt 文本工具抽屉
            └── VoiceInputPage.ets                  # 目标：语音输入
```

上述目录是本功能的业务目录结构。与本文件早期版本不同，当前 HarmonyOS 工程已经出现一部分可运行实现：`Core/AI/Domain/*`、`Core/AI/Application/*`、`Core/AI/Infrastructure/*`、`Core/AI/Runtime/*`、`Core/Storage/*`、`Projects/Features/AISettings/Presentation/AISettingsPage.ets` 和 `AISettingsViewModel.ets` 已存在；Provider/模型/小任务的完整页面仍需继续补齐。目录树中的“目标”表示仍需完善或经过验收，不再表示文件一定不存在。

## 3. 分层职责与请求链路

### 3.1 页面与配置链路

```text
设置页入口
  ↓
AISettingsViewModel/AISettingsPageState
  ↓ 只通过 UseCase
AISettingsUseCase
  ├── AISettingsRepository.load(accountId)
  ├── AIConfigAPI.trialStatus/bootstrap
  └── ProviderConnectionTestUseCase
  ↓
AIConfigResolver
  ├── 本地 RDB Provider/Model/Binding/Task
  ├── HUKS API Key 解析为内存 secret
  └── Pro bootstrap overlay
  ↓
AIRuntimeSnapshot
  ↓
AI 业务调用 / AIRuntimeService
```

页面不得直接创建 `NetworkRequest`、读取 HUKS 或执行 SQL。API 层只能负责请求契约和 DTO 解码；Repository 负责账号 scope 和持久化；Resolver 负责来源优先级和完整性校验；Runtime 只消费解析后的安全内存结构。

### 3.2 主要状态

| 状态 | 进入条件 | 页面可见行为 | 恢复/清理 |
| --- | --- | --- | --- |
| `unloaded` | 尚未加载当前账号 | 显示骨架或加载态 | 账号准备后加载 |
| `localReady` | RDB 快照校验成功 | 显示本地 Provider、模型、场景和小任务 | 远端刷新可继续 |
| `refreshing` | bootstrap 或试用状态请求中 | 已有数据继续可读，刷新控件忙碌 | GET 合并同一 in-flight 请求 |
| `remoteReady` | Pro DTO 校验并合并成功 | 显示 local/Pro 来源和有效模型 | 原子写入 revision/ETag |
| `degraded` | 非鉴权网络失败、远端字段不兼容 | 保留最近有效本地配置，显示可恢复错误 | 手动刷新/重新进入 |
| `invalidated` | 401 或明确 401xx | 停止当前账号 AI 消费，返回会话处理 | 清理账号运行时和敏感引用 |
| `saving` | Provider/模型/小任务写入中 | 保存按钮禁用，避免重复提交 | 成功更新 runtime；失败保留草稿 |

### 3.3 关键业务流程

#### 账号启动

`AppBootstrapper.bootstrapAccountIfNeeded(accountId)` 当前会调用 `GET /api/v1/ai/config/bootstrap/`，非鉴权失败进入 degraded，鉴权失效返回 false。目标实现应在 bootstrap 返回后交给 `AIConfigCenter`，而不是丢弃返回对象；账号切换必须取消旧账号刷新并重新加载新 scope。

#### 编辑并保存 Provider

```text
打开模型密钥
  ↓
Repository.load(accountId)
  ↓
编辑名称/URL/Key/启用/隐私同意
  ↓
Key 写 HUKS，RDB 只写 secretRef
  ↓
ProviderConnectionTest（可选）
  ↓
事务保存 Provider + 相关模型状态
  ↓
Resolver 重建 runtime snapshot
```

#### Pro 试用

```text
打开 Provider 页面
  ↓
GET /api/v1/ai/trial/status/
  ↓
none/pending/rejected/expired/active 状态渲染
  ↓
用户同意隐私政策并提交
  ↓
POST /api/v1/ai/trial/apply/ { note }
  ↓
保存服务端返回状态，不伪造 active
  ↓
刷新 bootstrap 或接收应用内通知后重建 Pro overlay
```

### 3.4 并发、取消与账号隔离

- bootstrap、trial status、Provider test 使用各自的 operation key；相同 GET 合并 in-flight，非幂等 trial apply 禁止重复提交。
- RDB 写操作进入单写队列；同一个 Provider 保存不能与模型目录全量替换并发覆盖。
- 页面离开时取消仅影响页面发起的可取消任务；已经完成的安全持久化不回滚。
- 所有快照、ETag、revision、RDB 行、HUKS alias、模型文件引用和 runtime generation 使用 `accountId` 隔离。
- 旧账号异步回调必须带 generation；不匹配当前账号时丢弃，禁止回写新账号页面。

### 3.5 与《AI 配置生命周期与本地、Pro 统一消费》的职责边界

本文件不是对生命周期方案的替代实现，而是建立在其已经落地的 Repository、RDB、HUKS、Resolver 和 Runtime 之上的“配置编辑与场景管理层”。两份文档必须遵守以下单一事实源：

| 能力 | 生命周期文档负责 | 本场景文档负责 | 禁止重复建设 |
| --- | --- | --- | --- |
| 账号准备 | `AccountSessionRuntime`、`AppLifecycleCoordinator`、`AppBootstrapper` | 页面只订阅账号准备状态 | 不在页面中自行 bootstrap 或判断登录 |
| 本地快照 | `AIConfigRepository`、`AIConfigStore`、`AIConfigRdbStore`、schema/migration | 将页面编辑结果组装成合法 `AIConfigSnapshot` | 不在 UI 内直接 SQL、不创建第二个 RDB |
| API Key | `AIKeyStore`、HUKS、secretRef、删除清理 | 输入、校验、保存确认、密钥已配置状态展示 | 不把 Key 放进 `@State` 快照、Preferences 或页面路由参数 |
| Pro overlay | `AIConfigRepository.refreshRemote()`、revision/etag、Pro 行替换 | 展示远端来源、刷新按钮、冲突提示 | 不在页面中直接消费 Pro DTO 或另调 bootstrap |
| 模型选择 | `AIConfigResolver` 负责最终可用性与来源优先级 | 场景绑定编辑、默认模型选择、不可用原因展示 | 不在页面复制一套 local/Pro fallback 算法 |
| 统一消费 | `AIRuntimeSnapshotStore`、`AIRuntimeService`、Provider Adapter | 保存后触发 runtime 重建并显示保存结果 | 业务页面不得读取 RDB、endpoint 或 secretRef 后自行请求 |
| 本地 GGUF | 生命周期文档负责文件元数据、路由门禁、运行时能力边界 | 模型列表展示下载/导入/删除命令状态 | 未有真实 Adapter 前不得在 UI 宣称“本地推理可用” |

页面与生命周期层的唯一调用关系：

```text
AISettingsPage / ProviderPage / ModelsPage / SmallTasksPage
        ↓
AISettingsViewModel + Feature UseCase
        ↓
AIConfigRepository.save / saveDraft / refreshRemote / buildRuntime
        ↓
AIConfigRdbStore + AIKeyStore + AIConfigResolver
        ↓
AIRuntimeSnapshotStore
        ↓
AIRuntimeService
```

如果两份文档发生冲突，以以下优先级处理：真实 ArkTS 代码 > SparkService 后端契约与测试 > 生命周期方案中的已验证落地结论 > 本文件的 UI/交互设计。场景文档中的任何新增字段必须先进入 `AIConfigModels.ets` 和 RDB schema，再进入页面，不允许只在 UI 临时保存。

## 4. 核心关键技术与实现方案

### 4.1 后端 bootstrap 与 Pro overlay

#### iOS 当前事实

iOS `AIConfigAPI`、`AIConfigCenter`、`AIRuntimeConfigAssembler` 将本地配置和服务端场景模型合并。Pro 模型的 `source` 为 `pro`，本地模型优先；小任务按 `code` 合并，本地同 code 覆盖 Pro。

#### HarmonyOS 目标

`AIConfigAPI.ets` 已有 bootstrap 解码，但 `AIConfigBootstrapResult` 当前将 `scenarios` 声明为 `Object`，且没有领域化的 Provider/Model/Binding DTO。目标应新增显式 `class/interface`，完成 snake_case/camelCase 兼容和字段校验，再交给 Resolver。

伪代码：

```ts
// 伪代码：未作为可直接复制的 ArkTS 实现，需按目标 SDK 编译验证。
class AIConfigResolver {
  resolve(local: LocalAISettings, remote: AIProOverlay | undefined): AIRuntimeSnapshot {
    const mergedScenarios = mergeLocalFirst(local.scenarios, remote?.scenarios);
    const tasks = mergeTasksByCode(local.smallTasks, remote?.smallTasks ?? []);
    return validateAndBuildRuntime(local.accountId, mergedScenarios, tasks);
  }
}
```

#### 安全规则

后端 bootstrap 当前 payload 可能含 `endpoint` 和 `api_key`。HarmonyOS 解码后只能短暂进入受控内存 DTO，不能写日志、Preferences 或 RDB；若服务端最终改为不下发明文 Key，客户端应优先消费 `secretRef`/服务端授权引用。

### 4.2 Provider Key 与连通性测试

`AIConfigAPI.testProviderConnection` 当前请求体为 `{ request_url, api_key, model }`，调用 `POST /api/v1/ai/providers/test-connection/`，网络策略为高优先级、不可重试。页面测试前必须校验 URL、Key、模型非空；测试期间按钮禁用。

目标实现：

1. Provider 编辑页 SecureField 只在页面局部存在明文输入。
2. 点击保存时调用 `AIKeyStore.put(accountId, providerId, key)`，返回 `secretRef`。
3. RDB 只保存 `secret_ref`；Repository 返回页面时不回填明文 Key，可显示已配置/未配置状态。
4. 连通性测试由 UseCase 从安全存储短暂取值，完成后清理局部变量和错误字符串。
5. 任何异常文案只显示“连接失败/URL 无效/Key 未配置”等分类，不展示请求 body 或服务端回显的 Key。

官方参考：[Universal Keystore Kit ArkTS API](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/universal-keystore-arkts)。当前项目 `Foundation/Security/` 已有 Token 安全边界，可借鉴组合根和错误分类，但不能把 Token 存储实现直接当作 API Key 方案，需分别命名空间和生命周期。

### 4.3 模型目录、Agent 和本地模型

模型目录对应 iOS `AllModels`，至少包含：模型唯一名、展示名、identity、Provider、价格档位、启用状态、能力开关、图标、基座模型名、关联小任务和来源。`identity == agent` 时，模型名必须是 Agent 实例稳定标识，不能只使用基座模型名，否则同一基座的多个 Agent 会冲突。

目标页面：

- 模型列表：全部/模型/智能体筛选、搜索、排序、启用 Toggle、信息入口、编辑和删除。
- 添加在线模型：系统名、显示名、Provider、价格档位、能力开关、能力探测。
- 编辑模型：显示名、图标、场景绑定、工具、关联小任务和云端模型能力。
- 新建/编辑智能体：名称、图标、系统 Prompt、基座模型、工具、关联小任务、场景绑定。
- 本地模型：文件下载/导入/删除，RDB 只记录文件 metadata；模型二进制存应用私有目录。

本地 GGUF 推理当前 HarmonyOS 没有代码证据，不得把文件下载完成标记为“已支持本地推理”。

### 4.4 默认模型与场景绑定

默认配置页面按 `AIScenario` 展示场景，至少支持 `chat`、`embedding`、`voice` 和后端已确认的医疗/报告/营养场景。每个场景区块包含场景说明、localKey/Pro source、模型候选和当前摘要。

场景绑定字段：`scenario`、`identity`、`modelId`、`displayName`、`isActive`、`isDefault`、`position`、`temperature`、`maxTokens`、`systemProvision`、`briefDescription`、`aiToolScenarios`、`relatedTaskCodes`。

保存规则：同一场景最多一个默认绑定；设置一个默认值时清除其他默认值；排序使用 `position`；无绑定时不根据模型目录自动推断。

### 4.5 小任务

小任务字段为 `code`、`name`、`brief`、`prompt`、`icon`、`toolList`、`source`、`isDeleted`。本地任务使用 `Local_<id>` 编码，服务端任务使用 `Service_<id>` 语义；合并时本地同 code 覆盖 Pro，其他 Pro 任务保留。

小任务页面对应截图/设计：列表、删除二次确认、新建/编辑表单、图标选择、Prompt 输入、翻译/OCR/语音入口和工具多选。删除后必须检查 Agent/场景绑定的 `relatedTaskCodes`，目标实现要么事务清理，要么阻止删除并给出引用列表。

### 4.6 ArkData、HUKS 和文件分工

| 数据 | HarmonyOS 目标存储 | 禁止位置 |
| --- | --- | --- |
| Provider/Model/Binding/SmallTask 结构化目录 | `@kit.ArkData` RDB，所有表带 `account_id` | 不放普通 Preferences |
| API Key | HUKS；RDB 仅 `secret_ref` | Preferences、明文文件、日志 |
| 当前选中模型/source/revision | 账号 scope Preferences 或 RDB 偏好表 | 不跨账号共用全局 key |
| GGUF/模型二进制 | 应用沙箱私有文件目录 | 不写 RDB blob，不使用公共外部目录 |
| ETag/远端 revision | RDB 账号元数据或 Repository 管理的轻量 KV | 不和用户凭证混存 |

RDB 事务必须覆盖 Provider 与相关模型/绑定的原子更新；写队列保证单写；查询结果使用后关闭。Preferences 仅保存轻量、可恢复、非敏感状态。

### 4.7 UI 页面和交互对齐

| iOS 页面/截图 | HarmonyOS 目标页面 | 关键交互 |
| --- | --- | --- |
| AI 设置首页 | `AISettingsPage.ets` | 进入 Provider、模型、默认模型、小任务四个入口 |
| 模型密钥/编辑密钥 | `ProvidersPage.ets`、`ProviderEditorPage.ets` | Provider 列表、启用、隐私政策、Key 状态、API 测试 |
| 模型列表 | `ModelsPage.ets` | 全部/模型/智能体、搜索、编辑、删除、显隐 |
| 添加在线模型 | `AddOnlineModelPage.ets` | 必填校验、Provider 选择、价格和能力开关 |
| 编辑模型 | `EditModelPage.ets` | 图标、能力、场景、工具、小任务 |
| 新建智能体 | `AgentEditorPage.ets` | Prompt、基座模型、工具、关联任务和场景 |
| 默认模型配置 | `DefaultModelPreferencesPage.ets` | 本地/Pro 来源切换和场景默认模型 |
| 编辑小任务 | `SmallTaskEditorPage.ets` | Prompt、图标、工具、保存和删除确认 |

ArkUI 视觉上可使用深色背景和深灰卡片，但页面只绑定 `AISettingsPageState`，不直接绑定 RDB 行对象；所有保存按钮都必须有 disabled、saving、success、error 状态。

### 4.8 页面级 UI 规格与 Plain text 草图

本节是 HarmonyOS UI 开发的逐页规格。每个页面必须有独立的页面状态对象；按钮不能只改变视觉状态，必须调用下表指定的 UseCase/Repository 命令。草图使用 plain text 表示信息层级，不代表 ArkUI 组件名称。

#### 4.8.1 UI 通用规则

```text
页面背景：深色 #000000 / 浅色 systemBackground
卡片背景：深色 #1C1C1E / 浅色 white
主文字：primary
辅助文字：secondary
操作色：tint blue
启用开关：blue 或设计系统 success
禁用开关：gray track + white thumb
```

所有页面统一具备：

| 区域/组件 | 行为 |
| --- | --- |
| 左上角返回 | 返回上一页；正在加载时允许返回，但取消当前页面任务，不取消已经完成的持久化 |
| 右上角确认 | 根据页面显示“保存/添加/创建”；字段无效或 saving 时禁用 |
| 加载状态 | 页面首载显示 Progress/骨架；已有快照刷新时保留旧内容并只显示刷新状态 |
| 错误状态 | 页面内显示可理解的错误分类；不展示 Key、Authorization、完整 URL、Prompt 或响应 body |
| 空状态 | 显示原因、下一步入口和是否可重试；不得用示例模型伪装数据 |
| 页面离开 | 取消本页面可取消异步任务；未保存草稿按页面定义处理 |
| 账号切换 | 页面 generation 失效，禁止旧页面回写新账号；清理旧账号敏感内存 |

#### 4.8.2 页面一：AI 设置首页 `AISettingsPage.ets`

```text
┌────────────────────────────────────────┐
│                 AI 设置                 │
├────────────────────────────────────────┤
│ 模型设置                               │
│  🔑  模型密钥       厂商密钥与端点    › │
│  ───────────────────────────────────── │
│  ▱   模型           模型目录与能力开关 ›│
│  ───────────────────────────────────── │
│  ☷   默认模型配置   按场景配置本地/Pro ›│
│                                        │
│ 工具/检索/知识                          │
│  ☑   小任务         维护本地小任务    › │
└────────────────────────────────────────┘
```

| 组件/按钮 | 点击效果 | 禁用/失败 |
| --- | --- | --- |
| 模型密钥行 | `NavPathStack.pushPathByName('providers')`，打开 `ProvidersPage` | 账号未准备时显示登录/准备中，不读取全局配置 |
| 模型行 | 推入 `ModelsPage` | RDB 尚未初始化时显示加载态 |
| 默认模型配置行 | 推入 `DefaultModelPreferencesPage` | 没有模型时页面仍可进入并显示空态 |
| 小任务行 | 推入 `SmallTasksPage` | 没有任务时显示“暂无本地小任务” |
| 页面加载 | `loadAISettingsUseCase.execute(accountId)` | 失败保留上次内存快照并提供重试 |
| 重试 | 重新加载当前账号快照 | 不得切换到其他账号或默认全局数据 |

#### 4.8.3 页面二：模型密钥列表 `ProvidersPage.ets`

```text
┌────────────────────────────────────────┐
│ ‹              模型密钥               ＋│
├────────────────────────────────────────┤
│ [Pro 试用卡片：按 none/pending/active 显示]│
│                                        │
│ 模型厂商                               │
│  ◉ 302.AI                         ›  ● │
│  ───────────────────────────────────── │
│  ◉ 推理时代                        ›  ○│
│  ───────────────────────────────────── │
│  ◉ Anthropic                       ›  ○│
└────────────────────────────────────────┘
```

| 组件/按钮 | 点击效果 | 禁用/保存细节 |
| --- | --- | --- |
| 右上角 `+` | 推入 `AddCustomProviderPage` | 始终可点；表单为空时“保存”禁用 |
| Provider 行 | 推入 `ProviderEditorPage(providerId)` | 只显示当前账号 Provider；Key 只显示“已配置/未配置” |
| Provider 开关 | 调用 `setProviderEnabled`；成功后重建本地 bundle | 开启前必须有 secretRef；没有 Key 显示错误，不改变开关 |
| Pro 试用卡片 | 打开/展开 `AITrialCard` 状态内容 | pending 时提交按钮禁用 |
| 下拉刷新 | 调用 `refreshProviderRuntimeConfiguration` | 失败保留旧列表 |
| 错误确认 | 关闭错误提示 | 不清理已保存 Provider |

#### 4.8.4 页面三：新增自定义 Provider `AddCustomProviderPage.ets`

```text
┌────────────────────────────────────────┐
│ 取消        新增自定义供应商         保存│
├────────────────────────────────────────┤
│ 供应商名称  [                        ]  │
│ API Key     [••••••••••••••••••••••]  │
│ 请求地址    [https://                 ] │
│ [补全 /v1/chat/completions]             │
│                                        │
│ 错误：请求地址必须以 http(s) 开头       │
└────────────────────────────────────────┘
```

| 组件/按钮 | 点击效果 |
| --- | --- |
| 名称输入 | 写入页面草稿 `name`；去除首尾空白只在保存时执行 |
| API Key 输入 | 写入临时安全输入状态；离开页面或保存失败后清理明文状态 |
| 请求地址输入 | 写入草稿 `requestURL`；使用 URL 键盘，禁自动纠错 |
| 补全路径 | 去除尾部 `/`，追加 `/v1/chat/completions` |
| 保存 | 校验名称、Key、URL；调用 HUKS 写入 Key，再 RDB 保存 Provider `secretRef`；成功返回列表 |
| 取消 | 关闭页面并清理 Key 草稿，不创建数据 |
| 错误提示 | 留在当前页，保留名称/URL 草稿；不显示 Key 内容 |

保存按钮禁用条件：名称为空、Key 为空、URL 为空、正在保存。URL 不是 `http://` 或 `https://` 时，即使按钮可点也必须在页面内阻止提交。

#### 4.8.5 页面四：Provider 编辑 `ProviderEditorPage.ets`

```text
┌────────────────────────────────────────┐
│ ‹              编辑密钥               保存│
├────────────────────────────────────────┤
│ [●] 字节豆包                            │
│ 请求地址  https://api.example.com/...   │
│ API Key   已配置                        │
│ 查看隐私政策                            │
│ [●] 我已阅读并同意该厂商隐私政策         │
│                                        │
│ 该厂商模型                            ＋│
│  ◉ Doubao Seed 1.6             ⓘ   ●  │
│  ───────────────────────────────────── │
│  ◉ Doubao Seed 1.6 Lite         ⓘ   ○  │
│                                        │
│ API 测试                               │
│ 测试模型       Doubao Seed 1.6      ˅  │
│ 测试 API                 [成功/失败]    │
└────────────────────────────────────────┘
```

| 组件/按钮 | 点击效果 | 约束 |
| --- | --- | --- |
| Provider 开关 | 写入启用草稿；启用后调用 Repository 保存 | Key 未配置时阻止开启 |
| 请求地址 | 编辑 URL | 保存前校验 scheme 和非空 |
| API Key | 点击“更新密钥”后打开安全输入，不回填旧 Key | RDB 只保存 `secretRef` |
| 查看隐私政策 | 推入 `ProviderPrivacyPolicyPage`/ArkWeb | URL 无效不显示 |
| 隐私同意 | 更新 `privacyPolicyAccepted` | 有政策且未同意时保存禁用 |
| 模型区 `+` | 打开 `ProviderModelManagementPage` | 传入当前 Provider ID |
| 模型显隐开关 | 调用模型可见性 UseCase | 没有有效 Key 的云模型不可启用 |
| 模型 info | 打开模型详情/能力说明 | 不展示 endpoint 或 API Key |
| 模型删除 | 显示确认；确认后删除模型并清理绑定 | 有引用时必须提示或事务清理 |
| 测试模型 Picker | 只显示已启用且支持文本的模型 | 没有候选时测试按钮禁用 |
| 测试 API | HUKS 临时取 Key，POST Provider test；显示 loading/成功/失败 | 不重试、不记录 body、禁止重复点击 |
| 保存 | 保存 Provider 和开关状态，重建 Runtime，返回列表 | saving 时禁用；失败留在当前页 |

#### 4.8.6 页面五：隐私政策 `ProviderPrivacyPolicyPage.ets`

```text
┌────────────────────────────────────────┐
│ ‹              隐私政策                 │
├────────────────────────────────────────┤
│                                        │
│          ArkWeb / 隐私政策正文          │
│                                        │
│ [页面加载中]   [加载失败：重新加载]      │
└────────────────────────────────────────┘
```

| 组件/按钮 | 点击效果 |
| --- | --- |
| 返回 | 返回 Provider 编辑页，不自动改变同意状态 |
| 重新加载 | 重新请求当前合法 URL |
| 网页内部链接 | 在受控 ArkWeb 内打开；不得把 URL 内容写入日志 |
| 同意 | 同意动作位于 Provider 编辑页，不在 WebView 内直接持久化 |

#### 4.8.7 页面六：模型管理 `ProviderModelManagementPage.ets`

```text
┌────────────────────────────────────────┐
│ 关闭      ARK_API_KEY 模型          ＋ ↻│
├────────────────────────────────────────┤
│ 自动刷新                               │
│ 进入页面自动拉取一次，也支持手动刷新     │
│                                        │
│ 已添加 (2)                             │
│  ◉ Doubao Seed 1.6                 ●  │
│  ◉ Doubao Seed 1.6 Lite             ○  │
│                                        │
│ 远端可用 (118)                         │
│  ◉ deepseek-r1-250120             添加│
│  ◉ deepseek-r1-250528             添加│
│                                        │
│ 🔍 搜索模型                             │
└────────────────────────────────────────┘
```

| 组件/按钮 | 点击效果 |
| --- | --- |
| 关闭 | 关闭页面；不丢失已经持久化的模型 |
| `+` | 打开 `AddOnlineModelPage`，默认 Provider 为当前 Provider |
| 刷新 | 调用 Provider 模型目录服务；显示刷新态，失败保留已添加列表 |
| 搜索框 | 只过滤当前已添加/远端列表，不修改数据 |
| 已添加开关 | 更新模型启用状态；失败恢复原状态 |
| 已添加 info | 打开模型详情 |
| 远端“添加” | 校验 Provider Key，创建本地模型目录行；成功变为已添加 |
| 空状态 | 无 Key、无远端模型、无搜索结果分别显示不同说明 |

#### 4.8.8 页面七：模型目录 `ModelsPage.ets`

```text
┌────────────────────────────────────────┐
│ ‹    ＋       [全部 | 模型 | 智能体]   ☰│
│                                        │
│ 模型                                   │
│ ┌────────────────────────────────────┐ │
│ │ ◉ Doubao Seed 1.6            ⓘ  ● │ │
│ │   工具  视觉  思考  经济             │ │
│ │ ────────────────────────────────── │ │
│ │ ◉ Doubao Seed 1.6 Lite        ⓘ  ○ │ │
│ │   工具  文本  思考  经济             │ │
│ └────────────────────────────────────┘ │
└────────────────────────────────────────┘
```

| 组件/按钮 | 点击效果 |
| --- | --- |
| 返回 | 返回 AI 设置首页 |
| 加号 Menu | 展开“添加在线模型”“添加本地模型”“添加智能体”“高级编辑” |
| 添加在线模型 | 推入 `AddOnlineModelPage` |
| 添加本地模型 | 推入 `LocalModelDownloadPage` |
| 添加智能体 | 打开 `AgentEditorPage` 新建态 |
| 高级编辑 | 推入 `ModelsAdvancedPage` |
| 全部/模型/智能体 | 更新 `selectedIdentity` 并同步标题和搜索提示 |
| 搜索 | 按 displayName、name、company、baseModelName 和拼音过滤 |
| 编辑/完成 | 切换编辑态；编辑态显示排序/删除，不显示普通显隐操作 |
| 模型 info | 打开 `EditModelPage`；Agent info 打开 `AgentEditorPage` 编辑态 |
| 显隐 Toggle | 调用模型可见性 UseCase；无 API Key 时阻止云模型启用 |
| 左滑编辑 | 打开对应编辑页 |
| 右滑删除 | 弹确认并删除；同时清理绑定和 Agent 引用 |

#### 4.8.9 页面八：高级模型编辑 `ModelsAdvancedPage.ets`

```text
┌────────────────────────────────────────┐
│ ‹              高级模型编辑             │
├────────────────────────────────────────┤
│ 🔍 搜索模型                             │
│                                        │
│ ▾ Doubao Seed 1.6                      │
│   显示名称 [                         ]  │
│   厂商     [字节豆包                 ]  │
│   身份     [模型                   ˅]  │
│   可见                         [●]     │
│   支持搜索                     [○]     │
│   支持多模态                   [●]     │
│   价格档位                    免费 ˅   │
│                                        │
│ 侧滑：编辑 / 删除    长按/编辑：排序    │
└────────────────────────────────────────┘
```

| 组件/按钮 | 点击效果 |
| --- | --- |
| 搜索 | 过滤模型/Agent，不改变底层顺序 |
| Disclosure 展开 | 展开全部目录字段；收起只显示模型名称 |
| 身份 Picker | 切换 `model/agent`；改变前需确认 Agent 专属字段 |
| 能力开关 | 写入领域草稿，保存时统一提交 |
| 价格 Picker | 写入 0..3 价格档位 |
| 删除 | 删除目录行，事务清理场景绑定和文件 metadata |
| 排序 | 通过编辑态拖动更新 `position`；保存后持久化 |

#### 4.8.10 页面九：添加在线模型 `AddOnlineModelPage.ets`

```text
┌────────────────────────────────────────┐
│ 取消                             添加  │
│ 添加在线模型                           │
│ 基本信息                               │
│ ┌────────────────────────────────────┐ │
│ │ 🔎 系统名称（用于 API 请求）        │ │
│ │ 格式      显示名称（自定义）        │ │
│ │ 🏢 厂商                         ˅  │ │
│ └────────────────────────────────────┘ │
│ 价格                                   │
│ ┌────────────────────────────────────┐ │
│ │ ￥ 价格档位                    免费 ˅│ │
│ └────────────────────────────────────┘ │
│ 能力                                   │
│ 默认隐藏                         [○]  │
│ 自动模型能力探测                   ›  │
│ 注意：探测可能产生 API 费用             │
│ 支持文本                         [●]  │
│ 支持多模态                       [○]  │
│ 支持推理                         [○]  │
│ 思考可控                         [○]  │
│ 支持工具调用                     [○]  │
│ 支持生图                         [○]  │
└────────────────────────────────────────┘
```

| 组件/按钮 | 点击效果/校验 |
| --- | --- |
| 系统名称 | 必填，写入 API `name` |
| 显示名称 | 必填，写入 `displayName` |
| Provider Picker | 只显示已配置且启用的 Provider；无 Provider 时不能添加 |
| 价格 Picker | 选择免费/经济/标准/高级，写入 `priceTier` |
| 默认隐藏 | 写入 `isHidden`；隐藏模型不进入默认候选 |
| 自动能力探测 | 打开 `ModelCapabilityProbePage`；显示 loading/逐项结果/失败 |
| 能力开关 | 写入对应 `supports*` 字段 |
| 添加 | 校验必填字段，写 RDB 模型目录并返回 ModelsPage |
| 取消 | 关闭页面，丢弃草稿 |
| 错误 | 显示字段级错误；不清除其他已填字段 |

#### 4.8.11 页面十：编辑模型 `EditModelPage.ets`

```text
┌────────────────────────────────────────┐
│ 取消                             保存  │
│ 编辑模型                               │
│ 名称                                   │
│ ┌────────────────────────────────────┐ │
│ │ Doubao Seed 1.6                   │ │
│ └────────────────────────────────────┘ │
│ 图标              [      ◌       ]     │
│ 使用场景与工具                         │
│ 使用场景                         15 › │
│ 工具                           全部 › │
│ 关联小任务                       0 ›  │
│ 能力                                   │
│ 支持文本                         [●]  │
│ 支持多模态                       [●]  │
│ 支持推理                         [●]  │
│ 思考可控                         [●]  │
│ 支持工具调用                     [●]  │
└────────────────────────────────────────┘
```

| 组件/按钮 | 点击效果 |
| --- | --- |
| 名称 | 编辑 `displayName`，保存时 trim |
| 图标 | 打开 `ModelIconPickerPage`，回填 icon |
| 使用场景 | 推入 `ScenarioBindingPage(modelId)` |
| 工具 | 推入 `ToolSelectionPage`，回填 `aiToolScenarios` |
| 关联小任务 | 推入 `SmallTaskSelectionPage`，回填 `relatedTaskCodes` |
| 能力开关 | 编辑非本地、非只读云模型的能力字段；本地模型只允许显示名/图标 |
| 保存 | `replaceModelAndPersist`；事务成功后返回 |
| 取消 | 丢弃当前模型草稿并返回 |

#### 4.8.12 页面十一：新建/编辑智能体 `AgentEditorPage.ets`

```text
┌────────────────────────────────────────┐
│ 取消                            创建/保存│
│ 新建智能体                             │
│ 图标选择          [ stethoscope ]      │
│ 基础信息                               │
│ 智能体名称       [                  ]  │
│ 智能体设定                             │
│ ┌────────────────────────────────────┐ │
│ │ 系统 Prompt                  工具 🎙⌃│ │
│ │                         自动填写    │ │
│ ├────────────────────────────────────┤ │
│ │ 关联小任务                       0 ›│ │
│ └────────────────────────────────────┘ │
│ 基座模型              Doubao Seed ˅   │
│ 使用场景                         0 ›  │
│ 工具                           全部 › │
└────────────────────────────────────────┘
```

| 组件/按钮 | 点击效果/禁用条件 |
| --- | --- |
| 图标 | 打开图标选择页 |
| 智能体名称 | 写入 `displayName`；为空时“自动填写”和创建均禁用 |
| Prompt | 写入 `systemPrompt`；支持文本工具、OCR、翻译和语音输入 |
| 自动填写 | 调用 `autoFillAgentPrompt(name, baseModelName)`；运行中显示进度，再次点击可恢复原文本 |
| 关联小任务 | 推入多选页，按 code 保存 |
| 基座模型 | 只显示已启用、支持文本且有本地文件或有效 Key 的模型 |
| 使用场景 | 推入场景绑定页；新建 Agent 尚未落盘时只改草稿 |
| 工具 | 推入工具多选页，显示全部或 `n/total` |
| 创建/保存 | 名称、基座模型、Prompt 非空时调用 Agent CRUD UseCase；成功关闭 |
| 取消 | 关闭并丢弃草稿 |
| 失败 alert | 保留已输入 Prompt 和名称，不展示底层请求内容 |

#### 4.8.13 页面十二：默认模型配置 `DefaultModelPreferencesPage.ets`

```text
┌────────────────────────────────────────┐
│ ‹              默认模型配置             │
├────────────────────────────────────────┤
│ 🔍 搜索场景                             │
│ 对话                                   │
│ ┌────────────────────────────────────┐ │
│ │            [对话图标]              │ │
│ │ 对话模型用于日常问答和多轮对话      │ │
│ │ [本地模型] [Pro 模型]               │ │
│ │ 场景模型              Doubao ˅     │ │
│ │ ◉ Doubao Seed 1.6                  │ │
│ └────────────────────────────────────┘ │
│ 向量模型                               │
│ ┌────────────────────────────────────┐ │
│ │ 暂无可用模型：请配置 API Key 或模型 │ │
│ └────────────────────────────────────┘ │
│ 语音模型                               │
└────────────────────────────────────────┘
```

| 组件/按钮 | 点击效果 |
| --- | --- |
| 搜索场景 | 过滤本地化场景名，不影响配置 |
| 本地模型/Pro 模型 | 改变当前场景 `AIModelSelectionSource`，重新计算 bundle |
| 场景模型 Picker | 只列当前 source bundle 的模型；选择写入偏好 |
| 模型摘要 | 显示 Provider 图标、displayName、原始 name；原始名可复制 |
| 空状态 | 显示配置引导；不能生成无效模型选择 |
| 返回 | 返回 AI 设置首页 |

保存策略：当前设计为选择后即时写入轻量偏好；若 HarmonyOS 使用显式“保存”，则保存按钮必须显示 dirty 状态，并在失败时保留选择草稿。

#### 4.8.14 页面十三：场景绑定 `ScenarioBindingPage.ets`

```text
┌────────────────────────────────────────┐
│ ‹              使用场景              ＋│
├────────────────────────────────────────┤
│ 普通聊天                               │
│ 默认   温度 0.70   Token 4096       ›│
│ 报告解读                               │
│ 未启用 温度 0.20   Token 8192       ›│
│                                      │
│ 左滑：删除绑定                         │
└────────────────────────────────────────┘
```

| 组件/按钮 | 点击效果/规则 |
| --- | --- |
| `+` | 打开新增绑定表单；所有场景已绑定时禁用 |
| 绑定行 | 打开编辑绑定表单 |
| 左滑删除 | 确认后删除；同步清理 Runtime 引用 |
| 场景 Picker | 新增时选择未绑定场景；编辑时只读 |
| 启用 Toggle | 写入 `isActive` |
| 默认 Toggle | 写入 `isDefault`，同一场景自动清除其他默认 |
| 温度/最大 Token | 输入范围校验；保存前拒绝负数/零值等非法值 |
| 系统 Prompt | 打开 Prompt 编辑器，写入 `systemProvision` |
| 描述 | 写入 `briefDescription` |
| 工具 | 推入 `ToolSelectionPage` |
| 关联小任务 | 推入 `SmallTaskSelectionPage` |
| 保存/取消 | 保存通过事务提交，取消不调用持久化 |

#### 4.8.15 页面十四：小任务列表 `SmallTasksPage.ets`

```text
┌────────────────────────────────────────┐
│ ‹                小任务               ＋│
├────────────────────────────────────────┤
│ ☑ 摘要整理                             │
│   将长文本整理成摘要                    │
│ ───────────────────────────────────── │
│ ☑ 健康术语解释                         │
│   使用通俗语言解释医学术语              │
│                                      │
│ 左滑：删除                              │
└────────────────────────────────────────┘
```

| 组件/按钮 | 点击效果 |
| --- | --- |
| `+` | 打开 `SmallTaskEditorPage` 新建态，生成下一个 `Local_<id>` code |
| 任务行 | 打开编辑态，载入名称、简介、Prompt、图标和工具 |
| 左滑删除 | 弹“删除小任务？”；确认执行删除，取消关闭弹窗 |
| 空状态 | 显示“暂无本地小任务”和新增入口 |
| 刷新 | 重新加载本地任务和 Pro 合并任务；本地任务仍优先 |

删除策略必须在提交前查找 `relatedTaskCodes` 引用：有引用时显示引用的 Agent/场景数量并阻止删除，或使用同一 RDB 事务清理引用；不能只删除任务行。

#### 4.8.16 页面十五：小任务编辑 `SmallTaskEditorPage.ets`

```text
┌────────────────────────────────────────┐
│ 取消                              保存 │
│ 编辑小任务                             │
│ 图标选择          [     checklist ]    │
│ 基础信息                               │
│ ┌────────────────────────────────────┐ │
│ │ 名称                               │ │
│ │ ───────────────────────────────── │ │
│ │ 简介                               │ │
│ └────────────────────────────────────┘ │
│ Prompt                                 │
│ ┌────────────────────────────────────┐ │
│ │ Prompt 内容                输入工具│ │
│ │                             🎙  ⌃  │ │
│ └────────────────────────────────────┘ │
│ 工具                           全部 › │
└────────────────────────────────────────┘
```

| 组件/按钮 | 点击效果/规则 |
| --- | --- |
| 图标 | 打开 `ModelIconPickerPage` |
| 名称 | 必填，保存时 trim |
| 简介 | 可选；列表为空时显示 code |
| Prompt | 必填；支持文本抽屉、OCR、翻译和语音输入 |
| 输入工具 | 打开 `PromptInputDrawerPage`；结果回填当前 Prompt |
| 麦克风 | 打开 `VoiceInputPage`；取消不改变原文本 |
| 工具 | 打开工具多选页，保存 `toolList` |
| 保存 | 名称和 Prompt 非空时调用 `upsertLocalSmallTask`，成功返回列表 |
| 取消 | 关闭并丢弃草稿 |
| 错误 | 保留所有输入，显示分类错误，不显示 Prompt 内容 |

#### 4.8.17 页面十六：工具/小任务多选与 Prompt 工具抽屉

```text
工具选择                              Prompt 输入工具
┌──────────────────────┐              ┌──────────────────────┐
│ [●] 全部             │              │ 翻译                 │
│ [●] 搜索             │              │ OCR 图片             │
│ [○] 网页             │              │ 从模板插入            │
│ [○] 文件             │              │ 关闭                 │
└──────────────────────┘              └──────────────────────┘
```

| 页面/按钮 | 行为 |
| --- | --- |
| 全部 Toggle | 全选/取消全部，返回摘要“全部” |
| 工具行 | 单项切换，返回 `n/total` |
| 翻译 | 异步翻译当前 Prompt；失败保留原文 |
| OCR | 请求图片权限/选择图片后识别；失败不清空 Prompt |
| 模板 | 从本地已加载模板选择并插入；不得直接读取网络 |
| 关闭 | 关闭抽屉，不修改未确认内容 |

#### 4.8.18 页面十七：本地模型下载/能力探测/图标选择

```text
本地模型下载                         能力探测结果
┌────────────────────────┐           ┌────────────────────────┐
│ Qwen 0.6B   [下载]     │           │ 文本生成       ✓       │
│ Qwen 3B     [下载]     │           │ 多模态         ✕       │
│ 当前进度 42%           │           │ 推理           ✓       │
│ 取消下载               │           │ 关闭            确定    │
└────────────────────────┘           └────────────────────────┘

图标选择
┌────────────────────────┐
│ [✓] [☷] [⌁] [⌘] [♡]   │
│ 取消              确定 │
└────────────────────────┘
```

| 页面/按钮 | 行为 |
| --- | --- |
| 下载 | 请求文件服务，显示进度；完成后写 `ai_model_file` metadata |
| 取消下载 | 取消网络/文件任务，删除临时文件，不创建可用模型行 |
| 重试 | 仅重试可恢复下载错误；不重复写已完成文件 |
| 能力探测 | 显示每项能力结果和费用/耗时提示；关闭不改变模型，确认才回填草稿 |
| 图标格 | 选择图标并回填编辑页；取消保持旧图标 |

本地模型下载成功不等于本地推理可用；必须等待 `LocalModelAdapter`、内存预算、取消和真实设备测试完成后才可在模型行显示“可推理”。

### 4.9 本地化配置实现细节与完整技术方案

本节以 2026-07-21 对 HarmonyOS 工程的代码审计结果为准，描述当前真实实现、推荐的生产实现和需要补齐的边界。这里的“本地化”包含四类不同数据，不能用一个 `Preferences` 或一个 JSON 文件全部承载：

| 数据类别 | 例子 | 当前/目标存储 | 是否进入多端同步 | 关键原则 |
| --- | --- | --- | --- | --- |
| 内置种子 | 默认 Provider、模型、场景绑定、小任务、默认来源 | `resources/rawfile/ai/*.json` → RDB | 不直接同步 | 版本化、可重复执行、不能放密钥 |
| 用户配置 | Provider 开关、模型开关、场景默认、小任务 Prompt、工具列表 | `spark_client.db` 的 `ai_*` 表 | 目前本地；若产品要求多端同步，必须新增服务端契约 | 账号隔离、事务写入、可回滚 |
| 凭证 | Provider API Key、未来 OAuth/STS secret | HUKS 密钥 + 应用私有密文文件；RDB 只存 `secret_ref` | 不同步明文 | Key 不进入 RDB、Preferences、日志、备份或普通导出 |
| 大文件 | GGUF 模型、校验信息、下载状态 | 应用 `filesDir/ai-models/<account>/<model>/` + RDB 元数据 | 不同步二进制；可同步目录/下载任务 | 临时文件、断点、校验、删除和空间回收 |

#### 4.9.1 当前真实代码链路

```text
EntryAbility / AppContainer
        │
        ├─ AppRelationalDatabase -> spark_client.db
        │       ├─ AIConfigSchema.ddlStatements()
        │       └─ AppRdbWriteQueue（全库单写队列）
        │
        ├─ AIKeyStore(filesDir/ai-secrets)
        │       └─ HuksAesGcmCipher -> HUKS AES-256-GCM
        │
        ├─ AIConfigRepository
        │       ├─ ensureSeeded(accountId)
        │       ├─ loadSnapshot(accountId)
        │       ├─ refreshRemote(accountId)
        │       ├─ save / saveDraft
        │       └─ buildRuntime(accountId)
        │
        ├─ AIConfigResolver -> RuntimeSnapshot
        └─ AIRuntimeService -> RemoteAdapter / LocalModelAdapter

账号进入：AccountSessionRuntime.activateUser
       -> AppBootstrapper.prepareAccount
       -> 本地 seed + buildRuntime
       -> bootstrap Pro + replaceRemotePro
       -> Runtime 可消费

账号退出/401：清 Runtime -> 清 Key -> 删 RDB 账号行 -> 清账号发布状态
```

代码事实：`AppContainer.ets` 已完成 `AppRelationalDatabase`、`AIConfigRdbStore`、`AIKeyStore`、`AIConfigResolver`、`AIConfigRepository`、`AIRuntimeService` 和 `LocalModelFileService` 的组合；`AppBootstrapper.ets` 已使用“local-first → remote refresh → degraded 放行”的准备策略；`SettingsPage.ets` 已嵌入 `AISettingsPage`。因此后续开发不能再重新设计第二套 AI Store 或第二个 Runtime 入口。

#### 4.9.2 初始化状态机

```text
UNINITIALIZED
  ├─ 打开 RDB 成功 -> EMPTY
  ├─ RDB 打开失败 -> DEGRADED（页面显示本地配置不可用）
  └─ 账号未登录 -> 不允许创建账号级快照

EMPTY
  └─ ensureSeeded
       ├─ rawfile 解析成功 + RDB 事务成功 -> LOCAL_READY
       └─ 解析/写入失败 -> DEGRADED + 可重试

LOCAL_READY
  ├─ buildRuntime -> Runtime 可消费
  ├─ 网络关闭 -> 保持 LOCAL_READY
  ├─ Pro bootstrap 成功 -> REMOTE_READY
  ├─ 网络错误/超时 -> DEGRADED，继续使用本地快照
  └─ 401/鉴权失效 -> INVALIDATED，交给会话失效流程

DRAFT
  ├─ 保存成功 -> LOCAL_READY
  ├─ 放弃 -> 恢复 persistedSnapshot
  └─ 页面退出未保存 -> 不应覆盖已持久化快照
```

每次状态转换必须同时更新：

1. `ai_account_meta.sync_state`。
2. 内存 `AIRuntimeSnapshotStore` 的 `state` 和 `runtimeSource`。
3. 页面 ViewModel 的 `loading/saving/errorMessage/hasUnsavedChanges`。
4. 诊断事件，但诊断事件只记录状态、revision、错误类别，不记录 Key、Prompt、完整 endpoint 或响应 body。

#### 4.9.3 RDB 设计、字段语义和事务边界

当前 `AIConfigSchema.ets` 已定义 `ai_account_meta`、`ai_provider`、`ai_model`、`ai_scenario_binding`、`ai_small_task`、`ai_model_file`、`ai_preferences` 七张表，并注册到共用 `spark_client.db`。表前缀隔离了 AI 模块，但数据库版本是全库 `PRAGMA user_version`，因此后续 Chat/Knowledge 模块不能各自递增自己的版本号。

| 表 | 主键 | 必须保持的约束 | 写入来源 | 删除策略 |
| --- | --- | --- | --- | --- |
| `ai_account_meta` | `account_id` | 每个已登录账号最多一行；记录 schema、seed、remote revision、etag、sync state | 初始化、远端刷新、状态更新 | 删除账号时先删子表或依赖级联 |
| `ai_provider` | `(account_id,id)` | `id` 必须稳定；`secret_ref` 可空但不得是 API Key | seed、用户编辑、Pro overlay | Provider 删除前处理模型引用 |
| `ai_model` | `(account_id,id)` | `provider_id` 必须同账号存在；`model_type` 只能是 `remote/gguf` | seed、用户编辑、Pro overlay | 先删文件元数据、场景绑定，再删模型 |
| `ai_scenario_binding` | `(account_id,scenario,model_id)` | scenario/model 必须存在；每个场景最多一个有效默认 | seed、用户编辑、Pro overlay | 模型删除时级联或事务清理 |
| `ai_small_task` | `(account_id,code)` | code 稳定；Prompt 可为空与否需由产品契约确定 | seed、用户编辑、Pro overlay | 被 Agent/绑定引用时阻断或事务解除引用 |
| `ai_model_file` | `(account_id,model_id)` | path 必须在应用私有目录；ready 必须经过 hash/size 校验 | 下载服务、导入服务 | 删除模型或账号时物理删除文件 |
| `ai_preferences` | `account_id` | `default_source` 只能 `local/pro/auto`；开关采用 0/1 | 设置页、迁移 | 随账号删除 |

当前 `AIConfigRdbStore.saveLocal()` 的整体策略是先保留 `pro` 行，删除非 Pro 的绑定/模型/Provider 和本地任务，再批量插回当前快照；这能避免旧的孤儿行，但仍需补齐以下生产约束：

1. `saveLocal()` 必须包在一个数据库事务中。当前写队列保证串行，不等于多条 SQL 原子提交；中途失败可能出现 Provider 已删、Model 未插回的半快照。
2. 应增加 `snapshot_generation` 或 `write_id`，在事务开始和完成时记录，启动恢复时发现未完成写入应回滚到上一版或重建。
3. `INSERT OR REPLACE` 可能表现为删除后插入，涉及外键和更新时间时不能把它当作无副作用更新；生产版本优先使用明确的 upsert 或临时 staging 表交换。
4. `PRAGMA user_version` 必须由 `AppRelationalDatabase` 统一迁移；AI 模块只能提供 `migrateFrom(version)`，不能自行覆盖全局版本。
5. 查询结果集必须在 `finally` 关闭；当前多数路径已关闭，新增查询不得把 `ResultSet` 持有到 UI 层。
6. 所有 SQL 值使用参数绑定；不能复制示例工程 `ParcelDB.ets` 中拼接业务字符串的方式到 Prompt、Provider URL 或模型名称。

推荐生产写入流程：

```text
编辑快照 draft
  -> validateSnapshot
      - accountId 与当前会话一致
      - 引用存在
      - 每场景默认最多一个
      - Provider URL 合法且允许的 scheme
      - GGUF 文件状态与 modelType 一致
  -> writeQueue.enqueue
  -> beginTransaction
  -> 写 staging/版本记录
  -> 写 provider/model/binding/task/file/preferences
  -> 更新 account_meta(snapshot_generation, updated_at, sync_state)
  -> commit
  -> resolver.buildRuntime
  -> runtimeStore.publish
```

#### 4.9.4 rawfile 种子设计

当前 `AIConfigRepository.loadSeedJson()` 读取以下资源路径：

```text
resources/rawfile/ai/providers.json
resources/rawfile/ai/models.json
resources/rawfile/ai/scenario_bindings.json
resources/rawfile/ai/small_tasks.json
resources/rawfile/ai/preferences.json
```

每个文件都必须是可校验的 JSON，不能靠空数组静默吞掉资源损坏。建议资源目录补充：

```text
resources/rawfile/ai/
├── manifest.json
├── providers.json
├── models.json
├── scenario_bindings.json
├── small_tasks.json
└── preferences.json
```

`manifest.json` 字段建议：

| 字段 | 类型 | 作用 |
| --- | --- | --- |
| `seedVersion` | number | 种子结构版本，不等于数据库 schema 版本 |
| `files` | object | 文件名到 sha256/size 的映射 |
| `minimumAppVersion` | string | 防止旧客户端读取新字段产生错误 |
| `knownScenarios` | string[] | 与 `AIScenario.allKnown()` 对照 |
| `createdAt` | string | 追踪构建产物 |

加载步骤：

1. 先读取并解析 manifest。
2. 校验每个文件存在、长度合理、SHA-256 一致。
3. 分别解析成强类型对象，拒绝缺少主键的行。
4. 先校验跨文件引用，再开启 RDB 事务。
5. 只有全量成功才写入 `seedVersion`；任何一步失败不得把账号标为 seeded。
6. `seedVersion` 相同直接跳过；更高版本采用迁移策略，不能覆盖用户已编辑字段。

建议区分三种种子字段：

```text
system-owned:  Provider 的展示信息、系统场景、系统小任务
user-owned:    Provider 开关、模型开关、默认模型、用户 Prompt、工具列表
derived:       Runtime 可用性、模型文件状态、最后错误、排序缓存
```

升级时只覆盖 `system-owned`，保留 `user-owned`；`derived` 必须根据当前数据重新计算。

#### 4.9.5 API Key 与 HUKS 的实现边界

当前 `AIKeyStore` 的实际做法是：`secretRef = ai-key:{accountId}:{providerId}`，明文 Key 通过 `HuksAesGcmCipher` 使用 HUKS 中的 AES-256-GCM 密钥加密，密文 JSON 文件写入 `filesDir/ai-secrets`，RDB 仅保存 `secret_ref`。`HuksAesGcmCipher` 使用随机 12 字节 nonce、AAD 和 GCM tag，密钥不出 HUKS，这个方向是正确的。

但是当前实现有一个不可忽略的安全缺口：HUKS 加密失败时会把明文 Key 放入 `memoryFallback`，并继续返回成功；这只能作为单测注入能力，不能作为生产降级。生产规则必须改成：

```text
HUKS 可用 + 加密成功 -> 写临时密文文件 -> fsync/关闭 -> 原子 rename -> 更新 secretRef
HUKS 不可用/失败 -> 不保存、不启用 Provider，返回 secureStorageUnavailable
```

不能在生产继续 `fallback_memory`，因为：

1. 进程内内存不是可验证的安全边界。
2. 进程崩溃转储、调试器或错误日志可能暴露 Key。
3. 用户看到“已保存”后，重启却无法恢复，会产生错误配置状态。
4. 多端互通不能把本地内存当作同步源。

还需补充：

| 场景 | 必须行为 |
| --- | --- |
| 更新 Key | 先写新密文并验证可解密，再替换旧文件；失败保留旧 Key |
| 删除 Key | 先禁用 Provider，再删密文，再清 `secret_ref`；任何步骤失败进入待清理队列 |
| Provider 改名 | `providerId` 不变，不能按显示名称生成新 alias |
| Provider 删除 | 删除 RDB 行、secret 文件、Runtime 引用和模型引用；需要确认弹窗 |
| 账号切换 | 清除旧账号解密出的临时变量和 Runtime，不删除新账号数据 |
| 密钥损坏 | 标记 `credentialCorrupted`，不自动把密文当明文读取；要求用户重新输入 |
| 备份/导出 | 只导出 Provider 展示信息和“已配置”状态，不导出 Key |
| 剪贴板/自动填充 | 默认禁止 API Key 复制、回显和系统自动填充；如产品必须支持需单独安全评审 |

Key 的读取只允许发生在 `AIProviderAdapter.send()` 或 `testProviderConnection()` 的最短生命周期，调用结束后释放局部变量，不缓存到 `RuntimeSnapshot`。Runtime 只能存 `secretRef`，不能存明文。

#### 4.9.6 Provider URL、请求和测试安全

当前 `OpenAICompatibleProviderAdapter` 发送 OpenAI-compatible JSON，并用 `Authorization: Bearer <apiKey>`。生产方案还需要补充以下规则：

1. 只允许 `https`；开发环境的 `http://127.0.0.1` 等例外必须由 build variant 显式开启。
2. 拒绝 `file://`、`data://`、自定义 scheme、内网 IP、回环地址和带用户名密码的 URL，避免 SSRF 和凭证泄露。
3. URL 规范化只允许追加固定 API path；不能把用户输入直接拼接到任意 endpoint。
4. 连接测试只发送最小探测请求，不发送用户 Prompt、医疗数据、历史聊天和本地文件。
5. 请求日志只记录 providerId、modelId、HTTP 状态、耗时、requestId；不记录 header、body 和响应全文。
6. Provider 请求超时、取消、429、5xx、证书失败分别映射为不同错误类型，UI 显示可执行建议。
7. `httpRequest.destroy()` 必须在 `finally` 执行；取消后不得再次发布 completed 事件。
8. 能力探测结果必须标记时间和模型版本；模型更新后自动失效，不能永久相信旧探测结果。

#### 4.9.7 本地模型文件的完整生命周期

当前 `LocalModelFileService` 只完成私有目录、`.gguf` 扩展名检查、文件存在/大小读取和删除约定，尚未实现下载、断点续传和 hash。生产流程建议如下：

```text
missing
  -> 创建 account/model 临时目录
  -> downloading
  -> 写 model.gguf.part + model.manifest.part
  -> 支持取消/断点/前台恢复
  -> 下载完成后计算 sha256/size
  -> 与服务端 manifest 比对
  -> 原子 rename model.gguf.part -> model.gguf
  -> RDB 标记 ready

任意失败 -> failed(errorCode)
取消 -> missing 或 paused，不能伪装 ready
文件损坏/版本不匹配 -> 删除文件并回到 missing
```

目录约定：

```text
filesDir/ai-models/<accountId>/<safeModelId>/
├── model.gguf
├── model.gguf.part
├── manifest.json
└── download.lock
```

必须额外考虑：

- 使用临时文件，避免应用崩溃后留下“看起来完整”的文件。
- `ready` 的前置条件是存在、扩展名正确、大小一致、SHA-256 一致、模型版本匹配。
- 下载前检查剩余空间，至少预留模型大小的 1.2 倍或产品设定的安全阈值。
- 设置页显示模型大小、已用空间、最后使用时间，并提供清理入口。
- 删除模型前检查场景绑定、Agent 和小任务引用；默认模型被删除时先要求重新选择。
- 大文件下载不能在 UI 主线程执行；按官方后台任务能力评估后台续传，不能自行假设进程被杀后任务仍然存在。
- GGUF 推理适配器必须明确设备/API Level、量化格式、上下文窗口、内存上限和取消语义；当前 `LocalModelAdapter` 只是占位，不能标记“支持本地推理”。

#### 4.9.8 Pro 远端覆盖层与本地用户修改

当前 `replaceRemotePro()` 会删除旧 `source=pro` 行，再按 bootstrap 场景模型生成 Provider、Model、Binding，并将服务端 API Key 转为 `secretRef`；Pro 小任务只在本地不存在相同 code 时插入。这是一个可用的第一版，但要避免远端刷新覆盖用户意图，必须建立字段级归属：

| 对象 | Pro 可更新 | 用户本地可更新 | 冲突策略 |
| --- | --- | --- | --- |
| Provider | 公司、展示名、官方 endpoint | 自定义 Provider、开关、Key | Pro 行与 localUser 行分离，不用名称去重 |
| Model | 能力、价格、官方 displayName | 启用、排序、图标、备注 | 以稳定 model identity 合并，展示字段远端优先，用户状态本地优先 |
| Scenario binding | Pro 默认、温度、最大 token、system provision | local 默认和手工排序 | 按 source 分层；Resolver 按用户选择/试用/Pro/本地种子优先级解析 |
| Small task | 服务 Prompt、工具列表、删除标记 | 用户自建 task、用户编辑 Prompt | `code` 冲突时不静默覆盖；新增 revision 或 `source` 分离 |
| Preferences | 不应远端覆盖 | defaultSource、allowNetwork、allowLocalModel | 永远本地优先，除非产品明确设计云同步 |

远端刷新应当是幂等的：相同 `revision + etag` 不重复重写 RDB；revision 下降时拒绝覆盖并记录 `remoteRevisionRollback`；模型被远端删除时不立即删除本地用户绑定，先标记 `unavailable`，让用户可以迁移场景。

#### 4.9.9 Resolver 的可用性判定与优先级

`AIConfigResolver` 当前会过滤禁用 Provider/Model、没有 endpoint 的远程模型、没有 ready 文件的 GGUF，并按 local/trial/pro/system 等来源构建 Runtime。生产实现必须把“存在”和“可用”分开：

```text
配置存在：RDB 有 provider/model/binding
配置可用：provider enabled + model enabled + binding enabled
凭证可用：remote provider 有 secretRef 且 HUKS 可解密
文件可用：gguf 有 ready metadata 且文件校验通过
能力可用：请求所需能力在 model capabilities 内
运行时可用：适配器已注册、设备资源足够、当前账号未失效
```

推荐解析顺序：

```text
1. 用户在当前场景明确选择的可用模型
2. localUser 默认
3. trial 默认（试用有效）
4. Pro 默认（allowNetwork=true 且来源允许）
5. localSeed/system 默认
6. 同来源按 position 的第一个可用模型
7. 无可用模型 -> noAvailableModel，不自动发送到未知 Provider
```

每个 resolved config 需要携带 `reason`，例如 `userSelected`、`localDefault`、`trialFallback`、`proDefault`、`capabilityFallback`，便于 UI 和日志解释“为什么选择这个模型”。

#### 4.9.10 草稿、保存和页面生命周期

当前 `AISettingsViewModel.markDirty()` 300ms 后调用 `saveDraft()`，而 `AIConfigRepository.saveDraft()` 不落盘，只发布 `runtimeSource=draft`。这个设计能实现实时预览，但必须加上以下防护：

1. 页面进入生成 `editSessionId`；草稿预览只能发布相同 session 的 Runtime。
2. 页面离开时取消 debounce timer，防止旧页面在新账号/新页面回写 Runtime。
3. `save()` 成功后才替换 `persistedSnapshot`；失败继续保留草稿并显示具体修复建议。
4. `refreshRemote()` 期间如果有未保存修改，必须弹出“保存/放弃/取消”，不能直接 `load()` 覆盖草稿。
5. Provider Key 输入成功写入 HUKS 后，草稿只保存 `secretRef`；当前输入框变更触发异步写入，需要增加 race guard，避免旧输入覆盖新输入。
6. 保存按钮应防重复点击，使用 `saving` 和命令级 request token；刷新、保存、删除不能同时修改同一快照。
7. 页面返回时有未保存修改必须拦截；系统杀进程后只恢复最后一次已提交快照，不能恢复明文 Prompt/Key 草稿。

#### 4.9.11 账号切换、鉴权失效和清理顺序

当前 `AccountSessionRuntime` 已发布当前账号并在切换/登出时通知清理，`AIConfigRepository.deleteAccountData()` 会清 Runtime、删 Key、删 RDB。推荐强制执行以下顺序：

```text
停止接受新 AI 请求
  -> cancel 所有 active request
  -> RuntimeSnapshotStore.invalidate(oldAccount)
  -> 从内存对象移除旧账号 snapshot / resolved config
  -> 删除旧账号 Key 文件和 memoryFallback
  -> 删除旧账号 RDB 行
  -> 删除旧账号模型临时文件/下载锁
  -> 发布 accountId=-1 或新账号
  -> 新账号 ensureSeeded + buildRuntime
```

401 时不应删除本地用户 Provider 配置和模型文件；只清除会话相关运行状态，等待重新登录后恢复同一账号快照。只有用户主动删除账号数据、撤销本地配置或卸载应用时，才执行不可逆物理删除。

#### 4.9.12 错误分类、恢复和 UI 文案

建议建立稳定错误码，而不是把 `${err}` 直接放到页面。至少覆盖：

| 错误码 | 触发 | 用户看到 | 是否自动重试 |
| --- | --- | --- | --- |
| `rdbUnavailable` | 数据库打开/迁移失败 | 本地配置暂时不可用，重试 | 可重试一次，随后人工入口 |
| `seedInvalid` | rawfile manifest/字段错误 | 默认配置损坏，请更新应用 | 不循环重试 |
| `secureStorageUnavailable` | HUKS 不可用 | 无法安全保存密钥 | 不自动降级明文 |
| `credentialMissing` | secretRef 无 Key | 请重新填写 API Key | 不自动重试 |
| `credentialCorrupted` | 解密失败 | API Key 已失效，请重新填写 | 不自动重试 |
| `remoteUnavailable` | 超时/DNS/5xx | 当前使用本地配置 | 按网络层策略有限重试 |
| `remoteUnauthorized` | 401/403 | 请重新登录或检查权限 | 401 交会话流程 |
| `providerRateLimited` | 429 | Provider 请求频繁，请稍后重试 | 遵循 Retry-After |
| `modelFileIncomplete` | 临时文件/校验失败 | 模型文件损坏，请重新下载 | 提供删除重下 |
| `capabilityDenied` | 模型不支持文本/工具/多模态 | 更换支持该能力的模型 | 不重试同模型 |
| `noAvailableModel` | Resolver 无可用配置 | 进入默认模型配置 | 不发起请求 |

诊断日志使用事件名和结构化字段，例如 `ai.refresh.degraded`、`ai.key.store.failed`、`ai.resolve.no_model`；错误详情通过 `ErrorLogger` 脱敏后记录。当前页面把 `${err}` 直接写入 `errorMessage` 和 `testResultMessage`，需要在生产 UI 前统一替换为本地化错误映射。

#### 4.9.13 性能、电量和容量预算

没有考虑到的运行约束也必须进入方案：

- 启动只读 `ai_account_meta` 和必要的默认绑定，设置页再按需加载完整列表，避免冷启动一次性解析所有 Prompt。
- Provider/Model 列表使用分页或增量渲染；不要在 UI 中频繁深拷贝超大 Prompt/工具配置。
- 远端 bootstrap 使用 revision/ETag，数据未变化时不重建全部 Runtime。
- 同一账号同时触发的多个 refresh 使用单飞 Promise；保存与刷新使用串行命令门。
- 大模型下载、SHA-256、能力探测要控制并发和 CPU 占用，前台显示进度，退后台按策略暂停。
- RDB 中不保存完整聊天记录、模型权重或重复的 Pro JSON；只保存可查询的配置字段和必要元数据。
- 监控 RDB 大小、Key 文件数、模型占用空间、失败下载数、远端 refresh 次数和平均耗时。

#### 4.9.14 测试设计

除了页面点击测试，还要加入以下测试矩阵：

```text
数据层：schema 首次创建、重复迁移、旧版本迁移、事务回滚、ResultSet 关闭
种子层：manifest 正常/缺失/哈希错误/未知字段/未知 scenario/引用不存在
安全层：HUKS 成功、HUKS 失败不得保存、密文损坏、Key 删除、账号隔离
合并层：local + pro、trial、revision 重复、revision 回退、远端删除、code 冲突
运行时：默认唯一、无 Key、无 endpoint、GGUF 未 ready、能力拒绝、取消、401
生命周期：冷启动、前后台、切号、登出、鉴权失效、进程中断、恢复
文件层：part 文件、断点、hash 不一致、空间不足、删除引用模型、并发下载
UI 层：未保存返回、刷新覆盖草稿、重复点击、错误重试、深色/浅色、长文本
```

每个测试都要验证“RDB 状态、密钥文件状态、Runtime 状态、页面状态”四者一致，不能只断言按钮文案。

#### 4.9.15 需要立即修复的现有实现问题

| 优先级 | 现有问题 | 代码位置 | 修复要求 |
| --- | --- | --- | --- |
| P0 | HUKS 失败回退明文内存 | `Core/AI/Infrastructure/AIKeyStore.ets` | 生产构造禁止 memory fallback；失败返回 `secureStorageUnavailable` |
| P0 | Key 文件写入非原子 | `AIKeyStore.put()` | 临时文件 + 完整写入 + 原子替换 + 崩溃恢复 |
| P0 | 页面错误直接展示 `${err}` | `AISettingsViewModel.ets` | 统一 ErrorLocalizer，过滤 Key/URL/body/stack |
| P1 | 本地快照多 SQL 写入无事务 | `AIConfigRdbStore.saveLocal()` | 使用数据库事务和 snapshot generation |
| P1 | Pro/local merge 只有 source/code 规则 | `AIConfigRdbStore.replaceRemotePro()` | 建立稳定 identity、字段归属和冲突策略 |
| P1 | GGUF 只检查扩展名/文件存在 | `LocalModelFileService.ets` | manifest、sha256、size、版本、临时文件和下载状态 |
| P1 | `AISettingsKVAdapter` 仍是占位 | `AISettingsKVAdapter.ets` | 明确 RDB 为唯一事实源；若不需要 KV，删除镜像接口，避免双写假象 |
| P1 | `LocalModelAdapter` 仍是占位 | `Core/AI/Runtime/LocalModelAdapter.ets` | 未选择真实推理方案前保持不可用并在 UI 标明 |
| P2 | Provider 连通性测试固定 `gpt-test` | `AISettingsViewModel.testProvider()` | 使用用户选择的模型或明确的探测模型，不硬编码业务模型 |
| P2 | API Key 更新在输入框每次变更时写入 | `AISettingsViewModel.updateProviderKey()` | 只在提交/确认时写入，避免频繁 HUKS 操作和旧值竞态 |
| P2 | 完整页面仍未按截图拆分 | `Projects/Features/AISettings/Presentation` | 按 4.8 页面规格补齐路由、组件、页面状态和验收 |

### 4.10 日志、测试与可观测性

日志只记录 `operation`、`accountHash`、`revision`、`requestId`、耗时、状态分类和错误码；禁止记录 API Key、完整 URL query、Authorization、Prompt、模型请求 body 和 Provider 测试 body。使用 `Foundation/Logging/Logger.ets` 与 `ErrorLogger.ets`，不要在页面直接 `hilog`。

## 5. 接口契约与数据模型

### 5.1 API 操作总表

| 操作 | 输入/输出 | 后端契约 | 鉴权/策略 | 错误/并发/缓存 | HarmonyOS 消费 | 证据 |
| --- | --- | --- | --- | --- | --- | --- |
| AI bootstrap | 输入 query `platform=harmonyos`、可选 `client_version`；输出 wrapped `data` | `GET /api/v1/ai/config/bootstrap/` | IsAuthenticated；AIConfigAPI 标记 auth、GET、ETag/cacheable | 允许缓存/ETag；非鉴权失败保留本地；401 触发失效 | `AIConfigRepository.refreshRemote` | `ai_config/urls.py`、`views.py:91`、`AIConfigAPI.ets:49` |
| Trial status | 输出 trial status | `GET /api/v1/ai/trial/status/` | IsAuthenticated | cacheable GET；可刷新 | Provider 试用卡片 | `urls.py`、`views.py`、`AIConfigAPI.ets:75` |
| Trial apply | body `{ note: string }`；输出申请 id/sequence/status | `POST /api/v1/ai/trial/apply/` | IsAuthenticated；当前服务端服务决定幂等/审核 | 客户端不可重复提交；ArkTS API 禁用重试 | 申请卡片 | `views.py`、`services.py`、`AIConfigAPI.ets:98` |
| Provider test | body `{ request_url, api_key, model }`；输出 `ok/reachable/message` | `POST /api/v1/ai/providers/test-connection/` | IsAuthenticated；当前 POST 不重试 | Key 只在内存短暂存在；不缓存 body | Provider 编辑页 | `views.py`、`AIConfigAPI.ets:124` |

### 5.2 API 字段

| 字段 | JSON 名称 | ArkTS 类型 | 必填 | 敏感 | 来源/消费 | 兼容规则 |
| --- | --- | --- | --- | --- | --- | --- |
| 平台 | `platform` | `string` | bootstrap query 是 | 否 | HarmonyOS API | 固定发送 `harmonyos` |
| 客户端版本 | `client_version` | `string` | 否 | 否 | bootstrap query | 未提供则省略 |
| 配置版本 | `revision` | `string` | bootstrap 输出 | 否 | RDB 账号元数据 | 版本变化才提交 runtime |
| 场景 | `scenarios` | `Record<string, ScenarioBundle>` | Pro 时可能为空 | 可能含敏感字段 | Resolver | 后端最终字段优先；当前 API 仍使用 `Object`，待强类型化 |
| 场景默认模型 | `default_model` | `string` | 场景块存在时 | 否 | DefaultModelResolver | 空字符串表示未配置 |
| 场景模型列表 | `models` | `ScenarioModelRow[]` | 场景块存在时 | row 可能含 endpoint/key | Resolver | 不直接暴露到 UI |
| 试用状态 | `status`/`trial_status` | `string` | 状态响应/非 Pro bootstrap | 否 | TrialState | `none/pending/rejected/expired/active` 需以后端枚举为准 |
| 是否 active | `is_active` 或 `isActive` | `boolean` | 状态响应 | 否 | 试用卡片/Resolver | 当前 iOS/Harmony 解码存在 snake/camel 差异，统一 Decoder 兼容 |
| 申请备注 | `note` | `string` | POST body | 可能含用户输入 | Trial apply | 不记录日志，不作为隐私同意字段 |
| API URL | `request_url` | `string` | Provider test body | 是/可能含 query secret | Provider test | 只在安全请求层短暂使用 |
| API Key | `api_key` | `string` | Provider test body | 是 | HUKS -> test use case | 禁止持久化、日志和 UI 回显 |
| 测试模型 | `model` | `string` | Provider test body | 否 | Provider test | 必须来自已启用文本模型或用户显式输入 |
| 测试结果 | `ok`/`reachable` | `boolean` | 响应可选 | 否 | 测试状态 | `reachable ?? ok ?? false` 与当前 Harmony 解码保持一致 |

### 5.3 场景模型字段

| 字段 | JSON 名称 | ArkTS 类型 | 必填 | 敏感 | 说明 |
| --- | --- | --- | --- | --- | --- |
| 模型名 | `name` | `string` | 是 | 否 | 普通模型为目录名；Agent 为 `agent-<bindingId>-<modelId>-<baseName>` |
| 展示名 | `display_name` | `string` | 是 | 否 | binding display name 优先，空时回退 catalog display name |
| 身份 | `identity` | `'model'|'agent'` | 是 | 否 | 决定列表和运行时分支 |
| 基座模型 | `baseModelName` | `string?` | Agent 必填 | 否 | Agent 关联的目录模型 |
| 厂商 | `company` | `string` | 是 | 否 | 用于 Provider 关联 |
| Endpoint | `endpoint` | `string` | 可能 | 是 | 远端请求地址；不得直接写 UI/日志 |
| API Key | `api_key` | `string` | 可能 | 是 | 服务端当前可能返回；Harmony 目标不得落普通存储 |
| 能力 | `supports_*`、`reasoning_controllable` | `boolean` | 否/有默认 | 否 | 文本、多模态、推理、工具、语音、生图等 |
| 价格档位 | `price_tier` | `number` 0..3 | 是 | 否 | UI badge 和成本提示 |
| 系统提示词 | `systemProvision` | `string` | 否 | 可能含业务敏感内容 | Agent/场景运行时消费 |
| 描述 | `briefDescription` | `string` | 否 | 否 | UI 摘要 |
| 工具场景 | `aiToolScenarios` | `string[]` | 否 | 否 | 工具能力引用 |
| 关联小任务 | `relatedTaskCodes` | `string[]` | 否 | 否 | 按 code 关联任务 |
| 默认 | `is_default` | `boolean` | 是 | 否 | 场景默认唯一 |
| 温度/Token | `temperature`/`max_tokens` | `number`/`number` | 否 | 否 | 运行参数，需范围校验 |

### 5.4 本地 RDB 领域模型

| 表/模型 | 核心字段 | 账号隔离 | 说明 |
| --- | --- | --- | --- |
| `ai_account_meta` | `account_id`, `schema_version`, `remote_revision`, `remote_etag`, `sync_state` | 主键 | 保存配置版本和刷新状态 |
| `ai_provider` | `id`, `account_id`, `company`, `request_url`, `secret_ref`, `is_enabled`, `source` | `(account_id,id)` | Key 只保存引用 |
| `ai_model` | `id`, `account_id`, `provider_id`, `name`, `display_name`, `identity`, `capabilities_json`, `local_filename` | `(account_id,id)` | 目录模型和 Agent |
| `ai_scenario_binding` | `scenario`, `model_id`, `is_default`, `position`, `temperature`, `max_tokens`, `system_provision`, `related_task_codes` | account scope | 场景模型关系 |
| `ai_small_task` | `code`, `name`, `brief`, `prompt`, `icon`, `tool_list_json`, `source`, `is_deleted` | `(account_id,code)` | 本地/Pro 合并输入 |
| `ai_model_file` | `model_id`, `path`, `size_bytes`, `sha256`, `download_state` | account scope | 只保存 metadata，不存二进制 |

### 5.5 后台管理关系和契约漂移

后台管理页面位于 `SparkService/backoffice-web/src/views/AIProvidersView.vue`、`AIModelsView.vue`、`AIScenarioModelsView.vue`、`AISmallTasksView.vue`、`AIScenariosView.vue`，API 聚合在 `backoffice-web/src/api/modules/ai.ts`。它们管理同一 `AIProviderKeyConfig`、`AIModelCatalog`、`AIScenarioModelBinding`、`SmallTask`，不能在 HarmonyOS 侧复制另一套字段或状态机。

当前必须关闭的漂移：`ai_config/tests.py` 仍断言 bootstrap 含 `api_keys`、`search_keys`、`tool_keys`、`all_models`、`user_info`、`trial`、`trial_model_policy`，而 `AIBootstrapConfigView` 当前实现的非 Pro/Pro payload 主要是 `revision`、`scenarios`、`smallTasks`、`trial_status`、`trial_message`。后端应先更新测试或恢复兼容字段，再标记 HarmonyOS bootstrap 联调通过。

## 6. iOS-HarmonyOS 功能对照矩阵

| 参考端能力/证据 | 可观察行为 | HarmonyOS 实现/证据 | 官方能力 | 本地示例 | 对齐状态 | 差异与处理 |
| --- | --- | --- | --- | --- | --- | --- |
| 厂商 Key 列表/编辑 | 用户维护 Provider URL、Key、启用和隐私同意 | `AIKeyStore`（禁明文回退）、`ProvidersPage`/`ProviderEditorPage`、确认写 Key | HUKS、ArkData RDB | `Core/AI/Infrastructure/AIKeyStore.ets` | 部分对齐 | UI 已拆页；真机 HUKS/联调前保持部分对齐 |
| Provider 连通性测试 | 选择模型并显示加载/成功/失败 | `ProviderEditorPage` 选已启用文本模型 + `AIConfigAPI.testProviderConnection` | HTTP request | News network commons | 部分对齐 | 已去掉硬编码 gpt-test；真机联调待完成 |
| Pro bootstrap | 启动/刷新获取场景和小任务 | `AIConfigAPI.bootstrap`、`AIConfigRepository.refreshRemote`、`AppBootstrapper` 已实现 | HTTP、ETag、Retry | `Core/Networking` 网络底座 | 部分对齐 | 已进入 RDB/Resolver；需补 ETag 条件请求和远端 revision 回退策略 |
| Pro 试用状态/申请 | 卡片展示五态，申请不可重复 | `AITrialCard` + `applyTrial` 禁重复提交 | HTTP、应用内通知边界 | `App/Notification` | 部分对齐 | UI 已接；真实联调待完成 |
| 模型目录 | 搜索、筛选、启用、编辑、删除模型/Agent | `ModelsPage`/`AddOnlineModelPage`/`EditModelPage`/`AgentEditorPage` + UseCases | ArkUI Navigation、RDB | Express RDB 示例仅借鉴事务边界 | 部分对齐 | 页面与门禁已落地；真机验收前保持部分对齐 |
| 在线/本地模型 | 添加 Provider 模型，下载/导入 GGUF | `LocalModelDownloadPage` 标明即将支持；`LocalModelFileService` 元数据校验 | File Kit、RDB、HUKS | Core File Kit 文档与本地 RDB 示例 | 部分对齐 | 不把下载当作本地推理完成 |
| 默认模型配置 | 按场景切换本地/Pro 并选择模型 | `DefaultModelPreferencesPage` + `scenarioSources` extras_json | ArkUI Picker/Navigation、RDB | `Projects/Features/Settings` 可借鉴路由边界 | 部分对齐 | 场景 UI/来源切换已接；真机联调待完成 |
| 场景绑定 | 默认唯一、排序、温度、Token、Prompt、工具和任务 | `ScenarioBindingPage`/`ToolSelectionPage`/`SmallTaskSelectionPage`；RDB 事务 | RDB transaction | Express RDB 事务示例 | 部分对齐 | 保存事务与引用检查已接；真机验收前保持部分对齐 |
| 小任务 | 本地任务 CRUD，按 code 合并 Pro | `SmallTasksPage`/`SmallTaskEditorPage`；删除前 `relatedTaskCodes` 引用检查 | RDB、Prompt 输入能力 | ChatInput Preferences 示例只借鉴轻量标记 | 部分对齐 | CRUD/引用阻止已接；OCR/语音仍标不可用 |
| 统一 Runtime | 业务只消费解析后的 AI 场景 | `AIConfigResolver`、`AIRuntimeSnapshotStore`、`AIRuntimeService` 已实现文本入口 | HTTP、File Kit、Promise | 项目现有 `Core/Networking` | 部分对齐 | Provider adapter 可用；GGUF adapter 仍是占位 |

## 7. 示例工程与官方文档参考结论

| 类型 | 标题/代码位置 | URL/绝对路径 | 可借鉴内容 | 禁止直接复制/版本注意事项 |
| --- | --- | --- | --- | --- |
| 官方 | HTTP 请求（ArkTS） | https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/http-request | 请求、响应、取消、权限设计依据 | 方法签名按目标 API 24/DevEco 复核 |
| 官方 | Universal Keystore Kit ArkTS API | https://developer.huawei.com/consumer/cn/doc/harmonyos-references/universal-keystore-arkts | API Key secretRef 的密钥保护 | 不得把密文/Key 写普通 Preferences 或日志 |
| 官方 | Preferences 数据持久化 | https://developer.huawei.com/consumer/cn/doc/HarmonyOS-Guides/data-persistence-by-preferences | 保存轻量 source、revision、页面偏好 | 不适合 Provider/Model 完整目录和 API Key |
| 官方 | ArkData/RDB | https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/data-persistence-by-arkdata | 事务、索引、账号 scope 结构化配置 | RDB 不存 GGUF、完整医疗正文或明文 Key |
| 官方 | 应用文件访问（Core File Kit） | https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/file-processing-apps-startup | 应用沙箱路径、fileUri、私有文件读写 | 模型下载仍需补断点、hash、原子替换和空间检查 |
| 官方 | 文档中心 / ArkData / Universal Keystore Kit 总入口 | https://developer.huawei.com/consumer/cn/doc/ | 按目标 API Level 复核最新 API 签名、权限和错误码 | 不能只依赖旧版示例或模型记忆 |
| 本地示例 | RDB 初始化、建表、索引、事务 | `/Users/hua/Documents/project/Reference/LookHealthClient/SparkClientHarmonyOS/开发详细技术文档/agc-template-market-harmonyos-demos-main/ShoppingTemplate/Express/commons/lib_foundation/src/main/ets/database/RdbHelper.ets`、`ParcelDB.ets` | `getRdbStore`、DDL/索引、事务封装、ResultSet 使用 | 示例使用 S1/未加密库和演示数据；本项目必须使用 S3/encrypt、参数绑定和账号 scope |
| 本地示例 | 独立网络 commons | `/Users/hua/Documents/project/Reference/LookHealthClient/SparkClientHarmonyOS/开发详细技术文档/agc-template-market-harmonyos-demos-main/HouseAndHomeTemplate/HomeDecoration/commons/network/src/main/ets/apis/HttpRequest.ets` | 网络模块边界和 API 类型拆分 | 不代表本项目 API 契约；必须接入本项目 `SupportBackend` |
| 本地示例 | Preferences 只保存轻量 UI 标记 | `/Users/hua/Documents/project/Reference/LookHealthClient/SparkClientHarmonyOS/开发详细技术文档/agc-template-market-harmonyos-demos-main/SocialTemplate/Community/components/chat_input/src/main/ets/components/ChatInputComponent.ets:53-68,247-252` | 首次提示/轻量开关的读取与 flush | 只能借鉴轻量标记；不能存 API Key、Token 或完整 AI 配置 |
| 项目现有 | Harmony 网络底座 | `SparkClientHarmonyOS/entry/src/main/ets/Core/Networking/` | 复用 `SupportBackend`、ResponseDecoder、ETag、Retry、Serial | 页面不能绕过组合根 |
| 项目现有 | 账号安全存储 | `SparkClientHarmonyOS/entry/src/main/ets/Foundation/Security/` | Token/设备凭证安全边界和错误分类 | API Key 需独立 alias/secretRef，不混用会话 Token |

## 8. 实施拆分与验收

| 阶段 | 目标文件/模块 | 依赖 | 实施结果 | 自动化测试 | 人工验收 |
| --- | --- | --- | --- | --- | --- |
| P0 契约收敛 | SparkService AI bootstrap、tests、`AIConfigAPI.ets` DTO | 后端唯一契约 | 明确新旧字段兼容策略，测试与视图一致 | 后端 bootstrap/trial/provider tests | 抓取 JSON 与 iOS/Harmony 解码一致 |
| P1 领域模型 | `Core/AI/Domain/*`、`Features/AISettings/Domain/*` | P0 | Provider/Model/Binding/Task/Trial/Scenario 强类型 | 编解码、snake/camel、默认唯一、任务 code 合并 | 账号快照字段完整 |
| P2 存储安全 | RDB、`AIKeyStore.ets`、模型文件 metadata | ArkData/HUKS | RDB 事务、账号 scope、secretRef、迁移 | 账号隔离、崩溃恢复、Key 不落盘测试 | 检查 RDB/Preferences/日志无明文 Key |
| P3 Repository/Resolver | `AISettingsRepository`、`AIConfigCenter`、`AIConfigResolver` | P1/P2 | 本地优先、Pro overlay、revision/ETag、runtime snapshot | 合并优先级、空 bundle、失效清理、并发单飞 | 断网仍可使用最近本地配置 |
| P4 Provider/模型 UI | Providers/Models 页面 | P1/P2/P3 | 截图对应页面、深色/浅色、保存/错误/空态 | UI 状态、表单校验、API 测试不重复提交 | 新增 Provider、模型启用、Key 缺失提示 |
| P5 默认/绑定/小任务 UI | Preferences/SmallTasks/Agent 页面 | P3 | 场景来源、默认唯一、小任务、Agent 关联 | 删除引用、Prompt、工具多选、默认切换 | 按截图逐页操作和返回 |
| P6 生命周期 | `AppBootstrapper`、账号运行时、通知/失效 | P3 | 启动预热、账号切换、退出清理、Pro 刷新 | generation、401、前后台、取消 | 旧账号数据不显示到新账号 |
| P7 业务接入 | `AIRuntimeService` 与聊天/医疗/工具调用方 | P3/P6 | 业务只依赖统一 Runtime | Provider、本地模型、Pro fallback | 各场景实际请求和失败恢复 |

### 8.1 页面验收

1. AI 设置首页可进入模型密钥、模型、默认模型配置和小任务；未实现功能显示明确不可用状态，不显示假数据。
2. Provider 编辑的 API Key 永远以密文输入或“已配置”状态展示；保存后只能读取 secretRef。
3. 添加在线模型校验系统名称、显示名称、Provider；能力探测显示进行中、成功、失败三态。
4. 模型列表的全部/模型/智能体筛选、搜索、启用、编辑、删除和排序可用；无 Key 的云模型不能启用。
5. 新建 Agent 必须完成名称、基座模型和系统 Prompt；可关联工具、小任务和场景绑定。
6. 默认模型配置支持 localKey/Pro source；无可用模型显示空态，不产生无效默认值。
7. 小任务新增/编辑/删除可用；删除有确认，引用中的任务不会静默造成悬挂 code。
8. 网络失败保留旧配置；保存失败保留草稿；401 清理当前账号运行时并回到会话流程。

### 8.2 编译与安全验收门

当前目标端已经存在本地配置、RDB/HUKS、Repository、Resolver、Runtime 和一个聚合 AI 设置页，但完整多页面 UI、下载引擎和生产安全收口尚未完成，不能据此标记本功能整体验收通过。实现阶段必须记录：目标 API Level、`assembleHap` 命令、执行日期、HAP 路径、错误/警告数、真机设备、RDB/HUKS 验证结果和接口联调结果。只有错误数为 0 才能通过编译门；编译通过不等于 API 联调、安全存储和页面验收通过。

## 9. 风险与待确认项

| 编号 | 风险/待确认项 | 影响模块 | 证据 | 依赖方 | 关闭条件 |
| --- | --- | --- | --- | --- | --- |
| AI-01 | bootstrap 当前实现与测试断言字段不一致 | API、Resolver、Pro | `ai_config/views.py`、`tests.py` | SparkService | 后端统一响应 schema，更新测试并完成真实 JSON 联调 |
| AI-02 | 本地快照和 Pro overlay 已实现，但整体 RDB 写入仍需事务化和版本恢复 | 启动、设置、Runtime | `AIConfigRepository.ets`、`AIConfigRdbStore.ets` | ArkData/数据库迁移 | 远端 DTO 原子落盘、崩溃恢复和 generation 测试通过 |
| AI-03 | HUKS alias、删除和账号清理已有实现，但 HUKS 失败会回退明文内存 | Provider、安全 | `AIKeyStore.ets`、`HuksAesGcmCipher.ets` | 安全模块 | 移除生产 memory fallback、原子密文写入、Key 不落普通存储 |
| AI-04 | AISettings 聚合页面已有，但截图对应的 Provider/Model/Agent/Task 子页面未完成 | 全部 UI | `Projects/Features/AISettings/Presentation/AISettingsPage.ets` | ArkUI Navigation | 页面按 iOS 功能矩阵逐项实现 |
| AI-05 | local/Pro Resolver 已存在，远端冲突、revision 回退和用户字段归属仍不完整 | 默认模型、Runtime | `Core/AI/Application/AIConfigResolver.ets` | AI 领域层/后端契约 | 通过优先级、空模型、Pro overlay、冲突和回退测试 |
| AI-06 | 本地模型文件服务只有路径/扩展名/存在性检查，GGUF 推理适配器是占位 | 本地模型 | `LocalModelFileService.ets`、`LocalModelAdapter.ets` | 平台/第三方推理方案 | 明确支持设备、模型格式、hash、内存和取消后再开放 |
| AI-07 | 后端是否继续下发明文 `api_key` 未收敛 | API、安全 | `views.py` 构建模型行 | SparkService | 改为安全授权引用或建立明确短暂内存消费契约 |
| AI-08 | 小任务删除后的 Agent/绑定引用清理未定义 | 小任务、Agent | iOS 文档已标风险，Harmony 未实现 | 产品/后端 | 事务清理或阻断删除，并有测试 |
| AI-09 | 后端场景列表与 iOS `AIScenario` 演进不同步 | 默认配置、绑定 | `models.py` choices、iOS `AIScenario.swift` | SparkService + iOS/Harmony | 维护共享场景契约和版本兼容测试 |
| AI-10 | UI 设计截图为深色卡片，但 HarmonyOS 当前没有对应页面 | 视觉、可用性 | iOS UI 文档/截图、Harmony 目录 | 设计与客户端 | 完成深色/浅色、可访问性、长文本和旋转验收 |
