# 核心数据模型

数据模型主要由 Ent schema 定义：

```text
backend/ent/schema/
```

数据库迁移脚本在：

```text
backend/migrations/
```

## 核心关系图

```text
User
  -> APIKey
      -> Group
          -> AccountGroup
              -> Account
                  -> Proxy
  -> UserSubscription
      -> Group
  -> UsageLog
  -> PaymentOrder
  -> AuthIdentity
  -> UserPlatformQuota

Channel
  -> OpenAI 平台的模型映射、定价和限制

Setting
  -> 系统级配置
```

## User

Schema：

```text
backend/ent/schema/user.go
```

用户是系统主体。关键字段：

- `email`
- `password_hash`
- `role`
- `balance`
- `concurrency`
- `status`
- `totp_*`
- `signup_source`
- `rpm_limit`

主要关系：

- `api_keys`
- `subscriptions`
- `allowed_groups`
- `usage_logs`
- `payment_orders`
- `auth_identities`
- `platform_quotas`

## APIKey

Schema：

```text
backend/ent/schema/api_key.go
```

API Key 是客户端调用网关的凭证。关键字段：

- `user_id`
- `key`
- `name`
- `group_id`
- `status`
- `ip_whitelist` / `ip_blacklist`
- `quota` / `quota_used`
- `expires_at`
- `rate_limit_*`
- `usage_*`

主要关系：

- 属于一个 `User`
- 可绑定一个 `Group`
- 关联多条 `UsageLog`

网关鉴权后会从 API Key 找到用户和分组，后续调度依赖该分组。

## Group

Schema：

```text
backend/ent/schema/group.go
```

Group 是用户/API Key 和上游账号池之间的隔离与调度单元。关键字段：

- `name`
- `platform`
- `rate_multiplier`
- `is_exclusive`
- `subscription_type`
- `daily_limit_usd` / `weekly_limit_usd` / `monthly_limit_usd`
- `model_routing`
- `model_routing_enabled`
- `supported_model_scopes`
- `allow_messages_dispatch`
- `default_mapped_model`
- `messages_dispatch_model_config`
- `models_list_config`
- `rpm_limit`

主要关系：

- 拥有多个 `APIKey`
- 通过 `AccountGroup` 关联多个 `Account`
- 通过 `UserAllowedGroup` 限制专属用户
- 关联订阅和 usage

## Account

Schema：

```text
backend/ent/schema/account.go
```

Account 是可调度的上游账号或凭证。关键字段：

- `name`
- `platform`
- `type`
- `credentials`
- `extra`
- `proxy_id`
- `concurrency`
- `priority`
- `rate_multiplier`
- `status`
- `schedulable`
- `model_whitelist`
- `quota` / `usage` / window 相关字段
- 平台特定的扩展字段通常放在 `extra`

主要关系：

- 通过 `AccountGroup` 绑定多个 `Group`
- 可绑定 `Proxy`

调度时通常会过滤：

- 平台是否匹配
- 是否在目标 group
- `status` 是否 active
- 是否 `schedulable`
- 并发槽位是否可用
- 模型是否支持
- quota/RPM/窗口成本是否允许

## AccountGroup

Schema：

```text
backend/ent/schema/account_group.go
```

Account 和 Group 的多对多关联表。常用于决定某个 group 可以调度哪些账号。

## Channel

Schema：

```text
backend/ent/schema/channel.go
```

Channel 主要服务 OpenAI 路径，用于表达模型映射、平台定价、限制和展示。关键相关文件：

```text
backend/internal/service/channel_service.go
backend/internal/repository/channel_repo.go
frontend/src/api/admin/channels.ts
frontend/src/views/admin/ChannelsView.vue
```

OpenAI 请求通常会先解析 requested model，再通过 channel 逻辑决定实际 upstream model、是否受限以及如何计价。

## UsageLog

Schema：

```text
backend/ent/schema/usage_log.go
```

UsageLog 记录请求使用情况，是统计、计费和排障的重要来源。通常包含：

- `user_id`
- `api_key_id`
- `group_id`
- `account_id`
- 请求模型和上游模型
- token 用量
- cost
- endpoint / request type
- 状态和错误信息
- latency / timing

使用路径：

```text
GatewayService.RecordUsage()
OpenAIGatewayService.RecordUsage()
UsageLogRepository
UsageBillingRepository
```

## Proxy

Schema：

```text
backend/ent/schema/proxy.go
```

Proxy 是上游请求可选代理配置。Account 可绑定 proxy，调度到该 account 后，上游请求可能走对应代理。

## Setting

Schema：

```text
backend/ent/schema/setting.go
```

Setting 是系统级 key/value 配置。前后端公共设置、OAuth、支付、风控、ops 等很多功能都依赖它。

注意：Setting 使用硬删除，不走软删除。

## Subscription / Payment

相关 schema：

```text
backend/ent/schema/user_subscription.go
backend/ent/schema/subscription_plan.go
backend/ent/schema/payment_order.go
backend/ent/schema/payment_provider_instance.go
backend/ent/schema/payment_audit_log.go
```

主要关系：

- `SubscriptionPlan` 是可售套餐，通常绑定一个 group。
- `UserSubscription` 是用户已获得的订阅权益。
- `PaymentOrder` 是支付订单。
- `PaymentProviderInstance` 是管理员配置的支付服务商实例。
- 支付成功后通常会充值余额或分配订阅。

## AuthIdentity

Schema：

```text
backend/ent/schema/auth_identity.go
```

AuthIdentity 存储用户登录身份：

- email
- github
- google
- linuxdo
- oidc
- wechat
- dingtalk

OAuth 登录、绑定、迁移和账号认领相关逻辑会用到它。

## UserPlatformQuota

Schema：

```text
backend/ent/schema/user_platform_quota.go
```

用于用户级平台 quota：

- `anthropic`
- `openai`
- `gemini`
- `antigravity`

字段表达日/周/月限额和当前窗口用量。注意：`nil` 表示无限额，`0` 表示完全禁用。

## 修改模型时的流程

1. 修改 `backend/ent/schema/*.go`。
2. 如需数据迁移，新增 `backend/migrations/*.sql`。
3. 执行：

```bash
cd backend
go generate ./ent
```

4. 同步修改 repository/service/handler/frontend API types。
5. 跑后端单元测试和前端构建。
