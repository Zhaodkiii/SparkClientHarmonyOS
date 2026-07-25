# HOS-MED-UPLOAD-0012 各类型结果页目录文件组件完全一致补充工单

> 状态：已实现
> 范围：仅补充 AI 上传报告“各类型结果页”与 iOS 在目录结构、文件拆分、组件命名、测试颗粒度上的完全一致性，不改动 iOS 代码，不改动服务器代码。
> 审计时间：2026-07-25
> 参考对象：`SparkClient/SparkClient/Projects/Features/MedicalDocumentUpload/Presentation/ResultPages/`
> 现有 HarmonyOS 基线：`SparkClientHarmonyOS/entry/src/main/ets/Projects/Features/MedicalDocumentUpload/Presentation/ResultPages/`
> 关联工单：`HOS-MED-UPLOAD-0008`、`HOS-MED-UPLOAD-0011`

## 1. 对标范围与结论

### 1.1 为什么要再补这张工单

前一版结果页工单已经把“按类型分流、确认页编辑、预提交校验、保存入口”做了功能对齐，但如果对齐目标提升为“**页面完全一致**”，那当前 HarmonyOS 仍然只做到了语义对齐，没有做到文件结构与组件拆分的同构对齐。

当前 HarmonyOS 与 iOS 的差异主要不在“能不能展示”，而在：

1. 目录层级是否一致
2. 文件拆分是否一致
3. 组件命名是否一致
4. 每个页面的职责边界是否一致
5. 测试文件的颗粒度是否一致

一句话结论：**目前 HarmonyOS 已具备结果页功能，但仍是“压缩版实现”；如果要求完全对齐 iOS，则必须补齐同名目录、同名文件、同职责组件。**

### 1.2 iOS 端真实文件结构

iOS 端结果页相关文件已经拆成了明确的分层：

```text
SparkClient/Projects/Features/MedicalDocumentUpload/Presentation/
├── MedicalDocumentUploadHostView.swift
├── MedicalDocumentUploadModeSelectionView.swift
├── MedicalDocumentUploadPickingView.swift
├── MedicalDocumentUploadProgressView.swift
├── MedicalDocumentUploadResultView.swift
├── MedicalDocumentUploadViewModel.swift
├── MedicalDocumentResultRouterView.swift
├── MedicalDocumentResultDetailNavigationSupport.swift
├── MedicalDocumentResultSupport.swift
├── MedicalDocumentTypedResultScaffoldView.swift
├── MedicalDocumentFilePickerMenu.swift
├── MedicalUploadLocalFileImportSupport.swift
├── CaseRecognitionResultView.swift
├── HealthExamRecognitionResultView.swift
├── MedicalReportRecognitionResultView.swift
├── MedicationRecognitionResultView.swift
├── MedicineBoxRecognitionResultView.swift
├── PrescriptionRecognitionResultView.swift
├── PreSubmitValidation/
│   ├── MedicalPreSubmitValidationNavigation.swift
│   ├── MedicalPreSubmitValidationSummaryBanner.swift
│   └── MedicalValidationIssueInlineView.swift
└── ResultPages/
    ├── CaseRecognitionResult/
    │   ├── CaseRecognitionResultContentView.swift
    │   ├── CaseRecognitionResultSupport.swift
    │   ├── CaseMemberInfoSectionView.swift
    │   ├── CaseHistoryDiagnosisSectionView.swift
    │   ├── CaseVisitInfoSectionView.swift
    │   ├── CaseTreatmentPlanSectionView.swift
    │   └── CaseMatchedAttachmentsGridView.swift
    ├── HealthExamRecognitionResult/
    │   ├── HealthExamRecognitionResultContentView.swift
    │   ├── HealthExamResultSupport.swift
    │   ├── HealthExamResultSections.swift
    │   └── HealthExamResultEditors.swift
    ├── MedicalReportRecognitionResult/
    │   ├── MedicalReportRecognitionResultContentView.swift
    │   ├── MedicalReportResultSupport.swift
    │   └── MedicalReportResultSections.swift
    ├── MedicationRecognitionResult/
    │   ├── MedicationRecognitionResultContentView.swift
    │   ├── MedicationRecognitionResultSupport.swift
    │   └── MedicationResultSections.swift
    ├── MedicineBoxRecognitionResult/
    │   ├── MedicineBoxRecognitionResultContentView.swift
    │   ├── MedicineBoxRecognitionResultSupport.swift
    │   └── MedicineBoxResultSections.swift
    └── PrescriptionRecognitionResult/
        ├── PrescriptionRecognitionResultContentView.swift
        ├── PrescriptionRecognitionResultSupport.swift
        ├── PrescriptionResultSections.swift
        └── PrescriptionRecognitionResultPreviewFixtures.swift
```

