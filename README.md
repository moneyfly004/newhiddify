# Proxy App - 现代化代理客户端

一个基于 Flutter 开发的跨平台代理客户端，支持 Android 和桌面平台，集成 Sing-box 和 Clash Meta 双内核。

## 🎯 功能特性

- ✅ **用户认证系统**：登录、注册、找回密码
- ✅ **订阅管理**：自动同步订阅，支持多订阅
- ✅ **节点管理**：节点列表、测速、智能选择
- ✅ **双内核支持**：Sing-box 和 Clash Meta
- ✅ **连接管理**：一键连接/断开，自动重连
- ✅ **测速引擎**：批量测速，智能排序
- ✅ **现代化 UI**：Material Design 3，深色模式支持

## 🏗️ 技术架构

### 技术栈

- **框架**: Flutter 3.5+
- **状态管理**: BLoC (flutter_bloc)
- **网络请求**: Dio + Retrofit
- **本地存储**: SharedPreferences + Hive
- **路由**: go_router
- **依赖注入**: get_it

### 项目结构

```
lib/
├── core/                    # 核心模块
│   ├── di/                  # 依赖注入
│   ├── models/              # 核心模型
│   ├── services/            # 核心服务
│   └── utils/               # 工具类
├── data/                    # 数据层
│   └── remote/              # API 客户端
├── features/                # 功能模块
│   ├── auth/                # 认证模块
│   ├── connection/          # 连接管理
│   ├── servers/             # 服务器/节点管理
│   ├── speed_test/          # 测速功能
│   └── settings/            # 设置
└── ui/                      # UI 层
    ├── router/              # 路由配置
    ├── theme/               # 主题配置
    └── widgets/             # 通用组件
```

## 🚀 快速开始

### 环境要求

- Flutter SDK 3.5.3 或更高版本
- Dart 3.0.0 或更高版本
- Android Studio / VS Code
- Android SDK (Android 开发)
- Xcode (iOS/macOS 开发，仅 macOS)

### 安装步骤

1. **克隆项目**
```bash
cd /Users/apple/myapk
```

2. **安装依赖**
```bash
flutter pub get
```

3. **生成代码**
```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

4. **运行应用**
```bash
# Android
flutter run

# 桌面 (macOS/Windows/Linux)
flutter run -d macos
flutter run -d windows
flutter run -d linux
```

## 📱 平台支持

- ✅ Android (API 21+)
- ✅ macOS
- ✅ Windows
- ✅ Linux

## 🔧 配置

### API 配置

默认 API 地址：`https://dy.moneyfly.top/api/v1`

如需修改，请编辑 `lib/data/remote/api_client.dart`：

```dart
const String baseUrl = 'https://your-api-domain.com/api/v1';
```

### Android 配置

确保 `android/app/src/main/AndroidManifest.xml` 包含必要的权限：

```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>
```

## 🏗️ 开发指南

### 添加新功能

1. 在 `lib/features/` 下创建新的功能模块
2. 实现 Repository 接口和实现类
3. 创建 BLoC/Cubit 管理状态
4. 实现 UI 页面
5. 在路由中注册新页面

### 代码生成

项目使用代码生成工具，修改模型后需要运行：

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

### 测试

```bash
flutter test
```

## 📦 构建发布

### Android APK

```bash
flutter build apk --release
```

### Android App Bundle

```bash
flutter build appbundle --release
```

### macOS

```bash
flutter build macos --release
```

### Windows

```bash
flutter build windows --release
```

## 🔐 安全注意事项

- 用户密码使用 bcrypt 哈希存储（后端）
- API 通信使用 HTTPS
- Token 存储在安全的本地存储中
- 配置文件加密存储

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

## 📄 许可证

本项目采用 MIT 许可证。

## 📞 支持

如有问题，请提交 Issue 或联系开发团队。

---

**注意**: 本项目需要配合 goweb 后端使用。后端代码位于 `/Users/apple/Downloads/goweb`。
