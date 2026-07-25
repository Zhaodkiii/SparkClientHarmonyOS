# HOS-MED-EXAM-0003 检验报告单详情 iOS 对齐工单

> 状态：部分实现  
> 范围：仅覆盖“检验报告单详情（报告概览 + 附件 + 检查明细列表 + 完整检验表）”与 iOS 对齐，不改动服务器契约，不改动 iOS 代码。  
> 审计时间：2026-07-25  
> 参考端：`/Users/hua/Documents/project/Reference/LookHealthClient/SparkClient/`  
> 目标端：`/Users/hua/Documents/project/Reference/LookHealthClient/SparkClientHarmonyOS/`  
> 关联前置工单：
> - `HOS-MED-EXAM-0001-医疗检查报告本地编辑iOS对齐工单.md`
> - `HOS-MED-EXAM-0002-检验单项详情iOS对齐工单.md`
> - `HOS-MED-UPLOAD-0013-检查报告识别结果iOS对齐工单.md`
> - `HOS-MED-UPLOAD-0014-检查报告结果页成员选择确认iOS对齐工单.md`

## 1. 对标范围与结论

### 1.1 本工单解决的问题

本工单只讨论“检验报告单详情”这条链路的 iOS 对齐：

- 报告概览
- 附件展示
- 检查明细列表
- 点击单项进入子页
- 点击「查看完整检验表」
- 编辑 / 删除 / 分享 / 本地草稿模式

这条链路的 iOS 端不是一个简单详情页，而是一个宿主页，内部再承接概览页、分类路由页、完整检验表和本地草稿编辑。

### 1.2 iOS 端真实现状

iOS 已实现以下文件：

- 宿主页：`ExaminationReportDetailPage.swift`
- UI 主体：`ExaminationReportSummaryDetailPage.swift`
- 完整检验表：`LaboratoryReportDetailPage.swift`

其中：

- `ExaminationReportDetailPage.swift` 负责编辑、删除、分享、本地草稿模式
- `ExaminationReportSummaryDetailPage.swift` 负责头部信息、附件、明细列表
- `LaboratoryReportDetailPage.swift` 负责完整检验表

### 1.3 鸿蒙端当前状态

鸿蒙当前是“部分实现”，但已经不只是一个静态简化页，而是存在宿主页、摘要页、分类页、完整表格页和路由注册：

- 宿主页：`ExaminationReportDetailPage.ets`
- 报告摘要：`ExaminationReportSummaryDetailPage.ets`
- 完整检验表：`LaboratoryReportDetailPage.ets`
- 路由入口：`AppRootNavDestination.ets`
- 子页路由：`ExaminationReportCategoryDetailPage.ets`

### 1.4 结论

鸿蒙当前已经进入“可交互详情页”的阶段，但仍然存在两类问题：

1. 页面层次和 iOS 不完全一致，部分旧的简化版实现仍在使用
2. 路由、宿主页、摘要页、完整表格页之间的职责边界还需要进一步收敛

如果这次目标是“目录结构一致、数据模型一致、页面模块一致、流程一致、公共组件缺少的补充、旧代码替换清理”，那么必须把旧的简化实现视为待替换对象，而不是继续在其上叠加。

## 2. 华为端目录设计

### 2.1 iOS 端真实目录结构

```text
SparkClient/SparkClient/Projects/Features/Home/Presentation/MedicalLists/ExaminationReports/
├── ExaminationReportDetailPage.swift
├── ExaminationReportSummaryDetailPage.swift
├── ExaminationReportCategoryDetailPage.swift
├── ExaminationReportDetailSupport.swift
├── ExaminationReportServerMutationService.swift
├── LaboratoryReportDetailPage.swift
├── ImagingReportDetailPage.swift
└── PathologyReportDetailPage.swift
```

### 2.2 鸿蒙端当前目录结构

```text
SparkClientHarmonyOS/entry/src/main/ets/App/Navigation/
└── AppRootNavDestination.ets

SparkClientHarmonyOS/entry/src/main/ets/Projects/Features/Home/Presentation/MedicalLists/ExaminationReports/
├── ExaminationReportDetailPage.ets
├── ExaminationReportSummaryDetailPage.ets
├── ExaminationReportCategoryDetailPage.ets
├── ExaminationReportDetailSupport.ets
├── ExaminationReportServerMutationService.ets
├── LaboratoryReportDetailPage.ets
├── ImagingReportDetailPage.ets
└── PathologyReportDetailPage.ets
```

### 2.3 鸿蒙端目标目录结构

如果要求“目录结构一致 + 旧代码替代清除”，建议目标状态是：

