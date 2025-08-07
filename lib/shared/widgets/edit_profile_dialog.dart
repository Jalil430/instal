import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/localization/app_localizations.dart';
import '../../features/auth/domain/entities/user.dart';
import '../../features/auth/presentation/widgets/auth_service_provider.dart';
import 'custom_button.dart';
import '../widgets/responsive_layout.dart';
import 'dialogs/desktop/edit_profile_dialog_desktop.dart';
import 'dialogs/mobile/edit_profile_dialog_mobile.dart';

class EditProfileDialog extends StatefulWidget {
  final User user;
  final VoidCallback? onSuccess;

  const EditProfileDialog({
    super.key,
    required this.user,
    this.onSuccess,
  });

  @override
  State<EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<EditProfileDialog> {
  final _formKey = GlobalKey<FormState>();

  // Form controllers
  final _fullNameController = TextEditingController();

  // Focus nodes for automatic navigation
  final _fullNameFocus = FocusNode();

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _initializeForm();
    
    // Auto-focus first field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fullNameFocus.requestFocus();
    });
  }

  void _initializeForm() {
    _fullNameController.text = widget.user.fullName;
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _fullNameFocus.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    
    try {
      final authService = AuthServiceProvider.of(context);
      
      await authService.updateUser(
        userId: widget.user.id,
        fullName: _fullNameController.text,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)?.profileUpdated ?? 'Profile updated successfully'),
            backgroundColor: AppTheme.successColor,
          ),
        );
        Navigator.of(context).pop();
        widget.onSuccess?.call();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${AppLocalizations.of(context)?.errorSaving ?? 'Error saving'}: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayout(
      mobile: EditProfileDialogMobile(
        user: widget.user,
        fullNameController: _fullNameController,
        fullNameFocus: _fullNameFocus,
        formKey: _formKey,
        isSaving: _isSaving,
        onSave: _saveProfile,
        onCancel: () => Navigator.of(context).pop(),
      ),
      desktop: EditProfileDialogDesktop(
        user: widget.user,
        fullNameController: _fullNameController,
        fullNameFocus: _fullNameFocus,
        formKey: _formKey,
        isSaving: _isSaving,
        onSave: _saveProfile,
        onCancel: () => Navigator.of(context).pop(),
      ),
    );
  }
}