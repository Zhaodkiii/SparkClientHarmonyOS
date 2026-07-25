# AI 模型厂商列表对齐 iOS：Pro Overlay 不进入密钥列表修复工单

> 工单类型：HarmonyOS 对标 iOS 的 AI 数据来源、持久化边界和页面读模型修复工单。目标是让鸿蒙“模型密钥/模型厂商”列表与 iOS 的业务语义一致。默认先完成文档、代码审计、测试和验收契约，再实现工程修改；不得通过 UI 临时隐藏来掩盖错误的数据分层。

## 1. 工单目标

当前鸿蒙“模型厂商”列表同时显示：

```text
seed:AI302 / seed:OPENAI / seed:...
pro:DEEPSEEK / pro:DOUBAO / pro:...
```

iOS 的同一页面只显示本地持久化的系统 Provider 和用户自定义 Provider；Pro 模型通过运行时 `proOverlay` 进入默认模型配置和业务消费，不进入可编辑的模型密钥厂商列表。

本工单要求：

1. 鸿蒙“模型密钥/模型厂商”列表与 iOS 使用相同的数据来源语义。
2. Pro bootstrap 不再把 Pro Provider/Model 写入模型密钥页读取的本地 Provider 目录。
3. 这是全新项目，首次设计就必须把 Pro Overlay 与本地 Provider/Model 目录分开，不引入历史数据迁移和旧版本兼容逻辑。
4. Pro 配置仍可进入默认模型配置、场景 bundle 和 Runtime 统一消费。
5. 修复必须落在 Repository/Store/Resolver/Presentation Model 边界，不能只在 ArkUI 页面中添加 `filter`。

## 2. 两端真实实现对比

### 2.1 iOS 数据流

```text
APIKeys.json + 用户新增 Provider
  -> Core Data AIProviderEntity
  -> AISettingsSnapshot.apiKeys
  -> APIKeysSettingsView.sortedProviders
  -> 模型密钥/厂商列表

SparkService bootstrap / Pro remote patch
  -> AIRuntimeConfigStore.proOverlay（内存）
  -> ScenarioPolicyResolver / AIConfigCenter
  -> 默认模型配置、场景消费、Runtime
```

iOS 事实文件：

```text
/Users/hua/Documents/project/Reference/LookHealthClient/SparkClient/SparkClient/Projects/Features/AISettings/Presentation/Providers/APIKeysSettingsView.swift
/Users/hua/Documents/project/Reference/LookHealthClient/SparkClient/SparkClient/Projects/Features/AISettings/Presentation/Root/AISettingsViewModel.swift
/Users/hua/Documents/project/Reference/LookHealthClient/SparkClient/SparkClient/Projects/Core/AI/AIConfigCenter.swift
/Users/hua/Documents/project/Reference/LookHealthClient/SparkClient/SparkClient/Projects/Core/AI/AIRuntimeConfigStore.swift
/Users/hua/Documents/project/Reference/LookHealthClient/SparkClient/SparkClient/Projects/Features/AISettings/Infrastructure/DefaultAISettingsRepository.swift
```

模型密钥列表的关键过滤：

```swift
let filtered = viewModel.snapshot.apiKeys.filter {
    AIProviderAdapterRegistry.adapter(for: $0.providerID).isLocal == false
}
```

这里的 `snapshot.apiKeys` 是本地仓储快照，不是 `effectiveBundles`，也不是 Pro overlay。Pro overlay 即使存在于 Runtime，也不会成为 `APIKeysSettingsView` 的 Provider 行。

### 2.2 鸿蒙当前数据流

```text
APIKeys.json / 本地种子
  -> RDB ai_provider(source=localSeed)

SparkService bootstrap
  -> AIConfigRdbStore.replaceRemotePro()
  -> RDB ai_provider(source=pro)
  -> RDB ai_model(source=pro)
  -> AIConfigSnapshot.providers/models
  -> ProviderModelCatalogService.proCredentials()
  -> 模型密钥/厂商列表
```

鸿蒙事实文件：

```text
/Users/hua/Documents/project/Reference/LookHealthClient/SparkClientHarmonyOS/entry/src/main/ets/Core/AI/Infrastructure/AIConfigRdbStore.ets
/Users/hua/Documents/project/Reference/LookHealthClient/SparkClientHarmonyOS/entry/src/main/ets/Core/AI/Infrastructure/AIConfigStore.ets
/Users/hua/Documents/project/Reference/LookHealthClient/SparkClientHarmonyOS/entry/src/main/ets/Projects/Features/AISettings/Application/ProviderModelCatalogService.ets
/Users/hua/Documents/project/Reference/LookHealthClient/SparkClientHarmonyOS/entry/src/main/ets/Projects/Features/AISettings/Presentation/Providers/ProvidersPage.ets
```

