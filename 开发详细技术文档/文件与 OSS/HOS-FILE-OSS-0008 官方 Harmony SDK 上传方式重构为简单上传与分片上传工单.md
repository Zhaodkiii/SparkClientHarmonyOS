# HOS-FILE-OSS-0008｜官方 Harmony SDK 上传方式重构为简单上传与分片上传工单

> 工单类型：HarmonyOS OSS 文件上传架构重构工单。
>
> 目标：按照阿里云官方 Harmony SDK 的简单上传和分片上传 API，重构当前 HarmonyOS 文件上传策略，避免继续围绕 FilePath/ArrayBuffer/RCP 进行无效切换。
>
> 约束：只允许修改 `SparkClientHarmonyOS/` 项目代码、测试和文档。禁止修改 iOS、服务器、OSS 权限、STS Role 和 `entry/third_party/aliyun-oss` Vendor SDK 源码；iOS、服务器和 Vendor 包仅作只读对照。
>
> 关联工单：HOS-FILE-OSS-0001～HOS-FILE-OSS-0007。

## 1. 重构结论

当前医疗文档上传不应继续把所有文件都当成同一种上传请求处理。按照官方文档，最终采用两级策略：

```text
小文件：官方 PutObject 简单上传
大文件：官方 Multipart Upload 分片上传
追加上传：不用于医疗文档上传
```

推荐策略：

| 文件类型/大小 | 官方方式 | HarmonyOS 方案 |
| --- | --- | --- |
| 图片、小 PDF、低于阈值的普通附件 | `client.putObject` | 单请求简单上传，使用官方支持的 `ArrayBuffer`、`FilePath` 或 `fs.File`。 |
| 超过阈值的 PDF、扫描件、批量文档 | `initiateMultipartUpload → uploadPart → completeMultipartUpload` | 分片上传，每片独立失败重试，可恢复和中止。 |
| 需要向同一 Object 尾部追加内容的场景 | `appendObject` | 医疗文档不使用，避免形成 Appendable Object 与 Normal Object 混用。 |

本次重构的关键不是把简单上传替换成追加上传，而是恢复官方 API 的语义边界：

- 单个完整文件使用 PutObject；
- 大文件使用 Multipart Upload；
- 追加上传只用于真正的日志/持续追加数据，不用于医疗报告；
- 文件登记只在完整 Object 成功后执行；
- 分片未完成时不得登记为业务文件。

## 2. 当前问题

### 2.1 当前 RCP 失败证据

14:30 日志显示：

```text
policy=v4-prod-arraybuffer-explicit-len
retryAttempt=0
RCP code=1007900056
Failure when receiving data from the peer

policy=v4-fallback-arraybuffer-explicit-len
retryAttempt=1
RCP code=1007900052
Server returned nothing (no headers, no data)
```

两次请求都具有：

- HTTP status=0；
- 没有 OSS Code；
- 没有 OSS EC；
- 没有 OSS RequestId；
- TLS 阶段有耗时；
- 发送后没有接收到有效响应。

这说明当前失败发生在完整对象 PUT 的传输链路中。继续更换 `FilePath`、`ArrayBuffer`、`stream` 或 Content-Length 只是在同一个简单上传路径上做参数试验，尚未改变上传架构。

### 2.2 当前策略的结构性问题

当前 `FileUploadTransportPolicy` 主要解决：

- payload 类型；
- 是否 stream；
- Content-Length；
- Content-MD5；
- Content-Type；
- RCP 失败后的 fallback。

但是它没有解决：

- 大文件是否需要分片；
- 每个分片是否独立重试；
- uploadId 如何持久化；
- 已完成分片如何恢复；
- 中途取消如何 Abort；
- 部分分片失败如何清理；
- Complete 失败如何处理；
- 文件登记与完整 Object 的绑定；
- 分片上传的 ETag/partNumber 记录。

### 2.3 当前追加上传不适用

官方追加上传说明：

