# SuperHUT - 湖南工业大学学生一站式服务APP

<div align="center">

![SuperHUT Logo](assets/icon/logo.png)

**为湖南工业大学学生打造的第三方一站式服务应用**

[![Flutter](https://img.shields.io/badge/Flutter-3.47.0%2B-blue.svg)](https://flutter.dev/)
[![Dart](https://img.shields.io/badge/Dart-3.13.0%2B-blue.svg)](https://dart.dev/)
[![License](https://img.shields.io/badge/GPL-3.0-green.svg)](LICENSE)
[![Version](https://img.shields.io/badge/Version-1.6.1-brightgreen.svg)](pubspec.yaml)

</div>

## 📱 项目简介

SuperHUT 是专为湖南工业大学学生开发的第三方一站式服务应用。由于官方APP用户体验不佳，我们开发了这个功能更完善、界面更友好的替代方案。

## ✨ 主要功能

### 🎓 学习服务
- **📅 课表查询** - 查看个人课程安排，支持桌面小部件
- **📊 成绩查询** - 实时查询各学期成绩和学分
- **📝 考试安排** - 查看考试时间表和考场信息
- **🏫 空教室查询** - 快速查找可用教室，支持按教学楼筛选

### 🏠 生活服务
- **💧 宿舍喝水** - 一键购买宿舍饮用水
- **🚿 洗澡服务** - 便捷的洗澡卡充值和管理
- **⚡ 电费充值** - 宿舍电费查询和在线充值
- **💧 水费管理** - 宿舍水费查询和充值服务

### 📋 其他功能
- **📝 学生评教** - 参与课程评价和教学质量反馈
- **🔐 统一登录** - 支持HUT统一身份认证系统
- **🌙 深色模式** - 支持明暗主题切换
- **📱 桌面小部件** - 课表信息快速查看
- **🔔 智能提醒** - 电费预警、课程提醒等功能

## 🛠️ 技术栈

- **框架**: Flutter 3.47.0+（Dart 3.13.0+）
- **状态管理**: GetX
- **网络请求**: Dio
- **本地存储**: SharedPreferences（应用设置）、flutter_secure_storage（登录凭据与令牌）
- **WebView**: flutter_inappwebview、webview_flutter
- **UI组件**: Material Design 3
- **主题**: FlexColorScheme
- **图标**: Ionicons
- **二维码**: qr_code_scanner

## 📦 安装说明

### 环境要求

SDK 下限以当前 [pubspec.lock](pubspec.lock) 的 `sdks` 字段为准；更新依赖时请同步核对环境要求。

#### 通用工具

- **Flutter SDK**：3.47.0 或更高的兼容稳定版，并将其 `bin` 目录加入 PATH。
- **Dart SDK**：`>=3.13.0 <4.0.0`，随 Flutter SDK 提供，无需单独安装。
- **Git**：用于克隆仓库和拉取 Git 来源的依赖。
- **编辑器**：Android Studio 或 VS Code，并安装 Flutter / Dart 插件；编辑器插件不能替代 Flutter SDK。

#### Android 开发

通过 Android Studio 的 SDK Manager 安装所需组件：

| 组件 | 当前构建要求 |
| --- | --- |
| Android SDK Platform | API 36（`compileSdk = 36`） |
| Android SDK Build-Tools | 36.0.0（AGP 9.1 默认版本） |
| Android NDK | 28.2.13676358 |
| JDK | 17 或与 Gradle 9.3.1 兼容的版本，可使用 Android Studio 自带的 JDK |

配置来源：[Android 应用配置](android/app/build.gradle.kts)、[Gradle Wrapper 配置](android/gradle/wrapper/gradle-wrapper.properties)和[Gradle 插件配置](android/settings.gradle.kts)。Gradle 9.3.1、AGP 9.1.0 和 Kotlin 2.4.0 已由项目配置管理，无需单独安装 Gradle 或 Kotlin 编译器。

准备开启 USB 调试的 Android 真机，或安装 Android Emulator 及系统镜像。Windows 环境若提示缺少符号链接权限，请按 Flutter 提示配置开发者模式。完整步骤见 [Flutter Android 环境配置](https://docs.flutter.dev/platform-integration/android/setup)。

#### iOS 开发（仅 macOS）

本地编译和调试 iOS 需要 macOS、与所用 Flutter SDK 兼容的 Xcode 及命令行工具、CocoaPods，以及 iOS 模拟器或真机。

当前 [iOS 构建工作流](.github/workflows/build-ios-ipa.yml)使用 `macos-15-intel`、`latest-stable` Xcode 和 Flutter stable，可作为工具链配置参考。详细步骤见 [Flutter iOS 环境配置](https://docs.flutter.dev/platform-integration/ios/setup)。

### 安装步骤

1. **克隆项目**
```bash
git clone https://github.com/cc2562/superhut.git
cd superhut
```

2. **检查开发环境**

```bash
flutter --version
flutter doctor -v

# Android 开发：阅读并接受 SDK 许可
flutter doctor --android-licenses
```

按目标平台处理 `flutter doctor` 提示的问题，再继续安装依赖。

3. **安装依赖并运行测试**

```bash
flutter pub get
flutter test
```

4. **运行项目**

```bash
# 查看已连接的真机和模拟器
flutter devices

# 调试模式
flutter run

# 发布模式：使用受支持的真机
flutter run --release
```

### 构建发布版本

```bash
# Android APK
flutter build apk --release

# Android App Bundle
flutter build appbundle --release

# iOS（仅 macOS，需要配置签名）
flutter build ios --release

# iOS：仅验证编译，不签名
flutter build ios --release --no-codesign
```

Android 正式发布前需要配置本地 `android/key.properties` 和签名密钥；当前工程在未配置正式签名时使用 debug 签名。iOS 真机安装和分发也需要相应的签名配置。

## 🚀 开发指南

### 添加新功能
1. 在 `lib/pages/` 下创建新的功能模块
2. 在 `lib/home/Functionpage/view.dart` 中添加功能入口
3. 更新路由配置和状态管理

### 代码规范
- 使用 GetX 进行状态管理
- 遵循 Flutter 官方代码规范
- 使用有意义的方法和变量命名
- 添加适当的注释和文档

## 🤝 贡献指南

我们欢迎所有形式的贡献！

1. Fork 本项目
2. 创建功能分支
3. 提交更改
4. 推送到分支
5. 开启 Pull Request

## 📄 许可证

本项目采用 GPL-3.0 license - 查看 [LICENSE](https://github.com/cc2562/superhut/blob/master/LICENSE) 文件了解详情

## ⚖️ 法律

- [用户协议](assets/UserAgreement.md)
- [隐私政策](assets/PrivacyAgreement.md)

## 🙏 致谢

- 感谢所有为项目做出贡献的开发者
- 感谢Flutter团队提供的优秀框架

## 📞 联系我们

- **项目主页**: [GitHub Repository](https://github.com/cc2562/superhut)
- **问题反馈**: [Issues](https://github.com/cc2562/superhut/issues)
- **邮箱**: syywqs@foxmail.com



---

<div align="center">

**⭐ 如果这个项目对你有帮助，请给我们一个星标！**

Made with ❤️ for HUT Students
</div>
