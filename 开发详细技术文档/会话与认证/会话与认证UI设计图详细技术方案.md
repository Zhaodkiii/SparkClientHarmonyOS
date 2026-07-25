# SupportClientHuawei｜会话与认证 UI 设计图详细技术方案

## 1. 对标范围与结论

### 1.1 本文档范围

本文档只补充会话与认证模块的 UI 设计图、HarmonyOS 设计方案与 UI 技术细节，不替代认证接口、Token、会话恢复和退出登录底座方案。认证业务链路继续以 `会话与认证详细技术方案.md` 为主。

对标输入：

| 输入 | 说明 |
| --- | --- |
| iOS UI 文档 | `SupportClient/总领文档/会话与认证/会话与认证UI设计图.md` |
| iOS 参考代码 | `SupportClient/Projects/Features/Auth/Presentation/LoginView.swift`、`LoginConductor.swift`、`VerificationCodeField.swift`、`LoginLegalAgreementNote.swift`、`PhoneRegions.swift` |
| HarmonyOS 当前代码 | `SupportClientHuawei/entry/src/main/ets/Projects/Features/Auth/`（`LoginPage`/`PhoneLoginPage`/`OtpVerifyPage`/`LoginViewModel`/`components/*`）、`App/LegalAcceptanceStore.ets`；领域底座与截图级登录 UI（P0–P7）已落地；华为账号仍为「即将支持」占位 |
| 华为 demo | `Package/Huawei/agc-template-market-harmonyos-demos-main/.../components/aggregated_login/` |
| 官方能力 | ArkUI `Navigation`、`TextInput`、`Button`、`Checkbox`、`bindSheet`、ArkWeb `Web`、Account Kit 登录组件 |

### 1.2 截图级页面范围

| 截图 | iOS 页面状态 | HarmonyOS 目标页面 | 当前 HarmonyOS 状态 | 结论 |
| --- | --- | --- | --- | --- |
| Image #1 | 登录首页，协议已勾选 | `LoginPage.ets` 登录首页 | 已实现：盾牌 Hero、欢迎文案、华为/手机号/游客、底部协议勾选 | 已实现 |
| Image #2 | 6 位验证码页，键盘弹出 | `OtpVerifyPage.ets` | 已实现：6 格、脱敏手机号、倒计时重发、按钮提交验码 | 已实现 |
| Image #3 | 手机号登录页，输入手机号 | `PhoneLoginPage.ets` | 已实现：地区入口、手机号输入、获取验证码（&lt;6 位禁用） | 已实现 |
| Image #4 | 国家/地区选择展开 | `RegionPickerSheet.ets` | 已实现：常用 12 地区名称+区号（无旗帜） | 已实现 |
| Image #5 | 首次协议提示半屏弹窗 | `LoginLegalPromptSheet.ets` | 已实现：`bindSheet`，不同意/同意显式关闭 | 已实现 |
| Image #6 | 隐私政策阅读器 | `LegalWebPage.ets` | 已实现：ArkWeb + 失败重试；占位 HTTPS URL | 已实现 |

### 1.3 平台适配结论

| iOS 入口 | HarmonyOS 设计 | 是否保持一致 | 处理原因 |
| --- | --- | --- | --- |
| `通过 Apple 登录` | 优先替换为 `通过华为账号登录`，底层待接 Account Kit 与后端 Huawei 身份换票接口 | 文案和平台能力不一致，交互位置一致 | 华为端不应展示 Apple 专属入口，除非产品明确要求跨平台 Apple 登录 |
| `手机号登录` | 保持 `手机号登录` | 一致 | 后端已有 OTP API 契约，可复用会话底座 |
| `游客模式` | 保持 `游客模式` 或 `设备游客登录` | 一致 | HarmonyOS 已有设备登录链路，可继续作为无账号入口 |
| 协议勾选 | 保持勾选区与首次半屏提示 | 一致 | 登录前合规门禁，两端必须同一行为 |
| Safari 阅读器 | 改为 ArkWeb 内置阅读页或系统浏览器承载 | 视觉近似，组件不同 | HarmonyOS 没有 iOS `SFSafariViewController`，应使用 `Web` 与自定义顶部栏 |

### 1.4 最终结论

HarmonyOS 已将 `LoginPage.ets` 升级为截图级认证入口，并落地手机号登录、验证码、地区选择、协议半屏与协议 Web 阅读页；业务经 `LoginViewModel` 调用既有 UseCase / `AppSessionStore`。华为账号登录仍为占位提示「即将支持」，须等待后端确认 Huawei token 换取 Spark 会话的接口契约后再接 Account Kit。

## 2. 华为端目录设计

### 2.1 当前目录

```text
SupportClientHuawei/entry/src/main/ets/
├── App/
│   ├── AppContainer.ets
│   ├── AppSessionStore.ets
│   ├── AccountSessionRuntime.ets
│   └── LegalAcceptanceStore.ets
├── Foundation/Security/
│   └── DeviceCredentialStore.ets
└── Projects/
    ├── Core/
    │   ├── Domain/Entities/UserSession.ets
    │   └── Networking/API/
    │       ├── Auth/AuthAPI.ets
    │       └── Auth/OTPAPI.ets
    └── Features/
        └── Auth/
            ├── LoginPage.ets
            ├── PhoneLoginPage.ets
            ├── OtpVerifyPage.ets
            ├── LoginViewModel.ets
            ├── AuthUiState.ets
            ├── PhoneRegion.ets
            ├── AuthNavContext.ets
            ├── components/
            │   ├── AuthHeroIcon.ets
            │   ├── LegalAgreementNote.ets
            │   ├── LoginLegalPromptSheet.ets
            │   ├── RegionPickerSheet.ets
            │   ├── OtpCodeInput.ets
            │   ├── AuthToast.ets
            │   └── LegalWebPage.ets
            ├── Domain/AuthRepository.ets
            ├── Application/*UseCase.ets
            └── Infrastructure/
                ├── SessionSnapshotStore.ets
                └── DefaultAuthRepository.ets
```

