# HOS-FILE-OSS-0002｜InvalidArgument 直传参数对齐、HOS-FILE-OSS-0001 实现偏差与 iOS 文件架构收敛工单

> 工单类型：HarmonyOS 文件与 OSS 问题修复工单。本工单在 HOS-FILE-OSS-0001 已实施的事实基础上，审计其实现偏差，并解决新的真实失败 `HTTP 400 / InvalidArgument / EC 0002-00000226`。本文仅新增工单与验收契约；不修改 HarmonyOS、iOS、SparkService、OSS 配置或 Vendor SDK。
>
> 优先级：P0。后端唯一事实源：`/Users/hua/Documents/project/Reference/LookHealthClient/SparkService`。参考客户端：`/Users/hua/Documents/project/Reference/LookHealthClient/SparkClient`。目标客户端：`/Users/hua/Documents/project/Reference/LookHealthClient/SparkClientHarmonyOS`。

## 1. 结论先行

本次已经不是“未知的 OSS 拒绝”：最新日志已经明确给出 OSS PUT 的真实响应为 `HTTP 400`、`Code=InvalidArgument`、`EC=0002-00000226`、OSS `RequestId=6A62D77E97D18A33365D96F4`。STS 为 `fresh`，文件属于小于 1 MB 的图片，请求在 328 ms 内收到服务端响应。

因此以下原因可以排除或降级：

- 不是前一轮的“没有 OSS 诊断信息”问题；HOS-FILE-OSS-0001 的日志增强已生效。
- 不是 RCP session 被提前关闭：session close 发生在 PUT 异常后的 `finally` 释放 client/session，时序正常。
- 不是网络超时/DNS/无响应：OSS 返回了带 RequestId 的 HTTP 400。
- 不是已知的 STS 过期分类：日志为 `stsAge=fresh`，OSS Code 不是 `ExpiredToken`、`SecurityTokenExpired`、`InvalidSecurityToken` 或签名错误。
- 不是常规权限拒绝：权限通常是 403 `AccessDenied`；本次是 400 `InvalidArgument`。
- 未调用 SparkService 文件登记：PUT 失败发生在 `FileTransferService.fileApi.register()` 之前。

当前可确认的直接根因是“HarmonyOS PUT 请求被 OSS 判为参数非法”。**尚不能仅凭 `InvalidArgument + EC` 证明是 Content-MD5、Content-Length、Content-Type、object key 还是 Vendor SDK 请求序列化。**不过，HarmonyOS 与 iOS 在上传载体和完整性请求上存在一个关键差异：iOS 以 `Data` 调用 SDK 且不显式传 `Content-MD5`；HarmonyOS 以 `FilePath + useStream:true` 调用 SDK 并显式传 `contentMD5`。这应作为首个隔离验证对象。

HOS-FILE-OSS-0001 已实现日志、错误模型、通知注入与页面恢复的主要骨架，但存在 8 项偏差；其中 P0 偏差是：当前把所有 `InvalidArgument` 都提示为“文件暂不支持上传，请重新选择文件”，并仅作 inline 展示。这会把服务端/SDK 请求参数问题误导为用户文件问题，且遗漏全局错误 banner。

## 2. 最新现场日志与严格时序

```text
11:09:49.910 oss.put.started
  contentTypeCategory=image; sizeBucket=lt1m;
  keyFp=v1:897c711525e17898:len=111; stsAge=fresh;
  transferHash=f83db4b6f25edd02

11:09:49.915 RCP session create: 0

11:09:50.244 oss.put.failed
  HTTP 400; ossCode=InvalidArgument; ossEc=0002-00000226;
  OSS RequestId=6A62D77E97D18A33365D96F4;
  retryable=false; hasMd5=true; elapsedMs=328

11:09:50.245 RCP session close: 0
11:09:50.245 file.upload.failed
11:09:50.246 medical.upload.error_presented presentation=inline
11:09:50.246 medical.upload.vm.pipeline_failed step=upload
```

