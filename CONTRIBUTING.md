# 贡献指南

译入是 MIT 许可的原生 macOS 应用。请保持客户端轻量，优先使用系统框架。

## 开发

要求 macOS 14+、Swift 6；HTTP 测试另需 Python 3。

```bash
swift run --package-path macos CoreChecks
python3 scripts/check-integration.py
./scripts/build-app.sh
```

- `macos/Sources/TranslationCore/`：提供商预设、配置、HTTP 协议、响应校验、会话与快捷键状态。
- `macos/Sources/TranslationInput/`：AppKit 窗口、全局快捷键、Keychain、Accessibility 回填。
- `macos/Tests/TranslationCoreTests/`：独立可执行断言检查。
- `scripts/check-integration.py`：临时 HTTP 测试夹具。
- `docs/manual-testing.md`：自动验证结果与真机验收边界。

新增提供商请先确认官方接口、地域、鉴权、模型和停止原因，再补请求/响应测试。测试使用模拟 Key，真实模型验收使用开发者本机保存的 Key。

回填流程需保留请求取消、迟到响应拦截、目标焦点校验、密码框排除与 Key 地址隔离。译文保留在剪贴板中，供目标应用读取。

涉及建表、改表或批量更新数据时，请生成独立 SQL 文件。

## 发布

构建脚本支持 `SIGN_IDENTITY`。开发包默认 ad-hoc 签名，正式发布需自己的稳定 Bundle ID、Developer ID 签名、公证和新机器验收。提交前检查密钥、证书及本机配置是否已排除，发布前完成真机验收。
