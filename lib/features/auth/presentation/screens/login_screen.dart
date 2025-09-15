import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/custom_text_field.dart';
import '../../../../shared/widgets/custom_button.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../shared/widgets/responsive_layout.dart';
import '../../../../core/api/api_client.dart';
import '../widgets/auth_service_provider.dart';
import 'desktop/login_screen_desktop.dart';
import 'mobile/login_screen_mobile.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _togglePasswordVisibility() {
    setState(() => _obscurePassword = !_obscurePassword);
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final authService = AuthServiceProvider.of(context);
      await authService.login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (mounted) {
        context.go('/clients');
      }
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        final message = _friendlyErrorMessage(e, l10n);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _friendlyErrorMessage(Object e, AppLocalizations? l10n) {
    if (e is RequestTimeoutException) {
      return l10n?.noInternetConnection ?? 'No internet connection. Please check your network and try again.';
    }
    if (e is ApiException) {
      final lower = e.message.toLowerCase();
      if (lower.contains('socketexception') || lower.contains('failed host lookup') || lower.contains('network error')) {
        return l10n?.noInternetConnection ?? 'No internet connection. Please check your network and try again.';
      }
    }
    final base = l10n?.loginFailed ?? 'Login failed';
    return '$base: $e';
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayout(
      mobile: LoginScreenMobile(
        emailController: _emailController,
        passwordController: _passwordController,
        formKey: _formKey,
        isLoading: _isLoading,
        obscurePassword: _obscurePassword,
        onPasswordVisibilityToggle: _togglePasswordVisibility,
        onLogin: _login,
      ),
      desktop: LoginScreenDesktop(
        emailController: _emailController,
        passwordController: _passwordController,
        formKey: _formKey,
        isLoading: _isLoading,
        obscurePassword: _obscurePassword,
        onPasswordVisibilityToggle: _togglePasswordVisibility,
        onLogin: _login,
      ),
    );
  }
} 
