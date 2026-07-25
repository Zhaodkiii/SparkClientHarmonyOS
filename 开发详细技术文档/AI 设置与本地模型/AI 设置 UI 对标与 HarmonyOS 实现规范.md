# AI 设置 UI 对标与 HarmonyOS 实现规范

> 文档类型：跨客户端 UI 对标与实现规范  
> 参考端：`SparkClient` iOS 端 AI 设置场景配置  
> 目标端：`SparkClientHarmonyOS`  
> 核验日期：2026-07-21  
> 当前结论：HarmonyOS 当前页面功能入口已存在，但视觉结构与 iOS 参考明显不一致；本文件作为后续 UI 重构和截图验收的单一基线。

## 1. 对标范围与结论

### 1.1 参考资料

| 来源 | 内容 | 用途 |
| --- | --- | --- |
| `/Users/hua/Documents/project/Reference/LookHealthClient/SparkClient/总领文档/AI 设置与本地模型/AI 设置场景配置（厂商key、模型、默认模型配置、小任务）.md` | iOS 页面结构、页面行为、字段和状态矩阵 | 业务信息架构与交互事实 |
| iOS 参考截图 | “AI 场景配置”页面 | 视觉基线：背景、分组卡片、图标、层级、间距 |
| HarmonyOS 当前截图 | 当前 AI 设置页面 | 当前差异证据，不作为目标样式 |
| `SparkClientHarmonyOS/entry/src/main/ets/Projects/Features/AISettings/Presentation/AISettingsPage.ets` | 目标端当前页面 | 组件接入和待重构位置 |

### 1.2 视觉对标结论

当前 HarmonyOS 页面存在以下必须修正的差异：

1. 页面使用白色整页和横向分隔线，iOS 使用 `#F2F2F7` 浅灰背景和白色圆角分组卡片。
2. iOS 首页有“模型设置”和“工具/检索/知识”两个分组标题；HarmonyOS 当前仅有四个平铺入口。
3. iOS 每行有蓝色能力图标、主标题、副标题、右侧灰色 chevron；HarmonyOS 缺少图标和副标题，信息密度与层级不一致。
4. iOS 页面标题为大字号左对齐标题“AI 场景配置”；HarmonyOS 当前标题为“AI 设置”，需要区分业务标题与返回导航。
5. HarmonyOS 当前“返回设置”是内容区蓝色胶囊按钮；iOS 是左上角圆形返回按钮，不应作为业务列表第一行。
6. 同步状态、刷新、放弃、保存属于页面状态操作，不应挤占 iOS 首页的场景入口层级；应按照 iOS 参考确定位置和视觉权重。
7. 当前截图出现 `TypeError: undefined is not callable`，错误信息直接占用首页内容区域；目标设计必须提供稳定的错误横幅/状态区域，并且不破坏入口卡片布局。

### 1.3 状态定义

| 模块 | 当前 HarmonyOS 状态 | 目标 |
| --- | --- | --- |
| AI 设置入口 | 已接入 `SettingsPage` | 直接打开独立 AI 设置根视图，不嵌套外层业务 `Navigation` |
| 首页信息架构 | 部分实现 | 与 iOS 两个分组和四个入口完全对齐 |
| 视觉令牌 | 未建立 | 统一背景、卡片、间距、字体、图标和状态色 |
| Provider/模型/默认配置/小任务子页 | 已有 ArkUI 页面骨架 | 使用同一套 iOS 对标卡片和表单规范 |
| 加载/错误/空态 | 部分实现 | 失败可见、可重试、保留入口，不显示空白页 |
| 截图验收 | 未完成 | 固定同一设备尺寸、同一状态和对照项 |

## 2. 华为端目录设计

### 2.1 当前代码目录

```text
SparkClientHarmonyOS/entry/src/main/ets/Projects/Features/
├── Settings/
│   ├── SettingsPage.ets
│   └── SettingsAccountRouting.ets
└── AISettings/
    ├── Application/
    │   ├── AISettingsErrorLocalizer.ets
    │   ├── LoadSaveAISettingsUseCases.ets
    │   ├── ModelCatalogUseCases.ets
    │   ├── ProviderModelCatalogService.ets
    │   ├── ProviderUseCases.ets
    │   └── SmallTaskUseCases.ets
    └── Presentation/
        ├── AISettingsPage.ets
        ├── AISettingsRoutes.ets
        ├── AISettingsViewModel.ets
        ├── Providers/
        ├── Models/
        ├── Preferences/
        ├── SmallTasks/
        └── components/
```

### 2.2 UI 重构后的建议目录

```text
Projects/Features/AISettings/Presentation/
├── AISettingsPage.ets                 # 独立根页面：背景、标题、分组入口、状态区
├── AISettingsUiTokens.ets              # UI 常量；不放业务数据
├── AISettingsIcon.ets                  # 统一蓝色线性图标映射
├── AISettingsSection.ets               # 分组标题与白色圆角容器
├── AISettingsNavigation.ets            # 子页面导航和返回策略
├── components/
│   ├── AISettingsStatusBanner.ets      # 同步、错误、重试
│   ├── AISettingsActionBar.ets         # 刷新、放弃、保存
│   ├── AISettingsMenuRow.ets           # 图标、主标题、副标题、chevron
│   └── AISettingsEmptyState.ets        # 空数据和错误降级
├── Providers/
├── Models/
├── Preferences/
└── SmallTasks/
```

`AISettingsUiTokens.ets`、`AISettingsMenuRow.ets` 等为目标实现建议；本轮已修复 `EditModelPage` ArkUI 单根节点、`AISettingsIcon.size` 属性冲突、`NavigationAttribute.onBackPressed` API 不兼容和不存在系统符号资源的问题，并通过目标工程 `assembleHap`。页面业务闭环仍需真机和交互验收，不能仅因编译通过标记为整体验收完成。

### 2.3 页面层级

```text
设置 Tab
└── AI 设置根页面
    ├── 模型设置
    │   ├── 模型密钥
    │   │   ├── Provider 列表
    │   │   ├── 新增自定义供应商
    │   │   └── Provider 编辑
    │   ├── 模型
    │   │   ├── 模型列表
    │   │   ├── 添加在线模型
    │   │   ├── 编辑模型
    │   │   ├── 智能体编辑
    │   │   └── 本地模型入口
    │   └── 默认模型配置
    │       └── 场景绑定与模型选择
    └── 工具/检索/知识
        └── 小任务
            ├── 小任务列表
            ├── 新建/编辑小任务
            └── Prompt 输入与工具选择
```

## 3. 分层职责与请求链路

### 3.1 页面职责

```text
用户点击设置中的 AI 设置
        ↓
SettingsPage 切换到 AISettingsPage 根视图
        ↓
AISettingsPage 创建/获取 AISettingsViewModel
        ↓
ViewModel.load()
        ↓
LoadAISettingsUseCase
        ↓
AIConfigRepository
        ├── 账号级 RDB 本地快照
        ├── 首次账号种子
        ├── Secure/HUKS Key 状态
        └── SparkService Pro 配置刷新
        ↓
ViewModel 发布 ready / loading / error / empty 状态
        ↓
UI 只根据状态渲染，不直接操作 RDB、KV 或 HTTP
```

### 3.2 导航约束

1. `SettingsPage` 和 AI 设置页面不能形成“外层设置 `Navigation` + AI 页面内层业务 `Navigation`”的嵌套关系。
2. AI 设置根页面必须拥有自己的独立页面容器，返回由系统页面栈或明确的 `onClose` 回调处理。
3. AI 子页面使用 AI 页面自己的 `NavPathStack`，子页面不得再创建第二个业务导航根。
4. 路由名、参数和返回行为统一由 `AISettingsRoutes.ets` 与页面导航适配层管理。
5. 导航错误不得使页面变成空白节点；找不到目的地时显示错误状态并提供返回入口。

### 3.3 状态渲染优先级

```text
initializing
  → loading
      → ready / empty / failed
ready + dirty
  → saving
      → ready / saveFailed
```

页面渲染规则：

| 状态 | 页面展示 | 可用操作 |
| --- | --- | --- |
| `initializing` | 页面背景、标题骨架或加载指示 | 返回 |
| `loading` | 保留页面结构，状态区显示加载 | 返回；避免重复刷新 |
| `ready` | 完整 iOS 对标分组卡片 | 所有入口 |
| `empty` | 完整入口卡片 + 空数据提示 | 刷新、进入配置 |
| `failed` | 错误横幅 + 完整入口卡片 | 重试、返回 |
| `saving` | 保存按钮 loading/disabled | 取消导航，避免重复保存 |
| `saveFailed` | 错误横幅，保留草稿 | 重试保存、放弃 |

## 4. 核心关键技术与实现方案

### 4.1 iOS 视觉基线

| 令牌 | 目标值 | 用途 |
| --- | --- | --- |
| 页面背景 | `#F2F2F7`，随系统浅色/深色主题映射 | 页面底色，不使用纯白铺满 |
| 卡片背景 | `#FFFFFF` | 分组容器 |
| 主文字 | `#111111` 或系统 primary | 标题、主行文案 |
| 辅助文字 | `#8E8E93` | 副标题、分组标题、状态辅助信息 |
| 强调色 | iOS blue，约 `#007AFF` | 图标、可操作文字、主按钮 |
| 成功色 | 系统 green | 保存成功、连接成功 |
| 错误色 | 系统 red | 错误状态和字段校验 |
| 分组圆角 | 约 `28vp` | 白色卡片外轮廓 |
| 页面水平边距 | `24vp` | 标题、分组卡片左右边界 |
| 分组间距 | `28vp` 至 `36vp` | “模型设置”与“工具/检索/知识”之间 |
| 行最小高度 | `84vp` 至 `96vp` | 保证主标题、副标题和图标垂直舒适 |
| 卡片内边距 | `20vp` 至 `24vp` | 图标与文字不贴边 |
| 分割线 | `1px`、低对比度 | 仅用于卡片内部行分隔 |

数值是 iOS 截图对标起点，最终以目标设备截图和字体度量微调；不可把 HarmonyOS 默认 `List` 分隔线直接当作最终设计。

### 4.2 首页目标结构

```text
┌────────────────────────────────────────────┐
│ 状态栏                                     │
│                                            │
│  ‹                                          │  独立页面返回按钮
│                                            │
│  AI 场景配置                                │  大标题
│                                            │
│  模型设置                                   │  分组标题
│  ┌────────────────────────────────────────┐ │
│  │  🔑  模型密钥     厂商密钥与端点      › │ │
│  │  ────────────────────────────────────  │ │
│  │  ▱   模型         模型目录与能力开关  › │ │
│  │  ────────────────────────────────────  │ │
│  │  ☷   默认模型配置 按场景配置本地或 Pro› │ │
│  └────────────────────────────────────────┘ │
│                                            │
│  工具/检索/知识                             │  分组标题
│  ┌────────────────────────────────────────┐ │
│  │  ☑   小任务       维护本地小任务      › │ │
│  └────────────────────────────────────────┘ │
│                                            │
└────────────────────────────────────────────┘
```

页面第一屏必须能同时看见：页面标题、模型设置卡片、工具/检索/知识标题和小任务卡片的一部分；不得使用大面积空白把入口推到屏幕底部。

### 4.3 统一入口行组件

每个 `AISettingsMenuRow` 固定包含：

| 区域 | 内容 | 规则 |
| --- | --- | --- |
| 左侧图标 | 模型密钥、模型、滑杆、小任务对应线性图标 | 同一蓝色、同一视觉尺寸，不使用 emoji 代替 |
| 主标题 | `模型密钥`、`模型`、`默认模型配置`、`小任务` | 16–18vp，单行优先 |
| 副标题 | 对应 iOS 描述 | 14–15vp，辅助灰色，允许最多两行 |
| 右侧动作 | chevron `›` 或系统右箭头图标 | 灰色、垂直居中、不可点击区域独立处理 |
| 行点击区 | 整行 | 最小触控高度不低于 48vp |
| 分隔线 | 卡片内部 | 不延伸到卡片圆角外 |

禁止：用四个独立白色矩形替代分组卡片；用文字 `>` 代替正式图标；把副标题删除后声称与 iOS 一致。

### 4.4 ArkUI 组件映射

| iOS 结构 | HarmonyOS 目标映射 | 实现要求 |
| --- | --- | --- |
| `ScrollView` | `Scroll` | 页面内容可滚动，背景延伸到安全区 |
| `VStack` | `Column` | 只负责布局，不承载业务逻辑 |
| 分组 `Section` | `Column` + section title + white `Column` | 卡片统一圆角、内边距和分隔线 |
| `HStack` | `Row` | 图标、文字、chevron 使用固定尺寸和权重 |
| SF Symbols | 项目图标资源或已核验系统图标 | 不用 emoji；图标资源需加入 resources 并通过构建校验 |
| `NavigationStack` | 一个 AI 页面级 `Navigation` | 不在 Settings 的自定义目的地里再套一层 |
| `List` | `Scroll` + 自定义卡片 | 避免系统 List 默认背景、行高和分割线污染视觉 |
| `Alert` | `AlertDialog` 或页面状态横幅 | 错误内容脱敏，不能出现 Key/Token |
| `ProgressView` | `LoadingProgress`/系统加载组件 | 加载不破坏卡片布局 |

### 4.5 当前截图错误的 UI 处理

当前错误 `TypeError: undefined is not callable` 不能直接作为裸红色文本插在同步状态下面。目标状态如下：

