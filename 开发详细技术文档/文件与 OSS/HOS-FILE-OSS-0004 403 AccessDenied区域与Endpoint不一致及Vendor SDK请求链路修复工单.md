# HOS-FILE-OSS-0004｜403 AccessDenied：区域与 Endpoint 不一致及 Vendor SDK 请求链路修复工单

> 工单类型：HarmonyOS 文件与 OSS 直传 P0 问题修复工单。本文基于 HOS-FILE-OSS-0001、HOS-FILE-OSS-0002、HOS-FILE-OSS-0003 以及 07-24 11:43:25 的真机日志创建。
>
> 阶段一至二为问题分析与验收标准；阶段三客户端/服务端修复见 §13.1（2026-07-24 已落地）。
>
> 关联 Vendor 目录：`SparkClientHarmonyOS/entry/third_party/aliyun-oss/aliyun-oss`。

## 1. 工单目标

解决 AI 上传报告在选择图片后执行 OSS PUT 时收到 HTTP 403 `AccessDenied` 的问题，并完成以下目标：

1. 确认 STS 返回的 region、endpoint、bucket 与 HarmonyOS Vendor SDK 实际使用的请求目标是否一致。
2. 确认 Vendor SDK 的 SigV4 签名 region、请求 endpoint、Host、Content-Type 和 `useStream` 组合是否一致。
3. 确认 403 是 STS Role/Policy 权限拒绝、Bucket Policy 条件拒绝、Endpoint/Region 错配，还是 HarmonyOS Vendor SDK 请求组装差异。
4. 对齐 iOS OSS 上传的配置契约、请求模型、错误模型、日志模型和业务提示行为。
5. 保证错误不会被错误归类为可自动重试网络故障，也不会指导用户反复选择同一个文件。

## 2. 最新结论

本次错误已经不是上一工单中的 HTTP 400 `InvalidArgument`，而是服务端明确返回了 HTTP 403：

```text
ossCode=AccessDenied
ossEc=0003-00001403
code=ossAccessDenied
transportRetryable=false
userCanRetry=false
```

这说明 OSS 已经收到了请求并完成了身份/权限相关判断，当前首要方向从“请求参数格式非法”转为“请求目标、签名身份或资源策略不允许写入”。

本次最重要的证据是：

```text
regionAlias=oss-cn-shanghai
endpointAlias=oss-cn-beijing
regionNormalized=true
endpointOmitted=true
```

该组合存在明确不一致：

- STS/客户端配置中的 Region 被归一化为 `oss-cn-shanghai`；
- 原始 Endpoint 别名显示为 `oss-cn-beijing`；
- `endpointOmitted=true` 表示标准公有云 Endpoint 没有显式传入，SDK 会根据 Region 推导实际请求地址；
- 因此日志中显示的 `endpointAlias=oss-cn-beijing` 很可能只是“服务端返回的原始 endpoint 配置”，不等于本次 PUT 的实际网络目标；
- 如果 Bucket 实际位于北京，而 SDK 根据上海 Region 推导地址，或者签名 Region 与实际 Host 不一致，就可能出现 403 `AccessDenied` 或签名/权限类拒绝。

当前不能仅凭客户端日志直接宣布“Region/Endpoint 错配就是唯一根因”，但它已经是 P0 第一排查项，优先级高于继续调整 MD5、Content-Length 或用户提示文案。

## 3. 最新日志证据

### 3.1 文件选择和业务入口

```text
[picker] photo selectResult end
medical.upload.picking.files_selected
member=450
files=1
kind=auto
source=album
count=1
```

该部分说明：

1. 图片选择器成功返回；
2. 医疗上传页面收到 1 个文件；
3. 来源是相册，不是相机、聊天或外部 PDF；
4. 失败发生在文件选择之后的 OSS PUT 阶段；
5. 当前不应先排查 `MedicalDocumentFilePickerMenu` 的选择结果或 fullScreenCover 路由。

### 3.2 OSS 请求开始

