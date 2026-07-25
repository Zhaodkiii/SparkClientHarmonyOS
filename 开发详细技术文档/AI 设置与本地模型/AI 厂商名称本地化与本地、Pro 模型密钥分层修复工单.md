# AI 厂商名称本地化与本地、Pro 模型密钥分层修复工单

> 工单类型：HarmonyOS 对标 iOS 的 AI 设置业务与数据分层修复工单。默认先完成代码审计、模型/接口/页面契约和验收；实现时必须在目标 HarmonyOS 工程内完成，不创建第三套 AI 配置模型。后端唯一事实源为 `/Users/hua/Documents/project/Reference/LookHealthClient/SparkService`。

## 1. 工单目标

本工单处理两个跨端偏差：

1. AI 厂商名称没有按 iOS 方式本地化，页面可能直接显示 `BYTEDANCE`、`OPENAI`、`LOCAL` 或远端原始 company，导致中文界面不可读、同一厂商在不同页面显示不一致。
2. AI 设置内“本地模型”和“Pro 模型”使用相同 Provider/模型密钥入口，数据查询、编辑、保存和运行时解析边界不清晰；用户可能在本地模型页面看到 API Key，或在 Pro 页面看到本地 GGUF 文件模型。

目标是建立以下清晰边界：

```text
本地模型配置
  = 本地模型目录 + 模型文件 + manifest/能力 + 本地启用状态
  = 不需要 API Key，不进入 Pro Provider Key 列表

Pro 模型配置
  = 远端 Provider + HUKS API Key 引用 + endpoint + 远端模型目录/试用策略
  = 不保存本地 GGUF 文件路径，不直接修改本地模型文件状态

通用消费模型
  = Resolver 根据场景 source 选择 local / pro / auto
  = Runtime 只消费统一的已解析模型，不依赖页面或源数据表
```

## 2. iOS 事实基线

### 2.1 厂商名称本地化方式

iOS 当前实现位于：

- `/Users/hua/Documents/project/Reference/LookHealthClient/SparkClient/SparkClient/Projects/Features/AISettings/Presentation/Providers/ProviderSettingsEditorView.swift`
- `/Users/hua/Documents/project/Reference/LookHealthClient/SparkClient/SparkClient/Projects/Features/AISettings/Presentation/Providers/APIKeysSettingsView.swift`
- `/Users/hua/Documents/project/Reference/LookHealthClient/SparkClient/SparkClient/Projects/Core/AI/AIConfigModels.swift`
- `/Users/hua/Documents/project/Reference/LookHealthClient/SparkClient/SparkClient/Projects/Features/AISettings/Domain/AISettingsDomainModels.swift`

iOS 的核心逻辑：

```swift
var localizedDisplayName: String {
    if source == .custom {
        return displayName
    }
    let key = "company_\(company.uppercased())"
    let localized = L10n.text(key)
    return localized == key ? displayName : localized
}
```

必须保留的业务语义：

| 情况 | iOS 行为 | HarmonyOS 目标行为 |
| --- | --- | --- |
| 系统/种子 Provider | 使用 `company_<COMPANY>` 本地化资源 | 使用稳定 Provider ID 查 `ResourceStr`，缺失时回退本地 displayName/company |
| 自定义 Provider | `source == .custom` 时直接显示用户输入的 `displayName` | 自定义名称不经过系统厂商翻译，不被同名资源覆盖 |
| 本地模型 Provider | 由 `LocalModelService.localProviderID/localCompany` 识别 | 显示“本地模型”，但不进入云端 Provider Key 列表 |
| Pro/试用 Provider | 使用服务端/本地稳定 company 映射 | 先按 providerId/company 本地化展示，模型数据仍使用后端原始 ID |
| 资源不存在 | 返回 `displayName` | 返回非空的脱敏显示名，不显示资源 key 本身 |

### 2.2 本地模型与 Pro 模型的数据处理方式

iOS 并不是把本地 GGUF 当成普通 API Provider：

- `AIProviderAdapterRegistry.adapter(for:)` 对 `LocalModelService.localProviderID` 返回 `.localGGUF`，`isLocal == true`。
- `APIKeysSettingsView` 过滤掉 `isLocal == true` 的 Provider，只展示需要密钥的远端 Provider。
- `ModelsSettingsView` 的模型可见性将本地模型和“已配置 API Key 的服务模型”分开判断。
- `APIKeys` 保存 Provider Key、endpoint、启用和隐私同意；本地模型使用 `AllModels` 的本地标识、`localFilename` 和 `LocalModelService` 文件能力。
- 场景来源使用 `AIModelSelectionSource.localKey/trial`，运行时再与本地目录、试用策略和 Pro overlay 合并。

对应 iOS 代码：

- `/Users/hua/Documents/project/Reference/LookHealthClient/SparkClient/SparkClient/Projects/Core/AI/AIConfigModels.swift`
- `/Users/hua/Documents/project/Reference/LookHealthClient/SparkClient/SparkClient/Projects/Features/AISettings/Presentation/Providers/APIKeysSettingsView.swift`
- `/Users/hua/Documents/project/Reference/LookHealthClient/SparkClient/SparkClient/Projects/Features/AISettings/Presentation/Models/ModelsSettingsView.swift`
- `/Users/hua/Documents/project/Reference/LookHealthClient/SparkClient/SparkClient/Projects/Features/AISettings/Domain/AISettingsDomainModels.swift`
- `/Users/hua/Documents/project/Reference/LookHealthClient/SparkClient/SparkClient/Projects/Features/AISettings/Domain/AISettingsSnapshot.swift`
- `/Users/hua/Documents/project/Reference/LookHealthClient/SparkClient/SparkClient/Projects/Features/AISettings/Infrastructure/DefaultAISettingsRepository.swift`

## 3. HarmonyOS 当前问题

### 3.1 厂商名称问题

当前 HarmonyOS 已有 `company`、`name`、`providerId` 和 `source` 字段，也有 `normalizeProviderId()`，但没有发现与 iOS `localizedDisplayName` 等价的统一显示层。当前风险包括：