当前 `replaceRemotePro()` 会生成：

```text
providerId = pro:<normalizedCompany>
source = pro
kind = api
```

之后 `proCredentials()` 只排除本地 GGUF Provider，仍会把 `source='pro'` 返回给模型密钥页。因此当前差距是数据进入了错误的持久化/展示边界，而不只是页面过滤条件错误。

## 3. 问题定性与影响

| 严重度 | 问题 | 业务影响 |
| --- | --- | --- |
| P0 | Pro Provider 写入 `ai_provider`，而模型密钥页从合并快照读取 | 鸿蒙展示 iOS 不展示的 Pro 厂商，且用户可能进入错误编辑入口 |
| P0 | Pro 模型写入 `ai_model` 并与本地模型目录混合 | 删除、启用、编辑和场景绑定可能误操作远端服务端配置 |
| P0 | 刷新时 Pro 目录和本地用户目录使用相同 Store 替换链路 | Pro refresh 失败、空 payload 或账号切换可能影响本地配置可见性 |
| P1 | `source` 字符串承担数据来源、编辑权限、展示分组多个职责 | `localSeed/localUser/pro/trial/Service` 判断漂移 |
| P1 | `proCredentials()` 名称容易误导 | 方法名像“只返回 Pro credential”，实际返回 seed + custom + pro |
| P1 | Pro Provider 生成了本地目录 HUKS secretRef | 数据边界不清晰，可能让 Pro 凭证进入可编辑本地 Key 目录 |
| P2 | 页面来源标签和厂商本地化跟随混合快照 | 用户无法判断“本地 Key 厂商”和“Pro 场景模型”的区别 |

## 4. 目标业务边界

### 4.1 模型密钥/模型厂商列表

模型密钥页只展示下列数据：

```text
LocalProviderCredentialCatalog
├─ source = localSeed：系统种子 API Provider
├─ source = custom/localUser：用户新增或编辑的 API Provider
├─ kind = api
├─ providerId 不是 local:device
└─ 允许编辑 endpoint、API Key、隐私政策、启用状态
```

不得展示：

- `source='pro'` 的 Provider。
- `source='trial'` 的远端 Provider。
- `kind='local'` 或 `providerId=local:device` 的本地模型 Provider。
- 只有场景 bundle 中存在、但本地 Provider 目录没有对应 Key 的远端模型供应商。

### 4.2 Pro 模型与 Pro 场景配置

Pro 数据进入独立的远端运行时覆盖：

```text
ProBootstrapSnapshot / ProOverlay
├─ revision / etag
├─ scenarios[]
│  ├─ scenario
│  ├─ defaultModel
│  └─ models[]
├─ trialStatus
└─ smallTasks[]
```

Pro 数据的消费入口：

```text
AIConfigRepository.refreshRemote
  -> ProOverlayStore / AIRuntimeSnapshotStore
  -> AIConfigResolver
  -> DefaultModelPreferencesPage
  -> AIResolvedConfig
  -> AIRuntimeService
```

Pro 数据不应该成为模型密钥编辑页的 Provider 行。若产品需要展示 Pro Provider 状态，应在默认模型/试用卡片中以只读状态展示，不能复用“编辑 API Key”入口。

### 4.3 本地模型

本地模型是设备文件和本地能力目录，不是 API Key Provider：

```text
LocalModelCatalog
├─ modelId
├─ modelType = gguf
├─ fileId/pathRef
├─ installState
├─ manifest/capabilities
├─ isEnabled
└─ local:device Provider 标识
```

本地模型可进入：

- 模型目录的“本地”筛选。
- 本地模型下载/导入/校验/安装页。
- 默认模型配置的“本地模型”来源。

本地模型不能进入：

- 模型密钥列表。
- Pro Provider endpoint/API Key 编辑页。
- Pro 试用申请卡片。

## 5. 修复设计

### 5.1 Store 分层：Pro 不再写入本地模型密钥目录

目标调整：

