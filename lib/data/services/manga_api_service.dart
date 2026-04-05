import 'package:dio/dio.dart';
import '../../core/config/app_config.dart';
import '../models/manga_summary.dart';
import '../models/paged_response.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MangaApiService {
  static const String _tokenKey = 'auth_token';
  final Dio _dio;
  String? _jwtToken;

  List<String>? _cachedGenres;
  List<String>? _cachedTypes;

  MangaApiService()
    : _dio = Dio(
        BaseOptions(
          baseUrl: AppConfig.baseUrl,
          connectTimeout: const Duration(seconds: 45),
          receiveTimeout: const Duration(seconds: 45),
        ),
      ) {
    _initInterceptor();
  }

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _jwtToken = prefs.getString(_tokenKey);
  }

  void _initInterceptor() {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (_jwtToken != null) {
            options.headers['Authorization'] = 'Bearer $_jwtToken';
          }
          return handler.next(options);
        },
        onError: (DioException e, handler) async {
          if (e.response?.statusCode == 401 &&
              e.requestOptions.path != '/api/auth/firebase') {
            try {
              final user = FirebaseAuth.instance.currentUser;
              if (user != null) {
                final idToken = await user.getIdToken(true);
                if (idToken != null) {
                  await loginWithFirebase(idToken);

                  // Retry the request with the new token
                  final response = await _dio.fetch(e.requestOptions);
                  return handler.resolve(response);
                }
              }
            } catch (error) {
              print('Token refresh failed: $error');
            }

            print('Unauthorized, clearing token...');
            _jwtToken = null;
            final prefs = await SharedPreferences.getInstance();
            await prefs.remove(_tokenKey);
          }
          return handler.next(e);
        },
      ),
    );
  }

  Future<void> loginWithFirebase(String idToken) async {
    try {
      final response = await _dio.post(
        '/api/auth/firebase',
        data: {'idToken': idToken},
      );
      _jwtToken = response.data['token'];
      if (_jwtToken != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_tokenKey, _jwtToken!);
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> logout() async {
    try {
      await _dio.get('/api/auth/logout');
    } catch (e) {
      // Ignore error on logout
    } finally {
      _jwtToken = null;
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey);
    }
  }

  void updateBaseUrl(String newUrl) {
    _dio.options.baseUrl = newUrl;
  }

  Future<PagedResponse<MangaSummary>> getPagedManga({
    String? search,
    List<String>? genres,
    String? status,
    String? type,
    String? sortBy,
    String? orderBy,
    int page = 1,
    int pageSize = 10,
  }) async {
    try {
      final response = await _dio.get(
        '/api/manga/paged',
        queryParameters: {
          'search': search,
          if (genres != null && genres.isNotEmpty) 'genres': genres,
          'status': status,
          'type': type,
          'sortBy': sortBy,
          'orderBy': orderBy,
          'page': page,
          'pageSize': pageSize,
        },
      );

      return PagedResponse.fromJson(
        response.data as Map<String, dynamic>,
        (json) => MangaSummary.fromJson(json),
      );
    } catch (e) {
      rethrow;
    }
  }

  Future<List<MangaSummary>> getRecommendations({
    List<String>? readingHistoryIds,
    int limit = 10,
  }) async {
    try {
      final response = await _dio.post(
        '/api/manga/recommendations',
        data: {'readingHistoryIds': readingHistoryIds ?? [], 'limit': limit},
      );

      final List<dynamic> items = response.data['items'];
      return items.map((json) => MangaSummary.fromJson(json)).toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getMangaDetail(String mangaId) async {
    try {
      final response = await _dio.get('/api/manga/$mangaId');
      return response.data as Map<String, dynamic>;
    } catch (e) {
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getMangaChapters(String mangaId) async {
    try {
      final response = await _dio.get('/api/manga/$mangaId/chapters');
      return (response.data as List<dynamic>)
          .map((e) => e as Map<String, dynamic>)
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<List<String>> getAllGenres() async {
    if (_cachedGenres != null) return _cachedGenres!;
    try {
      final response = await _dio.get('/api/manga/genres');
      _cachedGenres = (response.data as List<dynamic>)
          .map((e) => e.toString())
          .toList();
      return _cachedGenres!;
    } catch (e) {
      rethrow;
    }
  }

  Future<List<String>> getAllTypes() async {
    if (_cachedTypes != null) return _cachedTypes!;
    try {
      final response = await _dio.get('/api/manga/types');
      _cachedTypes = (response.data as List<dynamic>)
          .map((e) => e.toString())
          .toList();
      return _cachedTypes!;
    } catch (e) {
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getChapterPages(
    String mangaId,
    double chapterNumber,
  ) async {
    try {
      final response = await _dio.get(
        '/api/manga/$mangaId/chapter/$chapterNumber',
      );
      return (response.data as List<dynamic>)
          .map((e) => e as Map<String, dynamic>)
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  String getImageUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    return '${AppConfig.baseUrl}$path';
  }

  String getLocalImageUrl(String? localPath, String? remotePath) {
    if (localPath == null || localPath.isEmpty) {
      return getImageUrl(remotePath);
    }
    if (localPath.startsWith('http')) return localPath;

    // If it already includes the full path including endpoint
    if (localPath.startsWith('/api/images/')) {
      return '${AppConfig.baseUrl}$localPath';
    }

    return '${AppConfig.baseUrl}/api/images/$localPath';
  }

  Future<void> scrapManga(
    String mangaUrl,
    bool scrapChapters,
    String provider,
  ) async {
    try {
      await _dio.post(
        '/api/scrapper/$provider/manga',
        data: {'mangaUrl': mangaUrl, 'scrapChapterPages': scrapChapters},
      );
    } catch (e) {
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> searchScrapSource({
    String? keyword,
    List<String>? genres,
    String? status,
    String? type,
    int page = 1,
    required String provider,
  }) async {
    try {
      final response = await _dio.get(
        '/api/scrapper/$provider/manga/search',
        queryParameters: {
          'keyword': keyword,
          if (genres != null && genres.isNotEmpty) 'genres': genres,
          'status': status,
          'type': type,
          'page': page,
        },
      );
      return (response.data as List<dynamic>)
          .map((e) => e as Map<String, dynamic>)
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateMangaMetadata(String mangaId) async {
    try {
      await _dio.get('/api/scrapper/manga/$mangaId/metadata');
    } catch (e) {
      rethrow;
    }
  }

  Future<void> scrapChapterPagesNew(String mangaId) async {
    try {
      await _dio.get('/api/scrapper/manga/$mangaId/chapter-pages');
    } catch (e) {
      rethrow;
    }
  }

  Future<void> fixFile() async {
    try {
      await _dio.get('/api/scrapper/fixfile');
    } catch (e) {
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getScrapQueue() async {
    try {
      final response = await _dio.get('/api/scrapper/queue');
      return (response.data as List<dynamic>)
          .map((e) => e as Map<String, dynamic>)
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getScrapProviders() async {
    try {
      final response = await _dio.get('/api/scrapper/providers');
      return (response.data as List<dynamic>)
          .map((e) => e as Map<String, dynamic>)
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  // --- Library Endpoints ---

  Future<List<Map<String, dynamic>>> getUserLibrary() async {
    try {
      final response = await _dio.get('/api/user-library');
      return (response.data as List<dynamic>)
          .map((e) => e as Map<String, dynamic>)
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> addToUserLibrary(
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await _dio.post('/api/user-library', data: data);
      return response.data as Map<String, dynamic>;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> removeFromUserLibrary(String mangaId) async {
    try {
      await _dio.delete('/api/user-library/$mangaId');
    } catch (e) {
      rethrow;
    }
  }

  // --- Progression Endpoints ---

  Future<List<Map<String, dynamic>>> getUserProgression() async {
    try {
      final response = await _dio.get('/api/user-progression');
      return (response.data as List<dynamic>)
          .map((e) => e as Map<String, dynamic>)
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> getProgressionForManga(String mangaId) async {
    try {
      final response = await _dio.get('/api/user-progression/$mangaId');
      if (response.statusCode == 204) return null; // Or appropriate empty check
      return response.data as Map<String, dynamic>;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> updateUserProgression(
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await _dio.post('/api/user-progression', data: data);
      return response.data as Map<String, dynamic>;
    } catch (e) {
      rethrow;
    }
  }
}
