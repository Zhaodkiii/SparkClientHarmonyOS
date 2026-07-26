# HOS-MED-EXAM-0007 ExamReportFormView 鸿蒙行级对齐与官方优化工单

> 状态：已完成  
> 完成时间：2026-07-26  
> 范围：只改动鸿蒙项目 `SparkClientHarmonyOS`，不修改 iOS、后端、后台管理端。  
> 目标端：`/Users/hua/Documents/project/Reference/LookHealthClient/SparkClientHarmonyOS/`  
> 参考端：`/Users/hua/Documents/project/Reference/LookHealthClient/SparkClient/`  
> 参考文件：
> - iOS：`/Users/hua/Documents/project/Reference/LookHealthClient/SparkClient/SparkClient/Projects/Features/MedicalRecord/Presentation/NewRecord/Forms/ExamReportFormView.swift`
> - 鸿蒙：`/Users/hua/Documents/project/Reference/LookHealthClient/SparkClientHarmonyOS/entry/src/main/ets/Projects/Features/MedicalRecord/Presentation/NewRecord/Forms/ExamReportFormView.ets`
> 关联前置工单：
> - `HOS-MED-EXAM-0001-医疗检查报告本地编辑iOS对齐工单.md`
> - `HOS-MED-EXAM-0002-检验单项详情iOS对齐工单.md`
> - `HOS-MED-EXAM-0003-检验报告单详情iOS对齐工单.md`
> - `HOS-MED-EXAM-0004-检查为什么点击编辑按钮无法进入本地编辑iOS对齐工单.md`
> - `HOS-MED-EXAM-0005-检查报告列表详情无法跳转iOS对齐工单.md`
> - `HOS-MED-EXAM-0006-检查报告头部、附件列表与卡片UI iOS对齐工单.md`

## 1. 对标范围与结论

本工单只看 `ExamReportFormView` 这一页，不延伸到列表页、详情页、上传页或后端工作流。

### 1.1 结论先行

鸿蒙端已经覆盖了 iOS 的核心业务意图：

- 新建 / 服务端编辑 / 本地编辑三种模式。
- 检验 / 影像 / 病理三种类型切换。
- 子项编辑弹层。
- 保存 / 更新 / 完成三种提交动作。

但和 iOS 相比，仍有几类关键偏差：

1. **模式建模不一样**：iOS 用 `Mode` 枚举把上下文、提交服务和回调绑定在一起，鸿蒙拆成多个 `@Prop`，可读性和约束力弱一些。
2. **日期模型不一样**：iOS 使用 `DatePicker + Date + formatter` 双轨管理日期；鸿蒙目前只有 `string date`，缺少可编辑、可校验、可回填的日期状态。
3. **编辑弹层控制不一样**：iOS 用 `sheet(item:)` 和可选 `editingItem`；鸿蒙用 `showItemSheet + editingItem` 两个状态，状态同步更脆弱。
4. **表单组件语义不一样**：iOS 使用统一的 `SparkFormCard / SparkFormTextRow / SparkFormTextAreaRow / bottom bar`，鸿蒙当前是自定义表单封装，容易丢失输入、焦点和无障碍一致性。
5. **重复内容渲染还可以更贴近官方最佳实践**：当前使用 `ForEach` 没问题，但如果子项数量增长，鸿蒙官方更推荐基于状态驱动的重复渲染方案，必要时切到 `Repeat` 或 `LazyForEach`。
6. **保存链路还缺一个 iOS 上下文**：iOS `create` 模式会携带 `medicalCaseID`，鸿蒙当前没有对应字段。

### 1.2 风险等级

| 风险 | 结论 | 说明 |
| --- | --- | --- |
| P0 | 无 | 当前没有明显会直接导致崩溃的行级问题。 |
| P1 | 有 | 日期模型和模式建模会影响后续维护和回填准确性。 |
| P2 | 有 | 弹层控制和输入封装会影响交互一致性和后续扩展。 |
| P3 | 有 | 重复渲染和日志能力是体验与可维护性优化项。 |

## 2. 行级对照

### 2.1 头部、模式与初始化

