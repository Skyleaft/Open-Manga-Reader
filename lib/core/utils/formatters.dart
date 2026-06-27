/// Global function to format view counts in a readable format
/// - 1000+ views: "X.Xk" format (e.g., "72.3k")
/// - 1000000+ views: "X.XXm" format (e.g., "1.23m")
/// - Less than 1000: original number as string
String formatViewCount(int viewCount) {
  if (viewCount >= 1000000) {
    return '${(viewCount / 1000000).toStringAsFixed(1)}M';
  } else if (viewCount >= 1000) {
    return '${(viewCount / 1000).toStringAsFixed(1)}K';
  } else {
    return viewCount.toString();
  }
}

String timeAgo(DateTime date) {
  final now = DateTime.now();
  final difference = now.difference(date);

  if (difference.inSeconds < 60) {
    return '${difference.inSeconds}s';
  } else if (difference.inMinutes < 60) {
    return '${difference.inMinutes}m';
  } else if (difference.inHours < 24) {
    return '${difference.inHours}h';
  } else if (difference.inDays < 7) {
    return '${difference.inDays}d';
  } else if (difference.inDays < 30) {
    return '${(difference.inDays / 7).floor()}w';
  } else if (difference.inDays < 365) {
    return '${(difference.inDays / 30).floor()}mo';
  } else {
    return '${(difference.inDays / 365).floor()}y';
  }
}
