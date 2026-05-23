import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:my_manga_reader/data/services/auth_service.dart';
import 'package:my_manga_reader/data/models/api_config.dart';
import 'core/theme/app_theme.dart';
import 'routes/app_pages.dart';
import 'presentation/screens/auth/login_screen.dart';
import 'package:app_links/app_links.dart';
import 'data/services/manga_api_service.dart';
import 'data/models/manga_detail.dart';
import 'core/di/injection.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Provider<AuthService>(
      create: (_) => AuthService(),
      child: MaterialApp(
        title: 'Open Manga Reader',
        navigatorKey: AppRoutes.navigatorKey,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.system,
        home: const AuthWrapper(),
        routes: AppRoutes.routes,
      ),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final AuthService _authService = AuthService();
  bool _isCheckingAuth = true;
  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;
  StreamSubscription<User?>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
    _checkAuthState();
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initDeepLinks() async {
    _appLinks = AppLinks();

    // Handle links when app is already open
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      _handleDeepLink(uri);
    });

    // Handle link that opened the app
    final initialUri = await _appLinks.getInitialLink();
    if (initialUri != null) {
      _handleDeepLink(initialUri);
    }
  }

  Future<void> _handleDeepLink(Uri uri) async {
    // Expected format: /manga/id or skyleaft-manga://manga/id
    String? mangaId;
    if (uri.pathSegments.length >= 2 && uri.pathSegments[0] == 'manga') {
      mangaId = uri.pathSegments[1];
    } else if (uri.host == 'manga' && uri.pathSegments.isNotEmpty) {
      mangaId = uri.pathSegments[0];
    }

    if (mangaId != null) {
      try {
        final apiService = getIt<MangaApiService>();
        final mangaData = await apiService.getMangaDetail(mangaId);
        final manga = MangaDetail.fromMap(mangaData);

        AppRoutes.navigatorKey.currentState?.pushNamed(
          AppRoutes.detail,
          arguments: manga,
        );
      } catch (e) {
        debugPrint('Error handling deep link: $e');
      }
    }
  }

  Future<void> _checkAuthState() async {
    try {
      // Listen to auth state changes
      _authSubscription = _authService.authStateChanges.listen(
        (User? user) async {
          if (mounted) {
            if (user != null) {
              // User is signed in, check API configuration
              await _checkApiConfiguration();
            } else {
              // No user signed in, show login screen
              setState(() {
                _isCheckingAuth = false;
              });
            }
          }
        },
        onError: (error) {
          // In case of error, show login screen
          if (mounted) {
            setState(() {
              _isCheckingAuth = false;
            });
          }
        },
      );

      // Add a timeout to prevent getting stuck
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted && _isCheckingAuth) {
          setState(() {
            _isCheckingAuth = false;
          });
        }
      });
    } catch (e) {
      // In case of error, show login screen
      if (mounted) {
        setState(() {
          _isCheckingAuth = false;
        });
      }
    }
  }

  Future<void> _checkApiConfiguration() async {
    try {
      // Check if there are any API configurations
      final configs = await ApiConfigManager.loadApiConfigs();

      if (configs.isEmpty) {
        // No API configuration found, redirect to base API setting screen
        if (mounted) {
          Navigator.pushReplacementNamed(context, AppRoutes.baseApiSetting);
        }
      } else {
        // API configuration exists, redirect to home screen
        if (mounted) {
          Navigator.pushReplacementNamed(context, AppRoutes.home);
        }
      }
    } catch (e) {
      // In case of error checking API config, redirect to base API setting screen
      if (mounted) {
        Navigator.pushReplacementNamed(context, AppRoutes.baseApiSetting);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingAuth) {
      // Show a loading screen while checking auth state
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 20),
              Text(
                'Checking authentication...',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      );
    }

    // Return the login screen as the default route with Provider
    return Provider<AuthService>(
      create: (_) => _authService,
      child: const LoginScreen(),
    );
  }
}
