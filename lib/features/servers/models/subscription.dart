/// 订阅模型
class Subscription {
  final String id;
  final String subscriptionUrl;
  final String? universalUrl; // 通用订阅URL（Base64格式）
  final DateTime expireTime;
  final bool isActive;
  final String status;
  final int deviceLimit;
  final int? usedDevices;

  Subscription({
    required this.id,
    required this.subscriptionUrl,
    this.universalUrl,
    required this.expireTime,
    required this.isActive,
    required this.status,
    required this.deviceLimit,
    this.usedDevices,
  });

  factory Subscription.fromJson(Map<String, dynamic> json) {
    return Subscription(
      id: json['id']?.toString() ?? '',
      subscriptionUrl: json['subscription_url'] as String? ?? '',
      universalUrl: json['universal_url'] as String?,
      expireTime: json['expire_time'] != null
          ? DateTime.parse(json['expire_time'] as String)
          : DateTime.now(),
      isActive: json['is_active'] as bool? ?? false,
      status: json['status'] as String? ?? 'inactive',
      deviceLimit: json['device_limit'] as int? ?? 0,
      usedDevices: json['used_devices'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'subscription_url': subscriptionUrl,
      'universal_url': universalUrl,
      'expire_time': expireTime.toIso8601String(),
      'is_active': isActive,
      'status': status,
      'device_limit': deviceLimit,
      'used_devices': usedDevices,
    };
  }

  /// 是否过期
  bool get isExpired => expireTime.isBefore(DateTime.now());

  /// 剩余天数
  int get remainingDays {
    final now = DateTime.now();
    if (expireTime.isBefore(now)) return 0;
    return expireTime.difference(now).inDays;
  }
}