### 1.3 HarmonyOS 端当前文件结构

```text
SparkClientHarmonyOS/entry/src/main/ets/Projects/Features/MedicalDocumentUpload/Presentation/
├── MedicalDocumentUploadHostView.ets
├── MedicalDocumentTypedResultPage.ets
├── MedicalDocumentUploadPickingView.ets
├── MedicalDocumentUploadProgressView.ets
├── MedicalDocumentUploadViewModel.ets
└── ResultPages/
    ├── MedicalDocumentResultRouter.ets
    ├── Shared/
    │   ├── MedicalDocumentResultChrome.ets
    │   └── PreSubmitValidation/
    │       └── MedicalPreSubmitValidationBanner.ets
    ├── CaseRecognitionResult/
    │   └── CaseRecognitionResultPage.ets
    ├── HealthExamRecognitionResult/
    │   └── HealthExamRecognitionResultPage.ets
    ├── MedicalReportRecognitionResult/
    │   └── MedicalReportRecognitionResultPage.ets
    ├── MedicationRecognitionResult/
    │   └── MedicationRecognitionResultPage.ets
    ├── MedicineBoxRecognitionResult/
    │   └── MedicineBoxRecognitionResultPage.ets
    └── PrescriptionRecognitionResult/
        └── PrescriptionRecognitionResultPage.ets
```

### 1.4 当前结论

HarmonyOS 已经完成功能上的结果页承接，但与 iOS 相比仍有三类结构性差异：

1. iOS 把“壳层、内容、分区、支持、测试”拆得更细，HarmonyOS 还偏单文件聚合
2. iOS 的每个类型页都有自己的 `ContentView` / `Support` / `Sections`，HarmonyOS 目前只有一个 `Page`
3. iOS 的预提交校验、结果页导航和 fixtures 是独立文件，HarmonyOS 当前仍压在少数共享文件中

## 2. 文件级对齐清单

### 2.1 主入口与结果壳

| iOS 文件 | iOS 职责 | HarmonyOS 现状 | 偏差 | 优化方向 |
| --- | --- | --- | --- | --- |
| `MedicalDocumentUploadHostView.swift` | 上传页主容器，承接 stage 分支 | `MedicalDocumentUploadHostView.ets` | 基本对齐 | 保持壳层一致，继续收敛公共装饰 |
| `MedicalDocumentUploadResultView.swift` | 结果页主容器/结果承接壳 | 当前无同名文件，结果入口由 `MedicalDocumentResultRouter.ets` 承接 | 文件结构不一致 | 补齐同名壳层或薄包装层 |
| `MedicalDocumentResultRouterView.swift` | 类型路由到各结果页 | `MedicalDocumentResultRouter.ets` | 命名不一致 | 保持路由职责，补同名层级或包装 |
| `MedicalDocumentTypedResultScaffoldView.swift` | typed 结果页壳层 | `MedicalDocumentTypedResultPage.ets` + `MedicalDocumentResultChrome.ets` 合并承接 | 结构压缩 | 拆成独立 scaffold 文件 |
| `MedicalDocumentResultSupport.swift` | 结果页共用工具 | 当前无同名文件，部分逻辑放在 `MedicalDocumentResultChrome.ets` | 结构压缩 | 抽出支持文件 |
| `MedicalDocumentResultDetailNavigationSupport.swift` | 结果页跳转/导航支持 | 当前无同名文件 | 缺失 | 新增同职责文件 |

### 2.2 预提交校验

| iOS 文件 | iOS 职责 | HarmonyOS 现状 | 偏差 | 优化方向 |
| --- | --- | --- | --- | --- |
| `PreSubmitValidation/MedicalPreSubmitValidationNavigation.swift` | 校验结果与导航锚点 | 当前无同名文件 | 缺失 | 增加独立导航支持文件 |
| `PreSubmitValidation/MedicalPreSubmitValidationSummaryBanner.swift` | 校验摘要横幅 | `MedicalPreSubmitValidationBanner.ets` | 仅部分对齐 | 拆出 summary banner 与 inline view |
| `PreSubmitValidation/MedicalValidationIssueInlineView.swift` | 字段级 inline 校验提示 | 当前无同名文件 | 缺失 | 补齐字段级校验组件 |

