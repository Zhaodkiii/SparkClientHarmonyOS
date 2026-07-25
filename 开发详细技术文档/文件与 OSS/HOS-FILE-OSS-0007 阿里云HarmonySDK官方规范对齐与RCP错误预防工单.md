# HOS-FILE-OSS-0007｜阿里云 Harmony SDK 官方规范对齐与 RCP 错误预防工单

> 工单类型：HarmonyOS OSS SDK 官方规范对齐工单。
>
> 修复范围：只允许修改 `SparkClientHarmonyOS/` 项目代码、测试、依赖声明和技术文档。禁止修改任何 iOS 代码、服务器代码、服务器配置、OSS 权限、STS Role 和阿里云 Vendor SDK 源码；iOS、服务器和 Vendor 包只做只读对照。
>
> 关联工单：HOS-FILE-OSS-0001～HOS-FILE-OSS-0006。
>
> 官方资料来源：用户提供的《Alibaba Cloud OSS SDK for Harmony OS》及《快速入门（Harmony SDK，更新时间 2025-11-28）》。

## 1. 工单目标

将 HarmonyOS 项目当前 OSS 接入方式逐项对齐阿里云官方 Harmony SDK 文档，避免继续出现：

- RCP `1007900056`：`Failure when receiving data from the peer`；
- RCP `1007900052`：`Server returned nothing (no headers, no data)`；
- 没有 HTTP status、OSS Code、OSS EC 和 OSS RequestId 的失败；
- SDK 版本、API 级别、请求体模式和官方示例不一致；
- FilePath、fs.File、ArrayBuffer 选择依据不清；
- 文件句柄、Client session 和重试生命周期不符合官方示例；
- Vendor SDK 错误字段被错误当成 OSS XML 错误；
- 未经完整验证将公测版 SDK 路径作为生产上传方案。

本工单不是修改 iOS 或服务器的工单。目标是让 HarmonyOS 在现有服务器配置和 iOS 行为基线下，按官方 Harmony SDK 规则完成安全接入和可验证上传。

## 2. 官方要求摘要

### 2.1 环境要求

官方资料明确要求：

1. 使用 API 12 及以上版本；
2. 通过 `ohpm install @aliyun/oss` 获取 Harmony SDK；
3. 使用 `ohpm list` 验证实际安装版本；
4. 当前 Harmony SDK 处于公测阶段；
5. 官方不建议未经充分测试直接用于生产环境；
6. 生产部署前必须进行充分稳定性和兼容性验证。

### 2.2 Client 初始化要求

官方示例使用：

```ts
import Client, { RequestError } from '@aliyun/oss';

const client = new Client({
  accessKeyId: 'yourAccessKeyId',
  accessKeySecret: 'yourAccessKeySecret',
  securityToken: 'yourSecurityToken',
  region: 'oss-cn-hangzhou',
});
```

关键要求：

- STS 模式必须使用 AccessKeyId、AccessKeySecret、SecurityToken；
- `region` 使用 OSS 地域格式，例如 `oss-cn-hangzhou`；
- region 必须是 Bucket 所在地域；
- 不应使用客户端硬编码生产凭证；
- Client 配置必须来自服务端 STS 配置并经过本地校验；
- Client 使用结束后主动关闭 session；
- 不应在未等待异步操作完成前关闭 session。

### 2.3 PutObject 要求

官方支持的数据类型：

- string；
- ArrayBuffer；
- FilePath；
- `fs.File`。

官方示例分别展示：

1. 字符串直接上传；
2. `fs.open(path, READ_ONLY)` 获得文件对象后上传；
3. `finally` 中关闭文件对象；
4. `new FilePath(path)` 直接上传；
5. Client session 在不再使用时主动关闭。

PutObject 关键字段包括：

- `bucket`；
- `key`；
- `data`；
- `contentLength`；
- `contentMD5`；
- `useStream`；
- `contentType` 或 SDK 支持的请求头/元数据字段。

### 2.4 错误处理要求

官方示例要求优先判断：

