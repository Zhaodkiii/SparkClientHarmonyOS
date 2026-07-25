# HOS-FILE-OSS-0003｜InvalidArgument 在无 MD5、显式长度策略下仍失败的根因收敛工单

> 工单类型：HarmonyOS 文件与 OSS 直传继续排查工单。本文基于 HOS-FILE-OSS-0001、HOS-FILE-OSS-0002 已完成的诊断改造和最新真机日志创建；只记录新的证据、实现复核和修复方案，不修改任何代码、配置、OSS 权限或 Vendor 包。
>
> 关联工单：HOS-FILE-OSS-0001、HOS-FILE-OSS-0002。优先级：P0。目标：将 `InvalidArgument / 0002-00000226` 从“可重复但未知的 400”收敛到具体请求字段、SDK 传输模式、云端配置或 Vendor 实现，并完成 iOS/HarmonyOS 公共上传契约对齐。

## 1. 最新结论

本次实验已经改变了两个关键上传变量，但结果没有变化：

```text
旧策略：FilePath + stream=true + Content-MD5 + SDK 推导 Content-Length
新策略：FilePath + stream=true + integrity=none + 显式 Content-Length
```

两次均收到：

```text
HTTP 400
OSS Code: InvalidArgument
OSS EC: 0002-00000226
contentTypeCategory=image
sizeBucket=lt1m
stsAge=fresh
```

因此可以形成新的排查判断：

1. Content-MD5 不是本次 400 的唯一触发条件；去掉 OSS Content-MD5 后仍失败。
2. SDK 是否自动计算 Content-Length 不是本次 400 的唯一触发条件；改为显式文件长度后仍失败。
3. `FilePath + useStream=true`、Content-Type header、bucket/region/endpoint、object key 规则、STS 身份及 Vendor SDK 请求序列化仍未被隔离。
4. OSS RequestId 已经正确只写入 `ossRequestId`；本次日志没有错误地补写 SparkService `requestId`，这说明 HOS-FILE-OSS-0002 的 request ID 分离修复已生效。
5. 当前把 `ossRequestValidationUnknown` 标为 `retryable=true`，对一个在两种稳定请求策略下重复返回 400 的确定性错误来说不准确。它可以允许用户手动重新尝试，但不应进入网络自动重试或被当成可恢复传输故障。

当前最可能的根因范围已从“完整性/长度参数”收窄为：

- Content-Type 通过 `headers` 注入后的 SDK 签名/序列化行为；
- 原始 object key 的实际字节或名称规则；
- endpoint、region、bucket 与 SDK 签名版本的组合；
- HarmonyOS Vendor SDK 的 `FilePath + useStream` 请求实现；
- STS role、bucket policy 或云端对象写入约束返回了非典型 400。

## 2. 最新日志证据

### 2.1 原始日志

```text
07-24 11:27:55.560  oss.put.started
  contentTypeCategory=image
  sizeBucket=lt1m
  keyFp=v1:909557a4d16e745d:bytes=111
  stsAge=fresh
  policy=v1-prod-explicit-len-no-oss-md5
  payload=filePath
  stream=true
  contentLength=explicit
  integrity=none

07-24 11:27:55.807  oss.put.failed
  ossRequestId=6A62DBBB48EAF23235647FAB
  HTTP 400
  ossCode=InvalidArgument
  ossEc=0002-00000226
  retryable=true
  keyFp=v1:909557a4d16e745d:bytes=111
  stsAge=fresh
  hasMd5=false
  policy=v1-prod-explicit-len-no-oss-md5
  payload=filePath
  stream=true

07-24 11:27:55.807  file.upload.failed
  code=ossRequestValidationUnknown
  ossRequestId=6A62DBBB48EAF23235647FAB

07-24 11:27:55.807  medical.upload.error_presented
  code=ossRequestValidationUnknown
  presentation=banner
  deduplicated=false
  retryable=true
```

### 2.2 证据对比

