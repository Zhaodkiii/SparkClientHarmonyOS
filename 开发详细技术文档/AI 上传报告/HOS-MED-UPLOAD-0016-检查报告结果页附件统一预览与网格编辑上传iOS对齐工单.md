# HOS-MED-UPLOAD-0016 检查报告结果页附件统一预览与网格编辑上传 iOS 对齐工单

> 状态：部分实现  
> 范围：仅覆盖检查报告结果页里的附件展示、统一预览、未关联附件、以及编辑态网格上传链路，不改动服务器契约，不改动 iOS 代码。  
> 审计时间：2026-07-25  
> 参考端：`/Users/hua/Documents/project/Reference/LookHealthClient/SparkClient/`  
> 目标端：`/Users/hua/Documents/project/Reference/LookHealthClient/SparkClientHarmonyOS/`  
> 关联结论：鸿蒙端已经具备统一预览、网格预览、结果页附件区块和未关联附件区块的基础能力，但 `LabReportCard` 的附件展开样式、检查报告结果页的附件组织方式、以及编辑态“新增附件 + 进度卡片 + 上传后回写”的交互仍未完全对齐 iOS。

## 1. 对标范围与结论

### 1.1 本工单要解决的核心问题

这张工单只对齐检查报告结果页截图里的四个关键区域：

1. `LabReportCard` 展开附件
2. 上传结果页 / 未关联附件区的统一预览
3. 结果页的源文件附件展示
4. 网格编辑态上传，包含 `onFileUploaded` 和进度卡片

目标不是单纯“能展示附件”，而是要把以下三件事同时对齐：

1. 页面结构和 UI 组织方式和 iOS 一致
2. 附件点击后的预览方式和 iOS 一致
3. 编辑态上传后的业务回写方式和 iOS 一致

### 1.2 iOS 端真实实现

iOS 端的附件体系分成三层：

1. 列表卡片上的可展开附件区
2. 结果页内的匹配附件 / 未关联附件区
3. 详情页里的网格编辑态附件区

其中关键组件包括：

- `LabReportCard`
- `MedicalAttachmentIconView`
- `MedicalAttachmentListView`
- `CaseMatchedAttachmentsGridView`
- `MedicalDocumentUnlinkedAttachmentsSectionView`
- `MedicalDocumentAttachmentAssociationSheet`
- `MedicalAttachmentGridPreview`

### 1.3 鸿蒙端真实实现

鸿蒙当前已经有同类能力，但分散在不同目录里：

- `LabReportCard.ets`
- `MedicalAttachmentListView` in `MedicalAttachmentComponents.ets`
- `MedicalAttachmentGridPreview` in `MedicalAttachmentComponents.ets`
- `MedicalDocumentUnlinkedAttachmentsSectionView.ets`
- `MedicalDocumentTypedResultScaffoldView.ets`
- `ExaminationReportSummaryDetailPage.ets`

这说明鸿蒙不是“缺少附件基础能力”，而是“页面形态和职责分层还没完全和 iOS 一致”。

### 1.4 结论

鸿蒙目前属于：

- 附件预览能力已具备
- 网格展示能力已具备
- 上传进度卡片能力已具备
- 但检查报告结果页的 UI 组织、网格编辑态上传回调、以及结果页附件区块之间的职责边界还没完全对齐 iOS

因此本工单应重点补齐：

1. `LabReportCard` 的附件展开视图同构
2. 结果页附件区统一预览行为
3. 编辑态上传后的 `onFileUploaded` 回写链路
4. 目录结构和组件归属的同构说明

## 2. 华为端目录设计

### 2.1 iOS 端真实目录

```text
SparkClient/SparkClient/Projects/Features/Home/Presentation/MedicalLists/
├── ExaminationReports/
│   ├── LabReportCard.swift
│   ├── ExaminationReportSummaryDetailPage.swift
│   └── ExaminationReportDetailPage.swift
└── Shared/
    └── MedicalAttachmentComponents.swift

SparkClient/SparkClient/Projects/Features/MedicalDocumentUpload/Presentation/ResultPages/
├── MedicalReportRecognitionResult/
│   ├── MedicalReportRecognitionResultContentView.swift
│   └── MedicalDocumentResultSupport.swift
└── ...
```

