# HOS-FILE-OSS-0001｜AI 上传报告 OSS 直传被拒绝、诊断链路与统一错误提示修复工单

> 工单类型：HarmonyOS 对标 iOS 的文件/OSS/错误体验修复工单。本文只定义问题、证据、接口与实施验收，不修改任何业务代码、配置、资源或服务端环境。后端唯一事实源为 `/Users/hua/Documents/project/Reference/LookHealthClient/SparkService`。
>
> 优先级：P0（AI 上传报告主路径被阻断）。范围：HarmonyOS 文件公共服务、OSS 直传、医疗文档上传流程、结构化日志、统一应用内通知；必要时包含 SparkService 的可观测性补充。不会新增平行上传接口或改变既有 iOS/HarmonyOS 的后端契约。

## 1. 问题摘要与用户影响

AI 上传报告在“开始识别”的第一个实际业务步骤——上传原始图片/PDF 到 OSS——失败。当前页面只显示“上传被拒绝”，无法让用户判断是否重试、重新选择文件或重新登录；研发也无法用客户端日志关联 OSS 拒绝原因与服务端 STS 签发请求。

本工单的目标不是把所有错误都改为自动重试，而是建立一条可验证的链路：

```text
用户选择图片/PDF
  → MedicalDocumentUploadViewModel
  → UploadMedicalDocumentFilesUseCase
  → MedicalDocumentAttachmentUploader
  → FileTransferService（缓存、STS、上传、登记）
  → GET /api/v1/oss/sts/credentials/
  → OSS PUT Object
  → POST /api/v1/files/register/
  → 文件记录回填、OCR 及后续流程
```

当前故障在 `OSS PUT Object` 返回后终止，尚未到 `POST /api/v1/files/register/`，因此不能归因于文件登记接口、医疗业务绑定或 OCR。

用户可见影响：

- AI 上传报告无法继续到 OCR/类型识别；已选择文件仍在页面，但没有可理解的失败动作。
- 图片与 PDF 走同一公共 `FileTransferService`，聊天附件、药箱附件和其他后续接入场景可能暴露同类直传问题。
- 当前把 OSS 原始异常直接放入 `ViewModel.errorMessage`，并在选文件页内联显示；没有接入根级 `NotificationClient`，与系统内已有 banner/toast 体系不一致。

## 2. 现场日志与可确认事实

### 2.1 用户提供的原始日志

```text
07-24 10:22:29.253  A03d00/JSAPP          I [RCP] session list: ["8"] after create: undefined
07-24 10:22:29.512  A03d00/JSAPP          I [RCP] session list: [] after close: 8
07-24 10:22:29.513  A05350/SupportClient  E {"event":"file.upload.failed","module":"FILE","level":"error","timestampMs":1784859749513,"detail":"FileTransferError code=ossRejected 上传被拒绝"}
07-24 10:22:29.514  A05350/SupportClient  I {"event":"medical.upload.vm.pipeline_failed","module":"HOME","level":"info","timestampMs":1784859749514,"operation":"medical_upload_vm","detail":"step=upload;上传被拒绝"}
```

### 2.2 由日志和当前代码共同证明的结论

| 结论 | 证据 | 可信度 | 说明 |
| --- | --- | --- | --- |
| 已创建 OSS SDK RCP session | `after create` 日志 | 已确认 | SDK 已进入真实请求前的 client/session 创建路径。 |
| session 随后被关闭 | `after close` 日志 | 已确认 | 对应 `OSSClientAdapter.upload()` 的 `finally -> closeClient()`；它是请求结束后的回收行为，不能单独判为根因。 |
| 失败在上传阶段 | `medical.upload.vm.pipeline_failed` 的 `step=upload` | 已确认 | 未到 OCR、类型识别、抽取、绑定或保存。 |
| 已得到 OSS HTTP 客户端拒绝类错误 | `FileTransferError code=ossRejected` | 已确认 | 现有 `OSSClientAdapter.mapError()` 仅在 SDK 错误的 `status >= 400` 且不是 `401/403` 时产生该 code。 |
| 具体 HTTP 状态、OSS Code、OSS RequestId 未被记录 | 两条结构化日志均无这些字段 | 已确认 | 当前无法区分 400 BadDigest、403 之外的鉴权策略拒绝、404 bucket/object、409 冲突、4xx 参数校验等。 |
| STS 接口已成功还是失败，现有片段无法独立证明 | 未提供 `oss.sts.*` 或网络日志 | 待复核 | 上传走到 `putObject` 通常意味着配置对象已取得，但需以同一次操作的网络 requestId/状态日志确认。 |
| 文件登记接口没有被调用 | `FileTransferService.upload()` 的控制流 | 已确认 | `fileApi.register()` 在 `ossAdapter.upload()` 成功之后；本次异常提前抛出。 |

### 2.3 不可在未补日志前下结论的事项

下列原因均可能返回 4xx，现有“上传被拒绝”不足以区分，禁止在工单关闭前任选其一作为根因：

1. STS 角色策略、bucket policy、RAM 权限边界或显式 Deny。
2. STS 的 `region`、`endpoint`、bucket 名或 endpoint 访问域名与签名区域不一致。
3. 时钟偏差（典型 OSS `RequestTimeTooSkewed`）。
4. SDK 对 `Content-MD5`、`content-type`、canonical headers 或流式 `FilePath` 的签名/请求兼容问题。
5. object key、bucket 名或请求头不符合 OSS 约束。
6. 已过期/尚未生效的临时凭证；本实现对 401/403 会刷新一次，但并未记录实际 OSS Code。
7. HarmonyOS Vendor SDK 版本或设备网络栈差异。