```text
┌────────────────────────────────────────┐
│  同步状态                               │
│  本地配置已加载 / Pro 配置未同步         │
│  [重试]                                  │
└────────────────────────────────────────┘
```

错误状态必须满足：

1. 用户可理解：显示“AI 配置加载失败，请重试”，技术错误只进入脱敏日志。
2. 用户可操作：提供“重试”按钮；如果已有本地快照，保留入口卡片和本地内容。
3. 不泄露敏感字段：不显示 API Key、请求 URL query、响应 body 或堆栈。
4. 不阻断页面结构：入口卡片保持可见，避免错误区域把首页挤成空白。

## 5. 接口契约与数据模型

本 UI 文档不重新定义 AI 数据模型。底层模型、RDB 表、KV 镜像、Pro overlay、Runtime 和 SparkService 交互统一引用：

`AI 配置生命周期与本地、Pro 统一消费详细技术方案.md`

页面只消费 ViewModel 对外状态：

| ViewModel 状态 | UI 用途 | 不可做的事 |
| --- | --- | --- |
| `ready` | 显示入口卡片 | 不直接读取 RDB |
| `loading` | 加载指示和按钮禁用 | 不重复创建 Repository |
| `errorMessage` | 脱敏错误横幅 | 不展示原始异常对象 |
| `syncStateText` | 同步状态摘要 | 不在页面自行判断 Pro 状态 |
| `hasUnsavedChanges` | 放弃/保存按钮状态 | 不在组件中比较完整快照 |
| `saving` | 保存按钮 loading | 不重复触发保存请求 |

### 5.1 页面到业务命令映射

| UI 操作 | ViewModel 命令 | 持久化/运行时效果 |
| --- | --- | --- |
| 点击模型密钥 | 打开 Provider 页面 | 读取 Provider 列表和 Key 配置状态 |
| 点击模型 | 打开模型页 | 读取本地/Pro 合并模型 |
| 点击默认模型配置 | 打开场景绑定页 | 更新场景 source 和 model binding |
| 点击小任务 | 打开小任务页 | 维护本地小任务并更新引用 |
| 点击刷新 Pro 配置 | `refreshRemote()` | 调 SparkService，替换 Pro overlay，重建 Runtime |
| 点击放弃 | `discard()` | 草稿回滚，不修改持久化快照 |
| 点击保存 | `save()` | 保存 RDB、镜像 KV、更新 Runtime |
| 点击重试 | `load()` 或 `refreshRemote()` | 保留旧快照，失败不清空入口 |

## 6. iOS-HarmonyOS 功能对照矩阵

| UI 功能 | iOS 参考 | HarmonyOS 当前 | HarmonyOS 目标 | 验收依据 |
| --- | --- | --- | --- | --- |
| 页面标题 | `AI 场景配置` 大标题 | `AI 设置` 系统标题 | 大标题左对齐，文案与业务统一 | 截图视觉比对 |
| 页面背景 | 浅灰系统背景 | 白色 | `#F2F2F7`/主题背景 | 像素/颜色检查 |
| 模型设置分组 | 白色大圆角卡片 | 平铺 ListItem | 自定义卡片容器 | 圆角和分组检查 |
| 工具/检索/知识分组 | 单独标题 + 小任务卡片 | 四行连续列表 | 单独标题和卡片 | 信息架构检查 |
| 模型密钥 | 图标 + 标题 + 副标题 + chevron | 仅标题和 chevron | 完整 MenuRow | 组件字段检查 |
| 模型 | 图标 + 标题 + 副标题 + chevron | 仅标题和 chevron | 完整 MenuRow | 组件字段检查 |
| 默认模型配置 | 图标 + 标题 + 副标题 + chevron | 仅标题和 chevron | 完整 MenuRow | 组件字段检查 |
| 小任务 | 单独分组卡片 | 仅平铺入口 | 完整 MenuRow | 组件字段检查 |
| 返回 | 圆形返回图标 | 内容区蓝色胶囊按钮 | 页面导航返回按钮 | 交互和截图检查 |
| 错误 | Alert/状态处理 | 红色裸文本 | 错误横幅 + 重试 | 错误状态检查 |
| 子页面 | iOS 导航栈 | ArkUI 页面骨架 | 同层级、同样式卡片/表单 | 页面逐项截图 |

## 7. 示例工程与官方文档参考结论

### 7.1 当前项目示例

| 示例 | 路径 | 可借鉴 | 不可直接复制 |
| --- | --- | --- | --- |
| HarmonyOS 当前设置导航 | `/Users/hua/Documents/project/Reference/LookHealthClient/SparkClientHarmonyOS/entry/src/main/ets/Projects/Features/Settings/SettingsPage.ets` | 设置 Tab、账号行和页面切换入口 | 当前白色 List 视觉不能作为 iOS 对标结果 |
| HarmonyOS 当前 AI 页面 | `/Users/hua/Documents/project/Reference/LookHealthClient/SparkClientHarmonyOS/entry/src/main/ets/Projects/Features/AISettings/Presentation/AISettingsPage.ets` | ViewModel 状态、AI 子路由、保存/刷新命令 | 当前 `List` 和内容区返回按钮需要视觉重构 |
| iOS AI 场景配置文档 | `/Users/hua/Documents/project/Reference/LookHealthClient/SparkClient/总领文档/AI 设置与本地模型/AI 设置场景配置（厂商key、模型、默认模型配置、小任务）.md` | 页面职责、按钮副作用、状态矩阵 | 文档草图不能替代真实 iOS 代码核验 |

### 7.2 官方能力核验方向

实现时按目标 SDK/API Level 查证：

- ArkUI `Navigation`、`NavPathStack` 和页面生命周期。
- ArkUI `Scroll`、`Column`、`Row`、自定义组件参数和资源图标。
- `resources` 图标、颜色和多语言资源引用。
- 深色模式、字体缩放、安全区和无障碍触控尺寸。

官方资料入口：

