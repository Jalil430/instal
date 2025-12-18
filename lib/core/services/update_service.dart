import 'package:auto_updater/auto_updater.dart' as au;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

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

    if (kIsWeb) {
      // Auto-updater not available on web
      return;
    }

    // Only support macOS and Windows for now
    final isMac = defaultTargetPlatform == TargetPlatform.macOS;
    final isWindows = defaultTargetPlatform == TargetPlatform.windows;
    if (!isMac && !isWindows) {
      return;
    }

    final String feedUrl = isMac ? macOsFeedUrl : windowsFeedUrl;

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

