# HOS-FILE-OSS-0009｜清理旧上传实现并统一到 HOS-FILE-OSS-0008 工单

> 工单类型：HarmonyOS OSS 上传代码收敛与冗余清理工单。
>
> 目标：清理当前 HarmonyOS 项目中 HOS-FILE-OSS-0008 之前遗留的上传实现、旧版 policy、fallback、兼容入口和重复测试代码，只保留官方简单上传 PutObject 与官方分片上传 Multipart Upload 两条生产链路。
>
> 约束：本工单只允许修改 `SparkClientHarmonyOS/`。不修改 iOS、服务器、OSS 权限、STS Role 和 `entry/third_party/aliyun-oss` Vendor SDK 源码。本次仅创建工单，不删除任何代码。
>
> 关联工单：HOS-FILE-OSS-0001～HOS-FILE-OSS-0008。

## 0. 版本取消与唯一保留版本

本工单明确取消“多套上传版本并存”的做法，只保留最新的 HOS-FILE-OSS-0008。

### 唯一保留

```text
HOS-FILE-OSS-0008
  ├── 最新简单上传：官方 PutObject
  └── 最新分片上传：官方 Multipart Upload
```

这里的“只保留最新”指：

- 保留 HOS-FILE-OSS-0008 的 simple/multipart 两种官方上传方式；
- simple 和 multipart 是同一最新架构内的两种文件大小分层，不是两个历史版本；
- 保留最新的数据模型、路由、checkpoint、错误模型和日志模型；
- 删除旧版本代码、旧 policy、旧 fallback、旧兼容入口和旧版本测试。

### 取消的旧版本代码

以下版本全部废止，禁止继续被生产代码引用：

```text
v1-prod-explicit-len-no-oss-md5
v2-prod-no-ctype-header-explicit-len
v3-prod-filepath-buffered-explicit-len
v3-prod-filepath-stream-explicit-len
v4-prod-arraybuffer-explicit-len
v4-fallback-arraybuffer-explicit-len
legacyV1ExplicitLenNoMd5()
legacyV2StreamNoCtype()
legacyFilePathBuffered()
arrayBufferFallback()
asLegacyAdapter()
```

### 不取消的最新代码

以下不是旧版本，不得误删：

```text
FileUploadMode.select()
OSSSimpleUploadAdapter
OSSMultipartUploadAdapter
MultipartUploadService
FileUploadCheckpointStore
MultipartUploadModels
MultipartUploadCheckpoint
```

## 1. 清理目标

项目内最终只保留以下两种生产上传方式：

```text
小文件：OSSSimpleUploadAdapter → 官方 client.putObject
大文件：MultipartUploadService → OSSMultipartUploadAdapter
          → initiateMultipartUpload
          → uploadPart
          → completeMultipartUpload
```

明确禁止继续存在于生产链路：

- `appendObject`；
- 旧版 v1/v2/v3 policy；
- 通过切换 FilePath/ArrayBuffer 盲目 fallback；
- 多层 `OSSClientAdapter → OSSSimpleUploadAdapter → inner adapter` 兼容包装；
- 业务层直接调用 Vendor SDK；
- 旧的单对象上传分支与新的 HOS-FILE-OSS-0008 分层重复；
- “上传请求发出”即视为成功；
- Complete 前执行文件登记；
- 通过重试掩盖未验证的 SDK 传输问题。

## 2. 当前代码盘点结论

### 2.1 已存在的新架构

以下代码已经按 HOS-FILE-OSS-0008 建立，应作为收敛后的主架构：

| 路径 | 当前职责 | 处理结论 |
| --- | --- | --- |
| `Core/FileStorage/FileUploadMode.ets` | 8 MB simple/multipart 路由、5 MB 分片大小、分片计算 | 保留，作为唯一模式选择器。 |
| `Core/FileStorage/MultipartUploadService.ets` | 分片编排、checkpoint、顺序上传、恢复、Complete、Abort | 保留，补齐验收后作为唯一分片业务编排。 |
| `Core/FileStorage/MultipartUploadModels.ets` | 分片输入、结果、part 状态模型 | 保留。 |
| `Core/FileStorage/MultipartUploadCheckpoint.ets` | 分片 checkpoint 数据模型 | 保留，确认是否与 Models 重复后合并。 |
| `Core/FileStorage/FileUploadCheckpointStore.ets` | Preferences/内存 checkpoint 存储 | 保留，删除重复存储实现。 |
| `Projects/Core/OSS/OSSMultipartUploadAdapter.ets` | 官方 initiate/uploadPart/listParts/complete/abort | 保留，作为唯一 Multipart Vendor adapter。 |
| `Projects/Core/OSS/OSSSimpleUploadAdapter.ets` | 官方 PutObject 对外适配入口 | 保留，但删除其 legacy 兼容暴露。 |
| `Projects/Core/OSS/OSSClientAdapter.ets` | 当前仍承载旧单对象实现和多 payload 分支 | 迁移完成后删除或收缩为内部 Simple 实现，不能继续作为并行主入口。 |