```ts
if (err instanceof RequestError) {
  console.log('code: ', err.code);
  console.log('message: ', err.message);
  console.log('requestId: ', err.requestId);
  console.log('status: ', err.status);
  console.log('ec: ', err.ec);
}
```

HarmonyOS 项目必须保留这些原始字段的语义：

- Vendor `code`；
- Vendor `message`；
- Vendor `requestId`；
- HTTP `status`；
- OSS `ec`。

RCP 数字错误码没有 HTTP status 和 OSS RequestId 时，不得伪造 OSS 错误字段。

## 3. 当前 HarmonyOS 实现审计

### 3.1 工程路径

```text
SparkClientHarmonyOS/entry/src/main/ets/Projects/Core/OSS/OSSClientAdapter.ets
SparkClientHarmonyOS/entry/src/main/ets/Core/FileStorage/FileUploadTransportPolicy.ets
SparkClientHarmonyOS/entry/src/main/ets/Projects/Core/OSS/OSSErrorDecoder.ets
SparkClientHarmonyOS/entry/src/main/ets/Projects/Core/OSS/OSSRuntimeConfig.ets
SparkClientHarmonyOS/entry/src/main/ets/Projects/Core/OSS/OSSClientConfigNormalizer.ets
SparkClientHarmonyOS/entry/src/main/ets/Core/FileStorage/FileTransferService.ets
SparkClientHarmonyOS/entry/third_party/aliyun-oss/aliyun-oss/README.md
```

### 3.2 当前实际 SDK 版本

工程构建产物显示：

```text
@aliyun/oss version=2.0.0-beta.1
```

这与官方文档给出的公测阶段警告一致。当前不能将该 SDK 当作已经具备生产稳定性保证的正式版。

需要补齐：

- 项目依赖声明中的实际来源；
- `ohpm list` 的版本证据；
- Vendor 目录、ohpm 包和构建产物是否同一版本；
- SDK 版本变更记录；
- HarmonyOS API 版本和 SDK 版本兼容矩阵；
- 真机 RCP 错误回归记录。

### 3.3 当前 API 级别

当前构建信息显示工程编译/目标 API 高于官方最低 API 12 要求，基础版本要求目前不是首要失败原因。

仍需确认：

1. 真机系统 API 是否满足 SDK 要求；
2. DevEco Studio、HarmonyOS SDK、RCP 运行库版本是否匹配；
3. 编译产物中实际加载的 `@aliyun/oss` 是否为声明版本；
4. debug/release 构建是否使用相同 SDK；
5. 不同设备 API 版本是否都能复现或规避 RCP 错误。

### 3.4 当前 Client 初始化

当前 HarmonyOS 由 `OSSClientAdapter` 统一创建 Client，使用：

- `accessKeyId`；
- `accessKeySecret`；
- `securityToken`；
- 归一化后的 `region`；
- 必要时的 endpoint；
- `cname`；
- `secure`。

已对齐的部分：

- 没有在业务层散落创建 Client；
- STS 凭证来自运行时配置；
- region 经过归一化；
- Region/Endpoint 冲突会在 PUT 前阻断；
- Client 使用后进入 finally close；
- 敏感信息不写入日志。

仍需按官方要求确认的部分：

- 标准公共 Endpoint 是否应完全省略并只传 region；
- 显式 endpoint 模式是否只用于自定义/特殊域名；
- `cname` 是否只在自定义域名时使用；
- `secure` 是否始终为 true；
- 实际签名 region 是否与传给 Client 的 region 完全一致；
- endpoint、bucket、key 是否全部通过官方请求参数进入 SDK。

### 3.5 当前 PutObject 数据路径

当前策略经历过：

```text
v1：FilePath + stream=true + explicit length + no MD5
v2：FilePath + stream=true + no Content-Type header
v3：FilePath + stream=false + explicit length
v4：小文件 ArrayBuffer + buffered + explicit length
```

14:30 日志显示：

```text
retryAttempt=0
policy=v4-prod-arraybuffer-explicit-len
RCP=1007900056

retryAttempt=1
policy=v4-fallback-arraybuffer-explicit-len
RCP=1007900052
```

这说明：

