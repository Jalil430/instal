import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../../core/api/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/localization/app_localizations.dart';
import '../domain/entities/client.dart';
import '../domain/repositories/client_repository.dart';
import '../data/repositories/client_repository_impl.dart';
import '../data/datasources/client_remote_datasource.dart';
import '../../../shared/widgets/custom_icon_button.dart';
import '../../../shared/widgets/custom_button.dart';
import '../../auth/presentation/widgets/auth_service_provider.dart';


class AddEditClientScreen extends StatefulWidget {
  final String? clientId; // null for add, id for edit

  const AddEditClientScreen({
    super.key,
    this.clientId,
  });

  @override
  State<AddEditClientScreen> createState() => _AddEditClientScreenState();
}

class _AddEditClientScreenState extends State<AddEditClientScreen> {
  final _formKey = GlobalKey<FormState>();
  late ClientRepository _clientRepository;

  // Form controllers
  final _fullNameController = TextEditingController();
  final _contactNumberController = TextEditingController();
  final _passportNumberController = TextEditingController();
  final _addressController = TextEditingController();

  bool _isLoading = false;
  bool _isSaving = false;
  Client? _existingClient;
  bool _isInitialized = false;

  bool get _isEditing => widget.clientId != null;

  @override
  void initState() {
    super.initState();
    _initializeRepository();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      if (_isEditing) {
        _loadClient();
      }
      _isInitialized = true;
    }
  }

  void _initializeRepository() {
    _clientRepository = ClientRepositoryImpl(
      ClientRemoteDataSourceImpl(),
    );
  }

  Future<void> _loadClient() async {
    setState(() => _isLoading = true);
    try {
      final client = await _clientRepository.getClientById(widget.clientId!);
      if (client != null) {
        setState(() {
          _existingClient = client;
          _fullNameController.text = client.fullName;
          _contactNumberController.text = client.contactNumber;
          _passportNumberController.text = client.passportNumber;
          _addressController.text = client.address ?? '';
          _isLoading = false;
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context)?.clientNotFound ?? 'Клиент не найден')),
          );
          context.go('/clients');
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppLocalizations.of(context)?.errorLoading ?? 'Ошибка загрузки'}: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _contactNumberController.dispose();
    _passportNumberController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _saveClient() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    
    try {
      // Get current user from authentication
      final authService = AuthServiceProvider.of(context);
      final currentUser = await authService.getCurrentUser();
      
      if (currentUser == null) {
        // Redirect to login if not authenticated
        if (mounted) {
          context.go('/auth/login');
        }
        return;
      }
      
      if (_isEditing && _existingClient != null) {
        // Update existing client
        final updatedClient = _existingClient!.copyWith(
          fullName: _fullNameController.text,
          contactNumber: _contactNumberController.text,
          passportNumber: _passportNumberController.text,
          address: _addressController.text.trim().isEmpty ? null : _addressController.text,
          updatedAt: DateTime.now(),
        );
        
        await _clientRepository.updateClient(updatedClient);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context)?.clientUpdatedSuccess ?? 'Клиент успешно обновлен')),
          );
          context.go('/clients');
        }
      } else {
        // Create new client
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context)?.clientCreatedSuccess ?? 'Клиент успешно создан')),
          );
          context.go('/clients');
        }
      }
    } catch (e) {
      if (!mounted) return;
      
      if (e is UnauthorizedException) {
        final authService = AuthServiceProvider.of(context);
        await authService.logout();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)?.sessionExpired ?? 'Ваша сессия истекла. Пожалуйста, войдите снова.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppLocalizations.of(context)?.errorSaving ?? 'Ошибка сохранения'}: $e')),
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

    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppTheme.surfaceColor,
        body: Center(
          child: CircularProgressIndicator(
            strokeWidth: 3,
            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.brightPrimaryColor),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.surfaceColor,
      body: Column(
        children: [
          // Clean Header
          Container(
            padding: const EdgeInsets.fromLTRB(32, 28, 32, 20),
            color: AppTheme.surfaceColor,
            child: Row(
              children: [
                CustomIconButton(
                  routePath: '/clients',
                ),
                const SizedBox(width: 16),
                Text(
                  _isEditing 
                      ? (l10n?.editClient ?? 'Редактировать клиента')
                      : (l10n?.addClient ?? 'Добавить клиента'),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.5,
                  ),
                ),
                const Spacer(),
                if (_isSaving) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation<Color>(AppTheme.brightPrimaryColor),
                    ),
                  ),
                  const SizedBox(width: 16),
                ],
                CustomButton(
                  text: l10n?.save ?? 'Сохранить',
                  onPressed: _isSaving ? null : () => _saveClient(),
                  showIcon: false,
                  height: 40,
                  width: 120,
                ),
              ],
            ),
          ),
          // Simple Clean Form
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
              child: Form(
                key: _formKey,
                child: Container(
                  color: AppTheme.surfaceColor,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Section Header
                      Text(
                        AppLocalizations.of(context)?.personalInformation ?? 'Личная информация',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 14),
                      
                      // Full Name
                      _buildTextField(
                        controller: _fullNameController,
                        label: AppLocalizations.of(context)?.fullName ?? 'Полное имя',
                        validator: (value) => value?.isEmpty == true ? AppLocalizations.of(context)?.enterFullName ?? 'Введите полное имя' : null,
                      ),
                      const SizedBox(height: 20),
                      
                      // Contact Number
                      _buildTextField(
                        controller: _contactNumberController,
                        label: AppLocalizations.of(context)?.contactNumber ?? 'Контактный номер',
                        keyboardType: TextInputType.phone,
                        validator: (value) => value?.isEmpty == true ? AppLocalizations.of(context)?.enterContactNumber ?? 'Введите контактный номер' : null,
                      ),
                      const SizedBox(height: 26),
                      
                      // Section Header
                      Text(
                        AppLocalizations.of(context)?.documentsAndAddress ?? 'Документы и адрес',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 14),
                      
                      // Passport Number
                      _buildTextField(
                        controller: _passportNumberController,
                        label: AppLocalizations.of(context)?.passportNumber ?? 'Номер паспорта',
                        validator: (value) => value?.isEmpty == true ? AppLocalizations.of(context)?.enterPassportNumber ?? 'Введите номер паспорта' : null,
                      ),
                      const SizedBox(height: 20),
                      
                      // Address
                      _buildTextField(
                        controller: _addressController,
                        label: AppLocalizations.of(context)?.address ?? 'Адрес (необязательно)',
                        maxLines: 3,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    IconData? icon,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: AppTheme.textPrimary,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: AppTheme.textSecondary,
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
        prefixIcon: icon != null ? Icon(icon, color: AppTheme.textSecondary) : null,
        filled: true,
        fillColor: Colors.white,
        hoverColor: Color.lerp(AppTheme.surfaceColor, AppTheme.backgroundColor, 0.6),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
          borderSide: BorderSide(color: AppTheme.borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
          borderSide: BorderSide(color: AppTheme.borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
          borderSide: BorderSide(color: AppTheme.primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
          borderSide: BorderSide(color: AppTheme.errorColor),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      validator: validator,
    );
  }
} 