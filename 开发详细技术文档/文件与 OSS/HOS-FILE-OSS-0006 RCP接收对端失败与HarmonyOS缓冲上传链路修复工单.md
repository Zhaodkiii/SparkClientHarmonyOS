# HOS-FILE-OSS-0006｜RCP 接收对端失败与 HarmonyOS 缓冲上传链路修复工单

> 工单类型：HarmonyOS OSS 上传 P0/P1 传输问题修复工单。
>
> 修复范围：只允许修改 `SparkClientHarmonyOS/` 项目代码、测试和技术文档。iOS 代码、服务器代码、服务器配置、OSS 权限、STS Role 和 `entry/third_party/aliyun-oss` Vendor SDK 源码均禁止修改，只能只读对照。
>
> 关联工单：HOS-FILE-OSS-0001～HOS-FILE-OSS-0005。

## 1. 问题结论

本次上传已经通过 Region/Endpoint 配置预检，并且成功进入 OSS PUT，但 HarmonyOS RCP 在接收对端数据阶段失败：

```text
RCP code=1007900056
RCP message=Failure when receiving data from the peer
httpPhase=111100
rcvDur=0.00
osErr=11
dstPort=443
proxyType=none

oss.put.failed
code=ossTransientFailure
transportRetryable=true
userCanRetry=true
reason=rcpTransport
```

这说明本次问题已经不再是：

- 图片选择失败；
- fullScreenCover 页面失败；
- STS 过期；
- Region/Endpoint 冲突；
- 400 InvalidArgument；
- 403 AccessDenied；
- OSS 权限预检失败。

当前问题集中在 HarmonyOS Vendor OSS SDK、RCP 网络层、上传 body 形态和响应接收时序之间的兼容性。

## 2. 最新日志逐条分析

### 2.1 选择器和业务入口正常

```text
[picker] photo selectResult end
medical.upload.picking.files_selected
member=450
files=1
kind=auto
source=album
count=1
```

结论：

1. 相册选择成功；
2. 文件数量正确；
3. 医疗上传 ViewModel 已接收到文件；
4. 业务入口和选择器不是当前根因；
5. 本次无需调整 `MedicalDocumentFilePickerMenu` 或 fullScreenCover。

### 2.2 OSS 配置预检已经通过

```text
oss.put.started
contentTypeCategory=image
sizeBucket=lt1m
keyFp=v1:94b5ed62fdcb0e53:bytes=111
stsAge=fresh
configuredRegionAlias=oss-cn-beijing
normalizedRegionAlias=oss-cn-beijing
configuredEndpointAlias=oss-cn-beijing
```

本次没有出现：

```text
blocked=preflight
reason=endpointConfig
code=ossConfigurationInvalid
```

说明：

- Region 与 Endpoint 已经通过 HarmonyOS 本地一致性校验；
- 已创建 Vendor Client；
- 已进入实际 PUT 传输；
- 错误发生在网络请求之后，而非配置阶段。

### 2.3 RCP 会话创建成功

```text
[RCP] session list: ["0"] after create: undefined
```

这说明：

1. RCP session 创建成功；
2. 不是 session 创建阶段直接失败；
3. `undefined` 是当前 RCP 日志格式的一部分，不应直接当作错误；
4. 需要关注后续 socket、请求发送和响应接收阶段。

### 2.4 RCP 失败细节

```text
code=1007900056
data=Failure when receiving data from the peer
httpPhase=111100
dnsDur=0.26
tcpDur=1.61
tlsDur=138.66
sndDur=2.45
rcvDur=0.00
totDur=457.01
osErr=11
proxyType=none
dstPort=443
```

逐项判断：

