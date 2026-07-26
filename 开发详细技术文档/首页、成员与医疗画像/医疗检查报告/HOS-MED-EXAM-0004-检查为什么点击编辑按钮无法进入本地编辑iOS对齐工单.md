# HOS-MED-EXAM-0004 检查为什么点击编辑按钮无法进入本地编辑 iOS 对齐工单

> 状态：待排查  
> 范围：仅排查“检查报告详情页点击编辑按钮无法进入本地编辑页”问题，不改动服务器契约，不改动 iOS 代码。  
> 审计时间：2026-07-25  
> 参考端：`/Users/hua/Documents/project/Reference/LookHealthClient/SparkClient/`  
> 目标端：`/Users/hua/Documents/project/Reference/LookHealthClient/SparkClientHarmonyOS/`  
> 关联前置工单：
> - `HOS-MED-EXAM-0001-医疗检查报告本地编辑iOS对齐工单.md`
> - `HOS-MED-EXAM-0003-检验报告单详情iOS对齐工单.md`
> - `HOS-MED-EXAM-0002-检验单项详情iOS对齐工单.md`

## 1. 对标范围与结论

### 1.1 问题定义

用户反馈的现象是：

- 在鸿蒙检查报告详情页点击“编辑”
- 但没有进入检查报告本地编辑页

这个问题不是“编辑页不存在”，而是“编辑入口虽然存在，但点击后没有成功打开编辑流程”。

### 1.2 已核验的代码事实

鸿蒙检查报告详情宿主页里，编辑入口确实已经存在：

- `ExaminationReportDetailPage.ets` 的 `toolbarMenuItems()` 中有“编辑”
- 点击后会执行 `this.showEditSheet = true`
- 页面底部通过 `bindSheet(this.showEditSheet, this.editSheetContent, ...)` 承接编辑弹层
- `editSheetContent()` 会根据 `detailMode` 进入：
  - `ExamReportFormModeKind.LOCAL_EDIT`
  - 或 `ExamReportFormModeKind.SERVER_EDIT`

所以问题不在“没写编辑按钮”，而在“编辑按钮被条件挡住”或“弹层承接链路有问题”。

### 1.3 当前最可疑的两个点

1. **菜单被禁用**
   - `toolbarMenuDisabled()` 返回 `busy || isLoadingDetails || isPreparingShare`
   - 只要详情还在加载，菜单就可能无法触发

2. **编辑表单模式与当前详情模式不一致**
   - `detailMode === SERVER` 时走 `SERVER_EDIT`
   - `detailMode === LOCAL_DRAFT` 时走 `LOCAL_EDIT`
   - 如果上游传入模式不对，用户点击编辑后可能进入了错误分支，或者感觉“没有进入”

### 1.4 结论

当前鸿蒙的编辑问题，优先判断为：

1. 编辑入口是存在的
2. 但它被菜单禁用态和/或编辑模式分支影响
3. 需要继续检查 `toolbarMenuDisabled()`、`showEditSheet`、`bindSheet()`、`ExamReportFormView` 的模式接入

## 2. 华为端目录设计

### 2.1 iOS 端真实目录结构

```text
SparkClient/SparkClient/Projects/Features/Home/Presentation/MedicalLists/ExaminationReports/
├── ExaminationReportDetailPage.swift
├── ExaminationReportSummaryDetailPage.swift
├── ExaminationReportCategoryDetailPage.swift
└── ExaminationReportDetailSupport.swift

SparkClient/SparkClient/Projects/Features/MedicalRecord/Presentation/NewRecord/Forms/
├── ExamReportFormView.swift
├── AddLabItemSheet.swift
├── AddImagingReportItemSheet.swift
└── AddPathologyReportItemSheet.swift
```

### 2.2 鸿蒙端当前目录结构

