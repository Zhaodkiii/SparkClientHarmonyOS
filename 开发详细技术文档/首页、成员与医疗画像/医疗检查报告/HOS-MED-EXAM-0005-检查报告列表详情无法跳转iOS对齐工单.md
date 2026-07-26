# HOS-MED-EXAM-0005 检查报告列表详情无法跳转 iOS 对齐工单

> 状态：待修复  
> 范围：仅覆盖“首页检查报告列表页卡片点击详情无法进入详情页”问题，目标是与 iOS 行为、目录职责、数据传递和页面模块结构对齐。  
> 审计时间：2026-07-25  
> 参考端：`/Users/hua/Documents/project/Reference/LookHealthClient/SparkClient/`  
> 目标端：`/Users/hua/Documents/project/Reference/LookHealthClient/SparkClientHarmonyOS/`  
> 关联前置工单：
> - `HOS-MED-EXAM-0001-医疗检查报告本地编辑iOS对齐工单.md`
> - `HOS-MED-EXAM-0002-检验单项详情iOS对齐工单.md`
> - `HOS-MED-EXAM-0003-检验报告单详情iOS对齐工单.md`
> - `HOS-MED-EXAM-0004-检查为什么点击编辑按钮无法进入本地编辑iOS对齐工单.md`

## 1. 对标范围与结论

### 1.1 问题定义

当前鸿蒙端在“医疗检查报告”列表页中：

- 点击卡片右上角“查看详情”
- 或点击整张卡片
- 但没有稳定进入详情页

这个问题不是单纯的“路由不存在”，而是“详情入口的触发条件、数据门禁和跳转承接方式”与 iOS 不一致，导致用户在列表页上看不到稳定的详情跳转行为。

### 1.2 当前已核验的鸿蒙现状

鸿蒙端目前已经有以下关键链路：

- 卡片组件：`LabReportCard.ets`
- 列表页：`ExaminationReportsListPage.ets`
- 路由分发：`AppRootNavDestination.ets`
- 详情页：`ExaminationReportDetailPage.ets`
- 详情正文：`ExaminationReportSummaryDetailPage.ets`
- 子页路由：`ExaminationReportCategoryDetailPage.ets`

但卡片点击入口存在明显门槛：

- `LabReportCard.ets` 里 `canOpenDetail()` 依赖 `medExamDetails.length > 0`
- 只要明细尚未补齐，点击就不会触发 `onOpenDetail()`
- 而明细又是异步懒加载补齐的，入口和数据状态被绑死

### 1.3 iOS 端对照结论

iOS 的检查报告列表卡片：

- 在卡片内部直接挂 `MainNavigationLink`
- 详情导航是卡片职责的一部分
- 详情页自身再负责补拉明细

也就是说，iOS 的设计是：

1. 列表卡片负责导航入口
2. 详情页负责加载和展示明细

而鸿蒙当前是：

1. 列表卡片先判断是否已经有明细
2. 明细不足时直接不让跳
3. 入口和数据补齐耦合在一起

这就是“点了没反应”的核心偏差。

### 1.4 结论

鸿蒙需要把检查报告列表页详情入口改成与 iOS 一致的结构：

1. 卡片点击应稳定可触发
2. 明细是否已加载不应成为“能不能进详情”的硬门槛
3. 详情页内部继续承担明细补拉
4. 旧的“卡片先验门禁”逻辑需要替换或降级

---

## 2. 华为端目录设计

### 2.1 iOS 端真实目录结构

```text
SparkClient/SparkClient/Projects/Features/Home/Presentation/MedicalLists/ExaminationReports/
├── LabReportCard.swift
├── ExaminationReportsListPage.swift
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
├── LabReportCard.ets
├── ExaminationReportsListPage.ets
├── ExaminationReportDetailPage.ets
├── ExaminationReportSummaryDetailPage.ets
├── ExaminationReportCategoryDetailPage.ets
├── ExaminationReportDetailSupport.ets
├── ExaminationReportServerMutationService.ets
├── LaboratoryReportDetailPage.ets
├── ImagingReportDetailPage.ets
└── PathologyReportDetailPage.ets
```

### 2.3 本工单的目录落点

本工单建议继续落在：

```text
SparkClientHarmonyOS/开发详细技术文档/首页、成员与医疗画像/
```

原因：

1. 这是首页检查报告列表到详情页的链路问题
2. 不是上传结果页，也不是纯路由框架问题
3. 和 `HOS-MED-EXAM-0001` 到 `0004` 属于同一条检查报告详细链路

### 2.4 旧代码替换与清理原则

1. 列表卡片里不要继续保留“先判断明细再决定能否跳转”的硬门禁
2. 列表页不要把详情跳转做成隐式条件逻辑
3. 详情页要接管明细补拉和展示职责
4. 如果存在旧的简化详情入口或重复实现，应在新工单中明确标记为待清理

---

## 3. 分层职责与请求链路

### 3.1 iOS 的职责拆分