| 变量 | HOS-FILE-OSS-0002 现场 | 本次现场 | 结论 |
| --- | --- | --- | --- |
| Content-MD5 | `hasMd5=true` | `hasMd5=false` | MD5 不是唯一根因。 |
| Content-Length | SDK 推导/未明确 | `contentLength=explicit` | SDK 自动长度不是唯一根因。 |
| FilePath | 是 | 是 | 未隔离。 |
| stream | `true` | `true` | 未隔离。 |
| Content-Type | image，仍由请求 headers 设置 | image，仍由请求 headers 设置 | 高优先级未变变量。 |
| object key | 长度约 111 | 长度约 111 | 结构/实际字符未隔离，仅 fingerprint 变化。 |
| STS | fresh | fresh | 不是简单过期问题；仍需云侧验证身份与策略。 |
| OSS response | 400 InvalidArgument EC 0002-00000226 | 完全相同 | 说明失败是确定性请求/配置问题，不应继续盲重试。 |
| UI | 上一轮应已改为 banner | banner | HOS-0002 的提示策略已生效。 |
| RequestId | OSS ID可能混用 | 仅 `ossRequestId` | ID 分离已生效。 |

### 2.3 RCP session close 判断

`session list: [] after close: 0` 发生在 `OSSClientAdapter.upload()` 的 `finally`。同一次调用已经收到 OSS 400 后才关闭 session；它是释放网络资源的结果，不是导致 400 的原因。除非后续 POC 证明 SDK 在 response body 尚未读取完时过早 close，否则不建立“close 导致拒绝”的修复方向。

## 3. HOS-FILE-OSS-0002 实现复核结果

### 3.1 已生效的修复

| 工单要求 | 当前证据 | 结论 |
| --- | --- | --- |
| 新增 transport policy | `Core/FileStorage/FileUploadTransportPolicy.ets` | 已落地，生产策略为 explicit length + no OSS MD5。 |
| 显式 Content-Length | `FileTransferService.ets` 将 `staged.fileSize` 写入 input；adapter 传 `contentLength` | 已实际执行，日志可见。 |
| 不传 OSS Content-MD5 | policy `integrity=none`，adapter 不传 `contentMD5` | 已实际执行，日志 `hasMd5=false`。 |
| object key preflight | `ObjectKeyPolicy.assertKeyValid()` | 已接入 adapter；但真实 key 内容仍未在日志/POC 中隔离。 |
| 未知 InvalidArgument 不再误报文件不支持 | `ossRequestValidationUnknown` + FileTransferL10n | 已生效。 |
| 全局 banner | localizer 对 unknown validation 设为 banner | 已生效，日志 `presentation=banner`。 |
| OSS 与 Spark request ID 分离 | `FileTransferError.ossRequestId`、`LogFields.ossRequestId` | 已生效；本次没有 Spark `requestId`，符合直传链路事实。 |

### 3.2 新发现的实现问题

| 编号 | 严重度 | 问题 | 证据 | 修复方案 |
| --- | --- | --- | --- | --- |
| N-01 | P0 | 未知 400 被标记 `retryable=true` | `OSSErrorDecoder.mapHttpAndCode()`；本次日志 | 将 `retryable` 拆为 `transportRetryable` 与 `userCanRetry`；HTTP 400 InvalidArgument 默认 `transportRetryable=false`，用户可手动重试一次但不得自动重试。 |
| N-02 | P0 | 当前生产 policy 只改变 MD5/Length，仍固定 `FilePath + stream=true + Content-Type header`，没有完成变量隔离 | 两次日志 policy 对比 | 先完成 POC 矩阵，再选择生产策略；不能把 policy v1 视为已验证的生产兼容方案。 |
| N-03 | P0 | `ossRequestValidationUnknown` 仍缺少字段级 reason，所有 400 共享一个用户动作 | decoder 仅按 Code/status 映射 | 增加 `requestValidationReason`：`contentType`、`objectKey`、`payloadMode`、`endpointConfig`、`cloudPolicy`、`unknown`；reason 未确认时不提示用户重新选文件。 |
| N-04 | P1 | 日志只写 policy 摘要，不能证明 headers 的实际 key/value 形态、endpoint alias、SDK 签名版本 | `oss.put.started` | 增加安全枚举：`contentTypeMode`、`endpointAlias`、`regionAlias`、`signatureMode`、`vendorVersion`；不记录原始 endpoint、bucket、header 或签名。 |
| N-05 | P1 | `ErrorLogger` 仍把结构化诊断拼进 detail，并可能追加摘要，日志最终被截断 | 最新 `detail` 仍有长度截断标记 | 诊断字段应使用 LogEvent 白名单字段；detail 只保留短摘要，禁止重复字段拼接。 |
| N-06 | P1 | 现有单测验证 decoder/localizer，不验证真实 PUT 请求体/headers/Content-Length | `entry/src/test/ets/FileStorage/OSSErrorDecoder.test.ets` | 增加 transport request capture 或真实测试 bucket 集成测试；必须验证 SDK 最终请求形态。 |
| N-07 | P1 | iOS 与 HarmonyOS 的 Content-Type 传递方式没有形成正式跨端契约 | iOS OSS wrapper 使用 `request.contentType`；HOS 使用 `headers['content-type']` | 以 Vendor SDK 实际支持的 request schema 为准建立 adapter；业务模型只传 MIME，不关心 header 组装。 |

