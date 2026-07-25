# HOS-FILE-OSS-0005｜iOS 与 HarmonyOS 统一从服务器获取 OSS 配置及 STS 契约修复工单

> 工单类型：HarmonyOS OSS 配置契约 P0 修复工单。
>
> 目标：以服务器返回的 OSS STS 配置和 iOS 现有实现为只读基线，仅在 HarmonyOS 中完成 OSS 配置获取、响应解析、Region/Endpoint/Bucket 校验、凭证生命周期、账号隔离、错误处理和日志诊断对齐。
>
> 关联工单：HOS-FILE-OSS-0001、HOS-FILE-OSS-0002、HOS-FILE-OSS-0003、HOS-FILE-OSS-0004。
>
> 范围约束：只允许修改 HarmonyOS 项目代码和 HarmonyOS 项目文档。禁止修改任何 iOS 代码、iOS 配置、服务器代码、服务器环境变量、服务端接口、OSS 权限和第三方 Vendor SDK 源码。iOS 与服务器只能用于只读审计、接口契约确认和行为对照。
>
> HarmonyOS 实施落地见 §15.1（2026-07-24）。

## 0. 执行边界

本工单的实际修复对象只有 HarmonyOS 项目：

- 允许修改：`SparkClientHarmonyOS/` 下的 HarmonyOS 业务代码、基础设施代码、测试和技术文档；
- 禁止修改：`SparkClient/` 下任何 iOS 代码、配置、测试和依赖；
- 禁止修改：`SparkService/` 下任何服务器代码、环境变量、部署配置、数据库和接口实现；
- 禁止修改：OSS Bucket Policy、STS Role、云端资源和第三方 Vendor SDK 源码；
- iOS 代码只用于逐条阅读和对齐；
- 服务器代码只用于确认真实接口、字段和配置来源；
- 如果服务器返回的配置本身冲突，HarmonyOS 只能识别、记录、阻断和提示，不在本工单内修复服务器。

## 1. 最新现场结论

07-24 12:07:17 的日志证明 HOS-FILE-OSS-0004 中增加的客户端前置保护已经生效：

```text
oss.put.started
configuredRegionAlias=oss-cn-shanghai
normalizedRegionAlias=oss-cn-shanghai
configuredEndpointAlias=oss-cn-beijing
...

oss.put.failed
code=ossConfigurationInvalid
blocked=preflight
reason=endpointConfig
...

file.upload.failed
code=ossConfigurationInvalid
retryable=false

medical.upload.error_presented
presentation=banner
retryable=false
```

本次没有真正发出 OSS PUT，也没有产生新的 OSS RequestId。失败发生在客户端配置预检阶段，而不是网络传输阶段。

当前问题已经从“OSS 上传参数怎么改”转变为 HarmonyOS 如何对齐 iOS 现有 OSS 配置获取流程：

1. 只读确认服务器返回的 OSS 配置和接口响应结构；
2. 只读确认 iOS 当前使用的 STS 接口、响应模型和 OSSManager 初始化顺序；
3. 在 HarmonyOS 中逐条翻译 iOS 的配置获取与使用流程；
4. HarmonyOS 复用服务器现有字段，不新增服务器接口、不修改服务器响应；
5. HarmonyOS 对返回配置执行本地完整性和一致性校验；
6. 服务器配置冲突时，HarmonyOS 在 PUT 前阻断并统一提示；
7. 不通过修改 iOS 或服务器代码解决本工单问题。

## 2. 最新日志逐条分析

### 2.1 上传页面进入

```text
medical.upload.picking_view.appeared
member=450
files=1
kind=auto
```

说明 AI 上传报告页面已正常出现，当前选中的成员是 450，文件数量为 1，上传类型为自动识别。

本次问题与以下内容无关：

- fullScreenCover 页面呈现；
- 图片选择器；
- 相册返回结果；
- MedicalDocumentFilePickerMenu；
- OCR 或医疗文档识别 pipeline；
- 文件内容是否为有效图片。

### 2.2 OSS PUT 开始前的配置证据