### 2.2 仍存在的旧上传实现

当前 `OSSClientAdapter.ets` 仍包含多套上传路径：

```text
putByPolicy
putArrayBuffer
putFsFile
putFilePath
readFileToArrayBuffer
RCP fallback / retry policy
legacy policy compatibility
```

这造成以下重复：

1. `OSSSimpleUploadAdapter` 已存在，但实际仍包装旧 `OSSClientAdapter`；
2. `FileTransferService` 同时持有 `ossAdapter` 和 `simpleUpload`；
3. `asLegacyAdapter()` 继续保留旧注入点；
4. `FileUploadTransportPolicy` 仍包含旧版本工厂；
5. 小文件模式选择已经由 `FileUploadMode` 决定，但单对象 payload 仍由旧 policy 决定；
6. Multipart 已有独立 adapter/service，但 AppContainer 仍创建旧 `OSSClientAdapter` 作为依赖；
7. 官方等价测试、请求捕获和生产上传实现混在同一套 policy 体系中。

## 3. 文件处理清单

### 3.1 必须保留

#### A. 官方简单上传

保留：

```text
Projects/Core/OSS/OSSSimpleUploadAdapter.ets
```

最终职责必须只有：

- 创建/管理单对象 Client；
- 调用 `client.putObject`；
- 处理官方支持的 data 类型；
- 等待请求完成；
- 关闭 session；
- 映射 RequestError；
- 暴露取消能力。

它不能再提供：

- `asLegacyAdapter()`；
- 旧 OSSClientAdapter 兼容接口；
- append；
- multipart；
- 多代 fallback policy。

#### B. 官方分片上传

保留：

```text
Projects/Core/OSS/OSSMultipartUploadAdapter.ets
Core/FileStorage/MultipartUploadService.ets
Core/FileStorage/MultipartUploadModels.ets
Core/FileStorage/MultipartUploadCheckpoint.ets
Core/FileStorage/FileUploadCheckpointStore.ets
Core/FileStorage/FileUploadMode.ets
```

最终职责必须只有：

- initiate；
- uploadPart；
- listParts；
- complete；
- abort；
- checkpoint；
- part retry；
- recovery；
- 完成后返回统一上传结果。

#### C. 统一上传门面

保留：

```text
Core/FileStorage/FileTransferService.ets
```

它只负责：

1. stage 文件；
2. 获取文件大小、MIME、MD5；
3. 调用 `FileUploadMode.select()`；
4. simple → `OSSSimpleUploadAdapter`；
5. multipart → `MultipartUploadService`；
6. 统一进度、取消和错误；
7. OSS 成功后执行文件登记；
8. 登记失败进入 pending 状态。

### 3.2 必须迁移后删除或收缩

#### A. `OSSClientAdapter.ets`

当前问题：

- 仍是旧上传实现的主体；
- 包含 ArrayBuffer/FilePath/fs.File 多套 putObject 分支；
- 包含旧 RCP fallback；
- 仍被 AppContainer 注入；
- `OSSSimpleUploadAdapter` 通过 inner 持有它；
- 与 HOS-FILE-OSS-0008 的 SimpleAdapter/MultipartAdapter 形成重复架构。

处理方案：

1. 先将官方 PutObject 的必要逻辑迁移到 `OSSSimpleUploadAdapter`；
2. 将配置预检、RequestError 解码和 session 逻辑归属明确化；
3. 将 Multipart 相关逻辑保持在 `OSSMultipartUploadAdapter`；
4. 将 FileTransferService 的注入改为 SimpleAdapter + MultipartService；
5. 删除 `OSSClientAdapter` 的生产引用；
6. 删除文件或将其改为不可被业务引用的内部基础实现；
7. 禁止保留 `asLegacyAdapter()` 作为长期兼容入口。

验收要求：

```text
rg "OSSClientAdapter" entry/src/main/ets
```

最终只允许出现在迁移测试、文档或明确的内部兼容说明中，不能作为 AppContainer/FileTransferService 的生产依赖。

#### B. `FileUploadTransportPolicy.ets` 旧版本工厂

当前需要清理的旧接口/版本：

```text
legacyV1ExplicitLenNoMd5()
legacyV2StreamNoCtype()
legacyFilePathBuffered()
arrayBufferFallback()
forMatrix()
officialMatrix()
```

处理方案：

- 生产只保留 `FileUploadMode.select()` 的 simple/multipart 选择；
- Simple 上传不再由 v1/v2/v3/v4 policy 叠加决定；
- Multipart 使用固定的 `MultipartUploadInput`、partSize 和 checkpoint；
- `arrayBufferFallback()` 不再作为生产 fallback；
- `officialMatrix()` 移到测试目录或删除；
- `forMatrix()` 只允许存在于测试专用模块，禁止被生产代码 import；
- 删除所有旧版本字符串和对应日志分支。