```text
本地 RDB
  ├─ ai_provider：仅本地 seed/custom API Provider
  ├─ ai_model：本地模型、用户添加的模型、Agent、本地绑定
  ├─ ai_model_file：本地模型文件 metadata
  └─ ai_preferences：用户 source/default 选择

Pro Runtime Store / Pro Overlay Store
  ├─ ProProvider/Model/ScenarioBundle 内存快照
  ├─ revision/etag
  ├─ trialStatus
  └─ Pro smallTasks
```

全新项目不允许将 Pro 行写入本地 `ai_provider`/`ai_model` 目录。Pro 如需离线恢复，使用独立的 Pro Overlay Store 或独立远端缓存命名空间，并禁止 `loadLocalSnapshot()`、`localCredentialProviders()` 和模型密钥页读取该命名空间：

```text
推荐优先级：
1. Pro overlay 保存在 Runtime 内存，并保留 revision/etag 元数据。
2. 需要离线恢复时，使用独立 `ai_pro_overlay` 表/记录，带 `account_id + revision`。
3. 本地 `ai_provider`/`ai_model` 表从 schema 层就不承载 `source='pro'` 行。
```

### 5.2 Repository 接口调整

当前混合快照接口需要拆出语义明确的读取方法：

```text
loadLocalCredentialCatalog(accountId)
  -> LocalProviderCredential[]

loadLocalModelCatalog(accountId)
  -> LocalModel[]

loadProOverlay(accountId)
  -> ProOverlay?              # Runtime/独立远端缓存

refreshProOverlay(accountId, clientVersion)
  -> RefreshResult<ProOverlay>

saveLocalCredential(providerDraft)
  -> 只写本地 seed/custom Provider + HUKS secretRef
```

页面不得调用：

```text
loadMergedSnapshot().providers  # 禁止作为模型密钥页数据源
```

页面应调用：

```text
ProviderCatalogService.localCredentials(snapshot)
```

### 5.3 `ProviderModelCatalogService` 调整

当前方法名 `proCredentials()` 实际返回 seed + custom + pro，必须改为语义准确的接口：

```text
localCredentialProviders(snapshot)
  -> kind=api
  -> source in localSeed/localUser/custom/system
  -> 排除 local:device
  -> 排除 pro/trial/Service

proOverlayProviders(overlay)
  -> 只用于 Pro 场景/状态展示
  -> 不进入模型密钥编辑列表

localModels(snapshot)
  -> kind=local / modelType=gguf / local:device

visibleRuntimeModels(localSnapshot, proOverlay, scenario)
  -> 交给 Resolver 处理 local/pro/auto
```

模型密钥列表的最终规则必须集中在应用服务中：

```text
isLocalCredentialProvider(provider):
  provider.kind == 'api'
  && provider.source not in ['pro', 'trial', 'Service']
  && !isLocalProviderId(provider.id)
  && !isLocalCompany(provider.company)
```

这里的 `isLocalCredentialProvider` 中“local”表示“本地持久化的远端 API 凭证目录”，不是“本地 GGUF 模型”。建议改名为 `isEditableApiCredentialProvider`，避免语义混淆。

### 5.4 `AIConfigRdbStore.replaceRemotePro()` 调整

目标流程：

```text
读取远端 bootstrap
  -> 解码并校验
  -> 写入新的 Pro Runtime Overlay
  -> 写入 ProOverlayStore / 独立远端缓存
  -> 不触碰本地 ai_provider/ai_model
  -> Resolver 合并 local snapshot + pro overlay
  -> 发布 runtime generation
```

### 5.5 Pro Key 的处理边界

Pro bootstrap 中如果携带 `api_key`：

- 不得写入模型密钥列表的本地 Provider 目录。
- 不得写入本地用户可编辑 Provider 的 `secretRef`。
- 只允许作为 Runtime 使用所需的短期凭证，或写入明确的 Pro overlay 安全缓存。
- 如果当前 Runtime Adapter 需要 HUKS，使用命名空间 `ai-pro:<accountId>:<providerId>`，与用户本地 Key 的 `ai-key:<accountId>:<providerId>` 区分。
- Pro overlay 失效/过期/账号切换时清理 Pro secretRef，不清理本地用户 API Key。

## 6. 全新项目初始化约束

本项目没有历史版本和线上旧数据，schema、Store、Repository、Resolver 和页面可以直接按目标边界落地：

