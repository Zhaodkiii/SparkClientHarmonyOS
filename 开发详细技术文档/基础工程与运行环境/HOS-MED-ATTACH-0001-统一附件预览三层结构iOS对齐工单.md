# HOS-MED-ATTACH-0001 统一附件预览三层结构 iOS 对齐工单

> 状态：部分实现  
> 范围：仅覆盖“统一附件预览 / 业务公共组件 / 页面调用”三层结构对齐，不改动服务器契约，不改动 iOS 代码。  
> 审计时间：2026-07-25  
> 参考端：`/Users/hua/Documents/project/Reference/LookHealthClient/SparkClient/`  
> 目标端：`/Users/hua/Documents/project/Reference/LookHealthClient/SparkClientHarmonyOS/`  
> 关联上下文：
> - iOS 核心预览：`SparkClient/SparkClient/Projects/Core/UI/FilePreview/View+UnifiedFilePreview.swift`
> - iOS 医疗附件组件：`SparkClient/SparkClient/Projects/Features/Home/Presentation/MedicalLists/Shared/MedicalAttachmentComponents.swift`

## 1. 对标范围与结论

### 1.1 iOS 端真实结构

iOS 的附件预览不是单一组件，而是明确的三层结构：

1. 底层统一预览
2. 业务公共组件
3. 各页面调用

对应到真实代码：

- 底层统一预览：`View+UnifiedFilePreview.swift`
- 业务公共组件：`MedicalAttachmentComponents.swift`
- 页面调用：各业务页面直接调用 `MedicalAttachmentListView`、`MedicalAttachmentGridPreview`、`MedicalAttachmentIconView`

### 1.2 鸿蒙端真实结构

鸿蒙当前已经有附件相关组件，但结构是“局部实现 + 各页面分散调用”，还没有收敛成与 iOS 一样的三层结构：

- `MedicalDocumentFilePreviewSquareCard.ets`
- `MedicalAttachmentGridPreview`（在 `MedicalAttachmentComponents` 同职责文件内）
- `MedicalAttachmentBindingBridge.ets`
- `MedicalDocumentAttachmentUploader.ets`
- `MedicalDocumentUnlinkedAttachmentsSectionView.ets`
- `MedicalDocumentUploadPickingView.ets` 的本地预览页
- `MedicineBoxAttachmentThumbnail.ets`

### 1.3 结论

鸿蒙当前已经具备“看附件”的局部能力，但缺少：

1. 统一附件预览底层
2. 业务公共附件组件的统一收敛
3. 各页面一致的调用方式
4. 统一的数据模型桥接

一句话结论：**鸿蒙有零散附件预览，没有 iOS 那种统一的三层附件预览架构。**

## 2. 华为端目录设计

### 2.1 iOS 端目录结构

```text
SparkClient/SparkClient/Projects/Core/UI/FilePreview/
└── View+UnifiedFilePreview.swift

SparkClient/SparkClient/Projects/Features/Home/Presentation/MedicalLists/Shared/
└── MedicalAttachmentComponents.swift
```

### 2.2 鸿蒙端当前目录结构

```text
SparkClientHarmonyOS/entry/src/main/ets/Projects/Features/Home/Presentation/MedicalLists/
├── Shared/
│   ├── MedicalAttachmentBindingBridge.ets
│   └── ...
├── MedicineBox/
│   └── MedicalDocumentFilePreviewSquareCard.ets
├── ExaminationReports/
│   └── ...
└── MedicalDocumentAttachmentUploader.ets

SparkClientHarmonyOS/entry/src/main/ets/Projects/Features/MedicalDocumentUpload/Presentation/
├── MedicalDocumentUploadPickingView.ets
└── ResultPages/
    └── MedicalReportRecognitionResult/
        └── MedicalDocumentUnlinkedAttachmentsSectionView.ets
```

### 2.3 鸿蒙端目标目录结构

如果要求与 iOS 三层结构对齐，建议收敛为：

```text
SparkClientHarmonyOS/entry/src/main/ets/Projects/Core/UI/FilePreview/
├── UnifiedFilePreview.ets
├── UnifiedFilePreviewInput.ets
└── View+UnifiedFilePreview.ets

SparkClientHarmonyOS/entry/src/main/ets/Projects/Features/Home/Presentation/MedicalLists/Shared/
├── MedicalAttachmentComponents.ets
├── MedicalAttachmentPreviewListView.ets
├── MedicalAttachmentPreviewGridView.ets
├── MedicalAttachmentIconView.ets
└── MedicalAttachmentPreviewSupport.ets
```

