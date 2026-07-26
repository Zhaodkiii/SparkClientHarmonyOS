# SparkClientHarmonyOS｜药箱识别结果页 iOS 对齐工单

> 核验日期：2026-07-26  
> 文档性质：需求工单 + 详细设计约束  
> 参考端：`SparkClient` iOS `MedicineBoxRecognitionResultContentView`  
> 参考输入文件：`/Users/hua/.codex/attachments/320e1e09-89eb-4556-93a4-c9e3414ace32/pasted-text.txt`  
> 目标端：`SparkClientHarmonyOS`  
> 代码边界：本文只创建工单与设计约束，不实现业务代码，不修改现有页面逻辑。

## 1. 工单索引

| 工单号 | 工单名 | 状态 | 范围 |
| --- | --- | --- | --- |
| `HOS-MED-UPLOAD-0019` | 药箱识别结果页 iOS 对齐 | 需求设计中 | 对齐 iOS 药箱识别结果页的页面结构、字段编辑、成员归属、附件重绑、预提交校验、保存接口、保存回执和退出回写语义 |

## 2. 背景与目标

### 2.1 背景

药箱识别结果页是医疗文档上传链路的最终编辑页之一，位于 OCR、类型判定、结构化抽取之后，承担“识别结果可编辑、可校验、可保存到个人药箱”的最后确认职责。

iOS 侧这不是一个只做展示的结果页，而是一个完整的编辑提交页：

- 先从 `MedicalDocumentTypedExtractionOutput` 取出药箱草稿。
- 默认带出成员归属。
- 药品条目支持逐项编辑。
- 支持附件重绑与未关联附件展示。
- 支持预提交校验问题聚合展示。
- 支持保存成功后回写并关闭当前上传流。

### 2.2 目标

本工单只定义药箱识别结果页应达到的行为和边界：

1. 页面结构必须与 iOS 结果页同构，不允许改成另一套单独的表单布局。
2. 结果页的草稿数据模型必须与 iOS `MedicineBoxRecognitionDraft` 字段级一致。
3. 成员确认、附件绑定、条目编辑、预提交校验和保存动作必须保持同一业务流程。
4. 保存提交必须走统一的 `saveResult` / `SaveTypedMedicalDocumentUseCase` / `TypedMedicalDocumentSaving` 入口。
5. 页面 wrapper、内容视图、分区视图、支持类的目录结构必须与当前鸿蒙结果页风格一致。

不在本工单范围内：

- 不实现新的识别算法。
- 不实现新的上传入口。
- 不改服务端 API。
- 不把结果页拆成详情页或药箱列表页。
- 不新增一套独立于上传流程的提交管线。

## 3. iOS 参考行为

### 3.1 页面职责

iOS 结果页的职责是把结构化抽取结果变成可编辑草稿，再提交保存。

页面的核心职责链路是：

```text
typedOutput
  → medicineBoxDrafts
  → member confirm
  → validation summary
  → editable medicine list
  → attachment association
  → submit save
```

### 3.2 页面结构

iOS 页面不是单一 List，而是由几个稳定模块拼成的复合结果页：

- 预提交校验摘要横幅。
- 成员确认区。
- 药品条目分区列表。
- 未关联附件分区。
- 保存回执分区。
- 底部操作栏。

对应的结构示意如下：

```text
MedicineBoxRecognitionResultContentView
├── PreSubmitValidationSummaryBanner
├── MemberConfirmSection
├── MedicineBoxListSection
├── UnlinkedAttachmentsSection
├── SaveReceiptSection
└── BottomBar
    ├── Back
    └── Submit
```

### 3.3 iOS 关键逻辑示意

以下是该页的行为骨架，不是源码复制，而是对当前真实实现的结构化提炼：

