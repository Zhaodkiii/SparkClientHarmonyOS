# SparkClientHarmonyOS｜用药计划周历选中态指示器与居中偏移修复工单

> 核验日期：2026-07-26  
> 文档性质：缺陷修复工单 + iOS 对齐技术方案  
> 参考端：`SparkClient` iOS 用药执行中心 `legacyDateStripFallback`  
> 目标端：`SparkClientHarmonyOS` 用药执行中心  
> 截图证据：`/var/folders/l4/gly2bq810gz95r7ttwj23l9h0000gn/T/codex-clipboard-5544a1b2-1b00-478d-aa16-543a00961275.png`  
> 代码边界：本文只创建工单，不修改任何项目代码。

## 1. 工单索引

| 工单号 | 工单名 | 状态 | 范围 |
| --- | --- | --- | --- |
| `HOS-MED-EXEC-0002` | 用药计划周历选中态指示器与居中偏移修复 | 待实现 | 修复鸿蒙用药执行中心日期条中“三角指示器与实际选中日期不一致”“选中日期没有居中”的问题；对齐 iOS `legacyDateStripFallback` 的居中吸附与提交逻辑 |

## 2. 问题描述

当前日期为 **7月26日（周日）**，但周历选中态存在偏差：

1. 黑色三角指示器没有正确指向周日，而是落在更靠左的位置。
2. 周日没有处在屏幕中央，当前日期没有按选中态居中展示。
3. 三角指示器的视觉焦点与实际选中日期不一致。
4. 用户难以准确判断当前选中的到底是哪一天。
5. iOS 页面是纵向可滚动页面，日期条自身也是横向可滚动控件；鸿蒙当前体验需要明确补齐“页面纵向滚动 + 日期条横向滚动”的嵌套滚动能力。

从截图看，页面标题显示 `7月26日 今天`，日期条右侧 `周日` 是黑色选中态，进度圆点为蓝绿色，但三角指示器位于中间偏左区域，视觉上更接近 `周四` 附近。这说明“页面选中日期”和“日期条中心定位”没有同步。

补充问题：如果鸿蒙端当前页面或周历不能顺畅滚动，则不只是视觉偏移问题，还属于交互能力缺失。iOS 的目标体验是外层页面可上下滚动，内层日期条可左右滚动，两个方向互不抢手势。

## 3. 预期效果

当选中日期为 7月26日（周日）时：

1. `周日` 日期项必须位于日期条可视区域水平中心。
2. 黑色三角指示器必须固定在日期条水平中心，并正好指向 `周日` 日期项中心线。
3. 标题日期、黑色星期选中态、蓝绿色进度圆点和三角指示器必须表达同一个日期。
4. 页面初始化、点击日期、手势滚动结束、外部变更 `selectedDate` 后都必须保持居中一致。

## 4. iOS 关键代码位置

### 4.1 iOS 页面纵向滚动入口

文件：

```text
SparkClient/SparkClient/Projects/Features/Home/Presentation/MedicalLists/Medications/MedicationExecutionCenter/MedicationExecutionCenterPage.swift
```

关键位置：

| 行号 | 代码位置 | 作用 |
| --- | --- | --- |
| `145-160` | `var body: some View { ScrollView { ... } }` | 整个用药执行中心是纵向滚动页面 |
| `147-157` | `VStack(alignment: .leading, spacing: 24)` | 标题、日期条、记录区、已完成区按顺序进入同一个纵向滚动内容 |
| `148-155` | `dateHeader`、`dateStrip`、`recordSection`、`completedSection` | iOS 中日期条不是固定悬浮层，而是滚动内容的一部分 |
| `158-159` | `.padding(.top, 20)`、`.padding(.bottom, 32)` | 保证滚动内容上下留白 |

### 4.2 iOS 日期条入口

文件：

```text
SparkClient/SparkClient/Projects/Features/Home/Presentation/MedicalLists/Medications/MedicationExecutionCenter/MedicationExecutionCenterPage.swift
```