### 2.3 病例页

| iOS 文件 | iOS 职责 | HarmonyOS 现状 | 偏差 | 优化方向 |
| --- | --- | --- | --- | --- |
| `CaseRecognitionResultView.swift` | 病例结果页主视图 | `CaseRecognitionResultPage.ets` | 命名不一致 | 拆出 View/ContentView/Support |
| `CaseRecognitionResultContentView.swift` | 病例内容编辑区域 | 当前无同名文件 | 缺失 | 新增内容层 |
| `CaseRecognitionResultSupport.swift` | 病例页支持函数和状态转换 | 当前无同名文件 | 缺失 | 新增支持层 |
| `CaseMemberInfoSectionView.swift` | 成员信息区块 | 当前无同名文件 | 缺失 | 新增分区组件 |
| `CaseHistoryDiagnosisSectionView.swift` | 病史/诊断区块 | 当前无同名文件 | 缺失 | 新增分区组件 |
| `CaseVisitInfoSectionView.swift` | 就诊信息区块 | 当前无同名文件 | 缺失 | 新增分区组件 |
| `CaseTreatmentPlanSectionView.swift` | 治疗计划区块 | 当前无同名文件 | 缺失 | 新增分区组件 |
| `CaseMatchedAttachmentsGridView.swift` | 匹配附件网格 | 当前无同名文件 | 缺失 | 新增附件组件 |

### 2.4 体检报告页

| iOS 文件 | iOS 职责 | HarmonyOS 现状 | 偏差 | 优化方向 |
| --- | --- | --- | --- | --- |
| `HealthExamRecognitionResultView.swift` | 体检结果页主视图 | `HealthExamRecognitionResultPage.ets` | 命名不一致 | 拆出 View/ContentView |
| `HealthExamRecognitionResultContentView.swift` | 体检内容编辑区域 | 当前无同名文件 | 缺失 | 新增内容层 |
| `HealthExamResultSupport.swift` | 体检结果支持函数 | 当前无同名文件 | 缺失 | 新增支持层 |
| `HealthExamResultSections.swift` | 基础信息/明细区块 | 当前无同名文件 | 缺失 | 拆成多个 section 文件 |
| `HealthExamResultEditors.swift` | 编辑器组合 | 当前无同名文件 | 缺失 | 新增编辑器层 |

### 2.5 检查报告页

| iOS 文件 | iOS 职责 | HarmonyOS 现状 | 偏差 | 优化方向 |
| --- | --- | --- | --- | --- |
| `MedicalReportRecognitionResultView.swift` | 检查结果页主视图 | `MedicalReportRecognitionResultPage.ets` | 命名不一致 | 拆出 View/ContentView |
| `MedicalReportRecognitionResultContentView.swift` | 检查内容编辑区域 | 当前无同名文件 | 缺失 | 新增内容层 |
| `MedicalReportResultSupport.swift` | 检查页支持函数 | 当前无同名文件 | 缺失 | 新增支持层 |
| `MedicalReportResultSections.swift` | 检查结果区块 | 当前无同名文件 | 缺失 | 拆出分区组件 |

### 2.6 处方页

| iOS 文件 | iOS 职责 | HarmonyOS 现状 | 偏差 | 优化方向 |
| --- | --- | --- | --- | --- |
| `PrescriptionRecognitionResultView.swift` | 处方结果页主视图 | `PrescriptionRecognitionResultPage.ets` | 命名不一致 | 拆出 View/ContentView |
| `PrescriptionRecognitionResultContentView.swift` | 处方内容编辑区域 | 当前无同名文件 | 缺失 | 新增内容层 |
| `PrescriptionRecognitionResultSupport.swift` | 处方页支持函数 | 当前无同名文件 | 缺失 | 新增支持层 |
| `PrescriptionResultSections.swift` | 处方区块 | 当前无同名文件 | 缺失 | 新增分区组件 |
| `PrescriptionRecognitionResultPreviewFixtures.swift` | 预览与测试样本 | 当前无同名文件 | 缺失 | 新增 fixtures 文件 |

### 2.7 用药计划页

