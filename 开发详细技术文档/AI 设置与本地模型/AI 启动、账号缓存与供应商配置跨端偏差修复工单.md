# AI 启动、账号缓存与供应商配置跨端偏差修复工单

> 工单类型：HarmonyOS 对标 iOS 的业务/代码审计修复工单。默认只维护文档和验收契约，不直接修改业务代码。后端唯一事实源为 `/Users/hua/Documents/project/Reference/LookHealthClient/SparkService`。

## 1. 背景与问题现象

当前页面出现“模型厂商 / 暂无厂商，请新增自定义供应商”。这不只是 UI 空态问题，而是账号级生命周期问题：认证恢复、首次种子灌库、RDB 读取、运行时缓存、Pro 刷新、Provider Key 安全存储和页面状态必须形成同一条可观测链路。

本工单要求与 iOS 业务流程一致：首次登录建立账号级本地数据；完成数据库导入后加载到 Runtime 缓存；非首次启动优先恢复上次有效缓存，再异步刷新 SparkService；失败时保留可用本地配置，不把网络错误误报为“暂无厂商”。

## 2. 真实代码基线

| 能力 | iOS 证据 | HarmonyOS 证据 | 当前结论 |
| --- | --- | --- | --- |
| 网络门控 | `SparkClient/Projects/App/Sources/App/AppCoordinatorView.swift` | `entry/src/main/ets/App/AppLifecycleCoordinator.ets` | HarmonyOS 已有网络状态，但 AI 就绪门禁需独立发布 |
| 会话恢复 | `AppSessionStore.swift`、`DefaultAuthRepository` | `App/AppSessionStore.ets`、`Projects/Features/Auth/Infrastructure/DefaultAuthRepository.ets` | 认证成功不能等价于账号业务准备完成 |
| 账号准备 | `SignedInSessionPreparationRegistry.swift`、`AppBootstrapper.swift` | `App/SignedInSessionPreparationRegistry.ets`、`AppBootstrapper.ets` | 已有雏形，需固定首次/非首次路径和 generation |
| AI 持久化 | Core Data + UserDefaults/Keychain | `Core/AI/Infrastructure/AIConfigRdbStore.ets`、`AIConfigSchema.ets`、`AIKeyStore.ets` | RDB 是正式主事实；KV 不承载 AI 目录 |
| AI 运行时 | `AIConfigCenter.swift`、`AIRuntimeConfigStore.swift`、Resolver | `Core/AI/Application/AIConfigRepository.ets`、Resolver、`AIRuntimeService.ets` | 已有统一消费入口，本地 GGUF 仍不能宣称可推理 |
| 后端交互 | iOS `AIConfigAPI.swift` | `Projects/Core/Networking/API/AI/AIConfigAPI.ets` | bootstrap/trial/provider test 路由已对齐，需真实 DTO/安全契约收口 |

## 3. 业务偏差与代码偏差

| 严重度 | 偏差 | 业务后果 | 修复方向 |
| --- | --- | --- | --- |
| P0 | `signedIn`、`prepared`、`aiRuntimeReady` 尚未形成单一可观测状态 | 主页面/设置页可能在 Runtime 尚未生成时显示空厂商 | 增加 AI 就绪门禁，主框架只在账号准备完成后放行 |
| P0 | 首次 seed、RDB load、Runtime publish 的幂等和失败边界需固定 | 首次启动空态、重复插入或半套表 | `ensureSeeded -> loadLocal -> buildRuntime -> refreshRemote`，按 accountId 单飞 |
| P0 | 已复制的 iOS `APIKeys.json`/`AllModels.json` 尚未被当前 `loadSeedJson()` 读取 | 工程有源文件但首次登录仍使用拆分 JSON，iOS/HarmonyOS 初始数据可能漂移 | 改造 `AIConfigSeedLoader`、`AIConfigRepository.loadSeedJson()`，增加原始 DTO、映射、引用校验和导入测试 |
| P0 | Pro bootstrap payload 当前可能含明文 `api_key` | Key 进入 DTO、日志或不安全持久化 | 后端优先改为安全引用；短期只能短暂内存消费后写 HUKS |
| P1 | `MemoryAIConfigStore` 与 RDB Store 并存 | 误注入后重启丢配置 | 生产组合根只注入 RDB，Memory 仅测试替身 |
| P1 | KV 与 RDB 可能重复保存同一配置 | 跨设备同步覆盖本地目录 | KV 只保存轻量偏好和同步元数据 |
| P1 | 空态把请求失败当成没有厂商 | 用户被错误引导新增 Provider | 区分 loading/empty/error/degraded |
| P1 | Provider 新增未定义原子写入顺序 | Key、Provider、Model 产生孤儿数据 | 测试连接 -> HUKS -> RDB 事务 -> Resolver -> Runtime |
| P1 | Pro revision 回退、空结果和远端删除保护需收口 | 新旧配置覆盖或误删 | revision 单调校验，空 payload 不删除本地有效行 |
| P2 | GGUF 文件 ready 与可推理状态混用 | 页面显示可用但首次推理失败 | 分离 downloaded/verified/loaded/ready |

