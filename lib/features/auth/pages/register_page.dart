import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/features/auth/data/verification_providers.dart';
import 'package:hiddify/features/auth/model/auth_failure.dart';
import 'package:hiddify/features/auth/notifier/auth_notifier.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class RegisterPage extends HookConsumerWidget {
  const RegisterPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authNotifier = ref.watch(authNotifierProvider.notifier);

    final usernameController = useTextEditingController();
    final emailController = useTextEditingController();
    final passwordController = useTextEditingController();
    final confirmPasswordController = useTextEditingController();
    final verificationCodeController = useTextEditingController();
    final formKey = useMemoized(() => GlobalKey<FormState>());
    final isLoading = useState(false);
    final showPassword = useState(false);
    final showConfirmPassword = useState(false);
    final countdown = useState<int?>(null);
    final isSendingCode = useState(false);
    final countdownTimer = useRef<Timer?>(null);

    useEffect(() {
      return () {
        countdownTimer.value?.cancel();
      };
    }, []);

    ref.listen(authNotifierProvider, (previous, next) {
      switch (next) {
        case AsyncData(value: final userValue):
          switch (userValue) {
            case AsyncData(value: final _?):
              // 注册成功，导航到主页
              WidgetsBinding.instance.addPostFrameCallback((_) {
                context.go('/');
              });
            default:
              break;
          }
        case AsyncError(:final error):
          String errorMessage = '注册失败';
          if (error is AuthFailure) {
            final failureInfo = error.present(ref.read(translationsProvider));
            errorMessage = failureInfo.message ?? '注册失败';
          } else {
            errorMessage = error.toString();
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: Colors.red,
            ),
          );
        default:
          break;
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('注册'),
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
                    '创建账户',
                    style: Theme.of(context).textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  const Gap(8),
                  Text(
                    '注册新账户以开始使用',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const Gap(32),
                  TextFormField(
                    controller: usernameController,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: '用户名',
                      hintText: '请输入用户名',
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '请输入用户名';
                      }
                      if (value.length < 3) {
                        return '用户名长度至少3位';
                      }
                      return null;
                    },
                  ),
                  const Gap(16),
                  TextFormField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: '邮箱',
                      hintText: '请输入您的邮箱',
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
                  const Gap(16),
                  TextFormField(
                    controller: verificationCodeController,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                    maxLength: 6,
                    decoration: InputDecoration(
                      labelText: '验证码',
                      hintText: '请输入6位邮箱验证码',
                      counterText: '',
                      suffixIcon: TextButton(
                        onPressed: (isSendingCode.value || countdown.value != null)
                            ? null
                            : () async {
                                // 验证邮箱格式
                                if (emailController.text.isEmpty) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('请先输入邮箱地址')),
                                  );
                                  return;
                                }
                                if (!emailController.text.contains('@')) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('请输入有效的邮箱地址')),
                                  );
                                  return;
                                }

                                isSendingCode.value = true;
                                final verificationApi = ref.read(verificationApiProvider);
                                final result = await verificationApi.sendVerificationCode(
                                  email: emailController.text.trim(),
                                );

                                isSendingCode.value = false;

                                if (result.success) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(result.message ?? '验证码已发送，请查收邮箱'),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                  // 开始倒计时
                                  countdown.value = 60;
                                  countdownTimer.value?.cancel();
                                  countdownTimer.value = Timer.periodic(
                                    const Duration(seconds: 1),
                                    (timer) {
                                      if (countdown.value != null && countdown.value! > 0) {
                                        countdown.value = countdown.value! - 1;
                                      } else {
                                        countdown.value = null;
                                        timer.cancel();
                                        countdownTimer.value = null;
                                      }
                                    },
                                  );
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(result.message ?? '发送验证码失败，请稍后重试'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              },
                        child: isSendingCode.value
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(countdown.value != null ? '${countdown.value}秒' : '发送'),
                      ),
                    ),
                    validator: (value) {
                      // 验证码是必填的
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
                  const Gap(16),
                  TextFormField(
                    controller: passwordController,
                    obscureText: !showPassword.value,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: '密码',
                      hintText: '请输入密码（至少8位）',
                      suffixIcon: IconButton(
                        icon: Icon(
                          showPassword.value ? Icons.visibility : Icons.visibility_off,
                        ),
                        onPressed: () {
                          showPassword.value = !showPassword.value;
                        },
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '请输入密码';
                      }
                      if (value.length < 8) {
                        return '密码长度至少8位';
                      }
                      return null;
                    },
                  ),
                  const Gap(16),
                  TextFormField(
                    controller: confirmPasswordController,
                    obscureText: !showConfirmPassword.value,
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      labelText: '确认密码',
                      hintText: '请再次输入密码',
                      suffixIcon: IconButton(
                        icon: Icon(
                          showConfirmPassword.value ? Icons.visibility : Icons.visibility_off,
                        ),
                        onPressed: () {
                          showConfirmPassword.value = !showConfirmPassword.value;
                        },
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return '请确认密码';
                      }
                      if (value != passwordController.text) {
                        return '两次输入的密码不一致';
                      }
                      return null;
                    },
                  ),
                  const Gap(24),
                  FilledButton(
                    onPressed: isLoading.value
                        ? null
                        : () async {
                            if (formKey.currentState?.validate() ?? false) {
                              // 确保验证码已输入
                              if (verificationCodeController.text.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('请先获取并输入验证码'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                                return;
                              }

                              isLoading.value = true;
                              final result = await authNotifier.register(
                                usernameController.text.trim(),
                                emailController.text.trim(),
                                passwordController.text,
                                verificationCode: verificationCodeController.text.trim(),
                              );
                              isLoading.value = false;
                              result.fold(
                                (failure) {
                                  // 错误已在listen中处理
                                },
                                (_) {
                                  // 成功
                                },
                              );
                            }
                          },
                    child: isLoading.value
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('注册'),
                  ),
                  const Gap(16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('已有账户？'),
                      TextButton(
                        onPressed: () {
                          context.pop();
                        },
                        child: const Text('立即登录'),
                      ),
                    ],
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