```text
oss.put.started
module=OSS
operation=oss.put_object
contentTypeCategory=image
sizeBucket=lt1m
keyFp=v1:c67c3e1aa0d7e8fc:bytes=111
stsAge=fresh
regionAlias=oss-cn-shanghai
endpointAlias=oss-cn-beijing
regionNormalized=true
endpointOmitted=true
signature...
```

可确认：

1. STS 在客户端判断为 fresh，不能说明权限正确，只能说明没有接近过期；
2. 上传对象 Key 的脱敏长度为 111 字节，当前没有直接证据证明 Key 非法；
3. 文件小于 1 MB，适合进行 `ArrayBuffer` 与非流式对照实验；
4. Region 已发生 `cn-*` 到 `oss-cn-*` 的归一化；
5. Endpoint 原始别名为北京，但实际标准 Endpoint 被省略；
6. Vendor SDK 可能最终使用 `oss-cn-shanghai.aliyuncs.com`，而不是日志中的北京 Endpoint；
7. 当前日志没有给出实际 Host、签名版本、签名 region、STS role 摘要、Bucket 区域摘要，无法完成闭环判断。

### 3.3 OSS 请求失败

```text
oss.put.failed
ossRequestId=6A62DF5FAB5F2633304A3739
operation=oss.put_object
code=ossAccessDenied
httpStatus=403
ossCode=AccessDenied
ossEc=0003-00001403
transportRetryable=false
userCanRetry=false
reason=unknown
keyFp=v1:c67c3e1aa0d7e8fc:bytes=111
stsAge=fresh
hasMd5=false
regionAlias=oss-cn-shanghai
endpointAlias=oss-cn-beijing
```

该响应意味着：

1. 请求已经到达 OSS；
2. OSS 已生成 RequestId；
3. 这不是本地文件读取失败；
4. 这不是相册选择失败；
5. 这不是单纯的网络不可达；
6. 403 不应自动重试；
7. 需要用 `ossRequestId=6A62DF5FAB5F2633304A3739` 查询云端访问日志、STS 承担角色和 Bucket Policy 命中原因。

### 3.4 业务错误呈现

```text
medical.upload.error_presented
code=ossAccessDenied
presentation=banner
deduplicated=false
retryable=false
```

当前页面行为方向是正确的：

- 使用 banner，而不是将 OSS 原始错误直接展示给用户；
- `retryable=false`，不会把权限问题伪装成临时网络问题；
- 业务 pipeline 记录 `step=upload`，定位链路清晰。

仍需要补充的是：当 `ossAccessDenied` 已确认是权限/配置类错误时，页面主动作不应继续显示“重试上传”，而应显示“返回选择”或“稍后再试”；若确认只是短期凭证状态异常，才允许触发一次刷新 STS 后重试。

## 4. Vendor SDK 目录审计结果

### 4.1 Vendor 包中已确认的能力

在以下目录和声明中已找到对应能力：

```text
SparkClientHarmonyOS/entry/third_party/aliyun-oss/aliyun-oss/README.md
SparkClientHarmonyOS/entry/third_party/aliyun-oss/aliyun-oss/src/main/type/clientBase.d.ts
SparkClientHarmonyOS/entry/third_party/aliyun-oss/aliyun-oss/src/main/type/object/basic-operations/putObject.d.ts
SparkClientHarmonyOS/entry/third_party/aliyun-oss/aliyun-oss/src/main/type/requestHandlerBase.d.ts
SparkClientHarmonyOS/entry/third_party/aliyun-oss/aliyun-oss/src/main/type/signatureHandlerBase.d.ts
```

Vendor API 支持或声明了：

- `region`；
- `endpoint`；
- `cname`；
- `secure`；
- `headers`；
- `contentLength`；
- `contentMD5`；
- `useStream`；
- `FilePath`；
- `fs.File`；
- `ArrayBuffer`；
- RequestError 的 `requestId`、`status`、`code`、`ec` 等诊断字段；
- SigV4 相关 region/signature 参数。

Vendor README 对 PUT 的关键语义是：

