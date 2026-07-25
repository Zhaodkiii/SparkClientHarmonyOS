# SparkClientHarmonyOS｜消息卡片 UI 与对话列表实现方案

> 基线：iOS《消息卡片UI、对话列表》；实现日期：2026-07-22。
> 本文描述鸿蒙当前真实代码，不把 iOS UIKit/SwiftUI 组件名称当作鸿蒙已实现能力。

## 1. 实现范围

鸿蒙采用 ArkUI 原生组件，数据来自 `ChatRepository` 的 RDB 投影：

```text
ChatRepository
  → ChatThread / ChatMessage / ChatMessageBlock
  → ChatThreadListItem / ChatMessagePreview
  → ChatTabPage
  → ChatMessageCardView
```

对应文件：

- `Domain/ChatModels.ets`：线程、消息、块、附件和同步状态。
- `Presentation/ChatPresentationModels.ets`：列表项、预览、瞬时 UI 状态、块展示投影。
- `Presentation/ChatMessageCardView.ets`：文本、推理、工具、附件、健康、任务和医疗提示卡片宿主。
- `Presentation/ChatTabPage.ets`：线程切换、消息列表、附件 composer 和发送状态。
- `Presentation/ChatConversationListPage.ets`：独立会话列表页、搜索、空态、刷新、新建和详情导航。
- `Presentation/ChatRoutes.ets`：`NavPathStack` 路由常量。
- `Presentation/ChatTimelineProjector.ets`：工具块归并、用户健康资料引用分组和稳定排序。
- `Presentation/ChatMessageTimelineView.ets`：ArkUI 时间线宿主。
- `Domain/ChatCardPayloads.ets`：工具、健康、附件、任务、医疗卡显式 payload 模型。

## 2. 消息模型

### 2.1 Message

`ChatMessage` 是消息事实源的本地投影，不承载页面临时状态：

| 字段 | 语义 |
| --- | --- |
| `clientId` | 客户端稳定幂等 ID，也是 UI identity |
| `serverMessageId` | 服务端 ACK 后的 ID |
| `threadClientId/threadId` | 账号内线程关联 |
| `role/kind` | system/user/assistant 与 text/tool/system/error |
| `text` | 可直接展示的主文本 |
| `attachmentsJson` | 附件 metadata，不保存二进制 |
| `deliveryStatus` | pending/sending/streamed/completed/failed/cancelled/sent/read |
| `syncState` | pending/sending/synced/failed，Outbox 状态 |
| `localRevision` | 本地消息修订序号 |
| `blocks` | 按 orderKey/revision 合并后的时间线块 |

空文本并不代表空消息：附件、工具卡、健康引用和状态卡均可构成有效消息。

### 2.2 Block

`ChatMessageBlock` 是消息时间线最小渲染单元：

- `blockId`：由 `ChatStableBlockID` 生成，禁止每次刷新随机变化。
- `kind`：text、deepThought、tool、toolPresentation、imageGallery、fileAttachments、healthCards、structuredHealthCards、sleepVisualization、nutritionCards、workoutVisualization、captureCard、smallTaskCard、taskCards、healthResourceReference、medicalRiskNotice、medicalDisclaimerCard 等。
- `orderKey`：文本/推理/工具/富内容的稳定排序依据。
- `revision`：流式更新单调递增，旧 revision 不覆盖新 revision。
- `status`：pending/streaming/ready/failed。
- `payloadJson`：卡片专属 payload；UI 只解析已声明字段，未知字段显示安全降级卡。
- `syncState`：块级 pending/synced，支持主消息 ACK 后迟到的工具结果再次上送。

### 2.3 UI 临时状态

`ChatMessageUIState` 只存在页面生命周期：软删除、翻译文案、翻译中、推理展开、卡片保存 ID。它不能覆盖 RDB 消息事实，也不能参与远端同步。

## 3. 对话列表模型

`ChatThreadListItem.from(thread, latestMessage)` 将数据库线程和最新消息投影为 UI 行：