1. 当前策略已经从 FilePath buffered 切换到业务侧 ArrayBuffer；
2. 第一次请求为 ArrayBuffer 仍未收到对端响应；
3. 第二次请求重新建立 session 后仍未收到响应；
4. 两次失败都发生在 HTTP response 之前；
5. 失败不再能简单归因于 FilePath wrapper；
6. 仍需排查 SDK 版本、Client Endpoint、签名、请求头、RCP 网络层和服务端响应可达性；
7. 不能继续只切换 `FilePath`/`ArrayBuffer` 来判断问题已解决。

## 4. 官方要求与当前实现偏差清单

| 编号 | 官方要求 | 当前状态 | 偏差/风险 | 优先级 |
| --- | --- | --- | --- | --- |
| O-01 | API 12 及以上 | 构建 API 满足 | 需补真机 API 证据，暂非主因 | P1 |
| O-02 | 使用 ohpm 安装并可查询版本 | 构建产物有 beta.1 | 依赖来源、Vendor 目录和 ohpm 版本未形成单一证据 | P0 |
| O-03 | Harmony SDK 公测版不得未经充分测试用于生产 | 当前已有生产上传策略 | 缺少正式准入门槛和回归矩阵 | P0 |
| O-04 | region 使用 `oss-cn-*` | 已归一化 | 需验证服务端原始值和最终 Client 值一致 | P0 |
| O-05 | region 与 Bucket 所在地域一致 | 有本地校验 | 缺少真实 Bucket Region 证据 | P0 |
| O-06 | STS 需要 SecurityToken | 已传入 | 需在 Client 构造前验证非空 | P0 |
| O-07 | PutObject 参数包含 bucket/key/data | adapter 已组装 | 需 request capture 验证最终请求 | P0 |
| O-08 | FilePath/fs.File 文件使用后关闭 | 本地 ArrayBuffer 读取有 close | Vendor FilePath/Client 内部关闭行为无验证 | P1 |
| O-09 | 不再使用 Client 时关闭 session | finally close | 需验证异步 response 完成后关闭且不重复关闭 | P0 |
| O-10 | RequestError 保留 code/message/requestId/status/ec | RCP 目前无 HTTP/OSS ID | 需严格区分 RCP 与 OSS 错误字段 | P0 |
| O-11 | SDK 处于公测阶段 | 2.0.0-beta.1 | 不应仅依靠手动 retry 作为稳定性方案 | P0 |
| O-12 | 文件类型路径按官方示例验证 | FilePath/ArrayBuffer 已切换 | 缺少 FilePath、fs.File、ArrayBuffer 对照结论 | P0 |
| O-13 | 官方 SDK 使用正确包入口 | adapter import 正确 | 需确认构建产物 entryPath 与官方包一致 | P1 |
| O-14 | 生产前充分测试 | RCP 两次失败 | 当前尚未达到生产准入 | P0 |
| O-15 | 连接和请求使用 SDK 生命周期 | 有 retry + close | 需验证 retry 不复用旧 session、不并发污染 | P0 |

## 5. 14:30 日志根因分析

### 5.1 第一次请求：1007900056

```text
httpPhase=111100
dnsDur=0.57
tcpDur=38.33
tlsDur=97.22
sndDur=0.14
rcvDur=0.00
osErr=104
```

结论：

- DNS 阶段完成；
- TCP/TLS 阶段有耗时，说明已尝试建立安全连接；
- 发送耗时很短；
- 没有收到 response header/data；
- `osErr=104` 说明底层连接被重置/对端关闭方向需要优先排查，但最终语义必须以 RCP 文档为准；
- 当前不能归类为 OSS 403/400。

### 5.2 第二次请求：1007900052

```text
httpPhase=111100
dnsDur=0.13
tcpDur=33.84
tlsDur=72.33
sndDur=0.12
rcvDur=0.00
osErr=11
```

结论：

- 重试创建了新的 session；
- 仍然没有 response header/data；
- 错误从 peer receive fail 变成 server returned nothing；
- 两个错误均属于 RCP 无响应类传输错误；
- 不能通过一次重试证明网络已恢复；
- 需要 request capture 或官方工具对照确认请求是否真正到达 OSS。

