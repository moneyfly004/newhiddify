import 'dart:async';

/// 重试助手
class RetryHelper {
  /// 带重试的执行
  static Future<T> retry<T>({
    required Future<T> Function() action,
    int maxRetries = 3,
    Duration delay = const Duration(seconds: 1),
    bool Function(dynamic error)? shouldRetry,
  }) async {
    int attempts = 0;
    
    while (attempts < maxRetries) {
      try {
        return await action();
      } catch (e) {
        attempts++;
        
        // 检查是否应该重试
        if (shouldRetry != null && !shouldRetry(e)) {
          rethrow;
        }
        
        // 如果已达到最大重试次数，抛出异常
        if (attempts >= maxRetries) {
          rethrow;
        }
        
        // 等待后重试
        await Future.delayed(delay * attempts);
      }
    }
    
    throw Exception('重试失败');
  }

  /// 指数退避重试
  static Future<T> retryWithExponentialBackoff<T>({
    required Future<T> Function() action,
    int maxRetries = 3,
    Duration initialDelay = const Duration(seconds: 1),
    bool Function(dynamic error)? shouldRetry,
  }) async {
    return retry(
      action: action,
      maxRetries: maxRetries,
      delay: initialDelay,
      shouldRetry: shouldRetry,
    );
  }
}