```text
SparkClientHarmonyOS/entry/src/main/ets/Projects/Features/Home/Presentation/MedicalLists/ExaminationReports/
├── ExaminationReportDetailPage.ets                # 宿主页，仅保留一份
├── ExaminationReportSummaryDetailPage.ets         # 摘要内容页，仅保留一份
├── ExaminationReportCategoryDetailPage.ets        # 分类路由页，仅保留一份
├── ExaminationReportDetailSupport.ets             # 支持层，仅保留一份
├── ExaminationReportServerMutationService.ets     # mutation 层，仅保留一份
├── LaboratoryReportDetailPage.ets                 # 完整检验表，仅保留一份
├── ImagingReportDetailPage.ets
└── PathologyReportDetailPage.ets
```

### 2.4 目录清理原则

1. 宿主页、摘要页、子页路由页不能互相替代。
2. 不要保留两份职责相同、命名相近但实现不同的页面。
3. 路由注册只能指向最终保留的宿主页，不要再挂旧的简化入口。

## 3. 分层职责与请求链路

### 3.1 iOS 的职责拆分

| 层级 | iOS 文件 | 职责 |
| --- | --- | --- |
| 宿主页 | `ExaminationReportDetailPage.swift` | 编辑、删除、分享、本地草稿模式 |
| 摘要页 | `ExaminationReportSummaryDetailPage.swift` | 头部、附件、明细列表 |
| 分类路由 | `ExaminationReportCategoryDetailPage` | 单项详情与完整检验表路由 |
| 完整表格 | `LaboratoryReportDetailPage.swift` | 表格式展示 |

### 3.2 鸿蒙当前职责拆分

| 层级 | 鸿蒙文件 | 当前状态 |
| --- | --- | --- |
| 宿主页 | `ExaminationReportDetailPage.ets` | 已有，但需要继续收敛为唯一宿主页 |
| 摘要页 | `ExaminationReportSummaryDetailPage.ets` | 已有，当前承担总览内容 |
| 分类路由 | `ExaminationReportCategoryDetailPage.ets` | 已有，可承接单项 / 完整表格 |
| 完整表格 | `LaboratoryReportDetailPage.ets` | 已有 |
| 路由注册 | `AppRootNavDestination.ets` | 已有 `EXAMINATION_DETAIL` |

### 3.3 目标请求链路

```text
首页检查列表
  → 路由进入检查详情宿主页
  → 宿主页承接编辑 / 删除 / 分享 / 本地草稿
  → 摘要页展示报告概览、附件、检查明细列表
  → 点击明细进入分类路由页
  → 点击「查看完整检验表」进入完整表格页
  → 归档 / 删除 / 保存回写列表与缓存
```

### 3.4 当前偏差

当前鸿蒙已经具备大部分链路，但还需要检查并清理以下偏差：

1. 旧的简化详情页是否仍在被路由引用
2. 宿主页与摘要页职责是否重复
3. 完整检验表和单项详情是否共用支持层
4. 结果页、宿主页、列表页是否都在维护同一份“检查报告”逻辑

## 4. 核心关键技术与实现方案

### 4.1 iOS 宿主页的关键代码示例

```swift
struct ExaminationReportDetailPage: View {
    let mode: ExaminationReportDetailMode
    let category: ExaminationReportCategory
    @State private var report: SparkMedicalSyncAPI.RemoteExaminationReportWithAttachments
    @State private var sourceReportDraft: MedicalReportRecognitionDraft?
    @State private var showingEditSheet = false
    @State private var showingDeleteConfirm = false
    @State private var showingArchiveConfirm = false
}
```

这说明 iOS 宿主页本身就承担了模式管理、草稿和编辑入口，不是一个只读详情壳。

### 4.2 iOS 摘要页的关键代码示例

```swift
struct ExaminationReportSummaryDetailPage: View {
    @Binding var report: SparkMedicalSyncAPI.RemoteExaminationReportWithAttachments
    let category: ExaminationReportCategory
    var fileTransferService: FileTransferService?
    var workflowAPI: SparkMedicalWorkflowAPI?
}
```

这说明摘要页是基于绑定报告数据的“内容页”，负责概览展示与内容跳转。

### 4.3 鸿蒙关键代码示例

#### 4.3.1 路由注册

```ts
} else if (this.routeName === HomeMedicalRoutes.EXAMINATION_DETAIL) {
  ExaminationReportDetailPage({
    homeVm: this.homeVm,
    onBack: () => {
      this.homeVm?.clearExaminationDetailTarget();
      this.pop();
    },
    onOpenSubitemDetail: () => {
      appRouter.jumpPage(HomeMedicalRoutes.EXAMINATION_SUBITEM_DETAIL);
    },
    onDeleted: (reportID: number) => {
      this.handleExaminationDeleted(reportID);
    },
    onArchiveStateChanged: (reportID: number, isArchived: boolean) => {
      this.handleExaminationArchiveChanged(reportID, isArchived);
    },
    onSaved: (report: RemoteExaminationReportWithAttachments) => {
      this.handleExaminationSaved(report);
    }
  })
}
```