关键位置：

| 行号 | 代码位置 | 作用 |
| --- | --- | --- |
| `414-455` | `legacyDateStripFallback` | 日期条 UI 结构：分割线、三角指示器、legacy 横向滚动日期条 |
| `421-430` | `MedicationExecutionLegacyDateStripScrollView(...)` | 注入日期项、选中日期、item 宽度、间距和提交回调 |
| `457-470` | `commitLegacyDateStripDate(_:)` | 选中日期提交后延迟加载记录窗口 |
| `859-937` | `MedicationExecutionLegacyDateStripScrollView` | iOS legacy 滚动容器主实现 |
| `965-972` | `contentInset(for:)` + `contentOffset(for:)` | 居中吸附核心公式 |
| `974-978` | `index(for:)` | 根据滚动偏移反算当前应选中的日期项 |
| `992-1040` | `Coordinator` | 滚动高亮、拖拽结束吸附、点击提交 |
| `1054-1078` | `MedicationExecutionLegacyDateStripContent` | 日期项 HStack 宽度和间距 |

### 4.3 iOS 日期圆点样式

文件：

```text
SparkClient/SparkClient/Projects/Features/Home/Presentation/MedicalLists/Medications/MedicationExecutionCenter/MedicationExecutionDateStrip.swift
```

关键位置：

| 行号 | 代码位置 | 作用 |
| --- | --- | --- |
| `3-9` | `MedicationExecutionDateStripMetrics` | `itemWidth=48`、`itemSpacing=8`、`stripHeight=108`、圆点直径等固定指标 |
| `30-39` | `MedicationExecutionDateDot.body` | 日期项整体宽度固定为 `itemWidth` |
| `41-64` | `weekdayLabel` | 选中星期使用黑色圆形 badge |
| `67-89` | `progressCircle` | 圆形进度展示 |

## 5. iOS 居中算法拆解

iOS legacy 日期条的核心是把“选中项中心”对齐到“屏幕中心”。

核心公式：

```swift
private func contentInset(for scrollView: UIScrollView) -> UIEdgeInsets {
    let horizontalInset = max((scrollView.bounds.width - itemWidth) / 2, 0)
    return UIEdgeInsets(top: 0, left: horizontalInset, bottom: 0, right: horizontalInset)
}

private func contentOffset(for index: Int, in scrollView: UIScrollView) -> CGFloat {
    CGFloat(index) * itemPitch - scrollView.contentInset.left
}

private func index(for scrollView: UIScrollView) -> Int {
    let rawIndex = ((scrollView.contentOffset.x + scrollView.contentInset.left) / itemPitch).rounded()
    return min(max(Int(rawIndex), 0), items.count - 1)
}
```

其中：

| 名称 | 含义 |
| --- | --- |
| `itemWidth` | 日期项视觉宽度，iOS 为 `48` |
| `itemSpacing` | 日期项之间间距，iOS 为 `8` |
| `itemPitch` | 一个日期项占用的滚动步长，即 `itemWidth + itemSpacing` |
| `contentInset.left` | 左侧补白，使第一个/最后一个日期项也能居中 |
| `contentOffset` | 滚动到指定 index 时的横向偏移 |
| `index(for:)` | 根据当前滚动偏移反推中心日期项 |

这个算法有一个重要前提：三角指示器固定在容器中心，滚动列表把选中项滚到容器中心。三角不跟着 item 移动，item 要移动到三角下面。

## 6. HarmonyOS 当前关键代码位置

### 6.1 鸿蒙页面入口

文件：

```text
SparkClientHarmonyOS/entry/src/main/ets/Projects/Features/Home/Presentation/MedicalLists/Medications/MedicationExecutionCenter/MedicationExecutionCenterPage.ets
```

关键位置：

