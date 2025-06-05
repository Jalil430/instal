import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/localization/app_localizations.dart';
import '../domain/entities/investor.dart';
import '../domain/repositories/investor_repository.dart';
import '../data/repositories/investor_repository_impl.dart';
import '../data/datasources/investor_local_datasource.dart';
import '../../../shared/database/database_helper.dart';

class AddEditInvestorScreen extends StatefulWidget {
  final String? investorId; // null for add, id for edit

  const AddEditInvestorScreen({
    super.key,
    this.investorId,
  });

  @override
  State<AddEditInvestorScreen> createState() => _AddEditInvestorScreenState();
}

class _AddEditInvestorScreenState extends State<AddEditInvestorScreen> {
  final _formKey = GlobalKey<FormState>();
  late InvestorRepository _investorRepository;

  // Form controllers
  final _fullNameController = TextEditingController();
  final _investmentAmountController = TextEditingController();
  final _investorPercentageController = TextEditingController();
  final _userPercentageController = TextEditingController();

  bool _isLoading = false;
  bool _isSaving = false;
  Investor? _existingInvestor;

  bool get _isEditing => widget.investorId != null;

  @override
  void initState() {
    super.initState();
    _initializeRepository();
    if (_isEditing) {
      _loadInvestor();
    }
    // Add listeners to auto-calculate percentages
    _investorPercentageController.addListener(_calculateUserPercentage);
    _userPercentageController.addListener(_calculateInvestorPercentage);
  }

  void _initializeRepository() {
    final db = DatabaseHelper.instance;
    _investorRepository = InvestorRepositoryImpl(
      InvestorLocalDataSourceImpl(db),
    );
  }

  Future<void> _loadInvestor() async {
    setState(() => _isLoading = true);
    try {
      final investor = await _investorRepository.getInvestorById(widget.investorId!);
      if (investor != null) {
        setState(() {
          _existingInvestor = investor;
          _fullNameController.text = investor.fullName;
          _investmentAmountController.text = investor.investmentAmount.toStringAsFixed(0);
          _investorPercentageController.text = investor.investorPercentage.toStringAsFixed(1);
          _userPercentageController.text = investor.userPercentage.toStringAsFixed(1);
          _isLoading = false;
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Инвестор не найден')),
          );
          context.go('/investors');
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

  void _calculateUserPercentage() {
    final investorPercentage = double.tryParse(_investorPercentageController.text) ?? 0;
    if (investorPercentage >= 0 && investorPercentage <= 100) {
      final userPercentage = 100 - investorPercentage;
      _userPercentageController.text = userPercentage.toStringAsFixed(1);
    }
  }

  void _calculateInvestorPercentage() {
    // Only calculate investor percentage if user manually changes user percentage
    if (!_investorPercentageController.text.isEmpty) return;
    
    final userPercentage = double.tryParse(_userPercentageController.text) ?? 0;
    if (userPercentage >= 0 && userPercentage <= 100) {
      final investorPercentage = 100 - userPercentage;
      _investorPercentageController.text = investorPercentage.toStringAsFixed(1);
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _investmentAmountController.dispose();
    _investorPercentageController.dispose();
    _userPercentageController.dispose();
    super.dispose();
  }

  Future<void> _saveInvestor() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    
    try {
      const userId = 'user123'; // TODO: Replace with actual user ID
      
      if (_isEditing && _existingInvestor != null) {
        // Update existing investor
        final updatedInvestor = _existingInvestor!.copyWith(
          fullName: _fullNameController.text,
          investmentAmount: double.parse(_investmentAmountController.text),
          investorPercentage: double.parse(_investorPercentageController.text),
          userPercentage: double.parse(_userPercentageController.text),
          updatedAt: DateTime.now(),
        );
        
        await _investorRepository.updateInvestor(updatedInvestor);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Инвестор успешно обновлен')),
          );
          context.go('/investors');
        }
      } else {
        // Create new investor
        final newInvestor = Investor(
          id: const Uuid().v4(),
          userId: userId,
          fullName: _fullNameController.text,
          investmentAmount: double.parse(_investmentAmountController.text),
          investorPercentage: double.parse(_investorPercentageController.text),
          userPercentage: double.parse(_userPercentageController.text),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        
        await _investorRepository.createInvestor(newInvestor);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Инвестор успешно создан')),
          );
          context.go('/investors');
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
                  onPressed: () => context.go('/investors'),
                  icon: const Icon(Icons.arrow_back),
                ),
                const SizedBox(width: 16),
                Text(
                  _isEditing 
                      ? (l10n?.editInvestor ?? 'Редактировать инвестора')
                      : (l10n?.addInvestor ?? 'Добавить инвестора'),
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const Spacer(),
                if (_isSaving) ...[
                  const CircularProgressIndicator(),
                  const SizedBox(width: 16),
                ],
                ElevatedButton(
                  onPressed: _isSaving ? null : _saveInvestor,
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
                      // Investment Amount
                      _buildTextField(
                        controller: _investmentAmountController,
                        label: 'Сумма инвестиции',
                        keyboardType: TextInputType.number,
                        suffix: '₽',
                        validator: (value) => _validateNumber(value, 'Введите корректную сумму инвестиции'),
                        icon: Icons.account_balance_wallet,
                      ),
                      const SizedBox(height: 24),
                      // Percentages
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _investorPercentageController,
                              label: 'Доля инвестора',
                              keyboardType: TextInputType.number,
                              suffix: '%',
                              validator: (value) => _validatePercentage(value, 'Введите корректную долю инвестора'),
                              icon: Icons.percent,
                            ),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            child: _buildTextField(
                              controller: _userPercentageController,
                              label: 'Доля пользователя',
                              keyboardType: TextInputType.number,
                              suffix: '%',
                              readOnly: true,
                              validator: (value) => _validatePercentage(value, 'Введите корректную долю пользователя'),
                              icon: Icons.person_outline,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Helper text
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 16,
                              color: AppTheme.primaryColor,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Доля пользователя рассчитывается автоматически. Сумма долей должна равняться 100%.',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: AppTheme.primaryColor,
                                    ),
                              ),
                            ),
                          ],
                        ),
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
    String? suffix,
    String? Function(String?)? validator,
    IconData? icon,
    bool readOnly = false,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      readOnly: readOnly,
      decoration: InputDecoration(
        labelText: label,
        suffixText: suffix,
        prefixIcon: icon != null ? Icon(icon) : null,
        border: const OutlineInputBorder(),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: AppTheme.primaryColor),
        ),
        filled: readOnly,
        fillColor: readOnly ? AppTheme.backgroundColor : null,
      ),
      validator: validator,
      inputFormatters: keyboardType == TextInputType.number
          ? [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))]
          : null,
    );
  }

  String? _validateNumber(String? value, String message) {
    if (value?.isEmpty == true) return message;
    final number = double.tryParse(value!);
    if (number == null || number <= 0) return message;
    return null;
  }

  String? _validatePercentage(String? value, String message) {
    if (value?.isEmpty == true) return message;
    final number = double.tryParse(value!);
    if (number == null || number < 0 || number > 100) return 'Процент должен быть от 0 до 100';
    
    // Check if percentages add up to 100
    final investorPercentage = double.tryParse(_investorPercentageController.text) ?? 0;
    final userPercentage = double.tryParse(_userPercentageController.text) ?? 0;
    final total = investorPercentage + userPercentage;
    
    if ((total - 100).abs() > 0.1) {
      return 'Сумма долей должна равняться 100%';
    }
    
    return null;
  }
} 