# 译入 · Translation Input

轻量、原生、开源的 macOS 翻译输入工具。按快捷键打开悬浮框，使用系统输入法输入文字，选择目标语言并确认，译文自动尝试回填到原输入位置。

客户端直接调用你选择的 LLM API，支持 OpenAI、Claude、DeepSeek、GLM、MiniMax、通义千问及自定义服务。填写自己的 API Key，调用费用由提供商按你的账户计费。

采用 Swift + AppKit 开发，支持 macOS 14+，使用 MIT 许可证。当前版本为 0.4 开发版。

![译入浅色输入窗口](docs/images/inline-light.png)

支持跟随系统、浅色和深色外观。[深色预览](docs/images/inline-dark.png) · [设置页](docs/images/settings.png)

## 使用

1. 打开设置，选择提供商，自动填入 API 地址、模型和接口协议。
2. 填写 API Key，点击“保存配置”。切换提供商前请保存修改。
3. 如需自动回填，点击输入框的“开启自动回填…”或设置页的“管理权限…”，进入系统辅助功能设置授权。
4. 在目标应用的输入位置按快捷键，输入文字，选择目标语言，点击“翻译”或按 `Command + Enter`。

翻译成功后，译文直接显示在原文下方，并自动复制到剪贴板。已授权且原输入位置可确认时，同时尝试自动回填；窗口保留原文和译文供查看。译文卡片右上角可再次复制。

默认快捷键为 `Option + Space`，可在设置中录制，成功后立即生效。`Enter` 换行，`Esc` 关闭；菜单栏和设置页也可打开输入框。

## 模型配置

| 提供商 | 预设模型 | 接口协议 |
| --- | --- | --- |
| OpenAI / ChatGPT | `gpt-5-nano` | Chat Completions |
| Anthropic / Claude | `claude-haiku-4-5-20251001` | Claude Messages |
| DeepSeek | `deepseek-flash` | Chat Completions |
| 智谱 GLM，中国区 | `glm-4.7-flash` | Chat Completions |
| MiniMax，中国区 | `MiniMax-M3` | Chat Completions |
| 通义千问，北京区 | `qwen-turbo` | Chat Completions |
| 自定义 | 自行填写 | 两种协议任选 |

预设优先低价文本模型。API 地址、模型和协议均可编辑，每个提供商独立保存配置。地域和 Key 需对应，详情见 [模型预设说明](docs/providers.md)。

API 地址填写完整接口 URL，例如 `https://api.openai.com/v1/chat/completions`。远程服务使用 HTTPS；自定义服务可连接本机推理接口，回环地址支持 HTTP 和空 Key。

## 构建与验证

需要 macOS 14+、Swift 6 工具链；验证脚本另需 Python 3。

```bash
./scripts/build-app.sh
open dist/TranslationInput.app
```

运行检查：

```bash
swift run --package-path macos CoreChecks
python3 scripts/check-integration.py
```

核心检查覆盖配置、请求解析和会话状态，HTTP 检查使用临时本地接口验证网络请求。界面迭代见 [设计检查记录](docs/design-review.md)。真实模型与跨应用回填的验收进度见 [验证记录](docs/manual-testing.md)。

构建输出为当前机器架构的 `.app`，默认使用 ad-hoc 开发签名。正式发布需稳定的 Bundle ID、Developer ID 签名和公证；`SIGN_IDENTITY` 可指定签名身份。

## 数据与回填

- API Key 保存在本机钥匙串，按提供商、协议和地址隔离；普通配置保存在 UserDefaults。
- 确认翻译后，文字直接发送至配置的 API 地址。首次发送会提示接收方，数据处理遵循对应提供商的政策。
- 当前原文和上次译文保存在运行内存中，退出应用后清除。
- 取消、失焦、超时或失败时保留原文。只有完整有效的译文才会进入回填流程。
- **翻译成功后，译文会替换并保留在系统剪贴板**。自动回填前校验原应用和输入位置。
- 权限或目标控件受限时，译文显示在原文下方并自动复制，可直接粘贴。密码框、终端、自绘控件和远程控件建议使用手动复制。
- 输入上限为 10,000 Unicode 标量，请求总时限为 60 秒。

[贡献指南](CONTRIBUTING.md) · [MIT License](LICENSE)
