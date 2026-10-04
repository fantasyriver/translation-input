# 下载、安装与升级

## 系统要求

- macOS 14 或以上。
- Apple Silicon（M 系列芯片）；v0.4.3 下载包为 arm64 架构。
- 自己的模型服务 API Key，调用费用按提供商账户计费。自定义本机模型服务可使用其支持的鉴权方式。

## 下载

从 [v0.4.3 测试版发布页](https://github.com/fantasyriver/translation-input/releases/tag/v0.4.3) 的 Assets 下载：

- **[TranslationInput-v0.4.3-macos-arm64.zip](https://github.com/fantasyriver/translation-input/releases/download/v0.4.3/TranslationInput-v0.4.3-macos-arm64.zip)**：可安装的应用。
- **[SHA256SUMS.txt](https://github.com/fantasyriver/translation-input/releases/download/v0.4.3/SHA256SUMS.txt)**：用于检查下载文件完整性。

页面中的 `Source code` 文件供开发者获取源码；安装应用请选择上面的 `TranslationInput` ZIP。

可选校验：将 ZIP 和 `SHA256SUMS.txt` 放在同一目录，在终端进入该目录并执行：

```bash
shasum -a 256 -c SHA256SUMS.txt
```

看到安装包文件名后显示 `OK`，表示文件与发布时的校验值一致。

## 安装

1. 双击 ZIP 解压，得到 `TranslationInput.app`。
2. 将应用拖到 Finder 的“应用程序”文件夹。
3. 从“应用程序”中双击打开。译入常驻菜单栏，图标为双向箭头与插入光标。
4. 后续从这份已安装的应用启动，并为它配置辅助功能权限。

## 首次打开

v0.4.3 使用临时开发签名，尚未经过 Apple 公证。macOS 可能提示“无法验证开发者”或“Apple 无法检查其是否包含恶意软件”。

确认文件从本项目发布页下载且来源可信后：

1. 尝试打开应用，关闭系统阻止提示。
2. 打开“系统设置 → 隐私与安全性”。
3. 在安全性区域找到 TranslationInput 被阻止的提示，点击“仍要打开”。
4. 按系统要求确认后打开应用。

仅对确认来源的应用执行上述操作。若提示文件损坏、包含恶意软件，或单位设备的管理策略阻止打开，请先停止安装并核实文件或联系管理员。

参考：[Apple：在 Mac 上安全地打开 App](https://support.apple.com/zh-cn/102445)。

## 配置与第一次翻译

1. 点击菜单栏译入图标，选择“设置…”。
2. 选择模型提供商，检查预设地址和模型，填写自己的 API Key 并保存。
3. 默认唤起快捷键为 `Option + Space`，可以自行录制；若与系统或其他应用冲突，选择其他组合。
4. 在任意目标应用的输入位置放好光标，再按快捷键唤起译入。
5. 输入原文、选择目标语言，点击“翻译”或按 `Command + Enter`。

译文自动复制到剪贴板。辅助功能权限可用且原输入位置可确认时，程序尝试回填并隐藏窗口；其他情况下保留译文供查看与粘贴。再次通过快捷键唤起会清空原文和结果，开始新的输入。从设置返回会保留草稿。

首次请求会显示目标模型服务的发送确认。API Key 保存在本机钥匙串，文字直接发送到配置的模型 API。

## 辅助功能授权与更新后的修复

自动回填需要辅助功能权限：

1. 点击译入输入窗口里的“开启自动回填…”或设置中的权限按钮。
2. 在“系统设置 → 隐私与安全性 → 辅助功能”里找到 **TranslationInput** 并开启。
3. 如列表中没有应用，点击 `＋`，选择“应用程序”中的 `TranslationInput.app` 并开启。
4. 返回目标输入位置，重新用快捷键唤起译入。

开发版更新后，系统里旧的授权记录可能与新程序签名不匹配。表现为开关已开启，回填仍无效。处理步骤：

1. 从菜单栏退出译入。
2. 在辅助功能列表选中旧的 TranslationInput，点击 `－` 移除。
3. 点击 `＋`，重新添加“应用程序”中的当前版本并开启开关。
4. 重新打开译入，在目标输入框中再次测试。

权限可用时，某些应用或自绘控件仍可能无法自动回填；此时可以直接按 `Command + V` 粘贴译文。

## 升级

1. 在 [Releases](https://github.com/fantasyriver/translation-input/releases) 下载新版本安装包。
2. 从菜单栏选择“退出译入”。
3. 解压新包，将应用拖入“应用程序”，确认替换旧版。
4. 打开新版本。普通设置和钥匙串中的 API Key 保存在应用包外，替换应用后保留。
5. 若自动回填失效，按上面的步骤重新添加辅助功能授权。

当前版本采用手动下载安装包的升级方式。

## 反馈

在 [GitHub Issues](https://github.com/fantasyriver/translation-input/issues) 提交问题，附上版本号、macOS 版本、目标应用名称、复现步骤和窗口提示。截图前请遮盖私人文字；请勿提交 API Key。