```text
oss.put.started
contentTypeCategory=image
sizeBucket=lt1m
keyFp=v1:93cceb763a22f951:bytes=111
stsAge=fresh
configuredRegionAlias=oss-cn-shanghai
normalizedRegionAlias=oss-cn-shanghai
configuredEndpointAlias=oss-cn-beijing
```

可以确认：

1. 客户端已经从服务端拿到 STS 运行时配置；
2. 客户端认为凭证处于 fresh 状态；
3. 配置中的 Region 是上海；
4. 配置中的 Endpoint 是北京；
5. Region 与 Endpoint 的地域不一致；
6. 客户端没有再试图通过“优先 Endpoint”或“优先 Region”静默修正；
7. 当前行为是阻断错误配置，避免发出无法正确签名或无法获得授权的请求。

`stsAge=fresh` 只代表 expiration 尚未进入刷新阈值，不代表 STS 的资源、Role、Bucket、Endpoint 或权限正确。

### 2.3 配置预检失败

```text
oss.put.failed
code=ossConfigurationInvalid
blocked=preflight
reason=endpointConfig
configuredRegionAlias=oss-cn-shanghai
normalizedRegionAlias=oss-cn-shanghai
configuredEndpointAlias=oss-cn-beijing
derivedEndpointAlias=oss-cn-beijing
```

这是正确的失败层级：

- 没有调用 Vendor OSS `putObject`；
- 不消耗一次无意义的网络请求；
- 不会制造新的 400/403 噪声；
- 不会误认为是用户文件损坏；
- 不会触发自动重试；
- 业务层明确知道失败步骤是 upload。

但是，这个结果也说明服务端下发契约仍未修复。客户端阻断只是保护措施，不是最终解决方案。

## 3. 当前跨端实现对比

### 3.1 iOS 获取 OSS 配置

iOS 相关路径：

```text
SparkClient/SparkClient/Projects/Core/Networking/API/OSS/SparkOSSAPI.swift
SparkClient/SparkClient/Projects/Core/Networking/API/OCR/OCRAPI.swift
SparkClient/SparkClient/Projects/Core/OSS/AliyunOSSRuntimeConfig.swift
SparkClient/SparkClient/Projects/Core/OSS/OSSClient.swift
SparkClient/SparkClient/Projects/Core/FileStorage/FileTransferService.swift
```

当前 iOS 流程：

1. `SparkOSSAPI.getSTSCredentials()` 请求：

```text
GET /api/v1/oss/sts/credentials/
```

2. 请求要求认证；
3. 响应通过 `APIResponseDecoder.decodeWrappedData()` 解析 `data`；
4. `OCRSTSCredentialsResponse` 作为响应模型；
5. `AliyunOSSRuntimeConfig.init(response:)` 读取：

```text
access_key_id
access_key_secret
security_token
bucket_name
region
endpoint
expiration
```

6. `SparkOSSConfigurationStore.configurationForUpload(using:)` 负责缓存/刷新；
7. `FileTransferService.upload()` 获取运行时配置；
8. `ossRuntimeConfigurator.updateConfiguration(endpoint:bucket:region:)` 更新 OSSManager；
9. `OSSClientWrapper.putObject()` 创建 iOS OSS PUT request；
10. OSS 上传成功后请求文件登记接口。

### 3.2 iOS 当前实现基线（只读，不修改）

iOS `AliyunOSSRuntimeConfig` 目前只做以下检查：

- access key id 非空；
- access key secret 非空；
- bucket 非空；
- region 非空；
- endpoint 非空。

它没有明确检查：

- endpoint 的地域是否与 region 一致；
- endpoint 是否属于 bucket 的实际地域；
- 服务端是否返回 `bucket_region`；
- endpoint 是标准公共域名还是自定义域名；
- region 是否需要 `oss-` 前缀；
- endpoint 是否应该由 region 推导；
- credentials 是否属于当前账号/成员上下文；
- 配置版本是否变化；
- 服务器是否下发了旧环境配置。

因此 HarmonyOS 需要以 iOS 当前实际调用链为基线完成翻译；即使发现 iOS 缺少某些校验，也不得在本工单中修改 iOS，而是在 HarmonyOS 中补齐本地安全校验并记录差异。

### 3.3 HarmonyOS 获取 OSS 配置

HarmonyOS 相关路径：

