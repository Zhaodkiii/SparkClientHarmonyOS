# HOS-MED-EXAM-0006 检查报告头部、附件列表与卡片 UI iOS 对齐工单

> 状态：待修复  
> 创建时间：2026-07-26  
> 范围：只改动鸿蒙项目 `SparkClientHarmonyOS`。不修改 iOS、后端、后台管理端。  
> 目标端：`/Users/hua/Documents/project/Reference/LookHealthClient/SparkClientHarmonyOS/`  
> 参考端：`/Users/hua/Documents/project/Reference/LookHealthClient/SparkClient/`  
> 关联前置工单：`HOS-MED-EXAM-0005-检查报告列表详情无法跳转iOS对齐工单.md`

## 1. 对标范围与结论

本工单覆盖检查报告列表卡片的三个体验偏差：

1. **头部点击无法跳转到详细页面**：检查报告卡片/分组头部区域的可点击范围与跳转承接需要对齐 iOS，用户点击头部主要信息时应进入检查报告详情，而不是只有局部“查看详情”可尝试跳转。
2. **附件点击后没有展示附件列表**：附件入口必须使用项目内公共组件 `MedicalAttachmentIconView` + `MedicalAttachmentListView`，点击附件图标后展开附件列表，再由列表项进入统一预览。
3. **卡片 UI 未对齐 iOS**：卡片头部、附件入口、三类报告内容区、重点信息展开、统计块、间距、颜色、圆角、阴影和 loading 状态需要按 iOS `LabReportCard.swift` 重新核验。

当前 HarmonyOS 已有代码证据：

| 模块 | 当前代码证据 | 现状判断 | 本工单要求 |
| --- | --- | --- | --- |
| 分类与时间线 | `entry/src/main/ets/Projects/Features/Home/Presentation/MedicalLists/ExaminationReports/ExaminationReportCategory.ets:117-151` | 已有连续同分类聚合 `buildExaminationTimelineSections`，但这里只负责数据分段，不承接头部点击跳转 | 不要在分类工具函数里塞路由；跳转应在列表/卡片 Presentation 层处理 |
| 列表分组头 | `ExaminationReportsListPage.ets:467-513` | `timelineSectionView` 绘制分组头 + 卡片列表；分组头当前仅展示图标、标题、数量 | 分组头如需点击，应进入该分组第一条报告详情，或明确只作为视觉头；卡片头部必须可跳详情 |
| 卡片 | `LabReportCard.ets:146-211`、`:281-320` | 卡片整体已绑定 `onClick`，详情按钮也触发 `triggerOpenDetail`；仍需检查头部子组件/附件按钮事件是否被外层点击吞掉或冲突 | 头部主信息点击、详情按钮点击、卡片空白区域点击都应稳定进入同一详情目标 |
| 附件公共组件 | `Shared/MedicalAttachmentComponents.ets:40-206` | 已有 `MedicalAttachmentIconView` 和 `MedicalAttachmentListView`，列表项支持下载后统一预览 | 卡片内必须复用公共列表，不允许另写私有附件弹层或只显示图标 |
| iOS 参考 | `SparkClient/.../ExaminationReports/LabReportCard.swift:105-171`、`Shared/MedicalAttachmentComponents.swift:41-165` | iOS 头部右侧含 `detailAction` + 附件入口；附件展开后渲染公共附件列表 | 鸿蒙应按同一职责拆分，而非把附件打开逻辑写在卡片内部 |

结论：本工单是 **HarmonyOS Presentation 层对齐修复**，不需要新增后端接口，不允许改 iOS，也不应改变 `examination_report` / `med-exam-details` 的后端契约。

## 2. 华为端目录设计

本工单只涉及以下 HarmonyOS 文件：

```text
SparkClientHarmonyOS/entry/src/main/ets/Projects/Features/Home/Presentation/MedicalLists/ExaminationReports/
├── ExaminationReportCategory.ets
├── ExaminationReportsListPage.ets
└── LabReportCard.ets

SparkClientHarmonyOS/entry/src/main/ets/Projects/Features/Home/Presentation/MedicalLists/Shared/
└── MedicalAttachmentComponents.ets
```

不得修改：

- `SparkClient/` iOS 工程。
- `SparkService/` 后端工程。
- `SparkClientHarmonyOS` 的网络契约、DTO 字段名、后端 path。

## 3. 分层职责与请求链路

目标链路：

```text
用户点击检查报告卡片头部 / 查看详情 / 卡片主体
  → LabReportCard.triggerOpenDetail()
  → ExaminationReportsListPage.openDetail(report)
  → homeVm.examinationDetailTarget = resolveReportForDetail(report)
  → onOpenDetail()
  → AppRootNavDestination
  → ExaminationReportDetailPage
```

附件链路：