1. 追加上传针对 Appendable Object；
2. Object 不存在时会创建追加类型文件；
3. 已存在的 Normal Object 不能通过 appendObject 继续追加；
4. 追加位置必须与当前对象长度一致；
5. 位置不一致会报 `PositionNotEqualToLength`；
6. 普通 PutObject 创建的 Normal Object 与 Appendable Object 类型不同；
7. 追加上传适合真正的尾部追加，不适合完整医疗报告一次性上传。

因此，本工单明确禁止用 `appendObject` 替代当前 `putObject`。

## 3. 官方 API 对照

### 3.1 简单上传 PutObject

官方 API：

```text
client.putObject({
  bucket,
  key,
  data
})
```

官方支持：

- 字符串；
- ArrayBuffer；
- FilePath；
- `fs.File`；
- 可选 Content-Length；
- 可选 Content-MD5；
- 可选 stream 行为；
- RequestError 统一错误字段。

适合：

- 单个小文件；
- 文件能够在一次请求内完成；
- 不需要断点恢复；
- 失败后重新上传成本可接受。

### 3.2 分片上传 Multipart Upload

官方流程固定为三步：

```text
1. initiateMultipartUpload
2. uploadPart × N
3. completeMultipartUpload
```

官方还提供：

- `abortMultipartUpload`：取消未完成任务；
- `listParts`：列举已上传分片；
- `listMultipartUploads`：列举未完成任务；
- `uploadId`：一个分片上传任务的全局标识；
- `partNumber`：分片顺序编号；
- `offset`：文件读取偏移；
- `length`：本分片大小；
- `ETag`：分片上传结果校验信息；
- `completeAll`：官方示例中的完成方式。

适合：

- 大文件；
- 网络不稳定；
- 文件上传时间较长；
- 需要分片级重试；
- 需要断点恢复；
- 不希望整文件读入内存。

### 3.3 追加上传 AppendObject

官方 API：

```text
client.appendObject({
  bucket,
  key,
  data,
  position
})
```

适合：

- 日志持续追加；
- 同一 Object 的顺序追加；
- 追加位置可由服务端确认；
- Object 明确为 Appendable 类型。

不适合：

- 医疗图片；
- PDF；
- OCR 原始附件；
- 需要幂等重试的完整对象；
- 需要文件 MD5 和完整长度登记的场景。

## 4. 重构后的目录和架构

### 4.1 目录结构

新增/重构范围只在 HarmonyOS：

```text
SparkClientHarmonyOS/entry/src/main/ets/Core/FileStorage/
├── FileTransferService.ets
├── FileUploadTransportPolicy.ets
├── FileUploadMode.ets
├── FileUploadCheckpointStore.ets
├── MultipartUploadService.ets
├── MultipartUploadModels.ets
├── MultipartUploadCheckpoint.ets
└── FileTransferErrorLocalizer.ets

SparkClientHarmonyOS/entry/src/main/ets/Projects/Core/OSS/
├── OSSClientAdapter.ets
├── OSSSimpleUploadAdapter.ets
├── OSSMultipartUploadAdapter.ets
├── OSSRuntimeConfig.ets
├── OSSRuntimeConfigStore.ets
├── OSSClientConfigNormalizer.ets
└── OSSErrorDecoder.ets
```

Vendor SDK 只作为底层依赖：

```text
SparkClientHarmonyOS/entry/third_party/aliyun-oss/
```

不得把业务逻辑写入 Vendor 目录。

### 4.2 分层职责

#### FileTransferService

负责：

- 文件 staging；
- 文件大小和 MIME 获取；
- 选择 simple/multipart；
- 统一进度；
- 统一取消；
- 统一错误；
- OSS 成功后文件登记；
- 业务附件绑定。

不负责：

- 直接拼装 Vendor SDK 参数；
- 直接决定 headers；
- 直接管理某一个分片请求；
- 直接调用 appendObject。

#### OSSSimpleUploadAdapter

只负责：

- 官方 `client.putObject`；
- ArrayBuffer/FilePath/fs.File 选择；
- 单对象请求；
- RequestError 解码；
- Client/session 生命周期。

#### OSSMultipartUploadAdapter

只负责：

- initiate；
- uploadPart；
- listParts；
- complete；
- abort；
- uploadId 和 part 状态；
- 分片级重试；
- 分片级进度。