### 2.2 鸿蒙端当前目录

```text
SparkClientHarmonyOS/entry/src/main/ets/Projects/Features/Home/Presentation/MedicalLists/
├── ExaminationReports/
│   ├── LabReportCard.ets
│   └── ExaminationReportSummaryDetailPage.ets
└── Shared/
    ├── MedicalAttachmentComponents.ets
    ├── MedicalAttachmentPreviewAdapter.ets
    └── MedicalAttachmentPreviewSupport.ets

SparkClientHarmonyOS/entry/src/main/ets/Projects/Features/MedicalDocumentUpload/Presentation/ResultPages/
├── MedicalDocumentTypedResultScaffoldView.ets
├── MedicalDocumentResultSupport.ets
├── MedicalReportRecognitionResult/
│   ├── MedicalReportRecognitionResultContentView.ets
│   ├── MedicalReportResultSections.ets
│   └── MedicalDocumentUnlinkedAttachmentsSectionView.ets
└── ...
```

### 2.3 目录设计上仍未完全对齐的地方

| iOS 职责 | 鸿蒙现状 | 建议补齐方向 |
| --- | --- | --- |
| `MedicalAttachmentListView` 属于统一附件交互底座 | 已存在于 `Shared/MedicalAttachmentComponents.ets` | 保持共享，但结果页和列表页应统一使用同一预览门面 |
| `LabReportCard` 展开附件后是统一预览列表 | 当前 `LabReportCard.ets` 展开的是文本附件列表 | 建议改成和 iOS 一致的可点击附件条目 + 统一预览 |
| 结果页未关联附件区 | 已有 `MedicalDocumentUnlinkedAttachmentsSectionView.ets` | 需把视觉层和预览行为补齐到 iOS 同构 |
| 编辑态网格上传 | iOS 由 `MedicalAttachmentGridPreview` 自带上传入口和进度卡片 | 鸿蒙当前有网格预览，但缺 `onFileUploaded` 和上传中卡片 |
| 检查报告结果页底部附件区 | 鸿蒙 scaffold 统一追加源文件附件 | 需要评估是否与 iOS 目标页完全一致，若不一致应收敛到页面内显式区块 |

## 3. 页面结构与 UI 组织

### 3.1 iOS 截图对应的页面结构

```text
检查报告识别结果页
├── 成员确认 / 统计
├── 分类检查报告卡片
│   ├── 卡片标题
│   ├── 右侧附件图标
│   ├── 展开后附件列表
│   └── 点击卡片进入本地草稿详情
├── 未关联附件
└── 保存回执
```

### 3.2 鸿蒙当前页面结构

```text
MedicalReportRecognitionResultContentView.ets
├── MedicalReportMemberConfirmSectionView
├── MedicalReportCardsSectionView
│   ├── ReportCard
│   └── MatchedAttachments（当前偏文本列表）
├── MedicalDocumentUnlinkedAttachmentsSectionView
└── SaveReceiptSection
```

### 3.3 当前 UI 差异

| 区块 | iOS | 鸿蒙 | 说明 |
| --- | --- | --- | --- |
| 实验室检查卡片 | `LabReportCard`，可展开附件 | `LabReportCard.ets` 已有卡片但附件区仍是文本式 | 需要对齐附件展开样式 |
| 匹配附件 | `CaseMatchedAttachmentsGridView` / 附件管理 sheet | `MatchedAttachments` 目前只列文件名 | 需要改成可预览、可管理的交互 |
| 未关联附件 | `MedicalDocumentUnlinkedAttachmentsSectionView` | 已有同名组件，但当前只是文本列表 | 需要补统一预览与视觉一致性 |
| 源文件附件 | iOS 检查报告结果页没有单独底部 scaffold 附件条 | 鸿蒙 `MedicalDocumentTypedResultScaffoldView` 底部统一追加 | 若目标是严格对齐 iOS，需要评估是否保留 |
| 编辑态上传 | `onFileUploaded` + 进度卡片 | 当前网格预览支持下载/删除/预览，未提供上传入口 | 需要补上传入口和进度态 |