## 4. 目标启动流程

### 4.1 首次登录

```text
登录成功(accountId)
 -> 校验当前 generation
 -> 打开 spark_client.db，执行 schema/migration
 -> 查询 ai_account_meta
 -> 不存在或 seed_version 过期：读取 rawfile/ai/*.json
 -> 校验 Provider/Model/Scenario/Task 引用
 -> 单事务写入 meta、provider、model、binding、task、preferences
 -> 写 seed_version、seeded_at、sync_state=localReady
 -> loadSnapshot(accountId)
 -> Resolver 过滤不可用项
 -> 发布 runtimeGeneration + aiRuntimeReady
 -> 请求 Pro bootstrap
```

seed 必须可重复执行。相同 `seedVersion` 不重复插入；升级 seed 只补 `source=system`，不得覆盖 `source=custom` 和用户选择；默认 Key 不得以占位字符串写入 HUKS。种子文件只放非敏感 Provider/模型/场景/小任务，不能放 API Key。

#### 4.1.1 iOS 原始初始配置文件已复制到 HarmonyOS

初始源文件来自 iOS：

```text
/Users/hua/Documents/project/Reference/LookHealthClient/SparkClient/SparkClient/Projects/App/Resources/AISettings/APIKeys.json
/Users/hua/Documents/project/Reference/LookHealthClient/SparkClient/SparkClient/Projects/App/Resources/AISettings/AllModels.json
```

已原样复制到 HarmonyOS：

```text
/Users/hua/Documents/project/Reference/LookHealthClient/SparkClientHarmonyOS/entry/src/main/resources/rawfile/ai/source/AISettings/APIKeys.json
/Users/hua/Documents/project/Reference/LookHealthClient/SparkClientHarmonyOS/entry/src/main/resources/rawfile/ai/source/AISettings/AllModels.json
```

两个目标文件与 iOS 源文件 SHA-256 一致且 JSON 解析通过。当前 `APIKeys.json` 的 `key` 字段为空，不包含实际密钥；后续禁止将真实 Key 回填到资源目录。

首次登录导入责任：`AppBootstrapper -> AIConfigRepository.ensureSeeded(accountId) -> AIConfigSeedLoader -> rawfile/ai/source/AISettings/* -> 字段映射/引用校验 -> RDB 事务 -> loadSnapshot -> Runtime`。页面不得直接读取 rawfile，Runtime 不得直接消费 iOS JSON。

导入映射至少包括：`requestURL -> requestUrl`、`displayName -> displayName`、`supportsTextGen -> supportsText`、`supportReasoningChange -> reasoningControllable`、`isEnabled -> isEnabled`。`APIKeys.json` 只负责 Provider 元数据，Key 为空时创建“未配置密钥”的 Provider；真实 Key 只能由用户输入后经 Provider 连通性测试写入 HUKS，RDB 只保存 `secretRef`。

现有 `rawfile/ai/providers.json`、`models.json`、`scenario_bindings.json`、`small_tasks.json`、`preferences.json` 是 HarmonyOS 规范化 seed 视图，不能与 iOS 原始文件形成两套人工来源。应由 SeedLoader 统一以原始文件为输入并完成合并，或在构建校验中比较 Provider/Model 数量、稳定 ID、公司和能力字段。

#### 4.1.2 当前代码缺口与改造位置

当前真实代码已改为：

```text
AIConfigRepository.ensureSeeded(accountId)
  -> loadSeedJson()
  -> readRawfileUtf8('ai/source/AISettings/APIKeys.json')
  -> readRawfileUtf8('ai/source/AISettings/AllModels.json')
  -> AIConfigSeedLoader.parseIOSSourceBundle(...)
  -> （可选叠加）ai/small_tasks.json、ai/preferences.json
  -> AIConfigStore.saveLocal(...)
```

`rawfile/ai/providers.json` 等规范化文件仅作兼容/对照视图，不再作为生产首次登录输入。