#### MultipartUploadCheckpointStore

只负责：

- 保存 uploadId；
- 保存 objectKey；
- 保存文件摘要；
- 保存文件大小；
- 保存 partSize；
- 保存已完成 partNumber/ETag；
- 保存当前状态；
- 账号和 generation 隔离。

## 5. 上传模式选择方案

### 5.1 推荐阈值

第一阶段建议：

```text
fileSize <= 8 MB：Simple PutObject
fileSize > 8 MB：Multipart Upload
```

说明：

- 8 MB 是 HarmonyOS 当前内存和 RCP 风险控制的工程阈值；
- 它不是阿里云官方强制阈值；
- 最终阈值需要通过真机内存、网络和分片测试确认；
- 阈值必须集中配置，不能由各业务页面自行决定。

### 5.2 小文件简单上传

小文件执行：

```text
stage local file
  → fetch STS config
  → validate region/endpoint/bucket
  → create Client
  → client.putObject
  → await complete response
  → close session
  → register file
```

小文件不执行：

- appendObject；
- multipart initiate；
- 无限制 retry；
- 成功前文件登记。

### 5.3 大文件分片上传

大文件执行：

```text
stage local file
  → fetch STS config
  → validate config
  → create Client
  → initiateMultipartUpload
  → persist uploadId/checkpoint
  → upload parts
  → persist ETag per part
  → completeMultipartUpload
  → remove checkpoint
  → register file
```

失败时：

- 可恢复网络错误：重试当前 part；
- 用户取消：Abort 或标记待清理；
- 凭证过期：刷新 STS 后继续；
- Complete 失败：保留 checkpoint，禁止登记；
- 不可恢复错误：Abort，删除 checkpoint，提示用户。

## 6. 分片上传详细设计

### 6.1 初始化

调用官方：

```text
client.initiateMultipartUpload({
  bucket,
  key
})
```

必须保存：

- uploadId；
- bucket fingerprint；
- objectKey fingerprint；
- local file UUID；
- file size；
- file MD5；
- MIME；
- partSize；
- totalParts；
- account scope；
- generation；
- createdAt；
- SDK policy version。

### 6.2 分片大小

第一阶段建议：

```text
partSize = 5 MB 或 10 MB
```

实际选择必须满足：

- 最后一片允许小于标准分片大小；
- 每一片的 offset 和 length 可精确计算；
- 不把整个大文件读入内存；
- 并发数量受设备内存限制；
- 一个 part 失败不影响其他 part 状态；
- 不能重复完成同一 part 的错误状态。

官方示例使用：

```text
data: new FilePath(filePath)
length: Math.min(chunkSize, fileStat.size - offset)
offset: offset
partNumber: partNumber
```

HarmonyOS 应优先验证该官方 FilePath + offset + length 方式，而不是自行切片后无限创建 ArrayBuffer。

### 6.3 上传分片

调用官方：

```text
client.uploadPart({
  bucket,
  key,
  uploadId,
  partNumber,
  data,
  length,
  offset
})
```

每个分片必须记录：

- partNumber；
- offset；
- length；
- upload attempt；
- ETag；
- status；
- lastErrorCode；
- lastRequestId；
- completedAt。

分片成功以官方响应中的 ETag/结果为准，不以“请求发出”视为成功。

### 6.4 并发策略

初版建议并发为 1：

- 先验证单分片顺序上传；
- 先确认 RCP 和 Vendor 行为；
- 降低设备内存和 session 并发复杂度；
- 保证 checkpoint 顺序简单。

稳定后再评估并发 2：

- 同一个 uploadId 下 partNumber 不重复；
- 每个 part 使用独立请求生命周期；
- 不共享可变 File 对象；
- 完成前收集全部 ETag；
- 任一分片失败时停止发起新分片。

第一阶段禁止直接上并发 4 或更高，避免把当前 RCP 问题扩大成连接池和内存问题。

### 6.5 Complete

调用官方：

```text
client.completeMultipartUpload({
  bucket,
  key,
  uploadId,
  completeAll: true
})
```

完成要求：

