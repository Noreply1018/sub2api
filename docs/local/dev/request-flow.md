# 网关请求流

网关是本项目最核心的二开区域。它把客户端请求转换、调度并转发到不同上游平台，同时记录 usage 和执行计费/配额逻辑。

## 入口路由

主要文件：

```text
backend/internal/server/routes/gateway.go
```

主要入口：

| 路由 | 说明 |
| --- | --- |
| `/v1/messages` | Claude Messages 兼容入口；OpenAI 分组会自动转给 OpenAI handler |
| `/v1/messages/count_tokens` | Claude token count；OpenAI 分组返回不支持 |
| `/v1/models` | 模型列表 |
| `/v1/usage` | 用户/key usage |
| `/v1/responses` | Responses API；OpenAI 分组走 OpenAI handler |
| `/v1/chat/completions` | OpenAI Chat Completions 兼容入口 |
| `/v1/embeddings` | OpenAI embeddings，仅 OpenAI 分组 |
| `/v1/images/*` | OpenAI images，仅 OpenAI 分组 |
| `/v1beta/models/*` | Gemini 原生 API 兼容入口 |
| `/antigravity/*` | Antigravity 专用入口 |

## 中间件顺序

网关路由通常挂载：

```text
RequestBodyLimit
  -> ClientRequestID
  -> OpsErrorLogger
  -> InboundEndpointMiddleware
  -> APIKeyAuth
  -> RequireGroupAssignment
  -> Handler
```

`APIKeyAuth` 会把 API Key、用户、分组等信息放入 Gin context。后续 handler/service 会依赖这些 context 值。

## 平台分流

`routes/gateway.go` 会根据 API Key 绑定分组的 `platform` 决定部分入口走哪个 handler：

```text
OpenAI 分组
  -> OpenAIGatewayHandler

其他分组
  -> GatewayHandler
```

核心 handler：

```text
backend/internal/handler/gateway_handler.go
backend/internal/handler/gateway_handler_chat_completions.go
backend/internal/handler/gateway_handler_responses.go
backend/internal/handler/gemini_v1beta_handler.go
backend/internal/handler/openai_gateway_handler.go
backend/internal/handler/openai_chat_completions.go
backend/internal/handler/openai_embeddings.go
backend/internal/handler/openai_images.go
```

核心 service：

```text
backend/internal/service/gateway_service.go
backend/internal/service/openai_gateway_service.go
backend/internal/service/antigravity_gateway_service.go
backend/internal/service/gemini_messages_compat_service.go
```

## 通用请求流

```text
客户端
  -> 网关路由
  -> API Key 鉴权
  -> 分组和平台解析
  -> 请求解析和模型识别
  -> 配额 / 余额 / 订阅检查
  -> 账号候选列表
  -> sticky session / 模型路由 / 混合调度 / 并发槽位
  -> 获取上游 token 或 API key
  -> 构建上游请求
  -> HTTP / WebSocket 转发
  -> 流式或非流式响应处理
  -> usage 提取
  -> 计费和 usage log
  -> 错误处理、failover、账号临时禁用
```

## Anthropic/Gemini/Antigravity 路径

主要使用 `GatewayService`：

```text
handler.Gateway.Messages / ChatCompletions / Responses / GeminiV1BetaModels
  -> GatewayService.SelectAccount*()
  -> GatewayService.GetAccessToken()
  -> GatewayService.Forward()
  -> GatewayService.handleStreamingResponse() 或 handleNonStreamingResponse()
  -> GatewayService.RecordUsage()
```

关键能力：

- 根据 group platform 选择平台。
- 支持 group/model routing。
- 支持 sticky session。
- 支持账号并发槽位。
- 支持 OAuth token 获取和刷新。
- 支持 Anthropic、Gemini、Bedrock、Antigravity 等协议差异。
- 支持 failover、临时不可调度、错误透传策略。

## OpenAI 路径

OpenAI 主要使用 `OpenAIGatewayService`：

```text
OpenAIGatewayHandler.ChatCompletions / Responses / Embeddings / Images
  -> OpenAIGatewayService.ResolveChannelMapping*
  -> OpenAIGatewayService.SelectAccountForModel*
  -> OpenAIGatewayService.Forward()
  -> OpenAIGatewayService.handleStreamingResponse() 或 handleNonStreamingResponse()
  -> OpenAIGatewayService.RecordUsage()
```

关键能力：

- OpenAI channel 映射和模型限制。
- Responses / Chat Completions / Embeddings / Images 分入口处理。
- OAuth 和 API key 账号差异处理。
- OpenAI WebSocket Responses 代理。
- Codex / compact / service tier / image 成本等特殊逻辑。
- OpenAI 上游错误检测、failover、运行时调度阻断。

## 计费和 usage

计费和 usage 相关入口：

```text
backend/internal/service/billing_service.go
backend/internal/service/billing_cache_service.go
backend/internal/service/gateway_record_usage.go
backend/internal/service/openai_gateway_service.go
backend/internal/repository/usage_log_repo.go
backend/internal/repository/usage_billing_repo.go
backend/ent/schema/usage_log.go
```

一般在响应处理后提取 token / cost 信息，再写入 `usage_logs`，并更新用户余额、API Key quota、订阅用量或平台 quota。

## 调度相关数据

调度主要依赖：

- API Key 绑定的 Group。
- Group 的平台、模型路由、倍率、RPM、专属组配置。
- Account 的平台、类型、分组绑定、状态、可调度标记、并发、优先级、模型白名单和 quota 状态。
- Redis 中的 session、并发、RPM、token、临时禁用等缓存。

## 二开定位建议

| 要改什么 | 先看哪里 |
| --- | --- |
| 新增网关入口 | `routes/gateway.go`、对应 handler |
| 改 API Key 鉴权 | `server/middleware/api_key_auth*.go`、`service/api_key_*` |
| 改账号选择 | `service/gateway_service.go`、`service/openai_gateway_service.go` 的 `SelectAccount*` |
| 改模型映射 | `service/channel_service.go`、`service/openai_gateway_service.go`、Group model routing |
| 改上游请求头/URL/body | `buildUpstreamRequest*` 系列方法 |
| 改流式响应 | `handleStreamingResponse*` 系列方法 |
| 改 usage 计费 | `RecordUsage*`、`billing_*`、`usage_billing_repo.go` |
| 改错误兜底/failover | `handleErrorResponse*`、`shouldFailover*`、`error_passthrough_*` |
