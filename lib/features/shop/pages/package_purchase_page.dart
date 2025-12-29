import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:gap/gap.dart';
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
              final statusData = await packageApi.getOrderStatus(orderNo);

              if (statusData != null && context.mounted && !isDisposed) {
                final status = statusData['status'] as String?;
                if (status == 'paid') {
                  isPaid = true;
                  timer.cancel();
                  timeoutTimer?.cancel();

                  // 刷新订阅信息
                  ref.invalidate(activeProfileProvider);

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
                }
              }
            } catch (e) {
              loggy.warning("查询订单状态失败", e, StackTrace.current);
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

      isLoading.value = true;
      errorMessage.value = null;

      try {
        // 使用read而不是watch，避免不必要的监听
        final packageApi = ref.read(packageApiProvider);
        final couponCode = couponCodeController.text.trim();

        // 创建订单（如果输入了优惠券但未验证，先验证再创建）
        String? finalCouponCode = couponCode;
        if (couponCode.isNotEmpty && couponInfo.value == null) {
          // 如果输入了优惠券但未验证，先验证
          await verifyCouponCode();
          if (couponInfo.value == null) {
            // 验证失败，不创建订单
            isLoading.value = false;
            return;
          }
          finalCouponCode = couponCode;
        }

        // 创建订单
        final order = await packageApi.createOrder(
          packageId: packageId,
          couponCode: finalCouponCode.isEmpty ? null : finalCouponCode,
        );

        if (order != null && context.mounted) {
          // 后台返回的字段：payment_url 和 payment_qr_code（两者相同，都是支付宝二维码URL）
          final paymentUrl = order['payment_url'] as String?;
          final paymentQrCode = order['payment_qr_code'] as String?;
          // 优先使用 payment_qr_code，如果没有则使用 payment_url
          final qrCodeUrl = paymentQrCode ?? paymentUrl;
          final orderStatus = order['status'] as String?;
          final orderNo = order['order_no'] as String? ?? '';
          // 使用订单返回的金额，如果没有则使用最终价格（考虑优惠券）
          final amount = order['final_amount'] ?? order['amount'] ?? finalPrice;

          if (orderStatus == 'paid') {
            // 订单已支付
            if (context.mounted) {
              // 刷新订阅信息
              ref.invalidate(activeProfileProvider);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('订单已支付成功！您的订阅已激活'),
                  backgroundColor: Colors.green,
                ),
              );
              Navigator.of(context).pop(true); // 返回并刷新
            }
          } else if (qrCodeUrl != null && qrCodeUrl.isNotEmpty) {
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
            // 订单创建成功但无支付链接
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('订单创建成功: $orderNo'),
                ),
              );
              Navigator.of(context).pop(true);
            }
          }
        } else {
          errorMessage.value = '创建订单失败：服务器返回空数据';
        }
      } catch (e) {
        // 捕获并显示具体错误信息
        final errorMsg = e.toString();
        if (errorMsg.contains('Exception:')) {
          errorMessage.value = errorMsg.replaceFirst('Exception: ', '');
        } else {
          errorMessage.value = '创建订单失败: $errorMsg';
        }
        loggy.error("购买失败", e, StackTrace.current);
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
