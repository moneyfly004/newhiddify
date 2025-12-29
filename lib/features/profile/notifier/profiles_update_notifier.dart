import 'package:dartx/dartx.dart';
import 'package:hiddify/core/preferences/general_preferences.dart';
import 'package:hiddify/core/preferences/preferences_provider.dart';
import 'package:hiddify/features/auth/notifier/auth_notifier.dart';
import 'package:hiddify/features/profile/data/profile_data_providers.dart';
import 'package:hiddify/features/profile/model/profile_entity.dart';
import 'package:hiddify/features/subscription/notifier/auto_subscription_notifier.dart';
import 'package:hiddify/utils/custom_loggers.dart';
import 'package:meta/meta.dart';
import 'package:neat_periodic_task/neat_periodic_task.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'profiles_update_notifier.g.dart';

typedef ProfileUpdateStatus = ({String name, bool success});

@Riverpod(keepAlive: true)
class ForegroundProfilesUpdateNotifier
    extends _$ForegroundProfilesUpdateNotifier with AppLogger {
  static const prefKey = "profiles_update_check";
  static const interval = Duration(minutes: 15);

  @override
  Stream<ProfileUpdateStatus?> build() {
    var cycleCount = 0;
    _scheduler = NeatPeriodicTaskScheduler(
      name: 'profiles update worker',
      interval: interval,
      timeout: const Duration(minutes: 5),
      task: () async {
        loggy.debug("cycle [${cycleCount++}]");
        await updateProfiles();
      },
    );

    ref.onDispose(() async {
      await _scheduler?.stop();
      _scheduler = null;
    });

    if (ref.watch(Preferences.introCompleted)) {
      loggy.debug("intro done, starting");
      _scheduler?.start();
      
      // 检查登录状态，如果已登录则自动获取订阅
      ref.listen(authNotifierProvider, (previous, next) {
        if (next.valueOrNull != null) {
          // 用户已登录，触发自动订阅获取
          ref.read(autoSubscriptionNotifierProvider.notifier).refreshSubscription();
        }
      });
      
      // 如果当前已登录，立即获取订阅
      final authState = ref.read(authNotifierProvider);
      if (authState.valueOrNull != null) {
        ref.read(autoSubscriptionNotifierProvider.notifier).refreshSubscription();
      }
    } else {
      loggy.debug("intro in process, skipping");
    }
    return const Stream.empty();
  }

  NeatPeriodicTaskScheduler? _scheduler;
  bool _forceNextRun = false;

  Future<void> trigger() async {
    loggy.debug("triggering update");
    _forceNextRun = true;
    
    // 如果已登录，先刷新订阅
    final authState = ref.read(authNotifierProvider);
    if (authState.valueOrNull != null) {
      await ref.read(autoSubscriptionNotifierProvider.notifier).refreshSubscription();
    }
    
    await _scheduler?.trigger();
  }

  @visibleForTesting
  Future<void> updateProfiles() async {
    var force = false;
    if (_forceNextRun) {
      force = true;
      _forceNextRun = false;
    }

    try {
      final previousRun = DateTime.tryParse(
        ref.read(sharedPreferencesProvider).requireValue.getString(prefKey) ??
            "",
      );

      if (!force &&
          previousRun != null &&
          previousRun.add(interval) > DateTime.now()) {
        loggy.debug("too soon! previous run: [$previousRun]");
        return;
      }
      loggy.debug(
        "${force ? "[FORCED] " : ""}running, previous run: [$previousRun]",
      );

      final remoteProfiles = await ref
          .read(profileRepositoryProvider)
          .requireValue
          .watchAll()
          .map(
            (event) => event.getOrElse((f) {
              loggy.error("error getting profiles");
              throw f;
            }).whereType<RemoteProfileEntity>(),
          )
          .first;

      await for (final profile in Stream.fromIterable(remoteProfiles)) {
        final updateInterval = profile.options?.updateInterval;
        if (force ||
            updateInterval != null &&
                updateInterval <=
                    DateTime.now().difference(profile.lastUpdate)) {
          await ref
              .read(profileRepositoryProvider)
              .requireValue
              .updateSubscription(profile)
              .mapLeft(
            (l) {
              loggy.debug("error updating profile [${profile.id}]", l);
              state = AsyncData((name: profile.name, success: false));
            },
          ).map(
            (_) {
              loggy.debug("profile [${profile.id}] updated successfully");
              state = AsyncData((name: profile.name, success: true));
            },
          ).run();
        } else {
          loggy.debug(
            "skipping profile [${profile.id}] update. last successful update: [${profile.lastUpdate}] - interval: [${profile.options?.updateInterval}]",
          );
        }
      }
    } finally {
      await ref
          .read(sharedPreferencesProvider)
          .requireValue
          .setString(prefKey, DateTime.now().toIso8601String());
    }
  }
}