```text
SparkClientHarmonyOS/entry/src/main/ets/Projects/Features/Home/Presentation/MedicalLists/ExaminationReports/
├── ExaminationReportDetailPage.ets
├── ExaminationReportSummaryDetailPage.ets
├── ExaminationReportCategoryDetailPage.ets
└── ExaminationReportDetailSupport.ets

SparkClientHarmonyOS/entry/src/main/ets/Projects/Features/MedicalRecord/Presentation/NewRecord/Forms/
├── ExamReportFormView.ets
├── AddLabItemSheet.ets
├── AddImagingReportItemSheet.ets
└── AddPathologyReportItemSheet.ets
```

### 2.3 需要重点检查的旧代码位置

1. `SparkClientHarmonyOS/entry/src/main/ets/App/Navigation/AppRootNavDestination.ets`
2. `SparkClientHarmonyOS/entry/src/main/ets/Projects/Features/Home/Presentation/MedicalLists/ExaminationReports/ExaminationReportDetailPage.ets`
3. `SparkClientHarmonyOS/entry/src/main/ets/Projects/Features/MedicalRecord/Presentation/NewRecord/Forms/ExamReportFormView.ets`
4. `SparkClientHarmonyOS/entry/src/main/ets/Projects/Features/MedicalRecord/Presentation/NewRecord/Forms/ExamReportFormMode.ets`

### 2.4 目录清理原则

1. 只保留一条正式详情链路。
2. 编辑入口只能指向 `ExaminationReportDetailPage.ets` 内的 `bindSheet` 逻辑。
3. 不要在旧简化页或其他入口重复挂编辑逻辑。

## 3. 分层职责与请求链路

### 3.1 当前鸿蒙编辑链路

```text
主页检查详情
  → 点击 ⋯ 菜单
  → 选择“编辑”
  → 设置 showEditSheet = true
  → 触发 bindSheet
  → 打开 ExamReportFormView
  → 根据 detailMode 进入 LOCAL_EDIT 或 SERVER_EDIT
```

### 3.2 当前最容易出问题的环节

1. `toolbarMenuDisabled()` 让菜单无法点击
2. `showEditSheet` 没有真正触发 sheet 展开
3. `editSheetContent()` 里的模式分支没有进入预期表单
4. `ExamReportFormView` 构造成功，但页面内部缺少正确的初始草稿或 mutationService

### 3.3 需要对齐的 iOS 行为

iOS 的编辑按钮是直接能打开 sheet 的，不需要用户先切换别的页面，也不依赖选图页状态。  
因此鸿蒙也应该保证：

- 详情页编辑入口始终可达
- 进入后默认能看到表单
- localEdit / serverEdit 与来源模式一致

## 4. 核心关键技术与实现方案

### 4.1 鸿蒙关键代码示例一：菜单禁用条件

```ts
private toolbarMenuDisabled(): boolean {
  return this.busy || this.isLoadingDetails || this.isPreparingShare;
}
```

这段代码是当前最可疑的阻断点之一。  
只要 `isLoadingDetails` 长时间为 `true`，编辑菜单就可能无法触发。

### 4.2 鸿蒙关键代码示例二：编辑入口

```ts
items.push(new ExaminationReportDetailMenuItem('编辑', (): void => {
  if (!this.toolbarMenuDisabled()) {
    this.showEditSheet = true;
  }
}));
```

这说明编辑按钮不是直接打开表单，而是先受菜单禁用条件保护。  
如果用户看到“点了没反应”，很可能是这层条件把事件吞掉了。

### 4.3 鸿蒙关键代码示例三：编辑弹层承接

```ts
.bindSheet(this.showEditSheet, this.editSheetContent, {
  height: SheetSize.LARGE,
  dragBar: true,
  showClose: true,
  onDisappear: () => {
    this.showEditSheet = false;
  }
})
```

这说明 sheet 机制本身已经存在。  
如果点编辑没有进入，下一步要确认：

1. `showEditSheet` 有没有真正变成 `true`
2. `bindSheet` 是否因为页面状态或 build 结构没有刷新
3. `editSheetContent()` 是否返回了可渲染内容

### 4.4 鸿蒙关键代码示例四：编辑表单分支

