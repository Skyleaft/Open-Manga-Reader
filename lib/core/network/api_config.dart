import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ApiConfig {
  final String id;
  final String name;
  final String baseUrl;
  final String? apiKey;
  final Map<String, String> headers;
  final bool isDefault;

  ApiConfig({
    required this.id,
    required this.name,
    required this.baseUrl,
    this.apiKey,
    this.headers = const {},
    this.isDefault = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'baseUrl': baseUrl,
      'apiKey': apiKey,
      'headers': headers,
      'isDefault': isDefault,
    };
  }

  factory ApiConfig.fromJson(Map<String, dynamic> json) {
    return ApiConfig(
      id: json['id'] as String,
      name: json['name'] as String,
      baseUrl: json['baseUrl'] as String,
      apiKey: json['apiKey'] as String?,
      headers: Map<String, String>.from(json['headers'] ?? {}),
      isDefault: json['isDefault'] as bool? ?? false,
    );
  }

  @override
  String toString() {
    return 'ApiConfig(id: $id, name: $name, baseUrl: $baseUrl, apiKey: $apiKey, headers: $headers, isDefault: $isDefault)';
  }
}

class ApiConfigManager {
  static const String _prefsKey = 'api_configs';
  static const String _activeApiIdKey = 'active_api_id';

  static Future<void> saveApiConfigs(List<ApiConfig> configs) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = configs
        .map((config) => jsonEncode(config.toJson()))
        .toList();
    await prefs.setStringList(_prefsKey, jsonList);
  }

  static Future<List<ApiConfig>> loadApiConfigs() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = prefs.getStringList(_prefsKey) ?? [];

    return jsonList.map((jsonString) {
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      return ApiConfig.fromJson(json);
    }).toList();
  }

  static Future<void> setActiveApiId(String apiId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activeApiIdKey, apiId);
  }

  static Future<String?> getActiveApiId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_activeApiIdKey);
  }

  static Future<void> addApiConfig(ApiConfig config) async {
    final configs = await loadApiConfigs();
    configs.add(config);
    await saveApiConfigs(configs);

    final activeId = await getActiveApiId();
    if (activeId == null || configs.length == 1) {
      await setActiveApiId(config.id);
    }
  }

  static Future<void> updateApiConfig(ApiConfig config) async {
    final configs = await loadApiConfigs();
    final index = configs.indexWhere((c) => c.id == config.id);
    if (index != -1) {
      configs[index] = config;
      await saveApiConfigs(configs);
    }
  }

  static Future<void> deleteApiConfig(String apiId) async {
    final configs = await loadApiConfigs();
    if (configs.length <= 1) {
      throw StateError(
        'Cannot delete the only API config. At least 1 active API is required.',
      );
    }

    configs.removeWhere((c) => c.id == apiId);
    await saveApiConfigs(configs);

    final activeId = await getActiveApiId();
    if (activeId == apiId && configs.isNotEmpty) {
      await setActiveApiId(configs.first.id);
    }
  }

  static Future<ApiConfig?> getActiveApiConfig() async {
    final configs = await loadApiConfigs();
    if (configs.isEmpty) return null;

    final activeId = await getActiveApiId();
    if (activeId != null) {
      final matches = configs.where((config) => config.id == activeId);
      if (matches.isNotEmpty) {
        return matches.first;
      }
    }

    await setActiveApiId(configs.first.id);
    return configs.first;
  }
}
