import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/features/auth/data/auth_data_providers.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class ForgotPasswordPage extends HookConsumerWidget {
  const ForgotPasswordPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider);
    final emailController = useTextEditingController();
    final codeController = useTextEditingController();
    final formKey = useMemoized(() => GlobalKey<FormState>());
    final isSending = useState(false);
    final codeSent = useState(false);
    final countdown = useState<int?>(null);
    final countdownTimer = useRef<Timer?>(null);

    useEffect(() {
      return () {
        countdownTimer.value?.cancel();
      };
    }, []);

    return Scaffold(
      appBar: AppBar(
        title: const Text('忘记密码'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Gap(32),
                  Text(
                    '找回密码',
                    style: Theme.of(context).textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  const Gap(8),
                  Text(
                    '请输入您的邮箱地址，我们将发送验证码到您的邮箱',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const Gap(32),
                  TextFormField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    enabled: !codeSent.value,
                    decoration: const InputDecoration(
                      labelText: '邮箱',
                      hintText: '请输入您的邮箱地址',
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '请输入邮箱';
                      }
                      if (!value.contains('@')) {
                        return '请输入有效的邮箱地址';
                      }
                      return null;
                    },
                  ),
                  if (codeSent.value) ...[
                    const Gap(16),
                    TextFormField(
                      controller: codeController,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      maxLength: 6,
                      decoration: const InputDecoration(
                        labelText: '验证码',
                        hintText: '请输入6位验证码',
                        counterText: '',
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return '请输入验证码';
                        }
                        if (value.length != 6) {
                          return '验证码必须是6位数字';
                        }
                        if (!RegExp(r'^\d+$').hasMatch(value)) {
                          return '验证码必须是数字';
                        }
                        return null;
                      },
                    ),
                  ],
                  const Gap(24),
                  if (!codeSent.value)
                    FilledButton(
                      onPressed: isSending.value
                          ? null
                          : () async {
                              if (formKey.currentState?.validate() ?? false) {
                                isSending.value = true;
                                final authRepo = ref.read(authRepositoryProvider);
                                final result = await authRepo.forgotPassword(emailController.text.trim()).run();

                                isSending.value = false;

                                result.fold(
                                  (failure) {
                                    final failureInfo = failure.present(t);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(failureInfo.message ?? '操作失败'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  },
                                  (_) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('验证码已发送，请查收邮箱'),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                    // 显示验证码输入框
                                    codeSent.value = true;
                                    // 开始倒计时
                                    countdown.value = 60;
                                    countdownTimer.value?.cancel();
                                    countdownTimer.value = Timer.periodic(
                                      const Duration(seconds: 1),
                                      (timer) {
                                        if (countdown.value != null && countdown.value! > 0) {
                                          countdown.value = countdown.value! - 1;
                                        } else {
                                          timer.cancel();
                                          countdown.value = null;
                                        }
                                      },
                                    );
                                  },
                                );
                              }
                            },
                      child: isSending.value
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('发送验证码'),
                    )
                  else
                    FilledButton(
                      onPressed: () {
                        // 验证码已输入，跳转到重置密码页面
                        if (formKey.currentState?.validate() ?? false) {
                          context.push(
                            '/auth/reset-password?email=${Uri.encodeComponent(emailController.text.trim())}&code=${Uri.encodeComponent(codeController.text.trim())}',
                          );
                        }
                      },
                      child: const Text('下一步'),
                    ),
                  if (codeSent.value && countdown.value != null && countdown.value! > 0) ...[
                    const Gap(8),
                    TextButton(
                      onPressed: null,
                      child: Text('${countdown.value}秒后可重新发送'),
                    ),
                  ] else if (codeSent.value && (countdown.value == null || countdown.value == 0)) ...[
                    const Gap(8),
                    TextButton(
                      onPressed: () {
                        codeSent.value = false;
                        codeController.clear();
                      },
                      child: const Text('重新发送验证码'),
                    ),
                  ],
                  const Gap(16),
                  TextButton(
                    onPressed: () => context.pop(),
                    child: const Text('返回登录'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