```text
init
  → 从 viewModel.typedOutput 读取结果
  → selectedMemberID = envelope.memberID
  → typedResult 是 medicineBoxes 时初始化 items

body
  → 先渲染预提交校验摘要
  → 再渲染成员确认区
  → 再渲染药品条目编辑列表
  → 再渲染未关联附件
  → 如果有 saveReceipt，再渲染保存成功卡片
  → 底部提供返回与提交按钮

submitSave
  → syncItemsToViewModel(items)
  → viewModel.saveResult()
```

### 3.4 iOS 状态与输入

| 状态 / 输入 | 作用 | 对 HarmonyOS 的要求 |
| --- | --- | --- |
| `output: MedicalDocumentTypedExtractionOutput` | 结果页唯一业务输入 | 结果页必须从 typedOutput 初始化，不可重建第二份结果源 |
| `selectedMemberID` | 当前保存归属成员 | 必须可从 envelope.memberID 兜底，并可被用户改写 |
| `items: [MedicineBoxRecognitionDraft]` | 可编辑药品草稿列表 | 必须保持字段级一致 |
| `attachmentTarget` | 附件重绑目标 | 必须支持单条目附件关联 |
| `validationIssues` | 预提交校验结果 | 必须驱动摘要横幅和字段级错误展示 |
| `saveReceipt` | 保存成功回执 | 必须在成功后展示并驱动退出逻辑 |

### 3.5 iOS 提交语义

iOS 提交不是页面直接调用网络层，而是：

```text
View
  → ViewModel.saveResult()
  → SaveTypedMedicalDocumentUseCase.execute(output, sourceFiles)
  → TypedMedicalDocumentSaving.save(output, sourceFiles)
  → MedicalDocumentSaveReceipt
```

这意味着 HarmonyOS 页面必须保持同样的提交职责边界，不能把保存请求改成页面直连或局部拼接 JSON。

## 4. HarmonyOS 当前现状与对齐目标

### 4.1 当前实现位置

当前鸿蒙侧已经存在同名结果页模块，目录结构如下：

```text
entry/src/main/ets/Projects/Features/MedicalDocumentUpload/Presentation/ResultPages/
└── MedicineBoxRecognitionResult/
    ├── MedicineBoxRecognitionResultView.ets
    ├── MedicineBoxRecognitionResultContentView.ets
    ├── MedicineBoxRecognitionResultSupport.ets
    └── MedicineBoxResultSections.ets
```

相关领域模型与保存接口位置：

```text
entry/src/main/ets/Projects/Features/MedicalDocumentUpload/Domain/
├── MedicalDocumentTypedModels.ets
├── MedicalDocumentRecognitionDrafts.ets
├── MedicalDocumentAttachmentBindingModels.ets
└── TypedMedicalDocumentSaving.ets

entry/src/main/ets/Projects/Features/MedicalDocumentUpload/Application/
├── SaveTypedMedicalDocumentUseCase.ets
└── BindUploadedFilesToMedicalBusinessUseCase.ets

entry/src/main/ets/Projects/Features/MedicalDocumentUpload/Presentation/
└── MedicalDocumentUploadViewModel.ets
```

### 4.2 当前鸿蒙页面结构

鸿蒙当前已采用和 iOS 同方向的三层拆分：

- `MedicineBoxRecognitionResultView.ets`：页面外壳。
- `MedicineBoxRecognitionResultContentView.ets`：内容布局。
- `MedicineBoxResultSections.ets`：药品条目编辑区。
- `MedicineBoxRecognitionResultSupport.ets`：草稿取值与错误取值辅助。

这个结构是对的，工单目标不是改结构，而是把内容、字段、保存语义与 iOS 完整拉齐。

### 4.3 当前鸿蒙关键代码骨架

鸿蒙现状已经是“View + ContentView + Sections + Support”模式：

```text
MedicineBoxRecognitionResultView
  → MedicineBoxRecognitionResultContentView
  → MedicalDocumentTypedResultScaffoldView
  → MedicineBoxItemsSectionView
```

条目编辑区当前字段已经覆盖：

