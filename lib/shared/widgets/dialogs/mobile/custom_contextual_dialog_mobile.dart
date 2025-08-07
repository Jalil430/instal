import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class CustomContextualDialogMobile {
  static Future<T?> show<T>({
    required BuildContext context,
    required Widget child,
    double width = double.infinity,
    bool dismissible = true,
  }) async {
    // On mobile, we show a bottom sheet instead of a positioned dialog
    return await showModalBottomSheet<T>(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: dismissible,
      enableDrag: true,
      isScrollControlled: true,
      builder: (context) => _ContextualDialogMobileWrapper<T>(
        dismissible: dismissible,
        child: child,
        width: width,
      ),
    );
  }
}

class _ContextualDialogMobileWrapper<T> extends StatelessWidget {
  final bool dismissible;
  final Widget child;
  final double width;

  const _ContextualDialogMobileWrapper({
    required this.dismissible,
    required this.child,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              margin: const EdgeInsets.only(top: 8, bottom: 4),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.subtleBorderColor,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            child,
            // Add extra padding at the bottom for safe area
            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );
  }
}

/// Base class for contextual dialog content - mobile version
abstract class ContextualDialogMobileContent extends StatelessWidget {
  const ContextualDialogMobileContent({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: buildContent(context),
    );
  }

  /// Override this to build the dialog content
  Widget buildContent(BuildContext context);
} 