| 字段 | 含义 | 判断 |
| --- | --- | --- |
| dnsDur=0.26 | DNS 阶段耗时 | DNS 已完成，不是 DNS 解析失败。 |
| tcpDur=1.61 | TCP 建连耗时 | TCP 建连成功，不是无法连接。 |
| tlsDur=138.66 | TLS 握手耗时 | TLS 阶段基本完成。 |
| sndDur=2.45 | 发送阶段耗时 | 客户端已经发送请求或请求体的一部分。 |
| rcvDur=0.00 | 接收阶段耗时 | 尚未读到有效对端响应数据。 |
| totDur=457.01 | 总耗时 | 失败快速发生，未达到长超时。 |
| osErr=11 | 底层系统错误摘要 | 需结合 Harmony RCP 定义确认，不能直接等同 OSS Code。 |
| proxyType=none | 未使用代理 | 当前不是代理改写问题。 |
| dstPort=443 | HTTPS | 请求目标为 HTTPS 服务。 |

### 2.5 当前最重要的判断

`Failure when receiving data from the peer` 不是 OSS XML 错误，当前没有：

- HTTP status；
- OSS Code；
- OSS EC；
- OSS RequestId。

因此不能将本次错误判断为 OSS 业务拒绝，也不能把 `1007900056` 当成阿里云 OSS 错误码。它是 HarmonyOS RCP/传输层错误，应在客户端被单独归类为 `ossTransientFailure` 或更精确的 `ossTransportPeerReceiveFailed`。

## 3. 当前传输策略审计

### 3.1 当前生产策略

当前日志显示：

```text
policy=v3-prod-filepath-buffered-explicit-len
```

对应策略含义：

```text
payload=filePath
stream=false / buffered
contentLength=explicit
integrity=none
contentType=sdkDefault
signatureMode=v4
vendorVersion=2.0.0-beta.1
```

Vendor README 对该模式的描述是：

1. `data` 可以是 FilePath、fs.File 或 ArrayBuffer；
2. FilePath + `useStream=false` 时，SDK 会先读取文件为 ArrayBuffer；
3. `contentLength` 是数据字节数；
4. `contentMD5` 可选；
5. 流式模式不会自动计算 Content-MD5；
6. FilePath/Buffer 会进入不同的内部请求组装路径。

### 3.2 当前新问题

上一轮策略从 FilePath stream 改为 FilePath buffered，原意是避开流式上传失败；但本次仍然在 RCP 接收阶段失败，说明：

1. “只切换 stream=false”尚未证明可解决问题；
2. `payload=filePath` 仍保留，Vendor 内部仍需自行打开和读取文件；
3. 可能失败在 FilePath → ArrayBuffer 的内部转换；
4. 可能失败在 ArrayBuffer 请求发送/响应接收；
5. 可能是 Endpoint 可达但 TLS/HTTP response 被远端关闭；
6. 可能是请求 body、Content-Length 或签名与实际传输不一致；
7. 目前没有真实 request capture，无法确认 SDK 最终发送的 Host、body 长度和 headers。

## 4. 根因候选

### 4.1 HOS-RCP-01：对端在响应前关闭连接

可能原因：

- 请求头或签名不被 OSS 接受；
- Endpoint/Host 与签名目标不一致；
- Content-Length 与实际 body 长度不一致；
- 对端因连接策略关闭 socket；
- TLS/HTTP 协议协商后服务端没有返回可解析响应。

当前无法确认，因为没有 HTTP status 和 OSS RequestId。

### 4.2 HOS-RCP-02：Vendor FilePath buffered 内部读取/发送异常

当前 policy 虽然标记为 buffered，但 `payload=filePath` 仍由 Vendor SDK 负责读取。需要验证：

- SDK 是否真的读取完整文件；
- SDK 是否把 FilePath 转换为 ArrayBuffer；
- SDK 是否在转换后传入正确 Content-Length；
- 临时文件是否在 PUT 完成前仍然可读；
- FilePath URI 是否包含 Vendor SDK 不支持的路径格式；
- 文件读取异常是否被错误包装成 peer receive fail。

### 4.3 HOS-RCP-03：真实 ArrayBuffer 请求与 FilePath 请求不同

如果直接传入 ArrayBuffer 成功，而 FilePath buffered 失败，则根因属于 Vendor FilePath wrapper 或文件读取路径。

