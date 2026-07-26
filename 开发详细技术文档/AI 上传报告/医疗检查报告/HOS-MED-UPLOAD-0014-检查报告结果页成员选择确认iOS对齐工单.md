# HOS-MED-UPLOAD-0014 检查报告结果页成员选择确认 iOS 对齐工单

> 状态：部分实现  
> 范围：仅覆盖“检查报告识别结果页里的成员选择 / 成员确认模块”与 iOS 对齐，不改动服务器契约，不改动 iOS 代码。  
> 审计时间：2026-07-25  
> 参考端：`/Users/hua/Documents/project/Reference/LookHealthClient/SparkClient/`  
> 目标端：`/Users/hua/Documents/project/Reference/LookHealthClient/SparkClientHarmonyOS/`  
> 关联结论：鸿蒙已经具备成员数据源、成员切换能力和结果页成员展示条，但“结果页内可切换成员确认卡片”尚未实现，当前切换只发生在识别前的选图页。

## 1. 对标范围与结论

### 1.1 本工单要解决的核心问题

本工单只讨论一个很明确的点：

- iOS：检查报告识别结果页内，可以直接切换保存归属成员
- 鸿蒙：检查报告识别结果页内只展示成员，真正可切换成员的入口在识别前的选图页

这意味着两端的“成员归属确认”发生位置不一致，页面职责也不一致。

### 1.2 iOS 端真实实现

iOS 在结果页内完成完整的成员确认和切换，核心链路如下：

1. `MedicalReportRecognitionResultContentView.swift` 持有 `@State private var selectedMemberID`
2. 页面初始化时，从识别 envelope 取初始值 `output.envelope.memberID`
3. 正文里渲染 `MedicalReportMemberConfirmSectionView`
4. 该区块内部通过 `MemberProfileBindingMenu` 打开成员列表
5. 选择成员后回调 `onSelectMember`
6. 回调里会更新 `selectedMemberID`
7. 同时调用 `viewModel.updateResultMemberID(memberID)`
8. 最终把结果写回 `typedOutput.envelope.memberID`

### 1.3 鸿蒙端真实实现

鸿蒙当前的成员能力分布在两处：

1. 识别前选图页：可以切换成员
2. 识别结果页：只展示当前成员，不提供结果页内切换

也就是说，鸿蒙底层已有成员能力，但**没有把它放到结果页的成员确认模块里**。

### 1.4 结论

当前鸿蒙处于“成员能力已存在，但结果页成员确认模块缺失”的状态。  
如果要达到“目录结构一致、数据模型一致、页面模块一致、流程一致，且公共组件补齐”，就不能把选图页的切换能力算作结果页已对齐。

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
├── MedicalDocumentTypedResultScaffoldView.ets
├── MedicalDocumentUploadHostView.ets
└── ResultPages/
    ├── MedicalReportRecognitionResultView.ets
    └── MedicalReportRecognitionResult/
        ├── MedicalReportRecognitionResultContentView.ets
        ├── MedicalReportResultSections.ets
        └── MedicalReportResultSupport.ets
```

### 2.3 鸿蒙端目标目录结构

如果要求“结果页成员选择/确认”真正对齐 iOS，建议补齐以下同职责文件：

```text
SparkClientHarmonyOS/entry/src/main/ets/Projects/Features/MedicalDocumentUpload/Presentation/ResultPages/MedicalReportRecognitionResult/
├── MedicalReportMemberConfirmSectionView.ets    # 目标补充：成员确认 + 切换
├── MedicalReportResultSections.ets              # 保留：统计 / 卡片 / 其他区块
├── MedicalReportResultSupport.ets               # 保留：分类、统计、文案
└── MedicalReportMemberBindingMenu.ets           # 目标补充：结果页内成员选择器
```

### 2.4 目录设计原则

1. 结果页内的“成员确认”必须单独成区块，不能继续依赖选图页。
2. 结果页成员选择器必须是公共组件，不应写死在某个页面内部。
3. 选图页的成员选择能力可以继续保留，但不能替代结果页确认。

## 3. 分层职责与请求链路

### 3.1 iOS 的职责拆分

| 层级 | iOS 文件 | 职责 |
| --- | --- | --- |
| 正文状态 | `MedicalReportRecognitionResultContentView.swift` | 维护 `selectedMemberID`、报告 drafts、附件、校验、保存 |
| 成员确认区块 | `MedicalReportMemberConfirmSectionView` | 成员标题、下拉选择、统计概览 |
| 成员选择器 | `MemberProfileBindingMenu` | 从成员上下文中渲染可选成员列表 |
| 状态回写 | `viewModel.updateResultMemberID(_:)` | 更新 `typedOutput.envelope.memberID` |

### 3.2 鸿蒙当前职责拆分

| 层级 | 鸿蒙文件 | 当前状态 |
| --- | --- | --- |
| 正文状态 | `MedicalReportRecognitionResultContentView.ets` | 已有，但结果页内没有成员切换状态 |
| 成员展示条 | `MedicalDocumentResultMemberBar` | 已有，只读展示 |
| 成员选择器 | 选图页 `MedicalDocumentUploadPickingView.ets` | 已有，可切换，但位置不对 |
| 状态回写 | `MedicalDocumentUploadViewModel.selectMember()` | 已有，作用在选图阶段 |

### 3.3 目标请求链路

```text
识别结果页打开
  → 读取 envelope.memberID 作为初始成员
  → 结果页内显示成员确认卡片
  → 点击成员区域展开成员列表
  → 选择新的成员
  → 同步更新 ViewModel
  → 同步更新 typedOutput.envelope.memberID
  → 保存时使用新的成员归属
