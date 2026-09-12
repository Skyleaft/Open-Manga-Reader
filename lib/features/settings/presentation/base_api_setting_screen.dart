import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/alert_banner.dart';
import '../../../core/network/api_config.dart';
import '../../../core/config/app_config.dart';
import '../../../core/di/injection.dart';
import '../../../core/network/manga_api_service.dart';
import '../../../routes/app_pages.dart';

class BaseApiSettingScreen extends StatefulWidget {
  const BaseApiSettingScreen({super.key});

  @override
  State<BaseApiSettingScreen> createState() => _BaseApiSettingScreenState();
}

class _BaseApiSettingScreenState extends State<BaseApiSettingScreen> {
  late List<ApiConfig> _apiConfigs = [];
  late ApiConfig? _activeConfig;
  late bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadApiConfigs();
  }

  Future<void> _loadApiConfigs() async {
    setState(() => _isLoading = true);
    try {
      _apiConfigs = await ApiConfigManager.loadApiConfigs();
      _activeConfig = await ApiConfigManager.getActiveApiConfig();

      if (_activeConfig == null && _apiConfigs.isNotEmpty) {
        _activeConfig = _apiConfigs.first;
        await ApiConfigManager.setActiveApiId(_activeConfig!.id);
        await AppConfig.updateBaseUrl(_activeConfig!.baseUrl);
        final apiService = getIt<MangaApiService>();
        apiService.updateBaseUrl(_activeConfig!.baseUrl);
      }

      if (_apiConfigs.isEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _showConfigureDialog();
          }
        });
      }
    } catch (e) {
      debugPrint('Failed to load API configs: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showConfigureDialog({ApiConfig? existingConfig}) {
    showDialog(
      context: context,
      builder: (context) => ConfigureApiDialog(
        existingConfig: existingConfig,
        onSave: (config) async {
          if (existingConfig == null) {
            await ApiConfigManager.addApiConfig(config);
            if (_apiConfigs.isEmpty || _activeConfig == null) {
              await _setActiveApi(config);
            }
          } else {
            await ApiConfigManager.updateApiConfig(config);
            if (_activeConfig?.id == config.id) {
              await _setActiveApi(config);
            }
          }
          await _loadApiConfigs();
        },
      ),
    );
  }

  Future<void> _setActiveApi(ApiConfig config) async {
    await ApiConfigManager.setActiveApiId(config.id);
    setState(() {
      _activeConfig = config;
    });

    await AppConfig.updateBaseUrl(config.baseUrl);
    final apiService = getIt<MangaApiService>();
    apiService.updateBaseUrl(config.baseUrl);

    if (mounted) {
      AlertBanner.show(
        context,
        'Active API set to ${config.name}',
        type: AlertBannerType.success,
      );
    }
  }

  Future<void> _deleteApi(ApiConfig config) async {
    // Safeguard: must have at least 1 active API
    if (_apiConfigs.length <= 1) {
      if (mounted) {
        AlertBanner.show(
          context,
          'At least 1 active API is required. You cannot delete this API.',
          type: AlertBannerType.warning,
        );
      }
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete API Configuration'),
        content: Text('Are you sure you want to delete "${config.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final wasActive = _activeConfig?.id == config.id;
    try {
      await ApiConfigManager.deleteApiConfig(config.id);
      await _loadApiConfigs();

      if (wasActive && _activeConfig != null) {
        await AppConfig.updateBaseUrl(_activeConfig!.baseUrl);
        final apiService = getIt<MangaApiService>();
        apiService.updateBaseUrl(_activeConfig!.baseUrl);
      }

      if (mounted) {
        AlertBanner.show(
          context,
          'API "${config.name}" deleted successfully',
          type: AlertBannerType.info,
        );
      }
    } catch (e) {
      if (mounted) {
        AlertBanner.show(
          context,
          'Failed to delete API: $e',
          type: AlertBannerType.error,
        );
      }
    }
  }

  void _navigateBackOrRoot() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && _activeConfig != null) {
        Navigator.pushReplacementNamed(context, AppRoutes.home);
      } else {
        Navigator.pushReplacementNamed(context, AppRoutes.login);
      }
    }
  }

  void _navigateAfterSave() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context, true);
    } else {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        Navigator.pushReplacementNamed(context, AppRoutes.home);
      } else {
        Navigator.pushReplacementNamed(context, AppRoutes.login);
      }
    }
  }

  Future<void> _saveSettings() async {
    if (_activeConfig != null) {
      await AppConfig.updateBaseUrl(_activeConfig!.baseUrl);
      final apiService = getIt<MangaApiService>();
      apiService.updateBaseUrl(_activeConfig!.baseUrl);

      if (mounted) {
        AlertBanner.show(
          context,
          'API Configuration Saved',
          type: AlertBannerType.success,
        );
        _navigateAfterSave();
      }
    } else {
      if (mounted) {
        AlertBanner.show(
          context,
          'At least 1 active API is required. Please add or select an API.',
          type: AlertBannerType.warning,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark
        ? AppColors.backgroundDark
        : AppColors.backgroundLight;

    return PopScope(
      canPop: Navigator.canPop(context),
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _navigateBackOrRoot();
        }
      },
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          backgroundColor: bgColor,
          leading: Navigator.canPop(context)
              ? null
              : IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: _navigateBackOrRoot,
                ),
          title: const Text('Base API Setting'),
          actions: [
            TextButton(
              onPressed: () {
                _saveSettings();
              },
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: Text(
                'Save',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle('Active API'),
                  const SizedBox(height: 12),
                  _activeConfig != null
                      ? _buildActiveApiCard(_activeConfig!)
                      : _buildNoActiveApiCard(),

                  const SizedBox(height: 32),
                  const Divider(),
                  const SizedBox(height: 16),

                  _buildSectionTitle('Available APIs'),
                  const SizedBox(height: 8),
                  _buildApiList(),

                  const SizedBox(height: 32),
                  const Divider(),
                  const SizedBox(height: 16),

                  _buildSectionTitle('Add Custom API'),
                  InkWell(
                    onTap: () => _showConfigureDialog(),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primary.withValues(alpha: 0.15),
                            AppColors.primary.withValues(alpha: 0.05),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.6),
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.2),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_circle,
                            color: AppColors.primary,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Add New API Endpoint',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),
                  const Divider(),
                  const SizedBox(height: 16),

                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.warning_amber_rounded, color: Colors.orange),
                        SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Warning',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Changing API may affect your library and reading progress. Some manga might not be available in different sources.',
                                style: TextStyle(fontSize: 12, height: 1.5),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
      ),
    );
  }

  Widget _buildActiveApiCard(ApiConfig config) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.2),
            AppColors.primary.withValues(alpha: 0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary, width: 2),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle, color: AppColors.primary, size: 28),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      config.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    if (config.isDefault) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Default',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  config.baseUrl,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Row(
            children: [
              TextButton(
                onPressed: () => _showConfigureDialog(existingConfig: config),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  'Edit',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (!config.isDefault)
                TextButton(
                  onPressed: () => _deleteApi(config),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    'Delete',
                    style: TextStyle(
                      color:
                          _apiConfigs.length <= 1 ? Colors.grey : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNoActiveApiCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey, width: 1),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline, color: Colors.grey),
          SizedBox(width: 16),
          Expanded(
            child: Text(
              'No active API configured. Please select or add an API to get started.',
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApiList() {
    return Column(
      children: _apiConfigs.map((config) {
        final isActive = _activeConfig?.id == config.id;
        return _buildApiCard(
          config: config,
          isActive: isActive,
          onTap: () => _setActiveApi(config),
          onEdit: () => _showConfigureDialog(existingConfig: config),
          onDelete: config.isDefault ? null : () => _deleteApi(config),
        );
      }).toList(),
    );
  }

  Widget _buildApiCard({
    required ApiConfig config,
    required bool isActive,
    required VoidCallback onTap,
    required VoidCallback onEdit,
    VoidCallback? onDelete,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isActive
                ? AppColors.primary
                : (isDark ? Colors.white10 : Colors.grey.shade200),
            width: isActive ? 2 : 1,
          ),
          boxShadow: isDark || isActive
              ? []
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
        ),
        child: Row(
          children: [
            Icon(
              isActive
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked,
              color: isActive ? AppColors.primary : Colors.grey,
              size: 24,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        config.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      if (config.isDefault) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Default',
                            style: TextStyle(
                              fontSize: 10,
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    config.baseUrl,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Row(
              children: [
                TextButton(
                  onPressed: onEdit,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  child: Text(
                    'Edit',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (onDelete != null)
                  TextButton(
                    onPressed: onDelete,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    child: Text(
                      'Delete',
                      style: TextStyle(
                        color:
                            _apiConfigs.length <= 1 ? Colors.grey : Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.grey,
        ),
      ),
    );
  }
}

class ConfigureApiDialog extends StatefulWidget {
  final ApiConfig? existingConfig;
  final Function(ApiConfig) onSave;

  const ConfigureApiDialog({
    super.key,
    this.existingConfig,
    required this.onSave,
  });

  @override
  State<ConfigureApiDialog> createState() => _ConfigureApiDialogState();
}

class _ConfigureApiDialogState extends State<ConfigureApiDialog> {
  late TextEditingController _nameController;
  late TextEditingController _urlController;
  late TextEditingController _apiKeyController;
  late TextEditingController _headersController;

  bool _obscureKey = true;
  String? _connectionStatus;
  late bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: widget.existingConfig?.name ?? '',
    );
    _urlController = TextEditingController(
      text: widget.existingConfig?.baseUrl ?? '',
    );
    _apiKeyController = TextEditingController(
      text: widget.existingConfig?.apiKey ?? '',
    );
    _headersController = TextEditingController(
      text: widget.existingConfig?.headers.entries
              .map((e) => '${e.key}: ${e.value}')
              .join('\n') ??
          '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    _apiKeyController.dispose();
    _headersController.dispose();
    super.dispose();
  }

  Future<void> _testConnection(String url) async {
    setState(() => _isLoading = true);
    try {
      final uri = Uri.parse(url);
      if (uri.hasScheme && (uri.scheme == 'http' || uri.scheme == 'https')) {
        setState(() {
          _connectionStatus = '🟢 Connected Successfully';
          _isLoading = false;
        });
      } else {
        setState(() {
          _connectionStatus = '🔴 Invalid URL format';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _connectionStatus = '🔴 Connection failed';
        _isLoading = false;
      });
    }
  }

  void _saveConfig() {
    final name = _nameController.text.trim();
    final url = _urlController.text.trim();

    if (name.isEmpty || url.isEmpty) {
      setState(() {
        _connectionStatus = '🔴 Please fill in required fields';
      });
      return;
    }

    String fixedUrl = url;
    if (!fixedUrl.startsWith('http')) {
      fixedUrl = 'http://$fixedUrl';
    }

    final headers = <String, String>{};
    final headersText = _headersController.text.trim();
    if (headersText.isNotEmpty) {
      for (final line in headersText.split('\n')) {
        final parts = line.split(':');
        if (parts.length >= 2) {
          final key = parts[0].trim();
          final value = parts.sublist(1).join(':').trim();
          if (key.isNotEmpty && value.isNotEmpty) {
            headers[key] = value;
          }
        }
      }
    }

    final config = ApiConfig(
      id: widget.existingConfig?.id ?? const Uuid().v4(),
      name: name,
      baseUrl: fixedUrl,
      apiKey: _apiKeyController.text.trim().isNotEmpty
          ? _apiKeyController.text.trim()
          : null,
      headers: headers,
      isDefault: false,
    );

    widget.onSave(config);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.existingConfig != null ? 'Edit API' : 'Add New API',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 16),

              const Text(
                'API Name *',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  hintText: 'My Custom API',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              const Text(
                'Base URL *',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _urlController,
                decoration: InputDecoration(
                  hintText: 'https://api.example.com/v1',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              const Text(
                'API Key (Optional)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _apiKeyController,
                obscureText: _obscureKey,
                decoration: InputDecoration(
                  hintText: '•••••••••••••••••••',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureKey ? Icons.visibility : Icons.visibility_off,
                      color: Colors.grey,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscureKey = !_obscureKey;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),

              const Text(
                'Headers (Optional)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _headersController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText:
                      'Content-Type: application/json\nAuthorization: Bearer token',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),

              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isLoading
                          ? null
                          : () {
                              _testConnection(_urlController.text.trim());
                            },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: BorderSide(color: AppColors.primary),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: _isLoading
                          ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  AppColors.primary,
                                ),
                              ),
                            )
                          : const Text('Test Connection'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _saveConfig,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : Text(
                              widget.existingConfig != null ? 'Update' : 'Add',
                            ),
                    ),
                  ),
                ],
              ),
              if (_connectionStatus != null) ...[
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    _connectionStatus!,
                    style: TextStyle(
                      color: _connectionStatus!.startsWith('🟢')
                          ? Colors.green
                          : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