| 文件 | 改造内容 |
| --- | --- |
| `Core/AI/Infrastructure/AIConfigSeedLoader.ets` | 增加 iOS 原始 JSON DTO、Provider/Model 映射、引用校验、默认绑定生成 |
| `Core/AI/Application/AIConfigRepository.ets` | `loadSeedJson()` 改为读取原始文件；增加 seed 单飞、来源标记和导入失败错误 |
| `Core/AI/Infrastructure/AIConfigSchema.ets` | 保持 `seed_version`/`seeded_at`；需要时增加 `seed_source`、`seed_checksum` |
| `Core/AI/Infrastructure/AIConfigRdbStore.ets` | 确认整个 seed 快照由一个事务写入，失败回滚 |
| `App/AppBootstrapper.ets` | 只有 seed 和 `buildRuntime` 成功才标记账号准备完成；不得吞掉 seed 错误 |
| `App/AppLifecycleCoordinator.ets` | 区分 `localReady`、`degraded` 和 `invalidated`，避免把 seed 失败变成“账号 complete” |

### 4.1.3 建议新增的源文件 DTO

以下 DTO 只表示 rawfile 输入，不得直接传给 RDB 或 Runtime：

```ts
interface IOSAPIKeySeedRow {
  name?: string;
  company?: string;
  key?: string;
  requestURL?: string;
  requestUrl?: string;
  help?: string;
  privacyPolicyURL?: string;
  privacyPolicyUrl?: string;
  isEnabled?: boolean;
  source?: string;
  from?: string;
}

interface IOSModelSeedRow {
  name?: string;
  displayName?: string;
  identity?: string;
  company?: string;
  price?: number;
  priceTier?: string | number;
  isEnabled?: boolean;
  supportsSearch?: boolean;
  supportsTextGen?: boolean;
  supportsText?: boolean;
  supportsMultimodal?: boolean;
  supportsReasoning?: boolean;
  supportReasoningChange?: boolean;
  reasoningControllable?: boolean;
  supportsImageGen?: boolean;
  supportsVoiceGen?: boolean;
  supportsToolUse?: boolean;
  supportsDeepReasoning?: boolean;
  systemProvision?: string;
  icon?: string;
  briefDescription?: string;
  aiScenarios?: string[];
  aiToolScenarios?: string[];
  relatedTaskCodes?: string[];
  baseModelName?: string;
}
```

生产代码应使用 `unknown`/受限 `Record` 解码并逐字段校验；不能将 `JSON.parse(...) as IOSModelSeedRow` 当作校验。每个字段必须有默认值，数组字段必须确认 `Array.isArray`，URL 必须检查 scheme，字符串必须 trim 后再判断长度。

### 4.1.4 字段映射代码细节

以下为贴合当前 `AIConfigSeedLoader.ets` 的实现骨架，具体 `Record` 类型和错误类型以目标 SDK 编译结果调整：

```ts
private static parseIOSProviders(json: string): LocalProvider[] {
  const rows = AIConfigSeedLoader.requireArray(json, 'APIKeys.json');
  const result: LocalProvider[] = [];
  const seen = new Set<string>();

  for (let i = 0; i < rows.length; i++) {
    const row = AIConfigSeedLoader.asRecord(rows[i], `APIKeys[${i}]`);
    const company = AIConfigSeedLoader.requiredText(row, 'company', `APIKeys[${i}]`);
    const id = `seed:${normalizeProviderId(company)}`;
    if (seen.has(id)) {
      throw new AISeedValidationError('duplicate_provider', id);
    }
    seen.add(id);

    const p = new LocalProvider();
    p.id = id;
    p.name = AIConfigSeedLoader.optionalText(row, 'name') || company;
    p.company = company;
    p.kind = 'api';
    p.requestUrl = AIConfigSeedLoader.optionalText(row, 'requestURL')
      || AIConfigSeedLoader.optionalText(row, 'requestUrl');
    p.isEnabled = AIConfigSeedLoader.bool(row, 'isEnabled', false);
    p.position = i;
    p.source = 'localSeed';
    p.updatedAt = nowIso();
    result.push(p);
  }
  return result;
}
```

Model 映射必须保持与 Provider 的稳定关联：

