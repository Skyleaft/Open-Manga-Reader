import 'package:flutter/material.dart';
import '../home/home_screen.dart';
import '../library/library_screen.dart';
import '../discover/discover_screen.dart';
import '../more/more_screen.dart';
import '../../../core/widgets/app_bottom_nav.dart';
import '../../../data/services/update_service.dart';
import 'package:url_launcher/url_launcher.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with TickerProviderStateMixin {
  int _currentIndex = 0;
  int _previousIndex = 0;
  late AnimationController _animationController;
  Animation<Offset>? _slideAnimation;
  Animation<double>? _fadeAnimation;
  String? _discoverSortBy;
  String? _discoverSearch;

  void _navigateToDiscover({String? sortBy, String? search}) {
    setState(() {
      _discoverSortBy = sortBy;
      _discoverSearch = search;
    });
    _navigateTo(2);
  }

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _checkForUpdate();
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

  List<Widget> _buildScreens() {
    return [
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
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _navigateTo(int index) {
    if (index != _currentIndex) {
      final isMovingForward = index > _currentIndex;

      // Set up slide animation
      _slideAnimation =
          Tween<Offset>(
            begin: isMovingForward ? const Offset(1, 0) : const Offset(-1, 0),
            end: Offset.zero,
          ).animate(
            CurvedAnimation(
              parent: _animationController,
              curve: Curves.easeInOut,
            ),
          );

      // Set up fade animation for the new screen
      _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
      );

      _animationController.reset();
      _animationController.forward();

      setState(() {
        _previousIndex = _currentIndex;
        _currentIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 1024;

    return Scaffold(
      body: Stack(
        children: [
          // Previous screen (sliding out)
          if (_previousIndex != _currentIndex)
            SlideTransition(
              position:
                  Tween<Offset>(
                    begin: Offset.zero,
                    end: _currentIndex > _previousIndex
                        ? const Offset(-1, 0)
                        : const Offset(1, 0),
                  ).animate(
                    CurvedAnimation(
                      parent: _animationController,
                      curve: const Interval(0.0, 0.7, curve: Curves.easeInOut),
                    ),
                  ),
              child: FadeTransition(
                opacity: Tween<double>(begin: 1.0, end: 0.0).animate(
                  CurvedAnimation(
                    parent: _animationController,
                    curve: const Interval(0.0, 0.7, curve: Curves.easeInOut),
                  ),
                ),
                child: _buildScreens()[_previousIndex],
              ),
            ),

          // Current screen (sliding in)
          SlideTransition(
            position:
                _slideAnimation ??
                Tween<Offset>(
                  begin: Offset.zero,
                  end: Offset.zero,
                ).animate(_animationController),
            child: FadeTransition(
              opacity:
                  _fadeAnimation ??
                  Tween<double>(
                    begin: 1.0,
                    end: 1.0,
                  ).animate(_animationController),
              child: _buildScreens()[_currentIndex],
            ),
          ),

          // Bottom navigation
          if (isDesktop)
            // Desktop: Center the bottom nav
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Center(
                child: Container(
                  width: 600, // Fixed width for desktop
                  child: AppBottomNav(
                    currentIndex: _currentIndex,
                    onTap: _navigateTo,
                  ),
                ),
              ),
            )
          else
            // Mobile/Tablet: Full width
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
    );
  }
}