| iOS 行号 | 鸿蒙行号 | 对照结论 | 没对齐的点 | 建议 |
| --- | --- | --- | --- | --- |
| `1-34` | `1-36` | 角色一致，都是表单页本体和外部依赖注入 | iOS 用 `Mode` 枚举聚合上下文；鸿蒙拆成 `modeKind + existingReport + existingDraft + memberID + mutationService + callbacks` | 鸿蒙建议把创建/编辑上下文收拢成单个 `formContext`，减少可空属性散落。 |
| `36-90` | `38-89` | 都在做 seed / state 初始化 | iOS 在 `init` 内完成初始化，并把 `Date`、`String`、`ItemDraft` 一次性建好；鸿蒙在 `aboutToAppear()` 里重新 seed，只有字符串日期 | 鸿蒙建议保留 `aboutToAppear()` 只做轻量状态注入，同时补一个 `examDay: Date` 作为日期真值。 |
| `30-34` | `27-36` | 都有取消、保存后的回调 | iOS 额外有 `dismiss` 和 `mode` 相关约束；鸿蒙靠 `onCancel` 回调退场 | 如果当前容器已经统一管理路由，`onCancel` 可以保留；但建议把“退出”统一交给一个闭包，避免不同模式行为分散。 |

### 2.2 表单主体

| iOS 行号 | 鸿蒙行号 | 对照结论 | 没对齐的点 | 建议 |
| --- | --- | --- | --- | --- |
| `92-214` | `407-513` | 主体结构一致，都是顶部标题、表单内容、底部保存栏、子项弹层 | iOS 使用 `ScrollView + VStack + SparkFormCard`，鸿蒙使用 `Scroll + Column + 自定义表单块` | 鸿蒙若保留现状，至少要把输入封装统一成更薄的组件层，避免表单控件散落在页面里。 |
| `101-113` | `434-438` | 都支持日期输入 | iOS 用 `DatePicker` 直接绑定 `Date`；鸿蒙只显示 `string date` | 这是最重要的差异之一，建议鸿蒙补 `examDay` 并在 `onChange` 内同步 `date`。 |
| `117-123` | `439-444` | 报告标题输入一致 | iOS `SparkFormTextRow` 还承载 `keyboardVisible`；鸿蒙无键盘态联动 | 如果底部栏需要避让键盘，鸿蒙的输入组件要把 focus/keyboard 状态向上透传。 |
| `125-146` | `446-460` | 类型切换一致 | iOS 用 `Picker + allCases`；鸿蒙用三个硬编码 chip | 鸿蒙建议至少从 `ExaminationReportCategory.allCases` 驱动 chip，避免日后新增类型时漏改。 |
| `148-168` | `462-476` | 医院、医生、内容一致 | iOS 同一组输入统一在卡片内，鸿蒙虽也在卡片内，但封装层更薄，缺少统一的辅助行为 | 建议把医院、医生、内容的输入约束统一到表单组件中，尽量复用一套输入参数。 |

### 2.3 子项模块

| iOS 行号 | 鸿蒙行号 | 对照结论 | 没对齐的点 | 建议 |
| --- | --- | --- | --- | --- |
| `216-326` | `218-405` | 都有按检查类型拆分的子模块 | iOS 用 `@ViewBuilder` 把模块组织成更清晰的树；鸿蒙用 `@Builder` + 条件分发，结构上可以接受，但逻辑密度偏高 | 建议把“模块选择”和“模块内容”继续拆薄，避免 `examTypeModule()` 变成大分发器。 |
| `230-255` | `296-331` | 检验模块都有默认一级/二级分类和“添加检验项目” | iOS 用 `SparkLabExamCategoryCascadeRow` 处理级联和键盘；鸿蒙用两个普通文本框 | 鸿蒙应把级联输入包装成一个专用组件，否则默认分类和子项回填逻辑会越来越难维护。 |
| `273-309` | `315-359` | 空态和子项列表都存在 | iOS 空态语义更具体，区分检验 / 影像 / 病理；鸿蒙空态文案偏通用 | 建议鸿蒙按类型拆空态文案和图标，至少让影像和病理有不同的提示。 |
| `311-326` | `323-355` | 列表渲染一致，都是点击子项进入编辑 | iOS `ForEach(items)` 直接绑定 `editingItem = item`；鸿蒙用显式 key 和 clone 逻辑 | 现状可用，但如果子项将来更复杂，建议用更明确的 item 模型承接 sheet。 |