- 药品名称
- 药品类型
- 品牌
- 剂型
- 规格
- 剂量单位
- 总数量
- 有效期
- 备注

### 4.4 需要继续对齐的点

1. 页面必须继续使用统一 scaffold，不允许单独造一个结果页容器。
2. `typedOutput` 到 `medicineBoxDrafts` 的初始化必须保持唯一真相源。
3. 成员确认、未关联附件、保存回执和底部提交栏需要和 iOS 的页面职责一一对应。
4. 字段级校验 key 必须稳定，不能因为 ArkUI 组件改造而改变字段语义。
5. 保存动作必须走当前上传链路的统一保存用例，不允许在页面里另起一条保存路径。

### 4.5 关键技术代码片段

下面是本工单要求保留的关键实现骨架，便于鸿蒙侧继续做同构对齐。

#### 4.5.1 页面壳

```text
MedicineBoxRecognitionResultView
  → 只负责挂载 ContentView
```

#### 4.5.2 内容层

```text
MedicineBoxRecognitionResultContentView
  → scaffold(pageTitle, pageSubtitle, kindLabel, body)
  → body 里只放药品条目分区
```

#### 4.5.3 条目编辑

```text
MedicineBoxItemsSectionView
  → list empty 时创建首条草稿
  → 逐字段编辑并 notifyTypedDraftChanged
  → 字段错误通过 err(viewModel, fieldKey) 显示
```

#### 4.5.4 保存链路

```ts
async saveResult(): Promise<boolean>
```

```ts
save(output: MedicalDocumentTypedExtractionOutput, sourceFiles: MedicalAttachmentInput[]): Promise<MedicalDocumentSaveReceipt>
```

结果页必须通过上面的统一链路提交，不能绕过 ViewModel 直接调用业务层。

## 5. 接口契约与数据模型

### 5.1 提交接口

结果页的提交接口在鸿蒙侧表现为两层：

1. 页面层：`viewModel.saveResult(): Promise<boolean>`
2. 领域层：`TypedMedicalDocumentSaving.save(output, sourceFiles): Promise<MedicalDocumentSaveReceipt>`

工单要求：

- 页面只能调用 `saveResult`。
- `saveResult` 只能委托 `SaveTypedMedicalDocumentUseCase`。
- `SaveTypedMedicalDocumentUseCase` 只能委托 `TypedMedicalDocumentSaving`。
- 不能把提交逻辑搬进页面组件树。

### 5.2 核心数据模型

#### `MedicalDocumentTypedExtractionOutput`

| 字段 | 含义 | 对齐要求 |
| --- | --- | --- |
| `envelope` | 成员、类型识别、上传会话信息 | 必须保留为结果页唯一外层信封 |
| `typedResult` | 结果页预览壳 | 用于展示和向后兼容 |
| `typedDrafts` | 分类型草稿树 | 药箱结果页真正编辑的数据源 |
| `extractedJSON` | 原始抽取 JSON | 需保留给调试与保存排障 |
| `payloadPreview` | 预览文本 | 仅用于结果页摘要 |
| `source` | 抽取来源 | 与上传链路保持一致 |
| `retryFeedback` | 重试反馈 | 用于失败后继续修正 |
| `rawAIOutput` | 原始 AI 输出 | 仅作为排障事实，不参与 UI 计算 |

#### `MedicalDocumentTypedDraftTree`

| 字段 | 含义 |
| --- | --- |
| `kind` | 当前结果类型 |
| `medicineBoxDrafts` | 药箱草稿列表 |
| `medicalReportDrafts` | 检查报告草稿列表 |
| `prescriptionDrafts` | 处方草稿列表 |
| `medicationPlanDrafts` | 用药计划草稿列表 |
| `caseDraft` | 病例草稿 |
| `healthExamDraft` | 体检草稿 |

#### `MedicineBoxRecognitionDraft`

