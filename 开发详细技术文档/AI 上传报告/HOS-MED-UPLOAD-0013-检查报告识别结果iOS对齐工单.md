# HOS-MED-UPLOAD-0013 检查报告识别结果 iOS 对齐工单

> 状态：部分实现  
> 范围：仅覆盖“检查报告识别结果（成员确认 + 统计概览 + 报告卡片 + 提交保存）”这一页的 iOS 对齐，不改动服务器契约，不改动 iOS 代码。  
> 审计时间：2026-07-25  
> 参考端：`/Users/hua/Documents/project/Reference/LookHealthClient/SparkClient/`  
> 目标端：`/Users/hua/Documents/project/Reference/LookHealthClient/SparkClientHarmonyOS/`  
> 关联上下文：鸿蒙已经有结果页入口、壳层、统计和卡片编辑的基础，但与 iOS 的区块组合、卡片交互和公共组件颗粒度仍有偏差。

## 1. 对标范围与结论

### 1.1 本工单对应的 iOS 页面

iOS 端“检查报告识别结果”页面已经形成完整结构，关键文件如下：

- 入口：`SparkClient/SparkClient/Projects/Features/MedicalDocumentUpload/Presentation/ResultPages/MedicalReportRecognitionResultView.swift`
- 正文：`SparkClient/SparkClient/Projects/Features/MedicalDocumentUpload/Presentation/ResultPages/MedicalReportRecognitionResult/MedicalReportRecognitionResultContentView.swift`
- 区块组件：`SparkClient/SparkClient/Projects/Features/MedicalDocumentUpload/Presentation/ResultPages/MedicalReportRecognitionResult/MedicalReportResultSections.swift`
- 统一壳层：`SparkClient/SparkClient/Projects/Features/MedicalDocumentUpload/Presentation/ResultPages/MedicalDocumentTypedResultScaffoldView.swift`

### 1.2 鸿蒙端当前状态

鸿蒙侧已经有对应入口和正文分层，但并没有完整复刻 iOS 的区块职责：

- 入口：`MedicalReportRecognitionResultView.ets`
- 正文：`MedicalReportRecognitionResultContentView.ets`
- 区块：`MedicalReportResultSections.ets`
- 壳层：`MedicalDocumentTypedResultScaffoldView.ets`

当前鸿蒙处于“能显示、能编辑部分内容、能提交保存”的阶段，但与 iOS 相比还有两个关键偏差：

1. iOS 是“成员确认 + 统计概览”合并成一个明确区块，鸿蒙目前是“壳层成员栏 + 统计区块”拆开承接。
2. iOS 的报告卡片更偏向“可跳详情 + 可编辑”，鸿蒙当前是“卡片内联编辑”为主，导航感不一致。

### 1.3 结论

鸿蒙已经进入“页面可用”阶段，但还没有进入“iOS 同构阶段”。  
如果要求目录结构、数据模型、页面模块、流程和公共组件都对齐 iOS，则本页还需要补：

1. 成员确认与统计概览的组合区块
2. 报告卡片的跳转和编辑职责统一
3. 页面内公共支持层进一步拆分
4. 与 iOS 一致的保存前校验与回执展示语义

## 2. 华为端目录设计

### 2.1 iOS 端真实目录结构

```text
SparkClient/SparkClient/Projects/Features/MedicalDocumentUpload/Presentation/
├── MedicalDocumentTypedResultScaffoldView.swift
├── MedicalDocumentUploadResultView.swift
├── MedicalReportRecognitionResultView.swift
└── ResultPages/
    └── MedicalReportRecognitionResult/
        ├── MedicalReportRecognitionResultContentView.swift
        ├── MedicalReportResultSections.swift
        └── MedicalReportResultSupport.swift
```

### 2.2 鸿蒙端当前目录结构

