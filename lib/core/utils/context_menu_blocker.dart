import 'context_menu_blocker_stub.dart'
    if (dart.library.html) 'context_menu_blocker_web.dart';

/// Disables the native browser context menu when running on web.
/// No-ops on other platforms.
void disableBrowserContextMenu() => preventDefaultContextMenu();
