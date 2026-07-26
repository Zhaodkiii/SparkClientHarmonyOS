# SparkClientHarmonyOS｜用药执行中心与 legacyDateStripFallback 对齐工单

> 核验日期：2026-07-26  
> 文档性质：需求工单 + 详细设计约束 + 目录对齐说明  
> 参考端：`SparkClient` iOS `MedicationExecutionCenterPage.swift`  
> 目标端：`SparkClientHarmonyOS`  
> 核心边界：**只实现 `legacyDateStripFallback` 对应的日期条与用药执行中心闭环，不实现 `ios17DateStrip`，不做 iOS 17 专属滚动分支迁移**

## 1. 工单索引

| 工单号 | 工单名 | 状态 | 范围 |
| --- | --- | --- | --- |
| `HOS-MED-EXEC-0001` | 用药执行中心与 `legacyDateStripFallback` 对齐 | 需求设计中 | 对齐 iOS 用药执行中心主视图、日期条、窗口缓存、记录列表、完成态、按需用药入口和提交闭环；日期条仅落地 `legacyDateStripFallback`，明确不实现 `ios17DateStrip` |

## 2. 背景与目标

### 2.1 背景

当前 iOS 用药执行中心已经不是“单纯列表页”，而是一个带有日期条、记录窗口缓存、待执行/已完成分区、按需用药入口和记录提交流程的完整页面。

iOS 源文件位置如下：

```text
SparkClient/SparkClient/Projects/Features/Home/Presentation/MedicalLists/Medications/MedicationExecutionCenter/MedicationExecutionCenterPage.swift
```

本工单要做的不是“重写一个相似页面”，而是把这个页面的核心行为对齐到鸿蒙端，尤其是以下事实：

1. 用药执行中心的日期条是页面核心导航，不是装饰组件。
2. 日期条不是只展示当前日，而是展示一个可滚动的日期窗口。
3. 页面记录加载要围绕选中日期形成缓存窗口，而不是只拉当天。
4. 日期条进度必须来自同一份按日缓存，而不是全局单日记录。
5. 鸿蒙端的日期条实现只允许采用 iOS 的 `legacyDateStripFallback` 路径，不允许引入 `ios17DateStrip` 作为等价目标。

### 2.2 目标

1. 在鸿蒙端实现与 iOS 用药执行中心同等语义的页面结构。
2. 对齐主标题、日期条、待执行用药、已完成用药、按需用药、记录提交和加载态。
3. 日期条只实现 legacy fallback 视觉和交互，不实现 iOS 17 专属滚动分支。
4. 统一数据模型、目录结构、加载窗口和进度计算方式。
5. 工单层面把关键代码路径、关键字段和关键 UI 状态说清楚，方便后续直接开工。

## 3. 明确边界

### 3.1 必做

1. 用药执行中心主视图布局对齐。
2. 日期条的 `legacyDateStripFallback` 行为对齐。
3. 日期窗口缓存与进度圆环计算对齐。
4. 记录列表、完成态、按需用药入口对齐。
5. 选择日期、滚动日期、提交记录后的状态联动对齐。

### 3.2 明确不做

1. 不实现 `ios17DateStrip`。
2. 不使用 `scrollTargetLayout`、`scrollPosition` 作为鸿蒙实现目标。
3. 不把 iOS 17 的分支条件、API 可用性判断和行为作为鸿蒙设计的一部分。
4. 不改服务端接口。
5. 不修改任何现有项目代码文件，本工单只新增文档。

### 3.3 这次工单的正确理解

本工单不是“把 iOS 代码机械翻译成 ArkTS 字面语法”，而是：

1. 保持页面语义一致。
2. 保持数据流一致。
3. 保持窗口缓存一致。
4. 保持 UI 结构一致。
5. 保持 legacy fallback 的实现路径一致。

也就是说，鸿蒙端可以用 ArkUI 自己的组件、滚动容器和状态管理方式，但行为必须对齐 `legacyDateStripFallback`，而不是去补一个 iOS 17 风格的第二实现。

## 4. iOS 源码事实基线

### 4.1 关键文件