- 所有分片成功；
- uploadId 匹配；
- key 匹配；
- Object 完整响应成功；
- 完成后才删除 checkpoint；
- 完成失败不得执行文件登记；
- Complete 的 RequestError 必须保留；
- 成功对象大小需要与本地文件大小核对。

### 6.6 Abort

调用官方：

```text
client.abortMultipartUpload({
  bucket,
  key,
  uploadId
})
```

触发条件：

- 用户明确取消；
- 文件 generation 失效；
- 账号切换；
- 配置不一致；
- 不可恢复权限错误；
- 文件本地已删除；
- checkpoint 校验失败。

网络不可用时 Abort 失败不能阻塞页面返回，必须保留待清理记录，并在后续进入清理任务。

### 6.7 恢复

恢复流程：

```text
read checkpoint
  → validate account/generation/fileMd5/fileSize/objectKey
  → listParts(uploadId)
  → compare remote parts with checkpoint
  → skip completed parts
  → upload missing parts
  → complete
```

以下情况不得恢复旧任务：

- 本地文件 MD5 变化；
- 文件大小变化；
- objectKey 变化；
- 账号变化；
- Bucket/Region 变化；
- STS 配置环境变化；
- uploadId 无效；
- checkpoint 版本过旧。

## 7. 当前简单上传迁移方案

### 7.1 保留内容

以下能力继续保留：

- `FileTransferService` 统一门面；
- 文件 staging/cache；
- OSS STS RuntimeConfigStore；
- Region/Endpoint 本地预检；
- objectKey 生成和校验；
- 文件 MD5；
- 文件登记接口；
- 统一错误提示；
- OSS/File/HOME 三层日志；
- 账号 scope 和 generation；
- 取消令牌。

### 7.2 删除/停止扩展的方向

以下方向不再作为长期架构：

- 不再继续增加 v5/v6/v7 的 FilePath/ArrayBuffer fallback policy；
- 不再把每次 RCP 错误都通过切换 payload 解决；
- 不使用 appendObject 上传医疗文件；
- 不在业务页面直接调用 Vendor SDK；
- 不以“请求已发出”标记上传成功；
- 不以文件登记成功替代 OSS 完成成功。

### 7.3 SimpleAdapter 责任

SimpleAdapter 只负责官方 PutObject：

1. 创建 Client；
2. 选择官方支持的数据类型；
3. 调用 PutObject；
4. await 结果；
5. 解码 RequestError；
6. 关闭 session；
7. 返回统一上传结果。

## 8. 业务流程对齐

### 8.1 AI 上传报告

```text
fullScreenCover
  → MedicalDocumentFilePickerMenu
  → FileTransferService
  → choose simple/multipart
  → OSS upload complete
  → file register
  → OCR
  → type recognition
  → extraction
  → result confirmation
```

### 8.2 失败边界

OSS 未完成：

- 不进入文件登记；
- 不进入 OCR；
- 不进入类型识别；
- 不生成业务附件绑定。

OSS 完成但文件登记失败：

- 保留 uploaded-unregistered 状态；
- 使用 objectKey 和 fileUuid 重试登记；
- 不重复上传完整对象；
- 不重复 Complete Multipart。

## 9. 错误模型

### 9.1 Simple Upload 错误

- `sourceInvalid`；
- `localIoFailed`；
- `credentialsExpired`；
- `ossAccessDenied`；
- `ossRequestValidationUnknown`；
- `ossTransientFailure`；
- `ossTransportPeerReceiveFailed`；
- `cancelled`。

### 9.2 Multipart 错误

新增：

- `multipartInitiateFailed`；
- `multipartPartUploadFailed`；
- `multipartPartIntegrityMismatch`；
- `multipartListPartsFailed`；
- `multipartCompleteFailed`；
- `multipartAbortFailed`；
- `multipartCheckpointInvalid`；
- `multipartUploadExpired`；
- `multipartRegistrationPending`。

### 9.3 用户提示