## 3. 当前代码、iOS 与后端契约基线

### 3.1 HarmonyOS 真实调用链

| 分层 | 当前文件 | 当前职责 | 本工单发现 |
| --- | --- | --- | --- |
| 页面 | `Projects/Features/MedicalDocumentUpload/Presentation/MedicalDocumentUploadPickingPage.ets` | 选择图片/PDF、点击开始识别、内联显示 `vm.errorMessage` | 没有展示错误类型、重试动作或系统通知。 |
| 流程 VM | `.../MedicalDocumentUploadViewModel.ets` | 运行 upload → OCR…；catch 后直接取 `error.message` | 丢失 `FileTransferError.code/stage/retryable/requestId/httpStatus`，且未注入 `NotificationClient`。 |
| 医疗用例 | `.../Application/UploadMedicalDocumentFilesUseCase.ets` | 顺序批量上传，断点续跑时跳过已有 remoteFile | 不应承载 SDK/接口错误翻译。 |
| 医疗适配 | `Home/.../MedicalDocumentAttachmentUploader.ets` | 补齐成员、账号、generation、业务类型 | 正确复用公共上传服务；不应直接访问 OSS。 |
| 公共服务 | `Core/FileStorage/FileTransferService.ets` | stage → STS → OSS PUT → register；上传异常归一化 | 已有分类模型，但上传失败日志只写摘要，诊断字段没有输出。 |
| OSS adapter | `Projects/Core/OSS/OSSClientAdapter.ets` | 工程唯一 `@aliyun/oss` import、PUT、关闭 RCP session、SDK 异常映射 | 只读取 `status`、`requestId`、`code` 用于判断；映射对象没有保存 OSS Code/EC/HostId/serverTime，也没有把 HTTP/requestId 送入 `LogFields`。 |
| STS | `Projects/Core/OSS/OSSRuntimeConfigStore.ets`、`Networking/API/OSS/OSSAPI.ets` | 内存快照、提前 300 秒刷新、`GET /api/v1/oss/sts/credentials/` | 日志只记录 bucket/region；不应记录任何 AK/SK/token。 |
| 系统提示 | `Projects/Core/Notification/Application/NotificationClient.ets`、`App/Notification/AppNotificationHost.ets` | 统一错误 banner / 成功 info toast | 基础设施已存在，AI 上传报告尚未使用。 |

### 3.2 后端唯一接口契约

| 阶段 | 服务端证据 | Method / path | 成功响应 | 失败语义 | 本次关系 |
| --- | --- | --- | --- | --- | --- |
| STS 签发 | `SparkService/file_manager/oss_sts_views.py`、`oss_urls.py`、`SparkService/urls.py` | `GET /api/v1/oss/sts/credentials/` | `{code:0,msg:"success",data:{access_key_id,access_key_secret,security_token,expiration,bucket_name,region,endpoint}}` | 401 未登录；5001 配置错误；5002 STS 调用异常；Django 响应含 `X-Request-ID` | 必须使用同一 `X-Request-ID` 与服务端日志关联；敏感字段仅内存消费。 |
| OSS 直传 | 阿里云 OSS；服务端 `sts_utils.py` 仅签发临时凭证 | SDK PUT object（非 SparkService JSON API） | OSS 2xx | OSS HTTP/XML `Code`、`RequestId`、`HostId` 等 | **本次故障点**。服务端应用日志不能自动看到这次 PUT，必须以 OSS RequestId/审计日志排查。 |
| 文件登记 | `SparkService/file_manager/views.py`、`serializers.py`、`urls.py` | `POST /api/v1/files/register/` | HTTP 201，`{code:0,msg:"created",data:ManagedFile}` | 400 serializer；5004 DB；请求响应均有服务端 request ID | 本次没有触发；不应把它当成失败根因。 |

`sts_utils.py` 当前为 AssumeRole 请求显式下发 `oss:PutObject` 等 Action，并针对 `bucket` 与 `bucket/*` 生成允许资源。该代码证明应用层意图允许上传，但不能替代阿里云侧实际 RAM role、bucket policy、权限边界、Endpoint/Region 与运行时环境核验。

### 3.3 与 iOS 的对齐结论

| 能力 | iOS 事实 | HarmonyOS 事实 | 需要收敛的目标 |
| --- | --- | --- | --- |
| 上传事务 | `Projects/Core/FileStorage/FileTransferService.swift`：缓存 → STS → OSS PUT → register | 相同事务边界，且已有 staging、generation、`uploaded_unregistered` | 保持同一后端契约与先上传后登记顺序。 |
| OSS 适配 | `Projects/Core/OSS/OSSClient.swift` 将 SDK 回调桥接为 async；上层收到 `OSSError.uploadFailed` | `OSSClientAdapter.ets` 已有更细 `FileTransferError` 分类 | 不应机械退化为 iOS 的字符串异常；应把 HarmonyOS 已有分类补完整，并反哺为跨端统一错误语义。 |
| 全屏流程错误 | `MedicalDocumentUploadHostView.swift` 对 `viewModel.errorMessage` 使用 modal alert；iOS 根 `NotificationHostView` 同时提供 banner/toast/alert 容器 | HarmonyOS Host 只有 processing 文案，Picking 页内联红字；根 `AppNotificationHost` 已存在 | 上传过程失败需保留页面内恢复上下文，同时通过统一通知发布一次可理解错误，避免直出 SDK 文案。 |
| 诊断安全 | iOS 日志要求脱敏、截断 | `LogSanitizer`、`Logger`、`ErrorLogger` 已实现白名单与脱敏 | OSS 诊断必须补充 allowlist 字段，绝不记录 AK/SK/securityToken、Authorization、签名 URL、完整对象路径或原始 XML。 |