```text
SparkClientHarmonyOS/entry/src/main/ets/Projects/Core/Networking/API/OSS/OSSAPI.ets
SparkClientHarmonyOS/entry/src/main/ets/Projects/Core/OSS/OSSRuntimeConfig.ets
SparkClientHarmonyOS/entry/src/main/ets/Projects/Core/OSS/OSSRuntimeConfigStore.ets
SparkClientHarmonyOS/entry/src/main/ets/Projects/Core/OSS/OSSClientConfigNormalizer.ets
SparkClientHarmonyOS/entry/src/main/ets/Projects/Core/OSS/OSSClientAdapter.ets
SparkClientHarmonyOS/entry/src/main/ets/Core/FileStorage/FileTransferService.ets
```

当前 HarmonyOS 流程：

1. `OSSRuntimeConfigStore.getForUpload()` 检查内存 snapshot；
2. snapshot 不存在或即将过期时调用 `OSSAPI.credentials(accountScope)`；
3. 请求服务端 OSS STS 接口；
4. 解析 access key、secret、security token、expiration、bucket、region、endpoint、bucketRegion；
5. 将配置保存在内存，不落 Preferences/RDB；
6. 上传前通过 `OSSClientConfigNormalizer.normalize()` 归一化；
7. 发现 Region/Endpoint/Bucket Region 冲突时，返回 `ossConfigurationInvalid`；
8. 只有通过预检才创建 Vendor Client 并发起 PUT。

### 3.4 HarmonyOS 当前优点

相较于 iOS 当前实现，HarmonyOS 已具备：

- `bucketRegion` 字段承载能力；
- Region 归一化；
- Endpoint 地域解析；
- Region/Endpoint 冲突检测；
- 上传前阻断；
- `ossConfigurationInvalid` 错误码；
- 结构化 `reason=endpointConfig`；
- STS single-flight 刷新；
- 账号 scope；
- 登出/切号 invalidate 能力；
- 不持久化临时凭证；
- 上传过程安全日志。

这些能力应当沉淀为跨端契约，而不是只存在 HarmonyOS。

## 4. 服务端当前实现审计

服务端相关路径：

```text
SparkService/file_manager/oss_sts_views.py
SparkService/file_manager/sts_utils.py
SparkService/SparkService/settings.py
SparkService/file_manager/tests.py
SparkService/file_manager/url_utils.py
```

### 4.1 STS 接口

当前通用接口：

```text
GET /api/v1/oss/sts/credentials/
```

当前 OCR 兼容接口：

```text
GET /api/v1/oss/ocr/sts/credentials/
```

两个接口目前都调用同一个 `_sts_payload()` 和 `get_sts_credentials()`，返回相同 OSS STS 语义。

### 4.2 服务端配置来源

当前 `settings.py` 从环境变量读取：

```text
ALIYUN_ACCESS_KEY_ID
ALIYUN_ACCESS_KEY_SECRET
ALIYUN_STS_ROLE_ARN
ALIYUN_OSS_BUCKET
ALIYUN_OSS_REGION
ALIYUN_OSS_ENDPOINT
ALIYUN_STS_DURATION_SECONDS
```

因此本次冲突最可能来自：

1. 生产 `.env` 中 `ALIYUN_OSS_REGION=cn-shanghai`；
2. 同时存在 `ALIYUN_OSS_ENDPOINT=https://oss-cn-beijing.aliyuncs.com`；
3. 服务器进程未加载最新环境变量；
4. 部署环境变量覆盖了 `.env`；
5. 不同环境的配置被错误合并；
6. Bucket 实际地域已经迁移，但 Region/Endpoint 没同步；
7. Endpoint 是历史配置，Region 是新配置；
8. 服务端 `resolve_oss_location()` 的兼容逻辑掩盖了配置冲突。

### 4.3 服务端冲突处理现状（只读记录，不修改服务器）

当前 `resolve_oss_location()` 的行为是：

1. 读取 region 和 endpoint；
2. 从标准 Endpoint 主机解析 endpointRegion；
3. 如果 region 与 endpointRegion 不一致，记录 warning；
4. 将 endpointRegion 作为 resolved region；
5. 继续生成 reconciled endpoint；
6. 返回 `consistent=False`，但仍然签发 STS 配置。

