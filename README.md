# 译入 · Translation Input

轻量、原生、开源的 macOS 翻译输入工具。按快捷键打开悬浮框，用已有输入法输入任意语言，选择目标语言并确认，译文自动尝试回填到原输入位置。

**Mac 客户端直接调用你选择的 LLM API，无中转服务器。** 自备 API Key，API 调用费用由模型提供商按你的账户计费。应用采用 MIT 许可证，不提供账号、订阅或额度售卖。这里的“本地调用”是请求从 Mac 发出；预设使用云端模型，不代表离线推理。

Swift + AppKit + 系统 URLSession / Keychain；无第三方运行依赖、无后台服务、无数据库。支持 macOS 14+。当前为 0.2 开发版，完整真机兼容性与真实模型验收仍在进行。

## 使用

1. 打开应用，在设置里选择提供商。地址、模型和接口协议自动填好。
2. 粘贴该提供商的 API Key，点击“保存模型配置”。各提供商保存独立配置；切换会放弃尚未保存的修改。
3. 如需自动回填，点击“开启自动回填权限…”，在系统设置中授权辅助功能。
4. 在原应用的输入位置按快捷键，输入文字并选择目标语言，点击确定或按 `Command + Enter`。

默认快捷键为 `Option + Space`，可自定义。录制成功立即保存，不依赖模型配置；冲突时显示错误并保留原配置。已有用户的快捷键保持不变。`Enter` 换行，`Esc` 关闭；也可从菜单栏或设置打开输入框。

| 提供商 | 预设模型 | 接口协议 |
| --- | --- | --- |
| OpenAI / ChatGPT | `gpt-5-nano` | Chat Completions |
| Anthropic / Claude | `claude-haiku-4-5-20251001` | Claude Messages |
| DeepSeek | `deepseek-flash` | Chat Completions |
| 智谱 GLM，中国区 | `glm-4.7-flash` | Chat Completions |
| MiniMax，中国区 | `MiniMax-M3` | Chat Completions |
| 通义千问，北京区 | `qwen-turbo` | Chat Completions |
| 自定义 | 自行填写 | 两种协议任选 |

预设优先低价文本模型，并尽量减少思考耗时；不承诺永久最低价。地址、模型、协议均可编辑；“恢复此提供商预设”可恢复默认值。具体 API 地址、地域、选择理由和官方来源见 [模型预设说明](docs/providers.md)。Key 必须来自对应 API 平台；本应用没有网站账号或订阅登录功能。

**API 地址是完整接口 URL**，例如 `https://api.openai.com/v1/chat/completions`，不是只有域名或 `/v1`。自定义服务可接 OpenAI 兼容的本机推理接口；本机回环地址允许 HTTP 和空 Key。远程地址要求 HTTPS，不允许 URL 中带用户名、密码、查询参数或片段，不跟随重定向。

## 构建与验证

需要 macOS 14+ 和 Swift 6 工具链，验证脚本另需 Python 3。不需要 Go、Node、模型 SDK 或服务端部署。

```bash
./scripts/build-app.sh
open dist/TranslationInput.app
```

```bash
swift run --package-path macos CoreChecks
python3 scripts/check-integration.py
./scripts/build-app.sh
```

`CoreChecks` 是独立断言检查程序，不依赖 XCTest，失败返回非零。HTTP 检查启动一次性回环地址测试夹具，使用随机测试 Key 验证真实 Swift 网络客户端，结束后关闭。**测试夹具不属于产品服务端，也不调用真实模型。**

生成的是当前机器架构 `.app`，默认 ad-hoc 签名。正式官网发布需稳定的 Bundle ID、自己的 Developer ID 签名与公证；可以用 `SIGN_IDENTITY` 指定签名身份。当前开发包尚未公证。

## 隐私与行为

- Key 只保存到本机 macOS 钥匙串，按提供商、协议与完整 API 地址隔离；地址变更会重新加载对应 Key。模型名及非敏感配置保存在 UserDefaults。旧中转服务令牌不会迁移为模型 Key。
- 首次向某个接口发送文字会确认接收方。保存设置不发网络请求，不自动探测模型，不自动重试。
- 不保存翻译历史、不记录输入/输出/Key，不内置遥测。当前原文与上次译文仅在内存中保留；模型提供商的数据处理政策另行适用。
- 取消、失焦、超时和失败保留原文；迟到响应不会自动粘贴。拒绝、截断、空译文、工具调用及超大响应不回填。
- 粘贴前检查原应用、窗口、控件和选区，事件限制到原进程；**译文会替换并保留在系统剪贴板**。这不是目标应用已消费粘贴的回执。
- 无辅助功能权限或无法确认目标时仍能查看、复制译文。密码框、终端、自绘/远程控件和系统安全界面不保证自动回填；不自动按回车发送消息。
- 输入上限 10,000 Unicode 标量；输出上限 8,192 tokens（部分模型含思考），HTTP 响应上限 512 KiB；等待数据超时 45 秒、请求总上限 60 秒。

[验证记录与人工验收](docs/manual-testing.md) · [贡献指南](CONTRIBUTING.md) · [MIT License](LICENSE)
