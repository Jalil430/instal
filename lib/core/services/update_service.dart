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

    // Avoid auto-downloading without user confirmation
    try {
      await au.autoUpdater.setAutoDownload(false);
    } catch (_) {
      // No-op if not supported on a platform version
    }

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

  /// Trigger a silent/background update check.
  /// Shows UI only if an update is available.
  static Future<void> checkForUpdatesInBackground() async {
    if (!_initialized) return;
    try {
      await au.autoUpdater.checkForUpdatesInBackground();
    } catch (_) {
      // Fallback: do nothing if background check isn't supported
    }
  }
}