```text
SparkClientHarmonyOS/entry/src/main/ets/Projects/Features/MedicalDocumentUpload/Presentation/
├── MedicalDocumentTypedResultPage.ets
├── MedicalDocumentTypedResultScaffoldView.ets
├── MedicalDocumentUploadHostView.ets
└── ResultPages/
    ├── MedicalDocumentResultSupport.ets
    ├── MedicalReportRecognitionResultView.ets
    └── MedicalReportRecognitionResult/
        ├── MedicalReportRecognitionResultContentView.ets
        ├── MedicalReportResultSections.ets
        └── MedicalReportResultSupport.ets
```

### 2.3 鸿蒙端目标目录结构

如果要求“目录结构完全一致”，建议鸿蒙保留当前公共壳层，但把职责拆分收敛到与 iOS 一致的同名域：

```text
SparkClientHarmonyOS/entry/src/main/ets/Projects/Features/MedicalDocumentUpload/Presentation/
├── MedicalDocumentTypedResultScaffoldView.ets
├── MedicalReportRecognitionResultView.ets
└── ResultPages/
    └── MedicalReportRecognitionResult/
        ├── MedicalReportRecognitionResultContentView.ets
        ├── MedicalReportResultSections.ets
        ├── MedicalReportResultSupport.ets
        └── MedicalReportMemberConfirmSectionView.ets   # 目标补充
```

### 2.4 目录设计原则

1. 入口层只负责进入页面，不承担细粒度区块。
2. 正文层承接成员、统计、卡片、附件与保存前校验。
3. 区块层要拆出“成员确认 + 统计概览”和“报告卡片”两个独立职责。
4. 壳层只提供统一标题、成员栏、底部操作和整体容器，不重复实现正文逻辑。

## 3. 分层职责与请求链路

### 3.1 iOS 的真实职责分工

| 层级 | iOS 文件 | 职责 |
| --- | --- | --- |
| 入口层 | `MedicalReportRecognitionResultView.swift` | 识别结果页入口 |
| 正文层 | `MedicalReportRecognitionResultContentView.swift` | 维护成员、报告 drafts、附件、校验、保存 |
| 区块层 | `MedicalReportResultSections.swift` | 成员确认、统计、卡片编辑 |
| 壳层 | `MedicalDocumentTypedResultScaffoldView.swift` | 标题、横幅、成员、正文、附件、底部操作 |

### 3.2 鸿蒙当前职责分工

| 层级 | 鸿蒙文件 | 当前状态 |
| --- | --- | --- |
| 入口层 | `MedicalReportRecognitionResultView.ets` | 已有，仅转发正文 |
| 正文层 | `MedicalReportRecognitionResultContentView.ets` | 已有，但区块组合和 iOS 不完全一致 |
| 区块层 | `MedicalReportResultSections.ets` | 已有，但成员确认与卡片职责拆分不同 |
| 壳层 | `MedicalDocumentTypedResultScaffoldView.ets` | 已有，负责统一标题、成员栏、正文、附件、底部操作 |

### 3.3 目标请求链路

```text
OCR / AI 抽取完成
  → 进入检查报告识别结果页
  → 显示成员确认 + 统计概览
  → 显示检查报告卡片列表
  → 卡片支持编辑 / 跳转详情 / 删除
  → 显示未关联附件
  → 点击提交保存
  → 校验通过后提交到 viewModel.saveResult()
  → 返回保存回执
```

### 3.4 当前偏差

鸿蒙当前已经有“能跑起来”的链路，但不是 iOS 同构链路：

1. iOS 的“成员确认 + 统计概览”是一个明确区块，鸿蒙当前被拆散到 scaffold 和 stats section 里。
2. iOS 卡片更强调“跳详情”和区块化展示，鸿蒙目前更强调“内联编辑”。
3. iOS 在结果页内容层内部组合校验、附件、回执，鸿蒙也有，但职责边界还不够像。

## 4. 核心关键技术与实现方案

### 4.1 iOS 结构的关键点

iOS `MedicalReportRecognitionResultContentView.swift` 的核心不是“展示一个列表”，而是：