| iOS 文件 | 职责 |
| --- | --- |
| `MedicationExecutionCenterPage.swift` | 主页面，负责日期条、记录区、完成区、Sheet、加载和保存 |
| `MedicationExecutionLegacyDateStripScrollView` | legacy 日期条滚动容器 |
| `MedicationExecutionDateDot` | 单个日期圆点/圆环表现 |
| `MedicationExecutionPlanner` | 剂次计算和进度计算 |
| `MedicationExecutionRecordCache` | 按日缓存记录读取 |
| `MedicationExecutionDateItem` | 日期条数据项 |

### 4.2 关键源码区间

当前需要对齐的核心范围位于以下行段：

```text
dateStrip        -> 286-293
ios17DateStrip   -> 296-399
legacyDateStripFallback -> 414-455
commitLegacyDateStripDate -> 457-470
```

本工单只把 `legacyDateStripFallback` 作为目标行为，`ios17DateStrip` 仅作为“历史参考分支”存在，不进入鸿蒙实施范围。

### 4.3 对齐结论

| 位置 | 结论 |
| --- | --- |
| `dateStrip` 主入口 | 鸿蒙端仅保留一个日期条入口，逻辑上等同 legacy fallback |
| `ios17DateStrip` | 不实现，不转译，不设计，不作为验收目标 |
| `legacyDateStripFallback` | 这是本工单唯一对齐对象 |
| 记录加载 | 必须支持按日期窗口加载，而不是只加载单日 |
| 日期条进度 | 必须按日读取 `recordsByDayID` 计算 |

## 5. 目录结构设计

### 5.1 本工单建议落点

建议将鸿蒙端用药执行中心相关文档统一放在以下目录：

```text
SparkClientHarmonyOS/开发详细技术文档/首页、成员与医疗画像/药箱/用药模块/
```

本次新增文档建议命名为：

```text
HOS-MED-EXEC-0001-用药执行中心与legacyDateStripFallback对齐工单.md
```

### 5.2 目标代码目录

如果后续要实现，建议把对应代码放在如下语义目录中：

```text
SparkClientHarmonyOS/entry/src/main/ets/Projects/Features/Home/Presentation/MedicalLists/Medications/MedicationExecutionCenter/
├── MedicationExecutionCenterPage.ets
├── MedicationExecutionDateStrip.ets
├── MedicationExecutionLegacyDateStripScrollView.ets
├── MedicationExecutionDateDot.ets
├── MedicationExecutionRecordCache.ets
├── MedicationExecutionPlanner.ets
├── MedicationExecutionModels.ets
├── MedicationExecutionPendingCard.ets
├── MedicationExecutionCompletedGroup.ets
├── MedicationExecutionAsNeededCard.ets
└── MedicationExecutionLogSheet.ets
```

### 5.3 目录职责原则

1. 页面负责展示和事件转发。
2. Planner 负责计算，不负责 UI。
3. Cache 负责按日查找，不负责网络请求。
4. Models 负责数据结构，不负责业务流程。
5. 日期条组件只接受已经整理好的数据，不直接访问网络。

## 6. 数据模型对齐

### 6.1 页面状态模型

鸿蒙端应保留与 iOS 相同语义的状态拆分，至少包含以下字段：

| 状态 | 职责 | 对齐意义 |
| --- | --- | --- |
| `selectedDate` | 当前选中的日期 | 驱动页面标题、记录区和日期条选中态 |
| `selectedDayStart` | 选中日的当天起点 | 统一日边界计算，避免时分秒污染 |
| `recordsByDayID` | 按日缓存记录 | 日期条圆环和记录列表的共同数据源 |
| `loadedWindow` | 当前已加载窗口 | 避免重复请求，支撑日期跳转 |
| `loadingWindowID` | 正在加载的窗口标识 | 防止快速切换时重复发请求 |
| `legacyDateStripDefersServerLoad` | legacy 日期条拖动时的延迟加载闸门 | 保证滚动体验与网络请求节奏分离 |
| `legacyDateLoadTask` | 延迟加载任务句柄 | 用于取消前一次滚动后的失效请求 |
| `activeRecordLoadToken` | 当前活跃加载令牌 | 防止旧请求回写新页面状态 |

### 6.2 日期条模型