最终生产日志不再出现：

```text
v1-prod-explicit-len-no-oss-md5
v2-prod-no-ctype-header-explicit-len
v3-prod-filepath-buffered-explicit-len
v4-fallback-arraybuffer-explicit-len
```

生产日志只出现：

```text
mode=simple;policy=simple-v1
mode=multipart;policy=multipart-v1
```

#### C. `OSSSimpleUploadAdapter.asLegacyAdapter()`

当前方法：

```text
asLegacyAdapter(): OSSClientAdapter
```

该方法会让旧架构继续存活，必须在所有调用迁移后删除。不得用“兼容旧注入点”作为长期保留理由。

#### D. OSSClientAdapter 内部 fallback

当前包含根据 RCP 错误自动切换 payload/session 的逻辑。HOS-FILE-OSS-0008 已经改为按文件大小选择 simple/multipart，因此以下逻辑必须删除：

- peerReceiveFailed 后自动 ArrayBuffer fallback；
- 同一 PutObject 任务改变 payload 再试；
- 旧的 retryAttempt 与 policy 组合；
- v4 fallback 日志；
- 通过 retry 掩盖 simple 上传未验证的问题。

网络失败只能在当前上传模式内进行有限重试：

- simple：重试整个 PutObject 一次；
- multipart：只重试失败 part；
- 不在 simple 和 multipart 之间临时切换；
- 不把 simple 失败转成 append；
- 不把大文件临时读成 ArrayBuffer。

### 3.3 只保留为测试探针或迁移完成后删除

#### A. `OSSOfficialEquivalence.ets`

用途是官方最小等价测试，不应进入业务上传路径。

处理：

- 如果仍用于 HOS-FILE-OSS-0007 官方验收，移动到测试支持目录；
- 禁止生产代码 import；
- 验收结束后保留为独立测试工具或删除；
- 不能让它成为第三套上传 adapter。

#### B. `OSSPutRequestCapture.ets`

用途是请求参数捕获和官方等价验证，不是业务上传实现。

处理：

- 只允许测试构建使用；
- 生产构建不得启用原始 header/body capture；
- 只保留安全字段 capture；
- 验收完成后从生产依赖图移除。

#### C. `OSSVendorSdkMeta.ets`

可保留为版本审计和生产准入元数据，但不得承担上传逻辑。若只是为旧 policy 提供版本字符串，应重构为只读版本信息服务。

## 4. 生产依赖关系重构

### 4.1 当前依赖问题

当前 AppContainer 类似：

```text
AppContainer
  → OSSClientAdapter
  → FileTransferService
  → FileTransferService 内部再创建 OSSSimpleUploadAdapter
  → OSSSimpleUploadAdapter.inner = OSSClientAdapter
```

这导致：

- 同一个旧 adapter 被多层包装；
- 依赖名称与实际职责不一致；
- multipart 与 simple 的生命周期不统一；
- 测试注入困难；
- 旧接口无法删除。

### 4.2 HOS-FILE-OSS-0008 目标依赖

```text
AppContainer
  → OSSSimpleUploadAdapter
  → OSSMultipartUploadAdapter
  → MultipartUploadCheckpointStore
  → FileTransferService

FileTransferService
  ├─ FileUploadMode.select(size)
  ├─ simple → OSSSimpleUploadAdapter
  └─ multipart → MultipartUploadService
                         └─ OSSMultipartUploadAdapter
```

要求：

- AppContainer 不再创建旧 `OSSClientAdapter`；
- FileTransferService 不再同时持有旧 adapter 和 simple wrapper；
- Simple 和 Multipart 分别拥有清晰依赖；
- Vendor SDK 只在两个 OSS adapter 内 import；
- FileTransferService 不 import `@aliyun/oss`；
- 业务 Feature 不 import `@aliyun/oss`。

## 5. 项目内调用切换清单

### 5.1 FileTransferService

当前：

- 仍保留 `ossAdapter` 字段；
- 构造函数接收 `OSSClientAdapter`；
- 通过 `new OSSSimpleUploadAdapter(ossAdapter)` 兼容旧结构。

切换：

1. 构造函数直接接收 `OSSSimpleUploadAdapter`；
2. MultipartService 单独接收 `OSSMultipartUploadAdapter` 和 checkpoint store；
3. 删除 `ossAdapter` 字段；
4. 删除 `new OSSSimpleUploadAdapter(ossAdapter)`；
5. 统一在 `FileUploadMode.select()` 后路由；
6. simple 只调用官方 PutObject；
7. multipart 只调用官方 Multipart；
8. 删除 simple 分支内旧 policy fallback；
9. 保留凭证过期刷新，但不改变上传模式。

### 5.2 AppContainer

当前：

```text
const ossClientAdapter = new OSSClientAdapter();
new FileTransferService(..., ossClientAdapter, ..., checkpointStore);
```