1. 从 `viewModel.typedOutput` 取结构化结果
2. 维护 `selectedMemberID`
3. 维护 `reports`
4. 维护 `attachmentTarget`
5. 维护 `expandedValidationSections`
6. 渲染校验横幅
7. 渲染成员确认区块
8. 渲染报告卡片区块
9. 渲染未关联附件
10. 渲染保存回执

### 4.2 iOS 关键代码示例

#### 4.2.1 正文的状态编排

```swift
@State private var selectedMemberID: Int?
@State private var reports: [MedicalReportRecognitionDraft]
@State private var attachmentTarget: MedicalReportAttachmentTarget?
@State private var expandedValidationSections: Set<String> = []
@State private var lastAutoRevealedIssueID: UUID?
```

这说明 iOS 的正文层不是简单渲染，而是直接管理成员、草稿、附件、校验展开状态。

#### 4.2.2 正文的区块组合

```swift
MedicalPreSubmitValidationSummaryBanner(issues: validationIssues) { issue in
    MedicalPreSubmitValidationNavigation.reveal(
        issue: issue,
        expandedSectionIDs: $expandedValidationSections,
        scrollProxy: scrollProxy
    )
}

MedicalReportMemberConfirmSectionView(
    memberContextStore: viewModel.memberContextStoreForLocalForms,
    selectedMemberID: selectedMemberID,
    reports: reports,
    onSelectMember: { memberID in
        selectedMemberID = memberID
        viewModel.updateResultMemberID(memberID)
    }
)

MedicalReportCardsSectionView(
    reports: reports,
    validationIssues: validationIssues,
    attachmentsForIDs: matchedAttachments(for:),
    detailNavigationContext: detailNavigationContext,
    onUpdateReportDraft: updateReportDraft(at:draft:),
    onDeleteReportDraft: deleteReportDraft(at:),
    onManageAttachments: { index in
        attachmentTarget = MedicalReportAttachmentTarget(index: index)
    }
)
```

这段代码说明 iOS 的结果页是“按区块编排”，不是把所有逻辑塞进一个大页面。

#### 4.2.3 报告卡片的跳转承接

```swift
if let detailNavigationContext {
    MainNavigationLink {
        reportDetailDestination(index: index, report: report, category: category, context: detailNavigationContext)
    } label: {
        reportCardContent(index: index, report: report, category: category)
    }
}
```

这说明 iOS 的卡片不仅能编辑，还可以跳转到更深层详情页，这一点鸿蒙当前还不完整。

### 4.3 鸿蒙关键代码示例

#### 4.3.1 入口层只是转发正文

```ts
@Component
export struct MedicalReportRecognitionResultView {
  @ObjectLink viewModel: MedicalDocumentUploadViewModel;

  build() {
    MedicalReportRecognitionResultContentView({ viewModel: this.viewModel })
  }
}
```

这说明鸿蒙入口层已经有了，但它只是薄包装，真正的差异在正文和区块层。

#### 4.3.2 正文层已经接入了 typed 输出、成员和报告列表

```ts
@ObjectLink viewModel: MedicalDocumentUploadViewModel;

@State private selectedMemberID: number | undefined = undefined;
@State private reports: MedicalReportRecognitionDraft[] = [];
@State private attachmentTarget: MedicalReportAttachmentTarget | undefined = undefined;

build() {
  MedicalDocumentTypedResultScaffoldView({
    viewModel: this.viewModel,
    pageTitle: '检查报告识别结果',
    pageSubtitle: MedicalReportResultSupport.categoryStats(
      MedicalReportResultSupport.reports(this.viewModel)),
    kindLabel: MedicalDocumentResultKindResolver.kindLabel(MedicalDocumentKind.MEDICAL_REPORT),
    body: () => {
      this.BodySections()
    }
  })
}
```

这说明鸿蒙已经具备结果页骨架，但正文依旧偏“组合式”，不是 iOS 那种明显的成员确认 + 卡片区块结构。

#### 4.3.3 鸿蒙已有的成员统计区块

```ts
MedicalDocumentResultSectionCard({
  title: '检查报告统计',
  subtitle: '按检验 / 影像 / 病理分类统计报告数量',
  content: () => {
    this.StatsContent()
  }
})
```

