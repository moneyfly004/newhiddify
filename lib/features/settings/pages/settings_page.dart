import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../ui/theme/cyberpunk_theme.dart';
import '../../../core/models/kernel_type.dart';
import '../../../core/services/permission_service.dart';
import '../../auth/cubit/auth_cubit.dart';
import '../../auth/models/auth_state.dart';

/// 设置页面
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  KernelType _selectedKernel = KernelType.singbox;
  bool _autoConnect = false;
  bool _autoTestSpeed = true;
  bool _vpnPermissionGranted = false;
  bool _batteryOptimizationIgnored = false;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    final vpnGranted = await PermissionService.checkVpnPermission();
    final batteryIgnored =
        await PermissionService.checkIgnoreBatteryOptimizations();
    setState(() {
      _vpnPermissionGranted = vpnGranted;
      _batteryOptimizationIgnored = batteryIgnored;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 内核设置
          _buildSection(
            context,
            '内核设置',
            [
              _buildKernelSelector(context),
            ],
          ),

          const SizedBox(height: 16),

          // 连接设置
          _buildSection(
            context,
            '连接设置',
            [
              _buildSwitchTile(
                context,
                '自动连接',
                '启动时自动连接',
                _autoConnect,
                (value) => setState(() => _autoConnect = value),
              ),
              _buildSwitchTile(
                context,
                '自动测速',
                '定期自动测试节点速度',
                _autoTestSpeed,
                (value) => setState(() => _autoTestSpeed = value),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // 权限设置
          _buildSection(
            context,
            '权限设置',
            [
              _buildPermissionTile(
                context,
                'VPN 权限',
                '需要 VPN 权限以建立代理连接',
                _vpnPermissionGranted,
                () async {
                  final granted = await PermissionService.requestVpnPermission();
                  setState(() => _vpnPermissionGranted = granted);
                  if (granted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('VPN 权限已授予'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                },
              ),
              _buildPermissionTile(
                context,
                '忽略电池优化',
                '保持后台运行，避免被系统杀死',
                _batteryOptimizationIgnored,
                () async {
                  final ignored =
                      await PermissionService.requestIgnoreBatteryOptimizations();
                  setState(() => _batteryOptimizationIgnored = ignored);
                  if (ignored) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('已忽略电池优化'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                },
              ),
            ],
          ),

          const SizedBox(height: 16),

          // 账户设置
          _buildSection(
            context,
            '账户',
            [
              BlocBuilder<AuthCubit, AuthState>(
                builder: (context, state) {
                  if (state is AuthAuthenticated) {
                    return ListTile(
                      leading: const Icon(Icons.person),
                      title: const Text('用户名'),
                      subtitle: Text(state.user.username),
                    );
                  }
                  return const ListTile(
                    leading: Icon(Icons.person),
                    title: Text('未登录'),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('登出'),
                onTap: () {
                  context.read<AuthCubit>().logout();
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),

          const SizedBox(height: 16),

          // 关于
          _buildSection(
            context,
            '关于',
            [
              const ListTile(
                leading: Icon(Icons.info),
                title: Text('版本'),
                subtitle: Text('1.0.0'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSection(
    BuildContext context,
    String title,
    List<Widget> children,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: CyberpunkTheme.neonGradient(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildKernelSelector(BuildContext context) {
    return Column(
      children: [
        RadioListTile<KernelType>(
          title: const Text('Sing-box'),
          subtitle: const Text('高性能、现代化的代理内核'),
          value: KernelType.singbox,
          groupValue: _selectedKernel,
          onChanged: (value) {
            if (value != null) {
              setState(() => _selectedKernel = value);
            }
          },
        ),
        RadioListTile<KernelType>(
          title: const Text('Clash Meta'),
          subtitle: const Text('功能丰富的 Clash Meta 内核'),
          value: KernelType.mihomo,
          groupValue: _selectedKernel,
          onChanged: (value) {
            if (value != null) {
              setState(() => _selectedKernel = value);
            }
          },
        ),
      ],
    );
  }

  Widget _buildSwitchTile(
    BuildContext context,
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return SwitchListTile(
      title: Text(title),
      subtitle: Text(subtitle),
      value: value,
      onChanged: onChanged,
    );
  }

  Widget _buildPermissionTile(
    BuildContext context,
    String title,
    String subtitle,
    bool granted,
    VoidCallback onRequest,
  ) {
    return ListTile(
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            granted ? Icons.check_circle : Icons.error,
            color: granted ? Colors.green : Colors.orange,
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: granted ? null : onRequest,
            child: Text(granted ? '已授予' : '请求'),
          ),
        ],
      ),
    );
  }
}