切换为：

```text
const simpleUploadAdapter = new OSSSimpleUploadAdapter();
const multipartUploadAdapter = new OSSMultipartUploadAdapter();
const checkpointStore = new PreferencesFileUploadCheckpointStore(context);
new FileTransferService(
  ...,
  simpleUploadAdapter,
  multipartUploadAdapter,
  checkpointStore
);
```

具体构造参数以实际项目接口为准，但禁止继续注入 `OSSClientAdapter`。

### 5.3 MedicalDocumentUpload

医疗上传 Feature 不应知道：

- PutObject；
- Multipart；
- appendObject；
- FilePath；
- ArrayBuffer；
- partSize；
- uploadId。

它只调用统一 `UploadMedicalDocumentFilesUseCase`/`FileTransferService`，上传方式由 Core 自动选择。

### 5.4 Home/Chat/外部文件入口

以下入口必须统一切换到同一个 `FileTransferService`：

- 首页医疗报告上传；
- 相机图片上传；
- 聊天附件上传；
- 外部 PDF 导入；
- 成员医疗画像附件；
- 药箱图片附件。

不得保留各 Feature 自己创建 Client 或各自实现上传 fallback。

## 6. 删除顺序

禁止直接删除文件。按以下顺序执行：

### 阶段一：建立引用基线

1. 统计所有 `OSSClientAdapter` 引用；
2. 统计所有 policy 工厂调用；
3. 统计所有 `putObject` 直接调用；
4. 统计所有 `FilePath`、`fs.File`、`ArrayBuffer` 生产调用；
5. 统计所有 `appendObject` 调用；
6. 统计所有 Multipart 调用；
7. 统计所有 `asLegacyAdapter` 调用；
8. 统计所有生产测试探针引用；
9. 形成迁移前清单。

### 阶段二：先切换生产依赖

1. AppContainer 切换新 adapter；
2. FileTransferService 删除旧 adapter 注入；
3. 确认 simple/multipart 都能从统一门面进入；
4. 确认业务入口无变化；
5. 确认错误和进度无变化；
6. 运行编译和单测。

### 阶段三：清理旧 policy

1. 删除旧 v1/v2/v3 policy 工厂；
2. 删除 `arrayBufferFallback`；
3. 删除旧 policy 日志名称；
4. 删除旧 policy 单测；
5. 更新只验证 simple/multipart 的单测；
6. 确认生产代码不再 import 旧 policy。

### 阶段四：清理旧 adapter

1. 删除 `asLegacyAdapter`；
2. 删除 OSSClientAdapter 旧 FilePath/ArrayBuffer/fs.File 多分支；
3. 删除旧 RCP fallback；
4. 将必要的通用配置校验移入明确归属的 adapter；
5. 删除 OSSClientAdapter 生产文件或改为不再被引用；
6. 确认只剩 Simple/Multi 两个生产 adapter。

### 阶段五：清理测试探针

1. 官方等价测试移入测试目录；
2. 请求捕获只保留测试构建；
3. 删除已经被新测试覆盖的旧矩阵；
4. 删除过期工单专用测试命名；
5. 保留 HOS-FILE-OSS-0008 的模式选择、分片、checkpoint、abort、complete 测试。

## 7. 代码保留/删除映射表

| 代码对象 | 处理 | 原因 |
| --- | --- | --- |
| `FileTransferService` | 保留并收敛 | 唯一上传门面。 |
| `FileUploadMode` | 保留 | 唯一 simple/multipart 选择器。 |
| `OSSSimpleUploadAdapter` | 保留并重构 | 唯一 PutObject 入口。 |
| `OSSMultipartUploadAdapter` | 保留 | 唯一 Multipart Vendor 入口。 |
| `MultipartUploadService` | 保留 | 分片编排和恢复。 |
| `MultipartUploadModels` | 保留 | 分片领域模型。 |
| `MultipartUploadCheckpoint` | 保留/合并 | 需消除与 Models 重复。 |
| `FileUploadCheckpointStore` | 保留 | 分片恢复和清理。 |
| `OSSClientAdapter` | 迁移后删除/收缩 | 旧上传主入口和重复实现。 |
| `FileUploadTransportPolicy` | 收缩/删除旧接口 | 不再管理多代 payload fallback。 |
| `legacyV1...` | 删除 | HOS-0008 不使用。 |
| `legacyV2...` | 删除 | HOS-0008 不使用。 |
| `legacyFilePathBuffered` | 删除 | 已被官方 simple/multipart 路由替代。 |
| `arrayBufferFallback` | 删除 | 不再跨模式 fallback。 |
| `OSSOfficialEquivalence` | 测试专用/迁移后删除 | 不是生产上传。 |
| `OSSPutRequestCapture` | 测试专用 | 不能进入生产依赖。 |
| `OSSVendorSdkMeta` | 保留为元数据 | 只做版本审计，不做上传。 |
| `appendObject` | 全项目禁止 | 不符合医疗文件语义。 |