| 模型 | 字段 | 语义 |
| --- | --- | --- |
| `MedicationExecutionDateItem` | `id` | 日期条唯一标识，通常按 day-start 生成 |
| `MedicationExecutionDateItem` | `date` | 当前条目对应日期 |
| `MedicationExecutionDateItem` | `calendar` | 统一日历上下文，用于比较和格式化 |
| `MedicationExecutionDateStripMetrics` | `itemWidth` | 单个日期项宽度 |
| `MedicationExecutionDateStripMetrics` | `itemSpacing` | 相邻日期项间距 |
| `MedicationExecutionDateStripMetrics` | `stripHeight` | 整条日期条高度 |

### 6.3 记录模型

| 模型 | 职责 |
| --- | --- |
| `RemoteMedicationPlan` | 用药计划源数据 |
| `RemoteMedicineBox` | 药箱引用数据 |
| `RemoteMedicationRecord` | 某日某次记录 |
| `MedicationExecutionDose` | 计算后的一次剂次展示模型 |
| `MedicationExecutionRecordWindow` | 记录加载窗口 |

### 6.4 计算模型

| 计算项 | 输入 | 输出 |
| --- | --- | --- |
| `scheduledDoses` | plans + boxes + records + date | 当日全部应执行剂次 |
| `pendingDoses` | `scheduledDoses` | 未完成剂次 |
| `completedDoses` | `scheduledDoses` | 已完成剂次 |
| `asNeededDoses` | 全部计划 + 药箱映射 + 选中日 | 按需用药展示项 |
| `progress` | 某日的记录集合 | 0 到 1 的进度值 |

## 7. UI 设计对齐

### 7.1 页面骨架

鸿蒙端的页面结构应与 iOS 保持同一层级语义：

```text
ScrollView
  └─ VStack / Column
      ├─ 日期标题区
      ├─ 日期条区
      ├─ 待执行用药区
      ├─ 已完成用药区
      └─ 按需用药区
```

### 7.2 日期条视觉结构

`legacyDateStripFallback` 的视觉骨架应保持为：

1. 顶部分割线。
2. 向下三角指示器。
3. 水平滚动日期条。
4. 每个日期项包含星期、日期和圆环/圆点进度。
5. 选中态与未选中态有明确视觉区分。
6. 日期条整体固定高度，不随内容抖动。

### 7.3 日期圆环状态

每个日期项至少要有以下状态：

| 状态 | 视觉语义 |
| --- | --- |
| 未加载 | 灰色弱化，不应伪装成已知进度 |
| 已加载但无记录 | 空态或低亮度空圆 |
| 有部分完成 | 部分填充 |
| 已全部完成 | 满圆/高完成度 |
| 当前选中日 | 额外高亮，通常连同星期文本或底部指示符强调 |

### 7.4 页面层级关系

```text
标题
日期条
待执行卡片
已完成卡片
按需用药卡片
```

如果鸿蒙端后续拆成多个子组件，也必须维持这个视觉顺序，不要把日期条塞到卡片内部，也不要把记录区拆成和 iOS 不同的主层级。

## 8. `legacyDateStripFallback` 逐行翻译约束

### 8.1 入口分支

iOS 的 `dateStrip` 当前已经把 `ios17DateStrip` 注释掉，实际只走 `legacyDateStripFallback`。

这在鸿蒙端的要求不是“也写一个分支判断”，而是：

1. 直接只保留 legacy 路径。
2. 不保留可切换的 iOS 17 分支。
3. 不设计双实现并存。

### 8.2 逐段对齐表

| iOS 行段 | iOS 行为 | 鸿蒙实现要求 |
| --- | --- | --- |
| 286-293 | `dateStrip` 仅作为单一入口，当前只返回 legacy fallback | 鸿蒙只保留一个日期条入口，内部直接使用 legacy 版实现 |
| 414-420 | 容器 + 分割线 + 三角指示器 | 使用 ArkUI 容器、分割线和顶部指示标记，视觉顺序不变 |
| 421-430 | legacy 滚动容器，接收条目、选中日期、延迟加载标记、宽度、间距和提交回调 | 鸿蒙滚动容器必须能接收同等语义参数，并在拖动结束时提交日期变更 |
| 431-449 | 日期点渲染，读取选中态、加载态、按日进度 | 圆环/圆点状态必须按日缓存读取，不允许从全局单日记录推断 |
| 451-454 | 固定高度容器包裹整个日期条 | 鸿蒙高度策略必须固定，避免页面上下抖动 |
| 457-470 | 提交日期后延迟请求，取消旧任务，加载新窗口，恢复延迟闸门 | 鸿蒙必须保留“滚动确认后再请求”的节奏，防止频繁切换导致网络风暴 |