```ts
private static parseIOSModels(json: string, providers: LocalProvider[]): LocalModel[] {
  const rows = AIConfigSeedLoader.requireArray(json, 'AllModels.json');
  const providerIds = new Set<string>();
  for (let i = 0; i < providers.length; i++) {
    providerIds.add(providers[i].company.toUpperCase());
  }

  const result: LocalModel[] = [];
  const seen = new Set<string>();
  for (let i = 0; i < rows.length; i++) {
    const row = AIConfigSeedLoader.asRecord(rows[i], `AllModels[${i}]`);
    const name = AIConfigSeedLoader.requiredText(row, 'name', `AllModels[${i}]`);
    const company = AIConfigSeedLoader.requiredText(row, 'company', `AllModels[${i}]`);
    const providerId = `seed:${normalizeProviderId(company)}`;
    if (!providerIds.has(company.toUpperCase())) {
      throw new AISeedValidationError('model_provider_missing', `${company}:${name}`);
    }
    const modelId = `${providerId}:${name}`;
    if (seen.has(modelId)) {
      throw new AISeedValidationError('duplicate_model', modelId);
    }
    seen.add(modelId);

    const model = new LocalModel();
    model.id = modelId;
    model.name = name;
    model.displayName = AIConfigSeedLoader.optionalText(row, 'displayName') || name;
    model.providerId = providerId;
    model.modelType = 'remote';
    model.identity = AIConfigSeedLoader.optionalText(row, 'identity') || 'model';
    model.isEnabled = AIConfigSeedLoader.bool(row, 'isEnabled', true);
    model.source = 'localSeed';
    model.capabilities = ModelCapabilities.fromRecord({
      supportsText: AIConfigSeedLoader.boolAny(row, ['supportsText', 'supportsTextGen'], false),
      supportsSearch: AIConfigSeedLoader.bool(row, 'supportsSearch', false),
      supportsMultimodal: AIConfigSeedLoader.bool(row, 'supportsMultimodal', false),
      supportsReasoning: AIConfigSeedLoader.bool(row, 'supportsReasoning', false),
      supportsToolUse: AIConfigSeedLoader.bool(row, 'supportsToolUse', false),
      supportsVoiceGen: AIConfigSeedLoader.bool(row, 'supportsVoiceGen', false),
      supportsImageGen: AIConfigSeedLoader.bool(row, 'supportsImageGen', false),
      supportsDeepReasoning: AIConfigSeedLoader.bool(row, 'supportsDeepReasoning', false),
      reasoningControllable: AIConfigSeedLoader.boolAny(
        row, ['reasoningControllable', 'supportReasoningChange'], false)
    });
    model.priceTier = AIConfigSeedLoader.optionalTextAny(row, ['priceTier', 'price']);
    model.systemProvision = AIConfigSeedLoader.optionalText(row, 'systemProvision');
    model.icon = AIConfigSeedLoader.optionalText(row, 'icon');
    model.briefDescription = AIConfigSeedLoader.optionalText(row, 'briefDescription');
    model.updatedAt = nowIso();
    result.push(model);
  }
  return result;
}
```

### 4.1.5 从 iOS 模型生成 HarmonyOS 场景绑定

iOS `AllModels.json` 有 `aiScenarios`，但当前 HarmonyOS `AIConfigSeedLoader.parseBindings()` 需要独立 binding JSON。因此导入器必须生成 binding，而不是让模型目录存在但所有场景为空：

```ts
private static buildBindings(models: LocalModel[], iosRows: Object[]): LocalScenarioBinding[] {
  const result: LocalScenarioBinding[] = [];
  const defaultByScenario = new Map<string, string>();

  for (let i = 0; i < iosRows.length; i++) {
    const row = AIConfigSeedLoader.asRecord(iosRows[i], `AllModels[${i}]`);
    const name = AIConfigSeedLoader.requiredText(row, 'name', `AllModels[${i}]`);
    const company = AIConfigSeedLoader.requiredText(row, 'company', `AllModels[${i}]`);
    const modelId = `seed:${normalizeProviderId(company)}:${name}`;
    const scenarios = AIConfigSeedLoader.stringArray(row, 'aiScenarios');

    for (let j = 0; j < scenarios.length; j++) {
      const scenario = scenarios[j];
      if (!AIScenario.isKnown(scenario)) {
        continue;
      }
      const binding = new LocalScenarioBinding();
      binding.scenario = scenario;
      binding.modelId = modelId;
      binding.position = i;
      binding.enabled = true;
      binding.source = 'localSeed';
      binding.isDefault = !defaultByScenario.has(scenario);
      if (binding.isDefault) {
        defaultByScenario.set(scenario, modelId);
      }
      binding.updatedAt = nowIso();
      result.push(binding);
    }
  }
  return result;
}
```