1. `region` 用于 OSS 地域和签名地域；
2. 显式设置 `endpoint` 时，SDK 使用该 Endpoint；
3. 未设置 Endpoint 时，SDK 根据 Region 推导公共 Endpoint；
4. `contentLength` 表示上传数据字节数；
5. `contentMD5` 用于内容校验；
6. `useStream=true` 对 FilePath/fs.File 有效；
7. 流式上传不会自动计算 Content-MD5；
8. FilePath、fs.File、ArrayBuffer 可能进入不同的 body/request 组装路径。

### 4.2 当前适配层存在的关键风险

当前工程的 Vendor SDK 只允许在以下适配层被调用：

```text
SparkClientHarmonyOS/entry/src/main/ets/Projects/Core/OSS/OSSClientAdapter.ets
```

当前适配流程是：

1. 从 STS 得到 `region` 和 `endpoint`；
2. 通过 `OSSClientConfigNormalizer.normalize()` 转换 region/endpoint；
3. 创建 Vendor `Client`；
4. 以 FilePath + `useStream=true` 执行 PUT；
5. 根据 policy 决定 Content-Length、Content-MD5 和 Content-Type；
6. 将 Vendor Error 映射为 FileTransferError。

需要重点确认的偏差：

| 编号 | 风险 | 说明 | 优先级 |
| --- | --- | --- | --- |
| V-01 | STS 返回的 region 与 endpoint 不一致 | 当前日志为上海 Region、北京 Endpoint | P0 |
| V-02 | 日志 Endpoint 不是实际请求 Host | `endpointOmitted=true` 时 SDK 可能根据 Region 重新推导 Host | P0 |
| V-03 | Endpoint alias 记录语义不清 | 记录的是原始配置还是最终请求目标尚未区分 | P0 |
| V-04 | 签名 region 未从最终请求目标独立确认 | Region 归一化后可能影响 SigV4 credential scope | P0 |
| V-05 | Bucket 所在 Region 未进入客户端可验证契约 | STS 返回区域不等于 Bucket 实际区域 | P0 |
| V-06 | 403 `AccessDenied` reason 仍为 unknown | 没有区分 RoleDenied、BucketPolicyDenied、EndpointMismatch、ObjectPolicyDenied | P1 |
| V-07 | Vendor Error 的原始字段可能被丢失 | 业务错误只保留统一 code，云侧诊断字段不完整 | P1 |
| V-08 | FilePath 流式路径没有和 ArrayBuffer 对照证据 | 无法确认是否为 Vendor body/signature 适配问题 | P1 |
| V-09 | 当前 policy 版本已变化但未形成配置变更记录 | 不能仅凭 `v2` 判断实际 Host/headers | P1 |

## 5. 根因分析

### 5.1 根因候选 A：Region 与 Endpoint 真实错配

当前日志同时显示：

```text
regionAlias=oss-cn-shanghai
endpointAlias=oss-cn-beijing
endpointOmitted=true
```

需要区分两个概念：

1. `endpointAlias`：当前配置中曾出现的 Endpoint 别名；
2. `actualRequestHost`：Vendor SDK 最终实际发送 HTTP 请求的 Host。

当 `endpointOmitted=true` 时，不能把 `endpointAlias=oss-cn-beijing` 解释为本次请求真正访问了北京 Endpoint。实际可能是：

```text
STS endpoint=oss-cn-beijing.aliyuncs.com
STS region=cn-shanghai
Normalizer region=oss-cn-shanghai
Normalizer endpoint omitted=true
SDK actual host=oss-cn-shanghai.aliyuncs.com
SDK signature region=oss-cn-shanghai
```

如果 Bucket 在北京，则这套组合会导致请求访问错误地域，或者签名和资源地域不一致。

修复要求：

- 服务端 STS 返回的 region、endpoint、bucketRegion 必须来自同一资源配置；
- 客户端不得静默接受明确冲突的 region/endpoint；
- 标准公共 Endpoint 应由唯一可信 Region 推导，或显式传入已验证的同区域 Endpoint；
- 日志必须区分 configured endpoint、normalized endpoint、actual request host；
- 在冲突时应在 PUT 前失败为 `ossConfigurationInvalid`，而不是发出必然被拒绝的请求。

### 5.2 根因候选 B：STS Role 无 PutObject 权限

