import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../core/theme/app_theme.dart';
import '../../core/localization/app_localizations.dart';
import '../../features/clients/domain/entities/client.dart';
import '../../features/clients/domain/repositories/client_repository.dart';
import '../../features/clients/data/repositories/client_repository_impl.dart';
import '../../features/clients/data/datasources/client_remote_datasource.dart';
import '../../features/auth/presentation/widgets/auth_service_provider.dart';
import 'custom_button.dart';

class CreateEditClientDialog extends StatefulWidget {
  final Client? client; // null for create, client for edit
  final VoidCallback? onSuccess;
  final String? initialName; // Pre-fill name when creating from search

  const CreateEditClientDialog({
    super.key,
    this.client,
    this.onSuccess,
    this.initialName,
  });

  @override
  State<CreateEditClientDialog> createState() => _CreateEditClientDialogState();
}

class _CreateEditClientDialogState extends State<CreateEditClientDialog> {
  final _formKey = GlobalKey<FormState>();
  late ClientRepository _clientRepository;

  // Form controllers
  final _fullNameController = TextEditingController();
  final _contactNumberController = TextEditingController();
  final _passportNumberController = TextEditingController();
  final _addressController = TextEditingController();

  // Focus nodes for automatic navigation
  final _fullNameFocus = FocusNode();
  final _contactNumberFocus = FocusNode();
  final _passportNumberFocus = FocusNode();
  final _addressFocus = FocusNode();

  bool _isSaving = false;

  bool get _isEditing => widget.client != null;

  @override
  void initState() {
    super.initState();
    _initializeRepository();
    _initializeForm();
    
    // Auto-focus first field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fullNameFocus.requestFocus();
    });
  }

  void _initializeRepository() {
    _clientRepository = ClientRepositoryImpl(
      ClientRemoteDataSourceImpl(),
    );
  }

  void _initializeForm() {
    if (_isEditing) {
      final client = widget.client!;
      _fullNameController.text = client.fullName;
      _contactNumberController.text = client.contactNumber;
      _passportNumberController.text = client.passportNumber;
      _addressController.text = client.address ?? '';
    } else if (widget.initialName != null) {
      // Pre-fill name when creating from search
      _fullNameController.text = widget.initialName!;
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _contactNumberController.dispose();
    _passportNumberController.dispose();
    _addressController.dispose();
    _fullNameFocus.dispose();
    _contactNumberFocus.dispose();
    _passportNumberFocus.dispose();
    _addressFocus.dispose();
    super.dispose();
  }

  Future<void> _saveClient() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    
    try {
      final authService = AuthServiceProvider.of(context);
      final currentUser = await authService.getCurrentUser();
      
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }
      
      if (_isEditing) {
        final updatedClient = widget.client!.copyWith(
          fullName: _fullNameController.text,
          contactNumber: _contactNumberController.text,
          passportNumber: _passportNumberController.text,
          address: _addressController.text.trim().isEmpty ? null : _addressController.text,
          updatedAt: DateTime.now(),
        );
        
        await _clientRepository.updateClient(updatedClient);
        
        if (mounted) {
          Navigator.of(context).pop(); // Close dialog first
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)?.clientUpdatedSuccess ?? 'Client updated successfully'),
              backgroundColor: AppTheme.successColor,
            ),
          );
          
          widget.onSuccess?.call(); // Then call success callback
        }
      } else {
        final newClient = Client(
          id: const Uuid().v4(),
          userId: currentUser.id,
          fullName: _fullNameController.text,
          contactNumber: _contactNumberController.text,
          passportNumber: _passportNumberController.text,
          address: _addressController.text.trim().isEmpty ? null : _addressController.text,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        
        await _clientRepository.createClient(newClient);
        
        if (mounted) {
          Navigator.of(context).pop(); // Close dialog first
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)?.clientCreatedSuccess ?? 'Client created successfully'),
              backgroundColor: AppTheme.successColor,
            ),
          );
          
          widget.onSuccess?.call(); // Then call success callback
        }
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
    final l10n = AppLocalizations.of(context);

    return Dialog(
      backgroundColor: AppTheme.surfaceColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Text(
                    _isEditing 
                        ? (l10n?.editClient ?? 'Edit Client')
                        : (l10n?.addClient ?? 'Add Client'),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                    style: IconButton.styleFrom(
                      backgroundColor: AppTheme.subtleBackgroundColor,
                      foregroundColor: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              // Form Fields
              _buildTextField(
                controller: _fullNameController,
                focusNode: _fullNameFocus,
                nextFocusNode: _contactNumberFocus,
                label: l10n?.fullName ?? 'Full Name',
                validator: (value) => value?.isEmpty == true ? l10n?.enterFullName ?? 'Enter full name' : null,
              ),
              const SizedBox(height: 16),
              
              _buildTextField(
                controller: _contactNumberController,
                focusNode: _contactNumberFocus,
                nextFocusNode: _passportNumberFocus,
                label: l10n?.contactNumber ?? 'Contact Number',
                keyboardType: TextInputType.phone,
                validator: (value) => value?.isEmpty == true ? l10n?.enterContactNumber ?? 'Enter contact number' : null,
              ),
              const SizedBox(height: 16),
              
              _buildTextField(
                controller: _passportNumberController,
                focusNode: _passportNumberFocus,
                nextFocusNode: _addressFocus,
                label: l10n?.passportNumber ?? 'Passport Number',
                validator: (value) => value?.isEmpty == true ? l10n?.enterPassportNumber ?? 'Enter passport number' : null,
              ),
              const SizedBox(height: 16),
              
              _buildTextField(
                controller: _addressController,
                focusNode: _addressFocus,
                label: l10n?.address ?? 'Address (Optional)',
                isLast: true,
                onSubmit: _saveClient,
              ),
              const SizedBox(height: 24),
              
              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                    child: Text(
                      l10n?.cancel ?? 'Cancel',
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                  ),
                  const SizedBox(width: 12),
                  CustomButton(
                    text: l10n?.save ?? 'Save',
                    onPressed: _isSaving ? null : _saveClient,
                    showIcon: false,
                    width: 120,
                    height: 40,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required FocusNode focusNode,
    FocusNode? nextFocusNode,
    required String label,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    bool isLast = false,
    VoidCallback? onSubmit,
  }) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: keyboardType,
      textInputAction: isLast ? TextInputAction.done : TextInputAction.next,
      onFieldSubmitted: (_) {
        if (isLast) {
          onSubmit?.call();
        } else if (nextFocusNode != null) {
          nextFocusNode.requestFocus();
        }
      },
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: AppTheme.textSecondary,
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppTheme.borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppTheme.borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppTheme.errorColor),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
      validator: validator,
    );
  }
}