| 错误 | 页面提示 | 动作 |
| --- | --- | --- |
| Simple 网络失败 | 网络连接不稳定，请稍后重试 | 有限重试/返回选择 |
| Part 网络失败 | 正在重试上传，请稍候 | 重试当前分片 |
| Complete 失败 | 文件正在整理，请稍后重试 | 恢复 checkpoint |
| 权限错误 | 暂时无法上传，请稍后重试 | 不自动重试，返回选择 |
| Checkpoint 失效 | 文件已变化，请重新选择 | 清理任务 |
| 取消 | 已取消 | 返回上传页 |

## 10. 日志设计

### 10.1 模式选择

```text
file.upload.mode_selected
mode=simple|multipart
fileSizeBucket=...
partSizeBucket=...
thresholdVersion=...
```

### 10.2 Multipart 初始化

```text
oss.multipart.initiated
uploadIdHash=...
keyFp=...
fileSizeBucket=...
partSize=...
totalParts=...
```

### 10.3 分片上传

```text
oss.multipart.part.started
uploadIdHash=...
partNumber=...
partSizeBucket=...
attempt=...

oss.multipart.part.succeeded
partNumber=...
elapsedMs=...
etagPresent=true
```

### 10.4 完成/中止

```text
oss.multipart.completed
uploadIdHash=...
totalParts=...
objectSizeBucket=...

oss.multipart.aborted
uploadIdHash=...
reason=cancelled|invalid|permission|expired
```

禁止记录：

- uploadId 原文；
- token；
- Authorization；
- 完整 bucket；
- 完整 objectKey；
- 文件路径；
- ETag 原文（如可关联敏感对象时只保留摘要）。

## 11. 实施阶段

### 阶段一：官方 API 能力验证

1. 使用固定测试 Bucket；
2. 使用固定测试 STS；
3. 验证官方 PutObject + ArrayBuffer；
4. 验证官方 PutObject + FilePath；
5. 验证官方 PutObject + fs.File；
6. 验证 initiateMultipartUpload；
7. 验证 uploadPart；
8. 验证 completeMultipartUpload；
9. 验证 listParts；
10. 验证 abortMultipartUpload；
11. 记录 RequestError 字段；
12. 记录 RCP 错误和 HTTP 错误是否可区分。

### 阶段二：SimpleUploadAdapter

1. 从现有 OSSClientAdapter 抽离单对象 PutObject；
2. 保留官方最小参数；
3. 统一 Client/session 生命周期；
4. 完成错误映射；
5. 完成图片/PDF 小文件真机测试；
6. 关闭旧 fallback 链路的继续扩展；
7. 验证成功后才进入 register。

### 阶段三：MultipartUploadAdapter

1. 建立 MultipartUploadModels；
2. 实现 initiate；
3. 实现顺序 uploadPart；
4. 保存 checkpoint；
5. 支持当前分片一次重试；
6. 实现 listParts 恢复；
7. 实现 complete；
8. 实现 abort；
9. 完成后删除 checkpoint；
10. 只在 Complete 成功后登记文件。

### 阶段四：FileTransferService 路由

1. staging 后获取 fileSize；
2. 根据集中阈值选择模式；
3. simple 调用 SimpleAdapter；
4. multipart 调用 MultipartAdapter；
5. 两种模式返回统一 `ManagedFileUploadResult`；
6. register 逻辑保持单一；
7. 业务页面不感知上传模式；
8. 统一 progress、cancel、retry、error。

### 阶段五：清理和验收

1. 清理未完成 multipart 任务；
2. 验证账号切换；
3. 验证进程重启恢复；
4. 验证断网恢复；
5. 验证取消后 Abort；
6. 验证 Complete 失败；
7. 验证 register 失败后的重试；
8. 验证小文件和大文件内存；
9. 验证 RCP 错误不再无限 fallback；
10. 形成 HarmonyOS 发布准入结论。

## 12. 验收标准

### 12.1 方式选型

- 医疗图片/PDF 不使用 appendObject；
- 小文件使用官方 PutObject；
- 大文件使用官方 Multipart Upload；
- 阈值集中配置；
- 业务层不直接选择 Vendor API。

### 12.2 Simple Upload

- PutObject 参数符合官方 API；
- Client 使用 STS + 正确 region；
- FilePath/fs.File 使用后正确关闭；
- ArrayBuffer 不超过内存上限；
- session 在 await 完成后关闭；
- RequestError 字段完整保留；
- RCP 失败有限重试。