默认模型策略必须明确：如果 iOS 源文件没有 `isDefault`，首个满足 `isEnabled=true` 且具备 `supportsText` 的模型只能作为本地 fallback；不能覆盖用户选择，也不能把首个模型伪装成 Pro 默认模型。更稳妥的做法是把默认规则写入 `SeedPolicy`，后续由产品确认每个场景的默认模型。

### 4.1.6 原始文件读取与编码

当前 `readRawfile()` 逐字节 `String.fromCharCode`，只适合 ASCII。实现时要统一 UTF-8 解码，避免中文模型名、描述和 Prompt 被破坏：

```ts
private async readRawfileUtf8(path: string): Promise<string> {
  const data = await this.context!.resourceManager.getRawFileContent(path);
  const bytes = data as Uint8Array;
  return new TextDecoder('utf-8').decode(bytes);
}
```

如果目标 API 24 的 ArkTS 不提供 `TextDecoder`，必须使用项目已验证的 UTF-8 工具或 `util.TextDecoder` 等官方 API，并在真实设备编译确认；禁止用 `String.fromCharCode` 作为生产实现。

### 4.1.7 Repository 入口改造

`AIConfigRepository.loadSeedJson()` 应改为原始源读取，并在源文件映射完成后再调用现有 `parseSeedBundle` 或新增 `parseIOSSourceBundle`：

```ts
private async loadSeedJson(): Promise<SeedJsonCache> {
  if (this.seedCache) {
    return this.seedCache;
  }
  if (!this.context) {
    throw new AISeedLoadError('missing_context');
  }

  const apiKeys = await this.readRawfileUtf8('ai/source/AISettings/APIKeys.json');
  const allModels = await this.readRawfileUtf8('ai/source/AISettings/AllModels.json');
  const source = AIConfigSeedLoader.parseIOSSourceBundle(apiKeys, allModels);

  const cache = new SeedJsonCache();
  cache.providers = JSON.stringify(source.providers);
  cache.models = JSON.stringify(source.models);
  cache.bindings = JSON.stringify(source.bindings);
  cache.tasks = await this.readRawfileUtf8('ai/small_tasks.json');
  cache.prefs = await this.readRawfileUtf8('ai/preferences.json');
  this.seedCache = cache;
  return cache;
}
```

禁止在 `!context` 时回退 `emptyMinimal()` 作为真实启动数据。测试可以通过 `setSeedJsonCache()` 注入 fixture；生产缺少 Context 或 rawfile 必须进入 `seedFailed`，否则会把工程资源缺失伪装成“暂无厂商”。

### 4.1.8 首次登录事务细节

```text
ensureSeeded(accountId)
  1. assertAccount(accountId)
  2. singleFlight(accountId, seedTask)
  3. store.load(accountId)
  4. 已有 seedVersion > 0 -> alreadySeeded
  5. 读 APIKeys/AllModels
  6. parse + normalize + validate
  7. snapshot.accountId = accountId
  8. snapshot.seedVersion = AIConfigSchema.SEED_VERSION
  9. store.saveLocal(accountId, snapshot)
      - beginTransaction
      - upsert ai_account_meta
      - 清理该账号 source=localSeed/system 的旧行
      - 插入 provider/model/binding/task/preferences
      - 校验外键、默认模型唯一性、账号一致性
      - commit
 10. loadSnapshot(accountId)
 11. resolver.buildRuntime(snapshot)
 12. runtimeStore.publish(runtime)
 13. 发布 localReady/aiRuntimeReady
```

seed 失败时：事务 rollback；不写 `seedVersion`；不发布 `aiRuntimeReady=true`；不调用 Pro refresh；向 UI 发布可重试错误。若账号已有旧快照，升级 seed 只能走 migration，不能通过 `ensureSeeded` 全量覆盖。

### 4.1.9 SparkService 刷新与 Key 安全代码边界

首次 seed 完成后才允许调用 `AIConfigAPI.bootstrap()`。远端返回的 `api_key`（如果后端暂时仍返回）只能在 `refreshRemote()` 的局部变量存在：

```ts
const remote = await this.api.bootstrap(clientVersion);
const secretRefs = new Map<string, string>();
try {
  for (const bundle of remote.scenarios) {
    for (const row of bundle.models) {
      if (row.apiKey && row.apiKey.length > 0) {
        const providerId = `pro:${normalizeProviderId(row.company)}`;
        const ref = await this.keys.put(accountId, providerId, row.apiKey);
        secretRefs.set(providerId, ref);
        row.apiKey = undefined;
      }
    }
  }
  await this.store.replaceRemotePro(accountId, remote, secretRefs, remote.etag);
} finally {
  // 不记录 row.apiKey；尽快解除对远端 DTO 的引用
  remote.clearSensitiveFields?.();
}
```

