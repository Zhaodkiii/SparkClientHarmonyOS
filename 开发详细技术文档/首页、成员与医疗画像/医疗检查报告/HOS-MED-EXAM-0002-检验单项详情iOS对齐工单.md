# HOS-MED-EXAM-0002 检验单项详情 iOS 对齐工单

> 状态：待实现  
> 范围：仅覆盖“检验单项详情”页面与子页路由对齐，不改动服务器契约，不改动 iOS 代码。  
> 审计时间：2026-07-25  
> 参考端：`/Users/hua/Documents/project/Reference/LookHealthClient/SparkClient/`  
> 目标端：`/Users/hua/Documents/project/Reference/LookHealthClient/SparkClientHarmonyOS/`  
> 关联现状：鸿蒙当前只做到了检查报告内嵌明细展示，没有独立的检验单项详情页，也没有与 iOS 对应的公共路由组件。

## 1. 对标范围与结论

### 1.1 需求定义

本工单对齐的对象不是“整个检查报告详情页”，而是其中的**单条检验明细点击后的详情页**。  
用户在 iOS 端点击检查报告下方的某一条明细时，会进入一个独立页面，展示该条明细的：

- 分类
- 检查方式
- 部位
- 检查结果
- 诊断/补充说明

这部分是“总览页 -> 单项详情页 -> 分类路由页”的独立链路。

### 1.2 iOS 端真实实现

iOS 端的单项详情链路分为三层：

1. `ExaminationReportSummaryDetailPage.swift` 底部 `subitemsSection`
2. `ExaminationReportCategoryDetailPage`
3. `ImagingReportDetailPage.swift` / `PathologyReportDetailPage.swift`

其中：

- `subitemsSection` 里的 `ForEach(sortedDetails, id: \.id)` 会为每条明细创建跳转入口。
- 点击后先进入 `ExaminationReportCategoryDetailPage`。
- `ExaminationReportCategoryDetailPage` 再按分类路由到 `ImagingReportDetailPage` 或 `PathologyReportDetailPage`。
- 当分类为 laboratory 时，iOS 当前也会落到 `ImagingReportDetailPage`，即“实验室单项以影像详情卡样式承接”的现状。

### 1.3 鸿蒙当前状态

鸿蒙端当前没有独立的单项详情页，也没有分类路由页。  
现状是：

- `LaboratoryReportDetailPage.ets` 直接在详情页里内嵌展示全部明细
- `PathologyReportDetailPage.ets` 也是列表式展示
- 明细不可点击
- 没有进入子页的公共路由承接层

### 1.4 结论

当前鸿蒙实现属于“明细平铺展示”阶段，不是 iOS 的“明细点击进入独立详情页”阶段。  
如果要达到“目录结构一致、数据模型一致、页面模块一致、流程一致”，必须补齐：

1. 单项详情路由页
2. 分类路由页
3. 单项详情卡片组件
4. 从总览页进入子页的点击链路

一句话结论：**鸿蒙缺的不是明细列表，而是明细详情页的路由体系和公共组件拆分。**

## 2. 华为端目录设计

### 2.1 iOS 端真实目录结构

```text
SparkClient/SparkClient/Projects/Features/Home/Presentation/MedicalLists/ExaminationReports/
├── ExaminationReportSummaryDetailPage.swift
├── ExaminationReportCategoryDetailPage.swift
├── ImagingReportDetailPage.swift
├── LaboratoryReportDetailPage.swift
└── PathologyReportDetailPage.swift
```

### 2.2 鸿蒙端当前目录结构

```text
SparkClientHarmonyOS/entry/src/main/ets/Projects/Features/Home/Presentation/MedicalLists/ExaminationReports/
├── ExaminationReportSummaryDetailPage.ets
├── LaboratoryReportDetailPage.ets
├── ImagingReportDetailPage.ets
└── PathologyReportDetailPage.ets
```

### 2.3 鸿蒙端目标目录结构

如果要求与 iOS 目录和模块完全一致，鸿蒙建议补齐：

```text
SparkClientHarmonyOS/entry/src/main/ets/Projects/Features/Home/Presentation/MedicalLists/ExaminationReports/
├── ExaminationReportSummaryDetailPage.ets
├── ExaminationReportCategoryDetailPage.ets
├── ExaminationReportSubitemSummaryRow.ets
├── ExaminationReportSubitemNavigationLink.ets
├── ExaminationReportDetailSupport.ets
├── ImagingReportDetailPage.ets
├── LaboratoryReportDetailPage.ets
└── PathologyReportDetailPage.ets
```