### 2.2 目标目录

建议保留 `LoginPage.ets` 作为路由入口，新增 UI 组件与状态模型：

```text
SupportClientHuawei/entry/src/main/ets/Projects/Features/Auth/
├── LoginPage.ets                         # 登录首页，承载 Image #1
├── PhoneLoginPage.ets                    # 手机号登录页，承载 Image #3
├── OtpVerifyPage.ets                     # 验证码页，承载 Image #2
├── LoginViewModel.ets                    # 页面状态、输入校验、倒计时、登录动作
├── AuthUiState.ets                       # UI 状态类型，不保存敏感长期数据
├── PhoneRegion.ets                       # 国家/地区区号列表与格式化
├── components/
│   ├── AuthHeroIcon.ets                  # 盾牌/电话渐变图标
│   ├── LegalAgreementNote.ets            # 底部协议勾选区
│   ├── LoginLegalPromptSheet.ets         # 首次协议提示半屏
│   ├── RegionPickerSheet.ets             # 地区选择浮层
│   ├── OtpCodeInput.ets                  # 6 位验证码输入格
│   ├── AuthToast.ets                     # 顶部成功/错误通知
│   └── LegalWebPage.ets                  # 协议 Web 阅读页
└── resources/
    └── AuthStrings.ets                   # 可选：临时集中常量，最终沉淀到 string.json
```

资源建议：

```text
SupportClientHuawei/entry/src/main/resources/
├── base/element/string.json              # auth.login.*、auth.phone.*、auth.otp.*、auth.legal.*
├── zh_CN/element/string.json
├── en_US/element/string.json
└── base/media/
    ├── ic_auth_shield.svg                # 可选，若不使用 SymbolGlyph
    └── ic_auth_phone.svg
```

### 2.3 文档目录

```text
SupportClientHuawei/开发详细技术文档/
├── iOS-HarmonyOS功能对照矩阵.md
└── 会话与认证/
    ├── 会话与认证详细技术方案.md
    └── 会话与认证UI设计图详细技术方案.md
```

## 3. 分层职责与请求链路

### 3.1 UI 分层

| 层级 | 文件 | 职责 |
| --- | --- | --- |
| 页面层 | `LoginPage.ets` | 展示登录首页、协议门禁、华为账号/手机号/游客入口 |
| 页面层 | `PhoneLoginPage.ets` | 展示手机号输入、地区选择入口、获取验证码 |
| 页面层 | `OtpVerifyPage.ets` | 展示 6 位验证码、倒计时、重发、验证并登录 |
| 组件层 | `LegalAgreementNote.ets` | 协议勾选区，触发半屏提示或 Web 阅读 |
| 组件层 | `LoginLegalPromptSheet.ets` | 首次协议说明、权限说明、同意/拒绝 |
| 组件层 | `RegionPickerSheet.ets` | 国家/地区列表选择 |
| 组件层 | `OtpCodeInput.ets` | 单输入源驱动 6 个验证码格 |
| 组件层 | `LegalWebPage.ets` | ArkWeb 加载服务条款/隐私协议 |
| 状态层 | `LoginViewModel.ets` | 输入校验、按钮状态、倒计时、网络请求、错误映射 |
| 服务层 | `AppContainer.ets`、`AuthAPI.ets`、`OTPAPI.ets` | 发起认证请求、写入 token/session |

### 3.2 登录首页链路

```text
用户进入 LoginPage
├── 读取 legalAccepted
├── 展示登录首页
│   ├── 点击 通过华为账号登录
│   │   ├── legalAccepted=false -> 打开 LoginLegalPromptSheet
│   │   └── legalAccepted=true -> 调用华为账号授权 -> 后端换 Spark 会话
│   ├── 点击 手机号登录
│   │   ├── legalAccepted=false -> 打开 LoginLegalPromptSheet
│   │   └── legalAccepted=true -> push PhoneLoginPage
│   └── 点击 游客模式
│       ├── legalAccepted=false -> 打开 LoginLegalPromptSheet
│       └── legalAccepted=true -> 复用现有 deviceLogin -> enterSignedIn
└── 点击 服务条款/隐私协议 -> push LegalWebPage 或 sheet 内嵌 Web
```

### 3.3 手机号验证码链路

```text
PhoneLoginPage
├── 选择地区
│   └── RegionPickerSheet 更新 selectedRegion
├── 输入手机号
│   └── LoginViewModel 归一化号码与按钮可用态
├── 点击 获取验证码
│   ├── 校验手机号
│   ├── OTPAPI.requestOtp
│   ├── 成功 -> push OtpVerifyPage，并展示 AuthToast: 验证码已发送
│   └── 失败 -> 保留当前页，展示错误文案
└── OtpVerifyPage
    ├── 输入 6 位验证码
    ├── 点击 验证并登录
    ├── OTPAPI.verifyOtp / AuthAPI.phoneLogin
    ├── 成功 -> tokenProvider.setSession -> sessionStore.enterSignedIn
    └── 失败 -> 不写 session，保留页面
```

### 3.4 协议阅读链路

```text
LoginLegalPromptSheet / LegalAgreementNote
├── 点击 服务条款
│   └── Navigation.push('LegalWebPage', { title, url })
└── 点击 隐私协议
    └── Navigation.push('LegalWebPage', { title, url })
```

## 4. 核心关键技术与实现方案

### 4.1 登录首页 UI 设计图

Plain text 设计图：