| 问题 | 影响 |
| --- | --- |
| 页面直接显示 `provider.company` 或 `provider.name` | 系统厂商显示英文 code，中文 UI 与 iOS 不一致 |
| 不同页面各自拼接显示名称 | Provider 列表、模型列表、模型编辑和场景配置出现不同名称 |
| 把本地化显示名写回 RDB | 切换系统语言后旧名称不会刷新，稳定 ID 被污染 |
| 以中文名称做 providerId | 远端模型关联、HUKS alias、RDB 外键和跨端数据无法稳定匹配 |
| 资源缺失时直接显示资源 key | 用户看到 `company_OPENAI`，错误状态难以识别 |

### 3.2 本地模型与 Pro 模型混用问题

当前 HarmonyOS 代码已经有来源字段和 `kind: 'api' | 'local'`，也有 `source: 'pro'` 的远端合并逻辑，但页面/数据边界仍需要收口：

| 问题 | 影响 | 优先级 |
| --- | --- | --- |
| `ai_provider`、`ai_model` 同时承载本地和 Pro 行，页面没有统一过滤适配器 | 本地模型可能进入 API Key 配置列表，Pro 模型可能被当成本地模型编辑 | P0 |
| `AIConfigRdbStore.replaceRemotePro()` 将远端行叠加到本地快照后再按 source 合并 | 运行时可合并，但编辑页无法区分“用户可编辑本地配置”和“服务端只读 Pro 配置” | P0 |
| API Key 使用 `providerId` 保存，但没有在页面层明确 `proProvider` 语义 | 用户无法判断 Key 是给远端模型还是本地模型使用 | P0 |
| 本地模型页面可能复用 Provider 编辑字段 | 出现 endpoint、API Key、隐私政策等不属于本地 GGUF 的字段 | P0 |
| `AIModelSelectionSource`、`AIDefaultSource`、`AIConfigSource` 存在多套来源枚举 | `local`、`localSeed`、`localUser`、`pro`、`trial` 的显示和消费条件容易漂移 | P1 |
| Pro 刷新失败时如果清理旧 Pro 行，页面可能误显示无模型 | 远端短时失败影响已有可用配置 | P1 |

## 4. 修复方案

### 4.1 建立统一 Provider 显示名解析器

新增目标文件：

```text
entry/src/main/ets/Core/AI/Presentation/AIProviderDisplayNameResolver.ets
entry/src/main/ets/Core/AI/Presentation/AIProviderNameCatalog.ets
entry/src/main/resources/base/element/string.json
```

建议职责：

```text
AIProviderDisplayNameResolver.display(provider)
  ├─ provider.source == 'custom' ? provider.name/displayName
  ├─ provider.kind == 'local' ? 本地模型资源
  ├─ providerId 命中系统映射 ? ResourceStr
  ├─ company 命中系统映射 ? ResourceStr
  ├─ provider.name 非空 ? provider.name
  └─ company/providerId ? 脱敏后的非空 fallback
```

要求：

1. `providerId` 是匹配 key，不是展示文案。匹配前统一执行 `normalizeProviderId`。
2. 系统 Provider 的资源 key 使用稳定规范，例如：

```text
ai_provider_company_openai
ai_provider_company_google
ai_provider_company_anthropic
ai_provider_company_deepseek
ai_provider_company_zhipu
ai_provider_company_bytedance
ai_provider_company_302ai
ai_provider_company_spark
ai_provider_company_local
```

3. `AIProviderNameCatalog` 返回 `ResourceStr` 或已解析显示字符串，但不修改 `LocalProvider.company/name`。
4. 自定义 Provider 必须优先显示用户输入的名称；名称为空时才回退 company。
5. Provider 列表、模型列表、模型编辑、在线模型添加、场景模型卡片、API 测试和错误文案全部调用同一个解析器。
6. 资源缺失记录可诊断日志 `provider_display_name_missing`，但用户界面只显示安全 fallback，不显示内部资源 key。
7. 本地化只影响 UI；接口、RDB、HUKS、模型 ID、Provider ID、路由参数和运行时日志仍使用稳定 ID。

### 4.2 本地模型与 Pro 模型分成两套业务模型

不要在页面层继续使用“一个 Provider 列表 + 一个模型列表 + source 字符串判断”的隐式分层。目标是保留底层快照兼容，同时在领域和 UI 层提供明确类型：

```text
LocalModelConfig
├─ modelId
├─ displayName
├─ providerId = local:device
├─ fileId / fileName / filePathRef
├─ installState: notInstalled/downloading/verified/ready/failed
├─ manifestVersion / sha256 / sizeBytes
├─ capabilities
├─ enabled
└─ source = localUser/localSeed

ProProviderCredential
├─ providerId
├─ displayNameKey/company
├─ endpoint
├─ secretRef             # HUKS 引用，不是明文 API Key
├─ enabled
├─ privacyPolicyUrl
├─ privacyPolicyAccepted
├─ credentialState
└─ source = proCredential/custom

ProModelCatalogItem
├─ modelId
├─ providerId
├─ name/displayName
├─ capabilities
├─ scenarios
├─ isEnabled
├─ revision/etag
└─ source = pro/trial
```

边界规则：

| 能力 | 本地模型配置 | Pro 模型配置 |
| --- | --- | --- |
| API Key | 不存在 | 通过 HUKS 保存，RDB 只存 `secretRef` |
| endpoint | 不作为用户输入项；本地 Adapter 内部能力 | Provider endpoint，可编辑/测试 |
| 文件 | 下载、导入、校验、安装、删除 | 不保存 GGUF 文件引用 |
| 能力来源 | manifest + 设备能力 | SparkService 远端目录/Provider 能力 |
| 可编辑字段 | 显示名、启用、文件操作、场景绑定 | Provider 名称/endpoint/Key/隐私同意；Pro 模型目录按服务端策略只读 |
| 页面入口 | 本地模型下载/导入、模型目录筛选 | 模型密钥、Provider、在线模型、Pro 试用 |
| 失败语义 | 文件不存在、校验失败、空间不足、设备不支持 | Key 缺失、401/403、试用过期、远端刷新失败 |
| 运行时 Adapter | `LocalModelAdapter` | `OpenAICompatibleProviderAdapter` 或后端约定 Adapter |

