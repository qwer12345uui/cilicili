# cilicili

cilicili 是一个使用 SwiftUI 开发的第三方 iOS 客户端实验项目，重点探索更轻量的 B 站浏览、动态、视频播放和弹幕体验。

> 本项目仅用于学习、研究和个人使用。项目不隶属于哔哩哔哩，也不包含任何账号凭据、签名证书或私有接口密钥。请遵守目标平台服务条款和当地法律法规。

官方 Telegram 频道：[@cilicili89](https://t.me/cilicili89)

## iOS 15 兼容版本

当前发布版本以 **iOS 15.0** 为最低部署目标，采用原生 SwiftUI 框架保留截图所示的三个底部入口：**首页**、**我的**与**搜索**。底部导航使用半透明材质、胶囊轮廓与粉色选中态呈现玻璃感效果；入口选择会在本机保存并于下次启动恢复。首页提供原生推荐轮播与内容卡片，搜索页提供原生关键词输入、热门词和结果列表，“我的”页提供偏好项与从系统相册选择图片、申请相册权限及写入系统相册的保存路径。

原始工程中的视频播放、弹幕、动态和高阶设置界面依赖 iOS 16–26 的 SwiftUI 与 UIKit API，因此不纳入 iOS 15 兼容构建。源码仍完整保留在仓库中，供后续按系统版本继续维护。

| 项目 | 当前兼容构建 | 原始高版本界面 |
| --- | --- | --- |
| 最低系统版本 | iOS 15.0 | iOS 26.4+ |
| 底部导航 | 首页、我的、搜索；浮动玻璃外观 | 首页、动态、直播、我的、搜索 |
| 内容框架 | 原生推荐卡片、原生搜索与偏好页 | 视频、弹幕、动态与直播 |
| 图片保存 | 系统相册选择、授权与写入 | 原图、GIF、Live Photo 保存 |
| 构建成员 | `bili/Compatibility/CiliCiliCompatibilityApp.swift` | `bili/Sources/` |

## 环境要求

| 项目 | 要求 |
| --- | --- |
| 开发环境 | macOS + Xcode 26.5 或更新版本 |
| 最低部署版本 | iOS 15.0 |
| 界面框架 | SwiftUI、UIKit、WebKit、Photos |
| 产物类型 | 无签名 IPA |

## 本地运行

```bash
xcodebuild \
  -project bili.xcodeproj \
  -scheme bili \
  -configuration Debug \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone Air' \
  build
```

也可以直接用 Xcode 打开 `bili.xcodeproj`，选择 `bili` scheme 后运行。

## 构建未签名 IPA

未签名 IPA 适合上传到 GitHub Release 或交给其他签名工具继续处理，不能直接作为 App Store/TestFlight 包发布。

```bash
DERIVED_DATA_PATH="$PWD/build/UnsignedIPADerivedData"
BUILD_DIR="$PWD/build/ipa"

rm -rf "$DERIVED_DATA_PATH" "$BUILD_DIR"
mkdir -p "$BUILD_DIR/Payload"

xcodebuild \
  -project bili.xcodeproj \
  -scheme bili \
  -configuration Release \
  -sdk iphoneos \
  -destination 'generic/platform=iOS' \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  PROVISIONING_PROFILE_SPECIFIER="" \
  COPY_PHASE_STRIP=YES \
  STRIP_INSTALLED_PRODUCT=YES \
  DEPLOYMENT_POSTPROCESSING=YES \
  build

APP_PATH="$(find "$DERIVED_DATA_PATH/Build/Products" -maxdepth 2 -name '*.app' -type d | head -n 1)"
cp -R "$APP_PATH" "$BUILD_DIR/Payload/"
(cd "$BUILD_DIR" && zip -qry cilicili-ios15-unsigned.ipa Payload)
```

## 在线构建

仓库内置 `.github/workflows/unsigned-ipa.yml`。该工作流仅在 GitHub 的 Actions 页面手动启动，构建完成后会提供 `cilicili-ios15-unsigned.ipa` 和 `xcodebuild.log` 两个可下载产物。发布步骤、文件校验与签名限制请参阅 [BUILD_AND_RELEASE_WORKFLOW.md](BUILD_AND_RELEASE_WORKFLOW.md)。

## 隐私与安全

- 仓库不提交 `.ipa`、`.dSYM`、签名证书、Provisioning Profile、`.env` 或本地配置文件。
- 登录态仅保存在本机 Keychain，不应提交到 Git。
- 如果 fork 或二次开发，请自行检查是否引入了个人账号、token、证书或本地路径。

## 致谢

感谢以下开源项目与社区实现带来的启发和支持：

- [PiliPlus](https://github.com/bggRGjQaUbCoE/PiliPlus)
- [MiniBili](https://github.com/ResistanceTo/MiniBili-WEB)
- [PiliPod](https://github.com/BPTPW/PiliPod)

## 许可证

本项目采用 [GNU General Public License v3.0](https://www.gnu.org/licenses/gpl-3.0.html)（GPL-3.0-only）开源。你可以在遵守协议的前提下学习、复制、修改和分发本项目代码；分发修改版本或基于本项目的作品时，需要保留版权与许可声明，并以同一协议开放对应源代码。

发布源码或二进制产物时，请按 GPLv3 要求一并提供对应源代码、许可文本和必要的构建说明。

本项目引用或参考的第三方项目保留各自版权与许可，使用时请同时遵循对应项目的开源协议和服务条款。

## Support / 支持

CiliCili 的源码可以免费阅读、使用和改造，但开发、调试和持续维护用掉的 AI Token 并不会自己续费。如果这个项目确实帮到了你，欢迎通过 Star、反馈、分享，或自愿赞助来支持它继续慢慢变好；不赞助也完全没关系，每一种支持都很珍贵。

Support is always optional. If CiliCili saves you a little time or makes watching videos more comfortable, a Star, an Issue, a share, or a small contribution all help keep the project moving.

[查看支持方式与支付宝二维码](SUPPORT.md)