| 观察项 | 代码/日志证据 | 结论 |
| --- | --- | --- |
| 请求是否实际到达 OSS | OSS RequestId 和 HTTP 400 | 已到达 OSS，不能归类为客户端本地文件不可读或纯网络失败。 |
| 文件体量 | `sizeBucket=lt1m` | 排除 PutObject 单对象 5 GB 上限。 |
| 上传类型 | `contentTypeCategory=image` | 本次不是 PDF 独有问题；仍需在矩阵中验证 PDF。 |
| object key | 仅记录安全摘要、长度 111 | 不能从该日志确认 key 合法性；长度本身远低于 OSS Object 名最大字节数。 |
| MD5 | `hasMd5=true` | 请求携带了 Content-MD5；尚未证明值错误。 |
| STS 时效 | `stsAge=fresh` | 当前快照未接近过期；仍需核验实际 role/endpoint/region，但它不是第一嫌疑。 |
| RCP close | Adapter `finally -> closeClient()` | 正常资源释放，不是根因。 |
| UI 呈现 | `presentation=inline` | 说明 HOS-0001 的 localizer 将该类错误归入本地重新选择，未走全局 banner。 |

阿里云 PutObject 官方说明中，`InvalidArgument`（HTTP 400）可由无效请求参数触发；Content-MD5 若参与校验则必须是消息体 MD5 的 Base64 值。官方错误表并不能将 `EC=0002-00000226` 在公开页面直接映射到单一字段，因此必须用 OSS RequestId 在云侧诊断/工单中查询，不得凭 EC 文本猜测具体参数。参考：[PutObject 官方文档](https://help.aliyun.com/zh/oss/developer-reference/putobject/)、[400 错误 FAQ](https://help.aliyun.com/zh/oss/user-guide/http-400-error-code)。

## 3. HOS-FILE-OSS-0001 已实现项与偏差审计

### 3.1 已实施且已从最新日志证实的部分

| HOS-FILE-OSS-0001 目标 | 当前实现证据 | 本次运行证据 | 状态 |
| --- | --- | --- | --- |
| SDK 异常解码 | `Projects/Core/OSS/OSSErrorDecoder.ets` | 400/InvalidArgument/EC 已被采集 | 已实现 |
| OSS RequestId 白名单字段 | `LogEvent.ets`、`Logger.ets`、`LogSanitizer.ets` | `ossRequestId=6A62...` | 已实现 |
| 上传开始/失败结构化事件 | `OSSClientAdapter.ets` | `oss.put.started`、`oss.put.failed` | 已实现 |
| 受控 FileTransferError | `FileStorageModels.ets` | `code=ossRequestInvalid`、stage uploading | 已实现 |
| 文件错误本地化器 | `FileTransferErrorLocalizer.ets` | 技术 OSS 文案未进入用户日志/UI | 已实现 |
| 医疗上传统一通知注入 | `MedicalDocumentUploadAssembly.ets`、`AppContainer.ets` | VM 已记录 error presented | 已实现，但呈现策略有偏差 |
| 处理页恢复动作 | `MedicalDocumentUploadHostPage.ets` | 失败状态由 VM 驱动 | 已实现，需补真机交互验收 |
| STS 服务端无敏感关联日志 | `SparkService/file_manager/oss_sts_views.py` | 代码已实现 | 已实现，需联调核验 |

### 3.2 必须在本工单修复的偏差

| 编号 | 严重度 | 偏差 | 当前证据 | 后果 | 修复要求 |
| --- | --- | --- | --- | --- | --- |
| D-01 | P0 | `InvalidArgument` 被直接映射为 `ossRequestInvalid`，文案“文件暂不支持上传，请重新选择文件” | `OSSErrorDecoder.mapHttpAndCode()`、`FileTransferErrorLocalizer.messageByCode()` | OSS 服务/SDK 参数问题被误导为用户文件问题 | 将“未经字段级确认的 InvalidArgument”定义为 `ossRequestValidationUnknown`（或同等 reason），提示“上传参数异常，请重试；持续失败请联系支持”，并走 banner。只有本地 preflight 或 OSS Code 明确指向文件内容/名称时才建议重新选择。 |
| D-02 | P0 | 当前 `ossRequestInvalid` 的 `showGlobalBanner=false` | `applyActions()`；日志 `presentation=inline` | 全屏上传页之外无法看到系统级失败；与工单原目标不一致 | 未确认的服务/SDK参数失败必须 `showGlobalBanner=true`；局部 reselect 仅用于 `sourceInvalid`、明确 MD5/本地内容校验失败。 |
| D-03 | P0 | OSS RequestId 同时写入 `requestId` 与 `ossRequestId` | `OSSClientAdapter`、`FileTransferService`、VM；最新日志两字段相同 | 混淆 SparkService `X-Request-ID` 与 OSS RequestId，破坏跨系统关联模型 | `requestId` 仅承载 SparkService 网络请求 ID；`ossRequestId` 仅承载 OSS ID。对直传 PUT 不得复制到 `requestId`。 |
| D-04 | P1 | `ErrorLogger` 对已经构造好的 `detail` 再追加同一 FileTransferError 摘要 | `ErrorLogger.enrichFromFileTransferError()` + `summarize()`；日志 `len=412` 且 httpStatus/ossCode 重复 | 关键字段被 200 字符截断，降低排查价值 | 将核心字段只写一次，摘要只保留 `name/code/stage`；或将诊断字段提升为白名单独立字段，禁止重复拼接。 |
| D-05 | P1 | PUT 日志没有 `contentLengthMode`、`useStream`、SDK vendor/version、MD5 校验模式 | `oss.put.started` | 无法通过日志判断实际请求形态，难以确认 400 的参数差异 | 增加非敏感的固定枚举：`payload=filePath`、`stream=true|false`、`contentLength=explicit|sdkDerived`、`integrity=contentMd5|crc64|none`、`vendorVersion`。 |
| D-06 | P1 | 没有真实 OSS PUT 集成测试，仅有 decoder fake fixture | `entry/src/test/ets/FileStorage/OSSErrorDecoder.test.ets` | 字符串映射通过不代表 Harmony SDK 请求可用 | 新增测试 bucket/测试 role 的 POC/集成验收；至少覆盖当前与候选请求形态。 |
| D-07 | P1 | 文件名“180 字符”被注释为“近似 UTF-8 字节”，实际并非字节上限；object key 无显式 UTF-8 byte/OSS 合法性 preflight | `FileHashUtil.sanitizeFileName()`、`makeObjectKey()` | 特殊长中文/emoji/控制字符仍可能制造无效 key，且错误只能到 OSS 才发现 | 新增 `ObjectKeyPolicy`：按 UTF-8 字节限制、拒绝/替换控制字符、禁止首位斜杠、验证完整 key 上限；失败归 `sourceInvalid` 并在 PUT 前阻断。 |
| D-08 | P2 | 上传 Host/Picking 多处硬编码中文文案 | `MedicalDocumentUploadHostPage.ets`、`MedicalDocumentUploadPickingPage.ets` | 与 iOS `L10n` 以及 HarmonyOS 资源体系不一致 | 将新增错误标题、按钮、恢复说明资源化；不得在错误本地化器散落硬编码文案。 |

## 4. iOS—HarmonyOS 文件/OSS 目录、架构与模型对齐

### 4.1 目录和依赖映射

| iOS 真实目录/文件 | iOS 职责 | HarmonyOS 当前目录/文件 | HarmonyOS 职责 | 对齐评估 |
| --- | --- | --- | --- | --- |
| `Projects/Core/FileStorage/FileStorageModels.swift` | ManagedFile、上传 payload、登记请求 DTO | `Core/FileStorage/FileStorageModels.ets` | 远端记录、上传命令、进度、缓存状态、错误/诊断 | HarmonyOS 更完整；需收敛 error reason 与 DTO 约束。 |
| `Projects/Core/FileStorage/FileTransferService.swift` | actor 编排缓存→STS→PUT→register | `Core/FileStorage/FileTransferService.ets` | 同一编排，另有 generation、缓存补偿、observer | HarmonyOS 语义更强；必须保持 API path/字段完全同源。 |
| `Projects/Core/FileStorage/FileCacheManager.swift` | Caches 文件保存、MD5、账号 namespace | `Core/FileStorage/FileCacheManager.ets`、`FileCacheRepository.ets`、`FileCacheSchema.ets` | 私有 staging、RDB、MD5、状态恢复 | HarmonyOS 设计更完整；目录物理不要求一比一，但责任已对齐。 |
| `Projects/Core/OSS/FileUtilities.swift` | MIME、文件名清理、object key | `Core/FileStorage/FileHashUtil.ets` | MIME、hash、object key、文件名 | 语义接近；需 D-07 的 UTF-8/key preflight。 |
| `Projects/Core/OSS/OSSClient.swift` | Objective-C SDK async bridge，`Data` PUT | `Projects/Core/OSS/OSSClientAdapter.ets` | Harmony Vendor SDK、`FilePath` streaming PUT | 平台适配不同；本次 400 的核心差异。 |
| `Projects/Core/OSS/OSSManager.swift` | iOS SDK client + credential runtime | `Projects/Core/OSS/OSSRuntimeConfigStore.ets` + adapter per request | STS 内存快照、single-flight、短 client 生命周期 | 允许平台不同；认证契约必须一致。 |
| `Projects/Core/OSS/SparkOSSConfigurationStore.swift` | STS snapshot/预取 | `Projects/Core/OSS/OSSRuntimeConfig.ets`、`OSSRuntimeConfigStore.ets` | 同等能力，到期前刷新 | 已对齐。 |
| `Projects/Core/Networking/API/File/FileAPI.swift` | list/register/bind/delete/download URL | `Projects/Core/Networking/API/File/FileAPI.ets` | 同一接口集合 | 已对齐；注意 iOS download URL `expires` 与服务端是否实际消费需单独校验。 |
| `Projects/Core/Networking/API/OSS/SparkOSSAPI.swift` | `GET /api/v1/oss/sts/credentials/` | `Projects/Core/Networking/API/OSS/OSSAPI.ets` | 相同 endpoint/认证 | 已对齐。 |

目标依赖方向固定，不得因解决 400 把 OSS SDK 逻辑移入 VM 或页面：

```text
MedicalDocumentUpload Presentation
  → Application / MedicalDocumentAttachmentUploader
  → Core/FileStorage/FileTransferService
  → Projects/Core/OSS/OSSClientAdapter + OSSRuntimeConfigStore
  → Projects/Core/Networking/API/{OSS,File}
  → 阿里云 OSS / SparkService
```

### 4.2 上传数据模型字段对齐

| 业务概念 | iOS | HarmonyOS | 服务端 JSON | 本工单要求 |
| --- | --- | --- | --- | --- |
| 上传源 | `ManagedFileUploadPayload.data: Data` | `FileUploadRequest.sourceUri` → staging localPath | 不进入 JSON | 平台差异允许；HarmonyOS 必须在 staging 完成后再 hash/PUT。 |
| 文件 UUID | service 内 `UUID` | `FileHashUtil.randomUuid()` | `file_uuid` | UUID 格式、长度和唯一性前置校验。 |
| 文件名 | `fileName`，`FileUtilities.sanitizeFileName` | `originalName`，`FileHashUtil.sanitizeFileName` | `original_name` | 统一无路径分隔符/控制字符/字节上限；不将用户原文件名用于日志。 |
| MIME | `UTType` 优先，fallback | 扩展名映射 | `mime_type` | 图片/PDF以实际文件/选择器 MIME 为优先，扩展名仅 fallback；补 MIME-内容不一致策略。 |
| 内容 hash | iOS `Data` MD5 | staged file MD5 hex | `file_md5` | hex 值用于登记；若传 OSS Content-MD5 必须转换为 RFC 1864 Base64。 |
| object key | `SparkClient/yyyyMMdd/uuid/safeName` | `SparkClient/yyyyMMdd/uuid/safeName` | `object_key` + `file_path` | 保持该业务格式；新增 key policy，不能在客户端按平台拆 prefix。 |
| 存储类型 | 固定 oss | 固定 oss | `storage_type` | 同源。 |
| 业务归属 | medical document source/member ID | 同 | `business_type/business_id` | 同源；上传源不能在 PUT 时误绑定最终业务单据。 |
| 远端文件 | `ManagedFileRecord` Codable，部分字段 optional | `ManagedFileRecord` class，默认空值/0 | `ManagedFileRecordSerializer` | HarmonyOS decoder 后必须验证 `id>0/file_uuid/object_key`，不能把空默认 DTO 当成功。 |

### 4.3 平台差异与不应倒退的 HarmonyOS 优势

- iOS 现有上传入口将文件完整读入 `Data`；HarmonyOS 使用私有 staging + `FilePath` 流式上传，更适合 PDF/多文件，不能为模仿 iOS 而将生产大文件全部读入内存。
- iOS 当前 OSS 错误主要封装为字符串 `OSSError.uploadFailed`；HarmonyOS 已建立 `FileTransferError`、阶段、重试、OSS Code、RequestId。应继续保留这种更强的边界，而不是退回字符串异常。
- HarmonyOS 采用 download-url、RDB 状态和 `uploaded_unregistered` 补偿，优于 iOS 直接解释 `filePath` 的历史实现；本工单不允许倒退这些安全与恢复边界。
- 需要对齐的是服务端契约、object key 规则、文件登记字段、STS 生命周期和用户可见恢复语义，而非把 Swift 的 `Data` API 逐行翻译成 ArkTS。

## 5. `InvalidArgument` 的假设、证据与隔离方案

### 5.1 候选原因排序

| 优先级 | 假设 | 支持/反驳证据 | 验证方式 | 修复方向（仅在验证后执行） |
| --- | --- | --- | --- | --- |
| H1 | `FilePath + useStream:true + contentMD5` 的 SDK 请求构造与 OSS 不兼容，或 MD5 内容/编码不一致 | HOS 显式发送 contentMD5；iOS `Data` PUT 未显式传；日志 `hasMd5=true`；文件很小、响应快 | 同一 staged 文件/STS/key 进行 integrity mode 矩阵 | 根据矩阵选择 SDK 支持的 Content-MD5、CRC64 或仅登记 MD5；不可未经验证直接关闭所有完整性校验。 |
| H2 | SDK 未显式或错误推导 `Content-Length` 的流式请求 | 400 InvalidArgument 可由请求参数触发；当前请求未传 `contentLength`，日志无请求形态 | POC 对比 explicit `contentLength=staged.fileSize` 与 SDK derived | 确认 SDK 需要时显式传准确字节数；不得用猜测常量。 |
| H3 | object key / 原始文件名含 OSS 不接受字符或 UTF-8 字节规则 | key 只记录 fingerprint；当前只按 JS 字符数量截断，不做 full key bytes 校验 | 用同一文件替换为 ASCII name/key、再用原 key 比较；增加本地 preflight | 实现 ObjectKeyPolicy；错误在 PUT 前转 sourceInvalid。 |
| H4 | content-type 由通用 `headers` 传入的大小写/签名/canonicalization 与 SDK 参数层冲突 | 当前通过 `headers['content-type']` 传递，README 对基础参数主要列 `contentMD5/contentLength` | POC 比较 no Content-Type、SDK推荐方式、当前 headers；查验 SDK 版本 release/source | 使用 Vendor 明确支持的字段；保持 MIME 登记字段不变。 |
| H5 | endpoint/region/bucket 参数组合不符合该 SDK/Sig V4 要求 | STS fresh 不代表 endpoint 配置正确；但常见签名问题会返回 403，不是当前首嫌 | 用同一 STS 在受控工具/另一 SDK 验证 endpoint/region；OSS RequestId 云侧查询 | 修正服务端 STS 配置或 SDK构造参数；不在客户端硬编码生产 endpoint。 |
| H6 | OSS bucket policy / 角色权限 | 通常应返回 403 AccessDenied；与本次 400 不吻合 | 云侧用 OSS RequestId 查询，核验 RAM/bucket policy | 若证实再改云配置；不改客户端重试逻辑。 |

### 5.2 必须执行的 POC 矩阵

前提：仅测试 bucket、测试账号、无真实医疗数据；每次使用新的 object key，记录安全 fingerprint。保持 STS、region、endpoint、bucket、同一 staged 文件不变，每次只改变一个维度。

| 编号 | data | useStream | Content-MD5 | contentLength | Content-Type | 目的 |
| --- | --- | --- | --- | --- | --- |
| P-01 | `FilePath` | true | 有（当前） | SDK 派生 | 当前 headers | 复现基线。 |
| P-02 | `FilePath` | true | 无 | SDK 派生 | 当前 headers | 隔离 Content-MD5 是否为触发条件。 |
| P-03 | `FilePath` | true | 有 | 显式 staged size | 当前 headers | 隔离 Content-Length。 |
| P-04 | `FilePath` | true | 无 | 显式 staged size | 当前 headers | 判断流式基础能力。 |
| P-05 | 小文件 `ArrayBuffer` / SDK 支持的非流式路径 | false | 按 Vendor 文档 | 明确长度 | 当前 headers | 与 iOS“内存对象”语义交叉验证；只做小文件 POC。 |
| P-06 | `FilePath` | true | 由 P-01~05 成功配置决定 | 由成功配置决定 | ASCII key/name | 排除原始 key/文件名。 |

每一行必须记录：HTTP status、OSS Code、EC、OSS RequestId、实际对象大小、响应 ETag/CRC（成功时）、`contentLengthMode`、`integrityMode`。禁止记录凭证、签名、原始 object key、原始医疗文件名或正文。

### 5.3 决策规则

1. 仅 P-01 失败、P-02 成功：根因收敛为 Content-MD5 传递/校验路径；必须进一步验证 hex→Base64 与实际上传字节是否一致，再选择 SDK 支持的完整性方案。
2. P-01/P-02 失败、P-03/P-04 成功：根因收敛为流式 Content-Length 推导；生产固定明确 `contentLength`，并加大小一致性断言。
3. 所有 FilePath 流式失败、P-05 成功：根因收敛为 Vendor SDK FilePath/stream 适配；评估升级/替换 Vendor 版本或以受控分块上传方案修复，不能生产性地对大文件退化为 ArrayBuffer。
4. P-01~05 都失败、P-06 成功：根因收敛为 object key/文件名规则；先补 ObjectKeyPolicy。
5. 所有测试形态均失败：以 OSS RequestId 查云侧原始错误；优先核验 endpoint/region/bucket、SDK version、RAM/bucket policy。不得把用户文件作为替罪原因。

## 6. 目标解决方案

### 6.1 新增“上传请求策略”领域模型

在 `Core/FileStorage` 建立平台无关的 `FileUploadTransportPolicy`，由 `FileTransferService` 产生，OSS adapter 消费。它不是页面 DTO，字段全部为显式枚举：

| 字段 | 示例 | 职责 |
| --- | --- | --- |
| `payloadKind` | `filePath` | 明确 adapter 上传输入类型。 |
| `streamMode` | `stream` | 明确 `useStream`，避免隐式默认值。 |
| `contentLengthMode` | `explicit` / `sdkDerived` | 使 POC/生产请求形态可观察。 |
| `integrityMode` | `contentMd5` / `crc64` / `none` | 必须由验证结果决定；默认策略不能以猜测替换。 |
| `contentTypeMode` | `explicitHeader` / `sdkDefault` | 记录 MIME 的实际设置路径。 |
| `vendorVersion` | 固定版本号 | 日志与回归可关联。 |

策略只能由公共服务构造；MedicalDocumentUpload、聊天、药箱等业务场景不得各自决定 MD5、stream 或 Content-Length。

### 6.2 Object key 前置策略

`ObjectKeyPolicy` 位于 `Core/FileStorage`，在创建 `OSSUploadInput` 前执行：

1. 使用 UTF-8 实际字节计数验证完整 key，而非 JavaScript 字符数。
2. 拒绝空 key、首字符 `/` 或 `\\`、NUL/控制字符、超过 OSS 限制的 key；错误归 `sourceInvalid`，不调用 OSS。
3. 生成规则保持 `SparkClient/yyyyMMdd/fileUuid/sanitizedName`，不得更改服务端登记字段或自行加入账号/成员明文。
4. 保留 key fingerprint、长度、policy version 用于日志；禁止原文。

### 6.3 错误分类与用户体验修正

将 `InvalidArgument` 从“确定是用户文件不支持”改为两层：

| 分类 | 判定条件 | 用户提示 | 展示 | 操作 |
| --- | --- | --- | --- |
| `sourceInvalid` | 本地 URI/read/hash/key policy/MIME preflight 已确认失败 | “该文件无法上传，请重新选择。” | 文件行内 | 重新选择/移除 |
| `integrityMismatch` | OSS 明确 `BadDigest/InvalidDigest`，或本地 hash 对比失败 | “文件校验失败，请重新选择后重试。” | 页面 + banner | 重新选择 |
| `ossRequestValidationUnknown` | OSS `InvalidArgument` 但未能定位字段（**本次现状**） | “上传参数异常，请重试。若持续失败，请稍后再试。” | processing 页面 + error banner | 重试上传/返回文件选择 |
| `ossConfigurationInvalid` | OSS/POC 明确 endpoint/bucket/region 配置问题 | “上传服务配置异常，请稍后再试。” | 页面 + banner | 返回/稍后重试 |

这样既不暴露技术错误，也不让用户反复重新选择本来没有问题的图片。`ossRequestValidationUnknown` 应统计并在日志中带 `ossCode/ossEc/transport policy`，用于推动后续精确映射。

### 6.4 日志修正

1. 对 OSS PUT，`LogFields.ossRequestId` 写 OSS ID；`LogFields.requestId` 留空。对 STS/register，`requestId` 写 SparkService `X-Request-ID`。
2. `ErrorLogger` 不重复拼接 `httpStatus/ossCode/ossEc/keyFp`；事件 detail 的长度控制前先去重。
3. `oss.put.started` 加入策略枚举；`oss.put.failed` 加入与 started 相同的策略版本，便于比对。
4. 增加 `oss.put.validation_matrix`（测试环境）事件，但生产默认关闭；仅记录 POC case ID 与安全字段。

## 7. 实施拆分与验收

### 阶段 A：根因冻结（P0）

| 任务 | 责任方 | 交付物 | 完成标准 |
| --- | --- | --- | --- |
| 使用 `6A62D77E97D18A33365D96F4` 查询 OSS 侧诊断 | 云资源/后端 | OSS 侧原因记录 | 给出 EC 对应字段或确认公共文档无映射，附原始诊断的脱敏摘要。 |
| 执行 P-01~P-06 矩阵 | HarmonyOS | 请求形态矩阵 | 每项含 status/Code/EC/RequestId，且仅改变一个变量。 |
| 核验 STS 成功请求 | 后端 | request ID 关联记录 | SparkService 日志证明 STS 200、环境/region/role mode 一致；无 credential 泄漏。 |

### 阶段 B：公共上传层修复（P0）

| 目标文件/模块 | 工作内容 | 验收 |
| --- | --- | --- |
| `Core/FileStorage/FileUploadTransportPolicy`（新增） | 固化经 POC 验证的 request shape | 单元测试覆盖 policy；业务层无 SDK 参数分支。 |
| `Projects/Core/OSS/OSSClientAdapter.ets` | 按 policy 构造 PUT；记录无敏感策略字段；修正 requestId/ossRequestId | 测试 bucket 图片/PDF PUT 成功；OSS 和 Spark request ID 不再混用。 |
| `Core/FileStorage/ObjectKeyPolicy`（新增或等价） | key UTF-8/preflight | 长中文、emoji、空名、非法路径分隔符、超长 key 测试通过。 |
| `OSSErrorDecoder.ets`、`FileTransferErrorLocalizer.ets` | 增加未知参数错误分类；只有证据充分时才指向重选文件 | 本次 InvalidArgument 显示正确 banner 和重试动作。 |
| `Foundation/Logging/ErrorLogger.ets` | 去重 detail | 日志中核心字段只出现一次，不再因重复被截断。 |

### 阶段 C：医疗上传与多端回归（P1）

| 场景 | 验收 |
| --- | --- |
| AI 上传报告，图片 | PUT → register；随后明确 OCR 当前状态；无重复 PUT。 |
| AI 上传报告，PDF | 与图片同样成功；MIME 与 object key 同源。 |
| 多文件 | 第一项成功、第二项失败后重试，不重复上传第一项。 |
| InvalidArgument 未知原因 | 页面和 banner 都为“上传参数异常”，有重试/返回动作；不提示用户文件不支持。 |
| 明确本地文件错误 | 只行内提示重选/移除；不发全局 banner。 |
| STS/register 失败 | SparkService request ID 正确；OSS RequestId 不被复用。 |
| iOS 回归 | 同一 STS、object key、register JSON 契约无漂移；无需把 iOS 改造成 FilePath。 |

## 8. 测试门槛

1. 单元测试增加：`InvalidArgument` 未知分类、ObjectKeyPolicy、错误提示策略、requestId/ossRequestId 分离、ErrorLogger 去重。
2. 集成测试必须是真实测试 bucket，不可只 mock `OSSErrorDecoder`；需覆盖当前 Vendor `@aliyun/oss` 版本与目标 API Level。
3. 测试要断言对象实际大小、ETag/CRC/HeadObject（如策略权限允许），不是只看 SDK Promise 成功。
4. `CompileArkTS` 与 `assembleHap` 错误数为 0；签名/设备状态与编译结果分开记录。
5. 不得输出 AccessKey、Secret、STS Token、Authorization、签名 URL、原始 object key、原始文件路径或文件正文；日志脱敏测试为发布阻断项。

## 9. 风险与待确认项

| 编号 | 项目 | 风险 | 关闭条件 |
| --- | --- | --- | --- |
| R-01 | `0002-00000226` | 公开文档未能直接定位到具体参数 | OSS RequestId 云侧查询或阿里云支持确认。 |
| R-02 | Content-MD5 | 关闭 MD5 可能暂时绕过错误但降低完整性边界 | 用 POC 得出 Vendor 支持的 integrity 模式后再生产改动。 |
| R-03 | ArrayBuffer POC | 小文件成功不代表大文件可安全生产使用 | POC 仅用于诊断；生产仍保持流式/分块策略。 |
| R-04 | SDK Vendor | 当前 Vendor 目录主要提供声明文件，难以审计实际请求序列化 | 固化版本、来源、版本级 POC 与升级回归。 |
| R-05 | UI 定位 | 未知参数错误被误导为“文件不支持” | 完成 D-01/D-02，并由产品确认文案。 |
| R-06 | 跨系统 request ID | 当前日志将 OSS ID 同时写入 `requestId` | 完成 D-03，新增测试防回归。 |
| R-07 | OCR | OSS 修复后流程仍会在未接入 OCR 阶段停止 | 页面要明确“文件上传成功”与“OCR 待接入”，不能把后者误报为上传失败。 |

## 10. 证据路径与参考资料

- HOS-FILE-OSS-0001 工单：`SparkClientHarmonyOS/开发详细技术文档/文件与 OSS/HOS-FILE-OSS-0001 AI上传报告OSS直传被拒绝、诊断链路与统一错误提示修复工单.md`
- HarmonyOS OSS adapter/decoder：`entry/src/main/ets/Projects/Core/OSS/{OSSClientAdapter,OSSErrorDecoder}.ets`
- HarmonyOS 文件模型/服务/本地化器：`entry/src/main/ets/Core/FileStorage/{FileStorageModels,FileTransferService,FileHashUtil,FileTransferErrorLocalizer}.ets`
- HarmonyOS 医疗上传与装配：`entry/src/main/ets/Projects/Features/MedicalDocumentUpload/`
- HarmonyOS 日志：`entry/src/main/ets/Foundation/Logging/{LogEvent,Logger,ErrorLogger,LogSanitizer}.ets`
- HarmonyOS Vendor README/type：`entry/third_party/aliyun-oss/aliyun-oss/README.md`、`src/main/type/object/basic-operations/putObject.d.ts`
- iOS 文件/OSS：`SparkClient/SparkClient/Projects/Core/{FileStorage,OSS}/`
- 服务端 STS/文件登记：`SparkService/file_manager/{oss_sts_views,sts_utils,views,serializers}.py`
- 官方： [OSS PutObject](https://help.aliyun.com/zh/oss/developer-reference/putobject/)、[OSS 400 错误 FAQ](https://help.aliyun.com/zh/oss/user-guide/http-400-error-code)、[OSS Content-MD5/签名说明](https://help.aliyun.com/en/oss/developer-reference/include-signatures-in-the-authorization-header)

## 11. 本次产出说明

已创建新的、独立于 HOS-FILE-OSS-0001 的修复工单，并完成阶段 B 工程实现（2026-07-24）：

- `InvalidArgument` → `ossRequestValidationUnknown`：文案“上传参数异常…”，`showGlobalBanner=true`，主操作重试上传。
- `requestId` / `ossRequestId` 分字段；PUT 失败只写 OSS ID。
- `FileUploadTransportPolicy` 生产默认：`FilePath + stream + explicit contentLength + 不向 OSS 传 Content-MD5`（登记仍保留 `file_md5`）。
- `ObjectKeyPolicy`：UTF-8 字节校验与 PUT 前阻断。
- `ErrorLogger` detail 去重；策略枚举进入 `oss.put.started/failed`。

阶段 A 的云侧 RequestId 查询与真机 P-01~P-06 矩阵仍需联调关闭；真实 bucket 集成测试不可用 mock 替代。
