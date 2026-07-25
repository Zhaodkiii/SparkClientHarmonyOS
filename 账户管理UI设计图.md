# SupportClientHuawei｜账户管理 UI 设计图

> 本文档是账户管理模块的 UI 设计图与交互标注，服务于 HarmonyOS/ArkUI 实现与验收。业务接口、字段级契约、Repository、UseCase 和状态机以 `开发详细技术文档/设置与账户管理/账户管理详细技术方案.md` 为准。本文不包含可直接复制的 ArkTS 生产代码。

## 1. 对标范围与结论

### 1.1 输入与证据

| 类型 | 路径/资料 | 用途 |
| --- | --- | --- |
| iOS 账户管理页面 | `SupportClient/SupportClient/Projects/Features/AccountManagement/Presentation/AccountManagementView.swift` | 主页面结构、资料卡、身份列表、退出登录、注销入口 |
| iOS 账户管理组件 | `SupportClient/SupportClient/Projects/Features/AccountManagement/Presentation/Components/AccountManagementComponents.swift` | 资料卡、信息行、验证方式卡片、OTP 卡片、结果卡片 |
| iOS 账户管理状态 | `AccountManagementViewModel.swift`、`AccountDeactivationFlowState.swift`、`AccountIdentityModels.swift` | 绑定/换绑、注销、OTP、Apple 再认证的状态来源 |
| HarmonyOS 当前实现 | `SupportClientHuawei/entry/src/main/ets/Projects/Features/Settings/SettingsPage.ets`、`Projects/Features/AccountManagement/AccountPlaceholderPage.ets` | 当前只有设置入口、升级登录 sheet、退出登录和账户占位页 |
| HarmonyOS API 底座 | `Projects/Core/Networking/API/Account/AccountIdentityAPI.ets`、`DeactivationAPI.ets`、`Auth/OTPAPI.ets` | 身份列表、身份验证、绑定/换绑、注销 API 已有基础封装 |
| 技术方案 | `SupportClientHuawei/开发详细技术文档/设置与账户管理/账户管理详细技术方案.md` | 华为端目录、接口、风险和验收基线 |

### 1.2 当前结论

华为端账户管理 UI 目前仍是 `AccountPlaceholderPage.ets` 占位。目标 UI 应按 iOS 的信息层级对齐，但不复制 iOS 组件名称或 Apple 专属能力：

- `Apple 登录` 在 HarmonyOS 设计中标记为 `Huawei 账号` 或后端确认的 provider。
- 手机号、邮箱、Huawei 账号三类身份必须共用同一“再验证 → 目标输入/授权 → 提交”的高风险流程。
- 注销必须使用独立危险区、身份验证和最终确认短语，不能只用一个普通确认弹窗完成。
- OTP、verification ticket、identity token 等敏感信息只在内存状态中存在，不进入页面文案、日志、Preferences 或截图。

## 2. 页面地图

```text
SettingsPage
└── AccountManagementPage
    ├── 账户资料主页面
    │   ├── AccountProfileCard
    │   ├── AccountInfoSection
    │   ├── AccountIdentitySection
    │   ├── SessionSection
    │   └── DangerSection
    ├── 身份绑定/换绑浮层
    │   ├── 再验证方式选择
    │   ├── 再验证 OTP / Huawei 授权
    │   ├── 新目标输入
    │   ├── 新目标 OTP
    │   └── 完成/失败
    └── 账号注销浮层
        ├── 注销验证方式选择
        ├── 注销 OTP / Huawei 授权
        ├── 最终确认短语
        ├── 提交中
        └── 失败
```

## 3. 账户管理主页面

### 3.1 主页面线框图