## 4. 核心关键技术与实现方案

### 4.1 iOS 关键代码示例

#### 4.1.1 `LabReportCard` 展开附件

```swift
MedicalAttachmentIconView(
    count: attachments.count,
    isExpanded: isShowingAttachments
) {
    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
        isShowingAttachments.toggle()
    }
}

if isShowingAttachments && attachments.isEmpty == false {
    MedicalAttachmentListView(
        attachments: attachments,
        fileTransferService: fileTransferService
    )
}
```

这说明 iOS 的附件展开不是简单列表，而是：

1. 右上角附件入口
2. 展开后直接进入统一附件预览列表
3. 附件条目具备下载和预览能力

#### 4.1.2 `MedicalAttachmentListView` 统一预览

```swift
.unifiedFilePreview(
    isPresented: Binding(
        get: { previewInput != nil },
        set: { isPresented in
            if isPresented == false {
                previewInput = nil
            }
        }
    ),
    inputs: previewInput.map { [$0] } ?? []
)
```

这段是关键对齐点。  
iOS 的附件点击不是“只看文件名”，而是“下载/命中缓存后，统一进入预览器”。

#### 4.1.3 编辑态上传 + 进度卡片

```swift
MedicalAttachmentGridPreview(
    attachments: remoteAttachments,
    fileTransferService: fileTransferService,
    isEditing: isEditingAttachments,
    onDeleted: { handleAttachmentDeleted(fileID: $0) },
    onFileUploaded: { handleFileUploaded($0) }
)
```

以及：

```swift
private func handleFileUploaded(_ record: ManagedFileRecord) {
    guard let fileTransferService else { return }
    Task {
        do {
            _ = try await fileTransferService.updateBusinessBinding(
                fileID: record.id,
                businessType: "examination_report",
                businessID: "\(report.id)"
            )
            let newFile = record.remoteManagedFile(
                businessType: "examination_report",
                businessId: "\(report.id)"
            )
            await MainActor.run {
                var updated = report
                updated.attachments = (updated.attachments ?? []) + [newFile]
                report = updated
                attachmentsDirty = true
            }
        } catch {
            await MainActor.run {
                attachmentErrorMessage = MedicalAttachmentErrorMessage.uploadFailed(from: error)
            }
        }
    }
}
```

这说明 iOS 的网格编辑态不是“只显示上传按钮”，而是：

1. 上传中显示独立进度卡片
2. 上传成功后回写业务绑定
3. 再把新附件追加到当前报告

#### 4.1.4 未关联附件区

```swift
MedicalDocumentUnlinkedAttachmentsSectionView(attachments: unlinkedAttachments)
```

这说明 iOS 的未关联附件区是结果页的正式组成部分，而不是调试信息。

### 4.2 鸿蒙关键代码示例

#### 4.2.1 `MedicalAttachmentListView` 已具备统一预览

```ts
UnifiedFilePreview({
  inputs: this.previewInputs,
  startIndex: 0,
  onClose: () => {
    this.showPreviewSheet = false;
  }
})
```

鸿蒙这一点和 iOS 的预览目标是一致的，属于“能力已在，但要在检查报告页面里正确复用”。

#### 4.2.2 `MedicalAttachmentGridPreview` 已具备网格、删除和预览

```ts
Grid() {
  ForEach(this.attachments, (file: RemoteManagedFile) => {
    GridItem() {
      this.gridCard(file, this.attachmentIndex(file))
    }
  })
}
.bindSheet(this.showPreviewSheet, this.previewSheet, {
  height: SheetSize.LARGE,
  dragBar: true,
  showClose: true
})
```

以及编辑态的删除按钮和下载中状态：

```ts
if (this.isEditing && this.onDeleted) {
  Button({ type: ButtonType.Circle }) {
    Text('×')
  }
}
```