1. `ai_provider` 只允许本地 seed/custom API Provider；schema 注释和 Store 接口明确禁止写入 `source='pro'`。
2. `ai_model` 只保存本地模型、用户添加的在线模型和 Agent；Pro 模型只进入 Pro Overlay 或独立远端缓存。
3. `AIConfigRdbStore.saveLocal()` 的输入类型只接受本地目录模型，不接受 `ProBootstrapSnapshot`。
4. `replaceRemotePro()` 改名为 `publishProOverlay()` 或等价方法，禁止执行本地 Provider/Model 删除和插入 SQL。
5. `ProviderModelCatalogService` 从接口层返回 `LocalCredentialProviderPresentation`，不再设计“混合快照过滤后展示”的默认路径。
6. 初始 seed 校验直接拒绝 `source='pro'`、`source='trial'` 或 `id` 以 `pro:` 开头的 Provider/Model，防止 Pro 数据误灌本地库。
7. 新建测试数据库时只验证本地 seed/custom、本地模型和独立 Pro Overlay 三类数据，不创建迁移 fixture。
8. HUKS 从第一版就分 namespace：本地用户 API Key 和 Pro 运行时凭证不能共用 alias 规则。

## 7. 页面与路由调整

### 7.1 模型密钥页

```text
模型密钥
├─ 本地持久化 API Provider
│  ├─ 系统种子 Provider
│  └─ 用户自定义 Provider
└─ + 新增自定义 Provider
```

不得显示：

```text
Pro Provider
Pro 远端模型
本地 GGUF Provider
```

如果需要向用户提示 Pro 已可用，只显示只读状态卡：

```text
Pro 模型已由账号服务提供
请在“默认模型配置”中选择使用场景
```

点击该卡片进入 `DefaultModelPreferencesPage`，不能进入 `ProviderEditorPage`。

### 7.2 模型页

模型页可以同时展示本地和 Pro 模型，但必须使用来源分组/筛选：

```text
全部 | 本地模型 | Pro 模型 | 智能体
```

规则：

- Pro 模型只读，不能修改远端 name、endpoint、API Key 和服务端能力。
- 本地模型进入安装/导入/编辑本地能力流程。
- 用户自定义在线模型可以编辑，但仍属于本地目录配置，不等于 Pro overlay。
- Pro 刷新后列表更新来源摘要，不将 Pro Provider 复制成可编辑厂商行。

## 8. 日志与可观测性

新增/调整以下事件：

| 事件 | 记录内容 |
| --- | --- |
| `ai.provider_catalog.local.begin` | account scope、local provider count |
| `ai.provider_catalog.local.ok` | seed/custom count、filtered pro count、local model count |
| `ai.pro_overlay.refresh.begin` | old revision、account scope、platform、client version |
| `ai.pro_overlay.refresh.ok` | new revision、scenario count、Pro model count、runtime generation |
| `ai.pro_overlay.not_persisted_to_local_catalog` | Pro provider/model count、destination overlay |
| `ai.provider_catalog.source_mismatch` | providerId、source、expected catalog |

禁止记录：API Key、Bearer Token、完整 secretRef、Prompt、完整 endpoint query 和远端原始响应 body。

## 9. 修改位置与任务拆分

| 编号 | 优先级 | 修改任务 | 目标文件 |
| --- | --- | --- | --- |
| AI-PROVIDER-01 | P0 | 新增本地模型密钥目录查询，只返回 seed/custom 本地 API Provider | `ProviderModelCatalogService.ets` |
| AI-PROVIDER-02 | P0 | 模型密钥页改用本地 credential catalog，不读 merged providers | `ProvidersPage.ets`、ViewModel |
| AI-PROVIDER-03 | P0 | Pro bootstrap 不再写入本地 Provider/Model 目录 | `AIConfigRdbStore.ets`、`AIConfigRepository.ets` |
| AI-PROVIDER-04 | P0 | Pro overlay 独立存储/内存消费，Resolver 继续支持场景合并 | `AIConfigStore.ets`、`AIConfigResolver.ets`、Runtime Store |
| AI-PROVIDER-05 | P0 | 首次 schema/seed 直接禁止 Pro 行写入本地目录 | `AIConfigSchema.ets`、`AIConfigRdbStore.ets` |
| AI-PROVIDER-06 | P1 | 重命名 `proCredentials()`，拆出 local credential / Pro overlay provider 两种接口 | `ProviderModelCatalogService.ets` |
| AI-PROVIDER-07 | P1 | 模型页增加本地/Pro 来源筛选和只读权限策略 | `ModelsPage.ets`、`AIModelPresentation` |
| AI-PROVIDER-08 | P1 | 增加 source mismatch 和 no-Pro-in-local-catalog 日志 | `AIConfigFlowLog.ets`、Repository |
| AI-PROVIDER-09 | P1 | 补齐 iOS/HarmonyOS 对照测试、schema/seed 边界测试 | AI 配置测试目录 |