```text
┌──────────────────────────────────────┐
│ ←            账户管理                 │
├──────────────────────────────────────┤
│                                      │
│  ┌────────────────────────────────┐  │
│  │           ● 头像                │  │
│  │        王小鲸 / user@mail.com   │  │
│  │        手机号验证码 / Huawei账号 │  │
│  └────────────────────────────────┘  │
│                                      │
│  账户信息                             │
│  ┌────────────────────────────────┐  │
│  │ ▣ 账号 ID                10086 │  │
│  │ ▣ 手机/邮箱        138****1234 │  │
│  │ ▣ 登录方式          手机号验证码 │  │
│  │ ▣ 登录时间       2026-07-18... │  │
│  └────────────────────────────────┘  │
│                                      │
│  登录方式                             │
│  ┌────────────────────────────────┐  │
│  │ ☎ 手机号   138****1234   修改 › │  │
│  │ ✉ 邮箱     未绑定        绑定 › │  │
│  │ H Huawei   已绑定        修改 › │  │
│  └────────────────────────────────┘  │
│                                      │
│  会话                                │
│  ┌────────────────────────────────┐  │
│  │ ⎋ 退出登录                      │  │
│  │    仅清除本机登录状态             │  │
│  └────────────────────────────────┘  │
│                                      │
│  危险操作                             │
│  ┌────────────────────────────────┐  │
│  │ 注销将停用账号并处理相关数据       │  │
│  │ 高级选项 展开/收起                │  │
│  │ 🗑 注销账号                ›     │  │
│  └────────────────────────────────┘  │
└──────────────────────────────────────┘
```

### 3.2 主页面组件标注

| 编号 | UI 元素 | ArkUI 建议组件 | 数据来源 | 交互 | 状态 |
| --- | --- | --- | --- | --- | --- |
| A1 | 标题栏 | `Navigation` / `NavDestination.title` | 固定文案 `account_title` | 返回设置页 | 已有占位页 title，可复用 |
| A2 | 头像圆形 | `Stack` + `Circle` + `Text/Image` | `AccountProfile.displayName/contact` | 无 | 待实现 |
| A3 | 昵称/联系方式 | `Text` | `UserSession.displayName`，空则 `contact` | 无 | 待实现 |
| A4 | 登录方式摘要 | `Text` | `AccountProfile.signInMethodDescription` | 无 | 待实现 |
| A5 | 账户信息区 | `Column` + `Row` | `AccountProfile` | 无 | 待实现 |
| A6 | 身份列表区 | `List` / `Column` + `ForEach` | `AccountIdentityList.identities` | 绑定/修改 | 待实现 |
| A7 | 退出登录区 | `Button` + `Row` | `SignOutUseCase` | 打开确认弹窗 | 设置页已有直接退出，需移入账号页并补确认 |
| A8 | 危险操作区 | `Column` + `Button` + `Toggle`/`Stepper` 替代控件 | `AccountDeactivationOptions` | 展开高级选项、进入注销 | 待实现 |

### 3.3 主页面视觉规则

| 项 | 规则 |
| --- | --- |
| 背景 | 使用浅灰页面背景；内容卡片白底，卡片圆角 12vp，间距 16vp |
| 卡片 | 不嵌套卡片；每个区块只用一个白底容器 |
| 图标 | 使用圆角方形色块承载图标：账号蓝、手机号绿、邮箱红、登录方式紫、时间橙、危险红 |
| 文案 | 右侧长字段最多 2 行；手机号/邮箱只显示脱敏值 |
| loading | 资料和身份列表可分别显示 `LoadingProgress`，不阻塞整页滚动 |
| 错误 | 资料/身份列表加载失败使用顶部 banner 或 alert；不展示后端原始敏感 message |

## 4. 设置页账户入口

### 4.1 设置入口线框图

```text
┌──────────────────────────────────────┐
│              设置                    │
├──────────────────────────────────────┤
│  账户                                │
│  ┌────────────────────────────────┐  │
│  │ 👤 账户管理        王小鲸 / 未登录 › │
│  └────────────────────────────────┘  │
│                                      │
│  AI                                  │
│  ┌────────────────────────────────┐  │
│  │ ◇ AI 场景             模型与能力 › │
│  └────────────────────────────────┘  │
└──────────────────────────────────────┘
```

### 4.2 分流规则

