import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/features/auth/data/auth_data_providers.dart';
import 'package:hiddify/features/auth/model/auth_entity.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class ResetPasswordPage extends HookConsumerWidget {
  const ResetPasswordPage({
    super.key,
    this.email,
  });

  final String? email;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider);
    final emailController = useTextEditingController(text: email ?? '');
    final codeController = useTextEditingController();
    final passwordController = useTextEditingController();
    final confirmPasswordController = useTextEditingController();
    final formKey = useMemoized(() => GlobalKey<FormState>());
    final isLoading = useState(false);
    final showPassword = useState(false);
    final showConfirmPassword = useState(false);

    // 从路由参数获取邮箱和验证码
    final routeEmail = GoRouterState.of(context).uri.queryParameters['email'] ?? email;
    final routeCode = GoRouterState.of(context).uri.queryParameters['code'];

    useEffect(() {
      if (routeEmail != null && routeEmail.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (emailController.text.isEmpty) {
            emailController.text = routeEmail;
          }
        });
      }
      if (routeCode != null && routeCode.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (codeController.text.isEmpty) {
            codeController.text = routeCode;
          }
        });
      }
      return null;
    }, [routeEmail, routeCode]);

    return Scaffold(
      appBar: AppBar(
        title: const Text('重置密码'),
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
                    '重置密码',
                    style: Theme.of(context).textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  const Gap(8),
                  Text(
                    '请输入验证码和新密码',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const Gap(32),
                  TextFormField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    enabled: routeEmail == null,
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
                  const Gap(16),
                  TextFormField(
                    controller: codeController,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
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
                  const Gap(16),
                  TextFormField(
                    controller: passwordController,
                    obscureText: !showPassword.value,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: '新密码',
                      hintText: '请输入新密码（至少8位）',
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
                        return '请输入新密码';
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
                      labelText: '确认新密码',
                      hintText: '请再次输入新密码',
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
                        return '请确认新密码';
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
                              isLoading.value = true;
                              final authRepo = ref.read(authRepositoryProvider);
                              final result = await authRepo
                                  .resetPassword(
                                    ResetPasswordRequest(
                                      email: emailController.text.trim(),
                                      verificationCode: codeController.text.trim(),
                                      newPassword: passwordController.text,
                                    ),
                                  )
                                  .run();

                              isLoading.value = false;

                              result.fold(
                                (failure) {
                                  final failureInfo = failure.present(t);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(failureInfo.message ?? '操作失败'),
                                    ),
                                  );
                                },
                                (_) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('密码重置成功，请使用新密码登录'),
                                    ),
                                  );
                                  // 返回登录页面
                                  context.go('/auth/login');
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
                        : const Text('重置密码'),
                  ),
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