| 展示项 | 规则 |
| --- | --- |
| 标题 | `thread.title`，为空显示“新对话” |
| 预览 | 主文本 > 附件消息 > 首个 block 文本 > 状态文案 |
| 时间 | 使用 `thread.updatedAt`，后续接本地化 today/yesterday/MM-dd formatter |
| 置顶 | `isPinned` 排序和视觉标记 |
| 外观 | `iconName/iconColorName`，无值使用默认聊天图标 |
| identity | `thread.clientId`，切换账号时整个投影重建 |

列表搜索必须在内存投影上过滤，不把 UI 搜索词发送到服务端。列表为空时分为本地加载中、远端兜底同步中、真正空态和错误保留本地四种状态。

## 4. ArkUI 视觉设计

### 4.1 设计 token

| Token | 值 | 用途 |
| --- | --- | --- |
| page background | `#F6F8FB` | 对话页面底色 |
| assistant surface | `#FFFFFF` | 助手气泡 |
| user accent | `#3973B9` | 用户气泡、发送动作 |
| card surface | `#F7FAFC` | 富内容卡片 |
| border | `#E5EDF5` | 卡片边界 |
| primary text | `#20252B` | 正文 |
| secondary text | `#66717D` | 元信息/状态 |
| danger | `#D14343` | 失败/医疗风险 |
| warning | `#B7791F` | pending/处理中 |
| radius | 14vp | 气泡/卡片 |
| spacing | 8/12/16vp | 行内、卡片、页面间距 |

交互反馈使用短促 press 状态；流式文本不做逐字符动画，避免高频刷新造成视口抖动。卡片展开/收起仅改变内容高度，后续接入滚动锚定时应保持当前可见消息。

### 4.2 气泡规则

- 用户消息右对齐，accent 背景，正文白色。
- 助手/system 消息左对齐，白色背景，正文深色。
- 消息块按 `orderKey → createdAt → blockId` 排序。
- 文本块使用普通正文渲染；非文本块进入 `ChatMessageCardView`。
- 空文本但存在 block/attachment 时不隐藏消息。
- failed/pending/streaming 必须显示明确状态，不能渲染空白占位。

## 5. 卡片设计与映射

| block kind | 卡片标题 | 当前行为 |
| --- | --- | --- |
| `deepThought` | 思考过程 | 折叠/展开预留，当前显示辅助文本 |
| `tool` | 工具调用 | 显示处理中或工具文本 |
| `toolPresentation` | 工具结果 | 显示结构化结果摘要 |
| `imageGallery` | 图片 | 显示附件摘要，后续接图片网格 |
| `fileAttachments` | 附件 | 显示文件摘要和下载状态 |
| `healthCards/structuredHealthCards` | 健康卡片 | 显示 payload 摘要，保留动作区扩展点 |
| `sleepVisualization` | 睡眠 | 使用健康数据卡视觉 |
| `nutritionCards` | 营养分析 | 使用营养摘要卡视觉 |
| `workoutVisualization` | 运动分析 | 使用运动摘要卡视觉 |
| `captureCard` | 采集信息 | 显示待采集/已采集状态 |
| `smallTaskCard/taskCards` | 任务 | 显示任务状态，动作回调后续接 UseCase |
| `healthResourceReference` | 健康资料 | 显示引用摘要，连续引用后合并为 group |
| `medicalRiskNotice` | 风险提示 | danger accent，不使用普通 success 样式 |
| `medicalDisclaimerCard` | 医疗免责声明 | assistant sending 时延后展示 |
| unknown | 智能内容 | 显示安全摘要，不让未知 payload 导致崩溃 |

卡片组件不直接写数据库或调用网络；保存、任务确认、工具预览和健康资料导航必须通过页面/UseCase 回调接线。

## 6. 当前页面流程

```text
aboutToAppear
  → ensureDefaultThread
  → listThreads / listMessages
  → pullThreadMessages
  → ChatThreadListItem projection
  → ChatMessageCardView render

pick image/file
  → Photo/Document Picker
  → FileTransferService private upload
  → image OCR / document adapter
  → prepared attachment
  → user message + attachment blocks
  → MessageRunActor
  → RDB + Outbox
```

