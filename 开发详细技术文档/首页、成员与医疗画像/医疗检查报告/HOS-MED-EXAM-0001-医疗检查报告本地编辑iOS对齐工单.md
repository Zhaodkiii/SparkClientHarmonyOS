# HOS-MED-EXAM-0001 医疗检查报告本地编辑 iOS 对齐工单

> 状态：待实现  
> 范围：仅覆盖“医疗检查报告（本地）”编辑页与子项编辑页的 iOS 对齐，不改动服务器契约，不改动 iOS 代码。  
> 审计时间：2026-07-25  
> 参考端：`/Users/hua/Documents/project/Reference/LookHealthClient/SparkClient/`  
> 目标端：`/Users/hua/Documents/project/Reference/LookHealthClient/SparkClientHarmonyOS/`  
> 关联现状：鸿蒙当前已有检查报告总览详情页，但没有与 iOS `ExamReportFormView`、`AddLabItemSheet` 对应的本地编辑页。

## 1. 对标范围与结论

### 1.1 本工单要对齐的 iOS 事实

iOS 端“医疗检查报告（本地）”编辑链路已经是完整闭环，核心入口由以下三个文件组成：

- `SparkClient/SparkClient/Projects/Features/Home/Presentation/MedicalLists/ExaminationReports/ExaminationReportDetailPage.swift`
- `SparkClient/SparkClient/Projects/Features/MedicalRecord/Presentation/NewRecord/Forms/ExamReportFormView.swift`
- `SparkClient/SparkClient/Projects/Features/MedicalRecord/Presentation/NewRecord/Forms/AddLabItemSheet.swift`

其中，`ExaminationReportDetailPage.swift` 通过 `editSheetContent` 打开编辑页；`ExamReportFormView.swift` 支持 `create`、`serverEdit`、`localEdit` 三种模式；`AddLabItemSheet.swift` 负责检验子项编辑。

### 1.2 鸿蒙当前状态

鸿蒙端当前已有检查报告只读详情页与分类详情页，但没有等价的本地编辑页：

- 已有：
  - `SparkClientHarmonyOS/entry/src/main/ets/Projects/Features/Home/Presentation/MedicalLists/ExaminationReports/ExaminationReportSummaryDetailPage.ets`
  - `SparkClientHarmonyOS/entry/src/main/ets/Projects/Features/Home/Presentation/MedicalLists/ExaminationReports/LaboratoryReportDetailPage.ets`
  - `SparkClientHarmonyOS/entry/src/main/ets/Projects/Features/Home/Presentation/MedicalLists/ExaminationReports/ImagingReportDetailPage.ets`
  - `SparkClientHarmonyOS/entry/src/main/ets/Projects/Features/Home/Presentation/MedicalLists/ExaminationReports/PathologyReportDetailPage.ets`
- 缺失：
  - `ExamReportFormView.ets`
  - `AddLabItemSheet.ets`
  - 与 `localEdit` 等价的编辑模式接入
  - 与 iOS 一致的“详情页 -> 编辑页 -> 子项编辑 -> 保存回写”链路

### 1.3 结论

当前鸿蒙实现属于“检查报告只读展示已存在，本地编辑链路未创建”的状态。  
如果目标提升为“目录结构一致、数据模型一致、页面模块一致、流程一致，且页面完全对齐 iOS”，则不能只补一个编辑弹窗，而必须补齐以下四层：

1. 目录结构
2. 页面模块
3. 数据模型
4. 交互流程

一句话结论：**鸿蒙当前没有进入 iOS 的“本地编辑页同构阶段”，仍处于“只读详情页阶段”。**

## 2. 华为端目录设计

### 2.1 iOS 端真实目录结构

```text
SparkClient/SparkClient/Projects/Features/Home/Presentation/MedicalLists/ExaminationReports/
├── ExaminationReportDetailPage.swift
├── ExaminationReportSummaryDetailPage.swift
├── ExaminationReportCategory.swift
├── ExaminationReportDetailSupport.swift
├── ExaminationReportServerMutationService.swift
├── LabReportCard.swift
├── LaboratoryReportDetailPage.swift
├── ImagingReportDetailPage.swift
└── PathologyReportDetailPage.swift

SparkClient/SparkClient/Projects/Features/MedicalRecord/Presentation/NewRecord/Forms/
├── ExamReportFormView.swift
├── AddLabItemSheet.swift
├── AddImagingReportItemSheet.swift
└── AddPathologyReportItemSheet.swift
```

### 2.2 鸿蒙端当前目录结构

```text
SparkClientHarmonyOS/entry/src/main/ets/Projects/Features/Home/Presentation/MedicalLists/ExaminationReports/
├── ExaminationReportCategory.ets
├── ExaminationReportSummaryDetailPage.ets
├── ExaminationReportsListPage.ets
├── ImagingReportDetailPage.ets
├── LabReportCard.ets
├── LaboratoryReportDetailPage.ets
└── PathologyReportDetailPage.ets
```

