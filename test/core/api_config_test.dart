import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_manga_reader/core/network/api_config.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('ApiConfigManager Tests', () {
    test('getActiveApiConfig returns null when no configs exist', () async {
      final config = await ApiConfigManager.getActiveApiConfig();
      expect(config, isNull);
    });

    test('addApiConfig automatically activates the first config', () async {
      final config1 = ApiConfig(
        id: 'api-1',
        name: 'Primary API',
        baseUrl: 'https://api1.example.com',
      );

      await ApiConfigManager.addApiConfig(config1);

      final active = await ApiConfigManager.getActiveApiConfig();
      expect(active, isNotNull);
      expect(active!.id, 'api-1');
      expect(active.baseUrl, 'https://api1.example.com');
    });

    test('deleteApiConfig prevents deleting the only remaining API', () async {
      final config1 = ApiConfig(
        id: 'api-1',
        name: 'Primary API',
        baseUrl: 'https://api1.example.com',
      );

      await ApiConfigManager.addApiConfig(config1);

      expect(
        () async => await ApiConfigManager.deleteApiConfig('api-1'),
        throwsA(isA<StateError>()),
      );

      final configs = await ApiConfigManager.loadApiConfigs();
      expect(configs.length, 1);
    });

    test('deleteApiConfig reassigns active API when deleting active config', () async {
      final config1 = ApiConfig(
        id: 'api-1',
        name: 'Primary API',
        baseUrl: 'https://api1.example.com',
      );
      final config2 = ApiConfig(
        id: 'api-2',
        name: 'Secondary API',
        baseUrl: 'https://api2.example.com',
      );

      await ApiConfigManager.addApiConfig(config1);
      await ApiConfigManager.addApiConfig(config2);

      expect((await ApiConfigManager.getActiveApiConfig())?.id, 'api-1');

      // Delete active config1
      await ApiConfigManager.deleteApiConfig('api-1');

      final active = await ApiConfigManager.getActiveApiConfig();
      expect(active, isNotNull);
      expect(active!.id, 'api-2');

      // Now config2 is the only remaining config, cannot be deleted
      expect(
        () async => await ApiConfigManager.deleteApiConfig('api-2'),
        throwsA(isA<StateError>()),
      );
    });
  });
}