### 2.4 目录清理原则

1. 不要让各页面自己造预览壳。
2. 不要让附件预览逻辑散落在上传页、详情页、结果页和药箱页里。
3. 统一预览只能保留一套核心实现。

## 3. 分层职责与请求链路

### 3.1 iOS 的三层结构

| 层级 | iOS 文件 | 职责 |
| --- | --- | --- |
| 底层统一预览 | `View+UnifiedFilePreview.swift` | 提供 `sheet` 弹层和输入数组版 / 本地文件数组版统一预览 |
| 业务公共组件 | `MedicalAttachmentComponents.swift` | 提供图标、列表、网格、上传 / 下载 / 预览 / 删除、文件元数据桥接 |
| 页面调用 | 各业务页面 | 在病例、检查报告、药箱、聊天、上传页中直接调用附件组件 |

### 3.2 鸿蒙当前分层

| 层级 | 鸿蒙文件 | 当前状态 |
| --- | --- | --- |
| 统一预览底层 | 未收敛成独立公共层 | 缺失 |
| 业务公共组件 | `MedicalDocumentFilePreviewSquareCard`、`MedicalAttachmentGridPreview`、`MedicalDocumentUnlinkedAttachmentsSectionView` | 部分实现 |
| 页面调用 | `MedicalDocumentUploadPickingView`、`MedicineBoxAttachmentThumbnail`、部分详情页 | 已有，但实现不统一 |

### 3.3 目标请求链路

```text
页面拿到附件数据
  → 统一映射为 FilePreviewInput / 预览输入
  → 交给业务公共组件渲染列表 / 网格 / 图标
  → 点击后调用统一预览底层
  → 图片 / PDF / 其它文件走同一预览入口
  → 删除 / 上传 / 绑定仍由业务组件接管
```

### 3.4 当前偏差

当前鸿蒙的偏差不是“没有预览”，而是：

1. 页面级预览方式不一致
2. 数据模型不统一
3. 图标、列表、网格、上传、预览逻辑混在不同文件里
4. 没有像 iOS 那样把底层统一预览抽成一个明确入口

## 4. 核心关键技术与实现方案

### 4.1 iOS 底层统一预览的关键代码示例

```swift
func unifiedFilePreview(
    isPresented: Binding<Bool>,
    inputs: [FilePreviewInput],
    startIndex: Int = 0,
    onDismiss: (() -> Void)? = nil
) -> some View {
    sheet(isPresented: isPresented, onDismiss: onDismiss) {
        UnifiedFilePreview(inputs: inputs, startIndex: startIndex) {
            isPresented.wrappedValue = false
        }
    }
}
```

这段代码说明 iOS 不是让各页面自己造弹层，而是把统一预览封装成 View 扩展。

### 4.2 iOS 业务公共组件的关键代码示例

#### 4.2.1 列表预览

```swift
struct MedicalAttachmentListView: View {
    let attachments: [SparkMedicalSyncAPI.RemoteManagedFile]
    let fileTransferService: FileTransferService
}
```

列表组件负责：

1. 渲染附件行
2. 命中缓存后直接预览
3. 未缓存时先下载再预览

#### 4.2.2 网格预览

```swift
struct MedicalAttachmentGridPreview: View {
    let attachments: [SparkMedicalSyncAPI.RemoteManagedFile]
    let fileTransferService: FileTransferService
    var isEditing: Bool = false
}
```

网格组件负责：

1. 方块缩略图
2. 图片 / 非图片分流
3. 下载缓存
4. 点击打开统一预览
5. 编辑态删除 / 上传

#### 4.2.3 附件图标

```swift
struct MedicalAttachmentIconView: View {
    let count: Int
    var isExpanded = false
    let onTap: () -> Void
}
```

这个组件负责展示附件数量与展开状态，是列表 / 卡片上的统一入口。

### 4.3 鸿蒙关键代码示例

#### 4.3.1 预览方块

