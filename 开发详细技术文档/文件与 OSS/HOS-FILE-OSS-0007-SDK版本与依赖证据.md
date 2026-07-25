# HOS-FILE-OSS-0007｜SDK 版本与依赖证据归档

归档时间：2026-07-24

## 1. 依赖声明（唯一来源）

`SparkClientHarmonyOS/entry/oh-package.json5`：

```json5
"@aliyun/oss": "file:./third_party/aliyun-oss/aliyun-oss"
```

说明：工程使用本地 Vendor HAR 路径声明，经 ohpm 解析为模块 `@aliyun/oss`；**不修改** `entry/third_party/aliyun-oss` 源码。

## 2. Vendor 包元数据

`entry/third_party/aliyun-oss/aliyun-oss/oh-package.json5`：

| 字段 | 值 |
| --- | --- |
| name | `@aliyun/oss` |
| version | `2.0.0-beta.1` |
| types / entry | `./src/main/harmony/index.d.ets` |
| compatibleSdkVersion | `12` |
| release phase | public-preview / beta |

## 3. 构建产物解析证据

CompileArkTS `dep_info.json`：

```text
"@aliyun/oss": ".../entry/third_party/aliyun-oss/aliyun-oss"
```

归一化模块 URL 含版本后缀：

```text
@aliyun/oss/src/main/harmony/index&2.0.0-beta.1
```

结论：声明路径、Vendor 目录、构建解析为同一版本，无第二份 ohpm registry 运行时副本。

## 4. API / 工程 SDK

| 项 | 值 |
| --- | --- |
| 官方最低 API | 12 |
| 工程 compatibleSdkVersion | 6.1.0(23) |
| 工程 targetSdkVersion | 6.1.1(24) |
| 基础 API 门槛 | 满足（真机系统 API 仍需现场确认） |

## 5. 生产准入

代码事实源：`OSSVendorSdkMeta.PRODUCTION_ADMITTED = false`

官方明确公测版未经充分测试不得直接用于生产。当前：

- 允许调试与受控上传验证；
- 日志携带 `productionGate=beta-not-admitted`；
- 不以增加自动重试次数替代稳定性准入；
- 正式准入需产品/发布流程显式放行并同步本文件与 `OSSVendorSdkMeta`。

## 6. ohpm list

本机若已安装 ohpm，可在 `SparkClientHarmonyOS/entry` 执行：

```bash
ohpm list
```

期望看到 `@aliyun/oss@2.0.0-beta.1` 解析自 `file:./third_party/aliyun-oss/aliyun-oss`。

若环境未配置 ohpm CLI，以本节 §2–§3 的 Vendor 元数据 + 构建 `dep_info` 作为等价证据。