此时 HarmonyOS 应在 adapter 内建立明确的受控小文件 ArrayBuffer 路径；不得修改 Vendor 源码。

### 4.4 HOS-RCP-04：RCP 对响应体读取或 session close 时序异常

当前日志顺序是：

```text
session create
RCP peer receive fail
oss.put.failed
session close
```

因此本次不是明确的“先 close 再失败”。但仍需验证：

- Vendor 是否在内部提前 close response stream；
- SDK 是否要求 response body 完整读取；
- Adapter 的 finally close 是否会遮蔽原始异常；
- close 是否重复执行；
- activeClient 是否被并发上传覆盖。

### 4.5 HOS-RCP-05：网络链路瞬时失败

`transportRetryable=true`、`userCanRetry=true` 对本次错误是合理的初始判断，但不能无限重试。

需要区分：

- 单次网络瞬时断开；
- 同一文件同一策略重复失败；
- 同一设备所有 OSS 请求均失败；
- 只有 FilePath 请求失败；
- 只有特定网络/运营商失败。

## 5. 只修改 HarmonyOS 的修复方案

### 5.1 统一 RCP 传输错误模型

在 HarmonyOS 内部保留 OSS 业务错误与 RCP 传输错误的区分：

```text
ossTransientFailure
  requestValidationReason=rcpTransport
  rcpCode=1007900056
  rcpMessage=peer_receive_fail
  httpStatus=0
  ossRequestId=empty
```

建议增加更细粒度的内部 reason：

- `peerReceiveFailed`；
- `connectionClosedByPeer`；
- `responseTimeout`；
- `dnsFailed`；
- `tlsFailed`；
- `requestSendFailed`；
- `unknownRcpTransport`。

该细分只修改 HarmonyOS 错误模型和日志，不修改服务器或 iOS。

### 5.2 小文件受控 ArrayBuffer 对照路径

对小于 8 MB 的医疗图片/PDF，建立两种 HarmonyOS 测试路径：

路径 A：

```text
data = new FilePath(localPath)
useStream = false
```

路径 B：

```text
data = ArrayBuffer
useStream = false
```

只改变 `data` 类型，其他条件保持一致：

- 同一 STS；
- 同一 Region；
- 同一 Endpoint；
- 同一 objectKey；
- 同一 Content-Type；
- 同一 Content-Length；
- 同一测试文件。

判定：

- A 失败、B 成功：FilePath wrapper/内部读取问题；
- A/B 均失败：Endpoint、签名、RCP、网络或云端问题；
- A/B 均成功但 stream 失败：流式 Vendor 路径问题。

### 5.3 不把所有文件永久读入内存

HarmonyOS 生产策略应按文件大小分层：

- 小图片、小 PDF：允许 ArrayBuffer；
- 中型文件：评估内存峰值后决定；
- 大型 PDF：保留 FilePath/fs.File/分片路径；
- 大文件失败时不能无条件回退到 ArrayBuffer；
- 回退必须受内存上限和并发数限制；
- policy 版本必须写入日志。

### 5.4 重试边界

本次可允许用户手动重试一次，或在网络层执行一次有限重试：

1. 首次 `peerReceiveFailed`：允许一次重试；
2. 重试时不得无条件复用已经关闭的 Client/session；
3. 重试可切换到已经验证的 payload mode，但必须记录 policy 变化；
4. 相同文件、相同策略、相同 RCP code 连续失败两次后停止自动重试；
5. 页面显示“网络连接不稳定，请稍后重试”；
6. 不提示用户重新选择同一个文件；
7. 不刷新 STS，除非同时出现凭证过期证据；
8. 不把 RCP 数字错误码发送给用户作为原始文案。

### 5.5 session 生命周期

HarmonyOS adapter 需要验证并保证：

1. 每个上传任务拥有独立 client/session；
2. `activeClient` 不被并发上传覆盖；
3. 上传成功或失败后只关闭当前任务 client；
4. close 操作幂等；
5. close 不覆盖原始 RCP 错误；
6. cancel、timeout、peer receive fail 都会释放资源；
7. FilePath/fs.File 在 SDK 使用完成后再关闭；
8. 不在 response 尚未消费完时由业务层提前关闭 session。

