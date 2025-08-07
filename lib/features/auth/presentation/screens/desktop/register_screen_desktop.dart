import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../../../shared/widgets/custom_text_field.dart';
import '../../../../../shared/widgets/custom_button.dart';
import '../../../../../core/localization/app_localizations.dart';

class RegisterScreenDesktop extends StatelessWidget {
  final TextEditingController nameController;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final TextEditingController confirmPasswordController;
  final GlobalKey<FormState> formKey;
  final bool isLoading;
  final bool obscurePassword;
  final bool obscureConfirmPassword;
  final VoidCallback onPasswordVisibilityToggle;
  final VoidCallback onConfirmPasswordVisibilityToggle;
  final VoidCallback onRegister;

  const RegisterScreenDesktop({
    Key? key,
    required this.nameController,
    required this.emailController,
    required this.passwordController,
    required this.confirmPasswordController,
    required this.formKey,
    required this.isLoading,
    required this.obscurePassword,
    required this.obscureConfirmPassword,
    required this.onPasswordVisibilityToggle,
    required this.onConfirmPasswordVisibilityToggle,
    required this.onRegister,
  }) : super(key: key);

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
                    Text(
                      l10n?.createAccount ?? 'Create Account',
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n?.signUpToGetStarted ?? 'Sign up to get started',
                      style: const TextStyle(
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
                  key: formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      CustomTextField(
                        controller: nameController,
                        label: l10n?.fullName ?? 'Full Name',
                        hintText: l10n?.enterFullName ?? 'Enter your full name',
                        keyboardType: TextInputType.name,
                        prefixIcon: Icons.person_outline,
                        validator: (value) {
                          if (value?.isEmpty == true) {
                            return l10n?.nameRequired ?? 'Name is required';
                          }
                          if (value!.length < 2) {
                            return l10n?.nameTooShort ?? 'Name must be at least 2 characters';
                          }
                          return null;
                        },
                      ),
                      
                      const SizedBox(height: 20),
                      
                      CustomTextField(
                        controller: emailController,
                        label: l10n?.email ?? 'Email',
                        hintText: l10n?.enterEmail ?? 'Enter your email',
                        keyboardType: TextInputType.emailAddress,
                        prefixIcon: Icons.email_outlined,
                        validator: (value) {
                          if (value?.isEmpty == true) {
                            return l10n?.emailRequired ?? 'Email is required';
                          }
                          if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value!)) {
                            return l10n?.emailInvalid ?? 'Please enter a valid email';
                          }
                          return null;
                        },
                      ),
                      

                      
                      const SizedBox(height: 20),
                      
                      CustomTextField(
                        controller: passwordController,
                        label: l10n?.password ?? 'Password',
                        hintText: l10n?.enterPassword ?? 'Enter your password',
                        obscureText: obscurePassword,
                        prefixIcon: Icons.lock_outline,
                        suffixIcon: obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        onSuffixIconPressed: onPasswordVisibilityToggle,
                        validator: (value) {
                          if (value?.isEmpty == true) {
                            return l10n?.passwordRequired ?? 'Password is required';
                          }
                          if (value!.length < 6) {
                            return l10n?.passwordTooShort ?? 'Password must be at least 6 characters';
                          }
                          return null;
                        },
                      ),
                      
                      const SizedBox(height: 20),
                      
                      CustomTextField(
                        controller: confirmPasswordController,
                        label: l10n?.confirmPassword ?? 'Confirm Password',
                        hintText: l10n?.enterPasswordAgain ?? 'Enter your password again',
                        obscureText: obscureConfirmPassword,
                        prefixIcon: Icons.lock_outline,
                        suffixIcon: obscureConfirmPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        onSuffixIconPressed: onConfirmPasswordVisibilityToggle,
                        validator: (value) {
                          if (value?.isEmpty == true) {
                            return l10n?.confirmPasswordRequired ?? 'Please confirm your password';
                          }
                          if (value != passwordController.text) {
                            return l10n?.passwordsDoNotMatch ?? 'Passwords do not match';
                          }
                          return null;
                        },
                      ),
                      
                      const SizedBox(height: 32),
                      
                      // Register Button
                      CustomButton(
                        text: l10n?.createAccount ?? 'Create Account',
                        onPressed: isLoading ? null : onRegister,
                        showIcon: false,
                        height: 48,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      
                      if (isLoading) ...[
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
                    Text(
                      l10n?.alreadyHaveAccount ?? 'Already have an account? ',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    _HoverableText(
                      text: l10n?.signIn ?? 'Sign In',
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