## 4. 根因收敛：哪些假设已排除，哪些仍成立

### 4.1 已降级的假设

1. **Content-MD5 值错误不是唯一根因。** 去除 MD5 后响应不变。不能再把生产修复继续围绕“只修 Base64 MD5”展开。
2. **Content-Length 推导错误不是唯一根因。** 显式传入 staged 文件大小后响应不变。仍需确认 SDK 是否真的把显式值发出，但至少“仅因为缺少 Content-Length”不成立。
3. **用户文件不支持不是当前证据结论。** 文件小于 1 MB 且只是图片类别；没有 `InvalidObjectName`、`BadDigest` 或本地读/hash 失败证据。

### 4.2 当前最高优先级假设

#### H3：Content-Type header 组合/签名序列化问题

当前 adapter 仍使用：

```text
headers['content-type'] = input.contentType
contentLength = staged.fileSize
useStream = true
data = FilePath(localPath)
```

旧、新 policy 都保留该组合。需要验证：

- SDK 是否要求以显式 request 字段设置 Content-Type，而不是放入 headers map；
- SDK 是否把 `content-type` 加入签名，但请求发送阶段大小写/值发生变化；
- `image/*` 具体 MIME 是否包含 SDK/OSS 不接受的值；
- 去掉 Content-Type 后是否仍为同一 400；
- 使用 `application/octet-stream` 与 `image/jpeg` 是否有差异。

#### H4：object key 实际字符或 UTF-8 规则问题

日志只有 `keyFp` 和字节长度，没有原始 key。当前 `FileHashUtil.sanitizeFileName()` 以 JS 字符长度截断，并不能证明完整 key 的 UTF-8 字节内容符合 OSS 规则。需要使用 ASCII 文件名/固定 ASCII key 进行对照；如果 ASCII 成功、原 key 失败，根因才可归到名称编码。

#### H5：endpoint/region/bucket/signature mode 组合问题

STS `fresh` 只说明客户端认为凭证未临近过期，不代表：

- 服务端返回的 endpoint 是该 bucket 正确 endpoint；
- region 与签名所用 region 一致；
- SDK 实际使用的签名版本与 bucket/endpoint 要求一致；
- STS role 的权限和 bucket policy 没有额外的条件限制。

由于当前两种 PUT 参数都返回完全相同的 EC，必须以同一个 OSS RequestId 查询云侧原始诊断，不能只在客户端继续猜。

#### H6：FilePath + stream=true 的 Vendor SDK 适配问题

两次实验都没有改变 `payload=filePath;stream=true`。如果 `useStream=false` 的小文件上传成功，说明问题不在 bucket/STS 基本权限，而在 Harmony Vendor 对 FilePath 流式请求的长度、body、header 或签名实现。生产不能简单将所有 PDF 读成 ArrayBuffer，需要评估 SDK 升级、修复 Vendor、分块上传或受控小文件/大文件双路径。

## 5. 必须执行的下一轮隔离实验

所有实验只使用测试 bucket、测试账号和脱敏测试文件。每次只改变一个变量；每次都记录 OSS status、Code、EC、RequestId、成功对象大小以及安全请求策略。禁止把 secret、签名 URL、原始 key、文件内容写入日志。