## 6. 隔离实验矩阵

所有实验只在 HarmonyOS 测试环境执行，不修改 iOS、服务器、OSS 权限或 Vendor 源码。

| Case | data | useStream | Content-Length | Content-Type | 目的 |
| --- | --- | --- | --- | --- | --- |
| R-01 | FilePath | false | explicit | sdkDefault | 当前 v3 生产基线。 |
| R-02 | ArrayBuffer | false | explicit | sdkDefault | 隔离 FilePath 内部读取。 |
| R-03 | FilePath | true | explicit | sdkDefault | 对比上一轮流式路径。 |
| R-04 | fs.File | false | explicit | sdkDefault | 隔离 FilePath wrapper。 |
| R-05 | ArrayBuffer | false | sdkDerived | 验证显式长度影响。 |
| R-06 | ArrayBuffer | false | explicit | explicit MIME | 验证 Content-Type 影响。 |
| R-07 | ArrayBuffer | false | explicit | no MIME | 隔离 MIME/header。 |
| R-08 | ArrayBuffer | false | explicit | sdkDefault | 固定 ASCII key，排除 Key 编码。 |
| R-09 | ArrayBuffer | false | explicit | sdkDefault | 连续 3 次验证稳定性。 |

### 6.1 结果判定

| 结果 | 根因方向 | 修复方向 |
| --- | --- | --- |
| R-01 失败、R-02 成功 | FilePath wrapper | HarmonyOS 小文件使用 ArrayBuffer。 |
| R-01/R-02 失败、R-03 失败 | 非 payload 单一因素 | 检查 Host、签名、RCP、网络和云端。 |
| R-03 失败、R-01/R-02 成功 | 流式 Vendor/RCP | 大文件另行评估 stream 或分片。 |
| R-04 成功、R-01 失败 | FilePath 类型适配 | 统一使用 fs.File 或 ArrayBuffer。 |
| 所有 HarmonyOS case 失败 | 配置/网络/Vendor/云端 | 不继续修改 UI 文案，收集 RCP 和 HTTP 证据。 |
| R-09 间歇成功 | 网络瞬时问题 | 有限重试和网络状态提示。 |

## 7. 日志与诊断修复

### 7.1 PUT 开始日志增加

```text
payloadMode=filePath|arrayBuffer|fsFile
stream=false|true
contentLengthMode=explicit|sdkDerived
contentLengthBucket=...
contentTypeMode=sdkDefault|explicitHeader
policyVersion=...
vendorVersion=...
```

### 7.2 RCP 失败日志增加

```text
reason=rcpTransport
rcpCode=1007900056
rcpReason=peerReceiveFailed
httpStatus=0
ossRequestId=empty
sessionLifecycle=create-send-receive-failed-close
retryAttempt=0|1
networkType=...
proxyType=none|...
```

不得记录：

- 文件路径；
- 文件内容；
- token；
- Authorization；
- 完整 Endpoint；
- 完整 objectKey；
- 用户隐私信息。

### 7.3 三层日志一致

OSS 层：

```text
oss.put.failed
```

FILE 层：

```text
file.upload.failed
```

HOME 层：

```text
medical.upload.error_presented
medical.upload.vm.pipeline_failed
```

三层必须保留同一内部错误码、policy version、RCP code 和 retry boundary；OSS RequestId 为空时不能伪造。

## 8. 统一错误提示

本次错误建议在 HarmonyOS 内显示：

```text
网络连接不稳定，请稍后重试。
```

页面行为：

- presentation=banner；
- 首次 userCanRetry=true；
- 允许一次重试；
- 连续相同失败后 userCanRetry=false；
- secondary action=返回选择；
- 不展示 `1007900056`；
- 不展示 `Failure when receiving data from the peer`；
- 不提示“文件格式不支持”；
- 不触发 OCR、类型识别或文件登记。

## 9. 验收标准

### 9.1 传输层

