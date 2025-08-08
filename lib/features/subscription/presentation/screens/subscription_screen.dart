import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../features/auth/presentation/widgets/auth_service_provider.dart';
import '../../../../shared/widgets/responsive_layout.dart';
import '../../domain/entities/subscription_state.dart';
import '../providers/subscription_provider.dart';
import 'desktop/subscription_screen_desktop.dart';
import 'mobile/subscription_screen_mobile.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _codeController = TextEditingController();
  

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      body: SafeArea(
        child: Consumer<SubscriptionProvider>(
          builder: (context, provider, _) {
            if (provider.isLoading) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(strokeWidth: 3),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      l10n.subscriptionCheckingStatus,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              );
            }

            return ResponsiveLayout(
              mobile: SubscriptionScreenMobile(
                formKey: _formKey,
                codeController: _codeController,
                isValidatingCode: provider.isValidatingCode,
                error: provider.error,
                status: provider.userStatus,
                onValidate: () => _validateCode(provider),
              ),
              desktop: SubscriptionScreenDesktop(
                formKey: _formKey,
                codeController: _codeController,
                isValidatingCode: provider.isValidatingCode,
                error: provider.error,
                status: provider.userStatus,
                onValidate: () => _validateCode(provider),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _validateCode(SubscriptionProvider provider) async {
    if (!_formKey.currentState!.validate()) return;

    final authService = AuthServiceProvider.of(context);
    final user = await authService.getCurrentUser();
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.subscriptionUserNotFound),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    final success = await provider.validateCode(
      _codeController.text,
      user.id,
    );

    if (success && mounted) {
      _codeController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.subscriptionActivatedSuccess),
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
      );
    }
  }
}