### 2.3 鸿蒙端目标目录结构

如果要求“目录结构完全一致”，建议补齐为两条镜像目录线：

```text
SparkClientHarmonyOS/entry/src/main/ets/Projects/Features/Home/Presentation/MedicalLists/ExaminationReports/
├── ExaminationReportDetailPage.ets
├── ExaminationReportSummaryDetailPage.ets
├── ExaminationReportCategory.ets
├── ExaminationReportDetailSupport.ets
├── ExaminationReportServerMutationService.ets
├── LabReportCard.ets
├── LaboratoryReportDetailPage.ets
├── ImagingReportDetailPage.ets
└── PathologyReportDetailPage.ets

SparkClientHarmonyOS/entry/src/main/ets/Projects/Features/MedicalRecord/Presentation/NewRecord/Forms/
├── ExamReportFormView.ets
├── AddLabItemSheet.ets
├── AddImagingReportItemSheet.ets
└── AddPathologyReportItemSheet.ets
```

### 2.4 目录对齐原则

1. Home 目录负责“详情承接与列表入口”。
2. MedicalRecord 目录负责“手工新建 / 本地编辑 / 子项编辑”。
3. 不把编辑表单继续压在只读详情页里。
4. 不把检验、影像、病理三个类型揉成单文件大页面。

## 3. 分层职责与请求链路

### 3.1 iOS 的真实职责分工

| 层级 | iOS 文件 | 职责 |
| --- | --- | --- |
| 入口层 | `ExaminationReportDetailPage.swift` | 详情页承接、菜单、编辑入口、删除、归档 |
| 表单层 | `ExamReportFormView.swift` | 新建、服务端编辑、本地编辑 |
| 子项层 | `AddLabItemSheet.swift` | 检验子项新增 / 编辑 |
| 子类型层 | `AddImagingReportItemSheet.swift` / `AddPathologyReportItemSheet.swift` | 影像 / 病理子项编辑 |
| 提交流程 | `localEdit` 回调 | 不立即请求服务端，仅回传草稿 |

### 3.2 鸿蒙当前职责分工

| 层级 | 鸿蒙文件 | 当前状态 |
| --- | --- | --- |
| 入口层 | `ExaminationReportSummaryDetailPage.ets` | 只读详情页，只有归档/删除 |
| 表单层 | 无 | 缺失 |
| 子项层 | 无 | 缺失 |
| 子类型层 | 无 | 缺失 |
| 提交流程 | 无 | 缺失 |

### 3.3 目标请求链路

```text
检查报告详情页
  → 点击“编辑”
  → 打开本地编辑页（localEdit）
  → 编辑基础字段：日期 / 标题 / 医院 / 医生 / 内容 / 分类
  → 进入子项编辑：检验项 / 影像项 / 病理项
  → 返回详情页
  → 仅更新本地草稿或回调上层
  → 由上层决定最终是否写服务端
```

### 3.4 当前偏差

鸿蒙当前只实现到“查看与归档/删除”，没有进入“编辑草稿 -> 子项编辑 -> 提交回调”的链路，所以和 iOS 不是同一阶段。

## 4. 核心关键技术与实现方案

### 4.1 页面模块必须一一对应

如果目标是“页面模块完全一致”，鸿蒙不能只做一个大页面，而应拆成和 iOS 接近的职责块：

1. `ExaminationReportDetailPage.ets`
2. `ExaminationReportSummaryDetailPage.ets`
3. `ExamReportFormView.ets`
4. `AddLabItemSheet.ets`
5. `AddImagingReportItemSheet.ets`
6. `AddPathologyReportItemSheet.ets`

### 4.2 编辑模式必须对齐 iOS

iOS `ExamReportFormView` 的模式是：

- `create`
- `serverEdit`
- `localEdit`

鸿蒙目标也应保留同等语义，至少要有：

- 新建模式
- 服务端编辑模式
- 本地草稿编辑模式

其中 `localEdit` 的关键点不是“界面长得像”，而是：

1. 不依赖服务端即时写入
2. 只维护当前草稿状态
3. 点击完成后回调上层
4. 允许上层统一处理保存、绑定、刷新

### 4.3 子项编辑必须拆页

`AddLabItemSheet` 不是一个普通输入框集合，而是一个独立的子项编辑容器。  
如果鸿蒙想和 iOS 完全一致，子项编辑页至少要保留以下职责：

- 支持单个检验子项的编辑
- 支持单位、结果、参考范围、标记
- 支持分类和子分类
- 支持取消 / 完成
- 支持从表单内弹出再回填

### 4.4 推荐实现方式

鸿蒙建议把当前只读详情页拆成三层状态：