这说明鸿蒙已经有统计卡片，但它被单独做成了统计区块，和成员确认没有合并成 iOS 那样的统一区块。

#### 4.3.4 鸿蒙已有的卡片编辑区块

```ts
MedicalValidatedEditableField({
  label: '报告标题',
  value: report.title,
  fieldKey: `examination_reports[${index}].item_name`,
  scrollTargetID: `preSubmitValidation.card.examinationReport.${index}`,
  errorMessage: MedicalReportResultSupport.err(this.viewModel, `examination_reports[${index}].item_name`),
  onValueChange: (v: string) => {
    report.title = v;
    this.viewModel.notifyTypedDraftChanged([`examination_reports[${index}].item_name`]);
  }
})
```

这段代码说明鸿蒙的卡片目前是“内联编辑”模式，和 iOS 的“卡片可跳详情”不完全一致。

### 4.4 需要补充的公共组件

如果要对齐 iOS，鸿蒙建议补齐或重构以下公共组件：

1. `MedicalReportMemberConfirmSectionView`
2. `MedicalReportCardsSectionView` 的详情跳转能力
3. `MedicalReportCardDetailNavigation` 或同职责路由组件
4. `MedicalReportResultValidationSummarySection`
5. `MedicalReportResultSaveReceiptSection`

其中最关键的是：

- 成员确认和统计概览要在语义上合并
- 卡片要支持“编辑”和“跳详情”两种承接方式
- 保存回执要保留统一展示位置

## 5. 接口契约与数据模型

### 5.1 iOS 端关键数据模型

| 模型 | 作用 | 关键字段 |
| --- | --- | --- |
| `MedicalDocumentTypedExtractionOutput` | typed 识别结果总载体 | `envelope`、`typedResult`、`payloadPreview` |
| `MedicalReportRecognitionDraft` | 检查报告草稿 | `category`、`title`、`hospital`、`doctor`、`content`、`date`、`details`、`attachmentFileIds` |
| `MedicalPreSubmitValidationIssue` | 保存前校验问题 | `resourceType`、`cardIndex`、`fieldKey`、`summaryLine` |
| `MedicalReportAttachmentTarget` | 附件关联目标 | `index` |

### 5.2 鸿蒙端当前数据模型状态

鸿蒙当前已经复用了检查报告草稿与校验模型的基础，但正文层仍然偏向上传识别流程，不完全等于 iOS 结果页：

- `MedicalReportRecognitionDraft` 已存在
- `MedicalPreSubmitValidationIssue` 已存在
- `MedicalDocumentUploadViewModel` 已能维护 typed result
- 但结果页区块的职责边界和 iOS 不同

### 5.3 需要一致的字段语义

以下字段必须与 iOS 保持同义，不得重命名成别的业务语义：

- 成员归属
- 报告分类
- 报告标题
- 医院
- 医生
- 日期
- 所见 / 印象
- 子项明细
- 附件关联
- 保存前校验问题
- 保存回执

### 5.4 当前模型偏差

鸿蒙当前的卡片编辑直接依赖 `MedicalValidatedEditableField`，可编辑性很强，但会弱化 iOS 的“卡片分组 + 跳详情”的结果页结构。  
这意味着模型本身虽然齐了，但页面模块没有完全收敛到 iOS 语义。

## 6. iOS-HarmonyOS 功能对照矩阵