| 层级 | iOS 文件 | 职责 |
| --- | --- | --- |
| 卡片入口 | `LabReportCard.swift` | 卡片展示 + 详情导航入口 |
| 列表页 | `ExaminationReportsListPage.swift` | 只负责渲染、筛选、懒加载触发 |
| 宿主页 | `ExaminationReportDetailPage.swift` | 编辑、删除、分享、本地草稿 |
| 内容页 | `ExaminationReportSummaryDetailPage.swift` | 头部、附件、明细列表 |
| 分类页 | `ExaminationReportCategoryDetailPage.swift` | 单项详情 / 完整检验表 |

### 3.2 鸿蒙当前职责拆分

| 层级 | 鸿蒙文件 | 当前状态 |
| --- | --- | --- |
| 卡片入口 | `LabReportCard.ets` | 已有，但被 `medExamDetails.length > 0` 门禁限制 |
| 列表页 | `ExaminationReportsListPage.ets` | 已有，负责 target 写回与路由触发 |
| 宿主页 | `ExaminationReportDetailPage.ets` | 已有 |
| 内容页 | `ExaminationReportSummaryDetailPage.ets` | 已有 |
| 分类页 | `ExaminationReportCategoryDetailPage.ets` | 已有 |

### 3.3 当前请求链路

```text
检查报告列表页
  → LabReportCard.ets
  → onOpenDetail()
  → ExaminationReportsListPage.openDetail(report)
  → homeVm.examinationDetailTarget = report.clone()
  → appRouter.jumpPage(HomeMedicalRoutes.EXAMINATION_DETAIL)
  → AppRootNavDestination.ets
  → ExaminationReportDetailPage.ets
  → ExaminationReportSummaryDetailPage.ets
```

### 3.4 当前偏差点

1. 卡片点击被 `medExamDetails.length > 0` 这个条件提前拦截
2. 明细补拉是异步的，导致很多场景下详情入口不可点
3. iOS 采用“先导航、后补数据”的结构，鸿蒙目前更像“先补数据、再决定能否导航”

---

## 4. 核心关键技术与实现方案

### 4.1 鸿蒙卡片入口关键代码

```ts
private canOpenDetail(): boolean {
  return this.detailItems().length > 0;
}
```

这段逻辑是当前问题的核心门槛。  
它把“是否已经有明细”当成“能不能进入详情页”的前提，而 iOS 并不是这么做的。

### 4.2 鸿蒙点击入口关键代码

```ts
Text('查看详情')
  .fontSize(13)
  .fontColor(this.canOpenDetail() ? '#0A84FF' : '#AEAEB2')
  .onClick(() => {
    if (this.canOpenDetail() && this.onOpenDetail) {
      this.onOpenDetail();
    }
  })
```

```ts
.onClick(() => {
  if (this.canOpenDetail() && this.onOpenDetail) {
    this.onOpenDetail();
  }
})
```

这意味着只要卡片没有明细，点击就直接失效。  
这个实现方式与 iOS 的“卡片内部直接导航”不一致。

### 4.3 鸿蒙列表页关键代码

```ts
private openDetail(report: RemoteExaminationReportWithAttachments): void {
  const homeVm = this.homeVm;
  if (!homeVm) {
    return;
  }
  homeVm.examinationDetailTarget = report.clone();
  homeVm.examinationDetailArchiveMode = this.archiveMode;
  if (this.onOpenDetail) {
    this.onOpenDetail();
  }
}
```

这里的写法本身没有问题，问题在于它前面多了一层卡片门禁。  
如果卡片不触发 `onOpenDetail`，后面的路由完全不会执行。

### 4.4 iOS 卡片入口关键代码

```swift
} else if canNavigateToDetail {
    MainNavigationLink {
        detailDestination
    } label: {
        HStack(spacing: 4) {
            Text(L10n.text("home.medical.list.examination.card.view_detail"))
            Image(systemName: "chevron.right")
        }
    }
}
```

iOS 的重点不是“先满足明细再跳”，而是“可跳状态下直接通过导航容器进入详情页”。

### 4.5 iOS 详情页补拉逻辑

```swift
private func loadDetailsIfNeeded() async {
    guard report.medExamDetails == nil else { return }
    ...
}
```

这说明 iOS 把“补明细”放在详情页内部完成，而不是挡在列表卡片入口外面。

### 4.6 本工单建议的修复方向

1. 保留卡片的视觉加载态，但不要把是否进入详情页绑定在 `medExamDetails.length`
2. 点击详情时优先保证 `onOpenDetail()` 一定能走到
3. 详情页继续做 `loadDetailsIfNeeded()`，保证数据完整
4. 如果需要灰态，只用于提示“明细还在加载”，不要彻底屏蔽跳转

---

## 5. 需要替换或清理的旧代码

### 5.1 `LabReportCard.ets`

需要清理的旧逻辑：

```ts
private canOpenDetail(): boolean {
  return this.detailItems().length > 0;
}
```

