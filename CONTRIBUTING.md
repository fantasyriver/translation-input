# 贡献指南

译入是 MIT 许可的原生 macOS 应用。请保持客户端轻量，优先使用系统框架，不增加中转服务、常驻后台进程或遥测。

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
- `scripts/check-integration.py`：临时 HTTP 测试夹具，不是产品服务。
- `docs/manual-testing.md`：自动验证结果与真机验收边界。

新增提供商请先确认官方接口、地域、鉴权、模型和停止原因，再补请求/响应测试。不要直接粘贴付费 API Key 到 issue、日志或测试；真实模型验收由持 Key 的开发者自行进行。

必须保留取消请求、迟到响应拦截、目标焦点校验、密码框排除与 Key 地址隔离。不要通过定时恢复旧剪贴板实现“无感回填”，跨应用粘贴没有统一完成回执。

任何建表、改表或批量更新数据只能生成独立 SQL 文件，禁止写进应用代码；当前项目没有数据库。

## 发布

构建脚本支持 `SIGN_IDENTITY`。开发包默认 ad-hoc 签名，正式发布需自己的稳定 Bundle ID、Developer ID 签名、公证和新机器验收。不要上传密钥、证书、UserDefaults 导出或 `.env`。发布安装包前请确认签名、公证及真机验收结果。