```ts
@Component
export struct MedicalDocumentFilePreviewSquareCard {
  @Prop item: FilePreviewInput = new FilePreviewInput();
  @Prop showDelete: boolean = true;
  onPreview?: () => void;
  onDelete?: () => void;
}
```

这说明鸿蒙已经有“文件预览方块”的雏形，但它还不是统一预览底层，只是一个卡片。

#### 4.3.2 医疗附件缩略图

```ts
@Component
export struct MedicineBoxAttachmentThumbnail {
  @Prop attachment: RemoteManagedFile = new RemoteManagedFile();
  fileTransferService?: FileTransferService;
}
```

这说明鸿蒙已经有业务页面级附件预览缩略图，但还没有把它完全提升成共享公共组件层。

#### 4.3.3 附件上传与预览的本地数据模型

```ts
export class MedicalAttachmentInput {
  previewId: string = '';
  sourceUri: string = '';
  originalName: string = '';
  mimeType: string = 'application/octet-stream';
  ocrText: string = '';
  remoteFile?: ManagedFileRecord;
}
```

这说明鸿蒙已有与 iOS `MedicalUploadLocalFile` 接近的本地附件模型，但 preview / 缓存 / 业务绑定还没有完全收敛成统一层。

#### 4.3.4 附件业务绑定桥

```ts
export class MedicalAttachmentBindingBridge {
  static applyHealthExamFileIds(...)
  static applyMedicineBoxFileIds(...)
  static remoteFileIdsFromLocal(...)
}
```

这说明鸿蒙已经有“文件 ID 绑定业务结果”的桥接层，但这层不负责统一预览本身。

#### 4.3.5 上传页临时预览

```ts
private UnifiedFilePreviewBuilder() {
  Column() {
    if (this.previewIndex >= 0 && this.previewIndex < this.viewModel.selectedFiles.length) {
      this.PreviewPage(this.viewModel.selectedFiles[this.previewIndex])
    }
  }
  .backgroundColor(Color.Black)
}
```

这段代码说明鸿蒙上传页目前用了页面内临时预览壳，属于需要收敛的旧实现。

### 4.4 需要补充的公共组件

建议鸿蒙补齐的公共组件分三层：

1. 底层统一预览
2. 业务公共组件
3. 页面调用封装

建议最少补齐：

- `UnifiedFilePreview`
- `UnifiedFilePreviewInput`
- `View+unifiedFilePreview`
- `MedicalAttachmentPreviewListView`
- `MedicalAttachmentPreviewGridView`
- `MedicalAttachmentIconView`
- `MedicalAttachmentPreviewSupport`

### 4.5 需要清理的旧代码

以下实现建议逐步替换，不要继续并存：

1. `MedicalDocumentUploadPickingView.ets` 里的页面内本地预览页
2. 各页面自己写的附件预览弹层
3. 只显示文本、不支持预览的简化附件列表
4. 只在某一个业务页生效的预览缩略图逻辑

## 5. 接口契约与数据模型

### 5.1 iOS 端关键数据模型

| 模型 | 作用 | 关键字段 |
| --- | --- | --- |
| `FilePreviewInput` | 统一预览输入 | `id`、`fileURL`、`displayName`、`mimeType`、`utTypeIdentifier`、`resolvedDisplayName`、`isImage`、`isLocalFileAvailable` |
| `MedicalUploadLocalFile` | 本地附件输入 | `id`、`url`、`displayName`、`mimeType`、`ocrText`、`remoteFile`、`previewInput` |
| `RemoteManagedFile` | 远端附件 | `id`、`fileUuid`、`fileUrl`、`objectKey`、`mimeType`、`businessType`、`businessId`、`fileSize`、`fileMd5`、`storageType`、`createdAt` |
| `ManagedFileRecord` | 预览 / 下载记录 | `id`、`fileUuid`、`filePath`、`originalName`、`fileSize`、`mimeType`、`fileMd5`、`isPublic`、`businessType`、`businessId`、`createdAt`、`objectKey`、`storageType` |

### 5.2 鸿蒙端关键数据模型

