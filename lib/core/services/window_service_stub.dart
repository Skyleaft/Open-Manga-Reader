class WindowService {
  static bool get isDesktop => false;

  Future<void> init() async {}

  Future<void> saveWindowState() async {}

  Future<bool> isFullScreen() async => false;

  Future<void> setFullScreen(bool isFullScreen) async {}
}