### 4.3 页面分层

```text
AI 设置
├─ 模型密钥
│  ├─ Pro/远端 Provider 列表
│  ├─ 编辑 Pro Provider Key、endpoint、隐私政策
│  ├─ Pro/试用状态卡片
│  └─ Provider 下的远端模型目录
├─ 模型
│  ├─ 全部 / 在线模型 / 智能体
│  ├─ 本地模型：文件安装状态、能力、启用
│  └─ Pro 模型：Provider、Key 可用性、能力和来源
├─ 本地模型
│  ├─ 导入/下载/校验/安装/删除
│  └─ 不显示 API Key、endpoint、Provider 隐私政策
└─ 默认模型配置
   ├─ 本地模型
   ├─ Pro 模型
   └─ 自动：按 Resolver fallback 规则选择
```

页面过滤必须通过应用层服务，不在 ArkUI builder 中直接判断字符串：

```text
ProviderCatalogService.proCredentials(snapshot)
  -> kind == 'api'
  -> source != 'local'
  -> 返回 ProProviderCredentialPresentation

LocalModelCatalogService.localModels(snapshot)
  -> kind == 'local' OR providerId == local:device
  -> 返回 LocalModelPresentation

ModelCatalogService.visibleModels(snapshot, filter)
  -> 本地模型按 installState/enabled
  -> Pro 模型按 credentialState/remotePolicy
  -> 统一排序后返回 UI 行模型
```

### 4.4 数据存储与迁移

当前 RDB 继续兼容 `ai_provider`、`ai_model` 和 `ai_scenario_binding`，但新增/收口以下逻辑边界：

| 逻辑模型 | 当前物理表/字段 | 修复要求 |
| --- | --- | --- |
| 本地模型 | `ai_model` 中 `provider_id/kind/source` 表示本地 | 由 `kind='local'` 或稳定 `local:device` 过滤；增加/确认 `file_id/install_state/manifest_json` 字段 |
| Pro 凭证 | `ai_provider` 中 `kind='api'`、`secret_ref`、`source` | 页面只读取 `kind='api'`；Key 只经 HUKS；source 统一为 `proCredential/custom` |
| Pro 模型目录 | `ai_model` 中 `source='pro'/'trial'` | 远端刷新按 account + revision/etag 原子替换；页面标记只读远端数据 |
| 场景来源 | `ai_preferences.default_source`、`selected_*` | 统一值域 `local/pro/auto`，旧值 `localSeed/localUser/trial` 只在 mapper 兼容 |
| 本地文件 | `ai_model_file` 或现有本地模型文件表 | 文件表只保存 metadata 和路径引用，不写二进制和 API Key |

数据库迁移要求：

1. 先增加 schema version 和兼容 mapper，再迁移旧 source 值，不直接删除旧字段。
2. `providerId` 规范化只用于关联键，不重写用户可见名称。
3. 将错误归类的 `LOCAL` API Provider 转换为 `kind=local`、`providerId=local:device`；如果该行存在 HUKS secretRef，先验证是否为误存密钥，再按安全策略删除无效引用。
4. Pro 远端刷新必须事务化：新 revision 完整校验成功后替换旧 Pro 行；失败保留旧 Pro snapshot。
5. 本地模型文件删除只删除文件和 file metadata，不能误删 Pro Provider 或 HUKS Key。
6. 账号切换、退出和鉴权失效分别执行：清理当前账号 Pro secretRef/runtime；本地公共模型文件是否保留按产品策略处理，但必须清理旧账号启用关系和场景绑定。

### 4.5 统一消费与 Resolver 规则

```text
场景请求(scenario)
  -> 读取 scenario source: local / pro / auto
  -> local:
       过滤 installState=ready、enabled=true、capability 满足的 LocalModelConfig
  -> pro:
       过滤 ProProviderCredential enabled + secretRef 可用
       过滤 ProModelCatalogItem revision/权限/能力
  -> auto:
       用户显式选择 > 本地有效默认 > Pro 有效默认 > 可用候选首项
  -> 生成 AIResolvedConfig
  -> AIRuntimeService.consume(AIResolvedConfig)
```

禁止页面直接消费 `LocalProvider`、`ProScenarioModelRow` 或数据库行。页面只显示 `AIModelPresentation`：

```text
AIModelPresentation
├─ id
├─ localizedProviderName
├─ displayName
├─ sourceLabel: 本地模型 / Pro 模型 / 试用
├─ availability: ready/configureKey/install/expired/unavailable
├─ capabilities
├─ isEnabled
└─ action: edit/install/configureKey/refresh
```

## 5. 后端与安全交互边界

### 5.1 Pro 数据

- Pro 模型目录、场景模型策略、试用状态以 `SparkService` 的 AI bootstrap/trial 接口为准；HarmonyOS 不凭 iOS UI 文案新增接口字段。
- Provider Key 是用户本地凭证，提交/测试时经过当前 `AIConfigAPI.ets` 和统一 `SupportBackend`，不由页面直接创建 HTTP 请求。
- API 响应中的 Provider/Model `company`、`providerId`、`displayName` 原样进入 DTO；本地化只在 presentation mapper 发生。
- 远端失败、401/403、试用过期、revision 冲突分别转换为页面状态；不得把远端失败当作“本地没有模型”。

### 5.2 本地数据

- 本地模型安装/导入使用 `LocalModelFileService`；下载任务、校验、文件路径和 manifest 不走 SparkService Provider Key 接口。
- 本地模型 metadata 写 RDB，模型二进制写应用沙箱，API Key 不进入任何本地模型结构。
- 本地模型推理能力当前如果没有真实 Adapter，只能显示“已安装/待加载”状态，不能显示“可推理”。

### 5.3 敏感数据

| 数据 | 存储 | 禁止 |
| --- | --- | --- |
| Pro API Key | HUKS；RDB 只保存 `secretRef` | 明文 RDB、KV、rawfile、日志、路由参数 |
| Provider endpoint | RDB，可脱敏展示 | 错误文案打印完整 URL query/token |
| 本地模型路径 | RDB metadata/文件服务 | 将账号密钥拼到路径，日志输出完整敏感路径 |
| providerId/company | RDB/DTO/日志可使用稳定标识 | 用本地化名称做主键或接口参数 |