| 模型 | 作用 | 关键字段 |
| --- | --- | --- |
| `MedicalAttachmentInput` | 本地待上传附件 | `previewId`、`sourceUri`、`originalName`、`mimeType`、`ocrText`、`remoteFile` |
| `FilePreviewInput` | 方块预览输入 | `fileURL`、`isImage`、`resolvedDisplayName` |
| `RemoteManagedFile` | 远端业务附件 | `id`、`fileUuid`、`originalName`、`fileSize`、`mimeType`、`fileMd5`、`businessType`、`businessId`、`objectKey`、`storageType`、`createdAt` |
| `ManagedFileRecord` | 上传 / 下载结果 | `id`、`fileUuid`、`filePath`、`originalName`、`fileSize`、`mimeType`、`fileMd5`、`businessType`、`businessId`、`objectKey`、`storageType`、`createdAt` |

### 5.3 需要一致的字段语义

以下语义必须保持一致：

- 文件来源
- 预览文件名
- MIME 类型
- 本地缓存地址
- 远端业务绑定
- 是否可删除
- 是否可点击预览

### 5.4 当前模型偏差

鸿蒙当前的问题不是缺模型，而是：

1. 同一类附件预览在不同页面用了不同输入结构
2. 本地文件和远端文件没有统一成同一个预览输入协议
3. 页面内部仍然有临时预览实现

### 5.5 完整数据模型对照

下面这张表把 iOS 侧的完整数据链路拆开，对应到鸿蒙现状，方便后续逐项补齐。

| 链路层 | iOS 模型 / 语义 | iOS 关键字段 | 鸿蒙当前模型 / 语义 | 鸿蒙关键字段 | 偏差结论 |
| --- | --- | --- | --- | --- | --- |
| 本地选择态 | `MedicalUploadLocalFile` | `id`、`url`、`displayName`、`mimeType`、`ocrText`、`remoteFile` | `MedicalAttachmentInput` | `previewId`、`sourceUri`、`originalName`、`mimeType`、`ocrText`、`remoteFile` | 语义基本对齐，但鸿蒙 `previewId` 是字符串，本地预览输入还没有统一封装成共享适配器 |
| 统一预览输入 | `FilePreviewInput` | `id`、`fileURL`、`displayName`、`mimeType`、`utTypeIdentifier`、`resolvedDisplayName`、`isImage` | `FilePreviewInput` | `fileURL`、`isImage`、`resolvedDisplayName` | 鸿蒙字段过少，缺少 `mimeType`、预览 ID、UTType / 文件类型信息，无法完整对齐 iOS 路由能力 |
| 远端附件展示态 | `SparkMedicalSyncAPI.RemoteManagedFile` | `id`、`fileUuid`、`originalName`、`fileSize`、`mimeType`、`fileMd5`、`businessType`、`businessId`、`objectKey`、`storageType`、`createdAt`、`fileUrl` | `RemoteManagedFile` | `id`、`originalName`、`mimeType`、`businessType`、`businessId`、`fileMd5`、`fileSize`、`fileUuid`、`objectKey`、`storageType`、`createdAt` | 基本对齐，但鸿蒙到预览层仍要手动做 `ManagedFileRecord` 转换，缺少统一桥接入口 |
| 下载 / 缓存中间态 | `ManagedFileRecord` | `id`、`fileUuid`、`filePath`、`originalName`、`fileSize`、`mimeType`、`fileMd5`、`isPublic`、`businessType`、`businessId`、`createdAt`、`objectKey`、`storageType` | `ManagedFileRecord` | `id`、`fileUuid`、`filePath`、`originalName`、`fileSize`、`mimeType`、`fileMd5`、`businessType`、`businessId`、`objectKey`、`storageType`、`createdAt` | 字段大体一致，鸿蒙与 iOS 的差异主要在字段命名和 `isPublic` 默认值约定 |
| 保存回执 | `MedicalDocumentSaveReceipt` | `recordID`、`savedAt`、`isSuccess` | `MedicalDocumentSaveReceipt` | `recordID`、`savedAt`、`isSuccess`、`kind`、`message` | 鸿蒙回执更丰富，但与附件预览无冲突，后续应作为业务绑定结果而不是预览层状态 |
| 附件匹配摘要 | iOS 识别 / 绑定阶段内部结果 | 本地文件、远端 fileId、业务节点 | `MedicalDocumentAttachmentMatchSummary` | `kind`、`matchedLocalFileIds`、`unmatchedLocalFileIds`、`targetNodeCount` | 鸿蒙已经有匹配摘要，但没有把它统一暴露给预览层 |
| 预提交绑定载荷 | iOS 业务保存前的附件绑定结果 | 远端 fileId、businessType、businessId | `MedicalDocumentPreparedAttachmentBinding` | `kind`、`matchedLocalFileIds`、`remoteFileIds`、`businessType`、`fileIdsForSave` | 鸿蒙具备保存前绑定数据，但需要和统一预览 / 公共组件解耦 |

