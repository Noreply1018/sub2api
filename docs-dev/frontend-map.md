# 前端模块地图

前端是 Vue 3 + TypeScript + Vite + Pinia + Axios + pnpm。核心代码在 `frontend/src/`。

## 入口

```text
frontend/src/main.ts
frontend/src/App.vue
frontend/src/router/index.ts
frontend/src/api/client.ts
frontend/src/stores/
```

`api/client.ts` 默认 base URL 是：

```text
/api/v1
```

除非通过 `VITE_API_BASE_URL` 覆盖。

## API client

核心文件：

```text
frontend/src/api/client.ts
frontend/src/api/index.ts
frontend/src/api/admin/
```

Axios request interceptor 会：

- 从 localStorage 读取 `auth_token` 并设置 `Authorization: Bearer ...`
- 设置 `Accept-Language`
- 给 GET 请求附加用户时区参数

Axios response interceptor 会：

- 解包后端标准响应 `{ code, message, data }`
- 遇到 401 时用 `refresh_token` 调 `/auth/refresh`
- 处理 ops monitoring disabled 的特殊 404
- 把 API error 归一成前端可处理对象

## Store

| Store | 文件 | 说明 |
| --- | --- | --- |
| Auth | `stores/auth.ts` | 登录态、token、refresh token、当前用户、管理员判断 |
| App | `stores/app.ts` | 全局 UI 状态、toast、公共设置、版本信息 |
| AdminSettings | `stores/adminSettings.ts` | 管理端设置缓存，控制 ops/payment/custom menu 等 UI |
| Announcements | `stores/announcements.ts` | 公告读取和弹窗状态 |
| Subscriptions | `stores/subscriptions.ts` | 用户订阅状态 |
| Payment | `stores/payment.ts` | 支付流程相关状态 |
| Onboarding | `stores/onboarding.ts` | 引导流程 |

## Router

路由定义在：

```text
frontend/src/router/index.ts
```

主要分组：

| 页面 | 路由 |
| --- | --- |
| setup | `/setup` |
| 登录注册 | `/login`、`/register`、`/forgot-password`、`/reset-password` |
| OAuth callback | `/auth/*/callback` |
| 用户首页 | `/dashboard` |
| API Key | `/keys` |
| 用户 usage | `/usage` |
| 可用渠道 | `/available-channels` |
| 用户资料 | `/profile` |
| 订阅和支付 | `/subscriptions`、`/purchase`、`/orders`、`/payment/*` |
| 管理首页 | `/admin/dashboard` |
| 管理用户 | `/admin/users` |
| 管理分组 | `/admin/groups` |
| 管理渠道 | `/admin/channels`、`/admin/channels/monitor` |
| 管理账号 | `/admin/accounts` |
| 管理设置 | `/admin/settings` |
| 管理 usage | `/admin/usage` |
| 风控 | `/admin/risk-control` |
| 支付管理 | `/admin/orders/*` |

路由 meta 中的 `requiresAuth` 和 `requiresAdmin` 决定导航守卫是否允许进入。

## 页面和 API 对应

| 前端区域 | 页面/组件 | API 模块 |
| --- | --- | --- |
| 登录注册 | `views/auth/` | `api/auth.ts` |
| 用户 API Key | `views/user/KeysView.vue`、`components/keys/` | `api/keys.ts` |
| 用户 usage | `views/user/UsageView.vue`、`views/KeyUsageView.vue` | `api/usage.ts` |
| 用户资料 | `views/user/ProfileView.vue`、`components/user/profile/` | `api/user.ts`、`api/totp.ts` |
| 用户订阅支付 | `views/user/SubscriptionsView.vue`、`views/user/Payment*` | `api/subscriptions.ts`、`api/payment.ts` |
| 管理账号 | `views/admin/AccountsView.vue`、`components/account/` | `api/admin/accounts.ts`、OAuth 相关 admin API |
| 管理分组 | `views/admin/GroupsView.vue` | `api/admin/groups.ts` |
| 管理渠道 | `views/admin/ChannelsView.vue` | `api/admin/channels.ts` |
| 管理用户 | `views/admin/UsersView.vue` | `api/admin/users.ts` |
| 管理设置 | `views/admin/SettingsView.vue` | `api/admin/settings.ts` |
| 管理 usage | `views/admin/UsageView.vue` | `api/admin/usage.ts` |
| 运维监控 | `views/admin/ops/` | `api/admin/ops.ts` |
| 支付管理 | `views/admin/orders/` | `api/admin/payment.ts` |

## i18n

语言文件：

```text
frontend/src/i18n/locales/zh.ts
frontend/src/i18n/locales/en.ts
```

新增前端文案时，应优先加 i18n key，而不是在页面里硬编码多语言文案。

## 二开注意事项

- 前端必须用 `pnpm`，改 `package.json` 后同步 `pnpm-lock.yaml`。
- API 返回值经过 `apiClient` 解包后，业务代码通常直接拿到 `data`。
- 登录态存在 localStorage，字段包括 `auth_token`、`refresh_token`、`auth_user`、`token_expires_at`。
- 管理端菜单和可见功能受后端 public settings / admin settings 影响。
- 构建产物会写入后端 dist 目录，提交前注意区分源码改动和生成产物。
