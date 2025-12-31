import 'package:flutter/material.dart';
import '../../../core/services/app_info_service.dart';
import '../../../ui/theme/cyberpunk_theme.dart';

/// 应用代理选择页面
class AppProxySelectorPage extends StatefulWidget {
  final List<String> selectedApps;
  final ValueChanged<List<String>> onAppsSelected;

  const AppProxySelectorPage({
    super.key,
    required this.selectedApps,
    required this.onAppsSelected,
  });

  @override
  State<AppProxySelectorPage> createState() => _AppProxySelectorPageState();
}

class _AppProxySelectorPageState extends State<AppProxySelectorPage> {
  final List<InstalledApp> _apps = [];
  final Set<String> _selectedPackages = {};
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _selectedPackages.addAll(widget.selectedApps);
    _loadInstalledApps();
  }

  Future<void> _loadInstalledApps() async {
    try {
      final apps = await AppInfoService.getInstalledApps();
      setState(() {
        _apps.addAll(apps);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载应用列表失败: $e')),
        );
      }
    }
  }
  
  List<InstalledApp> get _filteredApps {
    if (_searchQuery.isEmpty) return _apps;
    final query = _searchQuery.toLowerCase();
    return _apps.where((app) {
      return app.name.toLowerCase().contains(query) ||
          app.packageName.toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('选择应用'),
        actions: [
          IconButton(
            icon: const Icon(Icons.select_all),
            onPressed: _selectAll,
            tooltip: '全选',
          ),
          IconButton(
            icon: const Icon(Icons.deselect),
            onPressed: _deselectAll,
            tooltip: '全不选',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // 搜索框
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    onChanged: (value) => setState(() => _searchQuery = value),
                    decoration: InputDecoration(
                      hintText: '搜索应用',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: CyberpunkTheme.neonCyan,
                        ),
                      ),
                    ),
                  ),
                ),
                // 应用列表
                Expanded(
                  child: ListView.builder(
                    itemCount: _filteredApps.length,
                    itemBuilder: (context, index) {
                      final app = _filteredApps[index];
                      final isSelected = _selectedPackages.contains(app.packageName);
                      
                      return CheckboxListTile(
                        title: Text(app.name),
                        subtitle: Text(app.packageName),
                        value: isSelected,
                        onChanged: (value) {
                          setState(() {
                            if (value == true) {
                              _selectedPackages.add(app.packageName);
                            } else {
                              _selectedPackages.remove(app.packageName);
                            }
                          });
                        },
                        activeColor: CyberpunkTheme.neonCyan,
                      );
                    },
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          widget.onAppsSelected(_selectedPackages.toList());
          Navigator.pop(context);
        },
        backgroundColor: CyberpunkTheme.neonCyan,
        child: const Icon(Icons.check),
      ),
    );
  }

  void _selectAll() {
    setState(() {
      _selectedPackages.addAll(_filteredApps.map((app) => app.packageName));
    });
  }

  void _deselectAll() {
    setState(() {
      _selectedPackages.clear();
    });
  }
}

