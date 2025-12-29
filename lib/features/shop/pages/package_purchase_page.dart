import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:gap/gap.dart';
import 'package:hiddify/core/http_client/http_client_provider.dart';
import 'package:hiddify/core/preferences/preferences_provider.dart';
import 'package:hiddify/features/auth/data/auth_data_providers.dart';
import 'package:hiddify/features/auth/notifier/auth_notifier.dart';
import 'package:hiddify/features/profile/notifier/active_profile_notifier.dart';
import 'package:hiddify/features/shop/data/package_data_providers.dart';
import 'package:hiddify/utils/custom_loggers.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class PackagePurchasePage extends HookConsumerWidget with InfraLogger {
  final int packageId;
  final Map<String, dynamic> package;

  const PackagePurchasePage({
    super.key,
    required this.packageId,
    required this.package,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final couponCodeController = useTextEditingController();
    final isLoading = useState(false);
    final errorMessage = useState<String?>(null);
    final couponInfo = useState<Map<String, dynamic>?>(null);
    final isVerifyingCoupon = useState(false);
    final couponCodeText = useState('');

    final name = package['name'] as String? ?? '未知套餐';
    final price = (package['price'] as num?)?.toDouble() ?? 0.0;
    final durationDays = (package['duration_days'] as num?)?.toInt() ?? 0;
    final deviceLimit = (package['device_limit'] as num?)?.toInt() ?? 0;
    final description = package['description'] as String? ?? '';

    // 计算最终价格（考虑优惠券折扣）
    final finalPrice = couponInfo.value != null ? (couponInfo.value!['final_amount'] as num?)?.toDouble() ?? price : price;
    final discountAmount = couponInfo.value != null ? (couponInfo.value!['discount_amount'] as num?)?.toDouble() ?? 0.0 : 0.0;

    Future<void> verifyCouponCode() async {
      final code = couponCodeController.text.trim();
      if (code.isEmpty) {
        couponInfo.value = null;
        return;
      }

      isVerifyingCoupon.value = true;
      errorMessage.value = null;

      try {
        final packageApi = ref.read(packageApiProvider);
        final result = await packageApi.verifyCoupon(
          code: code,
          amount: price,
          packageId: packageId,
        );

        if (result != null && context.mounted) {
          couponInfo.value = result;
          loggy.debug("优惠券验证成功: $result");
        } else {
          couponInfo.value = null;
          errorMessage.value = '优惠券验证失败';
        }
      } catch (e) {
        couponInfo.value = null;
        final errorMsg = e.toString();
        if (errorMsg.contains('Exception:')) {
          errorMessage.value = errorMsg.replaceFirst('Exception: ', '');
        } else {
          errorMessage.value = '验证优惠券失败: $errorMsg';
        }
        loggy.error("验证优惠券失败", e, StackTrace.current);
      } finally {
        isVerifyingCoupon.value = false;
      }
    }

    // 显示支付对话框并轮询订单状态
    Future<void> _showPaymentDialog(
      BuildContext context,
      WidgetRef ref,
      String orderNo,
      double amount,
      String qrCodeUrl,
      String? paymentUrl,
    ) async {
      Timer? statusCheckTimer;
      Timer? timeoutTimer;
      bool isPaid = false;
      bool isDisposed = false;

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          // 开始轮询订单状态（优化：使用更长的间隔，减少请求频率）
          statusCheckTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
            if (isDisposed || !context.mounted || isPaid) {
              timer.cancel();
              return;
            }

            try {
              final packageApi = ref.read(packageApiProvider);
              loggy.debug("🔄 轮询订单状态: orderNo=$orderNo");
              final statusData = await packageApi.getOrderStatus(orderNo);

              if (statusData != null && context.mounted && !isDisposed) {
                final status = statusData['status'] as String?;
                loggy.debug("📊 订单状态: orderNo=$orderNo, status=$status");

                if (status == 'paid') {
                  loggy.info("✅ 订单支付成功！orderNo=$orderNo");
                  isPaid = true;
                  timer.cancel();
                  timeoutTimer?.cancel();

                  // 刷新订阅信息
                  loggy.info("🔄 正在刷新订阅信息...");
                  ref.invalidate(activeProfileProvider);
                  loggy.info("✅ 订阅信息已刷新，套餐已生效");

                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop();
                    Navigator.of(context).pop(true); // 返回并刷新
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('支付成功！您的订阅已激活'),
                        backgroundColor: Colors.green,
                        duration: Duration(seconds: 3),
                      ),
                    );
                  }
                } else {
                  loggy.debug("⏳ 订单状态: $status，继续等待支付...");
                }
              }
            } catch (e) {
              loggy.error("❌ 查询订单状态失败: orderNo=$orderNo", e, StackTrace.current);
              // 继续轮询，不中断
            }
          });

          // 30分钟后停止轮询
          timeoutTimer = Timer(const Duration(minutes: 30), () {
            statusCheckTimer?.cancel();
          });

          return AlertDialog(
            title: const Text('订单创建成功'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('订单号: $orderNo'),
                  const Gap(8),
                  Text('金额: ¥${amount.toStringAsFixed(2)}'),
                  const Gap(16),
                  const Text('请扫描二维码完成支付：'),
                  const Gap(8),
                  const Text(
                    '支付成功后，订阅将自动激活',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const Gap(16),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: QrImageView(
                        data: qrCodeUrl,
                        size: 250,
                        backgroundColor: Colors.white,
                      ),
                    ),
                  ),
                  if (paymentUrl != null && paymentUrl.isNotEmpty) ...[
                    const Gap(16),
                    const Text('或点击下方按钮跳转到支付页面：'),
                    const Gap(8),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  isDisposed = true;
                  statusCheckTimer?.cancel();
                  timeoutTimer?.cancel();
                  Navigator.of(dialogContext).pop();
                },
                child: const Text('取消'),
              ),
              if (paymentUrl != null && paymentUrl.isNotEmpty)
                FilledButton.icon(
                  onPressed: () async {
                    final uri = Uri.parse(paymentUrl);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  },
                  icon: const Icon(FluentIcons.open_24_regular),
                  label: const Text('跳转支付'),
                ),
              FilledButton(
                onPressed: () {
                  isDisposed = true;
                  statusCheckTimer?.cancel();
                  timeoutTimer?.cancel();
                  Navigator.of(dialogContext).pop();
                  Navigator.of(context).pop(true); // 返回并刷新
                },
                child: const Text('完成'),
              ),
            ],
          );
        },
      ).then((_) {
        // 确保对话框关闭时清理定时器
        isDisposed = true;
        statusCheckTimer?.cancel();
        timeoutTimer?.cancel();
      });

      // 清理定时器（双重保险）
      statusCheckTimer?.cancel();
      timeoutTimer?.cancel();
    }

    Future<void> handlePurchase() async {
      if (isLoading.value) return;

      // 检查用户是否已登录
      final authState = ref.read(authNotifierProvider);
      final isAuthenticated = authState.valueOrNull?.valueOrNull != null;

      if (!isAuthenticated) {
        errorMessage.value = '请先登录后再购买套餐';
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('请先登录后再购买套餐'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // 确保 token 已设置到 HTTP 客户端，并验证 token 是否有效
      final prefs = await ref.read(sharedPreferencesProvider.future);
      final accessToken = prefs.getString('access_token');
      final refreshToken = prefs.getString('refresh_token');

      if (accessToken == null) {
        errorMessage.value = '登录状态异常，请重新登录';
        isLoading.value = false;
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('登录状态异常，请重新登录'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // 设置 token 到 HTTP 客户端
      ref.read(httpClientProvider).setAccessToken(accessToken);
      loggy.debug("已确保设置AccessToken到HTTP客户端");

      // 验证 token 是否有效，如果无效则尝试刷新
      bool tokenValid = false;
      try {
        final authRepo = ref.read(authRepositoryProvider);
        final userResult = await authRepo.getCurrentUser().run();
        await userResult.fold(
          (failure) async {
            // Token 无效，尝试刷新
            loggy.warning("Token验证失败，尝试刷新token");
            if (refreshToken != null) {
              final refreshResult = await authRepo.refreshToken(refreshToken).run();
              await refreshResult.fold(
                (refreshFailure) {
                  // 刷新失败，需要重新登录
                  loggy.error("Token刷新失败，需要重新登录");
                  tokenValid = false;
                },
                (authResponse) async {
                  // 刷新成功，保存新 token 并更新 HTTP 客户端
                  await prefs.setString('access_token', authResponse.accessToken);
                  await prefs.setString('refresh_token', authResponse.refreshToken);
                  ref.read(httpClientProvider).setAccessToken(authResponse.accessToken);
                  loggy.info("Token刷新成功，已更新");
                  tokenValid = true;
                },
              );
            } else {
              tokenValid = false;
            }
          },
          (user) {
            // Token 有效，继续
            loggy.debug("Token验证成功，用户: ${user.email}");
            tokenValid = true;
          },
        );
      } catch (e) {
        loggy.error("验证token时发生异常", e, StackTrace.current);
        // 如果验证过程出错，继续尝试创建订单，如果失败会显示具体错误
        tokenValid = true; // 允许继续尝试
      }

      // 如果 token 无效且刷新失败，停止创建订单
      if (!tokenValid) {
        errorMessage.value = '登录已过期，请重新登录';
        isLoading.value = false;
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('登录已过期，请重新登录'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      isLoading.value = true;
      errorMessage.value = null;

      try {
        // 使用read而不是watch，避免不必要的监听
        final packageApi = ref.read(packageApiProvider);
        final couponCode = couponCodeController.text.trim();

        loggy.info("💰 开始创建订单: packageId=$packageId, couponCode=$couponCode, price=¥$finalPrice");

        // 创建订单（如果输入了优惠券但未验证，先验证再创建）
        String? finalCouponCode = couponCode;
        if (couponCode.isNotEmpty && couponInfo.value == null) {
          // 如果输入了优惠券但未验证，先验证
          loggy.info("🎫 验证优惠券: $couponCode");
          await verifyCouponCode();
          if (couponInfo.value == null) {
            // 验证失败，不创建订单
            loggy.error("❌ 优惠券验证失败，取消订单创建");
            isLoading.value = false;
            return;
          }
          loggy.info("✅ 优惠券验证成功");
          finalCouponCode = couponCode;
        }

        // 获取支付方式列表，选择第一个可用的支付方式（优先选择 alipay）
        String? selectedPaymentMethod;
        int? selectedPaymentMethodId;
        try {
          loggy.info("💳 获取支付方式列表...");
          final paymentMethods = await packageApi.getPaymentMethods();
          loggy.debug("获取到支付方式列表: $paymentMethods");

          if (paymentMethods.isNotEmpty) {
            // 优先选择 alipay
            var alipayMethod = paymentMethods.firstWhere(
              (method) => (method['key'] as String?)?.toLowerCase() == 'alipay',
              orElse: () => paymentMethods.first,
            );
            selectedPaymentMethod = alipayMethod['key'] as String?;
            selectedPaymentMethodId = alipayMethod['id'] as int?;
            loggy.info("✅ 选择支付方式: $selectedPaymentMethod (ID: $selectedPaymentMethodId)");
          } else {
            // 如果没有可用的支付方式，默认使用 alipay
            selectedPaymentMethod = 'alipay';
            loggy.warning("⚠️ 未获取到支付方式列表，使用默认支付方式: alipay");
          }
        } catch (e) {
          // 如果获取支付方式失败，默认使用 alipay
          selectedPaymentMethod = 'alipay';
          loggy.error("❌ 获取支付方式列表失败，使用默认支付方式: alipay", e, StackTrace.current);
        }

        // 创建订单
        loggy.info("📝 正在创建订单...");
        final order = await packageApi.createOrder(
          packageId: packageId,
          couponCode: finalCouponCode.isEmpty ? null : finalCouponCode,
          paymentMethod: selectedPaymentMethod,
        );

        if (order != null && context.mounted) {
          // 后台返回的字段：payment_url 和 payment_qr_code（两者相同，都是支付宝二维码URL）
          final paymentUrl = order['payment_url'] as String?;
          final paymentQrCode = order['payment_qr_code'] as String?;
          // 优先使用 payment_qr_code，如果没有则使用 payment_url
          var qrCodeUrl = paymentQrCode ?? paymentUrl;
          final orderStatus = order['status'] as String?;
          final orderNo = order['order_no'] as String? ?? '';
          // 使用订单返回的金额，如果没有则使用最终价格（考虑优惠券）
          final amount = order['final_amount'] ?? order['amount'] ?? finalPrice;

          loggy.info("📦 订单创建成功: orderNo=$orderNo, status=$orderStatus, amount=¥${(amount as num).toDouble()}");

          if (orderStatus == 'paid') {
            // 订单已支付
            loggy.info("✅ 订单已支付，正在激活订阅...");
            if (context.mounted) {
              // 刷新订阅信息
              ref.invalidate(activeProfileProvider);
              loggy.info("🔄 已刷新订阅信息");
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('订单已支付成功！您的订阅已激活'),
                  backgroundColor: Colors.green,
                ),
              );
              Navigator.of(context).pop(true); // 返回并刷新
            }
          } else if (qrCodeUrl != null && qrCodeUrl.isNotEmpty) {
            loggy.info("💳 显示支付二维码: orderNo=$orderNo");
            // 有支付URL，显示二维码对话框（使用QrImageView生成二维码）
            if (context.mounted) {
              await _showPaymentDialog(
                context,
                ref,
                orderNo,
                (amount as num).toDouble(),
                qrCodeUrl,
                paymentUrl,
              );
            }
          } else if (paymentUrl != null && paymentUrl.isNotEmpty) {
            // 只有支付链接，跳转到支付页面
            if (context.mounted) {
              final uri = Uri.parse(paymentUrl);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
                // 显示提示
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('已跳转到支付页面，支付完成后请返回'),
                    duration: Duration(seconds: 3),
                  ),
                );
                Navigator.of(context).pop(true); // 返回并刷新
              } else {
                errorMessage.value = '无法打开支付链接';
              }
            }
          } else {
            // 订单创建成功但无支付链接，尝试调用支付API生成支付链接
            if (selectedPaymentMethodId != null && orderNo.isNotEmpty) {
              loggy.debug("订单创建成功但无支付链接，尝试调用支付API生成: orderNo=$orderNo, paymentMethodId=$selectedPaymentMethodId");
              try {
                final paymentResult = await packageApi.payOrder(
                  orderNo: orderNo,
                  paymentMethodId: selectedPaymentMethodId,
                );

                if (paymentResult != null) {
                  final paymentUrlFromPay = paymentResult['payment_url'] as String?;
                  if (paymentUrlFromPay != null && paymentUrlFromPay.isNotEmpty) {
                    loggy.info("✅ 通过支付API成功生成支付链接: orderNo=$orderNo");
                    qrCodeUrl = paymentUrlFromPay;
                    if (context.mounted) {
                      await _showPaymentDialog(
                        context,
                        ref,
                        orderNo,
                        (amount as num).toDouble(),
                        qrCodeUrl,
                        paymentUrlFromPay,
                      );
                    }
                  } else {
                    loggy.error("❌ 支付API返回的支付链接为空: orderNo=$orderNo");
                    throw Exception('支付API返回的支付链接为空');
                  }
                } else {
                  loggy.error("❌ 支付API返回空数据: orderNo=$orderNo");
                  throw Exception('支付API返回空数据');
                }
              } catch (e) {
                loggy.error("❌ 调用支付API失败: orderNo=$orderNo", e, StackTrace.current);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('订单创建成功，但生成支付链接失败: ${e.toString()}'),
                      backgroundColor: Colors.orange,
                      duration: const Duration(seconds: 5),
                    ),
                  );
                  Navigator.of(context).pop(true);
                }
              }
            } else {
              // 订单创建成功但无支付链接，且无法生成
              loggy.warning("⚠️ 订单创建成功但无支付链接，且无法生成: orderNo=$orderNo");
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('订单创建成功: $orderNo，但无法生成支付链接，请稍后前往订单页面支付'),
                    backgroundColor: Colors.orange,
                    duration: const Duration(seconds: 5),
                  ),
                );
                Navigator.of(context).pop(true);
              }
            }
          }
        } else {
          errorMessage.value = '创建订单失败：服务器返回空数据';
        }
      } catch (e, stackTrace) {
        // 捕获并显示具体错误信息
        loggy.error("购买失败", e, stackTrace);

        String userFriendlyMsg;

        // 处理特定的错误类型
        if (e is DioException) {
          final statusCode = e.response?.statusCode;
          final responseData = e.response?.data;
          loggy.error("DioException详情: statusCode=$statusCode, responseData=$responseData");

          if (statusCode == 403) {
            userFriendlyMsg = '创建订单失败：权限不足。请确保您已登录且账户未被禁用。如果问题持续，请尝试重新登录。';
          } else if (statusCode == 401) {
            userFriendlyMsg = '创建订单失败：未授权。请重新登录后重试。';
          } else {
            final errorMsg = responseData?['message'] as String? ?? responseData?['error'] as String? ?? e.message ?? '创建订单失败';
            userFriendlyMsg = errorMsg;
          }
        } else {
          String errorMsg = e.toString();
          if (errorMsg.contains('403') || errorMsg.contains('Forbidden')) {
            userFriendlyMsg = '创建订单失败：权限不足。请确保您已登录且账户未被禁用。如果问题持续，请尝试重新登录。';
          } else if (errorMsg.contains('401') || errorMsg.contains('Unauthorized')) {
            userFriendlyMsg = '创建订单失败：未授权。请重新登录后重试。';
          } else if (errorMsg.contains('Exception:')) {
            userFriendlyMsg = errorMsg.replaceFirst('Exception: ', '');
          } else {
            userFriendlyMsg = '创建订单失败: $errorMsg';
          }
        }

        errorMessage.value = userFriendlyMsg;

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(userFriendlyMsg),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      } finally {
        isLoading.value = false;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('购买套餐'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 套餐信息卡片
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    if (description.isNotEmpty) ...[
                      const Gap(8),
                      Text(
                        description,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                    const Gap(16),
                    Row(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (discountAmount > 0) ...[
                              Text(
                                '¥${price.toStringAsFixed(2)}',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      decoration: TextDecoration.lineThrough,
                                      color: Colors.grey,
                                    ),
                              ),
                              Text(
                                '¥${finalPrice.toStringAsFixed(2)}',
                                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                      color: Theme.of(context).colorScheme.primary,
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                            ] else
                              Text(
                                '¥${price.toStringAsFixed(2)}',
                                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                      color: Theme.of(context).colorScheme.primary,
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                          ],
                        ),
                        const Spacer(),
                        Row(
                          children: [
                            const Icon(FluentIcons.calendar_24_regular, size: 16),
                            const Gap(4),
                            Text('${durationDays}天'),
                          ],
                        ),
                        const Gap(16),
                        Row(
                          children: [
                            const Icon(FluentIcons.phone_24_regular, size: 16),
                            const Gap(4),
                            Text('$deviceLimit 设备'),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const Gap(24),
            // 优惠券输入
            TextField(
              controller: couponCodeController,
              decoration: InputDecoration(
                labelText: '优惠券代码（可选）',
                hintText: '请输入优惠券代码',
                prefixIcon: const Icon(FluentIcons.tag_24_regular),
                suffixIcon: couponCodeText.value.isNotEmpty
                    ? IconButton(
                        icon: isVerifyingCoupon.value
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(FluentIcons.checkmark_24_regular),
                        onPressed: isVerifyingCoupon.value ? null : verifyCouponCode,
                        tooltip: '验证优惠券',
                      )
                    : null,
                border: const OutlineInputBorder(),
              ),
              onChanged: (value) {
                couponCodeText.value = value;
                // 当输入改变时，清除之前的验证结果
                if (value.isEmpty) {
                  couponInfo.value = null;
                }
              },
              onSubmitted: (_) => verifyCouponCode(),
            ),
            // 显示优惠券信息
            if (couponInfo.value != null) ...[
              const Gap(8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      FluentIcons.checkmark_circle_24_filled,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                    const Gap(8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '优惠券已应用',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (discountAmount > 0)
                            Text(
                              '已优惠 ¥${discountAmount.toStringAsFixed(2)}',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onPrimaryContainer,
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const Gap(24),
            // 错误信息
            if (errorMessage.value != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                    const Gap(8),
                    Expanded(
                      child: Text(
                        errorMessage.value!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (errorMessage.value != null) const Gap(16),
            // 购买按钮
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: isLoading.value ? null : handlePurchase,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: isLoading.value
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text(
                        '立即购买',
                        style: TextStyle(fontSize: 16),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
