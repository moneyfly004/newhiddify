# VPN 连接权限问题修复说明

## 问题描述
连接 VPN 时出现错误：`listen command.sock: listen unix command.sock: bind: permission denied`

## 已实施的修复

### 1. 路径一致性修复
- **文件**: `lib/core/directories/directories_provider.dart`
- **修改**: Android 和 iOS 都通过 method channel 获取路径，确保与原生代码一致
- **文件**: `android/app/src/main/kotlin/com/hiddify/hiddify/PlatformSettingsHandler.kt`
- **修改**: 添加了 `get_paths` 方法，返回正确的内部存储路径

### 2. 使用内部存储目录
- **文件**: `android/app/src/main/kotlin/com/hiddify/hiddify/bg/BoxService.kt`
- **修改**: 
  - 使用 `filesDir/working` 而不是外部存储
  - 确保目录权限正确设置
  - 在启动前清理旧的 socket 文件

### 3. 增强的调试日志
- 添加了详细的日志输出，包括：
  - 目录路径和权限状态
  - Socket 文件清理过程
  - CommandServer 启动过程

## 测试步骤

### 1. 安装应用
```bash
cd /Users/apple/Downloads/hiddify-app-main
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

### 2. 查看实时日志
```bash
# 过滤 BoxService 相关日志
adb logcat | grep -E "A/BoxService|A/VPNService|command.sock"

# 或者查看所有日志
adb logcat -s A/BoxService:* A/VPNService:* AndroidRuntime:E
```

### 3. 测试连接
1. 打开应用
2. 点击"开始连接"
3. 观察日志输出

### 4. 检查目录和文件
```bash
# 进入应用目录
adb shell
run-as com.hiddify.hiddify

# 检查工作目录
ls -la files/working/

# 检查 socket 文件
ls -la files/working/command.sock

# 检查权限
stat files/working/
```

## 如果问题仍然存在

### 检查点 1: 目录权限
```bash
adb shell run-as com.hiddify.hiddify ls -la files/working/
```
应该显示目录有读写执行权限。

### 检查点 2: Socket 文件
```bash
adb shell run-as com.hiddify.hiddify ls -la files/working/command.sock
```
如果文件存在但无法删除，可能需要：
1. 停止应用
2. 手动删除文件
3. 重新启动应用

### 检查点 3: SELinux 策略
```bash
# 检查 SELinux 状态
adb shell getenforce

# 如果是 Enforcing，可以临时设置为 Permissive（仅用于调试）
adb shell setenforce 0
```

### 检查点 4: 应用权限
确保应用已获得 VPN 权限：
1. 设置 → 应用 → Hiddify → 权限
2. 确保 VPN 权限已授予

## 关键日志标签

查看以下标签的日志：
- `A/BoxService`: BoxService 相关日志
- `A/VPNService`: VPNService 相关日志
- `AndroidRuntime`: 运行时错误

## 常见错误和解决方案

### 错误: "permission denied"
- **原因**: 目录或文件权限不足
- **解决**: 确保使用内部存储目录，检查目录权限

### 错误: "file exists"
- **原因**: 旧的 socket 文件未清理
- **解决**: 应用会自动清理，如果失败可以手动删除

### 错误: "bind failed"
- **原因**: Socket 文件路径不正确或权限不足
- **解决**: 检查工作目录路径，确保使用绝对路径

## 联系支持

如果问题仍然存在，请提供：
1. 完整的 logcat 输出（特别是 A/BoxService 标签）
2. 目录权限信息（`ls -la files/working/`）
3. Android 版本和设备型号
4. SELinux 状态（`getenforce`）