```

### 3.4 当前偏差

鸿蒙当前的流程是：

```text
选图页切换成员
  → 识别流程使用该成员
  → 结果页只读显示成员
```

这与 iOS 的“结果页内再确认一次成员归属”不同。  
如果目标是对齐 iOS，就必须补结果页内的可切换确认模块。

## 4. 核心关键技术与实现方案

### 4.1 iOS 关键代码示例

#### 4.1.1 结果页状态绑定

```swift
@State private var selectedMemberID: Int?

init(viewModel: MedicalDocumentUploadViewModel) {
    self.viewModel = viewModel
    let output = viewModel.typedOutput!
    self.output = output
    _selectedMemberID = State(initialValue: output.envelope.memberID)
}
```

这说明 iOS 把“结果页内的成员归属”当成结果页自身状态，而不是前一个页面的附属状态。

#### 4.1.2 结果页内的成员确认区块

```swift
MedicalReportMemberConfirmSectionView(
    memberContextStore: viewModel.memberContextStoreForLocalForms,
    selectedMemberID: selectedMemberID,
    reports: reports,
    onSelectMember: { memberID in
        selectedMemberID = memberID
        viewModel.updateResultMemberID(memberID)
    }
)
```

这段代码是本工单最关键的对标点。它说明：

1. 成员选择发生在结果页
2. 成员切换会即时回写 viewModel
3. 结果页的成员归属不是只读展示

#### 4.1.3 通用成员选择器

```swift
MemberProfileBindingMenu(
    memberContextStore: memberContextStore,
    selectedMemberID: selectedMemberID,
    onSelect: onSelectMember
) {
    HStack {
        Image(systemName: "person.crop.circle")
        Text(selectedMemberName)
        // ...
    }
}
```

这说明 iOS 的“成员确认”不是一个单纯文本条，而是一个可交互的成员绑定菜单。

#### 4.1.4 状态写回

```swift
func updateResultMemberID(_ memberID: Int?) {
    guard let output = typedOutput else { return }
    typedOutput = MedicalDocumentTypedExtractionOutput(
        envelope: MedicalDocumentRecognitionEnvelope(
            memberID: memberID,
            sourceFiles: output.envelope.sourceFiles,
            // ...
        ),
        typedResult: output.typedResult,
        // ...
    )
    selectedMemberName = memberID.flatMap { id in
        memberContextStore.context.members.first(where: { $0.id == id })?.name
    }
}
```

这说明 iOS 的成员切换不是 UI 假象，而是会真正改写结果数据。

### 4.2 鸿蒙关键代码示例

#### 4.2.1 结果页当前只读成员条

```ts
MedicalDocumentResultMemberBar({
  memberName: this.viewModel.selectedMemberName,
  memberId: this.viewModel.selectedMemberID,
  kindLabel: this.kindLabel
})
```

这说明鸿蒙结果页已经有成员展示，但没有任何成员切换交互。

#### 4.2.2 正文里没有成员确认区块

```ts
Column({ space: 14 }) {
  MedicalReportStatsSectionView({ viewModel: this.viewModel })
  MedicalReportCardsSectionView({ viewModel: this.viewModel })
  this.SaveReceiptSection()
}
```

这说明鸿蒙当前检查报告识别结果正文里，确实没有 iOS 同名的成员确认模块。

#### 4.2.3 选图页里才有成员切换

```ts
@Builder
private MemberCard() {
  Row() {
    // ...
    Text(this.showMemberChoices ? '收起⌃' : '选择成员›')
  }
  .onClick(() => {
    this.showMemberChoices = !this.showMemberChoices;
    this.showKindChoices = false;
  })

  if (this.showMemberChoices) {
    Column() {
      ForEach(this.viewModel.members(), (member: Member) => {
        Row() {
          Text(member.name)
          if (member.id === this.viewModel.selectedMemberID) {
            Text('✓')
          }
        }
        .onClick(() => this.selectMember(member.id))
      })
    }
  }
}
```

这段代码说明鸿蒙的成员选择器已经存在，但位置在选图页，不在识别结果页。

#### 4.2.4 选图页切换成员的 ViewModel 入口

```ts
async selectMember(memberID: number): Promise<void> {
  await this.memberContextStore.select(memberID);
  this.syncMemberContext();
  this.clearPresentedError(false);
  this.notifyChanged();
}
```

这说明鸿蒙已经具备成员切换能力，但作用域是识别前阶段。

### 4.3 需要补充的公共组件

如果要对齐 iOS，鸿蒙建议新增或扩展以下公共组件：

1. `MedicalReportMemberConfirmSectionView`
2. `MedicalReportMemberBindingMenu`
3. `MedicalReportSelectedMemberRow`
4. `MedicalReportMemberSummaryChip`
5. `MedicalDocumentUploadViewModel.updateResultMemberID()`

其中最关键的是：

- 结果页要有自己的成员确认卡片
- 成员卡片要能展开成员列表
- 选择成员后必须回写结果页 state 和 typedOutput

## 5. 接口契约与数据模型

### 5.1 iOS 端关键数据模型

| 模型 | 作用 | 关键字段 |
| --- | --- | --- |
| `MedicalDocumentTypedExtractionOutput` | 识别结果总载体 | `envelope.memberID`、`typedResult` |
| `MedicalReportRecognitionDraft` | 检查报告草稿 | `category`、`title`、`details` |
| `MemberContextStore` | 成员上下文 | `context.members`、选中成员 |

### 5.2 鸿蒙端关键数据模型

| 模型 | 作用 | 关键字段 |
| --- | --- | --- |
| `MemberContextStore` | 成员上下文 | `context.members`、`context.selectedMemberID` |
| `MedicalDocumentUploadViewModel` | 上传与识别编排 | `selectedMemberID`、`selectedMemberName` |
| `MedicalDocumentTypedExtractionOutput` | typed 输出 | `envelope.memberID` |

### 5.3 需要一致的字段语义

以下字段必须保持一致：

- 当前成员
- 选中成员 ID
- 成员展示名
- 识别结果归属成员
- 保存归属成员

### 5.4 当前模型偏差

鸿蒙当前的模型能力是够的，但“结果页状态持有者”不一致：

- iOS：结果页自己持有 `selectedMemberID`
- 鸿蒙：结果页只读 viewModel 的 `selectedMemberID`

这会导致鸿蒙的结果页很难提供和 iOS 相同的切换体验。

## 6. iOS-HarmonyOS 功能对照矩阵

| 模块 | iOS 状态 | 鸿蒙状态 | 差异 | 优化方向 |
| --- | --- | --- | --- | --- |
| 结果页内成员确认 | 已实现 | 未实现 | 鸿蒙只展示不切换 | 新建结果页成员确认卡 |
| 结果页成员选择器 | 已实现 | 未实现 | 缺 `MemberProfileBindingMenu` 等价物 | 补可交互成员菜单 |
| 初始成员来源 | envelope.memberID | typed 输出 / ViewModel | 基本一致 | 统一结果页初始化逻辑 |
| 切换后写回结果 | 已实现 | 未实现 | 缺 `updateResultMemberID()` | 补写回方法 |
| 选图页成员切换 | 已实现 | 已实现 | 位置不同 | 保留但不替代结果页 |
| 结果页成员展示条 | 已实现 | 已实现 | 仅展示 | 增加可交互确认区 |
| 成员上下文存储 | 已实现 | 已实现 | 数据源一致 | 复用 `MemberContextStore` |

## 7. 示例工程与官方文档参考结论

### 7.1 本地参考文件

- iOS 结果页正文：`/Users/hua/Documents/project/Reference/LookHealthClient/SparkClient/SparkClient/Projects/Features/MedicalDocumentUpload/Presentation/ResultPages/MedicalReportRecognitionResult/MedicalReportRecognitionResultContentView.swift`
- iOS 成员确认区块：`/Users/hua/Documents/project/Reference/LookHealthClient/SparkClient/SparkClient/Projects/Features/MedicalDocumentUpload/Presentation/ResultPages/MedicalReportRecognitionResult/MedicalReportResultSections.swift`
- iOS 成员上下文与写回：`/Users/hua/Documents/project/Reference/LookHealthClient/SparkClient/SparkClient/Projects/Features/MedicalDocumentUpload/Presentation/MedicalDocumentUploadViewModel.swift`
- 鸿蒙结果页正文：`/Users/hua/Documents/project/Reference/LookHealthClient/SparkClientHarmonyOS/entry/src/main/ets/Projects/Features/MedicalDocumentUpload/Presentation/ResultPages/MedicalReportRecognitionResult/MedicalReportRecognitionResultContentView.ets`
- 鸿蒙结果页成员条：`/Users/hua/Documents/project/Reference/LookHealthClient/SparkClientHarmonyOS/entry/src/main/ets/Projects/Features/MedicalDocumentUpload/Presentation/ResultPages/MedicalDocumentTypedResultScaffoldView.ets`
- 鸿蒙选图页成员切换：`/Users/hua/Documents/project/Reference/LookHealthClient/SparkClientHarmonyOS/entry/src/main/ets/Projects/Features/MedicalDocumentUpload/Presentation/MedicalDocumentUploadPickingView.ets`
- 鸿蒙 ViewModel 成员切换：`/Users/hua/Documents/project/Reference/LookHealthClient/SparkClientHarmonyOS/entry/src/main/ets/Projects/Features/MedicalDocumentUpload/Presentation/MedicalDocumentUploadViewModel.ets`

### 7.2 可复用结论

1. 鸿蒙已具备成员上下文与成员切换能力。
2. 鸿蒙缺少的不是成员数据，而是结果页内的成员确认组件。
3. 结果页成员确认需要新增一个可交互菜单，不应继续依赖选图页。

### 7.3 不可直接照搬的内容

1. iOS 的 `Menu` / `Button` / `sheet` 写法不能直接迁移。
2. iOS 的结果页状态绑定模式需要按 ArkTS 重写。
3. 选图页的成员选择逻辑不能直接当作结果页成员确认完成。

### 7.4 鸿蒙关键代码示例

#### 7.4.1 结果页成员展示条

```ts
MedicalDocumentResultMemberBar({
  memberName: this.viewModel.selectedMemberName,
  memberId: this.viewModel.selectedMemberID,
  kindLabel: this.kindLabel
})
```

这说明结果页已有成员信息展示，但它是只读组件。

#### 7.4.2 结果页正文缺少成员确认区块

```ts
Column({ space: 14 }) {
  MedicalReportStatsSectionView({ viewModel: this.viewModel })
  MedicalReportCardsSectionView({ viewModel: this.viewModel })
  this.SaveReceiptSection()
}
```

这说明鸿蒙结果页正文还没有 iOS 同构的成员确认区块。

#### 7.4.3 选图页成员选择

```ts
if (this.showMemberChoices) {
  Column() {
    ForEach(this.viewModel.members(), (member: Member) => {
      Row() {
        Text(member.name)
      }
      .onClick(() => this.selectMember(member.id))
    })
  }
}
```

这说明成员选择能力已存在，但位置偏前，不满足结果页对齐要求。

#### 7.4.4 ViewModel 切换成员

```ts
async selectMember(memberID: number): Promise<void> {
  await this.memberContextStore.select(memberID);
  this.syncMemberContext();
  this.clearPresentedError(false);
  this.notifyChanged();
}
```

这说明鸿蒙只需要补一个结果页内的写回入口，就可以把已有能力接过来。

## 8. 实施拆分与验收

### 8.1 实施拆分

1. 新建结果页成员确认区块。
2. 新建结果页成员绑定菜单。
3. 把结果页成员条从只读展示升级为可交互确认。
4. 将成员切换回写到 ViewModel 的 typed 输出。
5. 保留选图页成员切换，但不要把它当成结果页替代方案。

### 8.2 验收标准

必须同时满足以下条件，才算对齐完成：

1. 结果页中能看到当前成员。
2. 结果页中能切换成员。
3. 切换后结果页状态立即更新。
4. 切换后保存归属正确写入 typedOutput。
5. 选图页成员切换仍可用，但不作为结果页唯一入口。

### 8.3 体验验收

- 打开识别结果页，可以确认当前成员。
- 点击成员区域可以展开成员列表。
- 选择其他成员后，页面展示立即变化。
- 提交保存时，归属成员与最新选择一致。

## 9. 风险与待确认项

### 9.1 主要风险

1. 只把结果页成员条做成静态文案，会继续偏离 iOS。
2. 只复用选图页成员选择器，不在结果页补交互，会让流程位置不一致。
3. 如果不补 `updateResultMemberID()`，保存归属可能仍然停留在旧成员。

### 9.2 待确认项

1. 结果页成员确认卡是否要完全复刻 iOS 的卡片结构和图标布局。
2. 结果页成员菜单是否要支持“新增成员”入口。
3. `MedicalDocumentUploadViewModel` 是否需要新增专门的结果页成员回写方法，还是复用现有选择方法后再同步 typed 输出。

### 9.3 结论性建议

如果这次的目标是“**鸿蒙检查报告结果页成员选择/确认完全对齐 iOS**”，建议单独给结果页补一个可交互成员确认卡片，不要继续依赖选图页来承担最终归属确认。

