# 通用订阅（Base64）实现说明

## ✅ 已实现功能

### 1. Base64 订阅解析器
- ✅ `Base64SubscriptionParser` - 解析 Base64 编码的订阅内容
- ✅ 支持协议：VMess、VLESS、Trojan、Shadowsocks
- ✅ 自动解码和节点提取

### 2. 登录后自动获取
- ✅ 登录成功后自动加载订阅
- ✅ 自动获取通用订阅地址（Base64 格式）
- ✅ 自动解析节点列表

### 3. 连接管理器更新
- ✅ 只使用通用订阅格式（Base64）
- ✅ 不再使用 Clash 格式
- ✅ 自动解析并生成配置

## 🔄 工作流程

### 登录流程
1. 用户登录
2. `AuthCubit` 发出 `AuthAuthenticated` 状态
3. `HomePage` 监听状态变化
4. 自动创建 `SubscriptionCubit` 和 `NodeCubit`
5. 调用 `loadSubscriptions()` 加载订阅

### 订阅加载流程
1. `SubscriptionCubit.loadSubscriptions()` 获取订阅列表
2. 选择第一个有效订阅
3. 调用 `_loadUniversalSubscription()` 获取通用订阅
4. 使用 `getUniversalConfig()` 获取 Base64 内容
5. 使用 `Base64SubscriptionParser` 解析节点
6. 更新节点列表

### 连接流程
1. 用户点击连接
2. `ConnectionManager.connect()` 被调用
3. 获取通用订阅（Base64 格式）
4. 解析 Base64 内容获取节点
5. 生成内核配置
6. 启动内核

## 📝 API 使用

### 获取通用订阅
```
GET /api/v1/subscriptions/universal/{subscription_url}?t={timestamp}
```

返回：Base64 编码的节点列表（每行一个节点链接）

### 节点链接格式
- `vmess://{base64_json}`
- `vless://{uuid}@{server}:{port}?{params}`
- `trojan://{password}@{server}:{port}?{params}`
- `ss://{method}:{password}@{server}:{port}`

## 🔧 关键代码

### Base64SubscriptionParser
```dart
// 解析 Base64 订阅
final nodes = Base64SubscriptionParser.parseBase64Subscription(base64Content);
```

### 连接管理器
```dart
// 只使用通用订阅格式
final base64Content = await _subscriptionRepository.getUniversalConfig(
  subscription.subscriptionUrl,
);
```

### 订阅 Cubit
```dart
// 登录后自动加载
_subscriptionCubit?.loadSubscriptions();
```

## ⚠️ 注意事项

1. **只使用通用订阅格式**
   - 不再使用 Clash YAML 格式
   - 所有配置都从 Base64 订阅生成

2. **节点解析**
   - 支持多种协议
   - 自动识别节点类型
   - 错误节点会被跳过

3. **自动加载**
   - 登录后自动获取订阅
   - 无需手动刷新
   - 静默失败不影响使用

## 🚀 下一步

1. 测试 Base64 订阅解析
2. 验证节点连接
3. 优化错误处理
4. 添加节点缓存

---

**实现时间**: 2024-12-22
**状态**: ✅ 已完成