正式方案仍推荐 SparkService 不下发明文 Key，改为服务端代理或短期授权引用。客户端不得把 `api_key` 写入 `SeedJsonCache`、RDB、KV、日志、异常消息或页面状态。

### 4.1.10 首次登录与非首次启动测试代码

建议新增测试：

```ts
test('first login imports iOS source files and persists account seed', async () => {
  const repository = makeRepositoryWithIOSSourceFixtures();
  const result = await repository.ensureSeeded(1001);
  expect(result.status).toBe('seeded');

  const snapshot = await repository.loadSnapshot(1001);
  expect(snapshot.seedVersion).toBe(1);
  expect(snapshot.providers.length).toBeGreaterThan(0);
  expect(snapshot.models.length).toBeGreaterThan(0);
  expect(snapshot.scenarioBindings.length).toBeGreaterThan(0);
  expect(snapshot.providers.every((p) => p.secretRef === undefined)).toBe(true);
});

test('second launch does not overwrite custom provider', async () => {
  const repository = makeRepositoryWithIOSSourceFixtures();
  await repository.ensureSeeded(1001);
  await repository.save(1001, snapshotWithCustomProvider('custom:test'));
  const result = await repository.ensureSeeded(1001);
  expect(result.status).toBe('alreadySeeded');
  expect((await repository.loadSnapshot(1001)).providers.some((p) => p.id === 'custom:test')).toBe(true);
});

test('invalid source file rolls back and is not reported as empty provider list', async () => {
  const repository = makeRepositoryWithInvalidIOSSource();
  await expect(repository.ensureSeeded(1001)).rejects.toThrow('seed');
  expect((await repository.loadSnapshot(1001)).seedVersion).toBeUndefined();
});
```

集成验收还必须检查真实设备上的 rawfile 路径、中文 UTF-8、RDB 行数、`seed_version`、默认绑定唯一性、Runtime 场景数量和日志脱敏；单元测试只验证解析规则，不能替代设备安装后的资源读取测试。

### 4.2 非首次启动/前台恢复

```text
网络已评估且会话有效
 -> 读取当前 accountId 的 RDB snapshot
 -> 校验 secretRef、model_file 和场景引用
 -> buildRuntime(snapshot)
 -> 发布 localReady/degraded，允许已有场景消费
 -> 后台 GET /api/v1/ai/config/bootstrap/
 -> 校验 revision/etag/默认模型/字段
 -> 事务替换 source=pro 行
 -> 重建 Runtime，发布 remoteReady
```

不得先清缓存再拉远端。网络失败保留最后有效配置；401 交给认证失效总线；字段解码失败保留旧快照并记录 requestId/revision，不显示成空 Provider。

### 4.3 必须区分的状态

| 状态 | 含义 | 页面行为 |
| --- | --- | --- |
| `loading/networkEvaluating` | Ability 或网络未完成 | 启动占位 |
| `signedOut` | 无有效会话 | 登录页，不读账号 AI |
| `authenticated` | 仅完成鉴权 | 继续账号准备，不放行旧 Runtime |
| `seeding` | 账号首次建立或 seed 升级 | 设置页 loading |
| `localReady` | RDB 快照和本地 Runtime 有效 | 可消费本地/上次 Pro |
| `refreshing` | Pro 请求中 | 继续旧 Runtime，显示刷新中 |
| `remoteReady` | 新 revision 已原子提交并发布 | 消费合并结果 |
| `degraded` | 网络失败或远端不兼容 | 保留有效配置并可重试 |
| `invalidated` | 401、登出、切换账号 | 取消请求、释放 Runtime、清理敏感引用 |

## 5. 本地数据模型与缓存边界

### 5.1 RDB 关系

```text
ai_account_meta(account_id)
  ├─ ai_provider(account_id, id, secret_ref)
  │    └─ ai_model(account_id, id, provider_id)
  │          ├─ ai_scenario_binding(account_id, scenario, model_id)
  │          └─ ai_model_file(account_id, model_id)
  ├─ ai_small_task(account_id, code)
  └─ ai_preferences(account_id)
```