403 `AccessDenied` 的第二个高概率原因是 STS 临时身份没有目标 Bucket/Object Key 的写权限。

必须核对：

1. STS Role 是否包含目标 Bucket 的 `oss:PutObject`；
2. Resource 是否覆盖当前 Object Key 前缀；
3. 是否只允许某个固定目录，而客户端实际 Key 为 `SparkClient/yyyyMMdd/...`；
4. 是否允许 `oss:PutObjectAcl` 或其他额外操作（若 SDK 未执行则不应作为前置要求）；
5. Bucket Policy 是否限制 Principal、SourceVpc、Referer、SecureTransport 或 UserAgent；
6. 是否限制 `x-oss-forbid-overwrite`、StorageClass、ServerSideEncryption 等 header；
7. STS 的 account scope 是否与当前登录账号一致；
8. Token 是否属于另一个环境、Bucket 或租户；
9. 退出登录、切换成员或切换账号后是否复用了旧的 STS snapshot。

不能因为 `stsAge=fresh` 就排除权限问题。fresh 只代表时间有效，不代表授权范围正确。

### 5.3 根因候选 C：Bucket Policy 条件拒绝

如果 Role 本身拥有 PutObject，但 Bucket Policy 仍返回 403，需要检查：

- Object Key 前缀条件；
- 账号/角色条件；
- HTTPS 条件；
- 请求来源条件；
- Content-Type 条件；
- 用户元数据条件；
- 服务器端加密条件；
- 允许写入但禁止覆盖条件；
- 目标 Bucket 与环境标识条件。

当前客户端日志没有记录策略命中结果，必须依靠 OSS 访问日志或云审计查询 RequestId。

### 5.4 根因候选 D：Vendor SDK 签名与实际 Endpoint/Region 不一致

Vendor 包的声明同时支持 `region` 和 `endpoint`。当两者来源不一致时，需要确认 SDK 的实际签名行为：

1. 签名 Host 使用显式 Endpoint 还是 Region 推导 Endpoint；
2. SigV4 credential scope 使用传入 Region、规范化 Region 还是 Endpoint 推导 Region；
3. `endpoint` 被省略时是否仍保留了旧 Endpoint 的配置；
4. `cname` 是否在标准公共 Endpoint 情况下被错误设置；
5. Host header、canonical URI、canonical query 是否与请求目标一致；
6. STS security token 是否加入签名和请求头；
7. Vendor 包版本是否与 HarmonyOS RCP 传输层兼容。

### 5.5 根因候选 E：FilePath + stream=true Vendor 实现

本次 403 与上一轮 400 的共性是仍然使用：

```text
payload=filePath
stream=true
```

必须通过小文件对照实验确认：

- FilePath 流式请求是否正确设置 body 长度；
- FilePath 流式请求是否正确设置 Host/Content-Type；
- FilePath 流式请求是否走了与 ArrayBuffer 相同的签名路径；
- RCP session 是否在 response body 读取完成前关闭；
- Vendor SDK 是否在流式模式下追加了未被签名的 header；
- FilePath URI 是否来自 picker 临时目录，SDK 是否仍能在上传时读取该文件。

如果 ArrayBuffer 成功而 FilePath 失败，则应建立明确的 Vendor 兼容策略，而不是继续调整 OSS 权限。

## 6. 与 iOS OSS 实现对齐要求

### 6.1 iOS 参考路径

```text
SparkClient/SparkClient/Projects/Core/FileStorage/FileTransferService.swift
SparkClient/SparkClient/Projects/Core/OSS/OSSClient.swift
SparkClient/SparkClient/Projects/Core/FileStorage/FileUtilities.swift
```

iOS 上传链路的关键特点：

1. 文件先进入统一 FileCache/文件管理模型；
2. 业务层计算或保存文件摘要；
3. OSS client 统一创建 PUT request；
4. 业务层传入 data、objectKey、contentType 和 progress；
5. OSS client 负责 Vendor/平台请求字段组装；
6. OSS 失败统一封装为 OSS 上传错误；
7. 文件登记接口在 OSS 成功后执行。

### 6.2 HarmonyOS 需要对齐的公共契约

HarmonyOS 业务层不能直接决定以下细节：

