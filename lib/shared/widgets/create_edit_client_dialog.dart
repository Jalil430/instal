import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../core/theme/app_theme.dart';
import '../../core/localization/app_localizations.dart';
import '../../features/clients/domain/entities/client.dart';
import '../../features/clients/domain/repositories/client_repository.dart';
import '../../features/clients/data/repositories/client_repository_impl.dart';
import '../../features/clients/data/datasources/client_remote_datasource.dart';
import '../../features/auth/presentation/widgets/auth_service_provider.dart';
import '../widgets/responsive_layout.dart';
import 'dialogs/desktop/create_edit_client_dialog_desktop.dart';
import 'dialogs/mobile/create_edit_client_dialog_mobile.dart';
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
    return ResponsiveLayout(
      mobile: CreateEditClientDialogMobile(
        formKey: _formKey,
        fullNameController: _fullNameController,
        contactNumberController: _contactNumberController,
        passportNumberController: _passportNumberController,
        addressController: _addressController,
        fullNameFocus: _fullNameFocus,
        contactNumberFocus: _contactNumberFocus,
        passportNumberFocus: _passportNumberFocus,
        addressFocus: _addressFocus,
        isSaving: _isSaving,
        isEditing: _isEditing,
        onSave: _saveClient,
      ),
      desktop: CreateEditClientDialogDesktop(
        formKey: _formKey,
        fullNameController: _fullNameController,
        contactNumberController: _contactNumberController,
        passportNumberController: _passportNumberController,
        addressController: _addressController,
        fullNameFocus: _fullNameFocus,
        contactNumberFocus: _contactNumberFocus,
        passportNumberFocus: _passportNumberFocus,
        addressFocus: _addressFocus,
        isSaving: _isSaving,
        isEditing: _isEditing,
        onSave: _saveClient,
      ),
    );
  }
}