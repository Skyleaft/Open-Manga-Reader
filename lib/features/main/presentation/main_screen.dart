import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/di/injection.dart';
import '../../../core/services/network_status_service.dart';
import '../../../core/widgets/alert_banner.dart';
import '../../../core/widgets/app_bottom_nav.dart';
import '../../discover/presentation/discover_screen.dart';
import '../../home/presentation/home_screen.dart';
import '../../library/presentation/library_screen.dart';
import '../../settings/presentation/more_screen.dart';
import '../../settings/services/update_service.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  late final PageController _pageController;
  String? _discoverSortBy;
  String? _discoverSearch;
  DateTime? _lastBackPressTime;
  StreamSubscription<bool>? _networkSubscription;

  @override
  void initState() {
    super.initState();
    final networkService = getIt.isRegistered<NetworkStatusService>()
        ? getIt<NetworkStatusService>()
        : null;

    final isOffline = networkService != null && !networkService.isOnline;
    _currentIndex = isOffline ? 1 : 0;
    _pageController = PageController(initialPage: _currentIndex);

    if (isOffline) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          AlertBanner.show(
            context,
            'No internet connection. Switched to offline mode.',
            type: AlertBannerType.warning,
          );
        }
      });
    }

    if (networkService != null) {
      _networkSubscription = networkService.onStatusChange.listen((isOnline) {
        if (!mounted) return;
        if (!isOnline) {
          AlertBanner.show(
            context,
            'No internet connection. Switched to offline mode.',
            type: AlertBannerType.warning,
          );
          _navigateTo(1);
        } else {
          AlertBanner.show(
            context,
            'Connection restored. Back online.',
            type: AlertBannerType.success,
          );
        }
      });
    }

    _checkForUpdate();
  }

  @override
  void dispose() {
    _networkSubscription?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _navigateToDiscover({String? sortBy, String? search}) {
    setState(() {
      _discoverSortBy = sortBy;
      _discoverSearch = search;
    });
    _navigateTo(2);
  }

  Future<void> _checkForUpdate() async {
    final updateService = UpdateService();
    final updateData = await updateService.checkForUpdate();

    if (updateData != null && mounted) {
      _showUpdateDialog(updateData);
    }
  }

  void _showUpdateDialog(Map<String, dynamic> updateData) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Update Available!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('A new version (${updateData['version']}) is available.'),
            const SizedBox(height: 8),
            Text(
              updateData['body'] ?? 'Performance improvements and bug fixes.',
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Later'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              final url = Uri.parse(updateData['url']);
              launchUrl(url, mode: LaunchMode.externalApplication);
            },
            child: const Text('Update Now'),
          ),
        ],
      ),
    );
  }

  void _navigateTo(int index) {
    final isOffline = getIt.isRegistered<NetworkStatusService>() &&
        !getIt<NetworkStatusService>().isOnline;

    if (isOffline && (index == 0 || index == 2)) {
      AlertBanner.show(
        context,
        'This screen is unavailable in offline mode. Showing your Library.',
        type: AlertBannerType.warning,
      );
      index = 1;
    }

    if (index != _currentIndex) {
      setState(() {
        _currentIndex = index;
      });

      if (_pageController.hasClients) {
        _pageController.animateToPage(
          index,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      HomeScreen(
        key: const ValueKey('home'),
        onNavigateToDiscover: _navigateToDiscover,
      ),
      const LibraryScreen(key: ValueKey('library')),
      DiscoverScreen(
        key: const ValueKey('discover'),
        initialSearch: _discoverSearch,
        sortBy: _discoverSortBy,
      ),
      const MoreScreen(key: ValueKey('more')),
    ];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;

        // If not on Home tab, switch to Home first
        if (_currentIndex != 0) {
          _navigateTo(0);
          return;
        }

        // Double back to exit handler
        final now = DateTime.now();
        if (_lastBackPressTime == null ||
            now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
          _lastBackPressTime = now;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Press back again to exit'),
              duration: Duration(seconds: 2),
            ),
          );
        } else {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        body: Stack(
          children: [
            PageView(
              controller: _pageController,
              physics: const BouncingScrollPhysics(),
              onPageChanged: (index) {
                if (_currentIndex != index) {
                  setState(() {
                    _currentIndex = index;
                  });
                }
              },
              children: screens,
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: AppBottomNav(
                currentIndex: _currentIndex,
                onTap: _navigateTo,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
