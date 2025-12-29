# 构建错误修复指南

## 主要问题

### 1. 代码生成文件缺失
需要运行代码生成来生成以下文件：
- `lib/features/auth/model/auth_entity.freezed.dart`
- `lib/features/auth/model/auth_entity.g.dart`
- `lib/features/auth/model/auth_failure.freezed.dart`
- `lib/features/auth/data/auth_data_providers.g.dart`
- `lib/features/auth/notifier/auth_notifier.g.dart`
- `lib/features/auth/data/verification_providers.g.dart`
- `lib/features/shop/data/package_data_providers.g.dart`
- `lib/core/router/routes.g.dart`
- `lib/core/router/app_router.g.dart`

### 2. 已修复的问题

#### 2.1 重置密码API字段名
- ✅ 修复：`code` → `verification_code`
- ✅ 修复：`password` → `new_password`

#### 2.2 错误处理
- ✅ 修复：`AuthFailure.present()` 返回 record，不是 String
- ✅ 修复：使用 `translationsProvider` 而不是 `const TranslationsEn()`
- ✅ 修复：`t.failure.network` → `t.failure.unexpected`（因为 translations 中没有 network 字段）

#### 2.3 路由配置
- ✅ 已添加忘记密码和重置密码路由
- ⚠️ 需要运行代码生成来生成 `$forgotPasswordRoute` 和 `$resetPasswordRoute`

#### 2.4 PackageListDialog
- ✅ 修复：使用 `switch` 语句替代 `.when()` 方法处理 `AsyncValue`

## 修复步骤

### 步骤 1: 运行代码生成

```bash
cd /Users/apple/Downloads/hiddify-app-main
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
```

### 步骤 2: 如果代码生成失败，检查依赖

确保 `pubspec.yaml` 中包含：
- `build_runner: ^2.4.8`
- `freezed: ^2.4.7`
- `freezed_annotation: ^2.4.1`
- `riverpod_annotation: ^2.3.4`

### 步骤 3: 构建项目

```bash
flutter clean
flutter pub get
flutter build apk --debug
```

## 待修复的编译错误

1. **路由生成错误** - 需要运行代码生成
2. **Freezed 类错误** - 需要运行代码生成
3. **Riverpod 提供者错误** - 需要运行代码生成

## 注意事项

- 所有 API 基础 URL 已配置为 `https://dy.moneyfly.top`
- 验证码功能逻辑已完整实现
- 路由配置已添加，但需要代码生成

