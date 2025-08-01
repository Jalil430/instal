import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/custom_text_field.dart';
import '../../../../shared/widgets/custom_button.dart';
import '../../../../core/localization/app_localizations.dart';
import '../widgets/auth_service_provider.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Passwords do not match'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final authService = AuthServiceProvider.of(context);
      final authState = await authService.register(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        fullName: _nameController.text.trim(),
      );

      if (mounted) {
        context.go('/clients');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Registration failed: $e'),
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: AppTheme.surfaceColor,
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            margin: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // App Logo and Title
                Column(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.account_balance_wallet_rounded,
                        color: Colors.white,
                        size: 40,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Create Account',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Sign up to get started',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 40),
                
                // Registration Form
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      CustomTextField(
                        controller: _nameController,
                        label: l10n?.fullName ?? 'Full Name',
                        hintText: 'Enter your full name',
                        keyboardType: TextInputType.name,
                        prefixIcon: Icons.person_outline,
                        validator: (value) {
                          if (value?.isEmpty == true) {
                            return 'Name is required';
                          }
                          if (value!.length < 2) {
                            return 'Name must be at least 2 characters';
                          }
                          return null;
                        },
                      ),
                      
                      const SizedBox(height: 20),
                      
                      CustomTextField(
                        controller: _emailController,
                        label: 'Email',
                        hintText: 'Enter your email',
                        keyboardType: TextInputType.emailAddress,
                        prefixIcon: Icons.email_outlined,
                        validator: (value) {
                          if (value?.isEmpty == true) {
                            return 'Email is required';
                          }
                          if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value!)) {
                            return 'Please enter a valid email';
                          }
                          return null;
                        },
                      ),
                      
                      const SizedBox(height: 20),
                      
                      CustomTextField(
                        controller: _passwordController,
                        label: 'Password',
                        hintText: 'Enter your password',
                        obscureText: _obscurePassword,
                        prefixIcon: Icons.lock_outline,
                        suffixIcon: _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        onSuffixIconPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                        validator: (value) {
                          if (value?.isEmpty == true) {
                            return 'Password is required';
                          }
                          if (value!.length < 6) {
                            return 'Password must be at least 6 characters';
                          }
                          return null;
                        },
                      ),
                      
                      const SizedBox(height: 20),
                      
                      CustomTextField(
                        controller: _confirmPasswordController,
                        label: 'Confirm Password',
                        hintText: 'Enter your password again',
                        obscureText: _obscureConfirmPassword,
                        prefixIcon: Icons.lock_outline,
                        suffixIcon: _obscureConfirmPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        onSuffixIconPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                        validator: (value) {
                          if (value?.isEmpty == true) {
                            return 'Please confirm your password';
                          }
                          if (value != _passwordController.text) {
                            return 'Passwords do not match';
                          }
                          return null;
                        },
                      ),
                      
                      const SizedBox(height: 32),
                      
                      // Register Button
                      CustomButton(
                        text: 'Create Account',
                        onPressed: _isLoading ? null : _register,
                        showIcon: false,
                        height: 48,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      
                      if (_isLoading) ...[
                        const SizedBox(height: 16),
                        Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // Sign In Link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'Already have an account? ',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    _HoverableText(
                      text: 'Sign In',
                      onTap: () => context.go('/auth/login'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HoverableText extends StatefulWidget {
  final String text;
  final VoidCallback onTap;

  const _HoverableText({
    required this.text,
    required this.onTap,
  });

  @override
  State<_HoverableText> createState() => _HoverableTextState();
}

class _HoverableTextState extends State<_HoverableText> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: _isHovered ? AppTheme.primaryColor : Colors.transparent,
                width: 1,
              ),
            ),
          ),
          child: Text(
            widget.text,
            style: const TextStyle(
              fontSize: 14,
              color: AppTheme.primaryColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
} 