这造成了三个问题：

1. 服务端知道配置不一致，却仍把它作为正常成功响应返回给客户端；
2. iOS 当前只检查字段非空，可能继续使用冲突配置；
3. HarmonyOS 当前把原始冲突阻断，形成 iOS/HarmonyOS 行为差异。

本工单不修改服务端兼容逻辑、不修改服务端环境变量，也不修改 STS 签发行为。HarmonyOS 按服务器实际返回值解析和校验；发现冲突时停止上传并给出统一提示。

## 5. HarmonyOS 端服务器契约适配设计

### 5.1 服务器作为只读配置事实源

HarmonyOS 不得自行决定或覆盖：

- Bucket 名称；
- Bucket Region；
- OSS Endpoint；
- STS Role；
- object key 前缀；
- 生产/测试环境；
- 签名 Region。

HarmonyOS 只负责：

1. 调用认证后的 STS 配置接口；
2. 解析严格响应模型；
3. 校验服务端契约完整性和一致性；
4. 将配置交给平台 OSS adapter；
5. 在账号切换或凭证失效时重新获取；
6. 记录安全诊断信息。

### 5.2 按现有服务器响应模型翻译

HarmonyOS 按服务器现有成功响应 `data` 解析以下字段。字段是否新增不属于本工单范围：

```json
{
  "access_key_id": "STS...",
  "access_key_secret": "...",
  "security_token": "...",
  "expiration": 1784869000,
  "bucket_name": "...",
  "bucket_region": "cn-shanghai",
  "region": "cn-shanghai",
  "endpoint": "https://oss-cn-shanghai.aliyuncs.com",
  "object_key_prefix": "SparkClient/",
  "config_version": "oss-prod-v1",
  "signature_version": "v4"
}
```

字段语义：

| 字段 | 必填 | 语义 |
| --- | --- | --- |
| access_key_id | 是 | STS 临时 AccessKeyId。 |
| access_key_secret | 是 | STS 临时 AccessKeySecret。 |
| security_token | STS 环境是 | STS SecurityToken。 |
| expiration | 是 | Unix 秒或明确 ISO8601，建议统一 Unix 秒。 |
| bucket_name | 是 | 目标 Bucket。 |
| bucket_region | 是 | Bucket 实际地域，权威资源字段。 |
| region | 是 | SDK/签名使用的地域；应与 bucket_region 一致。 |
| endpoint | 是 | 标准或自定义访问域名；必须与地域语义一致。 |
| object_key_prefix | 建议 | 服务端允许的对象前缀。 |
| config_version | 建议 | 便于客户端和服务端定位配置版本。 |
| signature_version | 建议 | 明确 v4/v1 等签名版本。 |

### 5.3 HarmonyOS 对服务器错误响应的处理

如果服务器返回配置错误，或 HarmonyOS 在本地发现 region、bucket_region、endpoint 不一致，HarmonyOS 应停止上传并映射为配置错误；本工单不修改服务器响应行为：

```text
HTTP 500
code=oss_configuration_invalid
data.request_id=<backend request id>
```

客户端应将其映射为：

```text
ossConfigurationInvalid
```

这样可以区分：

- STS 网络请求失败；
- STS 未认证；
- STS 过期；
- 服务端 OSS 配置错误；
- 客户端本地归一化错误；
- OSS PUT 权限拒绝。

## 6. HarmonyOS 对齐 iOS 方案

### 6.1 API 路径对齐（仅修改 HarmonyOS 调用）

HarmonyOS 医疗文件、OCR、聊天附件统一使用 iOS 当前已使用的：

```text
GET /api/v1/oss/sts/credentials/
```

本工单不新增服务器接口，不修改 `/api/v1/oss/ocr/sts/credentials/`。HarmonyOS 按 iOS 当前使用的 STS 路径进行对齐。

### 6.2 HarmonyOS 响应解码对齐 iOS

以下 iOS 内容只读参考，不修改 iOS：

- `OCRSTSCredentialsResponse` 与 `SparkOSSAPI` 统一；
- `AliyunOSSRuntimeConfig` 使用同一套必填字段；
- 增加 bucket_region、config_version、signature_version 的解码能力；
- 解析 expiration 时统一 Unix 秒；
- 字段缺失或类型错误直接报配置契约错误。