1. `detail`：展示当前报告
2. `editor`：编辑报告主体
3. `itemEditor`：编辑单条子项

这样可以和 iOS 的 `sheet` + `localEdit` 语义保持一致。

## 5. 接口契约与数据模型

### 5.1 iOS 端关键数据模型

| 模型 | 作用 | 关键字段 |
| --- | --- | --- |
| `MedicalReportRecognitionDraft` | 检查报告草稿 | `category`、`title`、`hospital`、`doctor`、`content`、`date`、`details` |
| `ItemDraft` | 检验子项 | `itemName`、`resultValue`、`unit`、`flag`、`referenceRange`、`category`、`subCategory` |
| `RemoteExaminationReportWithAttachments` | 服务端检查报告 | 报告主体 + 附件 + 明细 |
| `ExaminationReportCategory` | 分类枚举 | laboratory / imaging / pathology |

### 5.2 鸿蒙端现状

鸿蒙当前在上传识别链路里已经出现了部分检查报告草稿和映射逻辑，但 Home 侧本地编辑页还没有独立出来。  
这意味着：

- 数据语义有部分复用基础
- 页面模块没有复用
- 详情页编辑回路没有复用

### 5.3 需要保持一致的字段语义

以下字段必须与 iOS 保持同义同序，不能在鸿蒙端重新定义另一套含义：

- 报告类型
- 报告标题
- 医院名称
- 医生名称
- 检查日期
- 检查内容
- 子项列表
- 子项名称
- 结果值
- 单位
- 异常标记
- 参考范围

### 5.4 当前模型偏差

当前鸿蒙缺少“Home 检查报告编辑页专用模型层”，容易把上传识别草稿和详情编辑草稿混用。  
如果要完全对齐 iOS，建议明确区分：

1. 上传识别草稿
2. Home 本地编辑草稿
3. 服务端返回实体

这三者可以字段同构，但职责不能混。

## 6. iOS-HarmonyOS 功能对照矩阵

| 模块 | iOS 状态 | 鸿蒙状态 | 差异 | 优化方向 |
| --- | --- | --- | --- | --- |
| 详情页入口 | 已实现 | 已有只读详情页 | 鸿蒙缺编辑入口 | 补 `ExaminationReportDetailPage.ets` 编辑菜单 |
| 主表单 | 已实现 | 未创建 | 缺少本地编辑页 | 新建 `ExamReportFormView.ets` |
| 子项编辑 | 已实现 | 未创建 | 缺少独立弹层 | 新建 `AddLabItemSheet.ets` |
| 本地编辑模式 | 已实现 | 未创建 | 无 `localEdit` 语义 | 补本地草稿回调模式 |
| 分类切换 | 已实现 | 部分存在 | 页面承接不完整 | 把分类逻辑前移到表单层 |
| 保存回调 | 已实现 | 未创建 | 无上层回传 | 增加 `onSubmit` / `onDone` |
| 目录结构 | 已实现 | 不完整 | 目录未镜像 | 按 iOS 拆目录与文件 |
| 页面模块拆分 | 已实现 | 偏聚合 | 颗粒度不一致 | 拆分 `Detail / Form / Sheet` |
| 文案 key | 已实现 | 未补齐 | 多语言资源缺失 | 补齐本地化键值 |

## 7. 示例工程与官方文档参考结论

### 7.1 本地参考文件

可直接参考的真实代码文件如下：

- iOS 详情页：`/Users/hua/Documents/project/Reference/LookHealthClient/SparkClient/SparkClient/Projects/Features/Home/Presentation/MedicalLists/ExaminationReports/ExaminationReportDetailPage.swift`
- iOS 主表单：`/Users/hua/Documents/project/Reference/LookHealthClient/SparkClient/SparkClient/Projects/Features/MedicalRecord/Presentation/NewRecord/Forms/ExamReportFormView.swift`
- iOS 子项编辑：`/Users/hua/Documents/project/Reference/LookHealthClient/SparkClient/SparkClient/Projects/Features/MedicalRecord/Presentation/NewRecord/Forms/AddLabItemSheet.swift`
- 鸿蒙只读详情页：`/Users/hua/Documents/project/Reference/LookHealthClient/SparkClientHarmonyOS/entry/src/main/ets/Projects/Features/Home/Presentation/MedicalLists/ExaminationReports/ExaminationReportSummaryDetailPage.ets`

### 7.2 可复用结论

1. iOS 的本地编辑不是单页面，而是“详情页 + form + sheet”的组合。
2. `localEdit` 的语义是“只回传草稿，不直接打服务端”。
3. 子项编辑必须独立成页，不能合并进主表单。
4. 鸿蒙当前的关键缺口是“页面模块层级”，不是单个字段。

### 7.3 不可直接照搬的内容