### 2.4 目录设计原则

1. `ExaminationReportSummaryDetailPage` 只负责总览与入口，不直接承载所有单项详情逻辑。
2. `ExaminationReportCategoryDetailPage` 负责子页路由，不负责具体内容排版。
3. `ImagingReportDetailPage`、`LaboratoryReportDetailPage`、`PathologyReportDetailPage` 负责各自展示样式。
4. 单项摘要行必须单独抽成公共组件，避免把点击逻辑和渲染逻辑写死在页面内部。

## 3. 分层职责与请求链路

### 3.1 iOS 的职责拆分

| 层级 | iOS 文件 | 职责 |
| --- | --- | --- |
| 总览层 | `ExaminationReportSummaryDetailPage.swift` | 展示报告总览、附件、子项入口 |
| 路由层 | `ExaminationReportCategoryDetailPage` | 按分类分发到对应详情页 |
| 影像页 | `ImagingReportDetailPage.swift` | 展示分类、检查方式、部位、结果、诊断 |
| 病理页 | `PathologyReportDetailPage.swift` | 展示分类、亚类、所见、印象、明细 |
| 实验室页 | `LaboratoryReportDetailPage.swift` | 展示表格式明细 |

### 3.2 鸿蒙当前职责拆分

| 层级 | 鸿蒙文件 | 当前状态 |
| --- | --- | --- |
| 总览层 | `ExaminationReportSummaryDetailPage.ets` | 已有，但明细平铺展示 |
| 路由层 | 无 | 缺失 |
| 影像页 | `ImagingReportDetailPage.ets` | 已有，但缺少单项跳转承接 |
| 病理页 | `PathologyReportDetailPage.ets` | 已有，但缺少单项跳转承接 |
| 实验室页 | `LaboratoryReportDetailPage.ets` | 已有，但仍是内嵌明细列表 |

### 3.3 目标请求链路

```text
检查报告总览页
  → 进入“明细”区
  → 点击某一条单项
  → 进入分类路由页
  → 进入影像 / 病理 / 实验室专属详情页
  → 展示该单项对应的分类、检查方式、部位、结果、诊断等信息
```

### 3.4 当前偏差

鸿蒙当前缺少“点击单项进入子页”的中间路由层，导致：

1. 明细只能平铺看，不能钻取
2. 单项详情的页面职责不清晰
3. 公共组件无法复用到多种分类

## 4. 核心关键技术与实现方案

### 4.1 必须补的公共组件

如果要把这条链路完全对齐 iOS，鸿蒙需要补齐以下公共组件：

1. `ExaminationReportCategoryDetailPage`
2. `ExaminationReportSubitemSummaryRow`
3. `ExaminationReportSubitemNavigationLink`
4. `ExaminationReportDetailSupport`
5. 单项结果展示卡片公共结构

这几个组件的意义不是“多写几个文件”，而是把职责拆开：

- 路由层只做跳转
- 行组件只做展示与点击入口
- 支持层只做分类、文本拼接、状态判断
- 各详情页只保留各自差异

### 4.2 影像单项详情必须对齐 iOS

iOS `ImagingReportDetailPage.swift` 的单项详情重点是：

- `category`
- `modality`
- `bodyPart`
- `resultValue + unit`
- `diagnosis`

鸿蒙要对齐这一页，不能只写“结果列表”，而应补成与 iOS 一致的卡片结构。

### 4.3 实验室单项详情必须对齐 iOS 的现状

iOS 当前对实验室单项的承接方式有一个实际现状：

- `ExaminationReportCategoryDetailPage` 的 `laboratory` 分支当前会落到 `ImagingReportDetailPage`

也就是说，实验室单项并不是单独的“实验室单项页”，而是复用了影像详情卡的展示范式。  
鸿蒙如果要完全复刻，不应该自己再设计一套不同的实验室单项卡，而应先保留同样的承接逻辑。

### 4.4 病理单项详情必须保留独立结构

病理页与影像页不同，它的核心信息更偏向：

- 分类
- 亚类
- 所见
- 印象
- 明细项

鸿蒙在补页时，不应把病理页做成“另一种实验室页”，否则会破坏 iOS 的页面语义。

## 5. 接口契约与数据模型