- 能区分 HTTP OSS 错误和 RCP 数字错误；
- RCP peer receive fail 被归类为 HarmonyOS 传输错误；
- `httpStatus=0` 时不生成 OSS RequestId；
- session 在失败后正确释放；
- 重试不会复用已关闭的 session；
- 同一文件连续失败不会无限自动重试。

### 9.2 上传策略

- R-01～R-09 实验结果有记录；
- 小文件 FilePath 与 ArrayBuffer 有明确对照结论；
- 大文件不会无条件读入内存；
- policy 版本与实际 payload mode 一致；
- Content-Length 和 Content-Type 模式可追踪。

### 9.3 业务流程

- 相册图片选择成功后进入上传；
- 上传失败停留在 upload 阶段；
- 不进入 OCR/类型识别/保存；
- banner 提示统一；
- 可以返回选择；
- 可以有限重试；
- fullScreenCover 返回和取消正常；
- 不产生文件登记记录和孤儿附件。

### 9.4 范围验收

- 未修改任何 iOS 代码；
- 未修改任何服务器代码或配置；
- 未修改 OSS 权限和 STS Role；
- 未修改 Vendor SDK 源码；
- 只修改 HarmonyOS 项目代码、测试或文档。

## 10. 证据路径

HarmonyOS 适配层：

```text
SparkClientHarmonyOS/entry/src/main/ets/Projects/Core/OSS/OSSClientAdapter.ets
SparkClientHarmonyOS/entry/src/main/ets/Core/FileStorage/FileUploadTransportPolicy.ets
SparkClientHarmonyOS/entry/src/main/ets/Projects/Core/OSS/OSSErrorDecoder.ets
SparkClientHarmonyOS/entry/src/main/ets/Core/FileStorage/FileTransferService.ets
```

Vendor 只读参考：

```text
SparkClientHarmonyOS/entry/third_party/aliyun-oss/aliyun-oss/README.md
SparkClientHarmonyOS/entry/third_party/aliyun-oss/aliyun-oss/src/main/type/object/basic-operations/putObject.d.ts
SparkClientHarmonyOS/entry/third_party/aliyun-oss/aliyun-oss/src/main/type/requestHandlerBase.d.ts
SparkClientHarmonyOS/entry/third_party/aliyun-oss/aliyun-oss/src/main/harmony/utils/getUploadObjectParams.d.ts
```

iOS/服务器仅作只读对照，不属于本工单修改范围。

## 11. 工单完成说明

本工单已记录：

- 07-24 13:01:23 RCP `1007900056` 现场日志；
- 配置预检通过后的实际 PUT 失败链路；
- `FilePath + buffered` 策略仍失败的事实；
- Vendor SDK FilePath、fs.File、ArrayBuffer、stream 参数能力；
- RCP peer receive fail 的根因候选；
- HarmonyOS 专属隔离实验矩阵；
- 小文件 ArrayBuffer 受控回退方案；
- session 生命周期、重试边界、错误映射和用户提示；
- iOS、服务器、OSS 权限和 Vendor 源码不可修改的范围约束。

### 11.1 HarmonyOS 实施落地（2026-07-24）

已仅在 HarmonyOS 落地（未改 iOS / 服务器 / Vendor 源码）：

1. **生产策略 v4**：≤8MB → `payload=arrayBuffer`（业务侧 `fs.readSync` 读入后 PUT）；>8MB → FilePath stream。
2. **Adapter**：独立 Client/session；RCP `peerReceiveFailed` 时自动换新 session 再试一次（小文件强制 ArrayBuffer）。
3. **错误**：`reason=peerReceiveFailed`；文案「网络连接不稳定，请稍后重试。」；相同 RCP 指纹二次失败降级为返回选择。
4. **日志**：`payloadMode` / `retryAttempt` / `sessionLifecycle` / `rcpCode` / `rcpReason`。

真机成功期望：

```text
policy=v4-prod-arraybuffer-explicit-len
payloadMode=arrayBuffer
stream=false
oss.put.succeeded
```
