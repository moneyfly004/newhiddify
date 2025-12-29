import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:dio_smart_retry/dio_smart_retry.dart';
import 'package:hiddify/utils/custom_loggers.dart';

class DioHttpClient with InfraLogger {
  final Map<String, Dio> _dio = {};
  String? _accessToken;

  DioHttpClient({
    required Duration timeout,
    required String userAgent,
    required bool debug,
  }) {
    for (final mode in ["proxy", "direct", "both"]) {
      _dio[mode] = Dio(
        BaseOptions(
          connectTimeout: timeout,
          sendTimeout: timeout,
          receiveTimeout: timeout,
          headers: {"User-Agent": userAgent},
        ),
      );
      _dio[mode]!.interceptors.add(
            RetryInterceptor(
              dio: _dio[mode]!,
              retryDelays: [
                const Duration(seconds: 1),
                if (mode != "proxy") ...[
                  const Duration(seconds: 2),
                  const Duration(seconds: 3),
                ],
              ],
            ),
          );

      _dio[mode]!.httpClientAdapter = IOHttpClientAdapter(
        createHttpClient: () {
          final client = HttpClient();
          client.findProxy = (url) {
            if (mode == "proxy") {
              return "PROXY localhost:$port";
            } else if (mode == "direct") {
              return "DIRECT";
            } else {
              return "PROXY localhost:$port; DIRECT";
            }
          };
          return client;
        },
      );
    }

    if (debug) {
      // _dio.interceptors.add(LoggyDioInterceptor(requestHeader: true));
    }
  }

  int port = 0;
  // bool isPortOpen(String host, int port, {Duration timeout = const Duration(milliseconds: 200)}) async{
  //   try {
  //     Socket.connect(host, port, timeout: timeout).then((socket) {
  //       socket.destroy();
  //     });
  //     return true;
  //   } on SocketException catch (_) {
  //     return false;
  //   } catch (_) {
  //     return false;
  //   }
  // }
  Future<bool> isPortOpen(String host, int port, {Duration timeout = const Duration(seconds: 5)}) async {
    try {
      final socket = await Socket.connect(host, port, timeout: timeout);
      await socket.close();
      return true;
    } on SocketException catch (_) {
      return false;
    } catch (_) {
      return false;
    }
  }

  void setProxyPort(int port) {
    this.port = port;
    loggy.debug("setting proxy port: [$port]");
  }

  void setAccessToken(String? token) {
    _accessToken = token;
    loggy.debug("设置AccessToken: ${token != null ? '已设置 (${token.length > 20 ? token.substring(0, 20) + '...' : token})' : '已清除'}");
    // 更新所有Dio实例的headers
    for (final dio in _dio.values) {
      if (token != null) {
        dio.options.headers['Authorization'] = 'Bearer $token';
        loggy.debug("已为Dio实例设置Authorization header");
      } else {
        dio.options.headers.remove('Authorization');
        loggy.debug("已清除Dio实例的Authorization header");
      }
    }
  }

  void clearAccessToken() {
    setAccessToken(null);
  }

  Future<Response<T>> get<T>(
    String url, {
    CancelToken? cancelToken,
    String? userAgent,
    ({String username, String password})? credentials,
    bool proxyOnly = false,
  }) async {
    // 对于外部API请求（非代理订阅），始终使用direct模式
    // 只有当明确需要代理时才使用proxy模式
    final mode = proxyOnly ? "proxy" : "direct"; // 直接连接，不通过本地代理
    final dio = _dio[mode]!;

    loggy.debug("GET请求: url=$url, mode=$mode, proxyOnly=$proxyOnly");
    loggy.debug("Authorization header: ${dio.options.headers['Authorization'] ?? '未设置'}");

    return dio.get<T>(
      url,
      cancelToken: cancelToken,
      options: _options(url, userAgent: userAgent, credentials: credentials),
    );
  }

  Future<Response<T>> post<T>(
    String url, {
    dynamic data,
    CancelToken? cancelToken,
    String? userAgent,
    ({String username, String password})? credentials,
    bool proxyOnly = false,
  }) async {
    // 对于外部API请求（非代理订阅），始终使用direct模式
    // 只有当明确需要代理时才使用proxy模式
    final mode = proxyOnly ? "proxy" : "direct"; // 直接连接，不通过本地代理
    final dio = _dio[mode]!;

    loggy.debug("POST请求: url=$url, mode=$mode, proxyOnly=$proxyOnly");
    loggy.debug("Authorization header: ${dio.options.headers['Authorization'] ?? '未设置'}");

    return dio.post<T>(
      url,
      data: data,
      cancelToken: cancelToken,
      options: _options(url, userAgent: userAgent, credentials: credentials),
    );
  }

  Future<Response> download(
    String url,
    String path, {
    CancelToken? cancelToken,
    String? userAgent,
    ({String username, String password})? credentials,
    bool proxyOnly = false,
  }) async {
    final mode = proxyOnly
        ? "proxy"
        : await isPortOpen("127.0.0.1", port)
            ? "both"
            : "direct";
    final dio = _dio[mode]!;
    return dio.download(
      url,
      path,
      cancelToken: cancelToken,
      options: _options(
        url,
        userAgent: userAgent,
        credentials: credentials,
      ),
    );
  }

  Options _options(
    String url, {
    String? userAgent,
    ({String username, String password})? credentials,
  }) {
    final uri = Uri.parse(url);

    String? userInfo;
    if (credentials != null) {
      userInfo = "${credentials.username}:${credentials.password}";
    } else if (uri.userInfo.isNotEmpty) {
      userInfo = uri.userInfo;
    }

    String? basicAuth;
    if (userInfo != null) {
      basicAuth = "Basic ${base64.encode(utf8.encode(userInfo))}";
    }

    return Options(
      headers: {
        if (userAgent != null) "User-Agent": userAgent,
        if (basicAuth != null) "authorization": basicAuth,
        if (_accessToken != null) "Authorization": "Bearer $_accessToken",
        "Accept": "application/json",
        "Content-Type": "application/json",
      },
    );
  }
}