### 5.3 当前不能下的结论

以下结论目前都没有足够证据：

- 不能断言文件内容损坏；
- 不能断言 OSS 权限拒绝；
- 不能断言 STS 过期；
- 不能断言 Content-Length 错误；
- 不能断言 Content-Type 错误；
- 不能断言 object key 错误；
- 不能断言单纯网络不稳定；
- 不能断言 RCP 一定是唯一根因。

## 6. HarmonyOS 官方对齐修复方案

### 6.1 依赖和版本对齐

只在 HarmonyOS 工程内完成：

1. 确认 `@aliyun/oss` 的唯一依赖来源；
2. 记录 package name、version、entryPath；
3. 对比 `ohpm list` 与构建产物版本；
4. 确认没有 Vendor 目录和 ohpm 包双份加载；
5. 固定版本并在工程文档记录；
6. 升级必须经过同一套真机回归；
7. 不修改 Vendor SDK 源码；
8. 若当前版本仍为 beta，标注为“未达到生产准入”，由产品/发布流程决定是否继续使用。

### 6.2 Client 初始化对齐

HarmonyOS 只保留一个 OSS Client 工厂，并按官方模型验证：

```text
accessKeyId = STS response
accessKeySecret = STS response
securityToken = STS response
region = validated oss-* region
endpoint = only when official contract requires
cname = only for custom endpoint
secure = true
```

初始化前必须验证：

- accessKeyId 非空；
- accessKeySecret 非空；
- securityToken 非空；
- region 为 `oss-*`；
- bucket region 与 region 一致；
- endpoint 与 region 一致；
- Bucket 名称非空；
- object key 经过校验。

### 6.3 PutObject 参数对齐

每次 PUT 必须明确记录但不泄漏明文：

- bucket fingerprint；
- key fingerprint 和字节长度；
- data kind；
- useStream；
- contentLength mode；
- contentLength value bucket；
- contentMD5 mode；
- contentType mode；
- region alias；
- endpoint mode；
- SDK version；
- retry attempt。

业务层不能直接改变这些参数。所有参数由 HarmonyOS Core OSS adapter 统一决定。

### 6.4 文件对象和句柄生命周期

按照官方示例对齐：

1. `fs.open`/`fs.openSync` 后必须在 finally 关闭；
2. FilePath 不应与已关闭文件句柄混用；
3. fs.File 交给 SDK 后，必须等 `putObject` 完成再关闭；
4. 每个上传任务不得共享同一个 fs.File；
5. ArrayBuffer 路径不应再持有不必要的文件句柄；
6. 失败、取消、超时和异常都必须释放资源；
7. 不能在 retry 前复用已关闭的 FilePath/fs.File/session。

### 6.5 Session 生命周期

必须按官方语义执行：

```text
create Client
  → await putObject
  → read success/error result
  → close session once
```

重试必须是完整的新任务：

```text
close old session
  → create new Client
  → create new request body
  → await new putObject
  → close new session once
```

禁止：

- await 前关闭 session；
- retry 复用旧 Client；
- 多个上传任务共享 mutable activeClient；
- finally 与取消回调重复 close；
- close 时覆盖原始 RequestError。

## 7. RCP 错误预防和定位

### 7.1 不再只做 payload 切换

当前 v4 已证明：

- ArrayBuffer 首次请求失败；
- ArrayBuffer fallback 二次请求失败；
- 两次都在 response header 前失败。

下一步必须同时对照：

1. 官方 SDK 示例的最小 ArrayBuffer 请求；
2. 当前业务的 ArrayBuffer 请求；
3. 官方 SDK 示例的 FilePath 请求；
4. 当前业务的 FilePath 请求；
5. 同一 endpoint/region 下的简单 `listObjectsV2` 或 `getObject` 只读请求；
6. 测试 Bucket 中的固定 ASCII key；
7. 同一设备不同网络；
8. SDK 版本和 API 版本。

### 7.2 最小官方等价测试

HarmonyOS 内建立仅用于测试的最小 adapter case：