### 2.4 保存与日期处理

| iOS 行号 | 鸿蒙行号 | 对照结论 | 没对齐的点 | 建议 |
| --- | --- | --- | --- | --- |
| `339-353` | `238-250` | 子项摘要逻辑一致 | 基本一致 | 这一段已经比较接近，可以保留。 |
| `355-360` | `199-214` | 都做了子项替换 / 补入 | iOS 用 `UUID` 定位，鸿蒙用字符串 `id` 定位 | 只要 `id` 生成规则稳定，这里没有问题。 |
| `363-385` | `91-109` | 标题和提交按钮文案一致 | iOS 用计算属性，鸿蒙用方法返回字符串 | 两边都能工作，但鸿蒙可以继续保留方法式，关键是把文案集中管理。 |
| `387-449` | `135-196` | 都有防重复提交、错误提示、保存后回调 | iOS 有日志、`defer`、`dismiss`、`medicalCaseID`；鸿蒙没有日志，且 create 模式不携带 `medicalCaseID` | 鸿蒙建议补日志，补 context，保存后统一由同一条退出路径退场。 |
| `452-472` | `--` | iOS 额外有日期格式化与解析工具 | 鸿蒙没有等价的 `Date` 解析 / 格式化 helper | 这是日期双轨缺失的直接结果，建议补一组静态 formatter / parser。 |

## 3. 没有对齐的部分

下面这些是本工单要重点处理的差异点，按优先级排序。

### 3.1 `medicalCaseID` 缺失

**iOS 事实：**

`CreateContext` 里有 `medicalCaseID`，保存创建时会传给 `submitMedicalReportCreate(memberID:draft:medicalCaseID:)`。

**鸿蒙现状：**

`ExamReportFormView.ets` 只有 `memberID` 和 `mutationService`，创建时只调用 `createReportWithDraft(this.memberID, draft)`。

**影响：**

- 以后如果创建检查报告要和病例时间线、case 归属挂钩，鸿蒙会少一个关键上下文。
- 这类缺口后补通常要改一串调用链，不如现在补齐。

**优化方案：**

- 给鸿蒙表单补一个 `medicalCaseID?: number`。
- 创建提交接口一并透传。
- 若当前后端或服务层暂时不支持，也至少把上下文保留在表单层，不要丢掉。

### 3.2 日期只有字符串，没有 `Date`

**iOS 事实：**

- 用 `DatePicker` 直接承载日期。
- 用 `DateFormatter` 做 `yyyy-MM-dd` 格式化。
- 在 `init` 里把字符串解析回 `Date`。

**鸿蒙现状：**

- 只有 `date: string`。
- 没有 `examDay: Date`。
- 没有单独的 parse / format helper。

**影响：**

- 无法做真正的日期选择器。
- 字符串修改和日期语义混在一起，后续做校验、排序、回显会更脆。

**优化方案：**

- 保留 `date: string` 作为提交字段。
- 额外增加 `examDay: Date` 作为 UI 真值。
- `examDay` 变化时同步 `date`。
- seed 时从 `date` 反向解析到 `examDay`。

### 3.3 `editingItem` + `showItemSheet` 双状态偏脆

**iOS 事实：**

- `editingItem` 是可选值。
- `.sheet(item: $editingItem)` 由单个状态驱动。
- 关闭 sheet 后自动释放 item 语义。

**鸿蒙现状：**

- `editingItem` 是非可选的 `ItemDraft`。
- 再用 `showItemSheet` 控制弹层显示。

**影响：**

- 容易出现“弹层已关闭，但 editingItem 还保留旧值”的状态残留。
- 同时也更难做“选中某条 item 自动打开”的语义。

**优化方案：**