## 7. 与 iOS 的差异与下一批

已对齐：消息/块语义、稳定 identity、线程投影、pending/failed 状态、附件块、工具/健康/医疗卡片宿主、账号隔离和本地优先读模型。

仍需继续：

1. 独立 `ChatConversationListPage` 路由与搜索、置顶、删除、外观编辑 sheet。
2. 最新消息/时间 formatter、列表空态、下拉刷新和分页加载更旧消息。
3. ArkUI 虚拟列表滚动锚定、流式贴底、顶部加载旧消息时保持视口。
4. 每种 card payload 的显式 DTO 与真实交互回调，而不是通用摘要卡。
5. 长按菜单、复制、选中文本、翻译和 UIState 快照。

## 8. 完整数据模型设计

### 8.1 领域模型、读模型、UI 模型分层

三类模型不能混用：

```text
远端 DTO / RDB Entity
        ↓ decode + merge
ChatMessage / ChatThread / ChatMessageBlock
        ↓ projection
ChatThreadListItem / ChatMessagePreview / ChatBlockPresentation
        ↓ render
ArkUI Component
```

| 模型层 | 是否持久化 | 是否可修改事实 | 主要用途 |
| --- | --- | --- | --- |
| Remote DTO | 否 | 否 | 网络传输、服务端字段兼容 |
| RDB Entity | 是 | 是 | 账号隔离、同步、恢复 |
| Domain Model | 否 | 由 Repository 生成 | 业务规则和 UseCase 输入 |
| Read Model | 否 | 否 | 列表和消息窗口快速读取 |
| UI State | 否 | 否 | 展开、翻译、菜单、卡片 loading |
| Card Payload | 通常随 block JSON 持久化 | 不能直接写网络 | 卡片渲染和动作参数 |

### 8.2 Thread 详细字段

```text
ChatThread
├── clientId / threadId       稳定线程身份
├── accountId                 账号隔离键
├── title                     列表标题
├── scenario                  chat / health / report 等场景
├── patientId / memberId      当前健康成员上下文
├── preferredModelName       当前线程模型
├── rolePrompt                线程级系统提示
├── imageDeliveryMode        directMultimodal / localOCR 等策略
├── isPinned / pinnedAt       列表置顶
├── iconName / iconColorName  外观配置
├── createdAt / updatedAt     本地排序时间
└── serverUpdatedAt / deletedAt 远端合并和 tombstone
```

线程列表排序规则：`isPinned DESC → updatedAt DESC → clientId ASC`。排序必须稳定，不能因同一毫秒内多条消息写入而抖动。

### 8.3 Message 与 Block 关系

一个消息可以只有文本，也可以由多个 block 组成：

```text
ChatMessage
├── text                         主文本，可为空
├── attachmentsJson              附件 metadata
└── blocks[]
    ├── text / deepThought       文本和推理
    ├── tool / toolPresentation  工具调用和结果
    ├── imageGallery             图片组
    ├── fileAttachments          文件组
    ├── healthResourceReference  健康资料引用
    └── rich card kinds           健康、任务、医疗、采集、知识
```

块排序使用：

1. `orderKey` 升序。
2. `createdAt` 升序。
3. `blockId` 字典序作为最终 tie-breaker。

块更新必须满足 `incoming.revision >= local.revision`；相同 revision 使用 `updatedAt` 和来源优先级判断，禁止随机覆盖。

### 8.4 Card Payload 规范

每种卡片 payload 都应包含通用元数据：

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `schemaVersion` | string | payload 版本，例如 `1.0` |
| `cardId` | string | 卡片稳定 ID |
| `title` | string | 可选标题 |
| `subtitle` | string | 可选副标题 |
| `status` | string | pending/ready/failed/saved |
| `source` | string | ai/tool/health/user/server |
| `createdAt` | string | ISO-8601 时间 |
| `actionPolicy` | object | 允许的动作集合 |

业务 payload 不能把隐私数据写入日志。卡片日志只允许输出 `cardId`、kind、status、itemCount 和错误类别。