| iOS 文件 | iOS 职责 | HarmonyOS 现状 | 偏差 | 优化方向 |
| --- | --- | --- | --- | --- |
| `MedicationRecognitionResultView.swift` | 用药计划结果页主视图 | `MedicationRecognitionResultPage.ets` | 命名不一致 | 拆出 View/ContentView |
| `MedicationRecognitionResultContentView.swift` | 用药计划内容编辑区域 | 当前无同名文件 | 缺失 | 新增内容层 |
| `MedicationRecognitionResultSupport.swift` | 用药计划页支持函数 | 当前无同名文件 | 缺失 | 新增支持层 |
| `MedicationResultSections.swift` | 用药计划分区组件 | 当前无同名文件 | 缺失 | 新增分区组件 |

### 2.8 药箱页

| iOS 文件 | iOS 职责 | HarmonyOS 现状 | 偏差 | 优化方向 |
| --- | --- | --- | --- | --- |
| `MedicineBoxRecognitionResultView.swift` | 药箱结果页主视图 | `MedicineBoxRecognitionResultPage.ets` | 命名不一致 | 拆出 View/ContentView |
| `MedicineBoxRecognitionResultContentView.swift` | 药箱内容编辑区域 | 当前无同名文件 | 缺失 | 新增内容层 |
| `MedicineBoxRecognitionResultSupport.swift` | 药箱页支持函数 | 当前无同名文件 | 缺失 | 新增支持层 |
| `MedicineBoxResultSections.swift` | 药箱分区组件 | 当前无同名文件 | 缺失 | 新增分区组件 |

### 2.9 测试

| iOS 测试 | iOS 职责 | HarmonyOS 现状 | 偏差 | 优化方向 |
| --- | --- | --- | --- | --- |
| `MedicalPreSubmitValidatorTests.swift` | 预提交校验规则 | HarmonyOS 仅有对应工单测试，不是同名文件 | 命名不一致 | 补齐同职责测试 |
| `PrescriptionMedicineBoxCandidateTests.swift` | 处方/药箱候选逻辑 | 当前无同名文件 | 缺失 | 补齐候选逻辑测试 |
| `MedicalExtractionInputSourceTests.swift` | 输入源映射 | 当前无同名文件 | 缺失 | 补齐输入源测试 |
| `PrescriptionPreSubmitValidationTests.swift` | 处方预提交校验 | 当前无同名文件 | 缺失 | 补齐处方校验测试 |

## 3. 组件级差异

### 3.1 iOS 的组件颗粒度

iOS 的结果页已经把“页面”和“组件”分得很细，典型特征是：

1. 顶层 `View` 只负责组装
2. `ContentView` 负责主体布局
3. `Support` 负责状态转换、格式化和辅助函数
4. `Sections` 负责每个页面的区块组件
5. `PreviewFixtures` 负责测试与预览样本

### 3.2 HarmonyOS 目前的组件颗粒度

HarmonyOS 当前更多是：

1. 一个 `Page`
2. 一个共享的 `MedicalDocumentResultChrome`
3. 一个共享的预提交 banner
4. 少量结果页页面文件

这会导致以下问题：

- 页面文件越来越胖
- 共用组件难以复用
- 页面之间的结构一致性难以保证
- 之后如果继续补 iOS 同名文件，会越来越难拆

### 3.3 必须补齐的组件族

建议按照 iOS 的结构补齐以下组件族：

| 组件族 | iOS 形式 | HarmonyOS 目标 |
| --- | --- | --- |
| 页面壳 | `*RecognitionResultView.swift` | `*RecognitionResultView.ets` 或同职责壳层 |
| 内容层 | `*RecognitionResultContentView.swift` | 独立 `ContentView.ets` |
| 支持层 | `*RecognitionResultSupport.swift` | 独立 `Support.ets` |
| 分区层 | `*ResultSections.swift` / 各种 SectionView | 独立分区组件文件 |
| 预提交校验 | `MedicalPreSubmitValidation*` | 拆成 navigation / banner / inline 三件套 |
| 结果页共用导航 | `MedicalDocumentResultDetailNavigationSupport.swift` | 独立导航支持文件 |
| 结果页 scaffold | `MedicalDocumentTypedResultScaffoldView.swift` | 独立 scaffold 文件 |

## 4. 当前偏差

### 4.1 结构偏差