HarmonyOS 需要：

- `OSSAPI.credentials()` 使用同一响应结构；
- `OSSRuntimeConfig` 与 iOS 字段一一对应；
- 不再把 `endpoint`、`region` 当作两个可独立猜测的配置；
- 服务端返回 bucket_region 时必须参与一致性校验；
- 记录 configVersion 和 signatureVersion 的安全摘要。

### 6.3 HarmonyOS 配置缓存对齐 iOS 语义

HarmonyOS 应对齐 iOS 的有效配置生命周期；本工单不修改 iOS。HarmonyOS 遵循：

1. 只在内存缓存临时凭证；
2. 不将 AK/SK/token 写入磁盘；
3. expiration 前至少 300 秒刷新；
4. 同一账号并发请求使用 single-flight；
5. 账号切换、登出、401/403 明确凭证失效时清理缓存；
6. 缓存 key 必须包含账号 scope；
7. 不允许匿名账号配置覆盖已登录账号配置；
8. 配置刷新失败时不继续使用已过期凭证；
9. 同一配置版本不重复刷新；
10. 配置冲突不缓存为可用配置。

### 6.4 HarmonyOS 配置验证

HarmonyOS 对服务器返回配置执行：

1. access key 必填；
2. secret 必填；
3. security token 在 STS 模式必填；
4. expiration 可解析；
5. bucket_name 非空；
6. bucket_region 非空；
7. region 非空；
8. region 与 bucket_region 相同；
9. 标准 endpoint 地域与 bucket_region 相同；
10. 自定义 Endpoint 需要服务端明确 `endpoint_type=custom`；
11. signature_version 与客户端 SDK 支持能力一致；
12. object_key_prefix 与客户端生成规则一致。

### 6.5 OSSManager/OSSClientAdapter 对齐

iOS：

- `OSSRuntimeConfiguring.updateConfiguration()` 只接收已校验配置；
- `OSSManager` 不再自行修正 Region/Endpoint 冲突；
- OSS request 由 `OSSClientWrapper` 统一组装；
- 失败错误必须保留 OSS RequestId 和服务器 request id 的区分。

HarmonyOS：

- `OSSClientAdapter` 只接收已校验配置；
- `OSSClientConfigNormalizer` 负责校验，不负责替服务器修正错误资源；
- 通过校验后再创建 Vendor Client；
- 标准 Endpoint 使用统一规则：由 bucket_region/region 推导，或使用同区域显式值；
- 失败错误统一映射到 FileTransferError。

## 7. 服务器只读核对步骤（不修改服务器）

本节只用于确认服务器实际返回内容和配置状态，不包含任何服务器代码、环境变量、接口或部署修改。

### 7.1 只读确认生产配置

1. 只读查看实际运行进程的环境变量，不修改环境变量；
2. 核对 `ALIYUN_OSS_BUCKET`；
3. 在阿里云控制台确认 Bucket 实际 Region；
4. 核对 `ALIYUN_OSS_REGION`；
5. 核对 `ALIYUN_OSS_ENDPOINT`；
6. 核对 STS Role ARN 所属账号；
7. 核对后端部署环境名；
8. 记录是否存在北京 Endpoint 残留在上海 Bucket 配置中的情况；
9. 记录是否存在测试环境配置进入生产进程的情况；
10. 将配置事实写入工单，不在本工单中修复。

### 7.2 服务器资源配置记录（不修改）

以下仅用于记录服务器契约应满足的形态，不授权本工单修改服务器：

模式 A：Region 驱动

```text
bucket_region=cn-shanghai
region=cn-shanghai
endpoint=空或同区域标准 endpoint
```

客户端由同一个 Region 推导标准 Endpoint。

模式 B：Endpoint 驱动

```text
bucket_region=cn-shanghai
region=cn-shanghai
endpoint=https://oss-cn-shanghai.aliyuncs.com
```

客户端显式使用同区域 Endpoint。

不得使用：

```text
bucket_region=cn-shanghai
region=cn-shanghai
endpoint=https://oss-cn-beijing.aliyuncs.com
```