## 9. 读模型与查询策略

### 9.1 线程列表读模型

线程列表不应为每一行重复查询完整消息历史。推荐由 Repository 返回：

```text
ChatThreadListProjection
├── thread
├── latestMessagePreview
├── latestMessageAt
├── unreadCount（若后端提供）
├── syncState
└── presentationFlags
```

本地没有独立 projection 表时，可先批量读取线程，再按 `threadClientId` 获取每个线程最新一条消息；不得在 UI `ForEach` 内部调用数据库。

### 9.2 消息窗口

消息窗口参数建议固定为：

| 参数 | 建议值 | 说明 |
| --- | --- | --- |
| `initialNewestLimit` | 20 | 首屏最新消息数 |
| `loadOlderPageSize` | 20 | 顶部加载旧消息页大小 |
| `maxPageCount` | 20 | 单次同步保护阈值 |
| `pinnedDistanceThreshold` | 80vp | 判断是否跟随底部 |
| `partialDebounce` | 50ms | 流式文本 UI 合并窗口 |

读模型需要返回 `hasMoreOlder`、`oldestCreatedAt`、`newestCreatedAt` 和 `isLoadingOlder`，而不是只返回数组。

### 9.3 账号与线程隔离

所有读模型 key 至少包含 `accountId + threadId`。账号切换时必须：

1. 停止实时连接。
2. 取消旧线程加载任务。
3. 清空内存中的 threadItems/messages/card UI state。
4. 重新读取新账号数据。
5. 校验旧异步回调的 generation，禁止写入新账号。

## 10. Presentation 架构

```text
ChatConversationListPage
├── ChatListViewModel
│   ├── load local
│   ├── refresh remote
│   ├── search/filter
│   ├── create/delete/pin
│   └── appearance editing
└── ChatThreadRow

ChatView
├── ChatDetailViewModel
├── ChatMessageWindowController
│   ├── load newest
│   ├── load older
│   ├── follow bottom
│   └── preserve anchor
├── ChatMessageRow
│   ├── ChatBubble
│   └── ChatTimelineProjector
│       └── ChatMessageCardView
└── ChatComposer
```

鸿蒙不必复制 iOS 的 UIKit 宿主，但必须保留职责边界：

- Page 负责生命周期和导航。
- ViewModel/UseCase 负责动作和状态。
- Read Model 负责列表与消息窗口投影。
- Card View 只负责渲染和回调。
- Repository 不进入组件树。

## 11. 对话列表 UI 设计

### 11.1 列表行结构

```text
┌──────┬────────────────────────────┬──────┐
│ 图标 │ 标题                         │ ⋯    │
│      │ 最新消息预览                 │ 时间 │
└──────┴────────────────────────────┴──────┘
```

- 行高：72–84vp。
- 图标：40vp 圆角容器，使用线程外观颜色。
- 标题最多 1 行，预览最多 2 行。
- 置顶线程可在标题左侧显示小型 pin 标记。
- 右侧菜单提供置顶、编辑外观、删除。
- 删除必须二次确认，并优先使用可撤销的本地操作反馈。

### 11.2 列表状态

| 状态 | UI |
| --- | --- |
| 首次加载 | skeleton 行，不显示“暂无对话” |
| 本地为空、远端同步中 | 居中 loading + “正在同步对话” |
| 真空态 | 插图/图标 + “开始新的健康对话” + 主按钮 |
| 搜索无结果 | “没有匹配的对话” + 清除搜索 |
| 刷新失败但有本地数据 | 保留列表，顶部轻量错误提示 |
| 未登录 | 登录引导，不读取任何线程 |

## 12. 消息时间线 UI 设计

消息列表采用虚拟化列表，key 使用 `clientMessageId`；块 key 使用 `blockId + revision`。新增历史消息时在顶部插入，不重建底部可见区域。

### 12.1 滚动规则