## 4. 初步根因判断与排查顺序

### 4.1 当前可下的技术判断

本次的直接失败原因是：OSS SDK 返回了一个被当前 adapter 识别为 HTTP 4xx 的请求错误，adapter 把它映射为 `FileTransferError(code=ossRejected, stage=uploading, retryable=false)`；流程 VM 再把安全文案“上传被拒绝”作为上传步骤失败原因。

根因尚未锁定。当前最严重的代码问题不是“没有 catch”，而是 adapter 已读到/可读到的 OSS 诊断信息没有被保留到受控错误模型和日志中，导致一个可定位的 4xx 变成不可排查的泛化文案。

### 4.2 按优先级执行的排查步骤

#### P0-A：一次失败操作的端到端关联采集

1. 在测试账号、测试 bucket、无真实医疗文件的最小图片/PDF 上复现一次；记录应用版本、API Level、设备型号、网络类型、测试时间（精确到秒）。
2. 开启 `SupportClient` 的结构化日志筛选，采集同一次 `transferId` 的 `oss.sts.*`、`file.upload.*`、`oss.put.*`、`medical.upload.*` 事件。
3. 采集 STS 请求的客户端 `X-Request-ID`，从 SparkService 日志按该 ID 找到 STS 的 HTTP 状态、业务 code 与签发时间。不得打印 `data` 内的任何凭证字段。
4. 采集 OSS PUT 的 HTTP status、OSS `Code`、OSS `RequestId`、`HostId` 是否存在、SDK error name/code、是否带 serverTime。OSS RequestId 只用于研发/运维关联，不对普通用户展示。
5. 确认日志能表明：STS 获取成功、配置是否处于 fresh、PUT 发生、PUT 的实际结果、是否发生一次凭证失效刷新、register 是否未触发。
6. 将 OSS RequestId 到阿里云 OSS 日志/审计系统中查询；结论必须附上“响应状态 + OSS Code + 策略/签名检查结果”，不能只写“OSS 拒绝”。

关闭 P0-A 的最低证据：一条脱敏客户端事件与一条 OSS 侧记录可以通过 `ossRequestId` 对应，且能给出 HTTP status 与 OSS Code。

#### P0-B：STS 与阿里云权限/签名配置核验

1. 在 SparkService 环境确认 `ALIYUN_OSS_BUCKET`、`ALIYUN_OSS_REGION`、可选 `ALIYUN_OSS_ENDPOINT` 一致且没有多环境串用；只核对配置值，不将值复制进工单或客户端日志。
2. 核验 `ALIYUN_STS_ROLE_ARN` 对应 role 的 trust policy：调用方是否被允许 AssumeRole。
3. 核验该 role 的 permission policy、permission boundary、资源组与 bucket policy：对目标 bucket/object prefix 是否存在显式 Deny；是否允许 `oss:PutObject`。
4. 确认临时凭证是 STS 格式：有 `security_token` 时 SDK 必须携带；角色未配置时服务端会返回静态凭证，这只能用于明确的开发环境，不能混入测试/生产。
5. 核验 endpoint 协议、host 与 region；特别确认自定义 endpoint 时客户端 SDK 的 region 与签名版本要求一致。
6. 核验设备时间自动同步；若 OSS Code 是 `RequestTimeTooSkewed`，将其归入时钟偏差专项而不是“权限拒绝”。
7. 核验 object key 实际格式仅包含服务端 policy 允许的 prefix；不得用完整对象 key 写入生产日志，只写不可逆摘要/长度/格式版本。

#### P0-C：SDK 请求构造与数据完整性隔离验证

以下验证在测试环境进行，禁止通过关闭安全校验直接上线：

1. 保持同一个 STS、同一对象 key 规则，分别上传极小 PNG 与极小 PDF，确认是否仅某 MIME/文件类型失败。
2. 使用同一 staged 文件的 MD5，核对十六进制 → 16 bytes → Base64 的转换值与独立工具结果；不得记录文件内容或完整 MD5。
3. 对照 Vendor `@aliyun/oss` 的类型定义：`RequestErrorBase` 明确声明 `code`、`ec`、`hostId`、`recommendDoc`、`requestId`、`serverTime`、`status`、`rawErrorInfo`。确认真实运行时字段名是否与 d.ts 一致。
4. 在可控 POC 中分别验证“有 Content-MD5”和“无 Content-MD5”的 PUT 行为。若只有带 MD5 失败，必须以 OSS Code 证明后再修改请求策略；医疗文件的本地 MD5 与登记字段仍需保留。
5. 核验 SDK `putObject` 对 `headers['content-type']`、`contentMD5`、`useStream:true`、`FilePath(localPath)` 的组合支持；如果 SDK 版本行为不确定，先以供应商文档/源码 POC 复核，不靠猜测改参数。
6. 检查 object key 不以 `/` 或 `\\` 开头、bucket 名合规、local staged 文件可读且文件大小与 hash 阶段一致。