```text
┌──────────────────────────────────────┐
│ 状态栏                                │
│                登录                  │
│                                      │
│          ┌────────────────┐          │
│          │   蓝紫渐变盾牌   │          │
│          └────────────────┘          │
│                                      │
│          欢迎使用健康助手             │
│          登录后享受更多个性化服务       │
│                                      │
│  ┌────────────────────────────────┐  │
│  │      华为图标  通过华为账号登录   │  │
│  └────────────────────────────────┘  │
│                                      │
│  ─────────────  或  ─────────────    │
│                                      │
│  ┌────────────────────────────────┐  │
│  │        电话图标  手机号登录       │  │
│  └────────────────────────────────┘  │
│                                      │
│              游客模式                │
│                                      │
│  ☑ 我已阅读并同意                    │
│    《服务条款》和《隐私协议》          │
└──────────────────────────────────────┘
```

控件标注：

| 编号 | UI 元素 | HarmonyOS 组件 | 展示内容 | 行为 | 技术细节 |
| --- | --- | --- | --- | --- | --- |
| H-A1 | 页面标题 | `Navigation`/自定义 `Row` | `登录` | 无 | 页面作为未登录态根页，不显示返回 |
| H-A2 | 安全图标 | `Stack` + `LinearGradient` + `SymbolGlyph` 或 `Image` | 蓝紫渐变盾牌 | 装饰 | 尺寸约 92vp，圆角 20vp |
| H-A3 | 主标题 | `Text` | `欢迎使用健康助手` | 无 | 字重 700，字号 26fp 左右 |
| H-A4 | 副标题 | `Text` | `登录后享受更多个性化服务` | 无 | 灰色辅助文案 |
| H-A5 | 华为账号登录 | `Button` | `通过华为账号登录` | 发起 Huawei ID 授权 | 若后端未提供 Huawei 登录接口，先 Feature Flag 隐藏 |
| H-A6 | 分隔线 | `Row` + `Divider` + `Text` | `或` | 无 | 与 iOS 截图保持视觉节奏 |
| H-A7 | 手机号登录 | `Button` | `手机号登录` | 进入 `PhoneLoginPage` | 未同意协议时打开协议半屏 |
| H-A8 | 游客模式 | `Text`/`Button` | `游客模式` | 调用现有 `deviceLogin` | 未同意协议时打开协议半屏 |
| H-A9 | 协议勾选 | `Checkbox` + `Text` | `我已阅读并同意` | 打开协议半屏或切换同意态 | 同意态用 `Preferences` 持久化 |
| H-A10 | 服务条款 | `Span`/`Text` | `《服务条款》` | 打开 `LegalWebPage` | 链接色使用主蓝 |
| H-A11 | 隐私协议 | `Span`/`Text` | `《隐私协议》` | 打开 `LegalWebPage` | 链接色使用主蓝 |

实现要点：

| 项 | 方案 |
| --- | --- |
| 布局 | `Column` 全屏，顶部标题固定，中部内容按截图纵向居中，上下使用 `Blank` 或固定 vp 间距 |
| 背景 | 使用 `sys.color.background_secondary` 或自定义 `#F7F8FC`，保持截图浅灰背景 |
| 登录按钮 | 华为账号主按钮可使用黑底或华为品牌红/深色，手机号按钮使用蓝色描边 |
| 门禁 | 所有登录动作先走 `ensureLegalAccepted(action)`，未同意只弹协议，不发请求 |
| 加载 | `busy=true` 时禁用三个登录入口，按钮内可展示 `LoadingProgress` |

### 4.2 首次协议提示半屏 UI 设计图

Plain text 设计图：

```text
┌──────────────────────────────────────┐
│ 登录页背景灰色遮罩                     │
│                                      │
│  ┌────────────────────────────────┐  │
│  │             ───                │  │
│  │           温馨提示              │  │
│  │                                │  │
│  │ 欢迎使用健康助手。在使用前，       │  │
│  │ 请认真阅读并理解以下协议：         │  │
│  │ 服务条款、隐私协议                │  │
│  │                                │  │
│  │ 本服务提供的信息仅供健康管理和     │  │
│  │ 记录参考，不作为诊断、治疗或       │  │
│  │ 用药的直接处置依据。              │  │
│  │                                │  │
│  │ • 常用设备信息：用于检查网络环境... │  │
│  │ • 位置信息：用于位置相关展示...    │  │
│  │                                │  │
│  │      不同意        同意并继续      │  │
│  └────────────────────────────────┘  │
└──────────────────────────────────────┘
```

控件标注：

| 编号 | UI 元素 | HarmonyOS 组件 | 展示内容 | 行为 | 技术细节 |
| --- | --- | --- | --- | --- | --- |
| H-B1 | 遮罩 | `bindSheet` 系统遮罩 | 登录页置灰 | 点击遮罩按策略关闭或不关闭 | 建议协议首次弹窗不允许误触关闭 |
| H-B2 | 拖拽条 | `bindSheet` drag bar 或自绘 `Divider` | 顶部短横 | 视觉提示 | 若强制阅读，可禁用拖拽关闭 |
| H-B3 | 标题 | `Text` | `温馨提示` | 无 | 居中，字重 700 |
| H-B4 | 协议引导 | `Text`/`RichText` | 阅读服务条款和隐私协议 | 无 | 链接独立可点 |
| H-B5 | 服务条款 | `Text`/`Span` | `服务条款` | 打开服务条款 Web | 传入 `LegalDocumentType.terms` |
| H-B6 | 隐私协议 | `Text`/`Span` | `隐私协议` | 打开隐私协议 Web | 传入 `LegalDocumentType.privacy` |
| H-B7 | 免责声明 | `Text` | 健康信息仅供参考 | 无 | 与 iOS 文案一致 |
| H-B8 | 权限说明 | `ForEach` + `Row` | 设备、位置等用途 | 无 | 后续相机/麦克风权限按真实功能补齐 |
| H-B9 | 不同意 | `Button` | `不同意` | 关闭弹窗，保持未同意 | 不写持久化 |
| H-B10 | 同意并继续 | `Button` | `同意并继续` | 写入协议确认并继续上一次动作 | 写 `legalAccepted=true` 到 Preferences |