```text
Client(STS + region)
putObject({
  bucket: fixedTestBucket,
  key: fixedAsciiKey,
  data: smallArrayBuffer
})
await result
close session
```

该测试不得接入医疗业务，不得写入生产 Bucket，不得输出凭证。

判定：

- 最小官方等价 case 成功、业务 adapter 失败：HarmonyOS adapter 参数/生命周期问题；
- 最小 case 也失败：SDK、RCP、设备网络、Endpoint 或环境问题；
- 只读 GET 成功、PUT 失败：PUT body/header/signature/权限方向；
- GET/PUT 均无响应：Endpoint/RCP/网络/SDK 方向。

### 7.3 RCP 与 OSS 错误分层

RCP 错误：

```text
httpStatus=0
ossCode=1007900056 或 1007900052
ossRequestId=empty
requestValidationReason=peerReceiveFailed|rcpTransport
```

OSS 错误：

```text
httpStatus>0
ossCode=AccessDenied|InvalidArgument|...
ossEc=...
ossRequestId=存在
```

不得把 RCP 数字码写成 OSS XML Code，也不得在 RCP 失败时伪造 RequestId。

## 8. 重试和用户提示

官方 SDK 公测阶段不等于可以无限自动重试。HarmonyOS 规则：

1. RCP 无响应首次可自动重试一次；
2. 重试必须创建全新 Client/session/request body；
3. 相同 RCP 错误连续两次后停止自动重试；
4. 页面可允许用户手动重试一次；
5. 不刷新 STS，除非明确是凭证过期；
6. 不改变 Bucket、Endpoint、Region 来盲试；
7. 提示“网络连接不稳定，请稍后重试”；
8. 不显示 RCP 数字码；
9. 不进入 OCR、类型识别和文件登记；
10. 失败后允许返回选择。

## 9. 验收标准

### 9.1 官方 SDK 接入

- API 版本满足官方最低要求；
- `@aliyun/oss` 版本来源和实际构建版本一致；
- `ohpm list` 结果已归档；
- Vendor 目录没有绕过包管理器产生第二份运行时；
- SDK beta 风险已记录；
- 未修改 Vendor SDK 源码。

### 9.2 Client 和 PutObject

- Client 只在 HarmonyOS Core OSS adapter 创建；
- STS 三字段完整传入；
- region 为 `oss-*` 且与 Bucket 一致；
- endpoint 使用方式符合官方规则；
- bucket/key/data 参数可通过测试捕获验证；
- FilePath、fs.File、ArrayBuffer 至少各有一组真实测试结果；
- 文件句柄和 session 生命周期无泄漏；
- retry 不复用旧 session。

### 9.3 错误和日志

- RCP `1007900056`、`1007900052` 被正确归为传输错误；
- RCP 失败不伪造 HTTP status、OSS EC 或 OSS RequestId；
- RequestError 字段保留 code/message/requestId/status/ec；
- OSS 4xx/5xx 与 RCP 错误分层；
- 日志包含 policy、SDK、payload、retry 和 session 摘要；
- 日志不含凭证、签名、原始路径和文件内容。

### 9.4 业务验收

- 相册图片上传失败停留在 upload 阶段；
- fullScreenCover 页面提示统一；
- 失败不进入 OCR/抽取/保存；
- 可有限重试和返回选择；
- 不产生文件登记孤儿记录；
- 未修改 iOS 和服务器。

## 10. 禁止事项

1. 不允许修改任何 iOS 代码；
2. 不允许修改任何服务器代码或配置；
3. 不允许修改 OSS 权限和 STS Role；
4. 不允许修改 `entry/third_party/aliyun-oss` Vendor 源码；
5. 不允许只通过增加重试次数掩盖 RCP 错误；
6. 不允许把公测版 SDK 当作已验证的生产稳定版本；
7. 不允许把 RCP 数字码映射成 OSS 业务错误；
8. 不允许在请求未完成前关闭 session；
9. 不允许在 retry 中复用旧 Client、文件句柄或请求体；
10. 不允许上传失败后继续医疗识别 pipeline。

## 11. 证据路径和官方参考