### 12.3 Multipart Upload

- initiate 返回 uploadId 并保存；
- 每个 part 使用正确 offset/length/partNumber；
- 分片成功记录 ETag；
- 分片失败可单独重试；
- listParts 可恢复；
- complete 成功后才算上传完成；
- abort 可清理未完成任务；
- checkpoint 与账号、文件摘要、objectKey 绑定；
- Complete 失败不登记文件。

### 12.4 业务流程

- fullScreenCover 上传页面不感知底层模式；
- 图片/PDF/相机/聊天/外部文件共用 FileTransferService；
- 上传成功后继续文件登记、OCR 和医疗识别；
- 上传失败停留在 upload 阶段；
- 不产生孤儿文件登记；
- 不重复上传或重复绑定。

### 12.5 范围约束

- 未修改 iOS；
- 未修改服务器；
- 未修改 OSS 权限；
- 未修改 STS Role；
- 未修改 Vendor SDK 源码；
- 只修改 HarmonyOS 代码、测试和文档。

## 13. 官方文档与证据路径

用户提供的官方资料：

```text
/Users/hua/.codex/attachments/2dce1b58-3b44-4bd3-b3b4-49c756917e09/pasted-text.txt
/Users/hua/.codex/attachments/f50d7dc9-7913-4db2-af3f-aee23753b066/pasted-text.txt
/Users/hua/.codex/attachments/1a3b9cda-43f6-4b08-b893-cad1c0ed857c/pasted-text.txt
```

HarmonyOS 当前代码：

```text
SparkClientHarmonyOS/entry/src/main/ets/Core/FileStorage/FileTransferService.ets
SparkClientHarmonyOS/entry/src/main/ets/Core/FileStorage/FileUploadTransportPolicy.ets
SparkClientHarmonyOS/entry/src/main/ets/Projects/Core/OSS/OSSClientAdapter.ets
SparkClientHarmonyOS/entry/src/main/ets/Projects/Core/OSS/OSSErrorDecoder.ets
SparkClientHarmonyOS/entry/src/main/ets/Projects/Core/OSS/OSSRuntimeConfigStore.ets
SparkClientHarmonyOS/entry/third_party/aliyun-oss/aliyun-oss/README.md
```

## 14. 工单完成说明

本工单已完成（文档设计 + HarmonyOS 代码落地，2026-07-24）：

### 14.1 设计结论

- 对比官方简单上传、追加上传、分片上传三种模式；
- 明确医疗图片/PDF **不使用**追加上传；
- 确定小文件 PutObject、大文件 Multipart Upload 的分层方案；
- 设计 uploadId、partNumber、offset、length、ETag、checkpoint、Abort 和 Complete；
- 明确只修改 HarmonyOS 的实施范围。

### 14.2 HarmonyOS 实施落地（未改 iOS / 服务器 / Vendor 源码）

1. **`FileUploadMode`**：阈值 8MB / 分片 5MB；`file.upload.mode_selected` 日志。
2. **`OSSSimpleUploadAdapter`**：官方 PutObject 门面（委托既有 `OSSClientAdapter`）。
3. **`OSSMultipartUploadAdapter`**：initiate / uploadPart(FilePath+offset+length) / listParts / completeAll / abort。
4. **`MultipartUploadService`**：顺序分片（并发=1）、分片 RCP 一次重试、Complete 前不登记。
5. **`FileUploadCheckpointStore`**：Preferences 断点（uploadId 可持久化；日志仅 hash）。
6. **`FileTransferService`**：staging 后按阈值路由 simple/multipart；业务页不感知模式。
7. **错误/文案**：新增 multipart* 错误码与本地化提示。
8. **测试**：`OSSMultipartUpload0008.test.ets`；`assembleHap` 通过。

### 14.3 真机仍需验证

- 官方等价 PutObject / Multipart 在固定测试 Bucket 的端到端成功；
- RCP 在分片路径上的表现与 Abort/恢复；
- 公测 SDK 生产准入决策。

范围约束：未修改 iOS、服务器、OSS 权限、STS Role、Vendor SDK 源码。