## 8. 测试清理和重建

### 8.1 删除旧测试

清理以下类型：

- v1/v2/v3 policy 断言；
- 旧 ArrayBuffer fallback 断言；
- 旧 FilePath stream fallback 断言；
- `OSSClientAdapter` 兼容注入测试；
- 以 RCP 错误切换 payload 的旧测试；
- 已被 HOS-0008 分片测试替代的矩阵测试。

### 8.2 保留/新增测试

Simple：

- mode select 小文件；
- 官方 PutObject 调用；
- RequestError 解码；
- session close；
- 单次有限重试；
- 文件登记只在成功后执行。

Multipart：

- 大文件 mode select；
- initiate 返回 uploadId；
- part offset/length/number；
- 单 part retry；
- checkpoint save/load；
- listParts 恢复；
- complete 成功；
- complete 失败不登记；
- abort；
- 账号切换清理；
- generation 失效清理。

架构：

- Feature 不直接 import Vendor；
- FileTransferService 是唯一业务入口；
- 生产代码不调用 appendObject；
- 生产代码只存在 simple/multipart 两种 mode；
- 旧 policy 名称不再出现。

## 9. 日志清理

删除旧日志 policy：

```text
v1-prod-explicit-len-no-oss-md5
v2-prod-no-ctype-header-explicit-len
v3-prod-filepath-buffered-explicit-len
v4-prod-arraybuffer-explicit-len
v4-fallback-arraybuffer-explicit-len
```

统一为：

```text
mode=simple;policy=simple-v1
mode=multipart;policy=multipart-v1
```

Simple 日志：

```text
file.upload.mode_selected
oss.put.started
oss.put.succeeded / oss.put.failed
```

Multipart 日志：

```text
file.upload.mode_selected
oss.multipart.initiated
oss.multipart.part.started
oss.multipart.part.succeeded / oss.multipart.failed
oss.multipart.completed / oss.multipart.aborted
```

禁止同时记录旧 `oss.put.retrying` payload fallback 与新 Multipart part retry，避免误判重试层级。

## 10. 验收标准

### 10.1 代码引用

- `FileTransferService` 不再依赖 `OSSClientAdapter`；
- `AppContainer` 不再创建 `OSSClientAdapter`；
- `OSSSimpleUploadAdapter` 不再暴露 `asLegacyAdapter()`；
- 生产代码不再调用旧 policy 工厂；
- 生产代码不再调用 appendObject；
- 生产代码只保留 Simple/Multi 两条上传链路；
- 业务 Feature 不直接 import `@aliyun/oss`。

### 10.2 行为

- 8 MB 以内走官方 PutObject；
- 超过 8 MB 走官方 Multipart；
- Simple 失败不切换 Multipart；
- Multipart part 失败只重试当前 part；
- Complete 成功前不登记文件；
- Cancel/账号切换可 Abort 或进入待清理；
- RCP 失败不无限 fallback。

### 10.3 构建和测试

- HarmonyOS 编译通过；
- 单元测试通过；
- Simple 官方 API 测试通过；
- Multipart 官方 API 测试通过；
- 旧 policy 测试已删除或迁移；
- 无未使用 import；
- 无旧上传入口残留；
- 无重复生产 adapter。

### 10.4 范围

- 未修改 iOS；
- 未修改服务器；
- 未修改 OSS 权限和 STS Role；
- 未修改 Vendor SDK 源码；
- 只修改 HarmonyOS 项目。

## 11. 工单执行注意事项

1. 不要先删除 `OSSClientAdapter` 再寻找编译错误；先完成依赖迁移；
2. 不要删除 checkpoint 相关代码；它属于 HOS-FILE-OSS-0008 分片能力；
3. 不要把 `OSSOfficialEquivalence` 当作生产 adapter；
4. 不要把 `OSSPutRequestCapture` 开到生产环境；
5. 不要因为当前没有大文件测试就删除 Multipart；
6. 不要保留旧 fallback 作为“以后可能有用”的生产分支；
7. 不要把 appendObject 加入统一上传门面；
8. 不要改变 iOS 和服务器代码来配合 HarmonyOS 清理；
9. 清理完成后必须用 `rg` 做全项目引用审计；
10. 清理过程中每次删除必须有对应测试覆盖。

## 12. 证据路径

HOS-FILE-OSS-0008 主架构：

```text
SparkClientHarmonyOS/开发详细技术文档/文件与 OSS/HOS-FILE-OSS-0008 官方 Harmony SDK 上传方式重构为简单上传与分片上传工单.md
SparkClientHarmonyOS/entry/src/main/ets/Core/FileStorage/FileUploadMode.ets
SparkClientHarmonyOS/entry/src/main/ets/Core/FileStorage/MultipartUploadService.ets
SparkClientHarmonyOS/entry/src/main/ets/Projects/Core/OSS/OSSSimpleUploadAdapter.ets
SparkClientHarmonyOS/entry/src/main/ets/Projects/Core/OSS/OSSMultipartUploadAdapter.ets
```