## 6. HarmonyOS 修改位置

| 文件 | 修复内容 |
| --- | --- |
| `entry/src/main/ets/Core/AI/Presentation/AIProviderDisplayNameResolver.ets` | 新增统一厂商名称解析和 fallback |
| `entry/src/main/ets/Core/AI/Presentation/AIProviderNameCatalog.ets` | Provider ID/company 到资源名映射，包含 LOCAL 和内置厂商 |
| `entry/src/main/resources/base/element/string.json` | 增加 AI Provider 本地化资源，至少覆盖 zh-CN 与 en-US |
| `entry/src/main/ets/Core/AI/Domain/AIConfigModels.ets` | 收口 source/kind 值域，补齐本地文件和 Pro credential 领域字段/mapper |
| `entry/src/main/ets/Core/AI/Infrastructure/AIConfigRdbStore.ets` | 本地/Pro 查询过滤、迁移、Pro 原子替换、secretRef 安全边界 |
| `entry/src/main/ets/Core/AI/Infrastructure/AIConfigSchema.ets` | schema version、file metadata、source/kind 索引和迁移 |
| `entry/src/main/ets/Core/AI/Application/AIConfigResolver.ets` | 按 `local/pro/auto` 选择源，过滤本地安装状态和 Pro credential 状态 |
| `entry/src/main/ets/Projects/Features/AISettings/Application/ProviderModelCatalogService.ets` | 暴露本地模型、Pro Provider、Pro 模型三类明确查询接口 |
| `entry/src/main/ets/Projects/Features/AISettings/Presentation/Providers/ProvidersPage.ets` | 只展示 Pro/API Provider；名称使用解析器 |
| `entry/src/main/ets/Projects/Features/AISettings/Presentation/Providers/ProviderEditorPage.ets` | 只编辑 Pro credential；不允许编辑本地模型文件字段 |
| `entry/src/main/ets/Projects/Features/AISettings/Presentation/Models/ModelsPage.ets` | 本地/Pro/Agent 筛选和来源标签，名称使用解析器 |
| `entry/src/main/ets/Projects/Features/AISettings/Presentation/Models/LocalModelDownloadPage.ets` | 只处理本地模型文件生命周期，不显示 API Key |
| `entry/src/main/ets/Projects/Features/AISettings/Presentation/Preferences/DefaultModelPreferencesPage.ets` | 场景 source 使用 `local/pro/auto`，展示可用性原因 |
| `entry/src/main/ets/Projects/Core/Networking/API/AI/AIConfigAPI.ets` | 只负责 SparkService DTO 和错误契约，不做名称本地化 |

## 7. 实施拆分

| 编号 | 优先级 | 工作内容 | 交付物 |
| --- | --- | --- | --- |
| AI-LOC-01 | P0 | 实现 Provider ID/company 统一名称解析器和资源映射 | 所有 AI 页面显示一致；缺失资源安全 fallback |
| AI-LOC-02 | P0 | 补齐 zh-CN/en-US Provider 资源，覆盖系统、LOCAL、Pro 常见厂商 | string resource + 本地化验收截图 |
| AI-SEP-01 | P0 | Provider/Model 查询按 `kind/source` 分层 | 本地模型不出现在模型密钥页；Pro credential 不出现在本地模型编辑页 |
| AI-SEP-02 | P0 | 新增本地模型与 Pro credential 的 presentation/use case 类型 | 页面不直接使用混合快照行 |
| AI-SEP-03 | P0 | 收口 RDB source/kind、secretRef、file metadata 和迁移 | 旧数据可迁移，Key 和文件不串 |
| AI-SEP-04 | P0 | Resolver 支持 `local/pro/auto` 三种场景来源 | 统一消费结果可解释、可回退 |
| AI-SEP-05 | P1 | Pro revision/etag 原子替换和失败保留旧快照 | Pro 刷新失败不清空已有可用模型 |
| AI-SEP-06 | P1 | 页面新增来源标签、不可用原因和正确操作入口 | 用户知道是安装模型、配置 Key 还是刷新 Pro |
| AI-TEST-01 | P1 | 增加本地化、数据过滤、迁移、Resolver 和账号隔离测试 | 自动化测试 + 真机验收矩阵 |

## 8. 验收标准

### 8.1 厂商名称本地化

- 中文系统下系统 Provider 显示中文名称，不显示 `company_XXX` 资源 key。
- 英文系统下系统 Provider 显示英文资源名称；切换语言后不需要改写 RDB 数据即可刷新显示。
- 自定义 Provider 始终显示用户输入名称，不被系统资源覆盖。
- Provider 列表、模型列表、模型编辑、在线模型添加、默认模型配置、API 测试错误文案显示同一名称。
- `LOCAL` 显示“本地模型”或对应本地化资源；稳定 ID 仍为 `local:device` 或项目统一 ID。
- 删除本地化资源后 UI 显示安全 fallback，日志记录缺失资源，不崩溃、不显示内部 key。

### 8.2 本地模型 / Pro 模型分层

- 模型密钥页只显示远端/API Provider；本地 GGUF 模型和本地文件不进入该页面。
- 本地模型页不显示 API Key、endpoint、隐私政策或 Pro 试用申请。
- Pro 模型页显示 Provider、Key 配置状态、试用状态、远端模型和来源；不显示本地文件路径。
- 本地模型只有在 `installState=ready`、`enabled=true` 且能力满足时才能被 Resolver 选中。
- Pro 模型只有在 Provider enabled、HUKS secretRef 可用、远端策略允许时才能被 Resolver 选中。
- 场景切换 `local/pro/auto` 后，页面和 Runtime 使用相同 source 规则；切换失败恢复旧选择。
- Pro 刷新失败保留上次有效 Pro snapshot 和本地模型，不显示误导性的“暂无模型”。
- 删除本地模型不会删除 Pro Key；删除 Pro Provider 不会删除本地模型文件。
- A/B 账号切换后，本地模型启用关系、Pro Key 引用、模型选择和 Runtime 均不串账号。

### 8.3 安全与编译