- 是否传 `headers['content-type']`；
- 是否传 Content-MD5；
- 是否显式传 Content-Length；
- 是否使用流式上传；
- 是否传 endpoint；
- 使用何种签名版本；
- 如何关闭 RCP session。

这些都必须收敛在：

```text
Projects/Core/OSS/OSSClientAdapter.ets
Projects/Core/FileStorage/FileTransferService.ets
Projects/Core/FileStorage/FileUploadTransportPolicy.ets
```

领域模型只保留跨端共有字段：

- local file URI/path；
- file size；
- MIME type；
- MD5/SHA 摘要；
- object key；
- upload status；
- OSS request ID；
- registration status。

### 6.3 Region/Endpoint 跨端单一事实源

后端 STS 契约应明确返回：

```text
accessKeyId
accessKeySecret
securityToken
expiration
bucketName
bucketRegion
endpoint
objectKeyPrefix
```

其中：

1. `bucketRegion` 是 Bucket 实际地域，不是客户端猜测值；
2. `endpoint` 必须属于 `bucketRegion`；
3. 若公共 Endpoint 可由 Region 推导，则服务端应统一返回 Region，客户端按约定推导；
4. 若服务端返回显式 Endpoint，则必须返回 Endpoint 类型和是否允许覆盖 Region；
5. 客户端检测到 region/endpoint 冲突时必须阻断上传并上报配置错误；
6. iOS 与 HarmonyOS 必须消费同一套字段语义，不得各自猜测 Endpoint。

## 7. 修复方案

### 7.1 P0：阻断 Region/Endpoint 静默错配

实施步骤：

1. 从后端 STS 响应中确认 `bucketRegion`、`region`、`endpoint` 的真实值；
2. 确认 Bucket 控制台显示的实际地域；
3. 确认 endpoint 主机中的地域与 Bucket 实际地域一致；
4. 客户端归一化时保留 `configuredRegion`、`normalizedRegion`、`configuredEndpointAlias`、`derivedEndpointAlias` 四个诊断概念；
5. 若 endpoint 是标准公共 Endpoint，校验其地域后再省略，让 SDK 根据同一个 Region 推导；
6. 若 endpoint 是自定义域名或特殊云 Endpoint，显式传入并使用服务端声明的签名 region；
7. 如果配置冲突，返回 `ossConfigurationInvalid`，禁止执行 PUT；
8. 增加配置校验日志，但不得输出 AK/SK/token/bucket 明文。

### 7.2 P0：云侧核对 STS Role 与 Bucket Policy

使用本次 OSS RequestId：

```text
6A62DF5FAB5F2633304A3739
```

由后端/云资源负责人核对：

1. 请求实际到达的 Host 和 Region；
2. 使用的 STS Role/Principal 摘要；
3. 目标 Bucket；
4. 目标 Object Key 前缀；
5. 命中的 Bucket Policy；
6. 是否命中 `AccessDenied` 的具体条件；
7. 是 Role 权限拒绝还是 Bucket Policy 拒绝；
8. 是否因为跨地域 Endpoint、签名 region 或临时凭证环境错误而拒绝；
9. 是否存在账号切换后复用旧 STS 的情况。

没有云侧 RequestId 结论前，不允许以“修复客户端重试”作为完成标准。

### 7.3 P0：补齐实际请求目标诊断

`oss.put.started` 和 `oss.put.failed` 增加安全字段：

- `configuredRegionAlias`；
- `normalizedRegionAlias`；
- `configuredEndpointAlias`；
- `derivedEndpointAlias`；
- `actualEndpointMode`：`derived` / `explicit` / `custom`；
- `signatureMode`；
- `signatureRegionAlias`；
- `bucketRegionAlias`（由后端安全枚举返回）；
- `regionEndpointConsistent`；
- `payloadMode`；
- `contentTypeMode`；
- `vendorVersion`。

禁止记录：

- 完整 endpoint URL；
- bucket 明文；
- object key 明文；
- Authorization；
- security token；
- AK/SK；
- 签名 query；
- 文件内容。

### 7.4 P1：增加 Vendor SDK 请求捕获验证