### 7.3 服务端启动期校验（只读检查）

本工单只检查服务器是否已有以下能力，不实现、不修改：

1. 解析 region；
2. 解析 endpoint host；
3. 解析 bucket_region；
4. 检查三者地域一致；
5. 冲突时拒绝启动或至少标记为不可签发；
6. 日志输出配置别名和一致性结果；
7. 绝不输出 AK/SK/token。

### 7.4 STS 响应只读核对

只读检查 `get_sts_credentials()` 的实际返回结果：

1. 确定 Bucket Region；
2. 确定签名 Region；
3. 确定 Endpoint；
4. 检查 Endpoint 地域；
5. 检查一致性；
6. 不一致时记录服务器现状，由 HarmonyOS 侧阻断上传；
7. 一致时返回完整 config version；
8. 返回 `bucket_region`；
9. 保持 iOS/HarmonyOS 可共同解析。

## 8. HarmonyOS 实施步骤（唯一允许修改的代码范围）

### 8.1 iOS 只读对照

1. 只读读取 iOS 现有 STS 请求路径；
2. 只读读取 iOS 现有响应字段和配置模型；
3. 只读读取 iOS 现有缓存刷新和 OSSManager 初始化顺序；
4. 将上述结果作为 HarmonyOS 翻译基线；
5. 禁止修改任何 iOS 文件、测试或配置。

### 8.2 HarmonyOS

1. `OSSRuntimeConfig` 与服务器响应字段完全对齐；
2. `OSSRuntimeConfigStore` 记录 account scope 和 config version；
3. STS 解析异常映射为配置契约错误；
4. 服务器已返回错误时不进入 OSS PUT；
5. 客户端本地冲突检测保留，作为第二道保护；
6. `OSSClientConfigNormalizer` 不再静默优先 endpoint 或 region；
7. `OSSClientAdapter` 只接受校验通过的最终配置；
8. 上传日志记录 configured/normalized/actual 三组安全别名；
9. 成功上传后文件登记继续使用同一 objectKey；
10. 补充与 iOS 相同的配置生命周期测试。

## 9. 错误链路统一

### 9.1 服务端获取配置失败

```text
oss.sts.requested
  → HTTP/API error
  → oss.sts.failed
  → file.upload.failed(stage=acquiringCredentials)
  → medical.upload.error_presented
```

### 9.2 服务端返回配置冲突

```text
oss.sts.requested
  → HTTP 500 oss_configuration_invalid
  → oss.sts.failed(code=ossConfigurationInvalid)
  → file.upload.failed(stage=acquiringCredentials)
  → medical.upload.error_presented(presentation=banner, retryable=false)
```

### 9.3 客户端本地发现配置冲突

```text
oss.sts.succeeded
  → config preflight
  → oss.put.failed(blocked=preflight, reason=endpointConfig)
  → file.upload.failed
  → medical.upload.error_presented(retryable=false)
```

### 9.4 OSS PUT 权限错误

```text
oss.sts.succeeded
  → oss.put.started
  → OSS HTTP 403
  → oss.put.failed(code=ossAccessDenied)
  → file.upload.failed
  → medical.upload.error_presented(retryable=false)
```

三种链路必须保持可区分，不能都归为“上传失败，请重试”。

## 10. 日志补充要求

### 10.1 STS 请求开始

```text
event=oss.sts.requested
module=OSS
operation=oss.sts.credentials
accountHash=...
environmentAlias=...
```

### 10.2 STS 成功

```text
event=oss.sts.succeeded
module=OSS
operation=oss.sts.credentials
backendRequestId=...
configVersion=...
configuredRegionAlias=...
bucketRegionAlias=...
configuredEndpointAlias=...
regionEndpointConsistent=true
roleMode=STS
stsAgeBucket=fresh
```

### 10.3 STS 配置冲突

```text
event=oss.sts.failed
module=OSS
operation=oss.sts.credentials
code=ossConfigurationInvalid
reason=regionEndpointMismatch
configuredRegionAlias=...
bucketRegionAlias=...
configuredEndpointAlias=...
backendRequestId=...
```

### 10.4 安全要求

禁止记录：