- 用户距离底部 ≤80vp 且没有拖拽：流式消息跟随底部。
- 用户主动上滑：停止自动跟随，只显示“回到底部”浮动按钮。
- 顶部加载旧消息：记录第一条可见消息 ID 和相对偏移，加载后恢复锚点。
- 卡片展开导致高度变化：若用户贴底则保持底部，否则保持当前可见消息。
- 切换线程：清除旧 anchor，加载新线程最新窗口并贴底。

## 13. 卡片设计系统

### 13.1 通用卡片结构

```text
卡片容器
├── Header
│   ├── 类型图标
│   ├── 标题
│   └── 状态徽标
├── Content
│   ├── 摘要
│   ├── 结构化指标/列表/图表
│   └── 错误或空态
└── Footer
    ├── 来源/更新时间
    └── 操作按钮
```

卡片容器统一使用 14vp 圆角、1vp 边框、12–16vp 内边距；阴影只用于浮层或可点击卡片，不给所有消息增加重阴影。

### 13.2 卡片颜色语义

| 语义 | 主色 | 使用 |
| --- | --- | --- |
| 普通信息 | `#3973B9` | 工具结果、健康摘要 |
| 成功/已保存 | `#268A5B` | 保存成功、任务完成 |
| 处理中 | `#B7791F` | streaming、pending |
| 风险/失败 | `#D14343` | 风险提示、抽取失败、发送失败 |
| 医疗免责声明 | `#66717D` | 中性灰，避免与风险混淆 |

### 13.3 交互状态

每个可操作卡片必须定义：默认、按下、loading、成功、失败、禁用六种状态。按钮 loading 期间要锁定同类动作，避免重复保存或重复确认。

### 13.4 健康与医疗卡片

- 健康数据必须显示来源与数据时间范围。
- 没有真实 HarmonyOS 健康数据时显示“数据源不可用”，不能展示 mock 数据冒充设备数据。
- 医疗风险卡片使用风险色，但不使用“诊断结论”措辞。
- 免责声明卡片必须与正文有明确视觉分隔，不能在流式中途抢先出现。

## 14. 可访问性与本地化

- 所有图标按钮提供无障碍文本，例如“置顶对话”“移除附件”“展开卡片”。
- 颜色不能作为唯一状态表达，必须同时有文字、图标或形状。
- 正文最小 16fp；辅助文本不低于 12fp，支持系统字体放大后不截断关键操作。
- 长标题、长文件名和超长卡片摘要必须截断并提供完整查看路径。
- 中英文、简体中文日期、错误文案和医疗术语使用本地化 key，禁止在组件中散落硬编码。

## 15. 错误与恢复矩阵

| 场景 | 保留什么 | 用户看到什么 | 可执行动作 |
| --- | --- | --- | --- |
| 列表刷新失败 | 本地线程列表 | 顶部错误提示 | 重试 |
| 消息发送失败 | user/assistant 消息和 blocks | 失败状态卡 | 重试同步 |
| 工具调用失败 | 工具块和错误 payload | 工具失败卡 | 重试工具或继续对话 |
| 卡片 payload 解析失败 | 原始 block | “内容暂不可展示” | 查看原文/反馈 |
| 附件 OCR 失败 | 附件 metadata | OCR 失败提示 | 仍允许发送附件 |
| 健康数据不可用 | 引用 block | 数据源不可用 | 打开权限/设置 |
| 账号切换 | 清空旧内存投影 | 新账号 loading | 不允许旧任务回写 |

## 16. 验收清单

### 数据模型

- [ ] 同一 message/block 在刷新、同步、重进页面后 identity 不变。
- [ ] 旧 revision 不覆盖新 revision。
- [ ] 空文本附件消息仍能显示。
- [ ] UI 临时状态不会写回同步字段。
- [ ] 账号切换不会看到上一个账号的线程或卡片状态。

### 对话列表

- [ ] 置顶、搜索、创建、删除和外观编辑有明确状态。
- [ ] 空态、加载态、错误态可区分。
- [ ] 列表行预览来自统一投影，不在 UI 内重复拼接。
- [ ] 列表刷新不会破坏当前线程导航。

### 消息与卡片