```ts
private editSheetContent() {
  if (this.detailMode === ExaminationReportDetailMode.LOCAL_DRAFT) {
    ExamReportFormView({
      modeKind: ExamReportFormModeKind.LOCAL_EDIT,
      existingDraft: this.currentSourceDraft(),
      onLocalSubmit: (draft: MedicalReportRecognitionDraft) => {
        this.applyLocalDraftReport(draft);
        this.showEditSheet = false;
      },
      onCancel: () => {
        this.showEditSheet = false;
      }
    })
  } else {
    ExamReportFormView({
      modeKind: ExamReportFormModeKind.SERVER_EDIT,
      existingReport: this.report,
      mutationService: this.mutationService,
      onServerSaved: (draft: MedicalReportRecognitionDraft) => {
        this.applyServerDraftSaved(draft);
        this.showEditSheet = false;
      },
      onCancel: () => {
        this.showEditSheet = false;
      }
    })
  }
}
```

这说明编辑页实际是有分支的。  
如果按钮进入不了，重点不是表单不存在，而是上游触发没成功，或者模式分支没走到预期页面。

### 4.5 鸿蒙关键代码示例五：表单模式定义

```ts
export enum ExamReportFormModeKind {
  CREATE = 'create',
  SERVER_EDIT = 'serverEdit',
  LOCAL_EDIT = 'localEdit'
}
```

模式已经齐了，所以问题更像是“入口”而不是“模型”。

### 4.6 鸿蒙关键代码示例六：表单构建

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

这说明结果页正文也在，编辑按钮无法进入通常不是因为结果页完全没有实现，而是入口 / 状态 / 分支没对上。

### 4.7 需要补的公共组件或支持层

如果最终确认是状态或模式问题，建议补充以下支持能力：

1. 编辑入口点击日志
2. `showEditSheet` 变化日志
3. `detailMode` 打印日志
4. `ExamReportFormView` 的 mode/seed 诊断日志

这几个点能快速判断问题出在：

- 菜单没触发
- sheet 没弹出
- 表单没渲染
- 表单渲染了但看起来像没进入

## 5. 接口契约与数据模型

### 5.1 当前编辑页依赖的数据模型

| 模型 | 作用 | 关键字段 |
| --- | --- | --- |
| `RemoteExaminationReportWithAttachments` | 当前检查报告 | `id`、`member`、`category`、`itemName`、`medExamDetails` |
| `MedicalReportRecognitionDraft` | 本地编辑草稿 | `category`、`title`、`hospital`、`doctor`、`content`、`date`、`details` |
| `ExaminationReportDetailMode` | 宿主页模式 | `server` / `localDraft` |
| `ExamReportFormModeKind` | 表单模式 | `create` / `serverEdit` / `localEdit` |

### 5.2 需要保持一致的语义

1. `serverEdit` 应该进入服务端更新流程
2. `localEdit` 应该进入本地草稿回调
3. `showEditSheet` 应该只负责“打开弹层”，不应该再承载业务分支

### 5.3 当前模型偏差

当前最容易偏差的是：

1. 宿主页的 `detailMode`
2. 表单的 `modeKind`
3. 草稿来源 `currentSourceDraft()`

如果这三者没有统一，点击编辑后就会出现“进了但像没进”或“完全没反应”的现象。

## 6. iOS-HarmonyOS 功能对照矩阵

| 模块 | iOS 状态 | 鸿蒙状态 | 差异 | 是否需要清理旧代码 |
| --- | --- | --- | --- | --- |
| 编辑入口 | 已实现 | 部分实现 | 入口存在但可能被禁用 | 检查是否有重复旧入口 |
| 本地编辑页 | 已实现 | 已实现 | 可能链路未打通 | 不删，实现先查清 |
| 服务端编辑页 | 已实现 | 已实现 | 可能模式没对上 | 检查 `detailMode` |
| 编辑 sheet 承接 | 已实现 | 已实现 | 可能 sheet 不弹或不刷新 | 检查 `bindSheet` |
| 草稿映射 | 已实现 | 已实现 | 数据源基本齐 | 不需要删，需排查 |
| 旧简化详情页 | 不作为正式入口 | 可能残留 | 易造成误导 | 若被引用应清除 |

