import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/features/auth/model/auth_failure.dart';
import 'package:hiddify/features/auth/notifier/auth_notifier.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class LoginPage extends HookConsumerWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authNotifier = ref.watch(authNotifierProvider.notifier);

    final emailController = useTextEditingController();
    final passwordController = useTextEditingController();
    final formKey = useMemoized(() => GlobalKey<FormState>());
    final isLoading = useState(false);
    final showPassword = useState(false);

    ref.listen(authNotifierProvider, (previous, next) {
      switch (next) {
        case AsyncData(value: final userValue):
          switch (userValue) {
            case AsyncData(value: final _?):
              // 登录成功，导航到主页
              WidgetsBinding.instance.addPostFrameCallback((_) {
                context.go('/');
              });
            default:
              break;
          }
        case AsyncError(:final error):
          String errorMessage = '登录失败';
          if (error is AuthFailure) {
            final failureInfo = error.present(ref.read(translationsProvider));
            errorMessage = failureInfo.message ?? '登录失败';
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
        title: const Text('登录'),
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
                    '欢迎回来',
                    style: Theme.of(context).textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  const Gap(8),
                  Text(
                    '请登录您的账户',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const Gap(32),
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
                    controller: passwordController,
                    obscureText: !showPassword.value,
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      labelText: '密码',
                      hintText: '请输入您的密码',
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
                  const Gap(8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        context.push('/auth/forgot-password');
                      },
                      child: const Text('忘记密码？'),
                    ),
                  ),
                  const Gap(24),
                  FilledButton(
                    onPressed: isLoading.value
                        ? null
                        : () async {
                            if (formKey.currentState?.validate() ?? false) {
                              isLoading.value = true;
                              final result = await authNotifier.login(
                                emailController.text.trim(),
                                passwordController.text,
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
                        : const Text('登录'),
                  ),
                  const Gap(16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('还没有账户？'),
                      TextButton(
                        onPressed: () {
                          context.push('/auth/register');
                        },
                        child: const Text('立即注册'),
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