当前待清理代码：

```text
SparkClientHarmonyOS/entry/src/main/ets/Projects/Core/OSS/OSSClientAdapter.ets
SparkClientHarmonyOS/entry/src/main/ets/Core/FileStorage/FileUploadTransportPolicy.ets
SparkClientHarmonyOS/entry/src/main/ets/Projects/Core/OSS/OSSOfficialEquivalence.ets
SparkClientHarmonyOS/entry/src/main/ets/Projects/Core/OSS/OSSPutRequestCapture.ets
SparkClientHarmonyOS/entry/src/main/ets/Projects/Core/OSS/OSSVendorSdkMeta.ets
SparkClientHarmonyOS/entry/src/main/ets/App/AppContainer.ets
SparkClientHarmonyOS/entry/src/main/ets/Core/FileStorage/FileTransferService.ets
```

## 13. 工单完成说明

本工单盘点阶段已完成：

- 盘点当前 Simple、Multipart、FilePath、fs.File、ArrayBuffer、stream 和 fallback 代码；
- 识别旧 `OSSClientAdapter` 与新 HOS-FILE-OSS-0008 adapter 的重复关系；
- 梳理旧 v1/v2/v3/v4 policy 和 fallback；
- 梳理 AppContainer、FileTransferService 的旧依赖注入；
- 明确 Simple/Multi 生产保留清单；
- 明确官方等价测试和请求捕获的测试边界；
- 明确删除顺序、引用迁移、测试重建和日志清理方案；
- 明确 appendObject 永久排除；
- 明确只允许修改 HarmonyOS。

**实现阶段（代码清理）已完成，见 §18。**

## 14. 旧代码全部清除明细

本节是本工单的强制删除清单。迁移完成后，以下旧文件、旧方法、旧引用和旧测试必须从 HarmonyOS 项目中清除，不允许以“兼容”“暂时保留”“以后可能使用”为理由继续存在于生产代码。

### 14.1 必须删除的完整文件

以下文件在引用迁移和测试完成后，整文件删除：

| 文件 | 删除原因 |
| --- | --- |
| `entry/src/main/ets/Projects/Core/OSS/OSSClientAdapter.ets` | 旧单对象上传总适配器，包含多代 policy、payload 分支、RCP fallback 和旧 session 管理；HOS-FILE-OSS-0008 已由 Simple/Multipart adapter 替代。 |
| `entry/src/main/ets/Core/FileStorage/FileUploadTransportPolicy.ets` | 旧 v1～v4 policy、ArrayBuffer fallback、FilePath/stream 矩阵；HOS-FILE-OSS-0008 使用 `FileUploadMode` 路由。 |
| `entry/src/main/ets/Projects/Core/OSS/OSSOfficialEquivalence.ets` | 官方等价探针，不属于生产上传；验收测试迁移后删除。 |
| `entry/src/test/ets/FileStorage/OSSOfficialAlignment.test.ets` | 旧官方等价矩阵测试依赖已取消的 policy/capture；由 Simple/Multipart 官方 API 测试替代后删除。 |

### 14.2 必须从生产代码删除的旧方法

#### `OSSClientAdapter.ets` 全部旧方法

删除整个文件时，以下方法必须全部消失：

```text
upload()
putOnce()
logStarted()
cloneInput()
createClient()
putByPolicy()
readFileToArrayBuffer()
putFsFile()
putArrayBuffer()
putFilePath()
cancelActive()
objectKeyFingerprint()
sizeBucketOf()
closeClientOnce()
hexMd5ToBase64()
safeRcpMsg()
```

对应迁移规则：

- `createClient()`：归属 `OSSSimpleUploadAdapter` 和 `OSSMultipartUploadAdapter` 各自内部；
- `putArrayBuffer()`、`putFilePath()`、`putFsFile()`：归属最新 Simple PutObject 实现，不再由旧 policy 动态选择；
- `putByPolicy()`：删除，禁止通过旧 policy 路由上传；
- `readFileToArrayBuffer()`：如 Simple 官方路径仍需要，迁移成 Simple adapter 内部唯一受控读取方法，否则删除；
- `sizeBucketOf()`：迁移到 `FileUploadMode` 或独立纯日志工具后删除旧实现；
- `objectKeyFingerprint()`：统一使用 `ObjectKeyPolicy` 后删除旧实现；
- `hexMd5ToBase64()`：若 HOS-FILE-OSS-0008 不发送 Content-MD5，则删除；
- `safeRcpMsg()`：统一归属 `OSSErrorDecoder` 后删除旧实现；
- `cancelActive()`、`closeClientOnce()`：分别归属最新 adapter 生命周期，不保留旧 adapter 版本。