| 行号 | 代码位置 | 当前作用 |
| --- | --- | --- |
| `61-64` | `selectedDate`、`recordsByDayID`、`loadedWindow`、`loadingWindowID` | 用药执行中心核心状态 |
| `80` | `legacyDateLoadTimer` | legacy 日期条提交后的延迟加载 |
| `82-90` | `aboutToAppear` | 初始化依赖、缓存和记录窗口 |
| `165-174` | `commitLegacyDateStripDate(dateMs:)` | 提交选中日期并延迟加载窗口 |
| `433-462` | `dateNavigationSection()` | 标题和日期条布局 |
| `445-458` | `MedicationExecutionDateStrip(...)` | 给日期条传入 `selectedDate` 和回调 |
| `480-587` | `Refresh { Scroll { Column { ... } } }` | 当前鸿蒙页面纵向滚动容器，需要验收是否真实可滚动 |
| `581-587` | `.padding({ bottom: 32 })`、`.height('100%')`、`.edgeEffect(EdgeEffect.Spring)` | 页面滚动高度、底部留白和边缘效果相关 |

### 6.2 鸿蒙日期条外层

文件：

```text
SparkClientHarmonyOS/entry/src/main/ets/Projects/Features/Home/Presentation/MedicalLists/Medications/MedicationExecutionCenter/MedicationExecutionDateStrip.ets
```

关键位置：

| 行号 | 代码位置 | 当前作用 |
| --- | --- | --- |
| `35-78` | `build()` | 绘制分割线、三角指示器、legacy scroll view |
| `42-51` | `Polygon()` | 黑色三角指示器，当前固定居中 |
| `53-74` | `MedicationExecutionLegacyDateStripScrollView(...)` | 日期滚动容器 |

### 6.3 鸿蒙 legacy 滚动容器

文件：

```text
SparkClientHarmonyOS/entry/src/main/ets/Projects/Features/Home/Presentation/MedicalLists/Medications/MedicationExecutionCenter/MedicationExecutionLegacyDateStripScrollView.ets
```

关键位置：

| 行号 | 代码位置 | 当前作用 |
| --- | --- | --- |
| `32-36` | `Scroller`、`displayedDate`、`viewportWidth`、`isProgrammaticScroll`、`pendingCommitTimer` | 滚动状态 |
| `59-65` | `contentInset()`、`contentOffsetFor(index)` | 试图复刻 iOS 居中公式 |
| `67-73` | `indexForOffset(offsetX)` | 根据滚动偏移反推中心项 |
| `75-80` | `scrollToIndex(index, animated)` | 程序化滚动 |
| `82-98` | `highlightAtOffset(offsetX)` | 滚动中更新选中日期 |
| `100-112` | `commitAtIndex(index)` | 提交最终选中日期 |
| `114-125` | `scheduleSnap()` | 滚动停止后吸附并提交 |
| `152-201` | `build()` | Scroll + Row + padding + onAreaChange/onScroll/onScrollStop |
| `177-180` | Row 左右 padding | 用 padding 模拟 iOS `contentInset` |
| `191-194` | `onAreaChange` | 记录 viewportWidth，并滚动到 selectedIndex |

### 6.4 鸿蒙日期点样式

文件：

```text
SparkClientHarmonyOS/entry/src/main/ets/Projects/Features/Home/Presentation/MedicalLists/Medications/MedicationExecutionCenter/MedicationExecutionDateDot.ets
```

关键位置：

| 行号 | 代码位置 | 当前作用 |
| --- | --- | --- |
| `8-14` | `MedicationExecutionDateStripMetrics` | 指标值对齐 iOS：`ITEM_WIDTH=48`、`ITEM_SPACING=8`、`STRIP_HEIGHT=108` |
| `35-55` | `weekdayLabel()` | 选中日期黑色圆角 badge |
| `86-92` | `build()` | 日期项整体宽度固定为 `ITEM_WIDTH` |

## 7. 初步根因判断

从截图和当前代码看，问题更可能发生在“滚动容器实际偏移”和“三角固定中心”之间：