实现要点：

| 项 | 方案 |
| --- | --- |
| 半屏能力 | 使用 ArkUI `bindSheet`，设置合适高度、圆角、遮罩、拖拽条 |
| 内容滚动 | 正文区使用 `Scroll`，底部按钮固定 |
| 动作续接 | `pendingAction` 保存用户原始点击：华为账号、手机号、游客 |
| 合规持久化 | 只持久化协议确认版本号和时间，不持久化 OTP、手机号全文 |

### 4.3 手机号登录页 UI 设计图

Plain text 设计图：

```text
┌──────────────────────────────────────┐
│  ○ 返回          手机号登录            │
│                                      │
│          ┌────────────────┐          │
│          │   蓝绿渐变电话   │          │
│          └────────────────┘          │
│                                      │
│          安全快速登录                 │
│          银行级别安全保护，支持全球多地区 │
│                                      │
│  手机号码 *                           │
│  ┌────────────────────────────────┐  │
│  │ 中国 +86 ▼ │ 15385056020        │  │
│  └────────────────────────────────┘  │
│                                      │
│  ┌────────────────────────────────┐  │
│  │            获取验证码             │  │
│  └────────────────────────────────┘  │
└──────────────────────────────────────┘
```

控件标注：

| 编号 | UI 元素 | HarmonyOS 组件 | 展示内容 | 行为 | 技术细节 |
| --- | --- | --- | --- | --- | --- |
| H-C1 | 返回按钮 | `Button` + `SymbolGlyph` | 左箭头圆按钮 | `pathStack.pop()` | 视觉与 iOS 圆形返回一致 |
| H-C2 | 页面标题 | `Text` | `手机号登录` | 无 | 可隐藏系统 title，自定义居中 |
| H-C3 | 电话图标 | `AuthHeroIcon` | 蓝绿渐变电话 | 无 | 与首页盾牌同尺寸体系 |
| H-C4 | 主标题 | `Text` | `安全快速登录` | 无 | 字重 700 |
| H-C5 | 副标题 | `Text` | `银行级别安全保护，支持全球多地区` | 无 | 灰色辅助 |
| H-C6 | 字段标签 | `Text` | `手机号码 *` | 无 | 左对齐 |
| H-C7 | 地区选择 | `Button`/`Row` | `中国 +86 ▼` | 打开 `RegionPickerSheet` | 不建议用系统小尺寸菜单直接照搬，截图浮层更大 |
| H-C8 | 手机号输入 | `TextInput` | 手机号 | 输入手机号 | `type(InputType.PhoneNumber)`，`maxLength` 按地区限制 |
| H-C9 | 获取验证码 | `Button` | `获取验证码` | 调用 `OTPAPI.requestOtp` | 手机号不足时禁用 |

实现要点：

| 项 | 方案 |
| --- | --- |
| 键盘 | `TextInput.type(InputType.PhoneNumber)`，页面底部用 `SafeArea`/键盘避让避免按钮被遮挡 |
| 归一化 | `PhoneRegion` 提供 `countryCode`、`dialCode`、`localizedName`、`maxLength` |
| 输入行为 | 用户输入 `+86` 前缀时可自动识别地区并剥离国家码；若复杂度过高，首期只允许通过地区选择修改 |
| 请求中 | 点击后按钮显示 loading，不允许修改已提交号码跳到验证码页 |

### 4.4 地区选择 UI 设计图

Plain text 设计图：

```text
┌──────────────────────────────────────┐
│ 手机号登录页背景                       │
│                                      │
│     ┌──────────────────────┐         │
│     │ 中国          +86    │         │
│     │ 中国香港      +852   │         │
│     │ 中国台湾      +886   │         │
│     │ 日本          +81    │         │
│     │ 韩国          +82    │         │
│     │ 中国澳门      +853   │         │
│     │ 新加坡        +65    │         │
│     │ 马来西亚      +60    │         │
│     │ 泰国          +66    │         │
│     │ 印度尼西亚    +62    │         │
│     │ 菲律宾        +63    │         │
│     │ 越南          +84    │         │
│     └──────────────────────┘         │
└──────────────────────────────────────┘
```

控件标注：

| 编号 | 国家/地区 | 区号 | 行为 |
| --- | --- | --- | --- |
| H-D1 | 中国 | `+86` | 选择后更新手机号前缀 |
| H-D2 | 中国香港 | `+852` | 选择后更新手机号前缀 |
| H-D3 | 中国台湾 | `+886` | 选择后更新手机号前缀 |
| H-D4 | 日本 | `+81` | 选择后更新手机号前缀 |
| H-D5 | 韩国 | `+82` | 选择后更新手机号前缀 |
| H-D6 | 中国澳门 | `+853` | 选择后更新手机号前缀 |
| H-D7 | 新加坡 | `+65` | 选择后更新手机号前缀 |
| H-D8 | 马来西亚 | `+60` | 选择后更新手机号前缀 |
| H-D9 | 泰国 | `+66` | 选择后更新手机号前缀 |
| H-D10 | 印度尼西亚 | `+62` | 选择后更新手机号前缀 |
| H-D11 | 菲律宾 | `+63` | 选择后更新手机号前缀 |
| H-D12 | 越南 | `+84` | 选择后更新手机号前缀 |

实现要点：