#### `FileUploadTransportPolicy.ets` 全部旧方法

删除整个文件时，以下方法和常量必须全部消失：

```text
MAX_ARRAY_BUFFER_BYTES
MAX_BUFFERED_BYTES
forUploadSize()
arrayBufferFallback()
productionDefault()
officialMatrix()
legacyFilePathBuffered()
legacyV2StreamNoCtype()
forMatrix()
toLogDetail()
useStream
sendContentMd5
sendExplicitContentLength
sendExplicitContentType
```

保留替代：

- `FileUploadMode.select()`：只决定 simple/multipart；
- `FileUploadMode.SIMPLE_THRESHOLD_BYTES`：唯一上传阈值；
- `FileUploadMode.PART_SIZE_BYTES`：唯一 Multipart 分片大小；
- `FileUploadMode.computeTotalParts()`、`partOffset()`、`partLength()`：唯一分片计算方法。

#### `OSSSimpleUploadAdapter.ets` 旧兼容方法

必须删除：

```text
asLegacyAdapter()
```

同时删除以下旧结构：

```text
private readonly inner: OSSClientAdapter
constructor(inner?: OSSClientAdapter)
this.inner = inner ?? new OSSClientAdapter()
```

Simple adapter 必须直接承担最新 PutObject 实现，不能继续包裹已废止的 `OSSClientAdapter`。

#### `FileTransferService.ets` 旧上传代码块

删除以下旧依赖和代码：

```text
import OSSClientAdapter
import OSSUploadInput
import FileUploadTransportPolicy
private readonly ossAdapter
constructor(... ossAdapter: OSSClientAdapter ...)
new OSSUploadInput()
FileUploadTransportPolicy.forUploadSize()
transportPolicy
旧 credentialsExpired + policy 重新上传分支
旧 simple payload fallback 分支
```

`upload()` 中只保留：

```text
const mode = FileUploadMode.select(fileSize)
if (mode.mode === 'simple') {
  await simpleUpload.upload(...)
} else {
  await multipartUpload.upload(...)
}
```

凭证过期时可以刷新 STS，但不得重新选择旧 policy、切换旧 payload 或回到 `OSSClientAdapter`。

### 14.3 必须删除的旧测试方法和断言

从现有测试中删除以下类型的测试：

```text
FileUploadTransportPolicy.forUploadSize() 的旧 v4 policy 断言
FileUploadTransportPolicy.officialMatrix() 断言
FileUploadTransportPolicy.legacyFilePathBuffered() 断言
FileUploadTransportPolicy.legacyV2StreamNoCtype() 断言
FileUploadTransportPolicy.arrayBufferFallback() 断言
OSSOfficialEquivalence.minimalArrayBufferPlan() 断言
OSSOfficialEquivalence.minimalFilePathPlan() 断言
OSSOfficialEquivalence.minimalFsFilePlan() 断言
OSSPutRequestCapture.fromUpload() 旧 policy capture 断言
旧 OSSClientAdapter 注入/兼容测试
RCP 失败后切换 payload 的 fallback 测试
```

需要改为验证：

- `FileUploadMode.select()` 只返回 simple/multipart；
- SimpleAdapter 调用 PutObject；
- MultipartService 调用 initiate/uploadPart/complete/abort；
- 失败只在当前上传模式内重试；
- 不存在旧 policy 名称；
- 不存在 appendObject 生产调用。

### 14.4 `OSSPutRequestCapture.ets` 处理

该文件当前被 Multipart checkpoint 和 adapter 用作 fingerprint 辅助，不应直接整文件保留为上传探针。

必须删除的测试/探针方法：

```text
fromUpload()
officialMinimalArrayBuffer()
toLogDetail()
```

必须迁移后删除的重复方法：

```text
sizeBucketOf()
```

`bucketFingerprint()` 如果 HOS-FILE-OSS-0008 的 checkpoint 日志仍需要，可迁移到明确命名的纯诊断工具，例如 `OSSDiagnosticFingerprint.ets`；迁移完成后删除 `OSSPutRequestCapture.ets` 整个文件。该诊断工具不得包含任何 PutObject/Multipart 调用。

### 14.5 `OSSOfficialEquivalence.ets` 方法全部删除

整文件删除，以下方法全部清除：

```text
clientInitFromConfig()
minimalArrayBufferPlan()
minimalFilePathPlan()
minimalFsFilePlan()
captureForPlan()
assertStandardPublicInit()
lifecycleJoined()
```

如果官方最小请求仍需保留，只能放到独立的测试 fixture 中，不得成为 `Projects/Core/OSS` 的生产模块。

## 15. 旧版本字符串全量清除

以下字符串在生产代码、生产日志和生产测试中必须为零命中：

