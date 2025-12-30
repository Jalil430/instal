// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:html' as html;

bool _contextMenuBlocked = false;

/// Prevents the default browser context menu so only the custom dialog shows.
void preventDefaultContextMenu() {
  if (_contextMenuBlocked) return;
  _contextMenuBlocked = true;

  html.document.onContextMenu.listen((event) => event.preventDefault());
}