```text
用户点击附件图标
  → LabReportCard.toggleAttachments()
  → 展开 MedicalAttachmentListView
  → 点击附件行
  → FileTransferService cachedURL/download
  → UnifiedFilePreview
```

职责边界：

| 层级 | 文件 | 应做 | 不应做 |
| --- | --- | --- | --- |
| 分类工具 | `ExaminationReportCategory.ets` | 分类、标题、颜色、图标、排序、分段 | 路由跳转、附件展示、页面状态 |
| 列表页 | `ExaminationReportsListPage.ets` | 持有报告列表、分组头、调用 `openDetail`、懒加载明细 | 下载附件、拼预览输入 |
| 卡片 | `LabReportCard.ets` | 展示头部/内容/附件入口；把用户意图回调给列表页 | 持有全局路由、改 HomeVM、直接 new 业务 API |
| 附件公共组件 | `MedicalAttachmentComponents.ets` | 展开附件列表、下载、统一预览 | 绑定具体检查报告业务、改变报告数据 |

## 4. 核心关键技术与实现方案

### 4.1 头部点击进入详情

当前卡片外层已有：

```ts
// 当前代码证据：LabReportCard.ets
.onClick(() => {
  this.triggerOpenDetail();
})
```

但头部区域中同时存在附件按钮、详情按钮和内部 Row/Column。开发时需要核验 ArkUI 事件分发，确保以下区域不会出现“点了没反应”：

- 标题图标 + 标题 + 副标题区域。
- 日期 / 机构行。
- “查看详情”按钮。
- 卡片主体非附件区域。

建议目标写法，伪代码/职责骨架：

```ts
// 伪代码：只表达职责，具体 ArkUI 事件冒泡以目标工程编译为准。
@Builder
private headerMainClickableArea() {
  Column({ space: 12 }) {
    this.titleCluster()
    this.dateMetaRow()
  }
  .layoutWeight(1)
  .onClick(() => {
    this.triggerOpenDetail();
  })
}
```

验收点：

- 点击标题、日期、机构均进入同一详情页。
- 点击附件图标只展开/收起附件列表，不误跳详情。
- 点击附件列表项只打开统一预览，不误跳详情。
- 无明细懒加载完成前，也能进入详情页，由详情页继续补拉。

### 4.2 附件必须展示公共附件列表

当前卡片已引用公共组件：

```ts
import { MedicalAttachmentIconView, MedicalAttachmentListView } from '../Shared/MedicalAttachmentComponents';
```

目标保留公共组件，不允许在 `LabReportCard.ets` 中新写一套附件列表。卡片内应保持：

```ts
// 伪代码：附件入口只控制展开状态。
MedicalAttachmentIconView({
  count: this.attachments().length,
  isExpanded: this.isAttachmentsExpanded,
  onTap: () => {
    this.toggleAttachments();
  }
})

if (this.isAttachmentsExpanded && this.attachments().length > 0) {
  MedicalAttachmentListView({
    attachments: this.attachments(),
    fileTransferService: this.fileTransferService
  })
}
```

需要重点排查：

1. `MedicalAttachmentIconView` 内 `.enabled(this.count > 0)` 是否导致 `count > 0` 时仍能稳定触发 `onTap`。
2. 外层卡片 `.onClick` 是否抢占附件图标点击，导致只进详情、不展开附件列表。
3. `MedicalAttachmentListView` 是否因为 `attachments` 字段为空、`fileTransferService` 未传入、或 Row 被外层点击覆盖而不可见。
4. 附件列表展开位置应在头部下方、卡片分割线内侧，对齐 iOS `headerSection` 中的 `MedicalAttachmentListView`。

验收点：

- 有 1 个以上附件时，附件图标展示数量角标。
- 第一次点击附件图标展开列表；第二次点击收起列表。
- 附件列表使用公共 `MedicalAttachmentListView` 的行样式。
- 点击附件行后触发公共下载/缓存/统一预览链路。
- 附件为 0 时图标置灰，不展示空列表。

### 4.3 卡片 UI 对齐 iOS

iOS 卡片结构：

```text
VStack(spacing: 0)
├── headerSection
│   ├── titleCluster
│   ├── dateMetaRow
│   ├── detailAction
│   └── MedicalAttachmentIconView
├── loadingSection
└── cardContentSection
    ├── laboratorySection
    ├── imagingSection
    └── pathologySection
```

HarmonyOS 目标结构应保持同构：

```text
Column(spacing: 0)
├── header
│   ├── titleCluster()
│   ├── dateMetaRow()
│   ├── detailAction()
│   └── MedicalAttachmentIconView()
├── MedicalAttachmentListView()  // 展开时
├── loadingSection()
└── category content
```

需要改动/复核的 UI 点：