- 优先考虑把 `editingItem` 改成可空。
- 用单一状态驱动弹层开关。
- 如果当前 ArkUI 组件对 item sheet 支持有限，至少把 `showItemSheet` 的写入集中到一个函数里，不要在多处散写。

### 3.4 类型切换还不够“枚举驱动”

**iOS 事实：**

- `Picker` 直接遍历 `ExaminationReportCategory.allCases`。
- 选中后同步更新 `category`。

**鸿蒙现状：**

- 三个 chip 写死在页面上。
- `setPageType()` 同时更新 `pageType` 和 `category`。

**影响：**

- 新增类型时容易漏 UI。
- 视觉和数据状态之间的绑定不是同一条链路。

**优化方案：**

- chip 数据改成由 `ExaminationReportCategory` 枚举驱动。
- 让显示标题、颜色、图标都来自同一份配置。

### 3.5 输入封装还可以更薄

**iOS 事实：**

- 标题、医院、医生、内容都经过统一封装。
- 输入组件会接收键盘态和样式语义。

**鸿蒙现状：**

- 页面依赖自定义 `ExamFormTextField` / `ExamFormTextAreaField`。
- 是否向上透传焦点、键盘状态，当前从本文件看不出来。

**影响：**

- 如果底部栏、键盘、滚动避让之间的联动没做好，体验会比 iOS 弱。

**优化方案：**

- 确保输入封装支持 focus、keyboardVisible、maxLength、returnKey 行为。
- 如果封装里已经支持，就把这些能力在文档里写清楚，避免后续复用时丢失。

### 3.6 重复内容渲染可以进一步贴近官方建议

**iOS 事实：**

- `ForEach(items)` 用得非常直接。

**鸿蒙官方建议：**

- 对于重复内容，官方文档已经给出 `Repeat`、`LazyForEach` 等方案。
- `Repeat` 直接监听状态变化；`LazyForEach` 则适合更大数据量和懒加载场景。

**影响：**

- 当前 `ForEach` 没有错。
- 但如果这个表单未来要承载更多子项，或者要把子项拆成更重的展示块，官方方案会更稳。

**优化方案：**

- 子项少时，当前 `ForEach` 可以保留。
- 子项增长明显时，优先评估 `Repeat` 或 `LazyForEach`。

## 4. 鸿蒙官方最优写法建议

下面这几条是本工单推荐的鸿蒙侧写法，依据来自官方文档：

- `aboutToAppear()` 适合做轻量初始化，不要塞重计算。
- 重复内容渲染优先考虑状态驱动方案，必要时切 `Repeat` / `LazyForEach`。
- 半模态内容优先使用 `bindSheet()`。
- `TextInput` / `TextArea` 相关输入态要把焦点和键盘行为考虑进去。

### 4.1 生命周期函数

官方文档明确说明，`aboutToAppear()` 会在 `build()` 之前执行，适合做状态注入，但不适合做耗时逻辑。  
本页当前的 `seedFromProps()` 只做纯内存赋值和克隆，这个方向是对的。

建议：

- 保留 `aboutToAppear()`。
- 不要把网络请求、IO、复杂解析塞进这里。
- 如果未来新增日期解析或草稿映射很重，建议提到外层预处理。

### 4.2 重复渲染

官方文档对重复内容渲染已经明确给出 `Repeat` 和 `LazyForEach`。  
本页目前的子项数量通常不大，所以 `ForEach` 可以先保留；如果后续要做大量项目列表，建议再升级。

### 4.3 半模态弹层

当前鸿蒙已经在用 `bindSheet()`，这和官方的半模态建议一致。  
如果后续要做更复杂的子项编辑器，仍建议保留这一套模式，不要换成手写浮层。

### 4.4 输入组件

`TextInput` / `TextArea` 是官方输入基元，建议表单封装尽量围绕这两个组件展开，向外暴露：

- `keyboardVisible`
- `maxLength`
- `focus`
- `onSubmit`
- `placeholder`

这样后续页面统一样式和行为会更稳。

## 5. 关键代码示例

### 5.1 日期双轨写法

下面是推荐的鸿蒙写法方向，保留字符串提交值，同时补 `Date` 作为 UI 真值：