#### P1-D：文件登记与恢复链路回归

修复 OSS PUT 后，必须继续验证 PUT 成功但 register 失败的补偿语义：

1. `POST /api/v1/files/register/` 成功时，返回的 `file_uuid` 与 `object_key` 必须匹配本次请求。
2. register 失败时只创建/保留 `uploaded_unregistered`，不重传对象；重试仅调用 register。
3. HTTP 401、服务端业务失败、网络超时、返回字段不一致必须分别映射，不能被误报为 OSS 拒绝。
4. AI 上传流程中多文件按顺序推进；前一文件成功后后一文件失败时，继续识别应跳过已有 `remoteFile`，避免重复对象和重复登记。

## 5. 目标错误模型与接口异常传播方案

### 5.1 错误责任边界

| 层 | 必须做什么 | 禁止做什么 |
| --- | --- | --- |
| OSS adapter | 将 Vendor SDK 异常解码为受控 `FileTransferError`；保留非敏感诊断字段 | 不直接弹 toast/banner；不抛 Vendor 原始对象；不记录 secret/XML 全文。 |
| FileTransferService | 按阶段决定一次 STS 刷新、上传/登记补偿、`retryable`；写结构化诊断日志 | 不把 OSS 失败伪装为 register 失败；不在页面层拼中文文案。 |
| 文件错误本地化器（新增公共职责） | `FileTransferError`/`SupportNetworkError` → 用户文案、展示方式、动作、是否展示客服定位号 | 不读取 SDK 原始对象；不泄漏 bucket、endpoint、objectKey、签名或 RequestId。 |
| MedicalDocumentUploadViewModel | 保留 `failedStep` 和错误展示模型，触发一次统一通知，驱动“重试上传/返回选择” | 不再以 `error.message` 作为唯一状态；不直接依赖 OSS SDK。 |
| Picking/Progress/Host 页面 | 显示页面内恢复动作和状态；Host 负责覆盖层生命周期 | 不各自 `promptAction.showToast`；不重复发多次 banner。 |
| NotificationClient | 作为唯一系统内提示入口，错误使用 banner，成功使用 toast | 不代替流程页面展示可恢复操作；不携带技术细节。 |

### 5.2 `FileTransferError` 的目标诊断字段

保留既有字段：`code`、`stage`、`retryable`、`requestId`、`httpStatus`、`safeMessage`。

在不改变用户 UI 文案的前提下，补充仅供内部日志/测试使用的受控字段：

| 字段 | 来源 | 日志规则 | 用户可见性 |
| --- | --- | --- | --- |
| `ossCode` | SDK `code` / XML `Code` | allowlist，最多 64 字符 | 否 |
| `ossEc` | SDK `ec` | allowlist，最多 64 字符 | 否 |
| `ossRequestId` | SDK `requestId` | 写入结构化 `requestId` 或明确 OSS 字段；最多 128 字符 | 默认否；仅客服诊断页按产品审批展示短定位号 |
| `httpStatus` | SDK `status` | `LogFields.code` 或显式字段 | 否 |
| `operation` | 固定 `oss.put_object` | allowlist | 否 |
| `objectKeyFingerprint` | object key 的不可逆摘要 + 长度/版本 | 不输出原文 | 否 |
| `contentTypeCategory` | `image` / `pdf` / `other` | allowlist | 否 |
| `stsAgeBucket` | fresh / near_expiry / refreshed_once | allowlist | 否 |

绝不允许进入异常、日志、Notification、RDB 或 Preferences 的内容：access key、access key secret、security token、Authorization、完整 request headers、完整 OSS URL、签名 query、完整 object key、原始文件路径、文件内容、完整 OSS XML 错误体、手机号/成员名。

### 5.3 OSS 状态到业务错误的映射矩阵

| 条件（以 OSS Code 优先） | 目标 `FileTransferError` | 重试策略 | 用户提示 | 页面动作 | 诊断处理 |
| --- | --- | --- | --- | --- | --- |
| `RequestTimeTooSkewed` | `ossClockSkew`（新增）或明确的 `ossRejected` 子原因 | 不自动重试；引导校准设备时间后重试 | “设备时间异常，请校准系统时间后重试。” | 重试、返回选择 | 记录 OSS Code/RequestId/serverTime，不记录签名。 |
| 401/403 且 Code 表示 token/签名过期 | `credentialsExpired` | STS invalidate 后仅重取并重传一次 | 首次不提示；二次失败提示“上传凭证已失效，请重试。” | 重试 | 记录 refresh 次数、OSS Code、RequestId。 |
| 403 且 Code 表示 AccessDenied/策略拒绝 | `ossAccessDenied`（新增） | 不自动重试 | “暂时无法上传，请稍后重试。” | 返回选择；可重试 | P0 运维告警，记录 OSS Code/RequestId。 |
| 400 `BadDigest` / `InvalidDigest` | `integrityMismatch` 或 `ossRequestInvalid` | 不自动重试，先修请求 | “文件校验失败，请重新选择文件后重试。” | 返回选择 | 记录 content type 分类、MD5 是否存在、OSS Code。 |
| 400 参数/对象 key/请求头错误 | `ossRequestInvalid`（新增） | 否 | “文件暂不支持上传，请重新选择文件。” | 返回选择 | 记录 OSS Code 和 objectKey fingerprint。 |
| 404 bucket/object endpoint 相关 | `ossConfigurationInvalid`（新增） | 否 | “上传服务配置异常，请稍后再试。” | 返回选择 | 触发研发告警；记录 endpoint fingerprint、region（非明文 URL）。 |
| 409/412 冲突 | `ossConflict`（新增） | 按 OSS Code 决定；默认否 | “文件上传状态冲突，请稍后重试。” | 重试 | 记录实际 Code/RequestId。 |
| 429/5xx | `ossTransientFailure` | 有界退避，上传对象可从 staging 重传；总次数由统一策略控制 | “网络或上传服务繁忙，正在重试…”；耗尽后“上传失败，请稍后重试。” | 取消、重试 | 记录 retryCount、elapsedMs、HTTP status。 |
| DNS/超时/连接中断 | `networkUnavailable` / `ossTransientFailure` | 有界重试 | “网络不稳定，请检查网络后重试。” | 重试 | 不伪造 HTTP status。 |
| 用户取消 | `cancelled` | 不自动重试 | 不显示错误 banner | 返回选择 | 记录 `cancelled`，不记 error。 |
| OSS 成功、register 失败 | `registrationPending` | 只重试 register | “文件已上传，正在保存附件。请重试。” | 重试保存 | 记录 SparkService requestId，与 OSS 无关。 |