- [ ] user/assistant 对齐正确。
- [ ] 流式输出贴底策略符合用户滚动行为。
- [ ] 顶部加载旧消息不跳动。
- [ ] 所有 block kind 都有明确 fallback。
- [ ] pending/streaming/failed 状态有可见反馈。
- [ ] 卡片动作具备 loading、成功、失败和重复点击保护。
- [ ] 健康卡片标记数据来源和时间范围。

## 17. 与 iOS 基线的对齐结论

鸿蒙需要对齐的是 iOS 的职责、状态语义、数据边界和用户可见行为，而不是复制 SwiftUI/UIKit 的具体实现。最终验收以以下四个条件为准：

1. 相同服务端消息在两个客户端产生相同的 Domain block 语义。
2. 相同状态下两个客户端给用户相同的 loading/error/retry 反馈。
3. 卡片动作的权限、审计、持久化和失败语义一致。
4. UI 可以使用平台原生组件，但列表、气泡、卡片和无障碍行为不能退化。

这些缺口不能用“构建成功”代替真机交互验收；每一项完成后需补对应页面和真机证据。

## 18. 本地 HarmonyOS 官方 Demo 对照

本轮实现参考目标工程内的官方模板集合：

`/Users/hua/Documents/project/Reference/LookHealthClient/SparkClientHarmonyOS/开发详细技术文档/agc-template-market-harmonyos-demos-main`

已采用的模式：

| 官方 Demo 模式 | 鸿蒙 Chat 使用方式 |
| --- | --- |
| `Navigation + NavPathStack` | 会话列表 → 会话详情独立导航栈 |
| `navDestination(builder)` | 按 route name 构造 `NavDestination` |
| `NavPathStack.pushPath({ name, param })` | 使用 thread client ID 进入详情 |
| `List + ForEach + stable key` | 线程行与消息/块渲染使用稳定 ID |
| 页面 `aboutToAppear` | 生命周期内加载本地读模型和刷新 |
| ViewModel/页面状态分离 | Repository/UseCase 保持在页面之外，UI 只持有投影状态 |

不能直接复制模板的部分：模板中的演示数据、Mock API、完整 body 日志、硬编码账号和示例 endpoint 不进入生产 Chat；聊天数据必须经过 `AppContainer → ChatRepository → ChatSyncEngine`，并带 `accountId` 隔离。

## 19. 当前已落地的端到端页面链路

```text
MainTabsPage
  → ChatConversationListPage
     → listThreads(accountId)
     → ChatThreadListItem projection
     → Search / empty / loading / refresh
     → pushPath(chat.detail, threadId)
        → ChatTabPage(showThreadSwitcher=false)
           → listMessages(accountId, threadId)
           → pullThreadMessages(threadId)
           → ChatTimelineProjector
              → ChatMessageCardView
           → ChatComposer
              → SendChatMessageUseCase
              → MessageRunActor
              → ChatRepository + ChatSyncEngine
```

## 20. 当前对齐状态

| iOS 能力 | 鸿蒙当前状态 |
| --- | --- |
| 独立线程列表页 | 已实现基础链路 |
| 本地搜索 | 已实现标题/预览过滤 |
| 空态/加载态/刷新态 | 已实现基础状态 |
| 新建线程并进入详情 | 已实现 |
| 独立详情页导航 | 已实现 `NavPathStack` |
| 消息时间线稳定排序 | 已实现 |
| 工具块归并 | 已实现基础 call ID 归并 |
| 健康资料连续引用分组 | 已实现基础分组 |
| 通用消息卡片宿主 | 已实现 |
| 显式卡片 payload 模型 | 已建立工具/健康/附件/任务/医疗模型 |
| iOS 26 种卡片逐种真实 payload 渲染 | 部分实现，仍需逐类接入真实 DTO |
| 置顶/删除/外观编辑 | 下一批 |
| 长按菜单/复制/翻译/朗读 | 下一批 |
| load older/滚动锚定 | 下一批 |

## 21. Markdown 文本渲染实现

### 21.1 本地依赖

Markdown 引擎来自：

`/Users/hua/Downloads/lv-markdown-in-master/markdown`

已复制到工程：

`entry/third_party/lv-markdown-in`