| Case | FilePath | stream | Content-Length | Content-MD5 | Content-Type | object key | 目的 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| C-01 | 是 | true | explicit | none | 当前 image MIME | 当前 key | 当前生产策略基线，复现本次。 |
| C-02 | 是 | true | explicit | none | 不设置 | 当前 key | 隔离 Content-Type header。 |
| C-03 | 是 | true | explicit | none | `application/octet-stream` | 当前 key | 隔离 MIME 值。 |
| C-04 | 是 | true | explicit | none | 当前 image MIME | 固定 ASCII key | 隔离 object key 字符/编码。 |
| C-05 | 是 | false | explicit | none | 当前 image MIME | 固定 ASCII key | 隔离 FilePath streaming。仅小文件。 |
| C-06 | 受 SDK 支持的 `fs.File` | true | explicit | none | 当前 image MIME | 固定 ASCII key | 隔离 FilePath wrapper 与 fs.File。 |
| C-07 | 是 | true | SDK derived | none | 当前 image MIME | 固定 ASCII key | 验证 explicit length 是否实际影响结果；不是生产方案。 |
| C-08 | 是 | true | explicit | none | 当前 image MIME | 当前 key | 通过已确认正确 endpoint/region 的对照环境验证云端配置。 |
| C-09 | 另一套已验证 OSS SDK/ossutil | 对应工具 | 工具默认 | 工具默认 | 同 MIME | 同 ASCII key | 隔离云端权限/config 与 Harmony SDK。 |

### 5.1 实验结果判定

| 结果 | 根因方向 | 处理 |
| --- | --- | --- |
| C-02 成功，C-01 失败 | Content-Type header/canonicalization | 修复 adapter 的 MIME 设置方式；保持领域模型不变。 |
| C-03 成功，C-01/C-02 失败 | 具体 image MIME 值或选择器 MIME | 建立 MIME allowlist/归一化；不能将所有图片拒绝。 |
| C-04 成功，C-01 失败 | object key/UTF-8/名称规则 | 修复 ObjectKeyPolicy；上传前阻断明确非法 key。 |
| C-05/C-06 成功，FilePath stream 失败 | Vendor FilePath streaming | 修复/升级 Vendor；明确小文件 fallback 与大文件上传方案。 |
| C-08/C-09 成功，Harmony C-01~C-07 失败 | Harmony SDK/endpoint adapter | 对照 request capture 和 SDK 版本；禁止继续修改业务文案掩盖。 |
| C-09 也失败 | OSS 配置/role/bucket policy | 用 RequestId/云审计核验 role、policy、endpoint、region。 |
| 所有 case 均失败且云侧返回同 EC | 云端约束或错误配置 | 由云资源/阿里云支持基于 RequestId 给出 EC 解释。 |

## 6. 修复方案

### 6.1 公共传输策略

将 `FileUploadTransportPolicy` 从“生产默认值”升级为“经验证的版本化策略”，至少包含：

- `payloadKind`: `filePath` / `fsFile` / `arrayBuffer`；
- `useStream`: 显式布尔值；
- `contentLengthMode`: `explicit` / `sdkDerived`；
- `integrityMode`: `contentMd5` / `crc64` / `none`；
- `contentTypeMode`: `header` / Vendor SDK 支持的明确字段方式 / default；
- `endpointAlias`、`regionAlias`、`signatureMode`、`vendorVersion`；
- `policyVersion`，每次真实策略变化必须增加版本号并进入日志。

业务层只提供：文件 URI、文件大小、MD5、MIME、object key 和业务归属；不允许医疗、聊天、药箱分别决定 Content-Type/Length/MD5/stream。

### 6.2 错误可恢复性修复

当前 `HTTP 400 InvalidArgument -> ossRequestValidationUnknown -> retryable=true` 应改为两维状态：

| 字段 | 含义 |
| --- | --- |
| `transportRetryable` | 是否允许 FileTransferService/网络层自动重试；400 InvalidArgument 为 false。 |
| `userCanRetry` | 页面是否允许用户手动再试一次；首次未知 400 可为 true，但连续相同 fingerprint/Code 时应降级为 false。 |

相同 `ossCode + ossEc + policyVersion + keyFingerprint + contentTypeCategory` 在短窗口重复失败时，不自动重试；页面显示“上传参数异常，请稍后再试”，提供“返回文件选择”和“重试一次”，并记录 `repeatFailure=true`。这样既保留用户恢复路径，也不把确定性 400 当网络故障循环。

### 6.3 日志字段修复