新增 code 前必须同步更新：`FileStorageModels.ets` 的联合类型、文件错误本地化器、日志测试、FileTransferService 测试、MedicalDocumentUpload VM 测试，以及全局错误对照矩阵。若产品不希望扩大错误枚举，至少应新增一个受控 `reason` 字段；不能再把所有 4xx 合并为“上传被拒绝”。

## 6. 统一应用内错误提示对齐方案

### 6.1 当前偏差

HarmonyOS 已有根级 `AppNotificationHost` 和 `NotificationClient.error(message, title, source)`：error 会进入 banner；Home/账户等模块已经以该方式发布失败提示。但医疗上传的 `MedicalDocumentUploadAssembly` 只装配 uploader/use case/VM，未传入 `NotificationClient`；VM catch 后仅设置字符串，Picking 页直接渲染红字。

iOS `MedicalDocumentUploadHostView` 会以 alert 展示流程错误，根 `NotificationHostView` 同时负责应用内 banner/toast/alert。对齐目标不是在 HarmonyOS 硬复制 SwiftUI alert，而是：

1. **流程内错误保留在上传页**：显示失败在哪个步骤、可执行动作和错误状态，避免 banner 一闪而过后用户不知道怎么恢复。
2. **系统内错误统一通过 `NotificationClient`**：只发布一次简洁 banner；跨页面/全屏覆盖层仍可见，避免业务页面各自 toast。
3. **技术细节只进入脱敏日志**：用户不能看到“ossRejected”、HTTP 状态、request ID、bucket 或 SDK 文案。

### 6.2 用户界面状态与文案规范

| 场景 | 页面内状态 | 系统内通知 | 主操作 | 次操作 |
| --- | --- | --- | --- | --- |
| 可重试网络/5xx | 上传步骤标红：“上传失败，请检查网络后重试。” | banner，同文案，source=`medical.upload` | “重试上传” | “返回文件选择” |
| 凭证二次失效 | 上传步骤标红：“上传凭证已失效，请重试。” | banner | “重新上传” | “取消” |
| 文件不可读/校验/格式问题 | 选中文件条目标红，显示“该文件无法上传，请重新选择。” | 可不发全局 banner，避免局部校验打扰 | “重新选择” | “移除文件” |
| 服务配置/权限拒绝 | 上传步骤标红：“暂时无法上传，请稍后重试。” | banner | “稍后重试” | “返回文件选择” |
| 已上传未登记 | 上传步骤标黄：“文件已上传，等待保存。” | warning banner | “重试保存” | “返回” |
| 用户取消 | 回到选择页，保留已成功的文件 | 不发 error | “继续识别” | “清空” |

文案必须资源化，至少提供简体中文；英文及其他 locale 使用同一语义 key。禁止把 SDK 的中文/英文 message 原样作为 UI 文案，也禁止页面与 banner 同时无限重复发布。

### 6.3 去重、生命周期和账号隔离

1. 一个 `transferId + failedStep + normalizedErrorCode` 在 3 秒窗口内最多发布一次 notification；页面重绘、VM listener、Host appear/disappear 不得重复发布。
2. 页面正在前台且错误已在固定上传进度区清晰显示时，可将通知降为一次 banner；不再加 `promptAction.showToast`。
3. 用户点击“重试”后清除该次展示状态；新的失败可重新发布。
4. account generation 变化、登出、关闭全屏 Host 时，旧上传任务不得向新账号页面发布通知；通知 source 只保留业务模块名，不含成员/账号明文。
5. OCR/AI 未接入的“待实现”失败与 OSS 上传失败必须区分：前者是功能可用性提示，后者是文件传输错误；不能都显示“上传失败”。

## 7. 结构化日志与系统接口补充方案

### 7.1 事件清单