1. `Polygon` 三角在 `MedicationExecutionDateStrip.ets` 中固定水平居中。
2. `周日` 的选中态已经被正确设置，说明 `selectedDate` 本身是 7月26日。
3. 但 `周日` 未居中，说明 `MedicationExecutionLegacyDateStripScrollView.ets` 没有把 `selectedIndex` 对应 item 滚到中心。
4. 当前 `onAreaChange` 只在区域变化时调用 `scrollToIndex(this.selectedIndex(), false)`，如果 `items`、`selectedDate` 或 `viewportWidth` 的更新顺序不稳定，可能出现首次定位时机偏早。
5. ArkUI `Scroller.scrollTo` 的 `xOffset` 与 Row `padding.left` 的关系需要核验，不能默认完全等价于 iOS `contentInset.left`。
6. `scrollToIndex` 内部立即把 `isProgrammaticScroll` 设回 `false`，如果 ArkUI 滚动是异步生效，可能导致随后的 `onScroll` 把程序化滚动当成用户滚动处理。

因此，修复方向不是移动三角，而是保证选中日期项真实居中到三角下方。

## 8. 页面滚动对齐方案

### 8.1 iOS 滚动结构

iOS 用药执行中心是两层滚动：

```text
外层：ScrollView（纵向）
  └─ VStack
      ├─ dateHeader
      ├─ dateStrip
      │   └─ MedicationExecutionLegacyDateStripScrollView（横向 UIScrollView）
      ├─ recordSection
      └─ completedSection
```

这个结构带来的体验是：

1. 页面内容超过屏幕高度时可以上下滚动。
2. 日期条在页面顶部区域内横向滚动。
3. 横向拖动日期条时不应触发页面纵向滚动。
4. 纵向拖动记录区时不应影响日期条横向位置。

### 8.2 鸿蒙目标滚动结构

鸿蒙端应保持同等语义：

```text
外层：Refresh
  └─ Scroll（纵向，layoutWeight=1，高度填满剩余区域）
      └─ Column（滚动内容）
          ├─ dateNavigationSection
          │   ├─ 标题
          │   └─ MedicationExecutionDateStrip
          │       └─ MedicationExecutionLegacyDateStripScrollView（横向 Scroll）
          ├─ 记录区
          └─ 已记录区
```

修复时必须确认两个滚动层都真实生效：

1. 外层 `Scroll` 必须是纵向滚动，内容高度超过视口时可滚动。
2. 内层 `MedicationExecutionLegacyDateStripScrollView` 必须是横向滚动，Row 内容宽度必须大于视口宽度。
3. 横向日期条不能因为父级 `Refresh` 或纵向 `Scroll` 抢手势而失效。
4. 日期条高度固定为 `86`，整条高度保持 `STRIP_HEIGHT=108`，不要通过压缩高度换取滚动。

### 8.3 嵌套滚动策略

当前鸿蒙日期条内层存在：

```ts
.nestedScroll({
  scrollForward: NestedScrollMode.PARENT_FIRST,
  scrollBackward: NestedScrollMode.SELF_FIRST
})
```

这段需要重点验证。对于“横向日期条嵌在纵向页面”这个场景，推荐策略是：

1. 横向手势优先交给日期条自身处理。
2. 纵向手势交给外层页面处理。
3. 如果 ArkUI 的 `nestedScroll` 不能按方向自动区分，需要改为让内层横向 Scroll 具备更高优先级。
4. 不要让父级 `Refresh` 在横向拖动开始时抢走手势，否则周历会表现为“不支持滚动”。

### 8.4 页面纵向滚动验收

为了对齐 iOS，鸿蒙页面纵向滚动应满足：

1. 待执行卡片很多时，页面可向下滚动看到全部记录。
2. 已记录区出现时，页面可继续向下滚动到底部。
3. 底部保留 32 左右的安全留白，不贴底。
4. 下拉刷新只在列表顶部触发，不影响正常向下滚动。
5. 日期条横滑时不触发下拉刷新。

### 8.5 日期条横向滚动验收

为了对齐 iOS，日期条横向滚动应满足：