| 区域 | iOS 行为 | HarmonyOS 目标 |
| --- | --- | --- |
| 卡片背景 | `.ultraThinMaterial` + systemBackground 透明覆盖 + 细边框 + 轻阴影 | 白色/浅材质观感、12 圆角、细边框、轻阴影；不能变成厚重灰块 |
| 头部分割线 | header 底部 `Divider` | 头部 padding 后加底部分割线 |
| 标题簇 | 40 圆形图标 + 标题 + 副标题 | 保持 40 图标容器、标题最多 2 行、副标题次要色 |
| 元信息 | calendar / building + 日期 / 机构 | 保持一行、机构超长省略 |
| 详情动作 | loading / 可进入 / 弱化三态 | loading 展示进度；可进入蓝色；无明细弱化但不阻断跳转 |
| 附件入口 | 48x48 图标按钮 + 数量角标 | 使用公共 `MedicalAttachmentIconView`，展开态图标/状态需清晰 |
| 实验室内容 | 三格统计 + 重点信息展开 | 保持 3 个等宽统计块；重点信息橙色弱底 |
| 影像内容 | 科室、医生、检查结论 | 不展示无值行；多行结论不截断正文 |
| 病理内容 | 分类、子分类、所见、结论、明细预览 | 明细最多前 5 条，异常 flag 红色 |

## 5. 接口契约与数据模型

本工单不新增接口。使用既有报告模型：

| 模型/属性 | 外部字段名 | ArkTS 类型 | 来源 | 消费位置 |
| --- | --- | --- | --- | --- |
| `RemoteExaminationReportWithAttachments.id` | `id` | `number` | `examination-reports` / complete-data | 列表 key、详情 target、附件业务关联 |
| `itemName` | `item_name` | `string` | 后端 Serializer | 卡片标题 |
| `category` | `category` | `string` | 后端 Serializer | 分类识别、卡片副标题 |
| `subCategory` | `sub_category` | `string` | 后端 Serializer | 卡片副标题 |
| `reportedAt` | `reported_at` | `string` | 后端 Serializer | 时间线排序、日期展示 |
| `performedAt` | `performed_at` | `string` | 后端 Serializer | 时间线排序兜底 |
| `organizationName` | `organization_name` | `string` | 后端 Serializer | 头部机构 |
| `departmentName` | `department_name` | `string` | 后端 Serializer | 影像卡片 |
| `doctorName` | `doctor_name` | `string` | 后端 Serializer | 影像卡片 |
| `findings` | `findings` | `string` | 后端 Serializer | 重点信息/病理所见 |
| `impression` | `impression` | `string` | 后端 Serializer | 重点信息/影像结论 |
| `attachments` | `attachments` | `RemoteManagedFile[]` | 后端 Serializer | 公共附件列表 |
| `medExamDetails` | `med_exam_details` 或懒加载明细 | `RemoteMedExamDetail[]` | `med-exam-details` | 统计、异常、详情 |

附件字段继续复用 `RemoteManagedFile` 与公共转换：

- `MedicalAttachmentPreviewSupport.toManagedFileRecordFromRemote`
- `MedicalAttachmentPreviewAdapter.fromRemoteAttachment`
- `FileTransferService.cachedURL/download`
- `UnifiedFilePreview`

## 6. iOS-HarmonyOS 功能对照矩阵

| 参考端能力/证据 | 可观察行为 | HarmonyOS 实现/证据 | 对齐状态 | 差异与处理 |
| --- | --- | --- | --- | --- |
| iOS `LabReportCard.swift` header + detailAction | 用户从卡片头部/详情入口进入详情页 | `LabReportCard.ets`、`ExaminationReportsListPage.ets` | 部分对齐 | 扩大并稳定头部点击区域；附件点击不得误触详情 |
| iOS `MedicalAttachmentIconView` + `MedicalAttachmentListView` | 点击附件图标展开列表，点击列表项预览 | `Shared/MedicalAttachmentComponents.ets` | 部分对齐 | 强制复用公共列表，排查外层点击抢占 |
| iOS 三类卡片 UI | 实验室/影像/病理按不同内容结构展示 | `LabReportCard.ets` | 部分对齐 | 按结构、间距、颜色、状态逐项复核 |

全局矩阵 `开发详细技术文档/iOS-HarmonyOS功能对照矩阵.md` 当前已有“医疗检查报告”行，本工单作为该行的 UI/交互补充工单，不新增后端契约行。

## 7. 示例工程与官方文档参考结论