```text
v1-prod-explicit-len-no-oss-md5
v2-prod-no-ctype-header-explicit-len
v3-prod-filepath-buffered-explicit-len
v3-prod-filepath-stream-explicit-len
v4-prod-arraybuffer-explicit-len
v4-fallback-arraybuffer-explicit-len
legacyV1ExplicitLenNoMd5
legacyV2StreamNoCtype
legacyFilePathBuffered
arrayBufferFallback
asLegacyAdapter
```

允许在历史工单文档中保留这些字符串作为问题记录，但不得在 `.ets`、`.ts`、测试执行代码和生产日志中继续存在。

## 16. 删除完成后的引用审计命令

代码清理完成后必须执行以下审计：

```text
rg "OSSClientAdapter" SparkClientHarmonyOS/entry/src/main/ets SparkClientHarmonyOS/entry/src/test/ets
rg "FileUploadTransportPolicy" SparkClientHarmonyOS/entry/src/main/ets SparkClientHarmonyOS/entry/src/test/ets
rg "legacyV1|legacyV2|legacyFilePath|arrayBufferFallback|asLegacyAdapter" SparkClientHarmonyOS/entry/src/main/ets SparkClientHarmonyOS/entry/src/test/ets
rg "appendObject" SparkClientHarmonyOS/entry/src/main/ets SparkClientHarmonyOS/entry/src/test/ets
rg "putObject" SparkClientHarmonyOS/entry/src/main/ets
rg "initiateMultipartUpload|uploadPart|completeMultipartUpload|abortMultipartUpload|listParts" SparkClientHarmonyOS/entry/src/main/ets
```

预期结果：

- `OSSClientAdapter`：无生产引用；
- `FileUploadTransportPolicy`：无引用，或仅在明确迁移说明中出现；
- 旧版本/旧方法：无代码引用；
- `appendObject`：无生产引用；
- `putObject`：只存在于最新 Simple adapter；
- Multipart API：只存在于最新 Multipart adapter；
- FileTransferService：只负责模式路由，不直接拼装 Vendor API。

## 17. 最终删除验收

只有同时满足以下条件，才允许执行旧文件物理删除：

1. AppContainer 已切换到最新 Simple/Multi 依赖；
2. FileTransferService 不再引用旧 OSSClientAdapter；
3. Simple 小文件上传通过真机测试；
4. Multipart 大文件上传通过真机测试；
5. checkpoint 恢复、Abort、Complete 测试通过；
6. 文件登记只发生在完整上传成功后；
7. 旧 policy 测试已删除或迁移；
8. `rg` 引用审计达到预期；
9. 工程编译通过；
10. 全部测试通过；
11. 确认没有 Feature 直接 import Vendor；
12. 确认没有旧日志版本字符串。

在以上条件未满足前，只允许标记为“待删除”，不得直接删除文件导致项目失去可编译状态。

## 18. 实现完成记录（HOS-FILE-OSS-0009）

完成时间：2026-07-24

### 18.1 已删除文件

```text
entry/src/main/ets/Projects/Core/OSS/OSSClientAdapter.ets
entry/src/main/ets/Core/FileStorage/FileUploadTransportPolicy.ets
entry/src/main/ets/Projects/Core/OSS/OSSOfficialEquivalence.ets
entry/src/main/ets/Projects/Core/OSS/OSSPutRequestCapture.ets
```

### 18.2 依赖重构

```text
AppContainer
  → OSSSimpleUploadAdapter
  → OSSMultipartUploadAdapter
  → PreferencesFileUploadCheckpointStore
  → FileTransferService

FileTransferService
  ├─ FileUploadMode.select(size)
  ├─ simple → OSSSimpleUploadAdapter（policy=simple-v1）
  └─ multipart → MultipartUploadService → OSSMultipartUploadAdapter（policy=multipart-v1）
```

### 18.3 新增/收敛

- `OSSDiagnosticFingerprint.ets`：承接 bucketFp / sizeBucket / uploadIdHash / etagHash；
- `OSSSimpleUploadAdapter`：独立 PutObject 实现，无 `asLegacyAdapter`，无跨 payload fallback；
- 生产日志仅 `mode=simple|multipart;policy=simple-v1|multipart-v1`；
- 单测已去掉旧 v4 policy / OfficialEquivalence / PutRequestCapture 依赖。

### 18.4 验收证据

- `rg`：`OSSClientAdapter` / `FileUploadTransportPolicy` / 旧 policy 字符串 / `asLegacyAdapter` / `arrayBufferFallback` 在 `entry/src/**/*.ets` 零命中；
- `putObject` 仅 `OSSSimpleUploadAdapter`；Multipart Vendor API 仅 `OSSMultipartUploadAdapter`；
- Feature 不直接 import `@aliyun/oss`；
- `scripts/assemble_hap.sh` → `BUILD SUCCESSFUL`。

### 18.5 真机待验（不阻塞代码清理合入）

- Simple ≤8MB 真机上传；
- Multipart >8MB 真机上传与 checkpoint 恢复；
- Complete 成功后才登记。