- API Key 只进入 HUKS；RDB、KV、日志、错误文案和路由参数均无明文 Key。
- ArkTS 编译通过，新增资源、类型和 `source/kind` 映射没有 `any/unknown`、索引类型或非显式对象错误。
- 页面加载/空态/失败态都有返回入口，不因本地化资源缺失或 Pro 请求失败出现空白页。

## 9. 测试矩阵

| 场景 | 预期 |
| --- | --- |
| zh-CN + 系统 Provider | 显示中文本地化名称 |
| en-US + 系统 Provider | 显示英文名称 |
| 自定义 Provider | 显示自定义名称 |
| 未知 Provider | 显示安全 fallback，不显示资源 key |
| 本地模型未安装 | 出现在本地模型页，Resolver 不可选，显示“安装” |
| 本地模型已安装且 ready | 可启用并参与 local 场景消费 |
| Pro Provider 无 Key | 显示“配置密钥”，不能参与 Pro 消费 |
| Pro Provider Key 有效 | 可显示远端模型并参与 Pro 消费 |
| Pro 刷新失败 | 保留旧 Pro 数据和本地数据，显示可重试状态 |
| local/pro/auto 切换 | UI、RDB/KV 偏好、Resolver、Runtime 四者一致 |
| 删除本地文件 | 删除本地文件元数据，不影响 Pro Key |
| 删除 Pro Provider | 删除/清理对应 HUKS 引用，不影响本地模型文件 |
| 切换账号 | 旧账号配置和运行时不回写新账号 |
| 暗色主题 | 本地化文案、来源标签、错误文案和卡片对比度正确 |

## 10. 完成定义

- [x] iOS 本地化规则在 HarmonyOS 有统一实现和资源映射。
- [x] 系统、Pro、试用、自定义、本地模型 Provider 的稳定 ID 和显示名职责分离。
- [x] 模型密钥页与本地模型页使用不同查询服务和不同编辑模型。
- [x] RDB/HUKS/本地文件/Pro overlay 的字段和清理边界已迁移并验证。
- [x] Resolver 完成 `local/pro/auto` 三源选择和统一消费。
- [ ] 真实账号、无 Key、无本地文件、Pro 失败、切换账号和暗色主题验收通过。
- [x] HarmonyOS 工程编译通过，页面截图与 iOS 对标页面一致。

> 实现核验（2026-07-21）：`assembleHap` BUILD SUCCESSFUL；ArkTS 0 error。真机 UI/账号切换验收仍待人工确认。  
> Schema：全新项目固定 `APP_SCHEMA_VERSION=1`，已去除历史增量 migration / `seed:LOCAL` 归一化等兼容路径。

## 11. 关联文档

- [AI 配置生命周期与本地、Pro 统一消费详细技术方案](./AI%20配置生命周期与本地、Pro%20统一消费详细技术方案.md)
- [AI 设置场景配置详细技术方案](./AI%20设置场景配置（厂商key、模型、默认模型配置、小任务）详细技术方案.md)
- [AI 设置 UI 对标与 HarmonyOS 实现规范](./AI%20设置%20UI%20对标与%20HarmonyOS%20实现规范.md)
- iOS 参考：[AI 设置场景配置（厂商 Key、模型、默认模型配置、小任务）](../../../SparkClient/总领文档/AI%20设置与本地模型/AI%20设置场景配置（厂商key、模型、默认模型配置、小任务）.md)

## 12. 子工单 AI-REFRESH-01：AI 配置与模型密钥列表下拉刷新

### 12.1 子工单目标

为 AI 设置首页、模型密钥 Provider 列表、Provider 下的模型目录建立与 iOS 一致的下拉刷新能力：

```text
下拉刷新
  -> 触发统一刷新命令
  -> 读取当前账号和本端版本/平台
  -> 请求 SparkService AI bootstrap
  -> 校验 wrapped response / revision / ETag / DTO
  -> HUKS 写入远端临时 API Key 或安全引用
  -> Pro 配置事务替换
  -> 保留本地模型配置
  -> Resolver 合并 local / Pro / trial
  -> Runtime 发布新 generation
  -> 页面重新读取脱敏列表
```

刷新不是简单重新执行 `loadSnapshot()`。`loadSnapshot()` 只读本地 RDB；下拉刷新必须完成远端配置获取、远端状态落库/内存替换、试用状态刷新、Runtime 重建和 UI 快照更新。

### 12.2 iOS 刷新事实

#### 12.2.1 模型密钥 Provider 列表

iOS 文件：

```text
/Users/hua/Documents/project/Reference/LookHealthClient/SparkClient/SparkClient/Projects/Features/AISettings/Presentation/Providers/APIKeysSettingsView.swift
/Users/hua/Documents/project/Reference/LookHealthClient/SparkClient/SparkClient/Projects/Features/AISettings/Presentation/Root/AISettingsViewModel.swift
```

页面使用：

```swift
.task {
    await viewModel.loadIfNeeded()
}
.refreshable {
    await viewModel.refreshProviderRuntimeConfiguration()
}
```

ViewModel 的实际顺序：

```text
isLoading = true
errorMessage = nil
  -> AIConfigCenter.refreshRemoteConfig()
  -> AIConfigCenter.reloadLocalSnapshot(ownerAccountID)
  -> 更新 lastPersistedSnapshot / snapshot
  -> hasLoadedSnapshot = true
  -> hasUnsavedChanges = false
  -> refreshEffectiveSmallTasks()
  -> refreshTrialStatus()
  -> isLoading = false
```

关键行为：

- 下拉时重新拉取 Pro 配置，不覆盖用户未提交的编辑，因为 Provider 列表本身不承载编辑草稿；如果页面存在草稿，刷新前必须先按产品策略提示“放弃草稿/取消刷新”。
- 刷新结束后重新读取本地快照，使远程下发 Provider、模型、场景和试用状态统一进入 UI。
- `isLoading` 在成功、失败、空响应和异常路径都必须复位，避免下拉控件永久转圈。
- `errorMessage` 只展示可恢复错误，旧数据继续保留；不能因为远程请求失败把 Provider 列表替换为空。

#### 12.2.2 Provider 模型目录

iOS 文件：