| 项 | 方案 |
| --- | --- |
| 截图一致优先 | 首期用 `bindSheet` 或自定义浮层 `Stack` + `List`，比系统 `Menu` 更容易控制宽度、圆角、阴影和可见行数 |
| 列表项 | `Row` 左侧国家/地区名，右侧区号；如资源支持，可增加旗帜图标 |
| 选择后 | 更新 `selectedRegion`，关闭浮层，不清空手机号 |
| 可扩展 | `PhoneRegion.defaultRegions` 可包含更多地区，截图只验收首屏可见 12 个 |

### 4.5 验证码页 UI 设计图

Plain text 设计图：

```text
┌──────────────────────────────────────┐
│ ┌──────────────────────────────────┐ │
│ │ ✓  验证码已发送                   │ │
│ └──────────────────────────────────┘ │
│                                      │
│          输入 6 位验证码              │
│          验证码已发送至 +86 153****20 │
│                                      │
│   ┌───┐ ┌───┐ ┌───┐ ┌───┐ ┌───┐ ┌───┐│
│   │   │ │   │ │   │ │   │ │   │ │   ││
│   └───┘ └───┘ └───┘ └───┘ └───┘ └───┘│
│                                      │
│             重新发送 59s             │
│                                      │
│  ┌────────────────────────────────┐  │
│  │ 盾牌 安全提示：验证码5分钟内有效， │  │
│  │ 请勿泄露给他人。如未收到验证码，   │  │
│  │ 请检查短信是否被拦截。             │  │
│  └────────────────────────────────┘  │
│                                      │
│  ┌────────────────────────────────┐  │
│  │            验证并登录             │  │
│  └────────────────────────────────┘  │
└──────────────────────────────────────┘
```

控件标注：

| 编号 | UI 元素 | HarmonyOS 组件 | 展示内容 | 行为 | 技术细节 |
| --- | --- | --- | --- | --- | --- |
| H-E1 | 成功通知 | `AuthToast`/`Toast` | `验证码已发送` | 发码成功后展示 | 顶部胶囊样式，2 秒自动消失 |
| H-E2 | 标题 | `Text` | `输入 6 位验证码` | 无 | 居中 |
| H-E3 | 发送目标 | `Text` | `验证码已发送至 +86 153****20` | 无 | 手机号必须脱敏 |
| H-E4 | 验证码输入格 | `OtpCodeInput` | 6 个输入格 | 输入 6 位数字 | 使用单个隐藏 `TextInput` 存真实输入，6 个 `Text` 只展示 |
| H-E5 | 倒计时 | `Text` | `重新发送 59s` | 倒计时中不可点 | `setInterval` 每秒递减 |
| H-E6 | 重新发送 | `Button`/`Text` | `重新发送` | 重新请求 OTP | 倒计时归零后可点 |
| H-E7 | 安全提示 | `Row` + `Text` | 验证码有效期和防泄露提醒 | 无 | 卡片背景白色 |
| H-E8 | 验证并登录 | `Button` | `验证并登录` | 调用验证码登录 | 6 位码且未 busy 才允许提交 |

实现要点：

| 项 | 方案 |
| --- | --- |
| 输入源 | 一个 `TextInput` 负责系统键盘和输入法兼容，6 个方框根据 `code[index]` 渲染 |
| 焦点边框 | 当前输入位使用黄色边框，已输入位使用主蓝或深色 |
| 自动提交 | 可在满 6 位时触发验证，但必须防重复；建议首期只启用按钮提交，降低误触风险 |
| 倒计时生命周期 | 页面 `aboutToDisappear` 清理 timer，重发后重置到 60 秒 |
| 安全 | 不打印验证码，不持久化验证码，不把完整手机号写日志 |

### 4.6 协议 Web 阅读页 UI 设计图

Plain text 设计图：

```text
┌──────────────────────────────────────┐
│  ×          阅读器可用          文档   │
│                                      │
│ 梦原鲸 隐私政策                       │
│ 生效日期：2026-07-16                  │
│                                      │
│ 欢迎使用梦原鲸（以下简称“本应用”）。    │
│ 我们重视您的个人信息与健康数据安全。    │
│                                      │
│ ┌────────────────────────────────┐  │
│ │ 重点提示：在 ZDKOpenChat 对话功能中 │  │
│ │ 您输入的内容会发送至 AI 服务提供方... │  │
│ └────────────────────────────────┘  │
│                                      │
│ 运营者信息                            │
│ • 企业名称：梦原鲸（苏州）科技服务有限公司│
│                                      │
│ 一、我们收集的数据类型                 │
│ 1. 账号与设备信息                     │
└──────────────────────────────────────┘
```

控件标注：

| 编号 | UI 元素 | HarmonyOS 组件 | 展示内容 | 行为 | 技术细节 |
| --- | --- | --- | --- | --- | --- |
| H-F1 | 关闭按钮 | `Button` | `X` | 返回上一层 | `pathStack.pop()` |
| H-F2 | 标题 | `Text` | `阅读器可用` 或协议标题 | 无 | 为贴近截图可显示 `阅读器可用` |
| H-F3 | 页面设置 | `Button` | 文档图标 | 首期可隐藏或打开系统浏览器 | 若无真实能力，不做假按钮 |
| H-F4 | Web 容器 | `Web` | 协议 HTML/URL | 加载协议内容 | 使用 `@kit.ArkWeb` 的 `webview.WebviewController` |
| H-F5 | 加载失败 | `Text` + `Button` | 加载失败/重试 | 重新加载 | Web 错误要可见 |

实现要点：