| 模块 | iOS 状态 | 鸿蒙状态 | 差异 | 优化方向 |
| --- | --- | --- | --- | --- |
| 结果页入口 | 已实现 | 已实现 | 基本对齐 | 保持入口薄包装 |
| 统一壳层 | 已实现 | 已实现 | 基本对齐 | 继续复用 scaffold |
| 成员确认区块 | 已实现 | 部分实现 | 鸿蒙拆散在 scaffold / stats | 新建统一成员确认区块 |
| 统计概览区块 | 已实现 | 已实现 | 布局不完全一致 | 收敛到一个 section |
| 报告卡片区块 | 已实现 | 部分实现 | iOS 可跳详情，鸿蒙偏内联编辑 | 增加详情承接与跳转 |
| 保存前校验 | 已实现 | 已实现 | 语义基本对齐 | 保留自动展开逻辑 |
| 附件关联 | 已实现 | 已实现 | 基本对齐 | 保持关联行为一致 |
| 保存回执 | 已实现 | 已实现 | 基本对齐 | 保持统一区块位置 |
| 公共组件颗粒度 | 已实现 | 不完全 | 鸿蒙组件更粗 | 继续拆公共组件 |

## 7. 示例工程与官方文档参考结论

### 7.1 本地参考文件

- iOS 入口：`/Users/hua/Documents/project/Reference/LookHealthClient/SparkClient/SparkClient/Projects/Features/MedicalDocumentUpload/Presentation/ResultPages/MedicalReportRecognitionResultView.swift`
- iOS 正文：`/Users/hua/Documents/project/Reference/LookHealthClient/SparkClient/SparkClient/Projects/Features/MedicalDocumentUpload/Presentation/ResultPages/MedicalReportRecognitionResult/MedicalReportRecognitionResultContentView.swift`
- iOS 区块：`/Users/hua/Documents/project/Reference/LookHealthClient/SparkClient/SparkClient/Projects/Features/MedicalDocumentUpload/Presentation/ResultPages/MedicalReportRecognitionResult/MedicalReportResultSections.swift`
- iOS 壳层：`/Users/hua/Documents/project/Reference/LookHealthClient/SparkClient/SparkClient/Projects/Features/MedicalDocumentUpload/Presentation/ResultPages/MedicalDocumentTypedResultScaffoldView.swift`
- 鸿蒙入口：`/Users/hua/Documents/project/Reference/LookHealthClient/SparkClientHarmonyOS/entry/src/main/ets/Projects/Features/MedicalDocumentUpload/Presentation/ResultPages/MedicalReportRecognitionResultView.ets`
- 鸿蒙正文：`/Users/hua/Documents/project/Reference/LookHealthClient/SparkClientHarmonyOS/entry/src/main/ets/Projects/Features/MedicalDocumentUpload/Presentation/ResultPages/MedicalReportRecognitionResult/MedicalReportRecognitionResultContentView.ets`
- 鸿蒙区块：`/Users/hua/Documents/project/Reference/LookHealthClient/SparkClientHarmonyOS/entry/src/main/ets/Projects/Features/MedicalDocumentUpload/Presentation/ResultPages/MedicalReportRecognitionResult/MedicalReportResultSections.ets`
- 鸿蒙壳层：`/Users/hua/Documents/project/Reference/LookHealthClient/SparkClientHarmonyOS/entry/src/main/ets/Projects/Features/MedicalDocumentUpload/Presentation/ResultPages/MedicalDocumentTypedResultScaffoldView.ets`

### 7.2 可复用结论

1. 鸿蒙入口层已经足够薄，后续重点是正文与区块职责。
2. 鸿蒙的壳层已经能承载成员、附件、底部操作，不需要重写，只需要继续补足区块语义。
3. `MedicalReportResultSupport` 已经提供分类、统计和错误提取能力，适合继续扩展，不适合拆散成页面私有逻辑。

### 7.3 不可直接照搬的内容

1. iOS 的 SwiftUI `NavigationLink` 不能直接照抄到鸿蒙。
2. iOS 的 `sheet` / `fullScreenCover` 组织方式必须按 ArkUI 重写。
3. iOS 的页面分层不能被鸿蒙合并成单文件，否则会失去后续可维护性。

### 7.4 鸿蒙关键代码示例

#### 7.4.1 入口层

```ts
@Component
export struct MedicalReportRecognitionResultView {
  @ObjectLink viewModel: MedicalDocumentUploadViewModel;

  build() {
    MedicalReportRecognitionResultContentView({ viewModel: this.viewModel })
  }
}
```

