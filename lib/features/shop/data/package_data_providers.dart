import 'package:hiddify/core/http_client/http_client_provider.dart';
import 'package:hiddify/features/shop/data/package_api.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'package_data_providers.g.dart';

@Riverpod(keepAlive: true)
PackageApi packageApi(PackageApiRef ref) {
  const baseUrl = 'https://dy.moneyfly.top';
  return PackageApi(
    httpClient: ref.watch(httpClientProvider),
    baseUrl: baseUrl,
  );
}

@Riverpod(keepAlive: true)
Future<List<Map<String, dynamic>>> packagesList(PackagesListRef ref) async {
  // 优化：keepAlive provider 会保持缓存，减少重复请求
  final packageApi = ref.watch(packageApiProvider);
  return await packageApi.getPackages();
}

