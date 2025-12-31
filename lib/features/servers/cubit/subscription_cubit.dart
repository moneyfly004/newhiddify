import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../models/subscription.dart';
import '../repositories/subscription_repository.dart';
import '../../../core/services/base64_subscription_parser.dart';

/// 订阅状态
abstract class SubscriptionState extends Equatable {
  const SubscriptionState();

  @override
  List<Object?> get props => [];
}

/// 订阅加载中
class SubscriptionLoading extends SubscriptionState {}

/// 订阅加载成功
class SubscriptionLoaded extends SubscriptionState {
  final List<Subscription> subscriptions;
  final Subscription? currentSubscription;

  const SubscriptionLoaded({
    required this.subscriptions,
    this.currentSubscription,
  });

  @override
  List<Object?> get props => [subscriptions, currentSubscription];
}

/// 订阅错误
class SubscriptionError extends SubscriptionState {
  final String message;

  const SubscriptionError(this.message);

  @override
  List<Object?> get props => [message];
}

/// 订阅 Cubit
class SubscriptionCubit extends Cubit<SubscriptionState> {
  final SubscriptionRepository _repository;

  SubscriptionCubit(this._repository) : super(SubscriptionLoading()) {
    loadSubscriptions();
  }

  /// 加载订阅列表
  Future<void> loadSubscriptions() async {
    try {
      emit(SubscriptionLoading());
      final subscriptions = await _repository.getSubscriptions();
      
      // 自动选择第一个有效订阅
      Subscription? current;
      for (var sub in subscriptions) {
        if (sub.isActive && !sub.isExpired) {
          current = sub;
          break;
        }
      }
      
      emit(SubscriptionLoaded(
        subscriptions: subscriptions,
        currentSubscription: current,
      ));

      // 如果有有效订阅，自动获取并解析通用订阅（Base64 格式）
      if (current != null) {
        await _loadUniversalSubscription(current);
      }
    } catch (e) {
      emit(SubscriptionError(e.toString()));
    }
  }

  /// 加载通用订阅（Base64 格式）
  Future<void> _loadUniversalSubscription(Subscription subscription) async {
    try {
      // 获取通用订阅地址（Base64 编码的节点）
      final base64Content = await _repository.getUniversalConfig(
        subscription.subscriptionUrl,
      );

      // 解析 Base64 订阅内容
      // 注意：这里解析的节点需要传递给 NodeCubit
      // 由于架构限制，节点解析将在连接时进行
    } catch (e) {
      // 静默失败，不影响订阅加载
      print('加载通用订阅失败: $e');
    }
  }

  /// 选择订阅
  void selectSubscription(Subscription subscription) {
    final currentState = state;
    if (currentState is SubscriptionLoaded) {
      emit(SubscriptionLoaded(
        subscriptions: currentState.subscriptions,
        currentSubscription: subscription,
      ));
    }
  }
}