| 字段 | 含义 | 备注 |
| --- | --- | --- |
| `medicineName` | 药品名称 | 主标题字段 |
| `medicineType` | 药品类型 | 分类字段 |
| `brandName` | 品牌 | 可空 |
| `dosageForm` | 剂型 | 可空 |
| `strength` | 规格 | 可空 |
| `doseUnit` | 剂量单位 | 可空 |
| `totalQuantity` | 总数量 | 需支持校验 |
| `expireDate` | 有效期 | 建议保持 yyyy-MM-dd |
| `notes` | 备注 | 可空 |
| `extra` | 扩展字段 | 用于兼容新增字段 |
| `sortOrder` | 排序字段 | 保留原顺序 |
| `attachmentFileIds` | 附件绑定 | 必须支持重绑 |

#### `MedicalDocumentSaveReceipt`

| 字段 | 含义 |
| --- | --- |
| `recordID` | 保存后的记录 ID |
| `savedAt` | 保存时间 |
| `isSuccess` | 是否成功 |
| `kind` | 保存的类型 |
| `message` | 保存提示文案 |

### 5.3 业务流程

```text
typedOutput
  → 初始化 selectedMemberID
  → 初始化 medicineBoxDrafts
  → 用户编辑条目
  → 用户重绑附件
  → 用户点击提交
  → preSubmitValidation
  → saveResult
  → 保存成功后退出并回写上游
```

### 5.4 字段级对齐要求

1. 页面展示字段必须和 iOS 草稿字段同名同义。
2. 任何新增字段必须进入 `extra` 或上游模型扩展，不允许在页面里私造临时字段作为事实源。
3. 附件绑定必须沿用现有 `attachmentFileIds` 语义。
4. 成员归属必须保留在 `envelope.memberID` 和页面本地 `selectedMemberID` 的双向同步逻辑中。
5. 保存成功回执必须保留 `recordID` 和 `message`，用于回写和提示。

## 6. iOS-HarmonyOS 功能对照矩阵

| 功能块 | iOS 事实 | HarmonyOS 现状 | 状态 | 需要补齐 |
| --- | --- | --- | --- | --- |
| 页面壳 | `MedicineBoxRecognitionResultView` + `ContentView` | `MedicineBoxRecognitionResultView.ets` + `ContentView.ets` | 已部分对齐 | 保持同构，不新增第二套容器 |
| 页面 scaffold | 自定义结果页骨架 | `MedicalDocumentTypedResultScaffoldView` | 已实现 | 保持页面标题、子标题、类型标签一致 |
| 成员确认 | `selectedMemberID` 初始化与可改写 | 当前 scaffold 支持 member ID 输入 | 部分对齐 | 结果页内必须显示确认入口 |
| 药品条目列表 | `items: [MedicineBoxRecognitionDraft]` | `MedicineBoxItemsSectionView` | 已实现 | 继续对齐字段、顺序、错误提示 |
| 未关联附件 | `unlinkedAttachments` | 已有通用未关联附件组件 | 已具备 | 结果页需接入并展示 |
| 预提交校验 | `validationIssues` + summary banner | 已有 pre-submit banner | 已具备 | 校验 key 与滚动定位保持一致 |
| 保存回执 | `saveReceipt` 卡片 | `MedicalDocumentSaveReceipt` | 部分对齐 | 成功后展示与退出语义要齐 |
| 提交接口 | `saveResult()` → `save(output, sourceFiles)` | `saveResult()` → `SaveTypedMedicalDocumentUseCase` | 已对齐 | 不能绕过统一保存用例 |
| 附件重绑 | `attachmentTarget` sheet | `MedicalDocumentAttachmentAssociationSheet` | 已具备 | 需保持每条目独立绑定语义 |

## 7. 示例工程与官方文档参考结论

### 7.1 本地示例工程

本工单优先参考当前工程内已有的医疗文档结果页实现，而不是额外造一套示例：