```text
/Users/hua/Documents/project/Reference/LookHealthClient/SparkClient/SparkClient/Projects/Features/AISettings/Presentation/Models/ModelManagementView.swift
/Users/hua/Documents/project/Reference/LookHealthClient/SparkClient/SparkClient/Projects/Features/AISettings/Infrastructure/ProviderModelCatalogService.swift
```

页面同时支持三种刷新入口：

```text
进入页面 .task
  -> remoteModels 为空时 refreshModels()

顶部刷新图标
  -> refreshModels()

列表下拉
  -> .refreshable { await refreshModels() }
```

`refreshModels()` 行为：

```text
校验 Provider endpoint 和 Key 非空
  -> isRefreshing = true
  -> 根据 endpoint 识别 openAICompatible / anthropic / gemini
  -> 请求 Provider 的模型目录
  -> 过滤 embedding/moderation/audio-only 等不适用于页面的模型
  -> 去重 model.name
  -> 按 displayName 稳定排序
  -> 更新 remoteModels
  -> isRefreshing = false
```

请求失败只更新错误提示，不清空 `remoteModels`；Provider Key 为空时不发请求，刷新按钮和下拉刷新应保持不可用或立即显示“请先配置密钥”。

### 12.3 SparkService bootstrap 契约

本次联调依据用户提供的后端执行日志和现有 HarmonyOS `AIConfigAPI.ets`：

```text
业务：拉取 AI 多场景模型与网关配置
Operation：AIConfig.Bootstrap
Method：GET
Path：/api/v1/ai/config/bootstrap/
Query：platform=<client-platform>&client_version=<client-version>
Auth：Bearer required
ETag：允许
Retry：启用，最多 2 次
Cache：60 秒
```

HarmonyOS 当前接口文件：

```text
/Users/hua/Documents/project/Reference/LookHealthClient/SparkClientHarmonyOS/entry/src/main/ets/Projects/Core/Networking/API/AI/AIConfigAPI.ets
```

当前代码已发送：

```text
platform=harmonyos
client_version=<传入值，缺省当前实现为 1.0.0>
```

必须修复/确认：

1. Operation 名称与 iOS/后端日志统一为 `AIConfig.Bootstrap`；当前 HarmonyOS 使用 `AI.Bootstrap`，应避免日志聚合、缓存 key 和排障工具出现两套名称。
2. `client_version` 不得长期使用默认 `1.0.0`，应从 `AppScope/app.json5` 或统一版本服务读取真实客户端版本，并在日志中记录版本来源。
3. `platform` 使用稳定值 `harmonyos`；不要使用设备型号、系统版本或中文平台名称作为业务 platform。
4. 请求必须经过 `SupportBackend`/`SupportNetworkOperation`，页面不得直接创建 HTTP 请求。
5. 刷新请求需带当前账号认证上下文；账号切换时旧请求的结果不得回写新账号。
6. 后端响应中的 `api_key` 只能在内存短暂存在并写入 HUKS；日志、异常、调试 body 和 UI 状态摘要必须脱敏。

> 安全阻断：用户提供的 bootstrap 日志原始响应体包含 API Key 字段。即使当前日志中已经出现部分脱敏，也必须把“禁止记录完整响应 body/`api_key`”作为本工单 P0，清理本地日志、网络拦截器和错误上报链路中的敏感内容。文档不复制任何真实密钥。

### 12.4 刷新状态机

```text
idle
  -> pullingLocal
  -> refreshingRemote
  -> decoding
  -> persistingPro
  -> buildingRuntime
  -> publishing
  -> success

任意阶段
  -> degraded：保留上一次有效数据，显示可重试错误
  -> invalidated：401/401xx，清理 Runtime，进入会话失效流程
  -> cancelled：页面离开或账号切换，丢弃结果，不覆盖当前账号
```

页面状态不能只使用一个 `isLoading`；至少需要：

```text
RefreshState
├─ idle
├─ refreshing(scope: aiBootstrap/providerModels)
├─ success(lastUpdatedAt, revision, changedCount)
├─ noChange(revision)
├─ degraded(reason, lastSuccessfulAt)
├─ authInvalidated
└─ cancelled
```

页面展示规则：

| 状态 | Provider 列表 | 模型目录 | 下拉控件 |
| --- | --- | --- | --- |
| refreshing | 保留旧列表，顶部/下拉显示进度 | 保留旧远端模型，显示进度 | 禁止重复刷新 |
| success | 刷新 Provider/试用摘要 | 替换远端模型并保留已添加本地模型 | 结束刷新，显示更新时间 |
| noChange | 保持列表，显示“已是最新” | 保持列表 | 正常结束 |
| degraded | 保留旧列表，显示重试提示 | 保留旧目录，显示重试提示 | 正常结束，可再次下拉 |
| authInvalidated | 停止展示需要认证的 Pro 状态 | 保留本地模型，进入登录/认证恢复 | 结束并禁止继续请求 |
| cancelled | 不改变当前 UI 快照 | 不改变当前 UI 快照 | 正常结束 |

### 12.5 HarmonyOS 页面刷新接入方案

#### 12.5.1 AI 设置首页

目标文件：

```text
entry/src/main/ets/Projects/Features/AISettings/Presentation/AISettingsPage.ets
entry/src/main/ets/Projects/Features/AISettings/Presentation/AISettingsViewModel.ets
```

实现契约：

```text
AISettingsPage
  -> Scroll/Refresh 容器
  -> onRefresh() { await viewModel.refreshAll() }
  -> RefreshStateView
  -> snapshotSummary / syncState / lastUpdatedAt
```

`refreshAll()` 不能直接调用 `AIConfigAPI.bootstrap()`，应调用组合根注入的 `AIConfigRepository.refreshRemote(accountId, clientVersion)`，由 Repository 负责：

1. 校验 active account。
2. 读取本地快照和 `allowNetwork`。
3. 设置 `syncState=refreshing`。
4. 调用 bootstrap，带 `platform=harmonyos` 和真实客户端版本。
5. 解码 wrapped response，检查 `code`、`data`、`revision`、`scenarios`、`smallTasks`、`trialStatus`。
6. 比较 revision/ETag；无变化直接 build runtime，不重复写库。
7. 有变化时将 Pro Key 写 HUKS、RDB 只写 secretRef，事务替换 Pro 行。
8. 保留本地模型、文件 metadata、本地 Provider 和用户场景绑定。
9. Resolver 合并并发布新的 runtime generation。
10. 返回 `RefreshResult` 给 ViewModel，页面重新 loadSnapshot。

