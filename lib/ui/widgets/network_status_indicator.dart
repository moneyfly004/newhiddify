import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../core/utils/network_utils.dart';
import '../theme/cyberpunk_theme.dart';

/// 网络状态指示器
class NetworkStatusIndicator extends StatefulWidget {
  const NetworkStatusIndicator({super.key});

  @override
  State<NetworkStatusIndicator> createState() => _NetworkStatusIndicatorState();
}

class _NetworkStatusIndicatorState extends State<NetworkStatusIndicator> {
  ConnectivityResult _connectivityResult = ConnectivityResult.none;

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
    _listenToConnectivity();
  }

  Future<void> _checkConnectivity() async {
    final result = await NetworkUtils.getNetworkType();
    if (mounted) {
      setState(() {
        _connectivityResult = result;
      });
    }
  }

  void _listenToConnectivity() {
    NetworkUtils.connectivityStream.listen((results) {
      if (mounted && results.isNotEmpty) {
        setState(() {
          _connectivityResult = results.first;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isConnected = _connectivityResult != ConnectivityResult.none;
    final icon = _getIcon();
    final color = _getColor();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            _getLabel(),
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getIcon() {
    switch (_connectivityResult) {
      case ConnectivityResult.wifi:
        return Icons.wifi;
      case ConnectivityResult.mobile:
        return Icons.signal_cellular_alt;
      case ConnectivityResult.ethernet:
        return Icons.cable;
      default:
        return Icons.signal_wifi_off;
    }
  }

  Color _getColor() {
    switch (_connectivityResult) {
      case ConnectivityResult.wifi:
        return CyberpunkTheme.neonGreen;
      case ConnectivityResult.mobile:
        return CyberpunkTheme.neonCyan;
      case ConnectivityResult.ethernet:
        return CyberpunkTheme.neonGreen;
      default:
        return Colors.red;
    }
  }

  String _getLabel() {
    switch (_connectivityResult) {
      case ConnectivityResult.wifi:
        return 'WiFi';
      case ConnectivityResult.mobile:
        return '移动';
      case ConnectivityResult.ethernet:
        return '以太网';
      default:
        return '无网络';
    }
  }
}

