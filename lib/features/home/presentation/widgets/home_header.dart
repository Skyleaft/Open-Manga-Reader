import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image_ce/cached_network_image.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../auth/services/auth_service.dart';

class HomeHeader extends StatelessWidget {
  final bool isDark;
  final VoidCallback? onSearchTap;

  const HomeHeader({
    super.key,
    required this.isDark,
    this.onSearchTap,
  });

  @override
  Widget build(BuildContext context) {
    AuthService? authService;
    try {
      authService = context.watch<AuthService?>();
    } catch (_) {}

    final user = authService?.currentUser;
    final photoUrl = user?.photoURL;
    final displayName = user?.displayName;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (displayName != null && displayName.isNotEmpty)
                  Text(
                    'Hello, $displayName 👋',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                Text(
                  'Open Manga Reader',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                    color: isDark ? Colors.white : AppColors.secondary,
                  ),
                ),
              ],
            ),
          ),
          if (onSearchTap != null)
            IconButton(
              onPressed: onSearchTap,
              icon: Icon(
                Icons.search_rounded,
                color: isDark ? Colors.white70 : Colors.black54,
                size: 24,
              ),
            ),
          const SizedBox(width: 4),
          _buildAvatar(photoUrl, displayName),
        ],
      ),
    );
  }

  Widget _buildAvatar(String? photoUrl, String? displayName) {
    if (photoUrl != null && photoUrl.isNotEmpty) {
      return Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.35),
            width: 2,
          ),
        ),
        child: ClipOval(
          child: CachedNetworkImage(
            imageUrl: photoUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _buildInitialsAvatar(displayName),
          ),
        ),
      );
    }

    return _buildInitialsAvatar(displayName);
  }

  Widget _buildInitialsAvatar(String? displayName) {
    final initial = (displayName != null && displayName.isNotEmpty)
        ? displayName[0].toUpperCase()
        : null;

    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [AppColors.primary, const Color(0xFFFF8E53)],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.25),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: initial != null
            ? Text(
                initial,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              )
            : const Icon(
                Icons.person_rounded,
                color: Colors.white,
                size: 20,
              ),
      ),
    );
  }
}