| 事件 | 级别 | 必填字段 | 触发点 | 禁止字段 |
| --- | --- | --- | --- | --- |
| `oss.sts.requested` | info | operation、accountHash、requestId | 发起 STS 请求 | 凭证 body。 |
| `oss.sts.succeeded` | info | requestId、elapsedMs、stsAgeBucket、regionAlias | 解码成功 | AK/SK/token/bucket 明文。 |
| `oss.sts.failed` | error | requestId、httpStatus、backendCode、elapsedMs | STS 请求/解码失败 | 响应 data。 |
| `oss.put.started` | info | operation、transferIdHash、contentTypeCategory、sizeBucket | PUT 前 | localPath、object key 原文、文件名。 |
| `oss.put.failed` | error | ossRequestId、httpStatus、ossCode、ossEc、stage、retryable、elapsedMs、objectKeyFingerprint | SDK catch 后 | raw XML、HostId 原文（如含敏感域信息）、secret。 |
| `oss.put.retrying` | warn | retryCount、reason、stsRefreshed | 一次凭证刷新/重传 | 凭证。 |
| `file.upload.failed` | error | code、stage、retryable、requestId、httpStatus、operation | 公共服务最终失败 | 仅 `detail=上传被拒绝` 的无上下文摘要。 |
| `medical.upload.vm.pipeline_failed` | warn/error | operation、step、normalizedErrorCode、retryable、transferCount | VM 收敛失败 | SDK 原文、用户文件名。 |
| `medical.upload.error_presented` | info | normalizedErrorCode、presentation=banner|inline、deduplicated | 实际发布 UI 时 | 用户内容。 |

`LogEvent` 当前白名单只有 `requestId/route/operation/code/elapsedMs/retryCount/accountHash/detail`。实施时应优先复用这些字段；若确有 `ossRequestId` 与 SparkService requestId 同时存在的需求，需明确新增一个专用白名单字段，而不是塞入长 `detail` 后再依赖字符串解析。

### 7.2 关联规则

| 关联目标 | 关联键 | 说明 |
| --- | --- | --- |
| HarmonyOS STS 请求 ↔ SparkService | `X-Request-ID` / 响应 `X-Request-ID` | 由 `SupportNetworkEngine` 生成并传递；后端 `RequestIdMiddleware` 回写。 |
| HarmonyOS OSS PUT ↔ 阿里云 OSS | OSS `RequestId` | SDK 异常对象中的 `requestId`；与服务端 HTTP request ID 不是同一个值。 |
| 同一上传流程内事件 | `transferId` 的不可逆摘要 | 用于串起 stage，不输出原值或文件信息。 |
| 上传与账号会话 | `accountHash` + generation（仅进内存/受控日志） | 防止跨账号误关联。 |

### 7.3 服务端日志补充范围

本次 SparkService 不需要代理二进制上传，但应补充 STS 签发可观测性：

1. `STSCredentialsAPIView` 的成功/失败日志统一包含 Django `request_id`、环境别名、region 别名、bucket 配置是否为空、role 模式（STS/static-development，不能记录 role ARN 明文）。
2. 5001/5002 的响应保持既有 `{code,msg,data}` 契约；`data.request_id` 与 response header 都应可用于排查。
3. 生产禁止返回或日志打印 STS credential 字段；现有 `logger.info("OSS STS 签发成功 user_id=...")` 可以增加无敏感的关联字段。
4. OSS PUT 拒绝以 OSS RequestId 去阿里云侧查询；不要试图让 Django 伪造“OSS 错误码”。

## 8. 实施任务拆分（仅工单，不在本次执行）

### 阶段 0：复现与根因冻结（P0）

| 编号 | 工作项 | 责任边界 | 交付物 | 完成条件 |
| --- | --- | --- | --- | --- |
| 0.1 | 在测试环境复现最小图片与最小 PDF 上传 | 客户端 + QA | 复现记录 | 每次都有 transfer 摘要、STS request ID、OSS RequestId 或明确缺失原因。 |
| 0.2 | 查询 OSS 拒绝的 HTTP status/Code/RequestId | 云资源/后端 | OSS 排查结论 | 结论能区分权限、签名、时间、参数、网络或 SDK。 |
| 0.3 | 核验 STS role/bucket/endpoint/region | 云资源/后端 | 配置核验表 | 只记录是否一致与审计证据，不泄露配置值。 |
| 0.4 | 复核 Vendor SDK error runtime 字段 | HarmonyOS | POC/单测结果 | 与 d.ts 的 `status/requestId/code/ec/...` 对应关系明确。 |

### 阶段 1：公共错误与诊断收口（P0）

| 编号 | 目标模块/文件 | 实施内容 | 依赖 | 验收 |
| --- | --- | --- | --- | --- |
| 1.1 | `Projects/Core/OSS/OSSClientAdapter.ets` | 建立显式 SDK error decoder；保留 status、OSS Code、EC、RequestId 等安全诊断字段；禁止不安全 Record/原始 body 泄漏 | 阶段 0.4 | 每类 fixture 都得到稳定错误分类；敏感字段断言不出现在日志。 |
| 1.2 | `Core/FileStorage/FileStorageModels.ets`、`FileTransferService.ets` | 细化 OSS 拒绝原因与一次 STS 刷新重试边界；保持 register 补偿语义 | 1.1 | 401/403 过期、4xx policy、4xx digest、429/5xx、network、cancel、register 失败分支独立通过。 |
| 1.3 | `Foundation/Logging/*` | 用白名单事件补齐 OSS/上传关联字段；增加测试捕获断言 | 1.1 | 能用 request ID 定位，且无 token/header/objectKey 原文。 |
| 1.4 | `Projects/Core/Networking/BackendErrorLocalizer.ets` 或新增文件领域 localizer | 建立 FileTransferError → 用户文案/操作模型；不污染后端 API localizer 的职责 | 1.2 | 所有错误 code 都有本地化 fallback，未识别错误不暴露技术文本。 |