1. 7月26日不在中心时，页面初始化后自动滚到中心。
2. 用户可以横向滑动到前后日期。
3. 滑动停止后自动吸附到离中心最近的日期。
4. 点击远处日期时，该日期滚到中心。
5. 横向滑动日期条不会带动页面上下滚动。

## 9. 技术方案

### 9.1 修复目标

1. 保持三角指示器固定在日期条水平中心。
2. 修复日期条滚动定位，使选中日期项中心与三角中心重合。
3. 页面首次进入时，`selectedDate` 对应日期项必须自动居中。
4. 点击任意日期项后，该日期项必须滚动到中心并提交。
5. 手势滑动停止后，中心最近日期项必须吸附到三角下方，并成为选中日期。
6. 保证页面外层纵向滚动和日期条内层横向滚动同时可用。

### 9.2 居中公式对齐

鸿蒙端应显式对齐 iOS 公式：

```ts
private itemPitch(): number {
  return this.itemWidth + this.itemSpacing;
}

private centerInset(): number {
  return Math.max((this.viewportWidth - this.itemWidth) / 2, 0);
}

private centeredOffsetFor(index: number): number {
  return index * this.itemPitch() - this.centerInset();
}

private centeredIndexForOffset(offsetX: number): number {
  const raw = Math.round((offsetX + this.centerInset()) / this.itemPitch());
  return Math.min(Math.max(raw, 0), this.items.length - 1);
}
```

验收重点不是函数名，而是：

1. `offset -> index` 与 `index -> offset` 必须使用同一个 inset 和 pitch。
2. 不能一处用 item 左边缘，一处用 item 中心。
3. 不能把三角位置当作可变值去迁就错误滚动。

### 9.3 初始化定位

当前 `onAreaChange` 会在 `viewportWidth` 变化后滚动到 selectedIndex。建议补充以下策略：

1. 当 `viewportWidth > 0` 且 `items` 非空时，执行一次初始居中。
2. 当外部 `selectedDate` 变化时，如果不是用户拖动中，也要重新居中。
3. 初始居中应在下一帧或短延迟后执行，避免 ArkUI Row padding 尚未布局完成就读取 offset。
4. 初始定位完成前，避免 `onScroll` 把中间态回写为错误日期。

伪代码：

```ts
private alignSelectedDateToCenter(animated: boolean): void {
  if (this.viewportWidth <= 0 || this.items.length === 0) {
    return;
  }
  const index = this.selectedIndex();
  this.scrollToIndex(index, animated);
}
```

### 9.4 程序化滚动保护

当前实现：

```ts
this.isProgrammaticScroll = true;
this.scroller.scrollTo({ xOffset: x, yOffset: 0, animation: animated });
this.isProgrammaticScroll = false;
```

如果 ArkUI 的 `scrollTo` 是异步触发滚动事件，这段保护可能太短。建议改为“滚动后一小段时间再释放保护”：

```ts
private scrollToIndex(index: number, animated: boolean): void {
  const x = this.contentOffsetFor(index);
  this.isProgrammaticScroll = true;
  this.scroller.scrollTo({ xOffset: x, yOffset: 0, animation: animated });
  setTimeout(() => {
    this.isProgrammaticScroll = false;
  }, animated ? 180 : 32);
}
```

具体时长应以真机验证为准。这里的目标是防止程序化滚动触发 `onScroll` 后立即错误改写 `selectedDate`。

### 9.5 滚动结束吸附

`onScrollStop` 应继续保留吸附逻辑，但吸附后的 index 必须来自中心点公式：

```ts
private scheduleSnap(): void {
  if (this.pendingCommitTimer >= 0) {
    clearTimeout(this.pendingCommitTimer);
  }
  this.pendingCommitTimer = setTimeout(() => {
    const offset = this.scroller.currentOffset().xOffset;
    const index = this.indexForOffset(offset);
    this.scrollToIndex(index, false);
    this.commitAtIndex(index);
    this.pendingCommitTimer = -1;
  }, 80);
}
```