### 8.3 明确禁止的翻译方式

以下做法都不合格：

1. 只翻译 UI，不翻译日期窗口缓存。
2. 只翻译选中态，不翻译按日进度。
3. 只翻译 ScrollView，不翻译提交节流。
4. 用单个 `records` 替代 `recordsByDayID`。
5. 为了省事把 `ios17DateStrip` 也一起做掉。

### 8.4 关键代码示意

下面是鸿蒙端建议的目标结构示意，不是要直接照搬 iOS 语法，而是要照搬行为：

```ts
@Component
struct MedicationExecutionDateStrip {
  @Prop selectedDate: Date
  @Prop recordsByDayID: Record<string, RemoteMedicationRecord[]>
  @Prop loadedWindow?: DateWindow
  @Prop onCommit: (date: Date) => void

  build() {
    Column() {
      Divider()
      TriangleIndicator()
      MedicationExecutionLegacyDateStripScrollView({
        items: this.dateStripDays,
        selectedDate: this.selectedDate,
        itemWidth: MEDICATION_DATE_STRIP_ITEM_WIDTH,
        itemSpacing: MEDICATION_DATE_STRIP_ITEM_SPACING,
        onCommit: (date: Date) => this.onCommit(date),
        renderItem: (item: MedicationExecutionDateItem) => {
          const progress = MedicationExecutionPlanner.progress(
            this.plans,
            this.medicineBoxes,
            MedicationExecutionRecordCache.recordsFor(item.date, this.recordsByDayID),
            item.date,
            this.calendar
          )
          return MedicationExecutionDateDot({
            date: item.date,
            isSelected: isSameDay(item.date, this.selectedDate),
            isLoaded: this.isDateInLoadedWindow(item.date),
            progress,
            calendar: this.calendar
          })
        }
      })
    }
  }
}
```

这段示意里最重要的不是语法，而是三个约束：

1. `onCommit` 不能省。
2. `recordsByDayID` 不能省。
3. `progress` 不能脱离按日缓存单独算。

## 9. 加载与缓存策略

### 9.1 窗口模型

本工单建议的窗口范围是：

```text
选中日 - 4 天  ~  选中日 + 4 天
```

总共 9 天。

### 9.2 加载原则

1. 初次进入页面时，先以当前选中日为中心加载窗口。
2. 窗口内切换日期不重复请求。
3. 超出窗口切换时重新加载新窗口。
4. 请求中的旧任务必须可取消。
5. 已完成和待执行区域只读取选中日的数据。

### 9.3 状态流转

```text
进入页面
  -> 初始化 selectedDate
  -> 计算 selectedDayStart
  -> 读取 initialRecords 或已有缓存
  -> 请求 selectedDate 前后 4 天窗口
  -> 写入 recordsByDayID
  -> 日期条和记录区同时刷新

滚动日期条
  -> 更新选中项
  -> 触发 commit
  -> 延迟短暂等待
  -> 决定是否重载窗口
  -> 若重载则更新 recordsByDayID 和 loadedWindow
```

### 9.4 为什么必须要窗口缓存

如果只保存单日记录，会发生三个问题：

1. 顶部日期条无法稳定显示相邻天的进度。
2. 用户向前后切换日期时每次都要重新请求。
3. 保存记录后相邻日期圆环无法即时体现整体状态。

因此，窗口缓存不是优化项，而是这个页面的数据基础。

## 10. 记录区与完成区对齐

### 10.1 待执行区

待执行区需要按时间分组展示，并与选中日保持一致。

要求：

1. 先按时间段分组。
2. 每组内仍保留剂次序号。
3. 有待执行剂次时显示卡片列表。
4. 无待执行剂次时显示全完成态。

### 10.2 已完成区

已完成区只在存在完成或跳过记录时显示。

要求：

1. 展示完成记录的时间、状态和对应剂次。
2. 不抢占待执行区的视觉主位。
3. 保存后立即同步刷新。

### 10.3 按需用药

按需用药卡片的规则保持为：