- `entry/src/main/ets/Projects/Features/MedicalDocumentUpload/Presentation/ResultPages/MedicalReportRecognitionResult/MedicalReportRecognitionResultContentView.ets`
- `entry/src/main/ets/Projects/Features/MedicalDocumentUpload/Presentation/ResultPages/MedicalDocumentTypedResultScaffoldView.ets`
- `entry/src/main/ets/Projects/Features/MedicalDocumentUpload/Presentation/ResultPages/PreSubmitValidation/MedicalPreSubmitValidationSummaryBanner.ets`
- `entry/src/main/ets/Projects/Features/MedicalDocumentUpload/Presentation/ResultPages/MedicalDocumentResultSupport.ets`

可直接借鉴：

- 结果页统一 scaffold 的接入方式。
- 预提交校验摘要的呈现方式。
- 成员确认、附件未关联、成功回执等模块的布局顺序。

不可直接复制：

- 其他类型结果页的字段文案。
- 其他类型结果页的卡片标题和业务解释。
- 不属于药箱草稿的字段和校验 key。

### 7.2 官方能力结论

本工单是结果页与保存链路的页面对齐，不涉及新的系统级能力扩展。

因此当前只需要遵守已经在工程中落地的 ArkUI 组件、页面导航和本地状态管理方式；如果后续需要补充 `Navigation`、`ScrollView`、`TextInput`、`Button` 或系统级文件选择的最新 API 约束，再按华为官方文档进行二次复核。

## 8. 实施拆分与验收

### 8.1 拆分建议

1. 对齐页面壳与 scaffold，确保结果页入口、标题和子标题与 iOS 同步。
2. 对齐成员确认区，把 `selectedMemberID` 变成显式且可回写的结果页状态。
3. 对齐药品条目编辑区，保持字段顺序、校验 key 和错误提示一致。
4. 对齐附件关联区，把未关联附件与条目重绑恢复到 iOS 同构语义。
5. 对齐保存回执和提交链路，保证保存成功后有回执、有退出、有上游回写。

### 8.2 验收标准

1. 页面结构可以一眼对应到 iOS 的结果页模块。
2. 药品草稿字段和 iOS 代码中的 `MedicineBoxRecognitionDraft` 完全一致。
3. 提交动作只走 `saveResult()` 和 `SaveTypedMedicalDocumentUseCase`。
4. 保存成功后能回显回执，并触发后续退出语义。
5. 预提交校验问题能聚合显示，并能定位到对应字段。
6. 附件重绑不会丢失原始草稿，也不会把未关联附件吞掉。

### 8.3 验收产物

- 页面结构截图或录屏。
- 字段级对照表。
- 保存成功与失败的日志样例。
- 预提交校验命中样例。
- 附件重绑样例。

## 9. 风险与待确认项

### 9.1 风险

1. 如果页面在鸿蒙侧新增第二套草稿源，会和 `typedDrafts` 发生分叉。
2. 如果保存入口绕过 `saveResult`，后续保存回执和附件绑定语义会失真。
3. 如果成员归属只在 UI 层临时保存，保存时会丢失正确的归属信息。
4. 如果附件绑定和条目编辑分散到多个页面，会破坏结果页一体化提交语义。

### 9.2 待确认项

1. iOS 端是否还存在更细的附件卡片排序规则，需要和鸿蒙附件区保持完全一致。
2. 保存成功后是否需要保留当前页一小段成功态，而不是立即退出。
3. 未关联附件在页面上是否只读展示，还是需要支持从结果页直接编辑。
4. 药箱识别结果页是否还要兼容旧版草稿字段别名。

### 9.3 不允许的做法

- 不允许把药箱识别结果页改写成药箱详情页。
- 不允许用一套新的数据模型替换 `MedicineBoxRecognitionDraft`。
- 不允许在页面里直接发起保存请求。
- 不允许把未关联附件和药品条目拆成两个独立结果页。
- 不允许删除保存回执，只保留一个 toast。

