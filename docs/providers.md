# 模型预设与官方来源

核实日期：2026-10-01。预设优先考虑短文本翻译的成本与延迟。价格和模型权限以对应平台为准。本地测试已覆盖请求/响应协议，真实 API 验收待完成。

| 提供商 | 完整 API 地址 | 默认模型与选择理由 |
| --- | --- | --- |
| OpenAI | `https://api.openai.com/v1/chat/completions` | `gpt-5-nano`，低价 Nano，`reasoning_effort=minimal` |
| Claude | `https://api.anthropic.com/v1/messages` | `claude-haiku-4-5-20251001`，Haiku 轻量档；`x-api-key` + `anthropic-version: 2023-06-01` |
| DeepSeek | `https://api.deepseek.com/chat/completions` | `deepseek-flash`，当前 Flash 名称；关闭 thinking |
| GLM 中国区 | `https://open.bigmodel.cn/api/paas/v4/chat/completions` | `glm-4.7-flash`，轻量 Flash；关闭 thinking |
| MiniMax 中国区 | `https://api.minimax.cn/v1/chat/completions` | `MiniMax-M3`，标准服务短上下文价格与 M2.7 同档，而且可关闭 thinking；开启 reasoning_split |
| 千问北京区 | `https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions` | `qwen-turbo`，低价 Turbo；`enable_thinking=false` |

OpenAI 使用 `max_completion_tokens`；其余 Chat Completions 使用 `max_tokens`。temperature 使用提供商默认值。预设关闭思考只应用到代码明确支持的模型系列；修改到其他模型时可能采用提供商默认思考策略。自定义模式使用所选协议的通用参数。

MiniMax 中国区官方文档当前示例为 `api.minimax.cn`；国际区为 `https://api.minimax.io/v1/chat/completions`。千问新加坡区通常使用 `dashscope-intl.aliyuncs.com`，美国区有独立地址。智谱中国区与 Z.ai 国际平台也不同。地域与 API Key 必须对应，更换地址后需填写该地址的 Key。

## 官方资料

- [OpenAI GPT-5 nano 模型、价格、可用接口](https://developers.openai.com/api/docs/models/gpt-5-nano)
- [Claude 模型与 API 使用说明](https://platform.claude.com/docs/en/claude_api_primer)；[Messages 请求](https://platform.claude.com/docs/en/api/messages/create)
- [DeepSeek 模型更新记录](https://api-docs.deepseek.com/updates/)；[Chat Completions 与思考控制](https://api-docs.deepseek.com/api/create-chat-completion/)
- [GLM-4.7-Flash 官方说明与调用示例](https://docs.bigmodel.cn/cn/guide/models/free/glm-4.7-flash)（页面不可达时可用同地址 `.md` 文档）
- [MiniMax 中国区 OpenAI 兼容接口](https://platform.minimaxi.com/docs/api-reference/text-openai-api)；[官方价格](https://platform.minimaxi.com/docs/pricing/overview)
- [千问 Turbo 模型说明](https://help.aliyun.com/zh/model-studio/qwen-turbo)；[OpenAI 兼容接口和地域地址](https://help.aliyun.com/zh/model-studio/compatibility-of-openai-with-dashscope)

模型下线或改价后，可直接在应用设置修改模型名或地址。更新默认值时需同步 `Providers.swift`、请求参数适配、HTTP 测试夹具、本页与 README，并按对应地域的官方资料核实价格和可用性。