```ts
@State private examDay: Date = new Date();
@State private date: string = ExaminationReportDraftMapping.todayDateText();

private syncDateFromDay(day: Date): void {
  this.examDay = day;
  this.date = ExaminationReportDraftMapping.formatDate(day);
}

private seedDate(rawDate?: string): void {
  const parsed = ExaminationReportDraftMapping.parseDate(rawDate);
  this.examDay = parsed;
  this.date = ExaminationReportDraftMapping.formatDate(parsed);
}
```

### 5.2 单一 item 状态驱动弹层

比起 `showItemSheet + editingItem` 两个状态，推荐把弹层收敛成单一入口：

```ts
@State private editingItem?: ItemDraft = undefined;

private openItemEditor(item?: ItemDraft): void {
  this.editingItem = item ? ExaminationReportDraftMapping.cloneItemDraft(item) : new ItemDraft();
}

private closeItemEditor(): void {
  this.editingItem = undefined;
}
```

如果当前 ArkUI 版本更适合 `bindSheet()` + 一个布尔值，也至少把 `editingItem` 的写入收口到这两个函数里。

### 5.3 枚举驱动的类型选择

当前三块 chip 是写死的。更稳的做法是让配置从枚举出来：

```ts
const examCategoryItems = ExaminationReportCategory.allCases.map((item) => ({
  value: item,
  title: examinationCategoryTitle(item),
}));
```

然后在页面里统一渲染，避免后续新增类型时漏改。

### 5.4 保存链路收敛

建议把保存逻辑抽成“先归一化，再提交，再退场”的固定流程：

```ts
private async saveNow(): Promise<void> {
  if (this.isSaving) {
    return;
  }

  const draft = this.buildDraft();
  this.errorText = '';
  this.isSaving = true;

  try {
    if (this.modeKind === ExamReportFormModeKind.LOCAL_EDIT) {
      this.onLocalSubmit?.(draft);
      this.onCancel?.();
      return;
    }

    if (this.modeKind === ExamReportFormModeKind.SERVER_EDIT) {
      if (!this.existingReport || !this.mutationService) {
        this.errorText = '保存配置缺失';
        return;
      }
      await this.mutationService.updateReportWithDraft(this.existingReport, draft);
      this.onServerSaved?.(draft);
      this.onCancel?.();
      return;
    }

    if (this.modeKind === ExamReportFormModeKind.CREATE) {
      if (!this.mutationService || this.memberID <= 0) {
        this.errorText = '保存配置缺失';
        return;
      }
      const newID = await this.mutationService.createReportWithDraft(this.memberID, draft);
      this.onCreated?.(newID, draft);
      this.onCancel?.();
    }
  } catch (e) {
    this.errorText = `${e}`;
  } finally {
    this.isSaving = false;
  }
}
```

## 6. 验收清单

修改完成后，建议按下面顺序验收：

1. 新建模式能否带出正确标题、默认日期和默认分类。
2. 服务端编辑模式能否正确回填日期、标题、医院、医生、内容和 item。
3. 本地编辑模式保存后能否稳定回到上一层。
4. 检验 / 影像 / 病理三种模式切换后，子项弹层能否正确打开。
5. 日期修改后，提交的 `date` 是否和页面显示一致。
6. `medicalCaseID` 是否被正确保留并透传到创建提交链路。
7. 输入法弹出时，底部保存栏和页面滚动是否正常。

## 7. 官方依据

本工单的鸿蒙建议主要参考以下官方资料：

- [ArkUI 组件与框架总览](https://developer.huawei.com/consumer/en/doc/harmonyos-guides/arkui)
- [状态管理概览](https://developer.huawei.com/consumer/en/doc/harmonyos-guides/arkts-state-management-overview)
- [自定义组件生命周期](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/ts-custom-component-lifecycle)
- [重复内容渲染 Repeat](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/arkts-new-rendering-control-repeat)
- [文本输入 TextInput / TextArea](https://developer.huawei.com/consumer/en/doc/harmonyos-guides/arkts-common-components-text-input)
- [半模态转场 bindSheet](https://developer.huawei.com/consumer/en/doc/best-practices/bpta-page-transition)