项目：

```text
SparkClientHarmonyOS/entry/src/main/ets/Projects/Core/OSS/OSSClientAdapter.ets
SparkClientHarmonyOS/entry/src/main/ets/Core/FileStorage/FileUploadTransportPolicy.ets
SparkClientHarmonyOS/entry/src/main/ets/Projects/Core/OSS/OSSErrorDecoder.ets
SparkClientHarmonyOS/entry/src/main/ets/Core/FileStorage/FileTransferService.ets
SparkClientHarmonyOS/entry/third_party/aliyun-oss/aliyun-oss/README.md
```

官方资料附件：

```text
/Users/hua/.codex/attachments/e6b893b5-c3aa-41c8-834d-3e910c0dc08a/pasted-text.txt
/Users/hua/.codex/attachments/f6b34f76-d9d4-4114-9e01-acb0c566ee21/pasted-text.txt
```

本次日志附件：

```text
/Users/hua/.codex/attachments/37fcb20a-7ee4-40a0-899a-2e6e854845ba/pasted-text.txt
```

## 12. 工单完成说明

本工单已完成（文档对照 + HarmonyOS 代码落地，2026-07-24）：

### 12.1 文档与官方对照

- 官方 Harmony SDK 环境、安装、版本和公测风险对照；
- Client 初始化参数对照；
- STS、Region、Endpoint 和 Bucket 规则对照；
- PutObject 数据类型、Content-Length、Content-MD5 和 stream 规则对照；
- FilePath、fs.File、ArrayBuffer 生命周期对照；
- RequestError 字段和 RCP 错误分层；
- 14:30 两次 RCP 无响应日志分析；
- HarmonyOS 官方等价最小测试方案；
- SDK 版本、依赖来源、session、重试和生产准入验收标准。

### 12.2 HarmonyOS 实施落地（未改 iOS / 服务器 / Vendor 源码）

1. **`OSSVendorSdkMeta`**：单一版本事实源（`2.0.0-beta.1`）、`PRODUCTION_ADMITTED=false`、日志 `productionGate=beta-not-admitted`；证据见 `HOS-FILE-OSS-0007-SDK版本与依赖证据.md`。
2. **Client**：构造前强制非空 `securityToken`；标准公有云省略 endpoint、`secure=true`、`cname` 仅自定义域名。
3. **PutObject**：生产小文件仍 ArrayBuffer；补齐官方 `fs.File` 路径（open → await put → finally close）；FilePath / ArrayBuffer / fs.File 矩阵策略 `officialMatrix`。
4. **请求捕获**：`OSSPutRequestCapture` 记录 bucketFp/keyFp/dataKind/contentLength/sdkVer/sessionLifecycle，无凭证与明文路径。
5. **官方等价**：`OSSOfficialEquivalence` 最小 ArrayBuffer/FilePath/fs.File 计划 + 标准 Client 初始化断言（单测，不写生产 Bucket）。
6. **Session**：`create → await putObject → closeSessionOnce`；重试为全新 Client/session/body；close 幂等且不覆盖原错误。
7. **RCP 分层**：`1007900056`→`peerReceiveFailed`，`1007900052`→`serverReturnedNothing`；RCP 失败不伪造 HTTP status / OSS EC / OSS RequestId；日志 `errorLayer=rcp|oss` + `rcpCode`。
8. **重试 / UX**：RCP 仅自动重试一次；连续两次同指纹停止鼓励重试；文案「网络连接不稳定…」，不展示 RCP 数字码。
9. **测试**：`OSSOfficialAlignment.test.ets` 覆盖版本准入、STS token、三 payload、捕获脱敏、RCP/OSS 分层。

### 12.3 仍开放（需真机/环境）

- 真机最小官方等价 PUT 与业务 adapter 对照结论（网络可达时）；
- 公测 SDK 正式生产准入决策；
- RCP 根因是否为设备网络 / Endpoint / SDK 运行时（已排除单纯 FilePath→ArrayBuffer）。

范围约束：未修改 iOS、服务器、OSS 权限、STS Role、Vendor SDK 源码。