修复时重点检查：

1. `currentOffset().xOffset` 是否包含 Row padding 影响。
2. `indexForOffset` 是否需要根据 ArkUI 实测调整为 `offsetX / itemPitch` 或 `(offsetX + centerInset) / itemPitch`。
3. 点击日期后是否先滚动居中再提交，避免标题先变、列表未居中。

### 9.6 三角指示器策略

三角指示器不建议跟随 `selectedDate` 移动。它应该始终在屏幕中心：

```ts
Column() {
  Polygon()
    .points([[12, 0], [0, 14], [24, 14]])
    .fill(MED_EXEC_PRIMARY_TEXT)
    .width(24)
    .height(14)
}
.width('100%')
.alignItems(HorizontalAlign.Center)
```

修复重点是让日期项滚到三角下面，而不是让三角去追日期项。

## 10. 验收标准

### 10.1 截图场景验收

以 2026-07-26 为例：

1. 页面标题显示 `7月26日 今天`。
2. 日期条中 `周日` 显示黑色选中 badge。
3. `周日` 日期项中心位于屏幕水平中心。
4. 黑色三角指示器正对 `周日` 日期项中心。
5. 蓝绿色进度圆点与 `周日` 选中 badge 上下对齐。

### 10.2 交互验收

1. 点击 `周一` 后，`周一` 滚动到中心，三角指向 `周一`。
2. 点击 `周日` 后，`周日` 滚动到中心，三角指向 `周日`。
3. 手势滑动停止后，距离中心最近的日期项被吸附到中心并成为选中日期。
4. 快速连续点击日期，不出现标题已变但日期条未居中的状态。
5. 下拉刷新或记录加载完成后，不改变当前选中日期的居中位置。
6. 页面内容超过屏幕时可以纵向滚动。
7. 日期条可以横向滚动，且横滑时不触发页面下拉刷新。

### 10.3 回归验收

1. `recordsByDayID`、`loadedWindowStart`、`loadedWindowEndExclusive` 仍能正常驱动日期圆点进度。
2. `commitLegacyDateStripDate` 仍按选中日期加载窗口记录。
3. 待执行、已完成、按需用药区仍跟随 `selectedDate` 刷新。
4. 不新增 `ios17DateStrip` 或等价双分支实现。

## 11. 开发注意事项

1. 先在鸿蒙端打印或断点观察 `viewportWidth`、`contentInset()`、`selectedIndex()`、`contentOffsetFor(index)` 和 `currentOffset().xOffset`。
2. 不要先调整 UI 间距来“看起来对齐”，应先确认滚动数学关系正确。
3. 不要移动三角位置来掩盖日期条未居中的问题。
4. 若 ArkUI `Row.padding` 与 `Scroller.currentOffset()` 的坐标语义和 iOS `contentInset` 不一致，应在 `MedicationExecutionLegacyDateStripScrollView.ets` 内统一换算。
5. 点击和滚动停止必须走同一套居中公式，避免两种路径表现不同。
6. 页面滚动问题要和日期条滚动问题一起验收，不能只修其中一个。
7. 如果真机上 `Refresh` 抢占横向手势，应优先调整嵌套滚动/手势优先级，而不是移除日期条横向滚动。

## 12. 结论

本问题的本质是日期条视觉锚点和滚动能力失配：页面状态已经选中 7月26日（周日），但滚动容器没有把该日期项吸附到三角指示器下方；同时鸿蒙端还需要确认外层页面纵向滚动和内层周历横向滚动都对齐 iOS。

修复时应以 iOS `legacyDateStripFallback` 为唯一对齐对象，重点对齐 `ScrollView` 页面结构、`contentInset`、`contentOffsetFor`、`indexForOffset`、程序化滚动保护和嵌套滚动手势策略。验收标准是页面能上下滚动，周历能左右滚动，并且标题、黑色选中 badge、蓝绿色进度圆点和三角指示器四者都指向同一天。
