import 'dart:async';
import '../utils/logger.dart';
import '../utils/cache_manager.dart';
import '../../features/servers/repositories/subscription_repository.dart';
import '../../features/servers/models/subscription.dart';
import 'incremental_updater.dart';

/// 订阅更新器
class SubscriptionUpdater {
  final SubscriptionRepository _repository;
  Timer? _updateTimer;
  bool _isUpdating = false;
  final _updateController = StreamController<UpdateProgress>.broadcast();

  SubscriptionUpdater(this._repository);

  /// 更新进度流
  Stream<UpdateProgress> get updateStream => _updateController.stream;

  /// 是否正在更新
  bool get isUpdating => _isUpdating;

  /// 启动自动更新（每30分钟）
  void startAutoUpdate({Duration interval = const Duration(minutes: 30)}) {
    _updateTimer?.cancel();
    _updateTimer = Timer.periodic(interval, (timer) {
      updateSubscriptions();
    });
    Logger.info('自动更新已启动，间隔: ${interval.inMinutes} 分钟');
  }

  /// 停止自动更新
  void stopAutoUpdate() {
    _updateTimer?.cancel();
    _updateTimer = null;
    Logger.info('自动更新已停止');
  }

  /// 更新订阅
  Future<void> updateSubscriptions() async {
    if (_isUpdating) {
      Logger.warning('订阅正在更新中，跳过本次更新');
      return;
    }

    _isUpdating = true;
    _updateController.add(UpdateProgress(
      status: UpdateStatus.updating,
      message: '开始更新订阅...',
    ));

    try {
      // 获取订阅列表
      final subscriptions = await _repository.getSubscriptions();

      if (subscriptions.isEmpty) {
        _updateController.add(UpdateProgress(
          status: UpdateStatus.completed,
          message: '暂无订阅',
        ));
        return;
      }

      int successCount = 0;
      int failCount = 0;

      for (int i = 0; i < subscriptions.length; i++) {
        final subscription = subscriptions[i];
        
        _updateController.add(UpdateProgress(
          status: UpdateStatus.updating,
          message: '更新订阅 ${i + 1}/${subscriptions.length}...',
          current: i + 1,
          total: subscriptions.length,
        ));

        try {
          // 获取最新配置（这会触发后端更新）
          final newConfig = await _repository.getClashConfig(subscription.subscriptionUrl);
          
          // 检测增量变更
          final change = await IncrementalUpdater.detectChanges(subscription, newConfig);
          
          if (change.hasChanges) {
            Logger.info('订阅 ${subscription.id} 有变更: 新增 ${change.addedNodes.length}, 删除 ${change.removedNodes.length}, 修改 ${change.modifiedNodes.length}');
            
            // 通知变更
            _updateController.add(UpdateProgress(
              status: UpdateStatus.updating,
              message: '订阅 ${i + 1}/${subscriptions.length} 有 ${change.totalChanges} 个变更',
              current: i + 1,
              total: subscriptions.length,
              change: change,
            ));
          }
          
          // 清除缓存，强制下次获取最新数据
          await CacheManager.clearCache('subscriptions');
          
          successCount++;
        } catch (e) {
          Logger.error('更新订阅失败: ${subscription.subscriptionUrl}', e);
          failCount++;
        }
      }

      _updateController.add(UpdateProgress(
        status: UpdateStatus.completed,
        message: '更新完成: 成功 $successCount, 失败 $failCount',
        successCount: successCount,
        failCount: failCount,
      ));

      Logger.info('订阅更新完成: 成功 $successCount, 失败 $failCount');
    } catch (e) {
      Logger.error('订阅更新失败', e);
      _updateController.add(UpdateProgress(
        status: UpdateStatus.failed,
        message: '更新失败: $e',
      ));
    } finally {
      _isUpdating = false;
    }
  }

  /// 更新单个订阅
  Future<bool> updateSubscription(Subscription subscription) async {
    try {
      await _repository.getClashConfig(subscription.subscriptionUrl);
      await CacheManager.clearCache('subscriptions');
      return true;
    } catch (e) {
      Logger.error('更新订阅失败', e);
      return false;
    }
  }

  /// 释放资源
  void dispose() {
    stopAutoUpdate();
    _updateController.close();
  }
}

/// 更新进度
class UpdateProgress {
  final UpdateStatus status;
  final String message;
  final int? current;
  final int? total;
  final int? successCount;
  final int? failCount;
  final SubscriptionChange? change;

  UpdateProgress({
    required this.status,
    required this.message,
    this.current,
    this.total,
    this.successCount,
    this.failCount,
    this.change,
  });

  /// 进度百分比
  double get progress {
    if (current != null && total != null && total! > 0) {
      return current! / total!;
    }
    return 0.0;
  }
}

/// 更新状态
enum UpdateStatus {
  updating,
  completed,
  failed,
}