- [HarmonyOS 开发文档中心](https://developer.huawei.com/consumer/cn/doc/)
- [ArkUI Navigation API 参考](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/arkui-ts/ts-basic-components-navigation)
- [资源分类与访问](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/resource-categories-and-access)

## 8. 实施拆分与验收

### 8.1 实施顺序

1. 固定页面标题、返回方式和导航层级，先消除嵌套导航。
2. 建立 UI tokens：背景、卡片、圆角、边距、字体、图标和状态色。
3. 把首页从系统 `List` 改成 `Scroll + Section + MenuRow`。
4. 补齐四个首页入口的图标和副标题。
5. 调整同步状态、刷新、放弃、保存为独立状态区域，不破坏入口卡片。
6. 按 iOS 文档逐页重构 Provider、模型、默认模型配置和小任务页面。
7. 为每个页面补充加载、空数据、失败、保存、取消和返回状态。
8. 在真实设备上按同一分辨率截图，对照 iOS 截图逐项验收。

### 8.2 首页验收标准

- [ ] 页面背景不是纯白铺满，分组卡片为白色圆角容器。
- [ ] 页面标题、分组标题、主标题、副标题的层级与 iOS 一致。
- [ ] “模型设置”包含模型密钥、模型、默认模型配置三行。
- [ ] “工具/检索/知识”包含小任务一行。
- [ ] 每行都有蓝色图标、主标题、副标题、右侧 chevron。
- [ ] 页面第一屏能看见两个分组，不出现大面积空白。
- [ ] 返回按钮位于页面导航区域，不作为列表第一行。
- [ ] 加载失败不为空白，显示脱敏错误和重试操作。
- [ ] 保存/放弃仅在有未保存修改时可用。
- [ ] API Key、URL query 和异常堆栈不会出现在 UI。
- [ ] 点击每一行都能进入正确子页面，返回后首页状态不丢失。

### 8.3 截图验收规格

截图必须同时保留：

1. 状态栏和安全区边界。
2. 页面标题和返回按钮。
3. 两个分组标题及完整入口卡片。
4. 加载成功、加载失败、空数据三种状态至少各一张。
5. 同一设备尺寸、同一字体缩放、同一主题模式下与 iOS 对照。

截图命名建议：

```text
ai-settings-harmony-light-ready.png
ai-settings-harmony-light-loading.png
ai-settings-harmony-light-error.png
ai-settings-ios-reference-light.png
```

## 9. 风险与待确认项

| 风险/待确认项 | 影响 | 处理方式 |
| --- | --- | --- |
| iOS 标题实际为“AI 场景配置”，HarmonyOS 资源当前为“AI 设置” | 视觉和产品文案不一致 | 由产品确认最终文案；UI 基线暂按 iOS“AI 场景配置” |
| iOS 图标为 SF Symbols，HarmonyOS 没有一对一资源 | 图标形状可能不一致 | 使用项目资源绘制/导入同语义线性图标，并保留蓝色和尺寸一致 |
| iOS 卡片圆角和系统字体会随设备变化 | 无法只靠固定像素完全复制 | 使用 vp、系统字体和截图基准校准，不锁死屏幕像素 |
| HarmonyOS 系统导航返回行为与 iOS 不同 | 返回路径可能出现重复页面 | 页面级栈只保留一层，统一处理 `onClose` 和子页 pop |
| AI 配置加载失败的真实后端/RDB原因未从当前日志确认 | UI 可显示错误但根因仍可能存在 | 保留脱敏错误事件和重试；另行核验 RDB、账号状态、SparkService 响应 |
| 当前页面代码已有功能骨架但未达到视觉验收 | 代码存在不能代表 UI 已对齐 | 在完成真实设备截图前标记“部分实现”，不得标记“完全一致” |

本文件是 UI 下游规范，不重新定义 AI 配置生命周期、RDB、KV、Pro 数据模型和 Runtime 合并规则；这些内容统一以上游《AI 配置生命周期与本地、Pro 统一消费详细技术方案》为准。

## 附录 A：全部 AI 设置页面与 Demo 对标目录

本附录把 AI 设置功能涉及的页面全部列入同一份 UI 文档。Demo 只用于验证 ArkUI 的布局、交互和状态表达方式，不代表 LookHealth 的业务模型、接口、权限或视觉最终值。

### A.1 Demo 参考总表

| UI 能力 | Demo 参考文件 | 可借鉴结论 | 不能直接复制 |
| --- | --- | --- | --- |
| 分组设置首页 | `/Users/hua/Documents/project/Reference/LookHealthClient/SparkClientHarmonyOS/开发详细技术文档/agc-template-market-harmonyos-demos-main/ToolsTemplate/AIOffice/components/business_setting/src/main/ets/pages/SettingPage.ets` | `NavDestination + NavHeaderBar + Scroll + SettingCard` 的页面组合；底部操作区可独立布局 | Demo 的设置数据、路由和账号逻辑与 AI 无关 |
| 图标/副标题/开关/选择器行 | `/Users/hua/Documents/project/Reference/LookHealthClient/SparkClientHarmonyOS/开发详细技术文档/agc-template-market-harmonyos-demos-main/ToolsTemplate/AIOffice/components/business_setting/src/main/ets/components/SettingCard.ets` | 行内图标、主标题、副标题、开关、选择值、右箭头和按压态 | Demo 使用 `SettingItem`，目标端必须使用 AI ViewModel 状态 |
| 响应式设置卡片 | `/Users/hua/Documents/project/Reference/LookHealthClient/SparkClientHarmonyOS/开发详细技术文档/agc-template-market-harmonyos-demos-main/ShoppingTemplate/Express/components/app_setting/src/main/ets/views/SettingView.ets`、`.../components/SettingCard.ets` | `GridRow/GridCol`、页面边距、分组标题、卡片圆角和 lanes | 不复制 Express 的主题色、退出登录和持久化 |
| 简化设置列表 | `/Users/hua/Documents/project/Reference/LookHealthClient/SparkClientHarmonyOS/开发详细技术文档/agc-template-market-harmonyos-demos-main/HouseAndHomeTemplate/HomeDecoration/features/mine/src/main/ets/pages/SettingsPage.ets` | 浅灰背景、白色圆角入口卡片、标题和右箭头、底部操作区 | Demo 没有 AI 状态和 Pro 同步语义 |
| 返回标题栏 | `/Users/hua/Documents/project/Reference/LookHealthClient/SparkClientHarmonyOS/开发详细技术文档/agc-template-market-harmonyos-demos-main/ToolsTemplate/AIOffice/components/module_feedback/src/main/ets/components/NavHeaderBar.ets` | 圆形返回按钮、系统 chevron、无标题栏自定义页面 | 图标资源和标题字号需按本项目资源重做 |
| 表单与字段校验 | `/Users/hua/Documents/project/Reference/LookHealthClient/SparkClientHarmonyOS/开发详细技术文档/agc-template-market-harmonyos-demos-main/HouseAndHomeTemplate/HomeDecoration/components/module_decoration_form/src/main/ets/components/FormDecoration.ets` | 分组标题、图标 + 输入框、Grid 选项、提交前校验、Toast 提示 | Demo 的房屋字段和 Toast 文案不能迁移到 AI |
| Sheet 表单 | `/Users/hua/Documents/project/Reference/LookHealthClient/SparkClientHarmonyOS/开发详细技术文档/agc-template-market-harmonyos-demos-main/ToolsTemplate/AIOffice/components/business_setting/src/main/ets/pages/SettingPersonal.ets` | `bindSheet`、输入草稿、取消/确定、页面状态与 Sheet 状态分离 | API Key 必须使用安全输入和 HUKS，不可照搬普通文本字段 |
| 选择弹窗 | `/Users/hua/Documents/project/Reference/LookHealthClient/SparkClientHarmonyOS/开发详细技术文档/agc-template-market-harmonyos-demos-main/ToolsTemplate/AIOffice/components/business_setting/src/main/ets/components/SettingSelectDialog.ets` | `SelectDialog` 的单选、确认、取消和自动关闭 | 选项必须来自 AI 模型/场景快照，不能使用 Demo 静态值 |
| 卡片内选择器 | `/Users/hua/Documents/project/Reference/LookHealthClient/SparkClientHarmonyOS/开发详细技术文档/agc-template-market-harmonyos-demos-main/ShoppingTemplate/Express/components/app_setting/src/main/ets/components/SettingSelectDialog.ets` | Popup 选择列表、当前项勾选、分隔线和按压态 | 不用动态 `Record` 或未声明对象承载 AI 选项 |
| 筛选/模型搜索 | `/Users/hua/Documents/project/Reference/LookHealthClient/SparkClientHarmonyOS/开发详细技术文档/agc-template-market-harmonyos-demos-main/HouseAndHomeTemplate/HomeDecoration/components/module_filter_list/src/main/ets/components/FilterList.ets`、`.../CommonPicker.ets` | 顶部筛选项、Drawer、Grid 选择、选中态和结果回调 | 目标端要增加 Provider、能力、来源和搜索关键字的业务过滤 |
| 抽屉/Prompt 编辑 | `/Users/hua/Documents/project/Reference/LookHealthClient/SparkClientHarmonyOS/开发详细技术文档/agc-template-market-harmonyos-demos-main/HouseAndHomeTemplate/HomeDecoration/components/module_filter_list/src/main/ets/components/Drawer.ets` | Drawer 控制器、打开/关闭回调、内容区独立渲染 | Prompt 草稿必须受 AI 小任务保存/取消语义控制 |
| 列表加载/空态/卡片 | `/Users/hua/Documents/project/Reference/LookHealthClient/SparkClientHarmonyOS/开发详细技术文档/agc-template-market-harmonyos-demos-main/ToolsTemplate/AIOffice/components/module_feedback/src/main/ets/pages/RecordListPage.ets`、`.../components/Empty.ets`、`.../components/RecordCard.ets` | loading、数据列表、空态、卡片、滚动和安全区边距的完整分支 | Demo 的反馈图片和网络模型不能作为 AI 数据模型 |
| 下载/进度对话框 | `/Users/hua/Documents/project/Reference/LookHealthClient/SparkClientHarmonyOS/开发详细技术文档/agc-template-market-harmonyos-demos-main/MovieTVAndLivestreamingTemplate/VideoEditor/components/check_app_update/src/main/ets/components/FindNewVersion.ets` | 弹窗内展示版本/大小/详情和稍后处理/立即执行动作 | 本地模型安装必须接入真实文件服务、校验和取消状态 |

### A.2 页面清单与目标对标

| 编号 | 目标端页面文件 | iOS 对应页面/入口 | 页面类型 | 必须包含 |
| --- | --- | --- | --- | --- |
| 1 | `Presentation/AISettingsPage.ets` | `AISettingsView` | 根页面 | 大标题、两段分组、四个入口、同步状态、刷新/放弃/保存、加载和错误 |
| 2 | `Presentation/Providers/ProvidersPage.ets` | `APIKeysSettingsView` | Provider 列表 | 试用卡片、Provider 分组、Key 状态、开关、下拉刷新、空态 |
| 3 | `Presentation/Providers/AddCustomProviderPage.ets` | `AddCustomProviderSheet` | Sheet 表单 | 名称、Key、URL、URL 补全、校验、取消、保存 |
| 4 | `Presentation/Providers/ProviderEditorPage.ets` | `ProviderSettingsEditorView` | Provider 编辑 | Provider 开关、URL、Key、隐私政策、模型列表、测试模型、API 测试 |
| 5 | `Presentation/Providers/ProviderPrivacyPolicyPage.ets` | `ProviderPrivacyPolicyWebSheet` | Web/协议页 | 标题、返回、加载、网页失败、重试、关闭 |
| 6 | `Presentation/Models/ModelsPage.ets` | `ModelsSettingsView` / `ModelManagementView` | 模型目录 | Provider 分组、来源、能力、启用开关、搜索/过滤、添加、删除 |
| 7 | `Presentation/Models/AddOnlineModelPage.ets` | `AddOnlineModelSheet` | Sheet 表单 | 系统名称、显示名、Provider、能力、价格/来源、隐私同意、提交状态 |
| 8 | `Presentation/Models/EditModelPage.ets` | `ModelManagementView` 编辑入口 | 编辑页 | 显示名、简介、图标入口、启用状态、删除、保存/取消 |
| 9 | `Presentation/Models/AgentEditorPage.ets` | `ModelsSettingsAgentSheet` | Agent 表单 | Agent 名称、图标、基座模型、系统 Prompt、关联小任务、工具和场景 |
| 10 | `Presentation/Models/ModelIconPickerPage.ets` | Agent/模型图标选择 | 选择页/Sheet | 图标网格、当前选中、确认、取消、无资源空态 |
| 11 | `Presentation/Models/LocalModelDownloadPage.ets` | 本地模型入口/下载流程 | 下载页 | 本地能力说明、文件大小、进度、暂停/取消、校验、安装完成、失败重试 |
| 12 | `Presentation/Preferences/DefaultModelPreferencesPage.ets` | `AIModelPreferencesView` | 场景配置 | 场景列表、默认来源、本地/Pro、当前模型、无模型引导 |
| 13 | `Presentation/Preferences/ScenarioBindingPage.ets` | `ModelScenarioBindingsEditorView` | 场景绑定 | 场景标题、已绑定模型、添加、编辑、默认唯一性、删除确认 |
| 14 | `Presentation/Preferences/ToolSelectionPage.ets` | 模型/场景工具选择 | 多选页 | 工具列表、已选数量、搜索/分组、确认、取消 |
| 15 | `Presentation/Preferences/SmallTaskSelectionPage.ets` | Agent 关联小任务选择 | 多选页 | 小任务列表、已选状态、搜索、确认、未保存提示 |
| 16 | `Presentation/SmallTasks/SmallTasksPage.ets` | `SmallTasksSettingsView` | 小任务列表 | 本地小任务、空态、添加、编辑、删除确认、关联数量 |
| 17 | `Presentation/SmallTasks/SmallTaskEditorPage.ets` | `SmallTaskEditorView` | 小任务编辑 | 图标、名称、简介、Prompt、工具、语音、模型/场景关联、保存校验 |
| 18 | `Presentation/SmallTasks/PromptInputDrawerPage.ets` | Prompt 编辑 Sheet/Drawer | 抽屉编辑 | Prompt 多行输入、插入变量、字数/空值校验、取消、应用 |

> 第 15 项归属于 `Presentation/Preferences/SmallTaskSelectionPage.ets`。上表路径以目标工程当前文件为准，不应据此创建重复目录。

### A.3 页面 1：AI 设置根页面

#### Plain text UI 草图

```text
页面背景：system background secondary / #F2F2F7
┌──────────────────────────────────────────────┐
│ 〈                                           │  圆形返回按钮
│                                              │
│ AI 场景配置                                  │  大标题
│                                              │
│ 模型设置                                     │  section title
│ ┌──────────────────────────────────────────┐ │
│ │ [key] 模型密钥                           │ │
│ │       厂商密钥与端点                  >  │ │
│ │ ───────────────────────────────────────  │ │
│ │ [layers] 模型                            │ │
│ │          模型目录与能力开关           >  │ │
│ │ ───────────────────────────────────────  │ │
│ │ [sliders] 默认模型配置                  │ │
│ │           按场景配置本地或 Pro        >  │ │
│ └──────────────────────────────────────────┘ │
│                                              │
│ 工具/检索/知识                               │
│ ┌──────────────────────────────────────────┐ │
│ │ [task] 小任务                            │ │
│ │        维护本地小任务并关联模型       >  │ │
│ └──────────────────────────────────────────┘ │
└──────────────────────────────────────────────┘
```

Demo 对标：AIOffice `SettingPage.ets` + `SettingCard.ets`；Express `SettingView.ets` + `SettingCard.ets`。目标组合为 `Scroll + Column + SectionHeader + AISettingsMenuCard`，不直接使用系统 `List` 的默认背景。

### A.4 页面 2–5：模型密钥与 Provider

#### Provider 列表

```text
┌──────────────────────────────────────────────┐
│ 〈                 模型密钥                 + │
│                                              │
│ [Pro 试用卡片：状态、剩余时间、申请/查看]      │
│                                              │
│ 模型厂商                                     │
│ ┌──────────────────────────────────────────┐ │
│ │ [provider] 302.AI             已配置   > │ │
│ │ ───────────────────────────────────────  │ │
│ │ [provider] 推理时代          未配置   > │ │
│ │ ───────────────────────────────────────  │ │
│ │ [provider] Anthropic         已关闭   > │ │
│ └──────────────────────────────────────────┘ │
│ 下拉刷新区域                                 │
└──────────────────────────────────────────────┘
```

Demo 对标：AIOffice `SettingCard.ets` 的图标/副标题/开关行，Express `SettingCard.ets` 的卡片内分隔线和选择状态；Provider 开关必须由 Key 状态和 ViewModel 命令控制。

#### 新增 Provider Sheet

```text
┌──────────────────────────────────────────────┐
│ 取消          新增自定义供应商             保存│
├──────────────────────────────────────────────┤
│ 供应商名称  [                              ] │
│ API Key     [••••••••••••••••••••••••      ] │
│ 请求地址    [https://                       ] │
│             [补全 /v1/chat/completions]      │
│ 错误：名称、Key、地址均不能为空               │
└──────────────────────────────────────────────┘
```

Demo 对标：AIOffice `SettingPersonal.ets` 的 `bindSheet` 表单和 `FormDecoration.ets` 的字段校验；Key 使用 `InputType.Password`，保存前通过 AI 专用 validator，取消不创建数据。

#### Provider 编辑

```text
┌──────────────────────────────────────────────┐
│ 〈             Provider 编辑               保存│
│ [switch] Anthropic                            │
│ 请求地址  https://...                         │
│ API Key   ••••••••••••••••                    │
│ 查看隐私政策                                  │
│                                              │
│ 该厂商模型                                  + │
│ [model] Claude 3.7              [开关]      > │
│ [model] Claude 3.5              [开关]      > │
│                                              │
│ API 测试                                      │
│ 测试模型    Claude 3.7                     > │
│ [测试连接]   未测试/测试中/成功/失败            │
└──────────────────────────────────────────────┘
```

Demo 对标：AIOffice `SettingCard.ets` 的 switch/select 场景、`SettingSelectDialog.ets` 的选择弹窗；表单字段布局参考 `FormDecoration.ets`。不能复制 Demo 的公开用户资料字段。

#### Provider 隐私政策

```text
┌──────────────────────────────────────────────┐
│ 〈              隐私政策                     │
├──────────────────────────────────────────────┤
│ WebView 加载中                               │
│                                              │
│ 加载失败：无法打开隐私政策                    │
│ [重试]                                      │
└──────────────────────────────────────────────┘
```

Demo 对标：Demo 中的 `ProtocolWebView.ets` 类协议页面；生产页面必须使用 Provider 快照中的已核验 URL，URL 不存在时显示不可用状态，不把异常 URL 展示给用户。

### A.5 页面 6–11：模型、Agent 与本地模型

#### 模型目录

```text
┌──────────────────────────────────────────────┐
│ 〈                  模型                    + │
│ [搜索模型................................]   │
│ [全部] [文本] [向量] [语音] [本地] [Pro]       │
│                                              │
│ 已启用模型                                    │
│ ┌──────────────────────────────────────────┐ │
│ │ [model] GPT / Doubao         文本   [开关]│ │
│ │ [model] Embedding             向量   [开关]│ │
│ └──────────────────────────────────────────┘ │
│ 未启用/远端可用                               │
│ [model] deepseek-r1              [添加]     │
└──────────────────────────────────────────────┘
```

Demo 对标：HomeDecoration `FilterList.ets` + `CommonPicker.ets` 的筛选和 Drawer；Feedback `RecordListPage.ets` 的 loading/list/empty 分支。搜索只过滤展示，不改变快照。

#### 添加在线模型

```text
┌──────────────────────────────────────────────┐
│ 取消          添加在线模型                  添加│
├──────────────────────────────────────────────┤
│ 系统名称    [用于 API 请求                   ] │
│ 显示名称    [用户看到的名称                  ] │
│ Provider    [选择厂商                       >] │
│ 能力        [文本] [向量] [语音]              │
│ 来源        本地 / Pro                        │
│ 隐私同意    [开关]                             │
│ 提交中：LoadingProgress                       │
└──────────────────────────────────────────────┘
```

Demo 对标：`FormDecoration.ets` 的字段分组、输入校验和底部保存按钮；`SettingSelectDialog.ets` 的 Provider 单选。提交中必须锁定按钮并防止重复请求。

#### 编辑模型与智能体编辑

```text
编辑模型
┌──────────────────────────────────────────────┐
│ 〈                 编辑模型                 保存│
│ 模型名称    GPT-4o                            │
│ 显示名称    [                                ] │
│ 简介        [多行文本                         ] │
│ 图标        [当前图标                       >] │
│ 启用        [开关]                            │
│ [删除模型]                                    │
└──────────────────────────────────────────────┘

编辑智能体
┌──────────────────────────────────────────────┐
│ 〈                 编辑智能体               保存│
│ 图标        [图标选择                       >] │
│ 名称        [                                ] │
│ 基座模型    [选择模型                       >] │
│ 系统 Prompt [多行文本                         ] │
│ 关联小任务  [0 个                           >] │
│ 工具/场景   [选择                           >] │
└──────────────────────────────────────────────┘
```

Demo 对标：AIOffice `SettingPersonal.ets` 的 Sheet 输入和 `FormDecoration.ets` 的分组表单；关联小任务和工具使用卡片选择页，不在编辑页内塞入长列表。

#### 图标选择

```text
┌──────────────────────────────────────────────┐
│ 〈                 选择图标                 确定│
│ [○] [○] [✓] [○] [○]                           │
│ [○] [○] [○] [○] [○]                           │
│ [○] [○] [○] [○] [○]                           │
└──────────────────────────────────────────────┘
```

Demo 对标：`CommonPicker.ets` 的选中项和网格布局；图标资源必须来自工程资源目录，不能使用未声明的动态图片 URL。

#### 本地模型下载/安装

```text
┌──────────────────────────────────────────────┐
│ 〈                 本地模型                 │
│ 模型名称       本地推理模型                  │
│ 文件大小       1.2 GB                        │
│ SHA-256        校验值隐藏/可展开              │
│                                              │
│ 下载中   ███████████░░░  72%                  │
│ [暂停]                         [取消]         │
│                                              │
│ 下载完成 → 校验中 → 已安装                   │
│ 失败：文件校验失败              [重试]        │
└──────────────────────────────────────────────┘
```

Demo 对标：`FindNewVersion.ets` 的信息确认弹窗、项目中 `CommonLoading.ets`/`FullLoadingComponent.ets` 的加载表达。实际下载必须接入 `LocalModelFileService`，支持取消、断点/重试策略和文件校验。

### A.6 页面 12–15：默认模型、场景绑定与工具选择

#### 默认模型配置

```text
┌──────────────────────────────────────────────┐
│ 〈               默认模型配置               │
│ 默认来源    自动 / 本地 / Pro                │
│                                              │
│ 对话                                         │
│ ┌──────────────────────────────────────────┐ │
│ │ 当前模型       GPT-4o                  > │ │
│ │ 来源           Pro                        │ │
│ └──────────────────────────────────────────┘ │
│ 向量                                         │
│ [选择可用 Embedding 模型                    >] │
│ 语音                                         │
│ [暂无模型，请先配置模型密钥                 ] │
└──────────────────────────────────────────────┘
```

Demo 对标：Express `SettingCard.ets` 的 select 场景、AIOffice `SettingSelectDialog.ets` 的单选确认、HomeDecoration `CommonPicker.ets` 的选中态。场景候选必须来自统一 Resolver 可消费模型。

#### 场景绑定

```text
┌──────────────────────────────────────────────┐
│ 〈                 场景绑定                 + │
│ 场景：对话                                   │
│ ┌──────────────────────────────────────────┐ │
│ │ GPT-4o          默认   Pro             > │ │
│ │ Claude          可用   本地             > │ │
│ └──────────────────────────────────────────┘ │
│ [添加模型绑定]                               │
│ 默认约束：同一场景只能有一个默认模型           │
└──────────────────────────────────────────────┘
```

Demo 对标：`SettingCard.ets` 的行点击和开关；使用 `CommonPicker` 的选择确认风格。删除绑定要有确认，并处理默认绑定自动迁移或清空。

#### 工具选择与小任务选择

```text
┌──────────────────────────────────────────────┐
│ 〈                 选择工具                 完成│
│ 已选择 2 项                                   │
│ [搜索工具................................]    │
│ [✓] 检索                                      │
│ [ ] 知识库                                    │
│ [✓] 文件读取                                  │
│ [ ] 计算                                      │
└──────────────────────────────────────────────┘
```

小任务选择复用同一结构，把工具项换成本地小任务项，并显示任务简介和关联状态。Demo 对标：HomeDecoration `FilterList.ets` 的筛选 Drawer + `CommonPicker.ets` 的选中网格；目标端必须支持已选数量、取消不保存和确认回写。

### A.7 页面 16–18：小任务、编辑与 Prompt

#### 小任务列表

```text
┌──────────────────────────────────────────────┐
│ 〈                  小任务                   + │
│ 本地小任务                                    │
│ ┌──────────────────────────────────────────┐ │
│ │ [icon] 健康总结          关联 2 个      > │ │
│ │        根据健康记录生成摘要              │ │
│ │ ───────────────────────────────────────  │ │
│ │ [icon] 报告解读          关联 1 个      > │ │
│ └──────────────────────────────────────────┘ │
│ 无任务时：图示 + “暂无本地小任务”             │
└──────────────────────────────────────────────┘
```

Demo 对标：Feedback `RecordListPage.ets` 的三态列表和 `Empty.ets` 的空态，`RecordCard.ets` 的白色圆角信息卡片；删除使用二次确认，失败保留原行。

#### 新建/编辑小任务

```text
┌──────────────────────────────────────────────┐
│ 取消              新建小任务                 保存│
├──────────────────────────────────────────────┤
│ 图标        [选择图标                       >] │
│ 名称        [                                ] │
│ 简介        [                                ] │
│ Prompt      [输入任务提示词                  ] │
│             [                                ] │
│ 输入工具    [选择                           >] │
│ 语音能力    [开关]                            │
│ 关联模型    [选择                           >] │
│ 关联场景    [选择                           >] │
│ 错误：名称和 Prompt 不能为空                  │
└──────────────────────────────────────────────┘
```

Demo 对标：`FormDecoration.ets` 的字段分组和提交前校验，AIOffice `SettingPersonal.ets` 的 Sheet 草稿模式。Prompt、工具、关联模型均只能在保存时回写草稿，不应在每次键入时立即覆盖已保存快照。

#### Prompt 输入抽屉

```text
┌──────────────────────────────────────────────┐
│ Prompt                                      │
│ [插入变量] [清空]                             │
│ ┌──────────────────────────────────────────┐ │
│ │ 请输入任务提示词...                       │ │
│ │                                          │ │
│ └──────────────────────────────────────────┘ │
│ 0 / 4000 字                                  │
│ [取消]                         [应用]        │
└──────────────────────────────────────────────┘
```

Demo 对标：HomeDecoration `module_filter_list/Drawer.ets` 的 Drawer 控制和打开/关闭回调；目标端需增加键盘避让、字数限制、空值校验、取消恢复旧值和应用回写。

### A.8 全页面状态矩阵

| 页面 | 加载 | 空数据 | 编辑/交互 | 成功 | 失败 |
| --- | --- | --- | --- | --- | --- |
| AI 设置首页 | 保留标题和卡片骨架 | 入口仍显示，状态区引导配置 | 刷新/放弃/保存 | 状态摘要更新 | 横幅 + 重试 |
| Provider 列表 | `LoadingProgress` | 无 Provider + 新增按钮 | 开关、下拉刷新 | 列表更新 | 保留旧列表 + 错误 |
| 新增 Provider | Sheet loading | 空表单 | 字段校验 | 关闭 Sheet、刷新列表 | 保留草稿 |
| Provider 编辑 | 表单 loading | 无模型文案 | Key、URL、模型开关、测试 | 保存退出 | 表单内错误、保留草稿 |
| 隐私政策 | Web loading | URL 不可用 | 滚动、重试 | 正常阅读 | 错误页 + 重试 |
| 模型目录 | 列表 loading | 无结果/无模型 | 搜索、筛选、启用、添加 | 列表刷新 | 保留已添加模型 |
| 添加在线模型 | 表单 loading | 无 Provider 不可提交 | 输入、选择、同意 | 服务端确认后关闭 | 保留表单、可重试 |
| 编辑模型 | 表单 loading | 模型不存在 | 编辑、图标、删除 | 保存退出 | 不覆盖旧模型 |
| Agent 编辑 | 表单 loading | 无基座模型/小任务 | 选择、输入、关联 | 保存退出 | 保留草稿 |
| 图标选择 | 资源 loading | 无图标资源 | 网格选择 | 回填图标 | 提示资源不可用 |
| 本地模型 | 文件状态 loading | 未安装 | 下载、暂停、取消 | 校验后安装 | 保留旧文件、重试 |
| 默认模型配置 | bundle loading | 无可用模型 | 选择 source/model | 更新偏好 | 保留上一选择 |
| 场景绑定 | 绑定 loading | 未设置 | 添加、编辑、删除 | 唯一默认生效 | 不破坏旧绑定 |
| 工具选择 | 列表 loading | 无工具 | 多选、搜索 | 回写草稿 | 保留旧选择 |
| 小任务选择 | 列表 loading | 无小任务 | 多选、搜索 | 回写 Agent/场景草稿 | 保留旧关联 |
| 小任务列表 | 快照 loading | Empty 组件 | 添加、编辑、删除 | 列表更新 | 保留旧列表 |
| 小任务编辑 | 表单 loading | 新建空表单 | 输入、关联、Prompt | 保存退出 | 字段错误、保留草稿 |
| Prompt 抽屉 | 草稿加载 | 空 Prompt | 输入、变量、清空 | 应用回填 | 取消恢复旧值 |

### A.9 Demo 采用边界

1. Demo 只证明 ArkUI 组件组合和交互 API 可行，不证明 AI 业务接口、RDB、KV、HUKS、Pro overlay 或 Runtime 行为。
2. Demo 的 `@ComponentV2`、`@Param`、`@Event`、`@Local` 使用方式必须结合目标工程 SDK/API Level 重新编译确认；不能把 Demo 的装饰器写法无审查地混入当前 V1 页面。
3. Demo 中静态 `SettingItem`、硬编码文案、随机 ID、Mock service、示例 URL、完整日志和未声明资源均不得进入生产 AI 页面。
4. Demo 的卡片、列表、Sheet、Drawer、Picker 和 Empty 只能作为视觉/交互参考；AI 页面必须继续调用当前 `AISettingsViewModel`、`AIConfigRepository`、`AIConfigResolver` 和既有页面路由。
5. 所有新增图标、颜色、圆角和字符串必须进入目标工程资源并通过 `assembleHap`，不得直接引用 Demo 模块资源路径。

### A.10 完整 UI 交付门槛

- [ ] 18 个 AI 设置页面均已在本文档登记，并有对应目标文件、iOS 页面、Demo 参考和状态矩阵。
- [ ] 首页、Provider 列表、模型目录、小任务列表均采用统一卡片/行组件语言。
- [ ] 表单页统一使用字段分组、校验状态、取消/保存语义和键盘避让。
- [ ] 选择页统一使用选中态、已选数量、确认/取消和空态。
- [ ] 列表页统一覆盖 loading、ready、empty、failed 四态。
- [ ] 下载页覆盖进度、暂停、取消、校验、安装、失败重试。
- [ ] 所有页面返回路径不创建嵌套业务 Navigation。
- [ ] 所有 Demo 参考路径已记录为绝对路径，并明确不可复制边界。
- [ ] UI 重构完成后使用目标 HarmonyOS 工程在真实设备截图，与 iOS 参考逐页比对。

### A.11 当前页面跳转问题分析（2026-07-21）

#### A.11.1 当前实际链路

当前实现的入口链路如下，已结合 `SettingsPage.ets`、`AISettingsPage.ets` 和 `AISettingsRoutes.ets` 审计确认：

```text
SettingsPage
  └─ 点击“AI 设置”
       └─ showAISettings = true
            └─ 条件渲染 AISettingsPage
                 └─ AISettingsPage 自己创建 aiStack 和 Navigation
                      └─ aiStack.pushPath({ name: route, param })
                           └─ aiDestination(name)
                                └─ Provider / Model / Preference / SmallTask 页面
```

子页面返回路径目前主要依赖各页面注入的 `stack.pop()`；`ProviderPrivacyPolicyPage` 和 `LocalModelDownloadPage` 没有显式持有 `NavPathStack`，主要依赖系统导航返回。

#### A.11.2 已出现的故障与根因

| 现象 | 根因 | 影响 |
| --- | --- | --- |
| 进入 AI 设置后出现空白页、`can't find inner navigation`、`load page failed: ai.settings` | 旧实现把 `ai.settings` 推入 Settings 外层 `Navigation`，但外层目的地配置没有对应的 `navDestination` 分支，同时目的地内部又创建了业务 `Navigation` | 外层路由找不到目标，或出现嵌套业务导航冲突 |
| 页面显示 `TypeError: undefined is not callable` | 旧页面把回调当作 ArkUI 属性使用，运行时拿到未初始化的函数；这不是后端接口错误 | 页面已渲染但点击返回或初始化时崩溃 |
| AI 首页可以打开，但系统返回不一定回到设置页 | 现在通过 `showAISettings` 条件切换根视图，AI 首页不再是 Settings 外层栈中的真实目的地，`onClose` 只是普通回调 | 系统返回键、边缘返回手势、页面恢复和深链进入缺少统一行为 |
| 子页面偶发回不到预期页面 | 每个页面都能直接操作共享栈，路由名和参数由调用方手写，没有统一 push/pop 适配器和结果契约 | 错误参数、重复 push、过度 pop 或返回后数据未回填难以及时发现 |
| 隐私政策、本地模型下载页的返回行为与其他页面不一致 | 页面未统一注入栈，也没有统一的页面头部返回按钮 | 依赖系统返回，测试和无障碍操作不一致 |

其中第一项是本次空白页问题的直接根因。当前修复后的条件渲染可以绕开旧的外层 `ai.settings` 缺失目的地，但它只是暂时改变了进入方式，尚未形成完整的导航契约。

#### A.11.3 当前路由覆盖审计

`AISettingsRoutes.ets` 中的路由目前均能在 `AISettingsPage.aiDestination` 找到对应分支，覆盖关系如下：

| 路由组 | 页面 | 参数/返回要求 |
| --- | --- | --- |
| Provider | `providers`、`provider.add`、`provider.edit`、`provider.privacy` | 编辑页必须携带 Provider 标识；隐私页必须携带 URL；保存后回到列表 |
| Model | `models`、`model.add`、`model.edit`、`model.agent`、`model.icon`、`model.local` | 编辑、Agent、图标页必须携带模型或草稿标识；完成后回填上一层 |
| Preference | `default.model`、`scenario.binding`、`tool.select`、`task.select` | 选择页必须携带场景/草稿上下文；确认后只回传结果，不重复创建快照 |
| Small Task | `small.tasks`、`small.task.edit`、`prompt.input` | 编辑和 Prompt 抽屉必须携带任务草稿标识；取消不得覆盖已保存值 |

因此，后续排查不能只看“路由是否注册”，还要同时检查四项：入口栈是否正确、目的地是否只有一个业务导航根、参数是否满足页面契约、返回是否有明确目标。

#### A.11.4 与 Demo 的正确对标方式

目标工程内的 Demo 已提供可复用的导航模式：

| Demo 参考 | 可借鉴点 |
| --- | --- |
| `/Users/hua/Documents/project/Reference/LookHealthClient/SparkClientHarmonyOS/开发详细技术文档/agc-template-market-harmonyos-demos-main/ToolsTemplate/AIOffice/components/business_setting/src/main/ets/pages/SettingPage.ets` | 设置首页通过真实 `NavDestination` 进入子页面，标题和返回由导航容器负责 |
| `/Users/hua/Documents/project/Reference/LookHealthClient/SparkClientHarmonyOS/开发详细技术文档/agc-template-market-harmonyos-demos-main/ToolsTemplate/AIOffice/components/business_setting/src/main/ets/pages/SettingPersonal.ets` | 页面通过 `onBackPressed` 处理系统返回，并在离开前处理草稿/保存语义 |
| `/Users/hua/Documents/project/Reference/LookHealthClient/SparkClientHarmonyOS/开发详细技术文档/agc-template-market-harmonyos-demos-main/ToolsTemplate/AIOffice/components/module_feedback/src/main/ets/components/NavHeaderBar.ets` | 统一从导航栈取得当前页面，并由标题栏执行 `stack.pop()`，避免每个页面自造返回逻辑 |
| `/Users/hua/Documents/project/Reference/LookHealthClient/SparkClientHarmonyOS/开发详细技术文档/agc-template-market-harmonyos-demos-main/ToolsTemplate/AIOffice/components/module_feedback/src/main/ets/pages/RecordListPage.ets` | 通过 `NavDestination` 和栈生命周期管理页面进入、返回与恢复 |

AI 设置应采用同一原则：一个 AI 导航容器、一个栈所有者、一个目的地注册表、一个统一返回入口。Demo 中的 `@Provider`、`@Consumer` 写法仍需按当前工程 ArkUI 版本验证，不能直接复制装饰器代码。

#### A.11.5 目标导航链路

```text
设置首页
  └─ AI 设置真实页面入口
       └─ AI 设置首页
            ├─ 模型密钥 -> Provider 列表 -> 新增/编辑 -> 返回列表
            ├─ 模型 -> 模型目录 -> 在线模型/Agent/图标/本地模型 -> 返回模型目录
            ├─ 默认模型配置 -> 场景绑定 -> 工具/小任务选择 -> 返回并回填草稿
            └─ 小任务 -> 新建/编辑 -> Prompt 输入抽屉 -> 应用并返回编辑页
```

每条链路必须满足：

1. AI 首页进入后，系统返回、左滑返回和页面返回按钮都能回到设置首页。
2. 子页面只允许 `push` 下一层或 `pop` 当前层，不允许直接清空父级栈或重建 `Navigation`。
3. 页面参数由集中式路由适配器构造和解析，不再在各页面散落 `Object`、字符串 URL 或裸 ID 转换。
4. 编辑页使用草稿标识，选择页返回 typed result；取消只 `pop`，保存/应用才提交 ViewModel。
5. 网络加载、数据库加载或模型文件校验失败时，路由页面仍保留标题、返回入口和重试状态，不得回到空白根节点。

#### A.11.6 必须补齐的实现约束

| 优先级 | 约束 | 验收方式 |
| --- | --- | --- |
| P0 | 明确 AI 首页的真实页面边界：要么由外层统一导航承载，要么作为独立根页面承载；不能再把业务 `Navigation` 放入外层自定义目的地 | 进入 AI 设置后无 `ai.settings` 查找失败、无 `can't find inner navigation` |
| P0 | 增加统一 `onBackPressed`：子栈非空时只弹一层，子栈为空时执行 `onClose` 回到设置页 | 系统返回、边缘手势、标题栏返回三者结果一致 |
| P0 | Provider、Model、Preference、SmallTask 页面使用同一套标题栏和返回组件 | 18 个页面均有可见返回入口，隐私政策和本地模型页不再例外 |
| P1 | 建立集中式 `AISettingsNavigationController` 或等价路由适配器 | 所有 `push` 使用统一 route + typed params；构建期可检查路由分支覆盖 |
| P1 | 统一 `pushPath` 与 `pushPathByName` 的使用策略 | 路由调用不混用隐式名称查找和裸 `NavPathInfo`，参数解析不依赖不明确的 `getParamByName` |
| P1 | 定义选择页结果协议和取消协议 | 模型、工具、小任务、图标选择后上一页可确定性回填，取消不改已保存数据 |
| P2 | 增加导航日志字段 | 每次 push/pop 记录 `fromRoute`、`toRoute`、`paramId`、`stackDepth`、`source`，便于复现设备差异 |

#### A.11.7 页面跳转验收用例

- 从设置页进入 AI 设置，确认标题、返回按钮、首页卡片和同步状态均显示。
- 从 AI 首页依次进入 Provider 列表、新增 Provider、编辑 Provider，再逐层返回；返回后列表数据不丢失。
- 从模型目录进入编辑模型、图标选择和本地模型下载；取消、系统返回和保存分别验证。
- 从默认模型配置进入场景绑定、工具选择、小任务选择；确认结果只回填当前草稿，重新进入不会产生重复绑定。
- 从小任务列表进入编辑页和 Prompt 抽屉；输入、应用、取消、系统返回分别验证。
- 在任一子页面执行系统返回和边缘返回，确认只返回上一层，不直接退出 AI 设置或设置页。
- 在 AI 首页执行系统返回，确认回到设置页，而不是停留在空白容器或退出应用。
- 断网、Pro 配置加载失败、本地模型文件不存在时，确认页面仍显示返回入口和可重试内容。
- 快速连续点击入口和返回按钮，确认不会重复 push、重复提交或出现空白目的地。
- 销毁并恢复页面后重新进入，确认路由栈、草稿和运行时配置没有串页。

#### A.11.8 本次文档结论

当前代码已经解决了旧的“外层 `ai.settings` 未注册 + 内层业务 Navigation”空白页触发方式，但页面跳转仍属于过渡实现。下一轮工程改造的重点不是继续增加路由分支，而是把 AI 设置提升为有明确生命周期的真实页面导航：统一栈所有权、系统返回、标题栏、typed 参数、选择结果和失败态。只有完成上述 P0/P1 约束后，才能认为 HarmonyOS 的页面跳转与 iOS 流程一致。

### A.12 截图驱动的页面与组件实施规格

本节以用户提供的 iOS 截图作为视觉基线，以目标工程内的 HarmonyOS Demo 作为组件实现基线。截图中出现的浅灰页面背景、白色圆角分组、蓝色系统强调色、粗体大标题、胶囊按钮、行间 Divider、Toggle 和右侧 Chevron 都属于同一套页面语言；业务代码只负责状态和事件，视觉参数统一收敛到 AI 设置组件层。

#### A.12.1 公共页面壳

所有 AI 设置页面都使用以下页面壳，不在每个页面重新拼装顶部返回逻辑：

```text
AISettingsPageShell
├─ NavDestination
│  ├─ 顶部安全区：WindowInsets / windowTopPadding
│  ├─ AISettingsNavHeader
│  │  ├─ 左侧：SymbolGlyph(chevron_backward) 或取消按钮
│  │  ├─ 中间：页面标题；根页面使用大标题，子页面使用 Title_S
│  │  └─ 右侧：保存 / 添加 / 刷新 / 关闭操作
│  └─ Scroll
│     └─ Column / GridRow + GridCol
└─ 页面底部安全区：windowBottomPadding
```

实现方向：

- 对标 `.../ToolsTemplate/AIOffice/components/module_feedback/src/main/ets/components/NavHeaderBar.ets`，使用 `SymbolGlyph($r('sys.symbol.chevron_backward'))`、`accessibilityText('返回')` 和统一 `NavPathStack.pop()`。
- 对标 `.../ToolsTemplate/AIOffice/components/business_setting/src/main/ets/pages/SettingPage.ets`，页面使用 `NavDestination().hideTitleBar(true)`，由业务标题栏控制标题和按钮。
- 复杂页面使用 `GridRow/GridCol` 适配手机、折叠屏和横屏，不能用固定屏幕宽度计算白色卡片。
- 页面背景使用系统 `background_secondary`；卡片使用系统 `comp_background_primary` 或项目定义的白色卡片色；不要用截图中的纯色值散落在每个页面。
- 所有异步页面先渲染标题栏和骨架/Loading，再加载 RDB、KV、SparkService 或模型文件；不能让整个 `build()` 因请求失败变成空节点。

#### A.12.2 公共组件清单

| 目标组件 | HarmonyOS 组件组合 | 作用 | Demo 参考 | AI 设置专属规则 |
| --- | --- | --- | --- | --- |
| `AISettingsNavHeader` | `NavDestination` + `Row` + `Button` + `SymbolGlyph` + `Text` | 标题、返回、保存、添加、刷新 | `module_feedback/NavHeaderBar.ets` | 注入 `onBack`、`onAction`，禁止页面自行创建第二个 Navigation |
| `AISettingsSection` | `Column` + `Text` section title + `Column/List` | 灰色分组标题和白色内容卡片 | `business_setting/SettingPage.ets` 的 `SettingCard` 组合 | 标题、说明文字和卡片内容必须分离，标题颜色使用 secondary |
| `AISettingsCard` | `Column` + `.borderRadius()` + `.backgroundColor()` + 内部 `Divider` | 白色圆角分组容器 | `SettingCard.ets`、`SettingPersonal.ets` | 卡片内只放同一语义集合，禁止卡中嵌卡 |
| `AISettingsRow` | `ListItem` 或 `Row` + `Text` + `Image/SymbolGlyph` + `Divider` | 设置项、表单项、模型项 | `SettingPersonal.ets` 的 `ListItem` | 左侧 icon、中间主副标题、右侧控件/chevron 固定列宽 |
| `AISettingsToggleRow` | `ListItem` + `Text` + `Toggle({ type: ToggleType.Switch })` | 能力开关、模型启用、隐私同意 | Demo 设置行的开关写法 | `onChange` 先更新草稿，保存时才写 RDB/Pro overlay |
| `AISettingsPickerRow` | `ListItem` + `Text` + `Text` + `SymbolGlyph` | 厂商、价格档位、测试模型、场景选择 | HomeDecoration `CommonPicker` 调用方 | 点击打开 Sheet/Drawer，选择结果回填草稿，不直接提交 |
| `AISettingsFormField` | `TextInput` / `TextArea` + `Divider` | API Key、URL、名称、Prompt | `SettingPersonal.ets` Sheet、`Posting.ets` | 密钥字段 `InputType.Password`；URL 做格式校验；错误显示在字段下方 |
| `AISettingsModelRow` | `ListItem` + `Image` + 多行 `Text` + `Toggle/Button` | 模型名称、能力标签、启用/添加 | `RecordListPage.ets` 的 `ForEach`/卡片组合 | 名称允许换行，能力标签最多两行，右侧操作固定不挤压文本 |
| `AISettingsDrawer` | `Drawer` + 遮罩 `Column` + `Scroll` | Prompt 输入、搜索筛选、底部操作 | `HomeDecoration/components/module_filter_list/Drawer.ets` | 点击遮罩关闭只等价取消；应用按钮才回传结果 |
| `AISettingsEmpty` | 居中 `Column` + `Text` + `Button` | 无 Provider、无模型、无小任务 | `module_feedback/Empty.ets` | Empty 必须保留页面标题和返回入口 |
| `AISettingsLoadState` | `if` + `LoadingProgress` / 内容 / 错误重试 | 页面 loading/ready/failed | `RecordListPage.ets` | loading 不清空旧数据；失败保留旧快照和重试按钮 |

#### A.12.3 截图 1：AI 场景配置首页

```text
┌────────────────────────────────────────────┐
│ [返回]                                      │  ← AISettingsNavHeader
│ AI 场景配置                                  │  ← 大标题 Title_L / Bold
│                                            │
│ 模型设置                                    │  ← SectionTitle
│ ┌────────────────────────────────────────┐ │
│ │ [钥匙] 模型密钥       厂商密钥与端点   > │ │  ← AISettingsRow
│ │ ├────────────────────────────────────┤ │
│ │ [层叠] 模型           模型目录与能力开关 >│ │
│ │ ├────────────────────────────────────┤ │
│ │ [滑杆] 默认模型配置   按场景配置模型     > │ │
│ └────────────────────────────────────────┘ │  ← AISettingsCard
│                                            │
│ 工具 / 检索 / 知识                          │
│ ┌────────────────────────────────────────┐ │
│ │ [任务] 小任务           维护本地小任务   > │ │
│ └────────────────────────────────────────┘ │
└────────────────────────────────────────────┘
```

组件实现和功能：

- `Scroll + Column` 承载页面内容，根页面不使用底部 Tab，也不显示旧的“返回设置”大按钮；返回统一放在 `AISettingsNavHeader`。
- 每个入口行由 `AISettingsRow` 生成：icon 48vp 区域、主标题、secondary 描述、右侧 24vp chevron；整行点击，不只点击箭头。
- `aboutToAppear` 只触发 ViewModel 的 `load()`；加载失败仍展示上述入口和同步错误横幅，避免截图中的 `undefined is not callable` 或空白页。
- 入口路由只调用统一 `AISettingsNavigationController.push(route, params)`；页面不直接拼接字符串路由。
- 对标 Demo：`ToolsTemplate/AIOffice/components/business_setting/src/main/ets/pages/SettingPage.ets` 的 `NavDestination + GridRow + Scroll + SettingCard`。

#### A.12.4 截图 2：编辑密钥 / Provider 模型配置

```text
┌────────────────────────────────────────────┐
│ [返回]              编辑密钥          [保存] │
│                                            │
│ ┌────────────────────────────────────────┐ │
│ │ 字节豆包                         [开关] │ │  ← Provider 开关
│ │ ────────────────────────────────────── │ │
│ │ https://ark.cn-beijing.volces.com/... │ │  ← endpoint 摘要/输入
│ │ ────────────────────────────────────── │ │
│ │ 查看隐私政策                           │ │  ← NavPath push
│ │ ────────────────────────────────────── │ │
│ │ 我已阅读并同意该厂商隐私政策       [开关] │ │
│ └────────────────────────────────────────┘ │
│                                            │
│ 该厂商模型                             [+] │
│ ┌────────────────────────────────────────┐ │
│ │ [logo] Doubao Seed 1.6  [信息] [开关]  │ │
│ │        工具 视觉 思考 经济              │ │
│ │ ├──────────────────────────────────────│ │
│ │ [logo] Doubao Seed 1.6 Lite     [开关] │ │
│ └────────────────────────────────────────┘ │
│                                            │
│ API 测试                                   │
│ ┌────────────────────────────────────────┐ │
│ │ 测试模型             Doubao Seed 1.6  ⇅ │ │
│ │ ────────────────────────────────────── │ │
│ │ 测试 API                                │ │
│ └────────────────────────────────────────┘ │
└────────────────────────────────────────────┘
```

组件实现和功能：

- 顶部保存按钮使用 `Button`，`enabled` 由 `draft.isValid && !isSaving` 决定；保存时执行字段校验、加密保存 API Key、提交 Provider/Model 变更、刷新 Resolver。
- Provider 基础卡使用 `AISettingsFormField`：名称/endpoint 是普通输入，API Key 是密码输入；页面只显示脱敏值，真实密钥不进入普通日志和 UI 状态摘要。
- 隐私政策行使用 `AISettingsRow`，点击 `PROVIDER_PRIVACY`；隐私同意开关只有在 URL 有效且用户阅读过政策后才允许打开。
- 模型列表使用 `ForEach(models, key=id)`，每行左侧为 Provider logo，中间使用 `Column` 放名称和 capability tags，右侧为信息按钮和 `Toggle`；不能用 `Row` 中无限增长文本挤压开关。
- “+”使用图标按钮，进入在线模型添加页；信息按钮打开模型详情/能力说明，不改变启用状态。
- API 测试区使用 `AISettingsPickerRow` 打开测试模型选择，点击“测试 API”调用 SparkService/统一 Runtime 的 probe 接口；结果展示 latency、HTTP/业务码、能力校验和脱敏错误。
- 对标 Demo：`SettingPersonal.ets` 的 `NavHeaderBar + ListItem + bindSheet + TextInput`，`RecordListPage.ets` 的 `ForEach + LoadingProgress/Empty`。

#### A.12.5 截图 3：新增自定义 Provider

```text
┌────────────────────────────────────────────┐
│ [取消]          新增自定义供应商       [保存] │
│                                            │
│ ┌────────────────────────────────────────┐ │
│ │ 供应商名称                              │ │  ← TextInput
│ │ ────────────────────────────────────── │ │
│ │ API Key                                │ │  ← Password TextInput
│ │ ────────────────────────────────────── │ │
│ │ 请求地址                                │ │  ← URL TextInput
│ └────────────────────────────────────────┘ │
│                                            │
│ 保存按钮：空表单/字段错误时禁用             │
│ 取消：有改动时二次确认，否则直接 pop         │
└────────────────────────────────────────────┘
```

组件实现和功能：

- 使用 `NavDestination + AISettingsNavHeader`，左侧是“取消”文字按钮，右侧是“保存”文字按钮；不要用 `bindSheet` 承载整个新增 Provider 页面，因为截图表现为完整页面，只有字段编辑/选择才适合 Sheet。
- 表单使用 `Column` 包裹 `AISettingsFormField`，每一行高度稳定，`Divider` 负责分隔；输入事件只更新 `ProviderDraft`。
- `providerName` 必填；`apiKey` 必填但只在内存草稿中短暂存在；`endpoint` 必须通过 URL/协议校验；保存前检查同账号下 Provider code 是否重复。
- 保存顺序：校验草稿 -> HUKS 写密钥引用 -> RDB 写 Provider 元数据 -> SparkService 同步/刷新 -> Resolver 重建 -> `pop()` 返回 Provider 列表。
- API 失败时保留表单和错误文案，不自动清空 API Key；用户取消时清理内存草稿。
- 对标 Demo：`SettingPersonal.ets` 的字段 Sheet 只借鉴输入和保存按钮状态；页面容器、路由和 AI 数据提交使用目标工程自己的 ViewModel/Repository。

#### A.12.6 截图 4：添加在线模型

```text
┌────────────────────────────────────────────┐
│ [取消]          添加在线模型          [添加] │
│                                            │
│ 基本信息                                    │
│ ┌────────────────────────────────────────┐ │
│ │ [说明] 系统名称（用于 API 请求）        │ │
│ │ ├──────────────────────────────────────│ │
│ │ [格式] 显示名称（自定义）               │ │
│ │ ├──────────────────────────────────────│ │
│ │ [厂商] 厂商              字节豆包  ⇅    │ │
│ └────────────────────────────────────────┘ │
│                                            │
│ 价格                                        │
│ ┌────────────────────────────────────────┐ │
│ │ [¥] 价格档位                 免费  ⇅   │ │
│ └────────────────────────────────────────┘ │
│                                            │
│ 能力                                        │
│ ┌────────────────────────────────────────┐ │
│ │ [隐藏] 默认隐藏                  [开关] │ │
│ │ [探测] 自动模型能力探测              > │ │
│ │ 注意：自动探测可能产生 API 费用         │ │
│ │ [字] 支持文本                    [开关] │ │
│ │ [图] 支持多模态                  [开关] │ │
│ │ [原子] 支持推理                  [开关] │ │
│ │ [灯] 思考可控                    [开关] │ │
│ └────────────────────────────────────────┘ │
└────────────────────────────────────────────┘
```

组件实现和功能：

- 使用 `AISettingsSection + AISettingsCard`，每一个能力项是 `AISettingsToggleRow`；能力枚举来自服务端/Provider metadata，不在页面硬编码为另一套枚举。
- “厂商”“价格档位”使用 `AISettingsPickerRow + bindSheet` 或 `Drawer + CommonPicker`；确认后只回填 `ModelDraft`。
- “自动模型能力探测”是带费用风险的异步动作：点击后弹出确认 Dialog，执行中显示行内 `LoadingProgress`，成功回填 capability，失败保留用户手工选择并显示重试。
- capability 字段必须区分“声明能力”和“探测能力”；页面 Toggle 只能编辑草稿，最终由后端能力结果和本地模型 manifest 合并。
- 对标 Demo：`HouseAndHomeTemplate/HomeDecoration/components/module_filter_list/src/main/ets/components/FilterList.ets` 的筛选项 + `CommonPicker` 组合；`Drawer.ets` 只借鉴开关、遮罩和动画控制。

#### A.12.7 截图 5：模型目录

```text
┌────────────────────────────────────────────┐
│ [返回]              模型密钥            [+] │
│                                            │
│ 自动刷新                                    │
│ ┌────────────────────────────────────────┐ │
│ │ 进入页面自动拉取一次模型列表，支持下拉或 │
│ │ 右上角刷新按钮手动刷新                   │
└────────────────────────────────────────────┘
│                                            │
│ 已添加（2）                                │
│ ┌────────────────────────────────────────┐ │
│ │ [logo] Doubao Seed 1.6          [开关] │ │
│ │        工具 视觉 思考 经济              │ │
│ │ ├──────────────────────────────────────│ │
│ │ [logo] Doubao Seed 1.6 Lite      [开关]│ │
│ └────────────────────────────────────────┘ │
│                                            │
│ 远端可用（118）                             │
│ ┌────────────────────────────────────────┐ │
│ │ [logo] deepseek-r1-250120       [添加] │ │
│ │        工具 文本 标准                   │ │
│ │ ...                                    │ │
│ └────────────────────────────────────────┘ │
│                           [搜索模型]       │  ← 底部 Search 浮层
└────────────────────────────────────────────┘
```

组件实现和功能：

- 使用 `Scroll + Refresh` 或等价刷新容器；首次进入调用 `loadRemoteModels()`，下拉和右上角刷新都复用同一个 ViewModel command，避免并发请求覆盖列表。
- “已添加”和“远端可用”是两个语义分区；已添加项显示 `Toggle`，远端项显示带 `add_circle` 的 `Button`，不能用同一个按钮文案混淆启用和添加。
- 模型行使用固定的 icon、内容和 action 三列；模型长名称最多两行，副标题能力标签按 `ForEach` 生成，价格标签使用 warning/accent 色但不依赖硬编码橙色。
- 底部搜索使用 `Search({ value: $$searchText, placeholder: '搜索模型' })`，可放在 `bindSheet` 或 `Drawer` 中；搜索只过滤已加载的远端快照，不直接修改 RDB。
- 加入模型后调用后端确认/本地 RDB upsert，列表重新分组；删除/禁用需要区分“从账号配置移除”和“关闭能力开关”。
- 对标 Demo：`HouseAndHomeTemplate/HomeDecoration/features/home/src/main/ets/pages/SearchPage.ets` 的 `Search` 页面和 `FilterList/CommonPicker`；`RecordListPage.ets` 的列表 loading/empty 结构。

#### A.12.8 截图 6：模型密钥首页

```text
┌────────────────────────────────────────────┐
│ [返回]                                       │
│ 模型密钥                                  [+] │
│                                            │
│ ┌────────────────────────────────────────┐ │
│ │ [钥匙] 模型密钥 / 试用权限               │ │
│ │        配置 API Key 后可启用对应模型能力  │ │
│ │ [成功] 试用已开通     剩余 80 天          │ │
│ │ [OpenAI] [Gemini] [Claude] [DeepSeek]   │ │
│ └────────────────────────────────────────┘ │
│                                            │
│ 模型厂商                                    │
│ ┌────────────────────────────────────────┐ │
│ │ [logo] 302.AI                     [开关]│ │
│ │ [logo] 推理时代                     > [开关]│
│ │ [logo] Anthropic                   [开关]│ │
│ │ [logo] 字节豆包                     [开关]│
│ │ ...                                    │ │
│ └────────────────────────────────────────┘ │
└────────────────────────────────────────────┘
```

组件实现和功能：

- 顶部试用权限是 `AISettingsStatusCard`：使用 `Row/Column/ForEach` 展示账号级 Pro 权限、剩余时间和覆盖的 Provider 标签；状态来自统一 Resolver，不由页面自行计算剩余天数。
- 右上角加号进入新增自定义 Provider；厂商列表每行使用 logo、名称、chevron、开关四列，点击行进入编辑，开关只改变 provider enabled 草稿。
- 加载远端 Provider 时显示卡片骨架；Pro 配置失败保留本地厂商列表并在卡片顶部显示同步状态。
- Provider icon 使用资源映射表和兜底系统图标，不允许把远端 URL 直接作为 `Image` 唯一来源；模型 logo 加载失败时显示首字母/默认图标。
- 对标 Demo：`business_setting/SettingCard.ets` 和 `SettingPage.ets` 的卡片分组；`module_feedback/RecordListPage.ets` 的 loading/empty 分支。

#### A.12.9 Provider 隐私政策页

```text
┌────────────────────────────────────────────┐
│ [返回]              隐私政策                 │
│                                            │
│ Web / RichText 内容                         │
│ [加载进度]                                  │
│ [页面内容]                                  │
│ [加载失败：重新加载]                         │
└────────────────────────────────────────────┘
```

- 页面必须是 `NavDestination`，统一使用 `AISettingsNavHeader`，不能只依赖系统返回。
- URL 来自已校验的 Provider metadata；网络失败显示错误和重试，不将 URL 错误渲染成空白页面。
- 如果采用 `Web`，需在文档和代码中明确网络权限、页面白名单、加载超时、返回和外链处理；如果采用 `RichText`，必须先完成 HTML 到安全文本的转换，禁止直接执行远端脚本。
- 参考 `HouseAndHomeTemplate/.../features/mine/src/main/ets/pages/PrivacyPolicyPage.ets` 的 `NavDestination` 页面边界；页面数据和安全策略使用 AI 模块自己的 ViewModel。

#### A.12.10 模型目录相关页面

**编辑模型：**

```text
┌────────────────────────────────────────────┐
│ [取消]              编辑模型          [保存] │
│ [图标] 显示名称                             │
│        系统名称 / model id                  │
│ [开关] 启用模型                             │
│ [行] 能力：文本 / 多模态 / 推理 / 思考       │
│ [行] 模型图标                         >     │
│ [危险按钮] 删除模型                         │
└────────────────────────────────────────────┘
```

- 使用 `AISettingsFormField + AISettingsToggleRow + AISettingsRow`；系统名称只读，显示名称可编辑。
- 删除必须弹出确认并明确影响：删除本地配置、取消默认绑定、是否保留本地文件；成功后返回模型目录并刷新 Resolver。

**Agent 编辑：**

```text
┌────────────────────────────────────────────┐
│ [取消]              编辑智能体        [保存] │
│ 名称 / 描述 / Prompt                         │
│ 基座模型                                >   │
│ 关联小任务                              >   │
│ 工具选择                                >   │
│ 能力开关                                    │
└────────────────────────────────────────────┘
```

- 表单使用独立 `AgentDraft`，选择模型、工具、小任务均进入选择页，返回 typed result；不要直接让选择页修改 Agent 已保存实体。
- Prompt 进入 `PromptInputDrawer`；保存前检查基座模型存在、Prompt 非空、工具权限合法。

**图标选择：**

```text
┌────────────────────────────────────────────┐
│ [返回]              选择图标                 │
│ [Search 搜索图标]                            │
│ [图标网格] [图标网格] [图标网格]              │
│ 选中态：蓝色边框 + 勾选                     │
└────────────────────────────────────────────┘
```

- 使用 `Grid` + `ForEach`，图标格子固定宽高，选中后通过结果协议返回 `iconId`；资源加载失败显示默认图标。
- 参考 Demo 的 `Grid`/`ForEach` 页面组合，不把远端图标 URL 直接写入 UI。

**本地模型下载/安装：**

```text
┌────────────────────────────────────────────┐
│ [返回]              本地模型                 │
│ 模型名称 / 文件大小 / 最低系统版本           │
│ [进度条 68%]  下载中              [暂停]     │
│ [取消下载] [校验中] [安装] [删除]             │
│ 错误：空间不足 / 校验失败              [重试] │
└────────────────────────────────────────────┘
```

- 使用 `Progress`、`Button`、`LoadingProgress` 和状态文本；下载状态由文件管理器/任务状态机驱动，不由页面百分比自增。
- 安装前校验 manifest、SHA-256、文件完整性和设备能力；安装成功后写入本地模型元数据，再由 Resolver 合并到通用消费模型。
- 删除必须先解除默认模型和场景绑定，保留删除确认和失败恢复。

#### A.12.11 默认模型、场景绑定、工具和小任务选择页

**默认模型配置：**

```text
┌────────────────────────────────────────────┐
│ [返回]            默认模型配置               │
│ [场景分组]                                  │
│ 文本对话       本地 / Pro 模型          >   │
│ 图片理解       本地 / Pro 模型          >   │
│ 语音转写       本地 / Pro 模型          >   │
│ 小任务         本地 / Pro 模型          >   │
└────────────────────────────────────────────┘
```

- 使用 `AISettingsSection + AISettingsPickerRow`；每个场景只能有一个生效绑定，显示 source、modelName、fallback 状态。
- 选择完成后提交 `ScenarioBindingDraft`；保存后更新 KV/RDB 和运行时缓存，失败时恢复旧绑定。

**场景绑定：**

```text
┌────────────────────────────────────────────┐
│ [返回]              场景绑定                 │
│ 当前场景：图片理解                           │
│ [模型来源 Segmented/Picker]                  │
│ [模型列表]                                   │
│ [工具选择]                              >    │
│ [小任务选择]                            >    │
│                                  [确认]       │
└────────────────────────────────────────────┘
```

- 选择器可以使用 `bindSheet`；多选工具/小任务使用 `Drawer + Search + ListItem + Toggle`，确认后返回完整 ID 集合。
- 选择页不能直接调用 SparkService 保存；统一由父级场景页的 Save command 提交。

**工具选择 / 小任务选择：**

```text
┌────────────────────────────────────────────┐
│ [取消]              选择工具          [完成] │
│ [Search 搜索]                               │
│ [开关] 文件检索                         [on] │
│ [开关] 图片理解                         [off]│
│ [开关] 网络搜索                         [on] │
│ 已选 2 项                                   │
└────────────────────────────────────────────┘
```

- 使用 `Search`、`List`、`ListItem` 和 `Toggle`；搜索文本只改变过滤结果，选中集合保存为 `Set` 的显式数组 ID。
- 工具和小任务不可用时显示禁用原因；服务端权限变化时重新校验，不能只依据本地开关。
- 参考 `FilterList.ets` 的 Drawer/Picker 回调模式和 `SearchPage.ets` 的搜索输入，但选择提交必须遵守 AI 草稿事务。

#### A.12.12 小任务列表、编辑页和 Prompt 抽屉

**小任务列表：**

```text
┌────────────────────────────────────────────┐
│ [返回]              小任务             [+]   │
│ [Search 搜索小任务]                          │
│ ┌────────────────────────────────────────┐ │
│ │ [图标] 总结健康报告       [启用开关]  > │ │
│ │        已关联：文本模型                  │ │
│ └────────────────────────────────────────┘ │
│ [Empty：暂无小任务]                         │
└────────────────────────────────────────────┘
```

- 列表使用 `ForEach` + 稳定 task ID；删除使用确认 Dialog，编辑使用 `SMALL_TASK_EDIT`。
- 搜索、启用和删除都先改变本地草稿/命令状态，成功后刷新小任务快照和场景绑定状态。

**新建/编辑小任务：**

```text
┌────────────────────────────────────────────┐
│ [取消]            新建小任务          [保存] │
│ [行] 图标                         >          │
│ [输入] 名称                                  │
│ [输入] 简介                                  │
│ [行] Prompt                       >          │
│ [行] 输入工具                     >          │
│ [行] 关联模型                     >          │
│ [行] 关联场景                     >          │
│ [错误] 名称和 Prompt 不能为空                │
└────────────────────────────────────────────┘
```

- 使用 `Scroll + Column + AISettingsFormField + AISettingsPickerRow`，编辑态由 `SmallTaskDraft` 驱动。
- Prompt、工具、模型、场景均在草稿中暂存；点击保存才执行字段校验和 repository command；取消不产生 RDB/KV 写入。
- 对标 `HomeDecoration/components/module_posting/src/main/ets/components/Posting.ets` 的 `TextInput/TextArea` 字段组合和 `FormDecoration.ets` 的表单分组思想。

**Prompt 输入抽屉：**

```text
┌────────────────────────────────────────────┐
│ Prompt                             [关闭]   │
│ [插入变量]                         [清空]   │
│ ┌────────────────────────────────────────┐ │
│ │ TextArea：请输入任务提示词              │ │
│ └────────────────────────────────────────┘ │
│ 0 / 4000 字                    [取消] [应用]│
└────────────────────────────────────────────┘
```

- 使用 `AISettingsDrawer`；背后遮罩点击等价取消，关闭动画完成后才清理 `isOpen`。
- `TextArea` 绑定 Prompt 草稿，实时显示字数但不写入已保存实体；应用时返回 `prompt`，取消时返回旧值。
- 参考 `HouseAndHomeTemplate/HomeDecoration/components/module_filter_list/src/main/ets/components/Drawer.ets` 的 controller、遮罩、窗口尺寸监听和动画生命周期；需要补齐键盘避让与高度上限。

### A.13 组件级状态、数据和事件契约

#### A.13.1 行组件统一接口

```text
AISettingsRow
  id: string
  title: string
  subtitle?: string
  icon: ResourceStr
  trailing: 'chevron' | 'toggle' | 'button' | 'value' | 'none'
  enabled: boolean
  onClick: () => void
  onToggle?: (value: boolean) => void
  accessibilityLabel: string
```

`AISettingsRow` 只负责呈现和事件，不直接访问 RDB、KV、SparkService 或 ViewModel。这样可以保证 Provider、模型、工具和小任务页面使用同一行高、Divider、点击区域和无障碍语义。

#### A.13.2 页面状态统一接口

```text
PageState = 'loading' | 'ready' | 'empty' | 'failed' | 'saving' | 'testing'

PageStateView
  state: PageState
  dataVersion: number
  errorMessage?: string
  retry: () => void
  content: () => void
```

- `loading`：标题栏存在，内容显示骨架或 `LoadingProgress`。
- `ready`：展示实际卡片/列表。
- `empty`：展示 Empty 和主操作按钮。
- `failed`：保留旧快照，显示错误和重试。
- `saving/testing`：只锁定相关按钮，不锁死整个页面返回；返回时按页面草稿策略处理。

#### A.13.3 组件事件到业务层的边界

```text
用户点击
  -> AISettingsRow / Toggle / Button
  -> Page ViewModel command
  -> Draft 更新
  -> 点击保存/应用
  -> Repository / SparkService / 文件管理器
  -> RDB/KV/运行时 Resolver 同步
  -> 页面重新读取快照
```

禁止以下写法：

- 在 `AISettingsRow.onClick` 里直接执行数据库 SQL。
- 在 `Toggle.onChange` 里直接调用 SparkService 并把网络失败吞掉。
- 在 `ForEach` 的 builder 内修改列表源数组造成重复渲染或索引错位。
- 用 `any`/`unknown` 承载选择结果、能力字段和路由参数。
- 把 API Key、完整 endpoint 或 Provider 隐私内容写进普通 UI 日志。

### A.14 截图对标验收细则

每个页面验收必须同时记录“视觉、交互、数据”三类结果：

| 检查维度 | 必须确认 |
| --- | --- |
| 视觉 | 背景、卡片圆角、分组间距、标题层级、icon/文字/控件三列对齐、长文本换行、底部安全区 |
| 交互 | 整行点击、返回/取消/保存、Toggle 防重复、Sheet/Drawer 遮罩、键盘避让、系统返回、加载/空态/失败态 |
| 数据 | 草稿与已保存快照隔离、保存事务、取消回滚、账号隔离、Provider/Model/Scenario ID 不串用、Resolver 刷新 |

截图验收顺序：

1. 先验收 AI 首页和模型密钥首页的页面壳、标题和卡片分组。
2. 再验收 Provider 编辑、新增 Provider、在线模型添加的表单字段和保存状态。
3. 再验收模型目录、编辑模型、Agent、图标选择、本地模型安装的列表和异步状态。
4. 最后验收默认模型、场景绑定、工具/小任务选择、小任务编辑和 Prompt 抽屉的草稿回传。
5. 每页至少保留 loading、ready、empty、failed 四张设备截图；表单页另保留 dirty、validation error、saving 三张状态截图。

### A.15 参考包使用边界与落地顺序

1. 先抽取公共页面壳、标题栏、卡片、行、Toggle、Picker、Drawer、Empty 和 Loading 状态，再实现业务页面；避免 18 个页面各自复制一套视觉代码。
2. 优先复用目标工程 Demo 的 ArkUI 组件组合和布局方法，不复制 Demo 的 Mock 数据、业务 ViewModel、资源包、账号逻辑和示例 endpoint。
3. 先完成 AI 首页、Provider 列表和 Provider 编辑三条核心链路，再扩展模型目录和小任务；每增加一页必须同步补路由、状态矩阵、Plain text 草图和验收用例。
4. 组件层必须通过当前 HarmonyOS 工程的 ArkTS 编译规则，特别是 `@Builder` 根节点、显式类型、`NavDestination` 目的地、`onBackPressed` 返回值和 `@Provider/@Consumer` 生命周期。
5. UI 对标通过后再接入真实 SparkService、RDB、KV、HUKS 和 Runtime；接口错误不能通过 UI 默认值掩盖。

### A.16 深色主题与新增截图页面补充规格

本组截图明确要求 AI 设置支持深色主题。深色主题不是把页面背景从白色改成黑色，而是整套系统颜色、卡片层级、文字层级、控件状态、图标和系统状态栏同时切换。所有页面组件必须使用资源色或主题 token，禁止在业务页面里写死 `#000000`、`#1C1C1E`、`#FFFFFF` 等颜色。

#### A.16.1 深色主题公共视觉规则

```text
深色页面
├─ Window/System bar：跟随系统深色背景，状态栏文字为浅色
├─ 页面背景：background_secondary_dark
├─ 卡片背景：comp_background_primary_dark
├─ 主标题/主文本：font_primary_dark
├─ 副标题/说明：font_secondary_dark
├─ 分割线：comp_divider_dark
├─ 交互蓝：interactive_primary_dark
├─ 开启态：accent / success；关闭态：control_secondary_dark
└─ 禁用态：font_disabled_dark + control_disabled_dark
```

实现要求：

- 通过 `$r('sys.color...')` 或目标工程资源别名取得颜色，颜色命名必须表达语义，例如 `ai_settings_card_background`，不能命名为 `dark_gray_1`。
- `AISettingsCard` 在浅色和深色下保持相同圆角、内边距、行高和布局，仅替换颜色和阴影层级；不要因为深色主题改变页面几何结构。
- 深色卡片仍需与黑色页面背景有可识别层级差异；卡片不能与背景融为一个纯黑大块。
- 蓝色 Toggle 开启态、灰色关闭态、绿色成功态和橙色价格标签需要同时满足对比度和无障碍文本描述；状态不能只靠颜色表达。
- Provider/Model logo 必须处理深色背景透明边缘；PNG/SVG 资源需要提供深色可读版本或统一底板。
- 键盘、Dialog、Sheet、Drawer 的背景和遮罩要跟随深色主题，不能出现浅色系统弹层覆盖深色页面。
- 截图中的状态栏时间、电量、网络图标属于系统窗口，不复制进业务 UI；业务页面只设置窗口主题和安全区。

#### A.16.2 截图 7：深色主题编辑小任务

```text
┌────────────────────────────────────────────┐
│ [取消]                              [保存]  │
│ 编辑小任务                                  │  ← Title_L / white
│                                            │
│ 图标选择                                    │  ← SectionTitle secondary
│                 [已选图标]                  │  ← IconPicker / empty state
│                                            │
│ 基础信息                                    │
│ ┌────────────────────────────────────────┐ │
│ │ 名称                                    │ │  ← TextInput dark
│ │ ────────────────────────────────────── │ │
│ │ 简介                                    │ │  ← TextInput dark
│ └────────────────────────────────────────┘ │
│                                            │
│ Prompt                                     │
│ ┌────────────────────────────────────────┐ │
│ │ TextArea                                │ │
│ │                          [输入工具][录音]│ │
│ │ [加入当前日期]                 [Toggle] │ │
│ └────────────────────────────────────────┘ │
│                                            │
│ 工具                                        │
│ ┌────────────────────────────────────────┐ │
│ │ 工具                            未设置 >│ │
│ └────────────────────────────────────────┘ │
└────────────────────────────────────────────┘
```

组件和功能：

- 顶部使用 `AISettingsNavHeader` 的取消/保存双操作模式；保存按钮在名称、Prompt 未通过校验时显示禁用态，深色下禁用态不能只降低透明度，要保留文本可读性。
- “图标选择”是一个独立的 `AISettingsIconPickerRow`：点击进入图标选择页，当前图标显示在固定尺寸容器内；没有图标时显示业务默认图标，不显示空白大区域。
- 基础信息卡由两个 `AISettingsFormField` 组成，暗色 TextInput 的输入文字使用 primary，placeholder 使用 secondary，输入光标和选中高亮使用蓝色。
- Prompt 使用 `TextArea` 放在较大的 `AISettingsCard` 内；底部工具输入和语音按钮是辅助操作，不应覆盖文本编辑区。键盘出现时卡片底部必须可滚动到。
- “在系统提示词中追加当前日期”使用 `AISettingsToggleRow`，字段落为 `appendCurrentDate`；只是草稿值，不在 Toggle 点击时立即保存。
- “输入工具”进入工具选择页；语音按钮只负责录音/语音转文字能力，不把音频数据混入小任务实体。
- 对标 Demo：`ToolsTemplate/AIOffice/components/business_setting/src/main/ets/pages/SettingPersonal.ets` 的 TextInput、Sheet 表单与自定义返回；`HomeDecoration/components/module_posting/Posting.ets` 的 TextArea 组合。

#### A.16.3 截图 8：模型页筛选、菜单与模型行

```text
┌────────────────────────────────────────────┐
│ [返回] [+]     [全部 | 模型 | 智能体]       [菜单]│
│                                            │
│ 模型                                        │
│ ┌────────────────────────────────────────┐ │
│ │ [logo] Doubao Seed 1.6       [信息][开关]│ │
│ │        工具 视觉 思考 经济              │ │
│ │ ────────────────────────────────────── │ │
│ │ [logo] Doubao Seed 1.6 Lite [信息][开关]│ │
│ └────────────────────────────────────────┘ │
└────────────────────────────────────────────┘
```

组件和功能：

- 顶部采用 `Row`：左侧返回按钮，中间 `SegmentedButton` 或等价分段控件，右侧加号和菜单图标按钮；分段控件只改变当前列表过滤，不改变模型数据。
- 分段值定义为 `all`、`model`、`agent`，过滤条件使用明确的 `ModelKind`，不能用显示文字“全部/模型/智能体”参与业务判断。
- 右侧加号使用 `SymbolGlyph`/资源图标按钮并提供 tooltip/accessibility text，菜单使用 `Menu` 或 `bindMenu`，菜单项包括“刷新远端模型”“导入本地模型”“管理 Provider”；菜单动作进入同一导航控制器。
- 模型行由 `AISettingsModelRow` 实现，固定为：logo 48vp、内容自适应、信息按钮 40vp、Toggle 64vp；长名称最多两行，能力标签在名称下方换行。
- 信息按钮打开能力详情，不等于编辑；点击模型主体进入编辑页；Toggle 仅控制 enabled，不能隐式修改默认模型绑定。
- 深色主题下模型卡片背景使用暗色卡片 token，分段选中态使用中灰底和白字，未选中态透明或更深灰；蓝色只用于可操作 icon 和开关。
- 对标 Demo：`business_setting/SettingPage.ets` 的页面分组结构、`HomeDecoration/features/home/SearchPage.ets` 的 Search/列表过滤思想；分段控件需要按当前 API Level 选用官方 `Tabs`、`SegmentedButton` 或自建等价组件并编译确认。

#### A.16.4 截图 9：新建智能体

```text
┌────────────────────────────────────────────┐
│ [取消]                         新建智能体[创建]│
│                                            │
│ 图标选择                                    │
│                   [听诊器图标]              │
│                                            │
│ 基础信息                                    │
│ ┌────────────────────────────────────────┐ │
│ │ 智能体名称                              │ │
│ └────────────────────────────────────────┘ │
│                                            │
│ 智能体设定                                  │
│ ┌────────────────────────────────────────┐ │
│ │ TextArea：系统提示词                     │ │
│ │ [自动填写] [输入工具] [语音]             │ │
│ │ 在系统提示词中追加当前日期       [开关]  │ │
│ │ 关联小任务                         0   > │ │
│ └────────────────────────────────────────┘ │
│                                            │
│ 基础模型                                    │
│ ┌────────────────────────────────────────┐ │
│ │ 基座模型                    Doubao... ⇅ │ │
│ │ Doubao Seed 1.6                         │ │
│ └────────────────────────────────────────┘ │
└────────────────────────────────────────────┘
```

组件和功能：

- `AgentEditorPage` 使用 `AgentDraft`，创建态标题为“新建智能体”，编辑态标题为“编辑智能体”；右上角分别显示“创建/保存”。
- 图标区域使用 `AISettingsIconPickerRow`，默认图标必须来自应用资源，不能用空字符串导致 `Image` 渲染异常。
- 名称字段必填且需要账号内唯一；创建按钮只在名称、基座模型和 Prompt 通过最小校验后启用。
- 智能体设定卡由 `TextArea`、工具按钮、语音按钮、日期 Toggle 和关联小任务行组成；每个控件拥有独立的可访问名称和 loading/disabled 状态。
- 关联小任务点击进入 `SmallTaskSelectionPage`，返回 `taskIds`；父页显示数量，不把完整小任务对象复制进 Agent 草稿。
- 基座模型使用 `AISettingsPickerRow` 打开本地/Pro 模型选择；显示 `source + displayName + modelId`，保存时重新验证模型是否仍启用。
- 创建顺序：校验 -> 生成 agentId -> RDB 写入草稿/实体 -> 更新 KV 场景索引 -> Resolver 重建 -> 返回模型页。
- 对标 Demo：`SettingPersonal.ets` 的编辑表单和 `bindSheet`；`module_posting/Posting.ets` 的 TextArea；图标/资源选择参考目标 Demo 中的 Grid/ForEach 组合。

#### A.16.5 截图 10：编辑模型

```text
┌────────────────────────────────────────────┐
│ [取消]                           编辑模型[保存]│
│                                            │
│ 名称                                        │
│ ┌────────────────────────────────────────┐ │
│ │ Doubao Seed 1.6                         │ │
│ └────────────────────────────────────────┘ │
│                                            │
│ 图标                                        │
│                 [加载中 / 当前 logo]        │
│                                            │
│ 使用场景与工具                              │
│ ┌────────────────────────────────────────┐ │
│ │ 使用场景                      15      > │ │
│ │ 工具                          全部    > │ │
│ │ 关联小任务                    0       > │ │
│ └────────────────────────────────────────┘ │
│                                            │
│ 能力                                        │
│ ┌────────────────────────────────────────┐ │
│ │ 支持文本                         [开关] │ │
│ │ 支持多模态                       [开关] │ │
│ │ 支持推理                         [开关] │ │
│ │ 思考可控                         [开关] │ │
│ │ 支持工具调用                     [开关] │ │
│ └────────────────────────────────────────┘ │
└────────────────────────────────────────────┘
```

组件和功能：

- 名称字段默认可编辑时只修改 `displayName`；系统 `modelId`、providerCode、source 等身份字段只读并隐藏在详情模型中，避免误改导致重复实体。
- 图标加载期间显示 `LoadingProgress`，完成后显示 logo；图标选择返回后只替换 `iconId`。
- “使用场景与工具”卡内三行使用 `AISettingsPickerRow`，数字是从绑定快照计算的摘要；进入详情后允许修改草稿，回到编辑页时刷新数量。
- 能力卡的每个 Toggle 使用 `CapabilityDraft`；对 Pro 模型，后端声明能力不可被本地任意打开；对本地模型，manifest 声明是上限，UI 只能在已安装能力范围内选择。
- 保存时检查：至少支持文本或其他有效模态之一、默认场景绑定合法、工具权限合法、模型处于可用 Provider 下；失败不退出页面。
- 删除属于危险操作，应放在页面底部或菜单中，不与保存按钮相邻；删除后需要检查默认模型和 Agent 引用。
- 对标 Demo：`RecordListPage.ets` 的列表状态管理；`SettingPersonal.ets` 的表单字段和返回；`FilterList.ets` 的选择结果回传模式。

#### A.16.6 截图 11：默认模型配置与能力场景卡片

```text
┌────────────────────────────────────────────┐
│ [返回]                                     │
│ 默认模型配置                                │
│                                            │
│ 对话                                        │
│ ┌────────────────────────────────────────┐ │
│ │ [对话图标]                              │ │
│ │ 对话模型用于日常问答、内容生成与多轮对话。│ │
│ │ ────────────────────────────────────── │ │
│ │ [本地模型        |        Pro 模型]      │ │  ← Segmented
│ │ ────────────────────────────────────── │ │
│ │ 场景模型             Doubao Seed 1.6 ⇅ │ │
│ │ [logo] Doubao Seed 1.6                   │ │
│ │        doubao-seed-1-6                   │ │
│ └────────────────────────────────────────┘ │
│                                            │
│ 向量模型                                    │
│ ┌────────────────────────────────────────┐ │
│ │ [向量图标]                              │ │
│ │ 向量模型用于知识索引、相似度检索与语义召回。│ │
│ │ [本地模型        |        Pro 模型]      │ │
│ │ 暂无可用模型：服务端未下发，且本地未配置 Key │
│ └────────────────────────────────────────┘ │
│                                            │
│ 语音模型                                    │
│ ┌────────────────────────────────────────┐ │
│ │ [波形图标] 语音模型用于文本转语音与播报能力 │ │
│ │ [本地模型        |        Pro 模型]      │ │
│ └────────────────────────────────────────┘ │
└────────────────────────────────────────────┘
```

组件和功能：

- 页面使用 `AISettingsSection + AISettingsCapabilityCard`，每张卡片由 icon、说明、`SegmentedButton`、模型选择行和当前模型摘要组成。
- 场景枚举至少包括 `conversation`、`embedding`、`speech`；显示标题和说明来自资源/配置映射，Resolver 使用稳定枚举，不使用中文标题作为 key。
- `本地模型/Pro 模型` 是当前场景的 source 选择，不是全局开关；切换时只切换草稿 source 并刷新可用模型列表。
- 当前模型选择行显示 displayName 和 modelId 两行；无可用模型时使用 `AISettingsEmpty`，同时说明缺失原因：未下发、未配置 API Key、未安装本地文件或能力不匹配。
- 场景卡的模型列表必须经过统一 Resolver：本地模型先检查安装、manifest 和 enabled，Pro 模型检查账号权限、Provider Key 和服务端下发状态，再生成可选项。
- 选择保存后更新场景绑定快照和运行时缓存；切换失败恢复之前的 source/model，不将半成品写入默认配置。
- 对标 Demo：`SettingPage.ets` 的多分组滚动布局、`RecordListPage.ets` 的 loading/empty/content 分支；分段选择参考目标 SDK 的官方控件或已验证 Demo 组件。

#### A.16.7 深色主题页面验收用例

- 系统切换浅色/深色时，AI 首页、Provider 编辑、模型页、Agent 编辑、默认模型配置同步切换，不能出现白色输入框或黑色文字。
- 深色页面中所有卡片仍能与背景区分，分割线、禁用按钮、Toggle 关闭态和错误文案可读。
- 模型页切换“全部/模型/智能体”后列表稳定，连续快速切换不会出现旧列表残留或重复项。
- 新建智能体输入名称、Prompt、关联模型和小任务，取消不落库，创建成功后模型页筛选为“智能体”可以找到该实体。
- 编辑模型切换能力、场景和工具，保存后 Resolver 立即反映；服务端能力不允许的开关显示禁用原因。
- 默认模型配置切换本地/Pro，分别验证有可用模型、无可用模型、Provider Key 缺失、本地模型未安装四种状态。
- 所有新页面都验证标题栏返回、系统返回、边缘手势返回和保存/取消按钮，不能重新触发 `ai.settings` 空白页。