### 5.6 必须统一的字段映射

以下字段必须在鸿蒙侧形成一套稳定的适配规则，不允许每个页面各写各的：

- `id` / `previewId`
- `fileURL` / `sourceUri` / `filePath`
- `displayName` / `originalName`
- `mimeType`
- `businessType`
- `businessId`
- `fileUuid`
- `fileMd5`
- `objectKey`
- `storageType`
- `createdAt`
- `remoteFile`

### 5.7 建议的统一适配层

鸿蒙建议明确一个共享适配层，把本地文件、远端记录和预览输入串起来：

```text
MedicalAttachmentInput
  → MedicalAttachmentPreviewAdapter
  → FilePreviewInput
  → UnifiedFilePreview
```

这样每个业务页只需要关心“拿到什么附件”，不用关心“怎么转成可预览输入”。

## 6. iOS-HarmonyOS 功能对照矩阵

| 模块 | iOS 状态 | 鸿蒙状态 | 差异 | 优化方向 |
| --- | --- | --- | --- | --- |
| 底层统一预览 | 已实现 | 未收敛 | 鸿蒙仍是分散实现 | 新建统一预览层 |
| 列表附件预览 | 已实现 | 部分实现 | 鸿蒙可预览但入口不统一 | 收敛为公共列表组件 |
| 网格附件预览 | 已实现 | 部分实现 | 鸿蒙有卡片但逻辑分散 | 收敛为公共网格组件 |
| 附件图标入口 | 已实现 | 缺失 / 不统一 | Count / expand 入口未统一 | 补 `MedicalAttachmentIconView` |
| 本地预览输入模型 | 已实现 | 部分实现 | 本地 / 远端输入未统一 | 统一为 shared preview input |
| 页面调用层 | 已实现 | 部分实现 | 各页自建预览壳 | 逐页替换到共享层 |
| 上传页预览 | 已实现 | 部分实现 | 鸿蒙用页面内临时预览 | 替换成统一预览底层 |

## 7. 示例工程与官方文档参考结论

### 7.1 本地参考文件

- iOS 统一预览：`/Users/hua/Documents/project/Reference/LookHealthClient/SparkClient/SparkClient/Projects/Core/UI/FilePreview/View+UnifiedFilePreview.swift`
- iOS 附件公共组件：`/Users/hua/Documents/project/Reference/LookHealthClient/SparkClient/SparkClient/Projects/Features/Home/Presentation/MedicalLists/Shared/MedicalAttachmentComponents.swift`
- 鸿蒙附件输入模型：`/Users/hua/Documents/project/Reference/LookHealthClient/SparkClientHarmonyOS/entry/src/main/ets/Projects/Features/MedicalDocumentUpload/Domain/MedicalDocumentAttachmentBindingModels.ets`
- 鸿蒙附件绑定桥：`/Users/hua/Documents/project/Reference/LookHealthClient/SparkClientHarmonyOS/entry/src/main/ets/Projects/Features/Home/Presentation/MedicalLists/Shared/MedicalAttachmentBindingBridge.ets`
- 鸿蒙方块预览：`/Users/hua/Documents/project/Reference/LookHealthClient/SparkClientHarmonyOS/entry/src/main/ets/Projects/Features/Home/Presentation/MedicalLists/MedicineBox/MedicalDocumentFilePreviewSquareCard.ets`
- 鸿蒙临时预览：`/Users/hua/Documents/project/Reference/LookHealthClient/SparkClientHarmonyOS/entry/src/main/ets/Projects/Features/MedicalDocumentUpload/Presentation/MedicalDocumentUploadPickingView.ets`

### 7.2 可复用结论

1. iOS 的统一预览是“系统弹层 + 统一输入协议”。
2. iOS 的附件公共组件把列表、网格、图标和下载预览都收在一层。
3. 鸿蒙已经有方块预览和绑定桥，但还缺统一底层和统一调用协议。

