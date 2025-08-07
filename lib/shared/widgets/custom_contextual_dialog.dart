import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_theme.dart';
import 'responsive_layout.dart';
import 'dialogs/desktop/custom_contextual_dialog_desktop.dart';
import 'dialogs/mobile/custom_contextual_dialog_mobile.dart';

class CustomContextualDialog {
  static Future<T?> show<T>({
    required BuildContext context,
    required Widget child,
    Offset? position,
    double width = 300.0,
    double estimatedHeight = 140.0,
    bool dismissible = true,
  }) async {
    final isDesktop = MediaQuery.of(context).size.width >= mobileBreakpoint;
    
    if (isDesktop) {
      // For desktop mode, we need a position - if not provided, use screen center
      final pos = position ?? Offset(
        MediaQuery.of(context).size.width / 2,
        MediaQuery.of(context).size.height / 2,
      );
      
      return await CustomContextualDialogDesktop.show<T>(
        context: context,
        position: pos,
        child: child,
        width: width,
        estimatedHeight: estimatedHeight,
        dismissible: dismissible,
      );
    } else {
      // For mobile mode, position is ignored - we show a bottom sheet
      return await CustomContextualDialogMobile.show<T>(
        context: context,
        child: child,
        width: double.infinity, // Full width for mobile
        dismissible: dismissible,
      );
    }
  }
}

/// Base class for contextual dialog content
abstract class ContextualDialogContent extends StatelessWidget {
  const ContextualDialogContent({super.key});

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= mobileBreakpoint;
    
    if (isDesktop) {
      return _buildDesktopContent(context);
    } else {
      return _buildMobileContent(context);
    }
  }
  
  // Build desktop version
  Widget _buildDesktopContent(BuildContext context) {
    return RawKeyboardListener(
      autofocus: true,
      focusNode: FocusNode(),
      onKey: (RawKeyEvent event) {
        if (event is RawKeyDownEvent) {
          _onKeyDown(event, context);
        }
      },
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: buildContent(context),
      ),
    );
  }
  
  // Build mobile version
  Widget _buildMobileContent(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: buildContent(context),
    );
  }
  
  // Handle keyboard events
  void _onKeyDown(RawKeyDownEvent event, BuildContext context) {
    // Add standard keyboard navigation
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      Navigator.of(context).pop();
    }
  }

  /// Override this to build the dialog content
  Widget buildContent(BuildContext context);
} 