HarmonyOS 的最大偏差不是“少了几个页面”，而是“把 iOS 的分层压扁了”。

具体表现为：

1. `MedicalDocumentResultChrome.ets` 承担了 iOS 多个支持文件的职责
2. `MedicalPreSubmitValidationBanner.ets` 承担了 iOS 三个文件的职责
3. 各类型结果页目前是单文件主视图，没有同构的 content/support/sections 拆分
4. `MedicalDocumentTypedResultPage.ets` 仍承担了过多兜底职责

### 4.2 命名偏差

iOS 使用的是 `*View.swift`、`*ContentView.swift`、`*Support.swift`、`*Sections.swift`。

HarmonyOS 当前使用的是：

- `*Page.ets`
- `*Router.ets`
- `*Chrome.ets`
- `*Banner.ets`

这并不是功能问题，但如果目标是“完全一致”，命名层就需要向 iOS 靠拢。

### 4.3 测试偏差

iOS 的测试集中在：

- 预提交校验
- 候选逻辑
- 输入源映射
- 处方校验

HarmonyOS 当前虽然已有医疗上传测试文件，但测试命名和覆盖点仍更偏“工单序列”，而不是“功能组件序列”。

## 5. 补齐方向

### 5.1 先做目录同构

建议先在 HarmonyOS 侧建立与 iOS 一致的子目录结构，即使一开始只是薄包装文件，也要先把目录搭平。

优先级建议：

1. `Presentation/ResultPages/PreSubmitValidation/`
2. `Presentation/ResultPages/CaseRecognitionResult/`
3. `Presentation/ResultPages/HealthExamRecognitionResult/`
4. `Presentation/ResultPages/MedicalReportRecognitionResult/`
5. `Presentation/ResultPages/PrescriptionRecognitionResult/`
6. `Presentation/ResultPages/MedicationRecognitionResult/`
7. `Presentation/ResultPages/MedicineBoxRecognitionResult/`

### 5.2 再做文件同名

建议把现有 `*Page.ets` 逐步拆成 iOS 同职责文件：

- `*View.ets`
- `*ContentView.ets`
- `*Support.ets`
- `*Sections.ets`

如果不想一次性重命名，也可以先并行增加同职责文件，再逐步把逻辑迁入。

### 5.3 结果页公共能力拆分

建议补齐以下共享文件：

1. `MedicalDocumentTypedResultScaffoldView.ets`
2. `MedicalDocumentResultSupport.ets`
3. `MedicalDocumentResultDetailNavigationSupport.ets`
4. `MedicalPreSubmitValidationNavigation.ets`
5. `MedicalPreSubmitValidationSummaryBanner.ets`
6. `MedicalValidationIssueInlineView.ets`

### 5.4 各类型页面拆分

建议每个类型页都按 iOS 方式拆成至少 3 层：

1. 顶层结果页壳
2. 内容层
3. 支持/区块层

其中病例、体检、检查、处方、用药计划、药箱要分别补齐自己的 section 文件。

### 5.5 测试也要同构

建议把测试文件命名和关注点按 iOS 对齐：

- 预提交校验测试
- 输入源测试
- 处方候选测试
- 处方/药箱校验测试

这样后续排查问题时，测试文件名就能直接对应到页面模块。

## 6. 整体验收标准

### 6.1 目录级验收

1. HarmonyOS 的 `ResultPages/` 目录层级与 iOS 同构
2. 结果页公共能力文件被拆成独立 support/scaffold/navigation 文件
3. 每个类型页都有独立子目录
4. 每个类型页都至少包含 `View` / `Content` / `Support` / `Sections` 四类职责文件

### 6.2 文件级验收

1. 文件命名能一一映射到 iOS 文件
2. 不能再用一个 `Page` 文件同时承担壳层、内容层和分区层职责
3. 不能再把多个 iOS 支持文件压缩进一个 HarmonyOS 共享文件

### 6.3 组件级验收

1. 体检、检查、处方、用药计划、药箱都能按 iOS 同样的组件层次组装
2. 校验横幅、校验 inline、导航支持、结果 scaffold 都有独立组件
3. 预览 fixtures 或测试样本不再散落在页面逻辑中

### 6.4 测试级验收

1. 测试文件覆盖点与 iOS 对齐
2. 预提交校验、候选逻辑、输入源映射、处方校验都能单独验证
3. 页面拆分后仍保持原有业务行为不回退