### 阶段 2：AI 上传报告体验接入（P0）

| 编号 | 目标模块/文件 | 实施内容 | 依赖 | 验收 |
| --- | --- | --- | --- | --- |
| 2.1 | `MedicalDocumentUploadAssembly.ets` | 将既有 `NotificationClient` 通过组合根注入 VM；不在页面 new 通知客户端 | 阶段 1.4 | 用例/页面可替换 fake notification，组合根只有一套实例。 |
| 2.2 | `MedicalDocumentUploadViewModel.ets` | 将异常收敛为展示模型；保留 `failedStep/retryable`；按去重规则发布一次统一通知 | 2.1 | 不再直接以 `error.message` 决定用户文案；旧任务不会向新会话发布通知。 |
| 2.3 | `MedicalDocumentUploadHostPage.ets`、`PickingPage.ets` | 在 processing/picking 中展示失败步骤、重试/返回/移除动作；资源化文案 | 2.2 | 不靠短暂 toast 才能恢复；PDF 与图片均可操作。 |
| 2.4 | 应用通知 Host | 验证 full-screen ContentCover 上 banner 的层级与关闭行为 | 2.1 | banner 不被上传全屏页遮挡，不重复出现，手动关闭后状态一致。 |

### 阶段 3：服务端与多场景回归（P1）

| 编号 | 工作项 | 说明 | 完成条件 |
| --- | --- | --- | --- |
| 3.1 | SparkService STS 日志/测试补充 | 不改变响应字段；增加 request ID 与无敏感诊断 | 401/5001/5002/200 均有稳定响应与关联 ID。 |
| 3.2 | 聊天附件、药箱附件回归 | 它们共享 FileTransferService，确认不会被医疗 UI 特化破坏 | 同一错误码在不同场景显示各自业务文案，但底层日志/重试一致。 |
| 3.3 | iOS 行为复核 | 保持 API、STS、register 顺序和用户可见“可恢复失败”语义一致 | 不因 HarmonyOS 修复引入新的服务端字段或平行 endpoint。 |

## 9. 测试与验收矩阵

### 9.1 自动化测试

| 测试类别 | 场景 | 断言 |
| --- | --- | --- |
| OSS decoder 单元测试 | SDK 错误 fixture 含 `status=400/401/403/404/409/429/500`，分别含/缺 `requestId`、`code`、`ec` | 输出 code/retryable/stage/HTTP status 正确；无原始错误 body 泄漏。 |
| 凭证重试测试 | 第一次是确定的凭证过期，第二次成功/失败 | 仅 invalidate + refresh + PUT 重试一次；第二次失败不会死循环。 |
| 非凭证 4xx 测试 | `BadDigest`、`AccessDenied`、请求参数错误 | 不取得新 STS、不盲重传；返回正确用户动作模型。 |
| 登记补偿测试 | PUT 成功、register 网络失败/500/响应不匹配 | `uploaded_unregistered`，只重试 register，不重复 PUT。 |
| VM 测试 | FileTransferError、SupportNetworkError、普通 Error、取消 | failedStep 为 upload；本地错误状态与 Notification intent 一致；取消无 error banner。 |
| 通知去重测试 | 同一失败回调多次、重复页面渲染、用户点击重试 | 同一窗口仅一条 banner；重试后可重新发布。 |
| 日志安全测试 | 构造含 AK/SK/token/header/URL/object key 的异常 | capture sink 中不存在敏感片段；允许 OSS RequestId/HTTP status/OSS Code。 |

### 9.2 人工验收

| 编号 | 场景 | 操作 | 预期 |
| --- | --- | --- | --- |
| M-01 | 正常图片 | 选择成员、图片、开始识别 | 上传完成，进入当前 OCR 待接入的明确状态；日志有 `oss.put.started/succeeded`，随后才有 register。 |
| M-02 | 正常 PDF | 选择 PDF 并开始识别 | 与图片相同；不因 MIME/文件选择路径不同失败。 |
| M-03 | 无网络 | 断网后开始上传 | 用户看到“网络不稳定”；可重试；不显示 ossRejected。 |
| M-04 | 凭证过期 | 使用可控 mock/短凭证 | 自动刷新一次；成功不打错误；失败给可重试提示。 |
| M-05 | OSS AccessDenied | 测试环境临时制造策略拒绝 | 不自动死循环；用户不看到 bucket/AccessDenied；研发可凭 OSS RequestId 定位。 |
| M-06 | MD5/请求校验错误 | 测试 fixture 制造 BadDigest/参数错 | 页面建议重新选择；日志能区分 Code。 |
| M-07 | register 失败 | PUT 成功后模拟 SparkService 5xx/网络断开 | 显示“已上传，等待保存”；重试不会再 PUT。 |
| M-08 | 多文件第二项失败 | 第一项成功、第二项被拒绝 | 已成功项保留 remoteFile；继续后不重复上传第一项。 |
| M-09 | 关闭/切号 | 上传中关闭 full-screen 或切换账号 | 不出现跨账号 banner/文件登记；资源回收不被误报为根因。 |
| M-10 | 全屏通知层级 | 在 AI 上传报告全屏页触发失败 | 一个 banner 可见且可关闭；页面内仍有重试按钮。 |