在测试构建中增加 request capture 或可控 mock transport，验证：

1. 实际 Host；
2. 实际 URL path；
3. 实际签名 region；
4. `x-oss-security-token` 是否存在；
5. Content-Length 是否与文件大小相等；
6. Content-Type 的来源和大小写；
7. 是否发送 Content-MD5；
8. FilePath 与 ArrayBuffer 是否走不同分支；
9. RCP session 创建、发送、响应读取、关闭的时序。

生产日志只保留枚举和 fingerprint，不开启原始 header 记录。

### 7.5 P1：建立最小可行上传回退路径

仅在 Vendor 确认 FilePath 流式路径存在问题时启用：

1. 小于指定阈值的图片/PDF 使用 ArrayBuffer 非流式上传；
2. 大文件继续使用 FilePath/fs.File，但必须有真实测试 Bucket 证据；
3. 不允许无条件把所有医疗 PDF 读入内存；
4. 回退路径必须写入版本化 policy；
5. 回退成功后仍要执行统一文件登记和附件绑定；
6. 回退失败时保留原始 OSS RequestId 和 policy 版本。

### 7.6 P1：统一错误提示

错误分类建议：

| OSS 情况 | 内部错误码 | 自动重试 | 页面动作 |
| --- | --- | --- | --- |
| 403 AccessDenied，Role/Policy 拒绝 | `ossAccessDenied` | 否 | 提示“暂时无法上传，请稍后再试”，主动作返回选择；记录支持诊断。 |
| 403 Token 过期且云侧明确 | `credentialsExpired` | 仅刷新凭证后一次 | 刷新 STS 后自动重试一次。 |
| Region/Endpoint 冲突 | `ossConfigurationInvalid` | 否 | 系统提示暂时无法上传，禁止反复重试。 |
| FilePath 流式 Vendor 失败 | `ossTransportUnsupported` | 否 | 进入受控回退路径或返回选择。 |
| 400 InvalidArgument | `ossRequestValidationUnknown` | 否 | 先完成诊断，不提示用户重复选文件。 |
| 网络断开/超时 | `ossTransientFailure` | 有限次数 | banner 提供重试。 |

`ossAccessDenied` 不应把 `userCanRetry` 设置为 true，除非后端明确确认是可通过刷新 STS 解决的凭证问题。

## 8. 必须执行的隔离实验

所有实验使用测试 Bucket、测试 Role、测试图片和固定 ASCII object key；每个实验只改变一个变量。

| Case | Region | Endpoint | 签名 | Payload | 目的 |
| --- | --- | --- | --- | --- | --- |
| E-01 | Bucket 实际 Region | 由 Region 推导 | 默认 | ArrayBuffer | 验证基础权限和配置。 |
| E-02 | Bucket 实际 Region | 同区域显式 Endpoint | 默认 | ArrayBuffer | 验证显式 Endpoint。 |
| E-03 | Bucket 实际 Region | 同区域显式 Endpoint | 默认 | FilePath stream | 验证流式路径。 |
| E-04 | Bucket 实际 Region | 同区域显式 Endpoint | 默认 | fs.File stream | 验证 fs.File 路径。 |
| E-05 | Bucket 实际 Region | 同区域显式 Endpoint | 默认 | ArrayBuffer + Content-Type | 验证 MIME。 |
| E-06 | Bucket 实际 Region | 同区域显式 Endpoint | 默认 | ArrayBuffer 不设置 Content-Type | 隔离 Content-Type。 |
| E-07 | Bucket 实际 Region | 故意错误 Region | 默认 | ArrayBuffer | 验证错误是否与当前日志同类。 |
| E-08 | Bucket 实际 Region | 故意错误 Endpoint | 默认 | ArrayBuffer | 验证跨区域目标表现。 |
| E-09 | 正确 Region | 正确 Endpoint | 正确 STS Role | ArrayBuffer | 与 ossutil/官方 SDK 结果对照。 |

### 8.1 实验判定