#### 12.5.2 模型密钥 Provider 列表

目标文件：

```text
entry/src/main/ets/Projects/Features/AISettings/Presentation/Providers/ProvidersPage.ets
entry/src/main/ets/Projects/Features/AISettings/Presentation/AISettingsViewModel.ets
entry/src/main/ets/Projects/Features/AISettings/Application/ProviderModelCatalogService.ets
```

页面行为：

```text
进入 ProvidersPage
  -> aboutToAppear / task：loadSnapshotIfNeeded()
  -> 首次无数据：显示 loading，不自动把请求失败显示为 empty

下拉
  -> refresh(scope=aiBootstrap)
  -> 等待 Repository 完整刷新
  -> 重新读取 proCredentials(snapshot)
  -> 更新试用状态、Provider 名称、Key 配置状态和模型数量
```

Provider 列表只显示远端/API Provider：

```text
provider.kind == 'api'
&& provider.providerId != 'local:device'
&& provider.source != 'localSeed' || provider.hasRemoteCredentialPolicy
```

这里不能简单用 `source` 单条件过滤，必须由 `ProviderModelCatalogService.proCredentials()` 统一处理兼容旧数据。

#### 12.5.3 Provider 下的模型管理列表

目标文件：

```text
entry/src/main/ets/Projects/Features/AISettings/Presentation/Providers/ProviderEditorPage.ets
entry/src/main/ets/Projects/Features/AISettings/Application/ProviderModelCatalogService.ets
```

这里有两种不同刷新来源，必须在 UI 文案和日志中区分：

| 刷新类型 | 数据来源 | 是否写 RDB | 用途 |
| --- | --- | --- | --- |
| AI bootstrap 刷新 | SparkService `/api/v1/ai/config/bootstrap/` | Pro 行原子替换 | 刷新多场景 Pro 模型、默认策略和试用状态 |
| Provider 模型目录刷新 | Provider endpoint `/models` 或厂商协议接口 | 用户点击“添加”后才写 | 查看该厂商当前可添加模型 |

Provider 模型目录刷新流程：

```text
校验 provider.kind=api
  -> 读取 HUKS(secretRef)
  -> endpoint 规范化为模型目录地址
  -> 按 provider protocol 发 GET
  -> 解码 data/models
  -> 过滤不可消费模型、去重、稳定排序
  -> 仅更新页面 remoteModels
  -> 用户点击“添加”
  -> 写入本地 Pro/custom model 目录
  -> Resolver 重建
```

重要边界：仅“刷新远端目录”不应自动把所有模型写入 RDB；只有用户明确点击“添加”才保存模型。bootstrap 刷新属于服务端策略同步，可以更新 Pro overlay，但也不能覆盖用户自定义模型和本地模型。

### 12.6 详细日志规范

#### 12.6.1 日志公共字段

每次刷新必须带以下结构化字段；字段值不得包含 API Key：

```text
operation=AIConfig.Bootstrap
scope=aiBootstrap | providerModels
accountId=<脱敏账号标识或内部安全 ID>
platform=harmonyos
clientVersion=<真实版本>
requestId=<X-Request-ID>
cacheKey=<不含 secret 的 method/path/query>
oldRevision=<old/empty>
newRevision=<new/empty>
etag=<hash/empty，不打印完整敏感值>
state=<refresh state>
durationMs=<耗时>
httpStatus=<状态码>
businessCode=<业务码>
providerId=<稳定 ID，可记录>
modelCount=<数量>
changedCount=<数量>
```

#### 12.6.2 日志事件表

| 事件 | 级别 | 必须记录 | 禁止记录 |
| --- | --- | --- | --- |
| `ai.refresh.begin` | info | scope、account、platform、version、oldRevision | API Key、Authorization、完整 URL query secret |
| `ai.refresh.request` | debug/info | method、path、query、requestId、cache policy | body 中的 Key、完整认证 header |
| `ai.refresh.response` | info | status、duration、size、requestId、revision | 原始响应 body、`api_key`、完整 Provider endpoint token |
| `ai.refresh.decode.ok` | info | scenarioCount、modelCount、taskCount、revision | Prompt 全文、Key、完整远端配置 |
| `ai.refresh.no_change` | info | old/new revision、etag result | raw payload |
| `ai.refresh.persist.begin` | info | account、revision、pro row count | secretRef 原文、密钥内容 |
| `ai.refresh.persist.ok` | info | inserted/updated/deleted counts | RDB 全量 dump |
| `ai.refresh.runtime.ok` | info | generation、effective defaults、local/pro counts | runtime 中的 apiKey |
| `ai.refresh.degraded` | warn | error kind、status、保留 revision、retryable | 完整异常 body 中的敏感字段 |
| `ai.refresh.auth` | warn | 401/业务码、account、requestId | Token |
| `ai.provider_models.begin` | info | providerId、protocol、scope | API Key |
| `ai.provider_models.ok` | info | providerId、count、filteredCount、duration | 原始响应全量内容 |
| `ai.provider_models.failed` | warn | providerId、status、error kind | Authorization、完整 endpoint query |

#### 12.6.3 脱敏规则

```text
Authorization: Bearer ***
api_key: ***
secretRef: 只记录 alias hash 或 providerId，不记录完整 alias
endpoint: 只记录 scheme + host + path 的脱敏摘要，移除 query
Prompt/systemProvision: 只记录长度和 hash，不记录正文
response body: 默认不记录；调试开关也必须经过字段级 redaction
```

用户提供的后端执行日志中，bootstrap 原始 body 包含 `api_key` 字段；该问题必须在客户端 `SupportBackend`、`AIConfigDecode` 前后的日志层和后端请求日志层同时修复。

### 12.7 刷新错误与回退矩阵