当前 schema 位于 `entry/src/main/ets/Core/AI/Infrastructure/AIConfigSchema.ets`，七张表为 `ai_account_meta`、`ai_provider`、`ai_model`、`ai_scenario_binding`、`ai_small_task`、`ai_model_file`、`ai_preferences`。所有查询带 `account_id`，所有写入进入 `AppRdbWriteQueue`，所有 ResultSet 在 `finally` 中关闭。

### 5.2 字段规则

| 对象 | 关键字段 | 规则 |
| --- | --- | --- |
| `AIAccountMeta` | `accountId, schemaVersion, seedVersion, remoteRevision, remoteEtag, lastRemoteSyncAt, syncState` | 账号主状态，不放密钥 |
| `LocalProvider` | `id, accountId, name, company, kind, requestUrl, secretRef, isEnabled, position, source, updatedAt` | `id` 使用稳定字符串；Key 只存 HUKS 引用 |
| `LocalModel` | `id, providerId, name, displayName, baseModelName, modelType, capabilities, contextWindow, priceTier, isDefault, isEnabled, source` | 模型能力必须显式声明，不能猜测 |
| `LocalScenarioBinding` | `scenario, modelId, temperature, maxTokens, systemProvision, isDefault, position, enabled, relatedTaskCodes, aiToolScenarios, source` | 每场景最多一个有效默认项 |
| `LocalSmallTask` | `code, name, brief, prompt, icon, toolList, enabled, source` | 以 code 去重，删除前检查引用 |
| `LocalModelFile` | `modelId, path, sizeBytes, sha256, downloadState, downloadedAt, errorCode` | RDB 只存 metadata，二进制在应用沙箱 |
| `AIUserPreferences` | `defaultSource, allowNetwork, allowLocalModel, selectedProviderId, selectedModelId, extras` | 轻量偏好，可被 KV 镜像但 RDB 仍是 AI 主事实 |

### 5.3 KV Store 允许范围

允许：`ai.<accountId>.lastRemoteRevision`、`lastSyncState`、`allowNetwork`、`allowLocalModel`、最近选择的模型 ID。禁止：API Key、Token、完整 Provider/Model/Binding/SmallTask、GGUF、医疗上下文、prompt、Runtime adapter。

KV 变化只能产生 Repository refresh/invalidate 事件，不能直接改 RDB 行；Repository 必须校验账号、版本和引用后才应用。RDB 与 KV 冲突时，以通过引用校验且 `updatedAt/generation` 更新的 RDB 值为准并回写镜像。

### 5.4 Runtime 缓存

内存 `RuntimeSnapshot` 至少包含 `accountId`、`generation`、`builtAt`、`sourceRevision`、providers、models、bindings、smallTasks、preferences、health。adapter 通过 `secretRef` 向 `AIKeyStore` 取 Key，页面和普通日志永远看不到明文。响应返回时若 generation 已变化，丢弃结果。

## 6. “暂无厂商”与新增自定义供应商

### 6.1 空态判定

`loading` 显示加载；请求成功且 `providers.length == 0` 才显示“暂无厂商，请新增自定义供应商”；请求失败但有 `lastSnapshot` 显示旧数据和刷新失败；请求失败且无快照显示错误和重试，不伪造空列表。

### 6.2 新增字段

| 字段 | 类型 | 必填 | 存储 |
| --- | --- | --- | --- |
| `id` | string | 是 | `custom:<uuid>`，RDB 主键 |
| `name` | string | 是 | 1-64 字符 |
| `company` | string | 是 | 1-64 字符，模型归属 |
| `kind` | `api\|local` | 是 | 自定义供应商首期为 `api` |
| `requestUrl` | string | 是 | HTTPS URL |
| `secretRef` | string? | 否 | HUKS 引用 |
| `isEnabled` | boolean | 是 | 默认 true，测试失败不自动启用 |
| `position` | number | 是 | 账号内排序 |
| `source` | `custom` | 是 | 用户新增固定为 custom |

保存顺序：表单校验 URL/名称/公司/模型 -> 调用 Provider test -> 成功后 `AIKeyStore` 写 HUKS -> 获得 `secretRef` -> RDB 事务写 Provider/Model/Binding -> load snapshot -> Resolver -> Runtime -> 刷新页面。任一步失败都不能留下孤儿 Key 或半套目录；RDB 失败要删除本次新建的 HUKS secret。编辑已配置 Provider 只显示“已配置”，不回填旧 Key。

## 7. SparkService 接口契约