- access key secret；
- security token；
-完整 access key；
- bucket 明文；
-完整 endpoint URL；
- object key 明文；
- Authorization；
- 签名内容；
- 文件内容。

## 11. 测试计划（iOS/服务器只读，重点验证 HarmonyOS）

### 11.1 服务端只读验证

1. 只读确认 region 与 endpoint 是否同地域；
2. region 与 endpoint 冲突；
3. bucket_region 与 region 冲突；
4. endpoint 为空时由 region 推导；
5. 自定义 endpoint；
6. 空 region；
7. 空 bucket；
8. 缺少 STS Role；
9. STS 响应包含 bucket_region；
10. STS 响应包含 config_version；
11. 配置冲突不签发成功响应；
12. 记录两个 STS 路径是否返回同一字段语义，不修改服务器测试代码。

### 11.2 iOS 只读对照

1. 读取 iOS 解析完整配置的实际行为；
2. 读取 iOS expiration 解析和刷新规则；
3. 读取 iOS 账号切换清理规则；
4. 读取 iOS OSSManager 初始化顺序；
5. 禁止修改 iOS 单测和业务代码。

### 11.3 HarmonyOS 单元测试

1. region 归一化；
2. endpoint 地域提取；
3. bucketRegion 优先级；
4. 冲突时 preflight block；
5. 标准 Endpoint 推导；
6. 自定义 Endpoint；
7. STS single-flight；
8. expiration 刷新；
9. account scope 隔离；
10. 配置错误不创建 Vendor Client。

### 11.4 HarmonyOS 真机集成测试

1. HarmonyOS 相册图片上传；
2. HarmonyOS PDF 上传；
3. HarmonyOS 相机、聊天和外部文件入口上传；
4. 使用服务器正确配置时上传成功；
5. 使用当前冲突配置时在 PUT 前阻断；
6. 服务端配置错误时 HarmonyOS 展示统一提示；
7. 账号切换后 HarmonyOS 重新拉取 STS；
8. 403 权限拒绝时 HarmonyOS 不自动重试；
9. fullScreenCover 上传页面返回、取消和失败恢复正常。

## 12. 验收标准

### 服务器（只读验收，不改动）

- 已记录生产 Bucket、bucket_region、region、endpoint 的实际状态；
- 已记录服务器是否对冲突配置继续签发 STS；
- 已记录接口响应是否包含 bucket_region；
- 已记录 iOS 当前使用的 STS 路径和字段语义；
- 本工单未修改服务器。

### iOS（只读基线验收）

- 已确认 iOS 从服务器获取 OSS 配置的接口、字段和调用顺序；
- 已确认 iOS 配置模型和 OSSManager 初始化方式；
- iOS 代码未被修改。

### HarmonyOS

- 继续从服务器获取配置，不使用客户端硬编码配置覆盖服务器结果；
- 保留本地预检；
- 配置冲突不发起 PUT；
- 配置正确时 Vendor SDK 使用正确 Region/Endpoint；
- 仅使用通过校验的配置创建 Client；
- 统一记录 STS 与 OSS 两类 request id。

### 业务

- AI 上传报告 fullScreenCover 页面流程不受配置修复影响；
- 图片、PDF、相机、聊天、外部文件入口共用上传配置服务；
- 上传成功后继续文件登记和医疗识别流程；
- 配置错误时提示统一、可理解且不可盲目重试；
- 不产生错误附件、孤儿文件或重复登记。

## 13. 范围边界、风险与禁止事项

1. 不允许修改任何 iOS `.swift` 文件、iOS 配置、iOS 测试或 iOS 依赖；
2. 不允许修改任何服务器 `.py` 文件、环境变量、部署配置、数据库或接口实现；
3. 不允许修改 OSS Bucket Policy、STS Role 或云端权限；
4. 不允许修改 `entry/third_party/aliyun-oss` Vendor SDK 源码；
5. HarmonyOS 不得自行把上海改成北京，或把北京改成上海；
6. HarmonyOS 不得通过硬编码覆盖服务器下发的 Bucket/Region/Endpoint；
7. 服务器配置冲突时，HarmonyOS 只能校验、阻断、记录和提示；
8. 不允许将 STS 临时凭证持久化到普通本地存储；
9. 不允许把配置错误映射为网络临时失败；
10. 不允许对 403 AccessDenied 自动无限重试；
11. 不允许以 `stsAge=fresh` 代替权限和资源一致性验证；
12. 不允许在日志中输出敏感配置。