这说明入口层已经正确薄化，不是当前主要偏差点。

#### 7.4.2 正文层

```ts
build() {
  MedicalDocumentTypedResultScaffoldView({
    viewModel: this.viewModel,
    pageTitle: '检查报告识别结果',
    pageSubtitle: MedicalReportResultSupport.categoryStats(
      MedicalReportResultSupport.reports(this.viewModel)),
    kindLabel: MedicalDocumentResultKindResolver.kindLabel(MedicalDocumentKind.MEDICAL_REPORT),
    body: () => {
      this.BodySections()
    }
  })
}
```

这段代码说明正文层已经接入 scaffold，但目前正文区块仍需要向 iOS 语义继续收敛。

#### 7.4.3 统计区块

```ts
MedicalDocumentResultSectionCard({
  title: '检查报告统计',
  subtitle: '按检验 / 影像 / 病理分类统计报告数量',
  content: () => {
    this.StatsContent()
  }
})
```

这说明统计已经有了，但它还没有和成员确认合并成 iOS 那种组合区块。

#### 7.4.4 卡片编辑区块

```ts
MedicalValidatedEditableField({
  label: '报告标题',
  value: report.title,
  fieldKey: `examination_reports[${index}].item_name`,
  scrollTargetID: `preSubmitValidation.card.examinationReport.${index}`,
  errorMessage: MedicalReportResultSupport.err(this.viewModel, `examination_reports[${index}].item_name`),
  onValueChange: (v: string) => {
    report.title = v;
    this.viewModel.notifyTypedDraftChanged([`examination_reports[${index}].item_name`]);
  }
})
```

这说明鸿蒙已经可以内联编辑单卡，但还缺少 iOS 式“区块化卡片 + 跳详情”的组合表达。

## 8. 实施拆分与验收

### 8.1 实施拆分

1. 把成员确认与统计概览收敛为单独区块。
2. 保留 `MedicalReportCardsSectionView`，但补充详情跳转承接。
3. 抽出卡片导航组件或详情路由组件。
4. 保持保存前校验横幅和自动展开逻辑。
5. 保持附件未关联区块和保存回执区块。

### 8.2 验收标准

必须同时满足以下条件，才算达到 iOS 对齐目标：

1. 识别结果页入口和正文分层一致。
2. 成员确认与统计概览的语义一致。
3. 报告卡片支持与 iOS 相同的交互意图。
4. 保存前校验展示和自动定位一致。
5. 附件关联和保存回执区块位置一致。
6. 公共组件颗粒度足够细，后续不需要在页面内重复堆逻辑。

### 8.3 体验验收

- 进入结果页后，先能确认成员。
- 能直观看到按类型统计的概览。
- 报告卡片可以继续编辑或跳转。
- 校验问题能自动提示并回到对应区块。
- 提交保存后出现保存回执。

## 9. 风险与待确认项

### 9.1 主要风险

1. 仅补视觉，不补区块职责，会导致和 iOS 还是不一致。
2. 只保留内联编辑，不增加详情跳转，卡片交互会偏离 iOS。
3. 成员确认区块如果继续分散在 scaffold 和 stats 两处，后续维护会越来越重。
4. 如果公共支持层继续只放在页面里，后续每个类型页都会复制逻辑。

### 9.2 待确认项

1. 鸿蒙是否要把 `MedicalReportMemberConfirmSectionView` 单独做成与 iOS 同名区块。
2. 卡片区块是否需要同时保留“编辑”与“详情跳转”两种承接方式。
3. 是否要把保存回执区块独立成与 iOS 同职责的 section。
4. 结果页的结构化字段展示是否需要补齐和 iOS 完全一致的标题文案。

### 9.3 结论性建议

如果本页的目标是“**鸿蒙 UI 对齐 iOS，且目录结构、数据模型、页面模块、流程、公共组件都一致**”，建议优先收敛区块职责，而不是继续在正文里堆字段。当前鸿蒙已经能用，但还没有完全进入 iOS 的页面同构阶段。