| 当前会话 | 右侧摘要 | 点击行为 |
| --- | --- | --- |
| `signedOut` | 未登录 | 进入登录页或打开登录 sheet |
| `isDeviceAccount=true` | 未登录 / 游客模式 | 打开升级登录 sheet |
| 正式账号 | `displayName`，为空则 `contact` | push `AccountManagementPage` |
| 会话恢复中 | 加载中 | 禁用点击 |

当前 `SettingsPage.ets` 已有账户入口、升级登录入口和退出登录入口。目标实现应把“升级登录”合并为账户入口的游客分支，避免设置页出现两个相近入口。

## 5. 登录身份列表与操作

### 5.1 身份行设计

```text
┌──────────────────────────────────────┐
│ 登录方式                              │
│ ┌──────────────────────────────────┐ │
│ │ ☎ 手机号                         │ │
│ │   138****1234              修改 › │ │
│ ├──────────────────────────────────┤ │
│ │ ✉ 邮箱                           │ │
│ │   未绑定                    绑定 › │ │
│ ├──────────────────────────────────┤ │
│ │ H Huawei 账号                    │ │
│ │   已绑定                    修改 › │ │
│ └──────────────────────────────────┘ │
└──────────────────────────────────────┘
```

### 5.2 身份行状态

| provider | `bound` | `bindable` | `modifiable` | 主按钮 | 辅助文案 |
| --- | --- | --- | --- | --- | --- |
| phone/email/huawei | true | 任意 | true | 修改 | 显示 `maskedValue` |
| phone/email/huawei | true | 任意 | false | 已绑定 | 显示 `maskedValue`，按钮禁用 |
| phone/email/huawei | false | true | 任意 | 绑定 | 显示未绑定 |
| phone/email/huawei | false | false | 任意 | 不可用 | 显示服务端限制文案 |

未知 provider 不进入 UI 列表，但需要在脱敏日志中记录 provider 名称和 requestId，便于后端契约收敛。

## 6. 绑定/换绑流程 UI

### 6.1 再验证方式选择

```text
┌────────────── 半透明遮罩 ──────────────┐
│                                      │
│      ┌────────────────────────┐      │
│      │ 🛡 安全验证              │      │
│      │ 修改登录方式前，请先验证   │      │
│      │                        │      │
│      │ ☎ 手机短信  138****1234 › │      │
│      │ ✉ 邮箱验证  a***@xx.com › │      │
│      │ H Huawei账号             › │      │
│      │                        │      │
│      │                  取消    │      │
│      └────────────────────────┘      │
└──────────────────────────────────────┘
```

| 元素 | 组件 | 规则 |
| --- | --- | --- |
| 遮罩 | `Stack` + 半透明背景，或 `CustomDialog` | 只有选择再验证阶段点击遮罩可取消 |
| 验证方式行 | `Button` / `Row` | 只展示已绑定身份；手机号/邮箱必须脱敏 |
| Huawei 授权 | `Button` | 等待后端与 Account Kit 契约确认；未确认时不展示或标记即将支持 |

### 6.2 再验证 OTP

```text
┌────────────── 半透明遮罩 ──────────────┐
│      ┌────────────────────────┐      │
│      │ ‹                      │      │
│      │       身份安全验证       │      │
│      │   请输入收到的 6 位验证码 │      │
│      │   验证码已发送至 138**** │      │
│      │                        │      │
│      │   [1] [2] [3] [ ] [ ] [ ]│      │
│      │                        │      │
│      │   58 秒后可重新发送       │      │
│      └────────────────────────┘      │
└──────────────────────────────────────┘
```

规则：

- OTP 输入满 6 位后才允许提交；可自动提交，也可显示主按钮，需与认证 OTP 体验保持一致。
- 输入错误时清空 code，保留当前 `otpId` 和倒计时。
- 倒计时结束后展示“重新发送”；重复点击期间显示 loading。
- 键盘弹出时卡片上移，输入格不得被遮挡。

### 6.3 新目标输入