这说明鸿蒙已经有网格附件底座，但还缺 iOS 的“新增附件 + 上传进度卡片 + 上传后回写”完整链路。

#### 4.2.3 结果页未关联附件区

```ts
@Component
export struct MedicalDocumentUnlinkedAttachmentsSectionView {
  @Prop fileNames: string[] = [];

  build() {
    if (this.fileNames.length === 0) {
      Column() {}
    } else {
      MedicalDocumentResultSectionCard({
        title: '未关联附件',
        subtitle: '以下源文件尚未关联到具体报告',
        content: () => {
          this.Content()
        }
      })
    }
  }
}
```

这个组件已经存在，但仍然是文本列表形态，没有完全复刻 iOS 的附件交互。

#### 4.2.4 检查报告结果页正文

```ts
Column({ space: 14 }) {
  MedicalReportMemberConfirmSectionView({ ... })
  MedicalReportCardsSectionView({ ... })
  MedicalDocumentUnlinkedAttachmentsSectionView({ fileNames: this.unlinkedNames() })
  this.SaveReceiptSection()
}
```

说明鸿蒙的页面顺序已经对齐 iOS，但卡片内附件与未关联附件的交互形态仍需补齐。

#### 4.2.5 检查报告详情页网格预览

```ts
MedicalAttachmentGridPreview({
  attachments: this.report.attachments,
  fileTransferService: this.fileTransferService
})
```

这说明鸿蒙的网格预览已经能挂到检查报告详情页，但当前缺的是编辑态上传入口和 `onFileUploaded` 回写模式。

### 4.3 需要补齐的关键能力

如果要严格对齐 iOS，本工单建议补以下能力：

1. `LabReportCard.ets` 的附件展开区改成统一预览列表，不再只显示文件名
2. `MedicalDocumentUnlinkedAttachmentsSectionView.ets` 补可点击预览能力
3. `MedicalAttachmentGridPreview` 增加 `onFileUploaded`，并在编辑态显示上传进度卡片
4. 检查报告结果页的附件管理入口要能复用统一附件预览门面
5. 如果 `MedicalDocumentTypedResultScaffoldView` 的源文件附件条与 iOS 目标不一致，应在页面级别收口，而不是让 scaffold 无条件追加

## 5. 接口契约与数据模型

### 5.1 iOS 关键模型

- `SparkMedicalSyncAPI.RemoteExaminationReportWithAttachments`
- `SparkMedicalSyncAPI.RemoteManagedFile`
- `MedicalAttachmentListView`
- `MedicalAttachmentGridPreview`
- `MedicalDocumentUnlinkedAttachmentsSectionView`
- `ManagedFileRecord`

### 5.2 鸿蒙关键模型

- `RemoteExaminationReportWithAttachments`
- `RemoteManagedFile`
- `MedicalAttachmentPreviewAdapter`
- `MedicalAttachmentListView`
- `MedicalAttachmentGridPreview`
- `MedicalDocumentUnlinkedAttachmentsSectionView`
- `MedicalDocumentResultSectionCard`

### 5.3 iOS-HarmonyOS 功能对照矩阵

| 能力 | iOS | 鸿蒙 | 结论 |
| --- | --- | --- | --- |
| 附件入口图标 | `MedicalAttachmentIconView` | `MedicalAttachmentIconView` | 已对齐 |
| 展开附件列表 | `MedicalAttachmentListView` | `MedicalAttachmentListView` | 预览能力对齐，页面使用方式需统一 |
| 统一预览 | `.unifiedFilePreview(...)` | `UnifiedFilePreview(...)` | 已对齐 |
| 网格附件展示 | `MedicalAttachmentGridPreview` | `MedicalAttachmentGridPreview` | 已对齐 |
| 上传进度卡片 | `uploadCoordinator.cards` | 仅有下载/删除态 | 需要补齐 |
| 上传后回写业务绑定 | `onFileUploaded` + `updateBusinessBinding` | 当前无结果页等价回调 | 需要补齐 |
| 未关联附件区 | `MedicalDocumentUnlinkedAttachmentsSectionView` | `MedicalDocumentUnlinkedAttachmentsSectionView` | 结构对齐，交互未完全对齐 |