1. 只有存在成员上下文和家用药箱能力时才展示。
2. 不是固定入口，属于条件显示。
3. 点击后打开记录 Sheet 或等价提交入口。

## 11. 关键技术点

### 11.1 进度计算必须按日

`MedicationExecutionPlanner.progress(...)` 的核心不是“当前页面全部记录”，而是“某一天的记录集合”。

鸿蒙端应确保：

1. 每个日期项传入对应日期的记录集合。
2. 不能把当前选中日记录硬塞给所有日期项。
3. 进度圆环与列表共享同一份按日缓存。

### 11.2 选中态和滚动态要解耦

滚动条的位置变化不应该直接等于数据刷新完成。

正确做法是：

1. 滚动先更新临时选中意图。
2. 提交后再决定是否加载新窗口。
3. 加载完成后再刷新页面状态。

### 11.3 取消旧任务

快速左右滑动日期条时，前一次请求可能还没返回。

必须保证：

1. 旧请求不回写新选中日。
2. 旧任务可取消。
3. `loadingWindowID` 或等价机制能去重。

### 11.4 只做 legacy fallback 的收益

只做 legacy fallback 的好处不是“偷工减料”，而是：

1. 缩小鸿蒙首版风险面。
2. 与 iOS 当前实际可见路径对齐。
3. 避免同时维护两套日期条行为。
4. 把精力集中到“窗口缓存 + 进度 + 提交流程”这些真正影响体验的核心上。

## 12. 验收标准

### 12.1 功能验收

1. 页面可展示用药执行中心主视图。
2. 日期条可左右滚动。
3. 点击或滚动日期后，选中日期、标题和记录区同步更新。
4. 顶部日期圆环能展示不同日期的完成进度。
5. 记录提交流程可回写当前页面状态。
6. 已完成区在有记录时正常展示。
7. 按需用药入口按条件显示。

### 12.2 边界验收

1. 页面不包含 `ios17DateStrip` 的任何实现或等价分支。
2. 日期条只保留 legacy fallback 路径。
3. 窗口内切换不重复请求。
4. 窗口外切换会重载新窗口。
5. 保存后相关日期进度即时刷新。

### 12.3 结构验收

1. 目标目录明确归入 `首页、成员与医疗画像/药箱/用药模块/`。
2. 数据模型、目录结构、UI 结构和 iOS 事实基线一致。
3. 工单能够直接指导后续实现，不依赖读者脑补。

## 13. 风险与注意事项

### 13.1 风险

| 风险 | 说明 | 规避方式 |
| --- | --- | --- |
| 误做 iOS 17 分支 | 容易把 `ios17DateStrip` 当成“更现代方案”一起补上 | 工单中明确禁止，代码评审时也要拒绝 |
| 单日缓存误用 | 会导致日期条进度错乱 | 统一按 `recordsByDayID` 驱动 |
| 滚动请求抖动 | 快速滑动导致大量请求 | 使用延迟提交、取消旧任务和窗口去重 |
| 视觉偏差 | 日期条高度、指示器和选中态容易跑偏 | 先对齐层级，再对齐像素 |
| 状态回写错位 | 旧请求覆盖新页面数据 | 引入请求令牌或等价机制 |

### 13.2 不要做的事

1. 不要把日期条直接做成普通横向列表。
2. 不要把记录区和日期条拆成两个互不关联的数据源。
3. 不要为了省事把选中态和加载态混成一个字段。
4. 不要把 `legacyDateStripFallback` 简化成“任意一个能横滑的控件”。
5. 不要顺手实现 `ios17DateStrip`。

## 14. 建议的后续实施顺序

1. 先建鸿蒙端用药执行中心目标目录和页面骨架。
2. 再补数据模型和记录窗口缓存。
3. 然后实现 legacy 日期条。
4. 接着对齐待执行区和已完成区。
5. 最后补记录提交流程和按需用药入口。

## 15. 结论

本工单只确认一件事：

> 鸿蒙端要实现与 iOS 用药执行中心相同的核心体验，但日期条只落地 `legacyDateStripFallback`，不实现 `ios17DateStrip`。

只要后续实现遵守下面三条，就算对齐方向正确：

1. 日期条只走 legacy 路径。
2. 进度来自按日缓存。
3. 页面状态围绕选中日期和加载窗口流转。