### 5.1 iOS 单项详情依赖的数据模型

| 模型 | 作用 | 关键字段 |
| --- | --- | --- |
| `RemoteExaminationReportWithAttachments` | 报告主体 | `category`、`subCategory`、`findings`、`impression`、`medExamDetails` |
| `RemoteMedExamDetail` | 单项明细 | `itemName`、`category`、`modality`、`bodyPart`、`resultValue`、`unit`、`referenceRange`、`flag`、`diagnosis` |

### 5.2 鸿蒙当前数据模型状态

鸿蒙当前已经有检查报告与明细实体的基础，但还没有把“单项详情页”的展示模型独立出来。  
这会带来两个问题：

1. 明细字段散落在总览页和列表页里
2. 单项页面无法复用统一的字段拼接逻辑

### 5.3 需要统一的字段语义

以下字段必须与 iOS 一致，不得重新定义语义：

- 分类
- 检查方式 / 模态
- 部位
- 结果值
- 单位
- 参考范围
- 异常标记
- 诊断
- 所见
- 印象

### 5.4 模型对齐建议

建议鸿蒙把公共支持层集中到一个独立的详情支持文件里，统一做：

1. 文本非空处理
2. 结果值拼接
3. 异常状态判断
4. 分类到页面的路由映射

这样后续无论是总览页、单项页还是卡片页，都能复用同一套规则。

## 6. iOS-HarmonyOS 功能对照矩阵

| 模块 | iOS 状态 | 鸿蒙状态 | 差异 | 优化方向 |
| --- | --- | --- | --- | --- |
| 单项点击入口 | 已实现 | 未实现 | 明细不可点 | 在总览页补点击入口 |
| 分类路由页 | 已实现 | 未创建 | 少中间路由层 | 新建 `ExaminationReportCategoryDetailPage.ets` |
| 影像单项详情 | 已实现 | 基本有页，但链路不完整 | 缺路由承接 | 接入单项跳转 |
| 病理单项详情 | 已实现 | 基本有页，但链路不完整 | 缺路由承接 | 接入单项跳转 |
| 实验室单项详情 | 已实现 | 仅内嵌展示 | 缺独立详情链路 | 补公共行组件与承接页 |
| 公共摘要行 | 已实现 | 未抽出 | 复用性差 | 抽 `ExaminationReportSubitemSummaryRow` |
| 公共路由支持 | 已实现 | 未抽出 | 模块职责混杂 | 抽 `ExaminationReportDetailSupport` |
| 单项详情页面层级 | 已实现 | 不完整 | 页面语义不一致 | 按 iOS 拆层 |

## 7. 示例工程与官方文档参考结论

### 7.1 本地参考文件

- iOS 总览与子页路由：`/Users/hua/Documents/project/Reference/LookHealthClient/SparkClient/SparkClient/Projects/Features/Home/Presentation/MedicalLists/ExaminationReports/ExaminationReportSummaryDetailPage.swift`
- iOS 影像单项详情：`/Users/hua/Documents/project/Reference/LookHealthClient/SparkClient/SparkClient/Projects/Features/Home/Presentation/MedicalLists/ExaminationReports/ImagingReportDetailPage.swift`
- iOS 实验室单项详情：`/Users/hua/Documents/project/Reference/LookHealthClient/SparkClient/SparkClient/Projects/Features/Home/Presentation/MedicalLists/ExaminationReports/LaboratoryReportDetailPage.swift`
- 鸿蒙总览页：`/Users/hua/Documents/project/Reference/LookHealthClient/SparkClientHarmonyOS/entry/src/main/ets/Projects/Features/Home/Presentation/MedicalLists/ExaminationReports/ExaminationReportSummaryDetailPage.ets`
- 鸿蒙实验室详情：`/Users/hua/Documents/project/Reference/LookHealthClient/SparkClientHarmonyOS/entry/src/main/ets/Projects/Features/Home/Presentation/MedicalLists/ExaminationReports/LaboratoryReportDetailPage.ets`

### 7.2 可复用结论

1. iOS 的单项详情不是总览页里的一个展开块，而是独立钻取页。
2. 分类路由页是必要的中间层，不是多余包装。
3. 单项详情公共组件的职责是承接点击与字段拼接，不是承载业务判断。

### 7.3 不可直接照搬的内容