| 项 | 方案 |
| --- | --- |
| Web 能力 | 使用 ArkWeb `Web({ src, controller })`，支持 URL 或本地 HTML |
| 安全默认 | `fileAccess(false)`、`geolocationAccess(false)`，协议页不需要地理位置 |
| 深色模式 | 可使用自动深色适配，但协议正文需保证对比度 |
| 本地 demo 参考 | `ProtocolWebView.ets` 已演示 `WebviewController`、`loadUrl`、`loadData` 和关闭行为，可复用结构思路 |

### 4.7 ArkUI 伪代码骨架

以下为结构伪代码，用于约束实现边界，不作为可直接编译代码：

```ts
@Component
struct LoginPage {
  @State legalAccepted: boolean = false
  @State showLegalSheet: boolean = false
  @State pendingAction: AuthPendingAction = AuthPendingAction.None
  private stack: NavPathStack = new NavPathStack()

  build() {
    Navigation(this.stack) {
      Column() {
        AuthHeroIcon({ type: AuthHeroType.Shield })
        Text($r('app.string.auth_login_welcome'))
        Button($r('app.string.auth_login_huawei')) {
          this.ensureLegalAccepted(AuthPendingAction.Huawei)
        }
        this.separator()
        Button($r('app.string.auth_login_phone')) {
          this.ensureLegalAccepted(AuthPendingAction.Phone)
        }
        Button($r('app.string.auth_login_guest')) {
          this.ensureLegalAccepted(AuthPendingAction.Device)
        }
        LegalAgreementNote({
          accepted: this.legalAccepted,
          onTap: () => this.showLegalSheet = true
        })
      }
      .bindSheet($$this.showLegalSheet, this.legalSheetBuilder())
    }
  }
}
```

## 5. 接口契约与数据模型

### 5.1 UI 状态模型

| 字段 | 类型 | 归属 | 是否持久化 | 说明 |
| --- | --- | --- | --- | --- |
| `legalAccepted` | `boolean` | `LoginViewModel` | 是 | 用户是否同意当前协议版本 |
| `legalAcceptedVersion` | `string` | `LoginViewModel` | 是 | 协议版本，版本变化时重新提示 |
| `busy` | `boolean` | `LoginViewModel` | 否 | 当前是否有登录/发码/验证请求 |
| `errorText` | `string` | `LoginViewModel` | 否 | 页面错误提示 |
| `pendingAction` | enum | `LoginViewModel` | 否 | 未同意协议时保存原点击动作 |
| `selectedRegion` | `PhoneRegion` | `PhoneLoginPage` | 可选 | 最近选择地区，可非敏感持久化 |
| `phoneNumber` | `string` | `PhoneLoginPage` | 否 | 手机号输入，不长期保存 |
| `submittedPhone` | `string` | `OtpVerifyPage` | 否 | 发码成功后用于脱敏展示 |
| `otpId` | `string` | `OtpVerifyPage` | 否 | 后端发码标识 |
| `otpCode` | `string` | `OtpVerifyPage` | 否 | 用户输入验证码，禁止日志和持久化 |
| `countdown` | `number` | `OtpVerifyPage` | 否 | 重发倒计时 |
| `toastText` | `string` | 页面层 | 否 | 顶部通知 |

### 5.2 PhoneRegion 模型

```ts
export interface PhoneRegion {
  countryCode: string
  localizedName: string
  dialCode: string
  minLength: number
  maxLength: number
}
```

默认首屏地区：

| 国家/地区 | countryCode | dialCode |
| --- | --- | --- |
| 中国 | `CN` | `+86` |
| 中国香港 | `HK` | `+852` |
| 中国台湾 | `TW` | `+886` |
| 日本 | `JP` | `+81` |
| 韩国 | `KR` | `+82` |
| 中国澳门 | `MO` | `+853` |
| 新加坡 | `SG` | `+65` |
| 马来西亚 | `MY` | `+60` |
| 泰国 | `TH` | `+66` |
| 印度尼西亚 | `ID` | `+62` |
| 菲律宾 | `PH` | `+63` |
| 越南 | `VN` | `+84` |

### 5.3 UI 与接口动作

| 用户动作 | UI 前置条件 | 调用对象 | 入参 | 成功结果 | 失败结果 |
| --- | --- | --- | --- | --- | --- |
| 点击华为账号登录 | 已同意协议，未 busy | 待接 Account Kit + AuthAPI | Huawei 授权凭证 | 写入 Spark 会话 | 留在登录页，展示错误 |
| 点击游客模式 | 已同意协议，未 busy | `AuthAPI.deviceLogin` | `DeviceLoginRequest` | `sessionStore.enterSignedIn()` | 留在登录页，展示错误 |
| 点击获取验证码 | 手机号长度合法，未 busy | `OTPAPI.requestOtp` | `dialCode`、`phoneNumber` | 进入 OTP 页，展示成功通知 | 保留手机号页 |
| 点击重新发送 | `countdown=0` | `OTPAPI.requestOtp` | 同上 | 重置 `otpId` 和倒计时 | 保留 OTP 页 |
| 点击验证并登录 | `otpCode.length=6`，未 busy | `OTPAPI.verify` 或 `AuthAPI.phoneLogin` | `otpId`、`otpCode` | 写入 Spark 会话 | 清空或保留验证码按后端错误类型决定 |
| 点击服务条款 | 任意协议区域可见 | `LegalWebPage` | `termsUrl` | 打开协议阅读页 | 展示加载失败 |
| 点击隐私协议 | 任意协议区域可见 | `LegalWebPage` | `privacyUrl` | 打开协议阅读页 | 展示加载失败 |

### 5.4 敏感信息处理

| 数据 | 处理要求 |
| --- | --- |
| 手机号 | UI 展示 OTP 目标时只显示 `+86 153****20` 形式 |
| 验证码 | 不写日志、不持久化、不进入崩溃上下文 |
| OAuth 凭证 | 只在内存中换取后端会话，失败时清理 |
| Token | 继续由 `SecureTokenStore`/`AuthTokenProvider` 管理 |
| 协议确认 | 可持久化确认状态、协议版本、确认时间 |

