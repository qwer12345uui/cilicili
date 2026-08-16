# iOS 15 手动构建与发布流程

本文档用于发布 `cilicili` 的 iOS 15 兼容 IPA。它对应仓库内的 `.github/workflows/unsigned-ipa.yml`，并与 GPL-3.0-only 的源码、许可文本和发行说明一并维护。[1]

## 构建前检查

在提交构建前，应确认应用目标的 `IPHONEOS_DEPLOYMENT_TARGET` 为 `15.0`，并确认 `bili/Compatibility/CiliCiliCompatibilityApp.swift` 同时包含**首页、我的、搜索**三个标签入口。任何涉及相册保存的修改必须保留 `NSPhotoLibraryUsageDescription` 与 `NSPhotoLibraryAddUsageDescription` 两项说明。

| 检查项 | 预期状态 | 目的 |
| --- | --- | --- |
| `git diff --check` | 无输出 | 防止空白字符或补丁格式错误 |
| 应用构建成员 | 仅兼容入口与资源 | 防止将 iOS 16–26 的源码编入 iOS 15 包 |
| 发布配置 | 团队、描述文件和签名标识为空 | 保证仓库不携带个人签名资料 |
| 修复日记 | 更新当前版本文件 | 说明功能范围、变更原因与验证结果 |

## 在线构建步骤

进入仓库的 **Actions** 页面，选择 **Build iOS 15 unsigned IPA**，在 `main` 分支上点击 **Run workflow**。构建使用 macOS 运行器和 Xcode，对 `bili` scheme 执行 Release、`iphoneos`、无签名构建。构建完成后下载两个产物：`cilicili-ios15-unsigned.ipa` 与 `xcodebuild.log`。

如果构建失败，应先下载 `xcodebuild.log`，提取 `error:` 行及其上下文，再修改对应的源代码或工程设置。不得通过关闭 Swift 可用性诊断来处理旧系统 API 错误；若某批界面不能在 iOS 15 上以等价方式实现，应从 iOS 15 目标的构建成员中移除，并在修复日记中明确范围。

## 成功校验与发布

构建成功后，使用下列步骤保存校验结果，再创建 GitHub Release。Release 应绑定对应源码提交或标签，并包含 IPA、SHA-256 校验文件和本版本修复日记。

```bash
sha256sum cilicili-ios15-unsigned.ipa
unzip -l cilicili-ios15-unsigned.ipa
```

| 发布文件 | 用途 |
| --- | --- |
| `cilicili-ios15-unsigned.ipa` | iOS 15 兼容的无签名包 |
| `cilicili-ios15-unsigned.ipa.sha256` | 完整性校验值 |
| `RELEASE_NOTES_1.0.20.md` | 修复内容、功能范围与验证结论 |
| `LICENSE` 与对应源码 | 履行 GPL-3.0-only 的源码与许可义务 |

> 无签名 IPA 不可直接作为 App Store 或 TestFlight 发布包，也不应随附任何开发者账号、证书、描述文件或私钥。需要安装到设备时，应由具备相应授权的开发者在仓库外完成签名。

## 失败日志处理顺序

| 顺序 | 处理动作 | 判断标准 |
| --- | --- | --- |
| 1 | 读取构建日志 | 以第一个 `error:` 的完整上下文为准 |
| 2 | 确认错误类别 | 区分 Swift 语法、工程成员、资源、可用性与签名问题 |
| 3 | 最小范围修改 | 不删除截图要求的首页、我的、搜索入口 |
| 4 | 提交变更并再次构建 | 使用新提交对应的构建运行 |
| 5 | 记录最终结论 | 写明构建运行链接、产物名和 SHA-256 |

## 参考来源

[1]: https://github.com/qwer12345uui/cilicili