## 14. 证据路径

iOS：

```text
SparkClient/SparkClient/Projects/Core/Networking/API/OSS/SparkOSSAPI.swift
SparkClient/SparkClient/Projects/Core/Networking/API/OCR/OCRAPI.swift
SparkClient/SparkClient/Projects/Core/OSS/AliyunOSSRuntimeConfig.swift
SparkClient/SparkClient/Projects/Core/FileStorage/FileTransferService.swift
SparkClient/SparkClient/Projects/Core/OSS/OSSClient.swift
```

HarmonyOS：

```text
SparkClientHarmonyOS/entry/src/main/ets/Projects/Core/Networking/API/OSS/OSSAPI.ets
SparkClientHarmonyOS/entry/src/main/ets/Projects/Core/OSS/OSSRuntimeConfig.ets
SparkClientHarmonyOS/entry/src/main/ets/Projects/Core/OSS/OSSRuntimeConfigStore.ets
SparkClientHarmonyOS/entry/src/main/ets/Projects/Core/OSS/OSSClientConfigNormalizer.ets
SparkClientHarmonyOS/entry/src/main/ets/Projects/Core/OSS/OSSClientAdapter.ets
```

服务端：

```text
SparkService/file_manager/oss_sts_views.py
SparkService/file_manager/sts_utils.py
SparkService/SparkService/settings.py
SparkService/file_manager/tests.py
SparkService/file_manager/url_utils.py
```

## 15. 本次工单完成说明

本工单已修正为“仅修改 HarmonyOS、iOS 与服务器只读对照”，并记录了：

- 最新 12:07 配置预检阻断日志；
- iOS 从服务器获取 OSS 配置的完整链路；
- HarmonyOS 从服务器获取 OSS 配置的完整链路；
- 服务端 STS 接口、环境变量和 `resolve_oss_location()` 行为；
- iOS 宽松校验与 HarmonyOS 严格校验的跨端偏差；
- 服务器唯一事实源和统一 STS 响应模型；
- Region、Endpoint、Bucket Region 一致性方案；
- 凭证缓存、刷新、账号隔离和错误链路；
- HarmonyOS 对齐 iOS 的逐步实施方案；
- 服务器只读核对步骤；
- iOS 只读基线和禁止修改范围；
- 单元测试、接口测试、真机对照和最终验收标准。

### 15.1 HarmonyOS 实施落地（2026-07-24）

已在 **仅 HarmonyOS** 范围内完成对齐（未改 iOS / SparkService / Vendor）：

1. **`OSSRuntimeConfig`**：对齐服务器可选字段 `bucketRegion` / `objectKeyPrefix` / `configVersion` / `signatureVersion` / `endpointType`。
2. **`OSSSTSConfigValidator`**：STS 获取后立即校验完整性与 Region/Endpoint/BucketRegion；冲突抛 `ossConfigurationInvalid`（stage=`acquiringCredentials`），**不缓存**。
3. **`OSSAPI`**：路径仍为 iOS 同款 `GET /api/v1/oss/sts/credentials/`；解码失败与服务端配置类错误映射为配置契约错误，不伪装成可重试网络错误。
4. **`OSSRuntimeConfigStore`**：账号 scope 变更 invalidate；single-flight；300s 刷新；冲突配置丢弃；STS requested/succeeded/failed 安全日志。
5. **`FileTransferService`**：先拉 STS 再按 `object_key_prefix` 生成 objectKey；PUT 前仍保留 Normalizer 二道预检。
6. **`ObjectKeyPolicy`**：支持服务端前缀；空则默认 `SparkClient`。

**真机预期（服务器仍下发上海 Region + 北京 Endpoint 时）**：

```text
oss.sts.requested
oss.sts.failed code=ossConfigurationInvalid reason=endpointConfig|regionEndpointMismatch
file.upload.failed stage=acquiringCredentials retryable=false
```

不再进入 `oss.put.started`。待服务器配置自身一致后，应出现 `oss.sts.succeeded` → PUT → register。