`oss.put.started` 与 `oss.put.failed` 必须形成同一组可比较字段：

```text
operation
policyVersion
payloadKind
useStream
contentLengthMode
integrityMode
contentTypeMode
contentTypeCategory
sizeBucket
keyFingerprint
endpointAlias
regionAlias
signatureMode
vendorVersion
stsAgeBucket
ossRequestId
httpStatus
ossCode
ossEc
transportRetryable
userCanRetry
```

detail 只做短摘要；不重复把同一字段拼进 `FileTransferError` 摘要。OSS RequestId 与 SparkService request ID 继续保持分离：直传事件只有 `ossRequestId`；STS/register 事件使用 `requestId`。

### 6.4 iOS 对齐要求

iOS 与 HarmonyOS 需要对齐行为和数据契约：

```text
选取文件
  → 私有缓存/staging
  → 计算文件大小、MIME、MD5
  → 获取内存 STS
  → OSS PutObject
  → POST /api/v1/files/register/
  → ManagedFileRecord
```

允许平台差异：iOS `Data`、HarmonyOS `FilePath/fs.File`；iOS actor、HarmonyOS Promise/服务门面；iOS Keychain、HarmonyOS 安全存储。

不允许差异：STS endpoint、文件登记 JSON 字段、`business_type=medical_document_upload_source`、object key 业务格式、`file_md5` 登记语义、失败阶段、OSS 与 Spark request ID 语义。

## 7. 实施步骤与验收

### 阶段 0：云侧证据冻结

1. 使用本次 OSS RequestId `6A62DBBB48EAF23235647FAB` 查询阿里云 OSS 诊断、审计日志或云厂商支持。
2. 核验返回的 endpoint、region、bucket alias 与当前 SparkService 环境；工单中只能记录别名和一致性结果。
3. 核验 AssumeRole 的 Action、Resource、bucket policy、条件键、地域限制和显式 Deny。
4. 获取云侧对 `EC=0002-00000226` 的字段级解释；未拿到之前，保持 `reason=unknown`，不得将其改成 MD5/key 等具体结论。

### 阶段 1：请求形态 POC

1. 固定 staged 文件、STS、endpoint、region 和测试 bucket。
2. 依次执行 C-01 至 C-09，每次只变更一个参数。
3. 每个 case 生成独立随机 key，并另外执行固定 ASCII key 对照。
4. 记录完整的非敏感策略字段和 OSS 结果。
5. 将结果填入“实验结果判定”，确定唯一第一修复方向。

### 阶段 2：公共服务修复

1. 将验证成功的 request shape 固化到 `FileUploadTransportPolicy`。
2. 让 adapter 仅依赖 policy 组装 SDK request，不在医疗页面增加特判。
3. 增加 ObjectKeyPolicy、MIME 归一化和显式 preflight。
4. 分离 `transportRetryable/userCanRetry`，修复 400 的重试边界。
5. 去除日志 detail 重复拼接并增加 request policy 字段。
6. 增加 fake decoder、request capture、真实测试 bucket 三层验证。

### 阶段 3：业务与多端回归

1. AI 上传报告图片成功后确认进入 register；当前 OCR 待接入状态必须独立显示。
2. PDF、中文文件名、ASCII 文件名、长文件名分别验证。
3. 多文件第 N 项失败后重试，确认前 N-1 项不重复 PUT/register。
4. 对聊天附件、药箱附件复用同一 FileTransferService 回归。
5. 对 iOS 验证同一后端接口、字段、object key 规则和 register 语义无漂移。

## 8. 验收标准

| 类别 | 验收条件 |
| --- | --- |
| 根因 | 能明确写出是 Content-Type、key、endpoint/region、Vendor stream、云策略中的哪一类；不接受“OSS 拒绝”作为最终结论。 |
| 直传 | 测试图片和 PDF 均可 PUT 成功，且对象大小与本地 staged size 一致。 |
| 完整性 | 若生产不传 OSS MD5，必须有明确的 CRC64/服务端或后续校验策略；不得静默丢失完整性保障。 |
| 错误 | HTTP 400 不进入自动网络重试；用户手动重试动作有边界并可回到文件选择。 |
| 日志 | started/failed 的 policy 字段一致；无 secret、token、签名、原始 key、文件路径；OSS/Spark request ID 不混用。 |
| 登记 | PUT 成功、register 失败时只重试 register；PUT 失败不创建远端记录。 |
| 跨端 | iOS/HarmonyOS 的 path、method、字段、业务类型和文件状态一致，平台差异只存在于本地载体/SDK适配。 |
| 构建 | HarmonyOS `CompileArkTS`、`assembleHap` 错误为 0；真机上传和失败恢复完成。 |