| 路由 | 方法 | 输入 | 用途 | 客户端策略 |
| --- | --- | --- | --- | --- |
| `/api/v1/auth/session/` | GET | Bearer | 会话恢复 | 401 进入统一失效 |
| `/api/v1/ai/config/bootstrap/` | GET | `platform=harmonyos`、可选 `client_version`、Bearer | Pro 场景/模型/小任务 | ETag/revision；成功才替换 Pro 行 |
| `/api/v1/ai/trial/status/` | GET | Bearer | 试用状态 | 失败不清空配置 |
| `/api/v1/ai/trial/apply/` | POST | `{note}` | 试用申请 | 不自动重试，按钮单飞 |
| `/api/v1/ai/providers/test-connection/` | POST | `{request_url, api_key, model}` | 自定义 Provider 测试 | 不重试，不记录请求体 |
| `/api/v1/device/register/` | POST | 设备登记 DTO | 账号准备前置 | 按启动协调器单飞/有限重试 |

服务端证据：`SparkService/ai_config/urls.py`、`views.py`、`services.py`、`models.py`、`tests.py`。bootstrap 由 `AIProviderKeyConfig`、`AIModelCatalog`、`AIScenarioModelBinding`、`SmallTask` 组装，HarmonyOS 不得根据 iOS 属性名另造接口。

bootstrap 处理顺序：统一加 Bearer/requestId/ETag -> decoder 兼容 snake/camel -> 校验 revision、场景、模型 identity、能力和默认项 -> 同 revision 不重写、旧 revision 拒绝 -> 新 revision 事务替换 `source=pro` -> 成功后重建 Runtime。网络/5xx 进入 degraded，字段不兼容保留旧快照，401 交给认证失效总线。

当前最大后端风险是 `SparkService/ai_config/services.py` 组装的模型行可能包含 `api_key`。推荐后端改为安全引用或服务端代理；若短期继续下发，必须限定 HTTPS、短暂内存、无日志、无持久化、无回显，并配套真实契约测试。

## 8. 修复拆分与验收

| 编号 | 优先级 | 修复 | 验收 |
| --- | --- | --- | --- |
| AI-START-001 | P0 | 增加 AI Runtime 就绪门禁和 account generation | 冷启动、登录、断网、恢复各只执行一次，未 ready 不进入主框架 |
| AI-START-002 | P0 | seed/RDB/Runtime 单飞、幂等、崩溃恢复 | 重复启动无重复默认项，无半套目录 |
| AI-PRO-001 | P0 | revision/ETag/空 payload/回退保护 | 旧 revision 不覆盖，新 revision 事务失败保留旧 Pro |
| AI-PRO-002 | P0 | 收敛 `api_key` 后端安全契约 | 数据库、KV、日志和快照无明文 Key |
| AI-UI-001 | P1 | 空态、新增 Provider、测试、保存、失败回滚 | 测试失败不写入，保存成功可见并完成 Runtime 重建 |
| AI-KV-001 | P1 | 固定 KV 白名单，RDB 为 AI 目录唯一事实 | 跨设备变化不覆盖 Provider/Model/Key |
| AI-RUNTIME-001 | P2 | GGUF 下载、校验、加载、推理、取消、删除闭环 | 文件 ready 不等于推理 ready，真实设备通过能力验收 |

关键用例：清空账号 RDB 后首次登录；已有快照断网启动；Pro revision 回退；bootstrap 空列表；Provider test 失败；RDB 事务失败；账号 A 切 B；401 失效；KV 轻量偏好冲突。每个用例同时检查 RDB、HUKS、Runtime、页面四者状态，不能只看按钮文案。

## 9. 当前结论

HarmonyOS 已具备 RDB、HUKS、Repository、Resolver、Runtime 和 SparkService API 的实现基础。本工单已落地的对齐项：

- 首次 seed 改为读取 `rawfile/ai/source/AISettings/{APIKeys,AllModels}.json`（UTF-8），校验后事务灌库；生产禁止 `emptyMinimal` 回退。
- `ensureSeeded` 按 accountId 单飞；seed / `buildRuntime` 失败不标记 prepared、不发布 `aiRuntimeReady`。
- Pro refresh：revision 单调校验、空 payload 不擦本地、`api_key` 短暂内存后写 HUKS 并清空。
- Providers 页区分 loading / empty / error / degraded；自定义供应商「测试 → HUKS → RDB → Runtime」原子保存与回滚。
- KV 白名单仅轻量偏好；RDB 仍为目录事实源。

仍为「部分对齐」：后端 `api_key` 安全契约需服务端收敛；GGUF ready≠可推理（P2）；真实设备 rawfile/中文 UTF-8/RDB 行数需联调验收。
