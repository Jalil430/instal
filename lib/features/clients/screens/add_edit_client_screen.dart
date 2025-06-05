import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/localization/app_localizations.dart';
import '../domain/entities/client.dart';
import '../domain/repositories/client_repository.dart';
import '../data/repositories/client_repository_impl.dart';
import '../data/datasources/client_local_datasource.dart';
import '../../../shared/database/database_helper.dart';

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

  bool get _isEditing => widget.clientId != null;

  @override
  void initState() {
    super.initState();
    _initializeRepository();
    if (_isEditing) {
      _loadClient();
    }
  }

  void _initializeRepository() {
    final db = DatabaseHelper.instance;
    _clientRepository = ClientRepositoryImpl(
      ClientLocalDataSourceImpl(db),
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
          _addressController.text = client.address;
          _isLoading = false;
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Клиент не найден')),
          );
          context.go('/clients');
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки: $e')),
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
      const userId = 'user123'; // TODO: Replace with actual user ID
      
      if (_isEditing && _existingClient != null) {
        // Update existing client
        final updatedClient = _existingClient!.copyWith(
          fullName: _fullNameController.text,
          contactNumber: _contactNumberController.text,
          passportNumber: _passportNumberController.text,
          address: _addressController.text,
          updatedAt: DateTime.now(),
        );
        
        await _clientRepository.updateClient(updatedClient);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Клиент успешно обновлен')),
          );
          context.go('/clients');
        }
      } else {
        // Create new client
        final newClient = Client(
          id: const Uuid().v4(),
          userId: userId,
          fullName: _fullNameController.text,
          contactNumber: _contactNumberController.text,
          passportNumber: _passportNumberController.text,
          address: _addressController.text,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        
        await _clientRepository.createClient(newClient);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Клиент успешно создан')),
          );
          context.go('/clients');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка сохранения: $e')),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: AppTheme.surfaceColor,
              border: Border(
                bottom: BorderSide(
                  color: AppTheme.borderColor,
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => context.go('/clients'),
                  icon: const Icon(Icons.arrow_back),
                ),
                const SizedBox(width: 16),
                Text(
                  _isEditing 
                      ? (l10n?.editClient ?? 'Редактировать клиента')
                      : (l10n?.addClient ?? 'Добавить клиента'),
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const Spacer(),
                if (_isSaving) ...[
                  const CircularProgressIndicator(),
                  const SizedBox(width: 16),
                ],
                ElevatedButton(
                  onPressed: _isSaving ? null : _saveClient,
                  child: Text(l10n?.save ?? 'Сохранить'),
                ),
              ],
            ),
          ),
          // Form
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceColor,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Full Name
                      _buildTextField(
                        controller: _fullNameController,
                        label: 'Полное имя',
                        validator: (value) => value?.isEmpty == true ? 'Введите полное имя' : null,
                        icon: Icons.person,
                      ),
                      const SizedBox(height: 24),
                      // Contact Number
                      _buildTextField(
                        controller: _contactNumberController,
                        label: 'Контактный номер',
                        keyboardType: TextInputType.phone,
                        validator: (value) => value?.isEmpty == true ? 'Введите контактный номер' : null,
                        icon: Icons.phone,
                      ),
                      const SizedBox(height: 24),
                      // Passport Number
                      _buildTextField(
                        controller: _passportNumberController,
                        label: 'Номер паспорта',
                        validator: (value) => value?.isEmpty == true ? 'Введите номер паспорта' : null,
                        icon: Icons.credit_card,
                      ),
                      const SizedBox(height: 24),
                      // Address
                      _buildTextField(
                        controller: _addressController,
                        label: 'Адрес',
                        maxLines: 3,
                        validator: (value) => value?.isEmpty == true ? 'Введите адрес' : null,
                        icon: Icons.location_on,
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
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: icon != null ? Icon(icon) : null,
        border: const OutlineInputBorder(),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: AppTheme.primaryColor),
        ),
      ),
      validator: validator,
    );
  }
} 