这说明鸿蒙路由已经接到了宿主页和子页，但必须确认是否还有旧简化页路径被遗漏。

#### 4.3.2 宿主页接摘要页

```ts
ExaminationReportSummaryDetailPage({
  report: this.report,
  embedded: true,
  onBack: () => { /* no-op */ },
  onOpenSubitemDetail: () => this.openSubitemDetail(),
  onDeleted: (reportID: number) => { /* ... */ },
  onArchiveStateChanged: (reportID: number, isArchived: boolean) => { /* ... */ }
})
```

这说明鸿蒙已经开始把摘要页作为宿主页内部内容承接，但要继续检查是否存在重复实现。

#### 4.3.3 完整检验表

```ts
Scroll() {
  Column() {
    this.TableHeader()
    ForEach(this.detailItems(), (item: RemoteMedExamDetail) => {
      this.TableRow(item)
    })
  }
}
```

这说明完整表格页已经存在，但它应当只做“完整检验表”这一职责，不能再回头承担摘要页逻辑。

### 4.4 需要补充的公共组件

如果要对齐 iOS，这一条链路建议补齐以下公共组件：

1. `ExaminationReportDetailSupport`
2. `ExaminationReportSubitemNavigationLink`
3. `ExaminationReportSubitemSummaryRow`
4. `ExaminationReportArchiveActionBar`
5. `ExaminationReportShareAction`

这些组件的目标不是再写一层壳，而是把“单项点击、完整表格入口、归档/删除/分享”统一成同一套职责。

## 5. 接口契约与数据模型

### 5.1 iOS 端关键数据模型

| 模型 | 作用 | 关键字段 |
| --- | --- | --- |
| `RemoteExaminationReportWithAttachments` | 报告主体 | `itemName`、`category`、`subCategory`、`findings`、`impression`、`attachments`、`medExamDetails` |
| `MedicalReportRecognitionDraft` | 本地草稿模式 | `category`、`title`、`details`、`attachmentFileIds` |
| `ExaminationReportDetailMode` | 宿主页模式 | `server` / `localDraft` |

### 5.2 鸿蒙端当前数据模型状态

鸿蒙当前已经具备报告主体和明细数据，但需要继续确认以下点：

1. 宿主页是否仍然直接持有报告克隆副本
2. 摘要页是否只通过 `@Prop` / `@Binding` 接收数据
3. 本地草稿与服务端实体是否完全分离

### 5.3 需要一致的字段语义

以下语义必须和 iOS 保持一致：

- 报告标题
- 分类
- 亚类
- 所见
- 印象
- 附件
- 明细项
- 本地草稿
- 已归档状态
- 删除和分享操作

### 5.4 当前模型偏差

鸿蒙最容易出偏差的地方是“把摘要页和宿主页都当成详情页”。

正确做法是：

1. 宿主页负责模式、编辑、删除、分享
2. 摘要页负责内容展示和内容跳转
3. 子页负责单项详情和完整表格

## 6. iOS-HarmonyOS 功能对照矩阵

| 模块 | iOS 状态 | 鸿蒙状态 | 差异 | 是否需要清理旧代码 |
| --- | --- | --- | --- | --- |
| 宿主页 | 已实现 | 部分实现 | 鸿蒙宿主页需最终收敛 | 是，旧简化入口应去掉 |
| 摘要页 | 已实现 | 部分实现 | 鸿蒙摘要页职责需收敛 | 是，重复展示逻辑应清理 |
| 分类路由 | 已实现 | 已实现 | 基本对齐 | 检查是否有旧路由残留 |
| 完整检验表 | 已实现 | 已实现 | 基本对齐 | 仅保留一份 |
| 单项详情 | 已实现 | 已实现 / 待收敛 | 需要统一入口 | 清理旧的平铺实现 |
| 编辑 / 删除 / 分享 | 已实现 | 部分实现 | 鸿蒙需继续补齐 | 视实现情况清理旧逻辑 |
| 本地草稿模式 | 已实现 | 部分实现 | 鸿蒙需对齐 | 清理重复草稿入口 |

## 7. 旧代码替代与清除建议

### 7.1 需要重点检查的旧代码位置

