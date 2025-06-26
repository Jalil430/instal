import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/themes/app_theme.dart';
import '../../domain/entities/client.dart';
import '../providers/client_provider.dart';

class AddClientScreen extends StatefulWidget {
  final Client? initialClient; // If provided, we're in edit mode
  
  const AddClientScreen({
    super.key,
    this.initialClient,
  });

  @override
  State<AddClientScreen> createState() => _AddClientScreenState();
}

class _AddClientScreenState extends State<AddClientScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Form controllers
  final _fullNameController = TextEditingController();
  final _contactNumberController = TextEditingController();
  final _passportNumberController = TextEditingController();
  final _addressController = TextEditingController();
  
  bool _isLoading = false;
  String? _errorMessage;
  bool get _isEditMode => widget.initialClient != null;

  @override
  void initState() {
    super.initState();
    
    // Populate form if in edit mode
    if (_isEditMode) {
      _fullNameController.text = widget.initialClient!.fullName;
      _contactNumberController.text = widget.initialClient!.contactNumber;
      _passportNumberController.text = widget.initialClient!.passportNumber;
      _addressController.text = widget.initialClient!.address;
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
    if (_formKey.currentState?.validate() ?? false) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      try {
        final clientProvider = Provider.of<ClientProvider>(context, listen: false);
        
        // Create client object
        final client = Client(
          id: _isEditMode ? widget.initialClient!.id : '', // Will be assigned by repository if new
          userId: 'user_1', // TODO: Replace with actual user ID
          fullName: _fullNameController.text,
          contactNumber: _contactNumberController.text,
          passportNumber: _passportNumberController.text,
          address: _addressController.text,
          createdAt: _isEditMode ? widget.initialClient!.createdAt : DateTime.now(),
          updatedAt: DateTime.now(),
        );
        
        if (_isEditMode) {
          // Update existing client
          await clientProvider.updateClient(client);
        } else {
          // Create new client
          await clientProvider.createClient(client);
        }
        
        if (mounted) {
          Navigator.of(context).pop();
        }
      } catch (e) {
        setState(() {
          _errorMessage = 'Ошибка при ${_isEditMode ? 'обновлении' : 'создании'} клиента: ${e.toString()}';
        });
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Редактировать клиента' : 'Добавить клиента'),
        elevation: 0,
        backgroundColor: AppTheme.surfaceColor,
        actions: [
          TextButton.icon(
            onPressed: _isLoading ? null : _saveClient,
            icon: _isLoading 
                ? const SizedBox(
                    width: 16, 
                    height: 16, 
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
            label: const Text('Сохранить'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Container(
        color: AppTheme.backgroundColor,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_errorMessage != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.only(bottom: 24),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: Colors.red.shade700),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(color: Colors.red.shade700),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            setState(() {
                              _errorMessage = null;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                
                // Main form content
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: AppTheme.dividerColor),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Информация о клиенте',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 24),
                        
                        // Full Name
                        TextFormField(
                          controller: _fullNameController,
                          decoration: const InputDecoration(
                            labelText: 'ФИО клиента',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.person),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Пожалуйста, введите ФИО клиента';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        
                        // Contact Number
                        TextFormField(
                          controller: _contactNumberController,
                          decoration: const InputDecoration(
                            labelText: 'Контактный номер',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.phone),
                          ),
                          keyboardType: TextInputType.phone,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Пожалуйста, введите контактный номер';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        
                        // Passport Number
                        TextFormField(
                          controller: _passportNumberController,
                          decoration: const InputDecoration(
                            labelText: 'Номер паспорта',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.assignment_ind),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Пожалуйста, введите номер паспорта';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        
                        // Address
                        TextFormField(
                          controller: _addressController,
                          decoration: const InputDecoration(
                            labelText: 'Адрес',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.home),
                          ),
                          maxLines: 2,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Пожалуйста, введите адрес';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
} 