以及所有依赖这个判断来阻断点击的代码。  
建议改成：

- 允许点击进入详情
- 或改成“加载中可进入、未加载明细时仍可进入”
- 仅将 `canOpenDetail()` 保留给视觉样式，不再作为硬门禁

### 5.2 `ExaminationReportsListPage.ets`

当前 `openDetail(report)` 的 target 写回逻辑应保留，但需要确认：

1. 不要再依赖卡片明细门禁来决定是否调用
2. 详情页进入后应继续补拉明细
3. 若后续有旧的简化详情入口，应统一指向这条正式链路

### 5.3 `ExaminationReportDetailPage.ets`

详情页要继续承担：

1. 进入后补拉明细
2. 编辑、删除、分享
3. 分类页路由承接

如果后续发现还有旧页面在重复承担“详情只读展示”，应在新工单里明确标记为废弃。

### 5.4 旧代码清理建议

1. 不要保留“卡片门禁 + 详情页再补拉”的双重阻断
2. 不要把详情入口逻辑拆散到多个旧入口里
3. 避免出现“简化版详情页”和“正式详情页”并存

---

## 6. 鸿蒙关键代码示例

### 6.1 入口回调链

```ts
LabReportCard({
  report: report,
  isLoadingDetails: this.isDetailLoading(report.id),
  fileTransferService: this.fileTransferService,
  onOpenDetail: () => {
    this.openDetail(report);
  }
})
```

### 6.2 列表页写回详情 target

```ts
homeVm.examinationDetailTarget = report.clone();
homeVm.examinationDetailArchiveMode = this.archiveMode;
```

### 6.3 路由跳转

```ts
onOpenDetail: () => {
  appRouter.jumpPage(HomeMedicalRoutes.EXAMINATION_DETAIL);
},
```

### 6.4 详情页接收 target

```ts
const target = this.homeVm?.examinationDetailTarget;
if (target) {
  this.report = target.clone();
}
```

这条链路说明“目标对象传递”是通的，真正断掉的是点击门槛。

---

## 7. 与前置工单的偏差复核

### 7.1 对 `HOS-MED-EXAM-0001` 的偏差复核

`HOS-MED-EXAM-0001` 聚焦的是“医疗检查报告本地编辑”的目录、数据模型和页面模块对齐。  
它不负责解决“列表页详情点不开”的问题。

本工单的新增价值是：

1. 把“列表入口不可达”单独拆出来
2. 不再把它混入本地编辑工单
3. 明确卡片门禁和详情跳转职责边界

### 7.2 对 `HOS-MED-EXAM-0002` 的偏差复核

`HOS-MED-EXAM-0002` 聚焦单项详情页。  
它要求“能从详情正文进入明细子页”，但前提仍然是：

1. 列表页要能先进入详情页
2. 详情页要有完整 target

如果列表页点不开，单项详情页再完整也无法形成闭环。

### 7.3 对 `HOS-MED-EXAM-0003` 的偏差复核

`HOS-MED-EXAM-0003` 已经覆盖详情正文、附件、分类页等内容。  
本工单只补“入口可达性”，属于上游阻塞修复。

### 7.4 对 `HOS-MED-EXAM-0004` 的偏差复核

`HOS-MED-EXAM-0004` 是“编辑按钮无法进入”的问题。  
本工单则是“列表卡片详情无法进入”的问题。  
二者看起来都是“点了没反应”，但触发链路不同，不应混成一个工单。

---

## 8. 预期修复结果

修复完成后，鸿蒙端应满足：

1. 列表页检查报告卡片能稳定进入详情页
2. 进入详情页后继续补拉明细
3. 详情页的结构与 iOS 保持一致
4. 不再依赖 `medExamDetails.length > 0` 作为跳转硬门槛
5. 旧的阻断式代码被替换或清理

---

## 9. 验收标准

### 9.1 功能验收

1. 列表页任意检查报告卡片点击“查看详情”可进入详情页
2. 点击整张卡片也可进入详情页
3. 详情页进入后能显示宿主页、摘要页和分类页结构
4. 明细未完全加载时，仍能进入详情页并在详情页内补齐数据

### 9.2 对齐验收

1. 鸿蒙的入口职责与 iOS 一致
2. 鸿蒙的详情页补数据职责与 iOS 一致
3. 不再出现“明细没回来就完全不能点”的行为

### 9.3 清理验收

1. 不再保留会阻断详情跳转的旧门禁逻辑
2. 不再存在重复的简化详情入口
3. 路由统一指向正式详情页

---

## 10. 结论

这次问题的本质不是“没有详情页”，而是“详情入口的时机和门槛不对”。

鸿蒙要对齐 iOS，必须把“能不能进入详情”从“是否已经有明细”里拆出来，让列表入口稳定可达，再由详情页负责懒加载和展示。  
这份工单建议作为下一步修复的正式依据，并把相关旧门禁逻辑列入清理范围。

