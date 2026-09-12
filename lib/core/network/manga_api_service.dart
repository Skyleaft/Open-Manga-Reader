import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';
import '../config/app_config.dart';
import '../models/manga_summary.dart';
import '../models/paged_response.dart';
import '../models/chapter_page.dart';
import '../di/injection.dart';
import '../services/network_status_service.dart';
import '../widgets/alert_banner.dart';
import '../../features/discover/models/advanced_recommendation_request.dart';
import '../../features/discover/models/query_paged_manga_request.dart';

class MangaApiService {
  static const String _tokenKey = 'auth_token';
  static const String _userIdKey = 'auth_user_id';
  static const String _usernameKey = 'auth_username';
  static const String _expiryKey = 'auth_expiry';

  final Dio _dio;
  String? _jwtToken;
  String? _userId;
  String? _username;
  String? _expiry;

  List<String>? _cachedGenres;
  List<String>? _cachedTypes;
  DateTime? _lastRateLimitAlertTime;

  String? get userId => _userId;
  String? get username => _username;
  String? get expiry => _expiry;
  String? get jwtToken => _jwtToken;

  MangaApiService()
    : _dio = Dio(
        BaseOptions(
          baseUrl: AppConfig.baseUrl,
          connectTimeout: const Duration(seconds: 45),
          receiveTimeout: const Duration(seconds: 45),
        ),
      ) {
    _dio.transformer = BackgroundTransformer();
    _initInterceptor();
  }

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _jwtToken = prefs.getString(_tokenKey);
    _userId = prefs.getString(_userIdKey);
    _username = prefs.getString(_usernameKey);
    _expiry = prefs.getString(_expiryKey);
  }

  dynamic _unwrap(dynamic responseData) {
    if (responseData is Map<String, dynamic> &&
        responseData.containsKey('data')) {
      return responseData['data'];
    }
    return responseData;
  }

  void _initInterceptor() {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (_jwtToken != null) {
            options.headers['Authorization'] = 'Bearer $_jwtToken';
          }
          if (kDebugMode) {
            options.extra['requestStartTime'] =
                DateTime.now().millisecondsSinceEpoch;
            debugPrint('🌐 [API REQ] ${options.method} ${options.uri}');
            if (options.data != null) {
              debugPrint('   📦 Data: ${options.data}');
            }
          }
          return handler.next(options);
        },
        onResponse: (response, handler) {
          if (getIt.isRegistered<NetworkStatusService>()) {
            getIt<NetworkStatusService>().reportNetworkSuccess();
          }
          if (kDebugMode) {
            final startTime =
                response.requestOptions.extra['requestStartTime'] as int?;
            final durationStr = startTime != null
                ? ' (${DateTime.now().millisecondsSinceEpoch - startTime}ms)'
                : '';
            debugPrint(
              '✅ [API RES] ${response.requestOptions.method} ${response.requestOptions.uri} -> [${response.statusCode}]$durationStr',
            );
          }
          return handler.next(response);
        },
        onError: (DioException e, handler) async {
          if (e.type == DioExceptionType.connectionError ||
              e.type == DioExceptionType.connectionTimeout ||
              e.type == DioExceptionType.sendTimeout ||
              e.type == DioExceptionType.receiveTimeout) {
            if (getIt.isRegistered<NetworkStatusService>()) {
              getIt<NetworkStatusService>().reportNetworkError();
            }
          }
          if (kDebugMode) {
            final startTime =
                e.requestOptions.extra['requestStartTime'] as int?;
            final durationStr = startTime != null
                ? ' (${DateTime.now().millisecondsSinceEpoch - startTime}ms)'
                : '';
            debugPrint(
              '❌ [API ERR] ${e.requestOptions.method} ${e.requestOptions.uri} -> [${e.response?.statusCode ?? 'NO STATUS'}]$durationStr',
            );
            if (e.message != null && e.message!.isNotEmpty) {
              debugPrint('   ⚠️ Message: ${e.message}');
            }
            if (e.response?.data != null) {
              debugPrint('   ⚠️ Response Body: ${e.response?.data}');
            }
          }

          if (e.response?.statusCode == 429) {
            _handleRateLimit(e);
          }

          if (e.response?.statusCode == 401 &&
              e.requestOptions.path != '/api/v1/auth/firebase') {
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
              debugPrint('Token refresh failed: $error');
            }

            debugPrint('Unauthorized, clearing token...');
            _jwtToken = null;
            _userId = null;
            _username = null;
            _expiry = null;
            final prefs = await SharedPreferences.getInstance();
            await prefs.remove(_tokenKey);
            await prefs.remove(_userIdKey);
            await prefs.remove(_usernameKey);
            await prefs.remove(_expiryKey);
          }
          return handler.next(e);
        },
      ),
    );
  }

  void _handleRateLimit(DioException e) {
    final now = DateTime.now();
    if (_lastRateLimitAlertTime != null &&
        now.difference(_lastRateLimitAlertTime!) < const Duration(seconds: 3)) {
      return;
    }
    _lastRateLimitAlertTime = now;

    String message =
        'Terlalu banyak permintaan (Rate limit). Mohon tunggu beberapa saat.';

    final retryAfter = e.response?.headers.value('retry-after');
    final responseData = e.response?.data;

    if (responseData is Map<String, dynamic>) {
      final msg = responseData['message'] ??
          responseData['detail'] ??
          responseData['error'] ??
          responseData['title'];
      if (msg != null && msg.toString().trim().isNotEmpty) {
        message = msg.toString().trim();
      }
    } else if (responseData is String && responseData.trim().isNotEmpty) {
      message = responseData.trim();
    } else if (retryAfter != null && retryAfter.isNotEmpty) {
      message =
          'Rate limit tercapai. Silakan coba lagi dalam $retryAfter detik.';
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      AlertBanner.showGlobal(
        message,
        type: AlertBannerType.warning,
        duration: const Duration(milliseconds: 4000),
      );
    });
  }

  Future<void> loginWithFirebase(String idToken) async {
    try {
      final response = await _dio.post(
        '/api/v1/auth/firebase',
        data: {'idToken': idToken},
      );
      final unwrapped = _unwrap(response.data);
      if (unwrapped is Map<String, dynamic>) {
        _jwtToken = unwrapped['token'] as String?;
        _userId = unwrapped['userId'] as String?;
        _username = unwrapped['username'] as String?;
        _expiry = unwrapped['expiry'] as String?;
      } else if (response.data is Map<String, dynamic>) {
        _jwtToken = response.data['token'] as String?;
        _userId = response.data['userId'] as String?;
        _username = response.data['username'] as String?;
        _expiry = response.data['expiry'] as String?;
      }

      final prefs = await SharedPreferences.getInstance();
      if (_jwtToken != null) await prefs.setString(_tokenKey, _jwtToken!);
      if (_userId != null) await prefs.setString(_userIdKey, _userId!);
      if (_username != null) await prefs.setString(_usernameKey, _username!);
      if (_expiry != null) await prefs.setString(_expiryKey, _expiry!);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> logout() async {
    try {
      await _dio.post('/api/v1/auth/logout');
    } catch (e) {
      // Ignore error on logout
    } finally {
      _jwtToken = null;
      _userId = null;
      _username = null;
      _expiry = null;
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey);
      await prefs.remove(_userIdKey);
      await prefs.remove(_usernameKey);
      await prefs.remove(_expiryKey);
    }
  }

  void updateBaseUrl(String newUrl) {
    String sanitized = newUrl.trim();
    while (sanitized.endsWith('/') && sanitized.length > 8) {
      sanitized = sanitized.substring(0, sanitized.length - 1);
    }
    _dio.options.baseUrl = sanitized;
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
        '/api/v1/manga',
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

      final unwrapped = _unwrap(response.data) as Map<String, dynamic>;
      return PagedResponse.fromJson(
        unwrapped,
        (json) => MangaSummary.fromJson(json),
      );
    } catch (e) {
      rethrow;
    }
  }

  Future<PagedResponse<MangaSummary>> queryPagedManga(
    QueryPagedMangaRequest request,
  ) async {
    try {
      final response = await _dio.request(
        '/api/v1/manga',
        data: request.toMap(),
        options: Options(method: 'QUERY'),
      );

      final unwrapped = _unwrap(response.data) as Map<String, dynamic>;
      return PagedResponse.fromJson(
        unwrapped,
        (json) => MangaSummary.fromJson(json),
      );
    } catch (e) {
      rethrow;
    }
  }

  Future<PagedResponse<MangaSummary>> getTrending({
    String? search,
    List<String>? genres,
    String? status,
    String? type,
    int page = 1,
    int pageSize = 10,
  }) async {
    try {
      final response = await _dio.get(
        '/api/v1/manga/trending',
        queryParameters: {
          'search': search,
          if (genres != null && genres.isNotEmpty) 'genres': genres,
          'status': status,
          'type': type,
          'page': page,
          'pageSize': pageSize,
        },
      );

      final unwrapped = _unwrap(response.data) as Map<String, dynamic>;
      return PagedResponse.fromJson(
        unwrapped,
        (json) => MangaSummary.fromJson(json),
      );
    } catch (e) {
      rethrow;
    }
  }

  Future<List<MangaSummary>> searchSemantic(
    String query, {
    int limit = 10,
  }) async {
    try {
      final response = await _dio.get(
        '/api/v1/manga/search/semantic',
        queryParameters: {'q': query, 'limit': limit},
      );
      final unwrapped = _unwrap(response.data);
      final List<dynamic> items = unwrapped is List
          ? unwrapped
          : (unwrapped['items'] ?? []);
      return items
          .map((json) => MangaSummary.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<List<MangaSummary>> getSimilarManga(
    String mangaId, {
    int limit = 10,
  }) async {
    try {
      final response = await _dio.get(
        '/api/v1/manga/$mangaId/similar',
        queryParameters: {'limit': limit},
      );
      final unwrapped = _unwrap(response.data);
      final List<dynamic> items = unwrapped is List
          ? unwrapped
          : (unwrapped['items'] ?? []);
      return items
          .map((json) => MangaSummary.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<List<MangaSummary>> getSimilarMangaFiltered(
    String mangaId, {
    String? status,
    String? type,
    List<String>? genres,
    int limit = 10,
  }) async {
    try {
      final response = await _dio.get(
        '/api/v1/manga/$mangaId/similar/filtered',
        queryParameters: {
          if (status != null && status.isNotEmpty) 'status': status,
          if (type != null && type.isNotEmpty) 'type': type,
          if (genres != null && genres.isNotEmpty) 'genres': genres,
          'limit': limit,
        },
      );
      final unwrapped = _unwrap(response.data);
      final List<dynamic> items = unwrapped is List
          ? unwrapped
          : (unwrapped['items'] ?? []);
      return items
          .map((json) => MangaSummary.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<List<MangaSummary>> getSimilarMangaByCategory({
    List<String>? categories,
    String? status,
    String? type,
    List<String>? genres,
    String? excludeMangaId,
    int limit = 20,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.get(
        '/api/v1/manga/similar/by-category',
        queryParameters: {
          if (categories != null && categories.isNotEmpty)
            'categories': categories,
          if (status != null && status.isNotEmpty) 'status': status,
          if (type != null && type.isNotEmpty) 'type': type,
          if (genres != null && genres.isNotEmpty) 'genres': genres,
          if (excludeMangaId != null && excludeMangaId.isNotEmpty)
            'excludeMangaId': excludeMangaId,
          'limit': limit,
        },
        cancelToken: cancelToken,
      );
      final unwrapped = _unwrap(response.data);
      final List<dynamic> items = unwrapped is List
          ? unwrapped
          : (unwrapped['items'] ?? []);
      return items
          .map((json) => MangaSummary.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<List<MangaSummary>> getSimilarMangaByIdCategories(
    String mangaId, {
    String? status,
    String? type,
    List<String>? genres,
    int limit = 20,
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.get(
        '/api/v1/manga/$mangaId/similar/by-category',
        queryParameters: {
          if (status != null && status.isNotEmpty) 'status': status,
          if (type != null && type.isNotEmpty) 'type': type,
          if (genres != null && genres.isNotEmpty) 'genres': genres,
          'limit': limit,
        },
        cancelToken: cancelToken,
      );
      final unwrapped = _unwrap(response.data);
      final List<dynamic> items = unwrapped is List
          ? unwrapped
          : (unwrapped['items'] ?? []);
      return items
          .map((json) => MangaSummary.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<List<MangaSummary>> getAdvancedRecommendations(
    AdvancedRecommendationRequest request,
  ) async {
    try {
      final response = await _dio.post(
        '/api/v1/manga/recommend/advanced',
        data: request.toMap(),
      );
      final unwrapped = _unwrap(response.data);
      final List<dynamic> items = unwrapped is List
          ? unwrapped
          : (unwrapped['items'] ?? []);
      return items
          .map((json) => MangaSummary.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<List<MangaSummary>> getRecommendations({
    List<String>? readingHistoryIds,
    int limit = 10,
  }) async {
    try {
      final response = await _dio.get(
        '/api/v1/manga/recomendations',
        queryParameters: {
          'readingHistoryIds': readingHistoryIds ?? [],
          'limit': limit,
        },
      );

      final unwrapped = _unwrap(response.data);
      final List<dynamic> items = unwrapped is List
          ? unwrapped
          : (unwrapped['items'] ?? []);
      return items
          .map((json) => MangaSummary.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getMangaDetail(
    String mangaId, {
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.get(
        '/api/v1/manga/$mangaId',
        cancelToken: cancelToken,
      );
      final unwrapped = _unwrap(response.data);
      return unwrapped as Map<String, dynamic>;
    } catch (e) {
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getMangaChapters(
    String mangaId, {
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.get(
        '/api/v1/manga/$mangaId/chapters',
        cancelToken: cancelToken,
      );
      final unwrapped = _unwrap(response.data);
      if (unwrapped is List) {
        return unwrapped.map((e) => e as Map<String, dynamic>).toList();
      }
      return [];
    } catch (e) {
      rethrow;
    }
  }

  Future<List<String>> getAllGenres() async {
    if (_cachedGenres != null) return _cachedGenres!;
    try {
      final response = await _dio.get('/api/v1/manga/genres');
      final unwrapped = _unwrap(response.data);
      if (unwrapped is List) {
        _cachedGenres = unwrapped.map((e) => e.toString()).toList();
        return _cachedGenres!;
      }
      return [];
    } catch (e) {
      rethrow;
    }
  }

  Future<List<String>> getAllTypes() async {
    if (_cachedTypes != null) return _cachedTypes!;
    try {
      final response = await _dio.get('/api/v1/manga/types');
      final unwrapped = _unwrap(response.data);
      if (unwrapped is List) {
        _cachedTypes = unwrapped.map((e) => e.toString()).toList();
        return _cachedTypes!;
      }
      return [];
    } catch (e) {
      rethrow;
    }
  }

  Future<List<ChapterPage>> getChapterPages(
    String mangaId,
    dynamic chapterId, {
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _dio.get(
        '/api/v1/manga/$mangaId/chapters/$chapterId',
        cancelToken: cancelToken,
      );
      final unwrapped = _unwrap(response.data);
      if (unwrapped is Map<String, dynamic>) {
        final pages = unwrapped['pages'] as List<dynamic>?;
        if (pages != null) {
          return pages.map((p) => ChapterPage.fromDynamic(p)).toList();
        }
      } else if (unwrapped is List) {
        return unwrapped.map((e) => ChapterPage.fromDynamic(e)).toList();
      }
      return [];
    } catch (e) {
      rethrow;
    }
  }

  Future<void> incrementChapterView(String mangaId, dynamic chapterId) async {
    try {
      await _dio.post('/api/v1/manga/$mangaId/chapters/$chapterId/view');
    } catch (e) {
      debugPrint('Failed to increment chapter view: $e');
    }
  }

  String getImageUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http')) return path;

    String baseUrl = AppConfig.baseUrl;
    String cleanPath = path.startsWith('/') ? path : '/$path';

    return '$baseUrl$cleanPath';
  }

  String getLocalImageUrl(String? localPath, String? remotePath) {
    if (localPath == null || localPath.isEmpty) {
      return getImageUrl(remotePath);
    }
    if (localPath.startsWith('http')) return localPath;

    String baseUrl = AppConfig.baseUrl;

    if (localPath.startsWith('/api/v1/images/') ||
        localPath.startsWith('/api/images/')) {
      return '$baseUrl$localPath';
    }

    if (localPath.startsWith('api/v1/images/') ||
        localPath.startsWith('api/images/')) {
      return '$baseUrl/$localPath';
    }

    String cleanLocalPath = localPath.startsWith('/')
        ? localPath.substring(1)
        : localPath;
    return '$baseUrl/images/$cleanLocalPath';
  }

  Future<void> scrapManga(
    String mangaUrl,
    bool scrapChapters,
    String provider, {
    String? linkId,
  }) async {
    try {
      await _dio.post(
        '/api/v1/scrapper/$provider',
        data: {
          'mangaUrl': mangaUrl,
          'scrapChapterPages': scrapChapters,
          'linkId': ?linkId,
        },
      );
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getScrapMangaDetail({
    required String provider,
    required String mangaUrl,
  }) async {
    try {
      final response = await _dio.get(
        '/api/v1/scrapper/$provider/detail',
        queryParameters: {'mangaUrl': mangaUrl},
      );
      final unwrapped = _unwrap(response.data);
      return unwrapped is Map<String, dynamic>
          ? unwrapped
          : response.data as Map<String, dynamic>;
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
        '/api/v1/scrapper/$provider/search',
        queryParameters: {
          'Keyword': ?keyword,
          if (genres != null && genres.isNotEmpty) 'Genres': genres,
          'Status': ?status,
          'Type': ?type,
          'Page': page,
        },
      );
      final unwrapped = _unwrap(response.data);
      if (unwrapped is List) {
        return unwrapped.map((e) => e as Map<String, dynamic>).toList();
      }
      return [];
    } catch (e) {
      rethrow;
    }
  }

  Future<void> updateMangaMetadata(String mangaId) async {
    try {
      await _dio.get('/api/v1/scrapper/manga/$mangaId/metadata');
    } catch (e) {
      rethrow;
    }
  }

  Future<void> scrapChapterPagesNew(String mangaId) async {
    try {
      await _dio.get('/api/v1/scrapper/manga/$mangaId/chapter-pages');
    } catch (e) {
      rethrow;
    }
  }

  Future<void> fixFile() async {
    try {
      await _dio.get('/api/v1/scrapper/fixfile');
    } catch (e) {
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getScrapQueue() async {
    try {
      final response = await _dio.get('/api/v1/scrapper/queue');
      final unwrapped = _unwrap(response.data);
      if (unwrapped is List) {
        return unwrapped.map((e) => e as Map<String, dynamic>).toList();
      }
      return [];
    } catch (e) {
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getScrapProviders() async {
    try {
      final response = await _dio.get('/api/v1/scrapper/providers');
      final unwrapped = _unwrap(response.data);
      if (unwrapped is List) {
        return unwrapped.map((e) => e as Map<String, dynamic>).toList();
      }
      return [];
    } catch (e) {
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getUserLibrary({
    String? userId,
    String? search,
  }) async {
    try {
      final activeUserId = (userId != null && userId.isNotEmpty)
          ? userId
          : _userId;
      final response = (search != null && search.isNotEmpty)
          ? await _dio.get(
              '/api/v1/user-library',
              queryParameters: {
                if (activeUserId != null && activeUserId.isNotEmpty)
                  'userId': activeUserId,
                'search': search,
              },
            )
          : await _dio.get(
              '/api/v1/user-library/all',
              queryParameters: {
                if (activeUserId != null && activeUserId.isNotEmpty)
                  'userId': activeUserId,
              },
            );

      final unwrapped = _unwrap(response.data);
      if (unwrapped is List) {
        return unwrapped.map((e) => e as Map<String, dynamic>).toList();
      } else if (unwrapped is Map<String, dynamic> &&
          unwrapped.containsKey('items')) {
        final items = unwrapped['items'] as List<dynamic>?;
        return items?.map((e) => e as Map<String, dynamic>).toList() ?? [];
      }
      return [];
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> addToUserLibrary(
    Map<String, dynamic> data,
  ) async {
    try {
      if ((data['userId'] == null || (data['userId'] as String).isEmpty) &&
          _userId != null) {
        data['userId'] = _userId;
      }
      final response = await _dio.post('/api/v1/user-library', data: data);
      final unwrapped = _unwrap(response.data);
      return unwrapped is Map<String, dynamic> ? unwrapped : {};
    } catch (e) {
      rethrow;
    }
  }

  Future<void> removeFromUserLibrary(String libraryIdOrMangaId) async {
    try {
      await _dio.delete('/api/v1/user-library/$libraryIdOrMangaId');
    } catch (e) {
      rethrow;
    }
  }

  // --- User Progression Endpoints ---

  Future<List<Map<String, dynamic>>> getUserProgression([
    String? userId,
  ]) async {
    try {
      final uid = (userId != null && userId.isNotEmpty) ? userId : _userId;
      final endpoint = '/api/v1/user-progression/$uid';
      final response = await _dio.get(endpoint);
      final unwrapped = _unwrap(response.data);
      if (unwrapped is List) {
        return unwrapped.map((e) => e as Map<String, dynamic>).toList();
      }
      return [];
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> getProgressionForManga(
    String? userId,
    String mangaId,
  ) async {
    try {
      final uid = (userId != null && userId.isNotEmpty) ? userId : _userId;
      final endpoint = '/api/v1/user-progression/$uid/$mangaId';
      final response = await _dio.get(endpoint);
      if (response.statusCode == 204) return null;
      final unwrapped = _unwrap(response.data);
      return unwrapped is Map<String, dynamic> ? unwrapped : null;
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
      if ((data['userId'] == null || (data['userId'] as String).isEmpty) &&
          _userId != null) {
        data['userId'] = _userId;
      }
      final response = await _dio.post('/api/v1/user-progression', data: data);
      final unwrapped = _unwrap(response.data);
      return unwrapped is Map<String, dynamic> ? unwrapped : {};
    } catch (e) {
      rethrow;
    }
  }

  // --- User Heartbeat ---

  Future<Map<String, dynamic>> patchUserHeartbeat() async {
    try {
      final response = await _dio.patch('/api/v1/users/heartbeat');
      final unwrapped = _unwrap(response.data);
      return unwrapped is Map<String, dynamic> ? unwrapped : {};
    } catch (e) {
      rethrow;
    }
  }

  // --- FCM Token Management ---

  Future<dynamic> registerFcmToken(String fcmToken) async {
    try {
      final response = await _dio.post(
        '/api/v1/users/fcm-token',
        data: {'fcmToken': fcmToken},
      );
      return _unwrap(response.data);
    } catch (e) {
      debugPrint('Failed to register FCM token: $e');
      rethrow;
    }
  }

  Future<dynamic> unregisterFcmToken(String fcmToken) async {
    try {
      final response = await _dio.delete(
        '/api/v1/users/fcm-token',
        data: {'fcmToken': fcmToken},
      );
      return _unwrap(response.data);
    } catch (e) {
      debugPrint('Failed to unregister FCM token: $e');
      rethrow;
    }
  }
}