## 6. iOS-HarmonyOS 功能对照矩阵

| UI 能力 | iOS 证据 | iOS 行为 | HarmonyOS 当前证据 | HarmonyOS 目标 | 对齐状态 |
| --- | --- | --- | --- | --- | --- |
| 登录首页 | `LoginView.swift`、Image #1 | Apple、手机号、游客、协议勾选 | `LoginPage.ets` + `LegalAgreementNote` | 华为账号、手机号、游客、协议区 | 部分对齐（华为占位） |
| 协议首次提示 | `LoginInitialLegalPromptContent`、Image #5 | 半屏提示，拒绝/同意，协议链接 | `LoginLegalPromptSheet.ets` + Preferences | 门禁后执行 pendingAction | 已验证对齐 |
| 手机号登录页 | `PhoneLoginView`、Image #3 | 地区 + 手机号 + 获取验证码 | `PhoneLoginPage.ets` + `RequestPhoneOTPUseCase` | 发码成功进 OTP | 已验证对齐 |
| 地区选择 | `PhoneRegions.swift`、Image #4 | 展开常用国家/地区 | `RegionPickerSheet.ets`、`PhoneRegion.ets` | 名称+区号（无旗帜） | 部分对齐 |
| 验证码输入 | `VerificationCodeField.swift`、Image #2 | 6 位格、倒计时、重发、验证 | `OtpVerifyPage.ets`、`OtpCodeInput.ets`、`SignInWithPhoneOTPUseCase` | 按钮提交，满 6 位才可点 | 已验证对齐 |
| 协议阅读器 | `SafariWebViewSheet.swift`、Image #6 | Safari 阅读页 | `LegalWebPage.ets` + 占位 HTTPS | 正式域名可替换 | 部分对齐 |
| 设备游客登录 | `signInWithDevice()` | 设备账号登录进入会话 | `LoginViewModel.signInWithDevice` | 保持现有链路 | 已验证对齐 |
| 华为账号登录 | iOS 对应 Apple 登录 | 平台账号授权登录 | 按钮可见，Toast「即将支持」 | 接 Account Kit 与后端换票 | 待确认 |

矩阵同步要求：全局 `iOS-HarmonyOS功能对照矩阵.md`「会话与认证 UI 设计图」行已与本方案同步。

## 7. 示例工程与官方文档参考结论

### 7.1 本地 demo 参考

| 示例 | 路径 | 可参考内容 | 不可直接照搬内容 |
| --- | --- | --- | --- |
| aggregated_login 登录页 | `Package/Huawei/agc-template-market-harmonyos-demos-main/LifestyleAndServiceTemplate/GovernmentService/Application/components/aggregated_login/src/main/ets/components/OtherLoginPage.ets` | 手机号输入、验证码输入、获取验证码按钮、loading、协议勾选区组合方式 | 模板样式、模拟登录跳转、业务 API、资源命名 |
| aggregated_login 协议勾选 | `.../components/AgreePrivacyBox.ets` | `Checkbox` + 富文本协议链接 + 路由打开协议页 | demo 中日志输出和模板路由依赖 |
| aggregated_login ViewModel | `.../viewmodel/AggregatedLoginVM.ets` | 验证码倒计时、手机号校验、loading 状态拆分 | 硬编码 App ID、模拟验证码、模板后端 |
| aggregated_login Sheet | `.../utils/LoginSheetUtils.ets` | `bindSheet`/半屏登录弹层参数、拖拽条、sheet 高度变化监听 | demo 的 `PopViewUtils` 与模板 Navigation 封装 |
| aggregated_login WebView | `.../views/ProtocolWebView.ets` | ArkWeb `WebviewController`、`loadUrl`、`loadData`、禁用文件/定位访问 | demo 的页面参数结构和协议 HTML 来源 |

### 7.2 官方文档参考

| 能力 | 官方文档 | 结论 |
| --- | --- | --- |
| Navigation | `https://developer.huawei.com/consumer/cn/doc/harmonyos-references/ts-basic-components-navigation` | 登录、手机号、OTP、协议 Web 页统一用 `Navigation`/`NavPathStack` 管理 |
| TextInput | `https://developer.huawei.com/consumer/cn/doc/harmonyos-references/ts-basic-components-textinput` | 手机号和验证码底层输入使用 `TextInput`，通过 `type`、`maxLength`、`onChange` 控制输入 |
| Button | `https://developer.huawei.com/consumer/cn/doc/harmonyos-references/ts-basic-components-button` | 主按钮、次按钮、圆形返回按钮使用 `Button` |
| Checkbox | `https://developer.huawei.com/consumer/cn/doc/harmonyos-references/ts-basic-components-checkboxgroup` | 协议同意状态使用 `Checkbox` 或独立复选组件 |
| bindSheet | `https://developer.huawei.com/consumer/cn/doc/harmonyos-references/ts-universal-attributes-sheet-transition` | 首次协议提示和地区选择可用半屏弹层承载 |
| Web | `https://developer.huawei.com/consumer/cn/doc/harmonyos-references/ts-basic-components-web` | 服务条款和隐私协议阅读页使用 ArkWeb |
| Account Kit | `https://developer.huawei.com/consumer/cn/doc/harmonyos-references-v5/account-api-component-manager-V5` | 华为账号登录入口需要接账号组件和后端换票接口，不能只做 UI |

### 7.3 与 demo 的设计差异