- E-01 成功、E-03 失败：Vendor FilePath stream 问题；
- E-01/E-03 均 403：权限、Bucket Policy 或 STS 配置问题；
- E-01 成功、E-02 失败：显式 Endpoint 或签名目标问题；
- E-07/E-08 与当前错误一致：确认 Region/Endpoint 错配会触发同类拒绝；
- E-09 成功、Harmony 所有路径失败：优先修 Vendor adapter/request serialization；
- E-09 也失败：优先修 STS Role/Bucket Policy/资源地域配置。

## 9. 分阶段实施步骤

### 阶段一：云侧事实确认

1. 获取 STS 原始响应的脱敏副本；
2. 获取 Bucket 实际 Region；
3. 获取 OSS RequestId 对应访问日志；
4. 确认真实 Host、Bucket、Object Key 前缀和 Principal；
5. 确认拒绝策略及具体条件；
6. 输出“云端权限正常/配置错误/请求目标错误”的结论。

### 阶段二：Vendor 请求事实确认

1. 固定测试文件和 ASCII Key；
2. 固定正确 STS；
3. 分别运行 ArrayBuffer、FilePath、fs.File；
4. 捕获测试请求中的 Host、Region、Content-Length 和 Content-Type；
5. 对比 Vendor SDK 与 ossutil/官方 SDK；
6. 标记 Vendor 版本和 HarmonyOS API 版本。

### 阶段三：客户端配置修复

1. 对齐 STS region/endpoint/bucketRegion 字段语义；
2. 增加 region/endpoint 冲突校验；
3. 明确 `configured` 与 `actual` endpoint 日志字段；
4. 选择经过 E-01～E-09 验证的 policy；
5. 将错误映射为 `ossConfigurationInvalid`、`ossAccessDenied` 或 `ossTransportUnsupported`；
6. 禁止 403 权限错误自动重试。

### 阶段四：业务回归

1. 相册选择图片；
2. 相机拍照图片；
3. 外部 PDF；
4. 聊天入口选择附件；
5. fullScreenCover 进入 AI 上传报告页面；
6. 单文件上传；
7. 多文件上传；
8. 上传成功后的文件登记；
9. 医疗文档识别 pipeline 继续执行；
10. 失败后重新选择、取消、返回页面；
11. 账号切换后重新获取 STS；
12. 弱网、断网、凭证过期和权限拒绝场景。

## 10. 验收标准

### 10.1 配置验收

- STS 返回的 Region、Endpoint、Bucket Region 通过一致性校验；
- 发现上海/北京等地域冲突时，PUT 前被阻断；
- 日志能区分配置 Endpoint 与实际请求 Endpoint 模式；
- 正确区域的测试上传成功；
- 错误区域不会被误标为网络可重试。

### 10.2 Vendor 验收

- FilePath、fs.File、ArrayBuffer 三种路径有明确测试结果；
- Content-Length、Content-Type、Content-MD5 发送形态有 request capture 证据；
- SigV4 region 与实际 Host 一致；
- STS security token 被正确使用；
- RCP session 在 response 读取完成后关闭；
- Vendor 版本和 policy 版本可追踪。

### 10.3 业务验收

- `ossAccessDenied` 不自动重试；
- 权限错误不要求用户反复重新选择同一文件；
- 页面只展示统一中文提示，不展示 OSS 原始错误；
- 上传成功才进入文件登记、OCR 和医疗文档识别；
- 上传失败不会产生孤儿业务附件记录；
- OSS RequestId 可贯穿 OSS、File、HOME 三层日志；
- fullScreenCover 返回和取消行为不丢失失败状态。

## 11. 风险与禁止事项

1. 不允许直接修改 `entry/third_party/aliyun-oss` Vendor 包源代码来掩盖 Region/Endpoint 或权限问题；
2. 不允许把错误 Endpoint 通过客户端硬编码成北京或上海；必须以 Bucket 真实地域和后端契约为准；
3. 不允许为了绕过 403 放宽生产 Bucket Policy 到全写权限；
4. 不允许把 `ossAccessDenied` 改成 `retryable=true`；
5. 不允许在日志中输出 STS token、AK/SK、完整 Bucket、完整 object key 或 Authorization；
6. 不允许仅凭客户端 `stsAge=fresh` 认定凭证权限正确；
7. 不允许用“重试成功一次”替代云侧 RequestId 证据；
8. 不允许将所有文件无条件读入内存作为长期方案。