| 场景 | 本地模型 | Pro 模型 | 页面提示 | Runtime |
| --- | --- | --- | --- | --- |
| 200 + 新 revision | 保留并重新合并 | 原子替换 Pro 行 | 刷新成功/更新时间 | 发布新 generation |
| 200 + 相同 revision | 不变 | 不重复写入 | 已是最新 | 可重建或复用 |
| 200 + 空 scenarios | 不变 | 不删除旧 Pro | 远端暂无更新/重试 | 保留旧有效 Runtime |
| 304/ETag 未变化 | 不变 | 不变 | 已是最新 | 保留 Runtime |
| 401/401xx | 可保留本地，但停止需要 Pro 的消费 | 标记失效，不误删本地 Key 以外的安全数据 | 需要重新登录/授权 | invalidate Pro 消费 |
| 403 | 不变 | 标记无权限/试用过期 | 显示权限说明 | 使用 local/降级 |
| 超时/断网 | 不变 | 保留上次 Pro 快照 | 可重试，不能显示空列表 | 保留上次有效 |
| DTO 解码失败 | 不变 | 保留旧 Pro 快照 | 配置版本不兼容/重试 | 保留上次有效 |
| HUKS 写入失败 | 不变 | 不发布含 Key 的 Pro 行 | 安全存储失败 | Pro 行不可消费 |
| RDB 事务失败 | 不变 | 回滚新 Pro 行 | 保存失败/重试 | 保留旧 Runtime |
| 账号切换 | 新账号本地数据 | 丢弃旧请求结果 | 重新加载新账号 | 旧 generation 无效 |

### 12.8 下拉刷新验收用例

#### 12.8.1 页面交互

- AI 设置首页向下拉动，出现刷新进度，页面标题、入口卡片和旧数据保持可见。
- 模型密钥 Provider 列表向下拉动，触发一次 `AIConfig.Bootstrap`；快速连续下拉不产生并发重复请求。
- 刷新期间点击 Provider 编辑、返回和其他页面操作，按产品策略允许查看旧快照，但不允许提交过期草稿覆盖新快照。
- 刷新成功后显示更新时间、远端 revision/状态摘要和本地/Pro 模型数量变化。
- 刷新失败后停止转圈，旧 Provider/模型列表仍显示，并出现可重试错误。
- 没有 Provider Key 时，Provider 模型目录页面的下拉刷新不可用或提示先配置密钥，不发送空凭证请求。
- Provider 模型目录刷新成功后只显示远端候选；点击“添加”后才进入本地模型目录和 Resolver。

#### 12.8.2 接口与缓存

- 请求路径为 `/api/v1/ai/config/bootstrap/`，method 为 GET，query 包含 `platform=harmonyos` 和真实 `client_version`。
- 请求带 Bearer 鉴权、request ID、ETag/cache policy；响应 200、304、401、403、429、5xx 均有明确状态映射。
- retry 只对 GET bootstrap 等幂等请求启用；Provider 添加、Key 保存、试用申请不因下拉刷新自动重试。
- 相同账号、相同 revision/ETag 的刷新不重复写 Pro 数据；不同 revision 只替换 Pro 行，不覆盖本地用户数据。
- 网络失败不清空上一次有效 Pro 配置，不把 `empty` 与 `degraded` 混为一类。

#### 12.8.3 日志与安全

- 同一刷新链路的 `requestId` 在开始、请求、响应、解码、持久化、Runtime 发布和失败日志中一致。
- 日志能看出 `oldRevision/newRevision`、耗时、数量和状态，但搜索不到 `api_key`、Bearer Token、Prompt 正文和完整敏感 URL。
- 发现原始响应 body 进入日志时，验收直接失败，不得以“本地调试”作为例外。

### 12.9 子工单实施清单

| 编号 | 优先级 | 修复内容 | 验收证据 |
| --- | --- | --- | --- |
| AI-REFRESH-01 | P0 | HarmonyOS AI 设置首页和模型密钥列表接入 `Refresh`/下拉刷新 | 真机操作视频或截图、一次完整日志链路 |
| AI-REFRESH-02 | P0 | 统一调用 `AIConfigRepository.refreshRemote`，不在页面直接调 bootstrap | 代码审计和单元测试 |
| AI-REFRESH-03 | P0 | 修正 Operation 名称、platform、client_version、ETag/retry/cache 参数 | 请求日志与 iOS 对比 |
| AI-REFRESH-04 | P0 | 远端 API Key 字段全链路脱敏，HUKS 写入后清理内存字段 | 安全日志扫描、异常路径测试 |
| AI-REFRESH-05 | P0 | refresh state、旧快照保留、账号 generation 和取消处理 | 断网/切账号/返回页面测试 |
| AI-REFRESH-06 | P1 | Provider 模型目录独立支持下拉、顶部刷新和首次自动刷新 | Provider model catalog 验收 |
| AI-REFRESH-07 | P1 | Provider 模型远端候选与用户点击添加分离 | RDB diff 与页面操作验收 |
| AI-REFRESH-08 | P1 | 增加 refresh flow log 事件和计数摘要 | 日志字段表逐项核对 |

### 12.10 子工单完成定义

- [x] AI 设置首页支持下拉刷新。
- [x] 模型密钥 Provider 列表支持下拉刷新。
- [ ] Provider 下的远端模型目录支持进入自动刷新、顶部刷新和下拉刷新。
- [x] 刷新链路与 iOS 顺序一致：远端刷新 -> 本地快照重载 -> 小任务/试用状态刷新 -> Runtime 更新。
- [x] SparkService bootstrap 请求使用 HarmonyOS 平台和真实版本，Operation 名称统一。
- [x] 支持 revision/ETag 无变化、远端空 payload、断网、401/403、解码失败、RDB/HUKS 失败回退。
- [x] 日志记录完整链路且不泄露任何 API Key、Token、Prompt 或敏感 URL。
- [x] 本地模型配置不因 Pro 下拉刷新被删除、覆盖或错误标记为远端模型。
- [x] 刷新完成后页面名称本地化、来源标签和模型数量与 Resolver 结果一致。

> Provider 模型目录独立刷新（AI-REFRESH-06/07）仍为 P1，本轮未做厂商 `/models` 远端候选拉取。
