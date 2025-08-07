import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_theme.dart';

class CustomContextualDialogDesktop {
  static Future<T?> show<T>({
    required BuildContext context,
    required Offset position,
    required Widget child,
    double width = 300.0,
    double estimatedHeight = 140.0,
    bool dismissible = true,
  }) async {
    return await showDialog<T>(
      context: context,
      barrierColor: Colors.transparent,
      barrierDismissible: dismissible,
      builder: (context) => _ContextualDialogDesktopWrapper<T>(
        position: position,
        width: width,
        estimatedHeight: estimatedHeight,
        dismissible: dismissible,
        child: child,
      ),
    );
  }
}

class _ContextualDialogDesktopWrapper<T> extends StatelessWidget {
  final Offset position;
  final double width;
  final double estimatedHeight;
  final bool dismissible;
  final Widget child;

  const _ContextualDialogDesktopWrapper({
    required this.position,
    required this.width,
    required this.estimatedHeight,
    required this.dismissible,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    // Get screen bounds
    final screenSize = MediaQuery.of(context).size;
    
    // Calculate adjusted position to keep dialog in bounds
    double left = position.dx - (width / 2);
    double top = position.dy + 10;
    
    // Adjust horizontal position
    if (left < 16) {
      left = 16; // Keep margin from left edge
    } else if (left + width > screenSize.width - 16) {
      left = screenSize.width - width - 16; // Keep margin from right edge
    }
    
    // Adjust vertical position
    if (top + estimatedHeight > screenSize.height - 16) {
      top = position.dy - estimatedHeight - 10; // Show above cursor
    }
    
    // Ensure top doesn't go negative
    if (top < 16) {
      top = 16;
    }

    return Stack(
      children: [
        // Invisible barrier to close dialog
        if (dismissible)
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(color: Colors.transparent),
            ),
          ),
        // Dialog content
        Positioned(
          left: left,
          top: top,
          child: Material(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: width,
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppTheme.subtleBorderColor,
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: child,
            ),
          ),
        ),
      ],
    );
  }
}

/// Base class for contextual dialog content - desktop version
abstract class ContextualDialogDesktopContent extends StatelessWidget {
  const ContextualDialogDesktopContent({super.key});

  /// Override this to provide custom keyboard handling
  Widget buildFocusWrapper({required Widget child}) {
    return RawKeyboardListener(
      autofocus: true,
      focusNode: FocusNode(),
      onKey: (RawKeyEvent event) {
        if (event is RawKeyDownEvent) {
          onKeyDown(event);
        }
      },
      child: child,
    );
  }

  /// Override this to handle keyboard events
  void onKeyDown(RawKeyDownEvent event) {
    // Default implementation does nothing
  }

  @override
  Widget build(BuildContext context) {
    return buildFocusWrapper(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: buildContent(context),
      ),
    );
  }

  /// Override this to build the dialog content
  Widget buildContent(BuildContext context);
} 