入口依赖使用本地 file 引用：

```json5
"@luvi/lv-markdown-in": "file:./third_party/lv-markdown-in"
```

组件入口为 `@luvi/lv-markdown-in` 的 `Markdown`，不是远端运行时下载；其底层 `@luvi/html2md`、公式和代码高亮依赖由 DevEco OHPM 安装到 `entry/oh_modules`。

### 21.2 消息卡片接入规则

`ChatMessageCardView` 对以下内容使用 Markdown：

- 普通文本 block。
- 深度思考/推理 block。
- 工具结果摘要。
- 健康、任务、附件、医疗卡片中的说明文本。
- 流式文本和服务端返回的 Markdown 内容。

渲染入口：

```text
ChatMessage
  → ChatTimelineProjector
  → ChatMessageTimelineView
  → ChatMessageCardView
  → Markdown({ controller, text })
```

当前控制器配置：

| 配置 | 用户消息 | 助手/卡片消息 |
| --- | --- | --- |
| 文本颜色 | `#FFFFFF` | `#20252B` |
| 字号 | 16vp | 文本 16vp、卡片 14vp |
| 行高 | 24vp | 文本 24vp、卡片 21vp |
| 文本选择 | 开启 | 开启 |

Markdown 引擎的链接、图片、代码复制和文本选择回调必须经过 `MarkdownController` 统一接入；不允许在消息卡片内直接打开未知 URL，也不允许把完整消息正文写入日志。

### 21.3 流式渲染约束

- Markdown 文本更新采用 latest-wins，不能为每个 token 创建新的组件 identity。
- block identity 继续使用 `blockId + revision`。
- `pending/streaming` 的富卡片显示状态文案；正文未准备好时不得传入空白 Markdown。
- 超长 Markdown、Mermaid、公式和代码块需要在后续版本启用引擎的懒渲染/Worker 能力，并以消息窗口分页限制内存。
- 用户上滑阅读历史时，流式 Markdown 更新不得强制滚到底部。

### 21.4 复制与安全

本地库从 3.1.0 起不直接替应用复制文本；如启用复制，需要在 `MarkdownController.setTextSelectionCopyListener` 和 `setCodeCopyListener` 中接入 HarmonyOS Pasteboard，并仅复制用户主动选中的内容。Markdown 中的图片、链接和 HTML 不能绕过应用权限策略。

## 22. 会话列表与详情页滚动、顶部导航约束

### 22.1 会话列表

`ChatConversationListPage` 使用 HarmonyOS `Refresh({ refreshing }) + List`：

- 列表内容支持垂直滚动。
- 下拉触发 `chatSyncEngine.refreshThreadListIncremental()`。
- 刷新结束后重新读取当前账号的 `chat_thread` 投影。
- 搜索栏固定在列表上方，搜索只过滤内存投影。
- 加载态、空态、错误态不影响列表容器的滚动与下拉手势。

### 22.2 会话详情

`ChatTabPage` 的消息区使用 `Refresh({ refreshing }) + List`：

- 消息列表支持垂直滚动。
- 下拉触发当前 thread 的 `pullThreadMessages`。
- 消息发送、流式 block、卡片高度变化都在同一消息列表容器内更新。
- 附件预览区是独立横向滚动区域，不抢占消息列表的垂直滚动手势。

### 22.3 详情页顶部导航

对齐 iOS `ChatView.swift` 的 `navigationDecoratedLayout`，鸿蒙详情页不再展示独立大标题或重复的“新对话”入口，只保留：

```text
┌────┬──────────────────────┬─────┐
│ <  │       会话名          │ ⋯   │
└────┴──────────────────────┴─────┘
```

- 左侧 `<`：返回会话列表，由 `NavPathStack.pop()` 执行。
- 中间：当前 thread title，单行省略。
- 右侧 `⋯`：HarmonyOS `bindMenu`，对应 iOS `ToolbarItem + Menu`。
- 当前菜单动作：刷新消息、同步会话、新建对话。
- 详情页不显示线程横向切换条；线程切换统一回到会话列表完成。