1. SwiftUI 的 `NavigationLink` / `ForEach` 写法不能原样迁移。
2. iOS 的页面级结构不能直接压扁成一个鸿蒙页面。
3. 不能把“明细列表”误写成“单项详情页已完成”。

### 7.4 鸿蒙关键代码示例

#### 7.4.1 当前已有的分类路由基础

```ts
export type ExaminationReportCategory = 'laboratory' | 'imaging' | 'pathology';

export function examinationCategoryTitle(category: ExaminationReportCategory): string {
  if (category === 'imaging') {
    return '影像';
  }
  if (category === 'pathology') {
    return '病理';
  }
  return '实验室';
}
```

这段代码说明鸿蒙已经有单项详情的分类语义，但还没有“点击某一条明细后进入独立页面”的路由层。

#### 7.4.2 当前总览页的明细渲染方式

```ts
Text(`附件 ${this.report.attachments.length} · 明细 ${this.report.medExamDetails.length}`)

LaboratoryReportDetailPage({ report: this.report })
PathologyReportDetailPage({ report: this.report })
```

这段代码说明鸿蒙当前已经有检查报告总览和分类详情页，但仍是“嵌入式承接”，不是“单项点击进入子页”。

#### 7.4.3 当前实验室详情页的内嵌列表

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

这段代码说明鸿蒙当前没有“单项可点击入口”，所以无法像 iOS 那样进入单项详情页。

#### 7.4.4 需要补上的页面路由骨架

```ts
// 目标结构示意
@Component
export struct ExaminationReportCategoryDetailPage {
  @Prop category: ExaminationReportCategory;
  @Prop report: RemoteExaminationReportWithAttachments;

  build() {
    if (this.category === 'imaging') {
      ImagingReportDetailPage({ report: this.report });
      return;
    }
    if (this.category === 'pathology') {
      PathologyReportDetailPage({ report: this.report });
      return;
    }
    LaboratoryReportDetailPage({ report: this.report });
  }
}
```

这不是现有代码，而是本工单要求补齐的公共路由层示意，用来承接总览页的单项点击。

### 7.5 对本工单的直接影响

1. 需要把 `ForEach` 的每条明细从静态渲染改成可点击行。
2. 需要补一个分类路由页，不要让总览页直接决定每个子页的全部布局。
3. 需要把“明细摘要行”抽成公共组件，否则后续影像、病理、实验室会各写一套。

## 8. 实施拆分与验收

### 8.1 实施拆分

1. 在总览页中为每条明细增加点击入口。
2. 新建 `ExaminationReportCategoryDetailPage.ets`。
3. 新建 `ExaminationReportSubitemSummaryRow.ets`。
4. 新建 `ExaminationReportDetailSupport.ets`。
5. 让 `ImagingReportDetailPage.ets`、`PathologyReportDetailPage.ets` 接受子页路由数据。
6. 处理实验室单项与 iOS 一致的承接方式。

### 8.2 验收标准

必须同时满足以下条件，才能认为“检验单项详情”对齐完成：

1. 明细项可点击。
2. 点击后进入独立子页。
3. 子页能按分类展示对应字段。
4. 影像 / 病理 / 实验室的页面职责清晰。
5. 公共组件可复用。
6. 页面结构与 iOS 语义一致。

### 8.3 体验验收

- 总览页的单项不是静态文本，而是可钻取条目。
- 进入子页后标题与当前单项一致。
- 分类不同，详情布局不同。
- 返回后能回到原始总览位置。

## 9. 风险与待确认项

### 9.1 主要风险

1. 只给明细行加跳转，但没有抽公共路由层，会导致后续维护混乱。
2. 把实验室单项另起一套页面，会偏离 iOS 的实际承接方式。
3. 只做视觉效果，不做字段级路由和职责拆分，会导致“看起来像，实际上不一致”。

### 9.2 待确认项

1. 鸿蒙是否要求严格复刻 iOS 当前“laboratory 落到 imaging 页面”的现状，还是允许在补缺时顺带纠正。
2. 单项详情页是否需要统一做成一个入口页再按分类切换，还是保留独立子页结构。
3. 是否要将公共组件拆到独立的 `Shared/` 目录，和其它检查报告页面共用。

### 9.3 结论性建议

如果目标是“**检验单项详情完全对齐 iOS**”，建议优先补公共路由层和公共摘要行组件，再补分类详情页，否则鸿蒙会一直停留在“总览内嵌列表”的状态。