| 类型 | 标题/代码位置 | URL/绝对路径 | 可借鉴内容 | 禁止直接复制/版本注意事项 |
| --- | --- | --- | --- | --- |
| iOS 参考 | `LabReportCard.swift` | `/Users/hua/Documents/project/Reference/LookHealthClient/SparkClient/SparkClient/Projects/Features/Home/Presentation/MedicalLists/ExaminationReports/LabReportCard.swift` | 卡片结构、头部、详情动作、附件入口、三类内容区 | 不复制 SwiftUI 代码；只对齐职责和可观察行为 |
| iOS 参考 | `MedicalAttachmentComponents.swift` | `/Users/hua/Documents/project/Reference/LookHealthClient/SparkClient/SparkClient/Projects/Features/Home/Presentation/MedicalLists/Shared/MedicalAttachmentComponents.swift` | 公共附件列表与统一预览链路 | 不把 iOS URL/File API 当 ArkTS API |
| HarmonyOS 本地实现 | `MedicalAttachmentComponents.ets` | `/Users/hua/Documents/project/Reference/LookHealthClient/SparkClientHarmonyOS/entry/src/main/ets/Projects/Features/Home/Presentation/MedicalLists/Shared/MedicalAttachmentComponents.ets` | 现成公共附件图标、列表、下载、预览组件 | 不在卡片里复制一套下载逻辑 |

## 8. 实施拆分与验收

| 阶段 | 目标文件/模块 | 依赖 | 实施结果 | 自动化测试 | 人工验收 |
| --- | --- | --- | --- | --- | --- |
| P0 | `LabReportCard.ets` 头部点击 | 现有 `onOpenDetail` | 头部主信息、详情按钮、卡片主体都进入详情 | 可补 UI 状态/事件单测或轻量组件测试 | 点击标题/日期/机构进入详情 |
| P0 | `LabReportCard.ets` 附件点击隔离 | `MedicalAttachmentIconView` | 点击附件只展开列表，不触发详情跳转 | 可补附件展开状态测试 | 有附件时点击图标展示列表 |
| P1 | `MedicalAttachmentListView` 接入确认 | `FileTransferService` | 附件列表项下载/缓存后统一预览 | 可补 adapter/fromRemote 映射测试 | 点击附件行打开预览 Sheet |
| P1 | `ExaminationReportsListPage.ets` 分组头语义 | `timelineSectionView` | 明确分组头只展示，或点击进入第一条报告详情 | 时间线分组测试保持通过 | 点击行为符合产品定义 |
| P2 | `LabReportCard.ets` UI 对齐 | iOS `LabReportCard.swift` | 头部、统计、重点信息、影像/病理布局按 iOS 复核 | 截图对比/组件快照 | 真机/模拟器检查不同数据状态 |

验收清单：

- [ ] 只修改 `SparkClientHarmonyOS`。
- [ ] 点击卡片头部主信息能进入 `ExaminationReportDetailPage`。
- [ ] 点击“查看详情”能进入同一详情页。
- [ ] 点击附件图标不会直接跳详情。
- [ ] 附件数量大于 0 时，点击图标展开 `MedicalAttachmentListView`。
- [ ] 附件列表项点击后进入 `UnifiedFilePreview`。
- [ ] 附件为 0 时图标置灰且不展示空列表。
- [ ] loading 状态不阻断详情页进入。
- [ ] 实验室/影像/病理三类卡片内容与 iOS 可观察结构一致。
- [ ] ArkTS 编译通过后再标记完成。

## 9. 风险与待确认项

| 编号 | 风险/待确认项 | 影响模块 | 证据 | 依赖方 | 关闭条件 |
| --- | --- | --- | --- | --- | --- |
| R1 | 外层卡片 `.onClick` 与附件按钮 `.onClick` 事件冲突 | 头部、附件 | `LabReportCard.ets:146-211` | HarmonyOS 客户端 | 真机点击验证：附件点击只展开列表，非附件点击进详情 |
| R2 | `fileTransferService` 未传入会导致附件列表可见但无法预览 | 附件列表 | `LabReportCard.ets:31`、`MedicalAttachmentListView.openAttachment` | HarmonyOS 客户端 | 列表页传入 `AppContainer.fileTransferService`，无服务时给出可见错误或禁用 |
| R3 | 分组头是否需要点击进入详情未在 iOS 中明确为可点击 | 时间线头部 | iOS `ExaminationReportTimelineSectionHeader` 仅展示 | 产品/客户端 | 明确“头部”指卡片头部还是时间线分组头；若是分组头，约定进入第一条报告详情 |
| R4 | 旧工单/旧文档仍写“ExaminationReports 目录缺失” | 文档状态 | `医疗检查报告详细技术方案.md` 早期审计结论 | 文档维护 | 后续总览文档单独做状态纠偏，不在本工单内扩大范围 |
| R5 | UI 仅凭代码改动未做截图验收，可能仍与 iOS 观感偏离 | 卡片 UI | `LabReportCard.ets` vs `LabReportCard.swift` | HarmonyOS 客户端/测试 | 提供 iOS 与鸿蒙同数据截图对比，确认间距、状态、附件展开一致 |