### 7.3 不可直接照搬的内容

1. iOS 的 `sheet` 扩展不能直接原样迁移。
2. iOS 的 `FilePreviewInput` 需要按 ArkTS 重新定义，但语义必须一致。
3. 不要让每个业务页都自己再造一个预览弹层。

### 7.4 鸿蒙关键代码示例

#### 7.4.1 本地附件模型

```ts
export class MedicalAttachmentInput {
  previewId: string = '';
  sourceUri: string = '';
  originalName: string = '';
  mimeType: string = 'application/octet-stream';
}
```

#### 7.4.2 文件预览卡

```ts
@Component
export struct MedicalDocumentFilePreviewSquareCard {
  @Prop item: FilePreviewInput = new FilePreviewInput();
  @Prop showDelete: boolean = true;
}
```

#### 7.4.3 业务预览网格

```ts
@Component
export struct MedicalAttachmentGridPreview {
  @Prop attachments: RemoteManagedFile[] = [];
  @Prop fileTransferService?: FileTransferService;
}
```

#### 7.4.4 页面内临时预览

```ts
@Builder
private UnifiedFilePreviewBuilder() {
  Column() {
    if (this.previewIndex >= 0 && this.previewIndex < this.viewModel.selectedFiles.length) {
      this.PreviewPage(this.viewModel.selectedFiles[this.previewIndex])
    }
  }
}
```

这段代码说明鸿蒙当前已经有预览能力，但它是页面内临时实现，应该被统一预览层替换。

### 7.5 关键技术方案的落地代码示例

#### 7.5.1 iOS 本地文件直接进入统一预览

```swift
struct MedicalUploadLocalFile: Identifiable, Equatable, Sendable {
    let id: UUID
    let url: URL
    let displayName: String
    let mimeType: String?
    let ocrText: String?
    let remoteFile: ManagedFileRecord?

    var previewInput: FilePreviewInput {
        FilePreviewInput(
            id: id,
            fileURL: url,
            displayName: displayName,
            mimeType: mimeType,
            utTypeIdentifier: nil
        )
    }
}
```

这就是 iOS 的关键设计点：**本地文件先被归一成 `FilePreviewInput`，再交给统一预览底层**。

#### 7.5.2 iOS 统一预览入口

```swift
extension View {
    func unifiedFilePreview(
        isPresented: Binding<Bool>,
        inputs: [FilePreviewInput],
        startIndex: Int = 0,
        onDismiss: (() -> Void)? = nil
    ) -> some View {
        sheet(isPresented: isPresented, onDismiss: onDismiss) {
            UnifiedFilePreview(inputs: inputs, startIndex: startIndex) {
                isPresented.wrappedValue = false
            }
        }
    }
}
```

这段代码说明 iOS 的统一预览不是页面私有逻辑，而是一个可复用的 `View` 扩展。

#### 7.5.3 鸿蒙建议补齐的统一适配器

下面这段是**建议新增**的共享适配器示意，目标是把本地文件和远端文件统一成同一个预览输入。

```ts
import { ManagedFileRecord } from '../../../../../../Core/FileStorage/FileStorageModels';
import { MedicalAttachmentInput } from '../../Home/Presentation/MedicalLists/MedicalDocumentAttachmentUploader';
import { FilePreviewInput } from '../../Home/Presentation/MedicalLists/MedicineBox/MedicalDocumentFilePreviewSquareCard';

export class MedicalAttachmentPreviewAdapter {
  static fromLocalFile(file: MedicalAttachmentInput): FilePreviewInput {
    const input = new FilePreviewInput();
    input.fileURL = file.sourceUri;
    input.isImage = (file.mimeType ?? '').indexOf('image') >= 0;
    input.resolvedDisplayName = file.originalName.length > 0 ? file.originalName : '医疗附件';
    return input;
  }

  static fromRemoteRecord(record: ManagedFileRecord): FilePreviewInput {
    const input = new FilePreviewInput();
    input.fileURL = record.filePath;
    input.isImage = (record.mimeType ?? '').indexOf('image') >= 0;
    input.resolvedDisplayName = record.originalName.length > 0 ? record.originalName : '医疗附件';
    return input;
  }
}
```

