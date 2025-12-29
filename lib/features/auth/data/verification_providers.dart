import 'package:hiddify/core/http_client/http_client_provider.dart';
import 'package:hiddify/features/auth/data/verification_api.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'verification_providers.g.dart';

@Riverpod(keepAlive: true)
VerificationApi verificationApi(VerificationApiRef ref) {
  const baseUrl = 'https://dy.moneyfly.top';
  return VerificationApi(
    httpClient: ref.watch(httpClientProvider),
    baseUrl: baseUrl,
  );
}