| 点 | demo 形态 | SupportClientHuawei 方案 |
| --- | --- | --- |
| 登录入口 | 聚合登录，手机号/华为/微信混合 | 只保留产品确认的华为账号、手机号、游客 |
| 协议形态 | 勾选框 + 协议页 | 增加首次半屏提示，匹配 iOS 截图 |
| OTP 输入 | 普通验证码输入框 | 6 个独立视觉格，截图级还原 |
| WebView | 可加载 HTML 或 URL | 仅加载服务条款/隐私协议，禁用不需要的权限 |
| 状态管理 | demo VM 直接控制模板登录 | `LoginViewModel` 调用项目 `AppContainer` 和真实 API |

## 8. 实施拆分与验收

### 8.1 实施拆分

| 阶段 | 交付 | 主要文件 | 验收 |
| --- | --- | --- | --- |
| P0 | 资源和状态模型 | `AuthUiState.ets`、`PhoneRegion.ets`、`string.json` | 文案可资源化，地区列表完整 |
| P1 | 登录首页重构 | `LoginPage.ets`、`AuthHeroIcon.ets`、`LegalAgreementNote.ets` | Image #1 结构一致 |
| P2 | 协议半屏 | `LoginLegalPromptSheet.ets` | Image #5 结构一致，按钮行为正确 |
| P3 | 手机号页 | `PhoneLoginPage.ets`、`RegionPickerSheet.ets` | Image #3/#4 结构一致 |
| P4 | OTP 页 | `OtpVerifyPage.ets`、`OtpCodeInput.ets`、`AuthToast.ets` | Image #2 结构一致，倒计时正确 |
| P5 | 协议 Web | `LegalWebPage.ets` | Image #6 结构近似，Web 加载和关闭正常 |
| P6 | 业务接线 | `LoginViewModel.ets`、`AppContainer` 调用 | 发码、验证、游客登录进入会话 |
| P7 | 测试和验收 | UI 单测/集成测试/真机走查 | 门禁、错误、键盘、倒计时、隐私链接通过 |

### 8.2 截图一致性验收

| 页面 | 必须出现的 UI |
| --- | --- |
| 登录首页 | `登录` 标题、盾牌图标、欢迎文案、华为账号登录、`或` 分隔线、手机号登录、游客模式、协议勾选区 |
| 协议半屏 | 灰色遮罩、拖拽条、`温馨提示`、服务条款、隐私协议、健康免责声明、权限说明、`不同意`、`同意并继续` |
| 手机号页 | 圆形返回、`手机号登录` 标题、电话图标、`安全快速登录`、手机号输入、地区选择、`获取验证码` |
| 地区选择 | 常用地区首屏包含中国、中国香港、中国台湾、日本、韩国、中国澳门、新加坡、马来西亚、泰国、印度尼西亚、菲律宾、越南 |
| OTP 页 | `验证码已发送` 顶部通知、`输入 6 位验证码`、脱敏手机号、6 个验证码格、`重新发送 59s`、安全提示、`验证并登录` |
| 协议 Web | 关闭按钮、顶部标题、协议正文标题、生效日期、重点提示、运营者信息、数据类型章节 |

### 8.3 交互验收

| 场景 | 验收标准 |
| --- | --- |
| 未同意协议点击登录入口 | 不发起任何网络请求，只展示协议半屏 |
| 点击同意并继续 | 协议状态持久化，执行原点击动作或解锁入口 |
| 点击不同意 | 半屏关闭，协议保持未同意，入口继续门禁 |
| 手机号不足 6 位 | `获取验证码` 禁用 |
| 发码成功 | 进入 OTP 页，展示成功通知，倒计时从 60 开始 |
| 重发倒计时中 | `重新发送` 不可点击 |
| 验证码不足 6 位 | `验证并登录` 不提交 |
| 验证成功 | 写入 token/session，进入已登录态 |
| 验证失败 | 不写 session，保留在 OTP 页并展示错误 |
| Web 加载失败 | 展示错误和重试，不白屏 |

### 8.4 测试建议

| 测试类型 | 覆盖点 |
| --- | --- |
| ViewModel 单测 | 协议门禁、手机号校验、倒计时、验证码提交条件 |
| API mock 测试 | request OTP 成功/失败、verify 成功/失败、device login 失败 |
| UI 走查 | 键盘弹出后按钮不被遮挡、半屏高度、地区列表滚动 |
| 安全检查 | 日志不包含完整手机号、验证码、OAuth 凭证 |
| 多语言检查 | 中文、英文资源缺失时不崩溃 |

## 9. 风险与待确认项

| 风险/待确认 | 影响 | 建议处理 |
| --- | --- | --- |
| 华为账号登录后端接口未确认 | UI 可做但无法完成真实登录 | 先用 Feature Flag 控制入口；后端确认后再开放 |
| 是否完全移除 Apple 登录 | 影响跨平台账号一致性 | 产品确认华为端是否保留 Apple 登录；默认不展示 |
| `InputType.PhoneNumber` 枚举和 API 版本 | 编译风险 | 实现前按当前 HarmonyOS SDK 校验枚举名称 |
| `bindSheet` 关闭策略 | 合规风险 | 首次协议弹窗建议不同意/同意显式关闭，不依赖遮罩关闭 |
| 地区旗帜显示 | 资源与字体兼容风险 | 首期可只显示国家/地区名和区号，旗帜作为增强 |
| WebView 协议 URL | 上线风险 | 确认服务条款/隐私协议正式 URL、ICP备案、HTTPS 证书 |
| OTP 自动提交 | 误触和重复请求风险 | 首期使用按钮提交；如要满 6 位自动提交，必须加防抖 |
| demo 代码质量 | 误拷贝风险 | 只参考 UI 形态和组件模式，不拷贝模拟登录、硬编码 App ID、模板路由 |
| 医疗免责声明文案 | 合规风险 | 与法务/产品确认最终版本，避免端侧与网页协议不一致 |