1. iOS 的 SwiftUI 语法不能直接迁移。
2. iOS 的导航和 sheet 组件要按鸿蒙 Stage / Navigation 机制重写。
3. iOS 的状态管理写法不能逐句翻译，必须按 ArkTS 结构拆分。

### 7.4 鸿蒙关键代码示例

#### 7.4.1 当前已有的分类与时间线基础

```ts
export type ExaminationReportCategory = 'laboratory' | 'imaging' | 'pathology';

export function resolveExaminationCategory(
  report: RemoteExaminationReportWithAttachments
): ExaminationReportCategory {
  const blob = `${nonEmptyText(report.category)} ${nonEmptyText(report.subCategory)}`.toLowerCase();
  if (blob.indexOf('影像') >= 0 || blob.indexOf('imaging') >= 0) {
    return 'imaging';
  }
  if (blob.indexOf('病理') >= 0 || blob.indexOf('patholog') >= 0) {
    return 'pathology';
  }
  return 'laboratory';
}
```

这段代码说明鸿蒙已经有“分类识别”的底层基础，但它只解决了总览分类，不解决“本地编辑页”的入口和表单结构。

#### 7.4.2 当前只读详情页的承接方式

```ts
if (target) {
  this.report = target.clone();
  this.isArchived = target.isArchived;
}

if (formatExaminationDateText(this.report).length > 0) {
  Text(`日期 ${formatExaminationDateText(this.report)}`)
}

if (category == 'laboratory') {
  LaboratoryReportDetailPage({ report: this.report })
}
```

这段代码说明鸿蒙当前已经能承接“检查报告详情”与“实验室分类页”，但仍然停留在只读展示，没有出现 `ExamReportFormView` 这一层。

#### 7.4.3 当前实验室明细的渲染方式

```ts
if (this.detailItems().length === 0) {
  Text('暂无检验明细')
} else {
  Column({ space: 8 }) {
    ForEach(this.detailItems(), (item: RemoteMedExamDetail) => {
      this.detailRow(item)
    }, (item: RemoteMedExamDetail) => `lab-detail-${item.id}`)
  }
}
```

这段代码说明当前鸿蒙是“明细列表内嵌展示”，而不是“点击某条明细进入子页编辑”的交互模型。

### 7.5 对本工单的直接影响

1. `ExamReportFormView.ets` 必须新建，不能在现有详情页里硬塞表单。
2. `AddLabItemSheet.ets` 必须独立成组件，不能和主表单混在同一页面。
3. 已有 `resolveExaminationCategory` 可以作为页面分流基础，但不能替代编辑页路由。

## 8. 实施拆分与验收

### 8.1 实施拆分

1. 新建鸿蒙检查报告编辑目录。
2. 新建 `ExaminationReportDetailPage.ets`，补齐编辑菜单入口。
3. 新建 `ExamReportFormView.ets`，实现本地编辑模式。
4. 新建 `AddLabItemSheet.ets`，实现检验子项编辑。
5. 视需要补齐 `AddImagingReportItemSheet.ets`、`AddPathologyReportItemSheet.ets`。
6. 补齐本地化文案与测试。

### 8.2 验收标准

必须同时满足以下条件，才算达到“iOS 页面完全一致”的目标：

1. 目录结构一致。
2. 文件命名一致或职责一一映射。
3. 页面拆分一致。
4. 主表单字段一致。
5. 子项编辑能力一致。
6. `localEdit` 语义一致。
7. 编辑入口位置一致。
8. 返回后状态回填一致。

### 8.3 体验验收

- 从详情页能打开编辑页。
- 编辑页标题与 iOS 一致。
- 子项可以单独编辑并回填。
- 取消不污染原始草稿。
- 完成后能把结果回到上层承接页。

## 9. 风险与待确认项

### 9.1 主要风险

1. 只补一个页面壳会导致“看起来像，实际上不是”。
2. 上传识别草稿和 Home 本地编辑草稿混用，会污染数据职责。
3. 只读详情页继续承载编辑逻辑，会让页面越来越胖。
4. 目录不镜像 iOS，会导致后续补文件越来越难。

### 9.2 待确认项

1. 鸿蒙这条链路最终是否必须与 iOS 完全同目录命名，还是只要求职责一致。
2. `ExamReportFormView.ets` 是否放在 `Features/MedicalRecord/Presentation/NewRecord/Forms/`，还是同时在 Home 目录下放一个薄包装。
3. 子项编辑页是否需要同时支持检验 / 影像 / 病理三种类型，还是分阶段交付。
4. 是否要复用上传识别链路里的草稿模型，还是单独拆 Home 编辑草稿模型。

### 9.3 结论性建议

如果这次目标是“**目录结构、数据模型、页面模块、流程全部对齐 iOS**”，建议直接按 iOS 的职责拆分创建鸿蒙新文件，而不要在现有只读详情页里继续加编辑逻辑。