## 6. 项目架构与页面样式建议

### 6.1 推荐的鸿蒙页面职责边界

| 层级 | 应承担的职责 | 不建议承担的职责 |
| --- | --- | --- |
| `LabReportCard.ets` | 只负责卡片头部、附件展开入口、详情跳转 | 不直接写下载逻辑和业务绑定逻辑 |
| `MedicalAttachmentComponents.ets` | 统一预览、网格展示、上传进度卡片 | 不混入检查报告特有文案 |
| `MedicalDocumentUnlinkedAttachmentsSectionView.ets` | 结果页未关联附件展示 | 不负责业务归属计算 |
| `MedicalDocumentTypedResultScaffoldView.ets` | 页面壳层、底部操作、通用附件区 | 不承载卡片内的业务编辑逻辑 |

### 6.2 UI 样式建议

1. `LabReportCard` 的附件展开区应与 iOS 一样使用“附件图标 + 数量 + 展开后的统一预览条目”
2. 未关联附件区应使用 iOS 类似的卡片层次，而不是纯文本堆叠
3. 网格编辑态的上传中状态应显示与 iOS 接近的进度环 / 进度卡片
4. 附件预览应统一走 `UnifiedFilePreview`，避免不同页面预览器风格不一致
5. 检查报告结果页上的“源文件附件”如需保留，建议在标题、层级和收口方式上与 iOS 做单独确认

## 7. 实施拆分与验收

### 7.1 建议拆分

1. 先把 `LabReportCard.ets` 的附件展开改成统一预览列表
2. 再把 `MedicalDocumentUnlinkedAttachmentsSectionView.ets` 改成可点击预览
3. 然后补 `MedicalAttachmentGridPreview` 的上传进度卡片和 `onFileUploaded`
4. 最后统一收口 `MedicalDocumentTypedResultScaffoldView` 里的源文件附件区是否保留

### 7.2 验收标准

| 验收项 | 期望结果 |
| --- | --- |
| `LabReportCard` 展开附件 | 点击附件图标后能展开统一预览列表，而不是仅显示文件名 |
| 未关联附件区 | 可直接点击预览，视觉层次接近 iOS |
| 网格编辑态上传 | 出现新增入口、上传中进度卡片、成功后回写业务绑定 |
| 统一预览 | 本地缓存和下载后的附件都走同一预览器 |
| 页面结构 | 检查报告结果页四个区域的顺序与 iOS 一致 |

### 7.3 最小回归用例

建议至少覆盖：

1. `LabReportCard` 展开 0/1/N 个附件
2. 未关联附件区 0/1/N 个文件
3. 点击附件条目后进入统一预览
4. 网格编辑态新增附件后显示进度卡片
5. 上传完成后触发 `updateBusinessBinding` 并追加到当前报告

## 8. 风险与待确认项

### 8.1 风险

1. 如果只把鸿蒙当前的文本列表视为“附件已对齐”，会误判 UI 完成度
2. 如果只看 `MedicalAttachmentGridPreview`，会忽略编辑态上传入口和回写逻辑的缺口
3. 如果 `MedicalDocumentTypedResultScaffoldView` 的底部源文件附件条不做页面级确认，容易和 iOS 目标页产生结构偏差

### 8.2 待确认项

1. 检查报告结果页是否要求严格保留 scaffold 底部“源文件附件”区
2. `LabReportCard.ets` 是否要和 iOS 一样改为附件图标展开 + 统一预览列表
3. `MedicalAttachmentGridPreview` 的上传进度卡片是否要直接复用 Home 详情页样式，还是单独为检查报告结果页做一版

### 8.3 本工单最终判断

鸿蒙端在检查报告附件展示和预览底座上已经具备较多基础能力，但在结果页 UI 组织、附件展开样式、以及编辑态上传回写上仍未完全和 iOS 对齐。  
**建议把本工单定位为：已具备统一预览底座，待补齐检查报告结果页附件交互与网格编辑上传同构化的对齐工单。**