## 12. 证据路径

客户端适配层：

```text
SparkClientHarmonyOS/entry/src/main/ets/Projects/Core/OSS/OSSClientAdapter.ets
SparkClientHarmonyOS/entry/src/main/ets/Projects/Core/OSS/OSSClientConfigNormalizer.ets
SparkClientHarmonyOS/entry/src/main/ets/Projects/Core/OSS/OSSRuntimeConfigStore.ets
SparkClientHarmonyOS/entry/src/main/ets/Projects/Core/OSS/OSSErrorDecoder.ets
SparkClientHarmonyOS/entry/src/main/ets/Core/FileStorage/FileTransferService.ets
SparkClientHarmonyOS/entry/src/main/ets/Core/FileStorage/FileUploadTransportPolicy.ets
```

Vendor SDK：

```text
SparkClientHarmonyOS/entry/third_party/aliyun-oss/aliyun-oss/README.md
SparkClientHarmonyOS/entry/third_party/aliyun-oss/aliyun-oss/src/main/type/clientBase.d.ts
SparkClientHarmonyOS/entry/third_party/aliyun-oss/aliyun-oss/src/main/type/object/basic-operations/putObject.d.ts
SparkClientHarmonyOS/entry/third_party/aliyun-oss/aliyun-oss/src/main/type/requestHandlerBase.d.ts
SparkClientHarmonyOS/entry/third_party/aliyun-oss/aliyun-oss/src/main/type/signatureHandlerBase.d.ts
```

iOS 对照：

```text
SparkClient/SparkClient/Projects/Core/FileStorage/FileTransferService.swift
SparkClient/SparkClient/Projects/Core/OSS/OSSClient.swift
SparkClient/SparkClient/Projects/Core/FileStorage/FileUtilities.swift
```

## 13. 本次工单完成说明

本工单新增并记录了：

- 07-24 11:43:25 最新 403 `AccessDenied` 证据；
- `oss-cn-shanghai` 与 `oss-cn-beijing` 配置不一致风险；
- `endpointOmitted=true` 导致日志 Endpoint 与实际请求目标可能不同的风险；
- Vendor SDK 的 region/endpoint/headers/contentLength/contentMD5/useStream 能力审计；
- STS Role、Bucket Policy、签名 region、FilePath stream 的分层排查；
- iOS/HarmonyOS OSS 公共契约对齐要求；
- 云侧 RequestId 查询、Vendor request capture 和九组隔离实验；
- 统一错误提示、重试边界、日志安全和最终验收标准。

### 13.1 阶段三客户端/服务端修复（2026-07-24）

已完成可编译落地（非仅文档）：

1. **根因**：`SparkService/.env` 曾配置 `ALIYUN_OSS_REGION=cn-shanghai` 且 `ALIYUN_OSS_ENDPOINT=https://oss-cn-beijing.aliyuncs.com`。iOS 以 endpoint 建连（北京）；Harmony 省略 endpoint 后按 region 推导（上海）→ 403 AccessDenied。
2. **后端**：`sts_utils.resolve_oss_location` 冲突时以标准 endpoint 主机地域为准并告警；响应增加 `bucket_region`；`.env` 已改为 `cn-beijing` 对齐。
3. **客户端**：`OSSClientConfigNormalizer` 检测 region/endpoint/bucketRegion 冲突 → PUT 前 `ossConfigurationInvalid`；日志区分 configured/normalized/derived/actualEndpointMode/regionEndpointConsistent。
4. **错误 UX**：`ossAccessDenied` / `ossConfigurationInvalid` → `userCanRetry=false`，主动作「返回文件选择」；裸 403 不再误判为可刷新凭证。
5. **验收**：`assembleHap` 通过；后端 `resolve_oss_location` 单测覆盖上海/北京错配。

仍需真机：确认 STS 返回 `region=cn-beijing` + 同区域 endpoint 后 PUT→register 成功；若仍 403，用 `ossRequestId` 查云侧 Role/Bucket Policy。
