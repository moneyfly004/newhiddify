import 'package:hiddify/core/http_client/http_client_provider.dart';
import 'package:hiddify/features/auth/data/auth_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'auth_data_providers.g.dart';

@Riverpod(keepAlive: true)
AuthRepository authRepository(AuthRepositoryRef ref) {
  // TODO: 从配置或环境变量获取baseUrl
  const baseUrl = 'https://dy.moneyfly.top';
  return AuthRepositoryImpl(
    httpClient: ref.watch(httpClientProvider),
    baseUrl: baseUrl,
  );
}

