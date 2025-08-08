import 'dart:io' show Platform;

import 'package:auto_updater/auto_updater.dart' as au;

class UpdateService {
  static bool _initialized = false;

  /// Configure the update feed URL based on platform.
  /// Provide your hosted appcast URLs.
  static Future<void> initialize({
    required String macOsFeedUrl,
    required String windowsFeedUrl,
    Duration? scheduledCheckInterval,
  }) async {
    if (_initialized) return;

    // Only support macOS and Windows for now
    if (!Platform.isMacOS && !Platform.isWindows) {
      return;
    }

    final String feedUrl = Platform.isMacOS ? macOsFeedUrl : windowsFeedUrl;

    if (feedUrl.isEmpty) return;

    await au.autoUpdater.setFeedURL(feedUrl);

    if (scheduledCheckInterval != null) {
      await au.autoUpdater.setScheduledCheckInterval(
        scheduledCheckInterval.inSeconds,
      );
    }

    _initialized = true;
  }

  /// Trigger an immediate update check.
  static Future<void> checkForUpdates() async {
    if (!_initialized) return;
    await au.autoUpdater.checkForUpdates();
  }
}