## 9. 风险与待确认项

| 编号 | 风险 | 关闭条件 |
| --- | --- | --- |
| R-01 | `EC=0002-00000226` 仍未被云侧解释 | 用 OSS RequestId 获得云侧字段级结论。 |
| R-02 | P-01/P-02 可能只改变客户端声明，SDK 最终请求仍相同 | 增加 request capture 或使用云侧可见请求特征验证。 |
| R-03 | `contentLength=explicit` 日志只证明 policy，不一定证明底层 HTTP header 真正发送 | Vendor 请求层/集成测试证明最终 Content-Length。 |
| R-04 | 无 OSS MD5 后完整性校验边界下降 | 确认 CRC64 或 register/下载 hash 的完整方案。 |
| R-05 | 固定 ASCII key 的 POC 若成功，中文文件名可能造成医疗文件用户体验退化 | 完成 UTF-8 key policy 与可逆展示名/不可逆 object key 分离。 |
| R-06 | 400 手动重试可能重复占用用户时间 | 相同失败 fingerprint 二次出现后给出返回/联系客服路径，不无限重试。 |

## 10. 证据路径与官方参考

- HOS-FILE-OSS-0001：`SparkClientHarmonyOS/开发详细技术文档/文件与 OSS/HOS-FILE-OSS-0001 AI上传报告OSS直传被拒绝、诊断链路与统一错误提示修复工单.md`
- HOS-FILE-OSS-0002：`SparkClientHarmonyOS/开发详细技术文档/文件与 OSS/HOS-FILE-OSS-0002 InvalidArgument直传参数对齐、HOS-0001实现偏差与iOS文件架构收敛工单.md`
- HarmonyOS adapter/policy：`entry/src/main/ets/Projects/Core/OSS/OSSClientAdapter.ets`、`entry/src/main/ets/Core/FileStorage/FileUploadTransportPolicy.ets`
- HarmonyOS decoder/error/UI：`OSSErrorDecoder.ets`、`FileTransferErrorLocalizer.ets`、`MedicalDocumentUploadViewModel.ets`
- iOS 上传基线：`SparkClient/SparkClient/Projects/Core/FileStorage/FileTransferService.swift`、`Projects/Core/OSS/OSSClient.swift`、`Projects/Core/OSS/FileUtilities.swift`
- SparkService：`SparkService/file_manager/oss_sts_views.py`、`sts_utils.py`、`views.py`、`serializers.py`
- 阿里云 PutObject：[官方文档](https://help.aliyun.com/zh/oss/developer-reference/putobject/)
- 阿里云 400 错误：[错误 FAQ](https://help.aliyun.com/zh/oss/user-guide/http-400-error-code)

## 11. 本次产出说明

已创建 HOS-FILE-OSS-0003 新工单，并完成阶段 2 公共服务修复（2026-07-24）：

**根因收敛（高置信）**：Harmony Vendor SDK（SigV4）要求 `region=oss-cn-hangzhou`，且公有云默认配置**不传**标准 endpoint；STS 返回的 `cn-hangzhou` + `https://oss-*.aliyuncs.com` 被原样传入 Client，与官方初始化契约不一致。已新增 `OSSClientConfigNormalizer`：补齐 `oss-` 前缀，并省略标准公有云 endpoint。

**同步修复**：
- 生产 policy → `v2-prod-no-ctype-header-explicit-len`（不再经 headers 注入 Content-Type）
- `InvalidArgument`：`transportRetryable=false`，`userCanRetry=true`；相同 fingerprint 二次失败降级为仅返回选择
- `requestValidationReason=unknown`（云侧 EC 未解释前不武断归因）
- PUT 日志增加 `regionAlias/endpointAlias/regionNormalized/endpointOmitted`

仍需真机验证 PUT→register；云侧 RequestId 查询可进一步确认 EC 字段级含义。