```text
┌────────────── 半透明遮罩 ──────────────┐
│      ┌────────────────────────┐      │
│      │ ‹                      │      │
│      │       绑定邮箱          │      │
│      │ 请输入新的邮箱地址        │      │
│      │                        │      │
│      │ ┌────────────────────┐ │      │
│      │ │ name@example.com   │ │      │
│      │ └────────────────────┘ │      │
│      │                        │      │
│      │       发送验证码         │      │
│      └────────────────────────┘      │
└──────────────────────────────────────┘
```

手机号输入复用认证模块的地区选择与 E.164 归一化；邮箱输入使用 normalized email。目标 OTP 发送成功后冻结目标快照，后续重发、提交都使用冻结值，避免用户编辑后验证码和目标错位。

### 6.4 完成态与失败态

```text
┌────────────── 半透明遮罩 ──────────────┐
│      ┌────────────────────────┐      │
│      │          ✓             │      │
│      │       绑定成功          │      │
│      │  已更新你的登录方式       │      │
│      │                        │      │
│      │          完成            │      │
│      └────────────────────────┘      │
└──────────────────────────────────────┘
```

失败态显示可读错误和两个动作：`重试`、`取消`。禁止展示 OTP code、verification ticket、identity token、完整手机号、完整邮箱或原始后端堆栈。

## 7. 注销账号流程 UI

### 7.1 危险区展开

```text
┌──────────────────────────────────────┐
│ 危险操作                              │
│ ┌──────────────────────────────────┐ │
│ │ 注销账号将停用账号，相关数据按服务端 │ │
│ │ 策略删除或匿名化。                  │ │
│ │                                  │ │
│ │ 高级选项                  展开⌄   │ │
│ │                                  │ │
│ │ [x] 立即注销                      │ │
│ │ [x] 匿名化个人数据                  │ │
│ │ [x] 删除关联数据                    │ │
│ │ 数据保留期       [-] 30 天 [+]      │ │
│ │ 原因（可选）                       │ │
│ │ ┌──────────────────────────────┐ │ │
│ │ └──────────────────────────────┘ │ │
│ │                                  │ │
│ │ 🗑 注销账号                   ›   │ │
│ └──────────────────────────────────┘ │
└──────────────────────────────────────┘
```

高级选项默认收起；普通用户只看到注销说明和注销入口。展开后才显示倒计时、匿名化、关联数据删除、保留期和原因。

### 7.2 注销验证方式选择

与身份绑定的“再验证方式选择”视觉一致，但标题和说明必须强调注销风险：

```text
┌────────────── 半透明遮罩 ──────────────┐
│      ┌────────────────────────┐      │
│      │ ⚠ 注销账号验证           │      │
│      │ 注销前需要确认你的身份     │      │
│      │                        │      │
│      │ ☎ 手机短信  138****1234 › │      │
│      │ ✉ 邮箱验证  a***@xx.com › │      │
│      │ H Huawei账号             › │      │
│      │                        │      │
│      │                  取消    │      │
│      └────────────────────────┘      │
└──────────────────────────────────────┘
```

### 7.3 最终确认短语

```text
┌────────────── 半透明遮罩 ──────────────┐
│      ┌────────────────────────┐      │
│      │       确认注销账号       │      │
│      │ 注销后将：               │      │
│      │ • 停用当前账号            │      │
│      │ • 清理身份、设备和同步状态 │      │
│      │ • 删除或匿名化相关数据     │      │
│      │                        │      │
│      │ 请输入：删除我的账户       │      │
│      │ ┌────────────────────┐ │      │
│      │ └────────────────────┘ │      │
│      │                        │      │
│      │ 取消       确认注销      │      │
│      └────────────────────────┘      │
└──────────────────────────────────────┘
```

规则：

- 确认按钮只有在输入完全匹配 `删除我的账户` 时可用。
- 文案必须本地资源化，英文环境需要使用对应英文确认短语，不能混用中文。
- 提交中禁用关闭、返回和重复点击。
- 成功后不展示“注销成功继续使用”，必须清理会话并回到未登录态。