## 10. 验收矩阵

| 场景 | 模型密钥页 | 模型页 | 默认模型/Runtime |
| --- | --- | --- | --- |
| 只有本地 seed Provider | 显示 | 显示可用模型 | 可按本地配置消费 |
| 用户新增 custom Provider | 显示并可编辑 | 显示其模型 | 可参与本地目录解析 |
| bootstrap 返回 Pro Provider | 不显示 | 显示 Pro 模型，只读 | 可进入场景 bundle 和消费 |
| Pro refresh 失败 | 保持本地 Provider | 保留上次 Pro 或显示降级 | 本地 Runtime 继续可用 |
| Pro 返回空 scenarios | 不显示 Pro Provider | 不删除本地模型 | 保留旧有效 Pro/本地策略 |
| 本地 GGUF 已安装 | 不显示 | 显示本地模型 | `local` 可消费，能力满足才可选 |
| Pro Key 缺失 | 不显示 Pro Provider 行 | Pro 模型显示 configureKey/unavailable | 不参与 Pro 消费 |
| 新建数据库 | 不存在 Pro Provider 行 | Pro 只存在 overlay | Resolver 可正常合并 |
| 账号切换 | 只显示新账号本地 Provider | 新账号本地 + Pro | 旧账号 Pro overlay 不回写 |

## 11. 验收用例

### 11.1 数据源验证

- 只写入本地 seed/custom Provider，模型密钥页显示这些 Provider。
- bootstrap 返回 `DEEPSEEK/DOUBAO` 等 Pro Provider 后，RDB 本地 Provider 目录不新增 `pro:*` 行。
- Pro overlay 存在时，默认模型配置可以看到 Pro 模型并选择场景。
- Pro overlay 失效时，模型密钥页仍只显示本地 seed/custom Provider。
- 刷新前后本地用户 Provider 的 ID、Key 引用、名称和启用状态不变化。

### 11.2 页面验证

- 模型密钥页看不到 `pro:DEEPSEEK`、`pro:DOUBAO` 等 Provider。
- 模型密钥页看不到本地 GGUF Provider。
- 模型页可以按“本地模型/Pro 模型”筛选；Pro 行显示只读来源，不出现 API Key 编辑入口。
- 点击 Pro 状态卡进入默认模型配置，不进入 Provider 编辑页。
- Pro 模型列表刷新后不改变本地 Provider 列表数量。

### 11.3 全新数据库验证

- 首次创建数据库后，`ai_provider` 和 `ai_model` 中不存在 `source='pro'`、`source='trial'` 或 `pro:*` 行。
- seed 导入遇到 Pro 来源字段直接拒绝并记录校验错误，不得静默写入本地目录。
- Pro bootstrap 成功后只发布 Overlay，不执行本地 Provider/Model 插入 SQL。
- 本地用户 API Key 和 Pro 运行时凭证使用不同 HUKS namespace。
- 新建测试数据库重复执行 seed 不产生重复本地 Provider，不需要迁移历史数据。

### 11.4 账号与错误验证

- A 账号的 Pro overlay 不会出现在 B 账号模型密钥页。
- 401/403、断网、空 payload、DTO 解码失败都不会把本地 Provider 列表清空。
- 页面加载失败显示错误/重试，不显示“暂无厂商”误导空态。
- 日志能看到本地目录与 Pro overlay 的数量和 revision，但不包含 API Key、Token 或原始远端 body。

## 12. 完成定义

- [x] 鸿蒙模型密钥页的数据源与 iOS 一致，只读本地 seed/custom API Provider。
- [x] Pro bootstrap 不再写入模型密钥页读取的本地 Provider/Model 目录。
- [x] Pro 模型仍可通过 overlay、场景配置和 Resolver 统一消费。
- [x] 全新 schema/seed 从第一版就禁止 `source=pro/trial/Service` 数据进入本地 Provider/Model 目录。
- [x] 本地模型、Pro 模型、用户自定义在线模型的编辑权限和页面入口分离。
- [x] RDB、HUKS、Runtime、账号切换和错误回退均通过测试。
- [ ] 真机截图确认鸿蒙“模型密钥”列表与 iOS 不再显示 Pro 厂商。