这段是鸿蒙侧最关键的补齐点。它把“本地待上传附件”和“远端业务附件”统一成同一种预览输入。

#### 7.5.4 鸿蒙业务页应当只依赖公共预览组件

```ts
MedicalAttachmentGridPreview({
  attachments: this.viewModel.attachments,
  fileTransferService: this.viewModel.fileTransferService,
  isEditing: this.isEditing,
  onDeleted: (fileID: number) => {
    this.viewModel.removeAttachment(fileID);
  },
  onFileUploaded: (record: ManagedFileRecord) => {
    this.viewModel.appendUploadedFile(record);
  }
})
```

业务页不应该自己再写“下载 + 预览 + 删除 + 上传”的组合逻辑，只保留业务回调。

#### 7.5.5 鸿蒙页面内临时预览的替换目标

下面这段也是**目标实现示意**，用于替换当前页内的临时预览壳。

```ts
@Builder
private UnifiedFilePreviewBuilder() {
  UnifiedFilePreview({
    inputs: this.previewInputs,
    startIndex: this.previewIndex,
    onClose: () => {
      this.showPreviewSheet = false;
    }
  })
}
```

这段代码是建议的替换方向。等统一预览层落地后，`MedicalDocumentUploadPickingView` 里现在的 `PreviewPage(file)` 就应该退场。

#### 7.5.6 鸿蒙上传模型回填远端记录

```ts
export class MedicalAttachmentInput {
  previewId: string = '';
  sourceUri: string = '';
  originalName: string = '';
  mimeType: string = 'application/octet-stream';
  ocrText: string = '';
  remoteFile?: ManagedFileRecord;

  withRemoteFile(record: ManagedFileRecord): MedicalAttachmentInput {
    const copy = new MedicalAttachmentInput();
    copy.previewId = this.previewId;
    copy.sourceUri = this.sourceUri;
    copy.originalName = this.originalName;
    copy.mimeType = this.mimeType;
    copy.ocrText = this.ocrText;
    copy.remoteFile = record;
    return copy;
  }
}
```

这说明鸿蒙已经具备“上传后回填远端文件”的数据基础，下一步要做的是把这份数据进入统一预览和统一业务绑定链路。

## 8. 实施拆分与验收

### 8.1 实施拆分

1. 新建统一附件预览底层。
2. 把 `MedicalAttachmentListView`、`MedicalAttachmentGridPreview`、`MedicalAttachmentIconView` 收敛成一组公共组件。
3. 统一 `FilePreviewInput` / 本地附件 / 远端附件的预览映射。
4. 替换页面内临时预览壳。
5. 把 Home、上传、药箱、聊天等页面逐步切到共享层。

### 8.2 验收标准

必须同时满足以下条件：

1. 所有附件预览都走统一预览底层。
2. 列表 / 网格 / 图标复用同一套公共组件。
3. 图片、PDF、其他文件的查看行为一致。
4. 页面不再自行实现独立预览弹层。
5. 统一预览支持本地文件和远端文件。

### 8.3 体验验收

- 点击附件可以统一预览。
- 图文混排附件保持一致的打开方式。
- 列表和网格都能进入同一个预览体验。
- 删除 / 上传 / 绑定行为不被预览层破坏。

## 9. 风险与待确认项

### 9.1 主要风险

1. 如果继续保留页面内临时预览壳，会导致后续每个页面都重复实现。
2. 如果本地文件和远端文件没有统一预览输入协议，会造成预览入口越来越多。
3. 如果只改 UI、不改数据模型，业务附件绑定会继续分叉。

### 9.2 待确认项

1. 统一预览底层是否放入 `Projects/Core/UI/FilePreview/`。
2. 业务公共组件是否继续放在 `Home/Presentation/MedicalLists/Shared/`。
3. 是否需要把 `MedicalDocumentFilePreviewSquareCard` 提升为所有业务共享的方块预览卡。
4. 各页面的旧预览实现是否允许在新层可用后直接清理。

### 9.3 结论性建议

如果目标是“**鸿蒙附件预览完全对齐 iOS 三层结构**”，建议先做统一预览底层，再收敛业务公共组件，最后替换页面调用。不要继续在每个页面里做局部预览，这会让架构越来越难维护。
