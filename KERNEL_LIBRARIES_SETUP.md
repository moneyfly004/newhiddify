# 内核库文件设置说明

## ✅ 已完成

1. **已复制 libcore.aar**：从 NekoBoxForAndroid 复制到 `android/app/libs/`
2. **已添加依赖**：在 `android/app/build.gradle` 中添加了 `libcore.aar` 依赖
3. **已创建 jniLibs 目录结构**：为将来可能的 .so 文件预留位置

## 当前状态

应用现在使用 `libcore.aar`（包含 sing-box 核心功能），而不是独立的 .so 文件。

## 下一步

需要修改 `MainActivity.kt` 以使用 `libcore.aar` 的 API：

1. 导入 `libcore` 包
2. 实现 `LocalDNSTransport` 接口（或使用简单的实现）
3. 使用 `Libcore.newSingBoxInstance()` 创建 sing-box 实例
4. 调用 `box.start()` 启动代理

## 参考代码

参考 NekoBoxForAndroid 的实现：
- `app/src/main/java/io/nekohasekai/sagernet/bg/proto/BoxInstance.kt`
- `app/src/main/java/moe/matsuri/nb4a/net/LocalResolverImpl.kt`

## 注意

- `libcore.aar` 已经包含了 sing-box 的所有功能
- 不需要单独的 `libsingbox.so` 或 `libmihomo.so` 文件
- 如果将来需要支持 Clash Meta (mihomo)，可能需要额外的库或使用不同的实现方式
