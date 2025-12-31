# 协议支持和格式转换完成

## ✅ 已实现的协议支持

### 1. 完整协议列表
- ✅ **VMess** - 完整支持
- ✅ **VLESS** - 完整支持
- ✅ **Trojan** - 完整支持
- ✅ **Shadowsocks (SS)** - 完整支持
- ✅ **ShadowsocksR (SSR)** - 完整支持
- ✅ **Hysteria/Hysteria2** - 基础支持
- ✅ **TUIC** - 基础支持

### 2. 传输协议支持
- ✅ **TCP** - 默认传输
- ✅ **WebSocket (ws)** - 完整支持
- ✅ **HTTP/2 (h2)** - 完整支持
- ✅ **gRPC** - 完整支持
- ✅ **QUIC** - 基础支持

### 3. TLS 配置支持
- ✅ **TLS 启用/禁用**
- ✅ **SNI 配置**
- ✅ **证书验证跳过**
- ✅ **ALPN 配置**
- ✅ **Reality 配置**（VLESS）

## 🔄 格式转换机制

### Clash → Sing-box 转换
```dart
// 使用 ProtocolConverter
final singboxNode = ProtocolConverter.clashToSingbox(clashNode);
```

**转换内容**：
- 协议类型转换
- 传输协议转换（ws/h2/grpc）
- TLS 配置转换
- Reality 配置转换

### Sing-box → Clash 转换
```dart
// 使用 ProtocolConverter
final clashNode = ProtocolConverter.singboxToClash(singboxNode);
```

**转换内容**：
- 协议类型转换
- 传输协议转换
- TLS 配置转换
- Reality 配置转换

## 📋 协议转换详情

### VMess 转换
**Clash → Sing-box**:
- `type: vmess` → `type: vmess`
- `uuid` → `uuid`
- `cipher` → `security`
- `alterId` → `alter_id`
- `network: ws` → `transport: {type: ws}`
- `tls: true` → `tls: {enabled: true}`

**Sing-box → Clash**:
- `type: vmess` → `type: vmess`
- `uuid` → `uuid`
- `security` → `cipher`
- `alter_id` → `alterId`
- `transport: {type: ws}` → `network: ws`
- `tls: {enabled: true}` → `tls: true`

### VLESS 转换
**Clash → Sing-box**:
- `type: vless` → `type: vless`
- `uuid` → `uuid`
- `flow` → `flow`
- `network: ws` → `transport: {type: ws}`
- `tls: true` → `tls: {enabled: true}` (必需)

**Sing-box → Clash**:
- `type: vless` → `type: vless`
- `uuid` → `uuid`
- `flow` → `flow`
- `transport: {type: ws}` → `network: ws`
- `tls: {enabled: true}` → `tls: true`

### Trojan 转换
**Clash → Sing-box**:
- `type: trojan` → `type: trojan`
- `password` → `password`
- `network: ws` → `transport: {type: ws}`
- `tls: true` → `tls: {enabled: true}` (必需)

**Sing-box → Clash**:
- `type: trojan` → `type: trojan`
- `password` → `password`
- `transport: {type: ws}` → `network: ws`
- `tls: {enabled: true}` → `tls: true`

## 🎯 内核切换流程

### 切换步骤
1. **检测需要切换**
   - 当前内核 ≠ 目标内核

2. **获取订阅内容**
   - 从 Base64 订阅获取节点列表

3. **解析节点**
   - 使用 Base64SubscriptionParser 解析
   - 提取所有协议参数

4. **选择节点**
   - 使用指定节点或自动选择

5. **生成目标格式配置**
   - Sing-box → 生成 JSON
   - Clash Meta → 生成 YAML
   - 自动转换所有协议参数

6. **执行无缝切换**
   - 启动新内核
   - 验证连接
   - 停止旧内核

## 📝 关键代码

### 协议转换器
```dart
// 创建 ProtocolConverter
final converter = ProtocolConverter();

// Clash → Sing-box
final singboxNode = converter.clashToSingbox(clashNode);

// Sing-box → Clash
final clashNode = converter.singboxToClash(singboxNode);
```

### 内核切换
```dart
// 在 ConnectionManager 中
await _switchKernelWithConversion(
  targetKernel: KernelType.mihomo,
  subscription: subscription,
  node: node,
  mode: ConnectionMode.rules,
);
```

### 配置生成
```dart
// 根据内核类型自动生成正确格式
final config = await KernelConfigGenerator.generateConfig(
  kernelType: _kernelManager.currentKernel,
  subscription: subscription,
  mode: mode,
  selectedNode: node,
);
```

## ⚠️ 注意事项

1. **协议兼容性**
   - 所有协议都支持双向转换
   - 传输协议完整转换
   - TLS 配置完整转换

2. **格式正确性**
   - Sing-box 使用 JSON 格式
   - Clash Meta 使用 YAML 格式
   - 自动验证配置格式

3. **无缝切换**
   - 先启动新内核
   - 验证连接成功
   - 再停止旧内核
   - 失败时自动回滚

## 🚀 使用示例

```dart
// 切换内核（自动转换格式）
await connectionManager.connect(
  subscription: subscription,
  node: node,
  kernelType: KernelType.mihomo, // 从 Sing-box 切换到 Clash Meta
  mode: ConnectionMode.rules,
);

// 所有协议参数会自动转换：
// - VMess/VLESS/Trojan 节点
// - WebSocket/HTTP2/gRPC 传输
// - TLS/Reality 配置
```

---

**实现时间**: 2024-12-22
**状态**: ✅ 已完成