1. `SparkClientHarmonyOS/entry/src/main/ets/App/Navigation/AppRootNavDestination.ets`
2. `SparkClientHarmonyOS/entry/src/main/ets/Projects/Features/Home/Presentation/MedicalLists/ExaminationReports/ExaminationReportDetailPage.ets`
3. `SparkClientHarmonyOS/entry/src/main/ets/Projects/Features/Home/Presentation/MedicalLists/ExaminationReports/ExaminationReportSummaryDetailPage.ets`
4. `SparkClientHarmonyOS/entry/src/main/ets/Projects/Features/Home/Presentation/MedicalLists/ExaminationReports/LaboratoryReportDetailPage.ets`
5. `SparkClientHarmonyOS/entry/src/main/ets/Projects/Features/Home/Presentation/MedicalLists/ExaminationReports/ExaminationReportCategoryDetailPage.ets`

### 7.2 替代原则

1. 如果旧的简化详情页还在路由里，就应替换为新的宿主页链路。
2. 如果摘要页里还保留了旧的静态内嵌逻辑，要迁移到统一支持层。
3. 如果完整检验表和单项详情有重复字段拼接逻辑，要抽到 `ExaminationReportDetailSupport`。
4. 如果存在两套“检查报告详情”的页面分支，只保留一套正式入口。

### 7.3 是否需要清除旧代码

建议清除，但前提是以下两点已经完成：

1. 新宿主页链路已完全可运行
2. 所有上游路由和下游引用已切换到新入口

否则不要先删，只能先标注为废弃实现。

## 8. 与前置工单的偏差复核

### 8.1 对 `HOS-MED-EXAM-0001` 的偏差复核

`HOS-MED-EXAM-0001` 讨论的是“医疗检查报告本地编辑 iOS 对齐”，它的偏差主要是：

1. 聚焦在表单与本地草稿，不是宿主页整体替换
2. 关注点是 `ExamReportFormView` 和 `AddLabItemSheet`
3. 不负责清理检查详情页旧实现

### 8.2 对 `HOS-MED-EXAM-0002` 的偏差复核

`HOS-MED-EXAM-0002` 讨论的是“检验单项详情 iOS 对齐”，它的偏差主要是：

1. 聚焦在单项钻取和分类路由
2. 关注点是 `ExaminationReportCategoryDetailPage`
3. 不负责替换宿主页和摘要页整体结构

### 8.3 这两个工单与本工单的关系

这两个工单都应该被视为本工单的前置补充，而不是替代：

- `0001` 解决编辑页
- `0002` 解决单项详情
- `0003` 解决报告单详情宿主页 / 摘要页 / 完整表格 / 路由收敛与清理

因此：

1. `0001`、`0002` 不需要删除
2. 其中描述的旧代码偏差要继续保留为历史结论
3. 真正需要清理的是实现层里与新宿主页冲突的旧逻辑，不是工单文档

## 9. 实施拆分与验收

### 9.1 实施拆分

1. 确认 `AppRootNavDestination.ets` 只挂最终宿主页。
2. 确认 `ExaminationReportDetailPage.ets` 是唯一宿主页。
3. 确认 `ExaminationReportSummaryDetailPage.ets` 只承接摘要内容。
4. 确认 `ExaminationReportCategoryDetailPage.ets` 只承接单项 / 完整表格路由。
5. 清理重复或废弃的旧简化实现。
6. 抽出公共支持层，统一字段拼接和标题逻辑。

### 9.2 验收标准

必须同时满足以下条件，才算完成：

1. 首页检查报告详情入口只进入一条正式宿主页链路。
2. 宿主页、摘要页、分类页、完整表格页职责清晰。
3. 单项明细可点击进入子页。
4. 完整检验表可从摘要页进入。
5. 旧的简化版入口不再被新路由引用。
6. 页面模块和 iOS 语义一致。

### 9.3 体验验收

- 进入检查详情后可看到报告概览和附件。
- 明细列表中的单项可以继续钻取。
- 可以进入完整检验表。
- 编辑、删除、分享入口保持在宿主页。
- 旧的简化版页面不会再重复出现。

## 10. 风险与待确认项

### 10.1 主要风险

1. 旧简化页和新宿主页同时存在，会让路由和维护成本持续上升。
2. 如果摘要页还保留旧逻辑，后续单项详情和完整表格会重复实现。
3. 过早删除旧代码，可能会导致路由断链。

### 10.2 待确认项

1. 是否已经可以把旧的简化详情实现标记为废弃。
2. `ExaminationReportSummaryDetailPage.ets` 是否继续作为可嵌入内容页，还是拆成更细的概览组件。
3. `LaboratoryReportDetailPage.ets` 是否只保留完整表格职责，避免再承接单项摘要。
4. 是否需要为宿主页增加专门的废弃实现注释，防止后续误用。

### 10.3 结论性建议

如果这次目标真的是“**鸿蒙检查报告单详情完全对齐 iOS，并清理旧代码**”，建议把宿主页、摘要页、分类页、完整表格页的职责一次性收拢，然后把旧的简化入口和重复展示逻辑清掉，只保留一条正式链路。

