import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../../core/localization/app_localizations.dart';
import '../../../domain/entities/subscription_state.dart';
// Minimal, text-first layout
import '../../../../../shared/widgets/custom_text_field.dart';
import '../../../../../shared/widgets/custom_button.dart';
import '../../../../../features/auth/presentation/widgets/auth_service_provider.dart';

class SubscriptionScreenMobile extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController codeController;
  final bool isValidatingCode;
  final String? error;
  final UserSubscriptionStatus status;
  final VoidCallback onValidate;

  const SubscriptionScreenMobile({
    super.key,
    required this.formKey,
    required this.codeController,
    required this.isValidatingCode,
    required this.error,
    required this.status,
    required this.onValidate,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    const String telegramHandle = '@jalil_katalov';

    // Map provider error keys to localized strings
    String? fieldErrorText;
    String? bannerErrorText;
    if (error != null) {
      switch (error) {
        case 'subscriptionCodeRequired':
          fieldErrorText = l10n.subscriptionCodeRequired;
          break;
        case 'subscriptionErrorInvalidCode':
          fieldErrorText = l10n.subscriptionErrorInvalidCode;
          break;
        case 'subscriptionErrorCodeUsed':
          fieldErrorText = l10n.subscriptionErrorCodeUsed;
          break;
        case 'subscriptionErrorCodeExpired':
          fieldErrorText = l10n.subscriptionErrorCodeExpired;
          break;
        case 'subscriptionErrorNetwork':
          bannerErrorText = l10n.subscriptionErrorNetwork;
          break;
        case 'subscriptionErrorUnexpected':
          bannerErrorText = l10n.subscriptionErrorUnexpected;
          break;
        case 'subscriptionErrorCheckFailed':
          bannerErrorText = l10n.subscriptionErrorCheckFailed;
          break;
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top-left logout handled by parent overlay button
          // Title & intro
          Text(
            l10n.subscriptionWelcomeTitle,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.subscriptionWelcomeMessage,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withOpacity(0.65),
                  height: 1.6,
                ),
          ),
          const SizedBox(height: 12),
          // Free-trial note (match desktop tint)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.18),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.subscriptionFreeTrialTitle,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.subscriptionFreeTrialMessage,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Contact info (match desktop)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.25),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.subscriptionContactTitle,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.subscriptionContactMessage(telegramHandle),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton(
                    onPressed: () {
                      Clipboard.setData(const ClipboardData(text: telegramHandle));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(l10n.subscriptionTelegramCopied(telegramHandle)),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                    child: Text(
                      l10n.subscriptionContactButton(telegramHandle),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Divider(
            height: 24,
            thickness: 0.6,
            color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
          ),
          const SizedBox(height: 6),
          Form(
            key: formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.subscriptionCodeInputTitle,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.subscriptionCodeInputMessage,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.7),
                      ),
                ),
                const SizedBox(height: 12),
                CustomTextField(
                  controller: codeController,
                  label: l10n.subscriptionCodeLabel,
                  hintText: l10n.subscriptionCodeHint,
                  prefixIcon: Icons.vpn_key,
                  enabled: !isValidatingCode,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return l10n.subscriptionCodeRequired;
                    }
                    return null;
                  },
                ),
                if (fieldErrorText != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    fieldErrorText!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.error,
                        ),
                  ),
                ],
                const SizedBox(height: 16),
                CustomButton(
                  text: isValidatingCode
                      ? l10n.subscriptionValidating
                      : l10n.subscriptionActivateButton,
                  onPressed: isValidatingCode ? null : onValidate,
                  showIcon: false,
                  height: 52,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
                if (isValidatingCode) ...[
                  const SizedBox(height: 10),
                  const Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ],
                if (bannerErrorText != null) ...[
                  const SizedBox(height: 12),
                  _ErrorBanner(error: bannerErrorText!),
                ],
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: CustomButton(
                    text: l10n.logout,
                    onPressed: () async {
                      final auth = AuthServiceProvider.of(context);
                      await auth.logout();
                    },
                    icon: Icons.logout,
                    showIcon: true,
                    height: 36,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    color: Theme.of(context).colorScheme.error,
                    textColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String error;
  const _ErrorBanner({required this.error});

  @override
  Widget build(BuildContext context) {
    String resolved = error;
    final l10n = AppLocalizations.of(context);
    if (l10n != null) {
      switch (error) {
        case 'subscriptionCodeRequired':
          resolved = l10n.subscriptionCodeRequired;
          break;
        case 'subscriptionErrorInvalidCode':
          resolved = l10n.subscriptionErrorInvalidCode;
          break;
        case 'subscriptionErrorCodeUsed':
          resolved = l10n.subscriptionErrorCodeUsed;
          break;
        case 'subscriptionErrorCodeExpired':
          resolved = l10n.subscriptionErrorCodeExpired;
          break;
        case 'subscriptionErrorNetwork':
          resolved = l10n.subscriptionErrorNetwork;
          break;
        case 'subscriptionErrorUnexpected':
          resolved = l10n.subscriptionErrorUnexpected;
          break;
        case 'subscriptionErrorCheckFailed':
          resolved = l10n.subscriptionErrorCheckFailed;
          break;
      }
    }
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).colorScheme.error.withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              resolved,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}


