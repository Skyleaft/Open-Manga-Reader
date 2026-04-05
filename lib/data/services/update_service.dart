import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';

class UpdateService {
  final Dio _dio = Dio();

  Future<Map<String, dynamic>?> checkForUpdate() async {
    try {
      final response = await _dio.get(
        'https://api.github.com/repos/Skyleaft/Open-Manga-Reader/releases/latest'
      );
      
      if (response.statusCode == 200) {
        final data = response.data;
        final String latestVersion = (data['tag_name'] as String).replaceAll('v', '').trim();
        
        final packageInfo = await PackageInfo.fromPlatform();
        final String currentVersion = packageInfo.version;
        
        if (_isNewerVersion(currentVersion, latestVersion)) {
          return {
            'version': data['tag_name'],
            'body': data['body'],
            'url': data['html_url'],
          };
        }
      }
    } catch (e) {
      print('Failed to check for updates: $e');
    }
    return null;
  }

  bool _isNewerVersion(String current, String latest) {
    try {
      final v1 = current.split('+')[0].split('.').map((e) => int.tryParse(e) ?? 0).toList();
      final v2 = latest.split('+')[0].split('.').map((e) => int.tryParse(e) ?? 0).toList();
      
      for (int i = 0; i < 3; i++) {
        final part1 = i < v1.length ? v1[i] : 0;
        final part2 = i < v2.length ? v2[i] : 0;
        if (part2 > part1) return true;
        if (part2 < part1) return false;
      }
    } catch (e) {
      print("Version parse error: $e");
    }
    return false;
  }
}