## 7. 示例工程与官方文档参考结论

### 7.1 本地参考文件

- 鸿蒙宿主页：`/Users/hua/Documents/project/Reference/LookHealthClient/SparkClientHarmonyOS/entry/src/main/ets/Projects/Features/Home/Presentation/MedicalLists/ExaminationReports/ExaminationReportDetailPage.ets`
- 鸿蒙表单：`/Users/hua/Documents/project/Reference/LookHealthClient/SparkClientHarmonyOS/entry/src/main/ets/Projects/Features/MedicalRecord/Presentation/NewRecord/Forms/ExamReportFormView.ets`
- 鸿蒙表单模式：`/Users/hua/Documents/project/Reference/LookHealthClient/SparkClientHarmonyOS/entry/src/main/ets/Projects/Features/MedicalRecord/Presentation/NewRecord/Forms/ExamReportFormMode.ets`
- 鸿蒙路由入口：`/Users/hua/Documents/project/Reference/LookHealthClient/SparkClientHarmonyOS/entry/src/main/ets/App/Navigation/AppRootNavDestination.ets`
- iOS 对照宿主页：`/Users/hua/Documents/project/Reference/LookHealthClient/SparkClient/SparkClient/Projects/Features/Home/Presentation/MedicalLists/ExaminationReports/ExaminationReportDetailPage.swift`
- iOS 对照表单：`/Users/hua/Documents/project/Reference/LookHealthClient/SparkClient/SparkClient/Projects/Features/MedicalRecord/Presentation/NewRecord/Forms/ExamReportFormView.swift`

### 7.2 可复用结论

1. 入口已经存在，不要再从“有没有编辑页”这个方向判断。
2. 优先检查禁用态、sheet 状态和 mode 分支。
3. 需要日志而不是再堆页面。

### 7.3 不可直接照搬的内容

1. iOS 的 sheet 行为不能直接照抄。
2. iOS 的菜单响应方式不能直接推断鸿蒙一定一致。
3. 不能把“编辑按钮没反应”误解成“编辑页未实现”。

## 8. 实施拆分与验收

### 8.1 排查拆分

1. 检查编辑菜单是否处于禁用态。
2. 检查点击编辑后 `showEditSheet` 是否真的变成 `true`。
3. 检查 `bindSheet` 是否正常打开。
4. 检查 `editSheetContent()` 是否返回了正确的 `ExamReportFormView`。
5. 检查 `detailMode` 是否与当前场景一致。
6. 检查 `mutationService` / `existingDraft` / `existingReport` 是否为空导致表单不可用。

### 8.2 验收标准

必须同时满足以下条件：

1. 点击编辑菜单能打开 sheet。
2. sheet 中能看到检查报告表单。
3. `serverEdit` 场景可继续更新。
4. `localEdit` 场景可正确回传草稿。
5. 旧简化实现不再干扰入口。

### 8.3 体验验收

- 点击编辑后，能明确看到表单页。
- 不会出现“点了没反应”。
- localDraft 和 serverEdit 均能正确进入。
- 关闭 sheet 后能回到详情页。

## 9. 风险与待确认项

### 9.1 主要风险

1. 如果只看页面结构，不看菜单禁用态，问题会一直误判。
2. 如果 `detailMode` 取值不对，表单会进错分支。
3. 如果旧简化入口还在，用户可能点到的是错误页面。

### 9.2 待确认项

1. 这个问题是只发生在 server 模式，还是 localDraft 模式也会发生。
2. 点击编辑后是完全无反应，还是 sheet 打开后立刻关闭。
3. 当前是否还存在旧的简化详情入口被路由到。
4. 是否需要把 `toolbarMenuDisabled()` 的判断从 `isLoadingDetails` 中解耦。

### 9.3 结论性建议

如果目标是“**修复点击编辑按钮无法进入本地编辑页，同时继续对齐 iOS**”，建议先在宿主页补诊断日志，再确认菜单禁用态和 sheet 承接是否正常。不要急着删页面，先把触发链路查清楚，再决定哪些旧代码需要清理。