## 8. 错误、空态和加载态

| 场景 | UI 表现 | 操作 |
| --- | --- | --- |
| 资料加载中 | 资料卡位置显示 loading | 无 |
| 身份列表加载中 | 身份列表位置显示 loading | 无 |
| 身份列表为空 | 显示“暂无可管理的登录方式” | 可重试 |
| 网络断开 | 顶部 banner 或页面错误行 | 重试 |
| 401 明确失效 | 清空账户页栈，回登录态 | 不在账户页弹复杂错误 |
| OTP 错误 | OTP 卡片下方提示，清空输入 | 重新输入 |
| ticket 过期 | 失败卡片提示重新验证 | 返回验证方式选择 |
| 注销提交失败 | 注销失败卡片 | 重新提交或取消 |
| 登出失败 | 弹窗/通知提示 | 允许重试；是否本地 signedOut 以认证方案为准 |

## 9. ArkUI 组件与官方资料

| 能力 | 官方资料 | 本文用途 | 注意 |
| --- | --- | --- | --- |
| Navigation / NavPathStack | [Navigation - 文档中心](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides-V5/arkts-navigation-navigation-0000001885999037-V5) | 设置页 push 账户管理页、二级页面返回 | 需按目标 SDK/API 24 复核 |
| 半模态 bindSheet | [Binding a Modal Sheet (bindSheet)](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/arkts-sheet-page) | 游客升级登录、可选底部输入/选择容器 | 账号高风险流程更建议遮罩卡片或 CustomDialog |
| 弹窗 showDialog / PromptAction | [Class (PromptAction)](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/arkts-apis-uicontext-promptaction)、[弹出框概述](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/arkts-base-dialog-overview) | 退出登录确认、错误提示、最终确认承载 | 高风险注销建议自定义内容，不用一句确认替代完整确认页 |
| 自定义弹窗 | [自定义弹窗(CustomDialog)](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/ts-methods-custom-dialog-box) | 验证方式、OTP、注销确认卡片 | 注意生命周期、焦点和返回键处理 |
| Checkbox | [Checkbox多选和反选功能实现](https://developer.huawei.com/consumer/cn/doc/harmonyos-faqs/faqs-arkui-1505) | 注销高级选项、协议类二值控件参考 | 敏感选项状态只在内存或非敏感配置中保存 |

## 10. 本地 HarmonyOS 示例参考

| 示例 | 绝对路径 | 可借鉴 | 禁止复制 |
| --- | --- | --- | --- |
| 登录半屏状态管理 | `/Users/hua/Documents/project/Reference/ClientSub-project/SparkAndroid/Package/Huawei/agc-template-market-harmonyos-demos-main/HouseAndHomeTemplate/RentAndBuy/components/aggregated_login/src/main/ets/viewmodel/AggregatedLoginVM.ets` | 登录/升级登录 sheet 的局部状态管理 | 第三方 SDK、AppId、示例账号、硬编码业务文案 |
| LoginSheetUtils | `/Users/hua/Documents/project/Reference/ClientSub-project/SparkAndroid/Package/Huawei/agc-template-market-harmonyos-demos-main/ShoppingTemplate/Express/components/aggregated_login/src/main/ets/utils/LoginSheetUtils.ets` | 半屏登录容器的打开/关闭思路 | 不作为账户管理全局路由器 |
| 网络拦截器链 | `/Users/hua/Documents/project/Reference/ClientSub-project/SparkAndroid/Package/Huawei/agc-template-market-harmonyos-demos-main/MovieTVAndLivestreamingTemplate/LiveStreaming/commons/utils/src/main/ets/network/interceptor/` | API 请求统一经过底层网络、日志、JSON 解码 | MockAdapter、完整 header/body/response 日志 |
| Token 刷新示例 | `/Users/hua/Documents/project/Reference/ClientSub-project/SparkAndroid/Package/Huawei/agc-template-market-harmonyos-demos-main/MovieTVAndLivestreamingTemplate/LiveStreaming/commons/server/src/main/ets/handler/interceptor/TokenRefreshInterceptor.ts` | 高风险 API 401 后刷新一次再重放的边界 | 不完整单飞和安全存储策略 |

## 11. 资源键建议

| key | 中文 | 英文建议 | 用途 |
| --- | --- | --- | --- |
| `account_title` | 账户管理 | Account Management | 页面标题，现有 |
| `account_profile_loading` | 正在加载账户资料 | Loading account profile | 资料 loading |
| `account_identity_loading` | 正在加载登录方式 | Loading sign-in methods | 身份 loading |
| `account_section_info` | 账户信息 | Account Info | 区块标题 |
| `account_section_identity` | 登录方式 | Sign-in Methods | 区块标题 |
| `account_section_session` | 会话 | Session | 区块标题 |
| `account_section_danger` | 危险操作 | Danger Zone | 区块标题 |
| `account_field_id` | 账号 ID | Account ID | 信息行 |
| `account_field_contact` | 联系方式 | Contact | 信息行 |
| `account_field_signin_method` | 登录方式 | Sign-in Method | 信息行 |
| `account_field_signin_time` | 登录时间 | Sign-in Time | 信息行 |
| `account_identity_bind` | 绑定 | Bind | 身份行按钮 |
| `account_identity_change` | 修改 | Change | 身份行按钮 |
| `account_identity_unbound` | 未绑定 | Not bound | 身份行文案 |
| `account_verify_security_title` | 安全验证 | Security Verification | 再验证标题 |
| `account_otp_resend` | 重新发送 | Resend | OTP |
| `account_sign_out` | 退出登录 | Sign Out | 会话区 |
| `account_sign_out_confirm_title` | 确认退出登录 | Sign out? | 确认弹窗 |
| `account_deactivation_title` | 注销账号 | Deactivate Account | 危险区 |
| `account_deactivation_confirm_phrase` | 删除我的账户 | Delete my account | 最终确认短语 |
| `account_deactivation_submit` | 确认注销 | Confirm Deactivation | 最终按钮 |

所有 key 必须在 `base`、`zh_CN`、`en_US` 中齐全。缺任一基线资源属于构建阻断项。

## 12. 验收清单

- [ ] 设置页账户入口按 signedOut、游客、正式账号三种状态分流。
- [ ] 账户主页面包含资料卡、账户信息、登录方式、会话、危险操作五个区块。
- [ ] 所有手机号、邮箱只展示脱敏值；OTP、ticket、token 不出现在 UI 文案和日志。
- [ ] 身份绑定/换绑必须经过再验证，且目标 OTP 使用冻结目标快照。
- [ ] 注销必须经过验证方式选择、OTP/Huawei 授权、最终确认短语和提交中状态。
- [ ] 退出登录必须有确认弹窗，并清理设置/账户本地导航栈。
- [ ] 账号切换、登出、401 失效后账户页旧异步结果不得回写当前 UI。
- [ ] 页面在窄屏、键盘弹出、英文长文案下不遮挡、不溢出。
- [ ] UI 自动化或单元测试覆盖：入口分流、身份行按钮状态、OTP 输入、注销确认短语、退出登录确认。

## 13. 待确认项

| 编号 | 待确认项 | 影响 |
| --- | --- | --- |
| UI-R1 | HarmonyOS provider 是否采用 `huawei`，以及后端凭证字段是什么 | Huawei 账号绑定/换绑/注销验证 |
| UI-R2 | 注销最终确认短语英文环境是否固定为 `Delete my account` | 国际化与验收 |
| UI-R3 | 退出登录失败时是否仍强制进入 signedOut | 设置页与账户页会话清理 |
| UI-R4 | 后端是否返回注销状态查询或取消能力 | 是否需要增加“注销进度/撤销注销”UI |
| UI-R5 | 邮箱注销 OTP scene 是否应从 iOS 的 `login` 改为 `account_deactivation` | 注销验证一致性 |