### 9.3 构建与发布门槛

1. 实施后必须在 `SparkClientHarmonyOS` 真实工程以当前 API Level 完成 `CompileArkTS` 与 `assembleHap`；编译错误数必须为 0。
2. 不得以“日志没有报错”替代真机/模拟器 OSS 联调；必须至少完成 M-01、M-02、M-03、M-05、M-07。
3. SparkService 的接口测试必须保持 `/api/v1/oss/sts/credentials/`、`/api/v1/files/register/` 的 path、method、响应包裹、认证、`X-Request-ID` 一致。
4. 任何新增日志字段都要通过脱敏测试；发现 secret/object URL 泄漏为发布阻断。
5. 工单关闭前必须将根因归因改为具体 OSS status/Code/配置或 SDK 事实；“上传被拒绝”不是根因结论。

## 10. 风险、边界与待确认项

| 编号 | 风险/待确认项 | 影响 | 关闭条件 |
| --- | --- | --- | --- |
| R-01 | 本次真实 OSS HTTP status、Code、RequestId 缺失 | 无法定位真实根因 | 阶段 0 的同次客户端/OSS 关联证据完整。 |
| R-02 | SDK d.ts 与设备实际异常字段可能不一致 | decoder 可能仍取不到关键字段 | 以设备 POC fixture/运行时结果确定字段读取策略。 |
| R-03 | 当前 OSS 4xx 统一 `ossRejected`，错误粒度过粗 | 用户无正确恢复动作，研发无法统计 | 完成阶段 1 的受控错误 reason/code。 |
| R-04 | STS 签发成功不等于阿里云 bucket policy 实际允许 PUT | 可能误以为后端接口无问题 | 阿里云 RAM/bucket policy/endpoint/region 核验通过。 |
| R-05 | 提示层可能发生 inline/banner/toast 重复 | 体验噪声 | 完成通知去重与全屏 Host 验收。 |
| R-06 | 扩大日志字段可能泄露医疗文件或凭证 | 安全与合规风险 | 白名单、脱敏、测试 capture 和代码审查通过。 |
| R-07 | iOS 当前 SDK error 也偏字符串化 | 多端错误统计仍可能不对齐 | 明确跨端错误 taxonomy；iOS 是否补结构化诊断另立兼容子任务，不阻塞本次 HarmonyOS 修复。 |
| R-08 | OCR 及后续步骤当前仍待接入 | 正常上传后流程仍会在 OCR 以“待接入”结束 | UI 明确区分“上传成功”与“OCR 尚未接入”；不将其误归为 OSS 故障。 |

## 11. 本工单涉及的证据路径

- HarmonyOS 公共文件服务：`SparkClientHarmonyOS/entry/src/main/ets/Core/FileStorage/FileTransferService.ets`
- HarmonyOS 文件错误模型：`SparkClientHarmonyOS/entry/src/main/ets/Core/FileStorage/FileStorageModels.ets`
- HarmonyOS OSS adapter：`SparkClientHarmonyOS/entry/src/main/ets/Projects/Core/OSS/OSSClientAdapter.ets`
- HarmonyOS STS API/store：`SparkClientHarmonyOS/entry/src/main/ets/Projects/Core/Networking/API/OSS/OSSAPI.ets`、`Projects/Core/OSS/OSSRuntimeConfigStore.ets`
- HarmonyOS AI 上传报告：`SparkClientHarmonyOS/entry/src/main/ets/Projects/Features/MedicalDocumentUpload/`
- HarmonyOS 统一日志/通知：`SparkClientHarmonyOS/entry/src/main/ets/Foundation/Logging/`、`Projects/Core/Notification/`、`App/Notification/`
- Vendor SDK 类型证据：`SparkClientHarmonyOS/entry/third_party/aliyun-oss/aliyun-oss/src/main/common/utils/requestErrorBase.d.ts`
- iOS 文件与上传流程：`SparkClient/SparkClient/Projects/Core/FileStorage/FileTransferService.swift`、`Projects/Core/OSS/OSSClient.swift`、`Projects/Features/MedicalDocumentUpload/`
- SparkService STS/文件登记：`SparkService/file_manager/oss_sts_views.py`、`oss_urls.py`、`sts_utils.py`、`views.py`、`serializers.py`
- 现有总方案：`SparkClientHarmonyOS/开发详细技术文档/文件与 OSS/文件与OSS详细技术方案.md`

## 12. 本次产出说明

本工单已把“OSS 日志补充、从接口到业务链路对齐、错误抛出与系统内提示优化”拆成可独立验证的阶段。

**实现状态（2026-07-24）**：阶段 1 / 阶段 2 / 阶段 3.1 已在工程落地：

- HarmonyOS：`OSSErrorDecoder`、细化 `FileTransferError`、结构化 `oss.*` / `file.upload.*` 日志白名单（含 `ossRequestId`）、`FileTransferErrorLocalizer`、医疗上传 `NotificationClient` 注入与去重 banner、Host 内嵌通知层与可恢复动作。
- SparkService：STS 成功/失败日志补充 `request_id` / 环境别名 / region 别名 / role_mode；5001/5002 的 `data.request_id` 可用于关联（响应外层契约未改）。

仍依赖联调关闭：阶段 0 的真实 OSS status/Code/RequestId 根因冻结，以及 M-01/M-02/M-03/M-05/M-07 人工验收。
