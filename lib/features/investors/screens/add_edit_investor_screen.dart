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
import '../../../shared/widgets/custom_icon_button.dart';
import '../../../shared/widgets/custom_button.dart';

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
            SnackBar(content: Text(AppLocalizations.of(context)?.investorNotFound ?? 'Инвестор не найден')),
          );
          context.go('/investors');
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

  void _calculateUserPercentage() {
    // Don't calculate if the field is empty
    if (_investorPercentageController.text.isEmpty) {
      _userPercentageController.text = '';
      return;
    }
    
    final investorPercentage = double.tryParse(_investorPercentageController.text) ?? 0;
    if (investorPercentage >= 0 && investorPercentage <= 100) {
      final userPercentage = 100 - investorPercentage;
      _userPercentageController.text = userPercentage.toStringAsFixed(1);
    }
  }

  void _calculateInvestorPercentage() {
    // Don't calculate if the user percentage field is empty
    if (_userPercentageController.text.isEmpty) {
      return;
    }
    
    // Only calculate investor percentage if investor field is empty
    if (_investorPercentageController.text.isNotEmpty) return;
    
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
            SnackBar(content: Text(AppLocalizations.of(context)?.investorUpdatedSuccess ?? 'Инвестор успешно обновлен')),
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
            SnackBar(content: Text(AppLocalizations.of(context)?.investorCreatedSuccess ?? 'Инвестор успешно создан')),
          );
          context.go('/investors');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppLocalizations.of(context)?.errorSaving ?? 'Ошибка сохранения'}: $e')),
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
                  routePath: '/investors',
                ),
                const SizedBox(width: 16),
                Text(
                  _isEditing 
                      ? (l10n?.editInvestor ?? 'Редактировать инвестора')
                      : (l10n?.addInvestor ?? 'Добавить инвестора'),
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
                  onPressed: _isSaving ? null : () => _saveInvestor(),
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
                        AppLocalizations.of(context)?.mainInformation ?? 'Основная информация',
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
                      
                      // Investment Amount
                      _buildTextField(
                        controller: _investmentAmountController,
                        label: AppLocalizations.of(context)?.investmentAmount ?? 'Сумма инвестиции',
                        keyboardType: TextInputType.number,
                        suffix: '₽',
                        validator: (value) => _validateNumber(value, AppLocalizations.of(context)?.enterValidInvestmentAmount ?? 'Введите корректную сумму инвестиции'),
                      ),
                      const SizedBox(height: 26),
                      
                      // Section Header
                      Text(
                        AppLocalizations.of(context)?.profitDistribution ?? 'Распределение прибыли',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 14),
                      
                      // Percentages
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _investorPercentageController,
                              label: AppLocalizations.of(context)?.investorShare ?? 'Доля инвестора',
                              keyboardType: TextInputType.number,
                              suffix: '%',
                              validator: (value) => _validatePercentage(value, AppLocalizations.of(context)?.enterValidInvestorShare ?? 'Введите корректную долю инвестора'),
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: _buildTextField(
                              controller: _userPercentageController,
                              label: AppLocalizations.of(context)?.userShare ?? 'Доля пользователя',
                              keyboardType: TextInputType.number,
                              suffix: '%',
                              readOnly: true,
                              validator: (value) => _validatePercentage(value, AppLocalizations.of(context)?.enterValidUserShare ?? 'Введите корректную долю пользователя'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Helper text
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.05),
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
                                AppLocalizations.of(context)?.userShareHelperText ?? 'Доля пользователя рассчитывается автоматически. Сумма долей должна равняться 100%.',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w400,
                                  color: AppTheme.textSecondary,
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
        suffixText: suffix,
        suffixStyle: TextStyle(
          color: AppTheme.textSecondary,
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
        prefixIcon: icon != null ? Icon(icon, color: AppTheme.textSecondary) : null,
        filled: true,
        fillColor: readOnly ? AppTheme.subtleBackgroundColor : Colors.white,
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
    // For empty fields, just show the basic validation message
    if (value?.isEmpty == true) return message;
    
    // Parse and validate the percentage value
    final number = double.tryParse(value!);
    if (number == null || number < 0 || number > 100) return AppLocalizations.of(context)?.percentageValidation ?? 'Процент должен быть от 0 до 100';
    
    // For read-only user percentage field, don't do sum validation if investor field is empty
    if (value == _userPercentageController.text && _investorPercentageController.text.isEmpty) {
      return null;
    }
    
    // Check if percentages add up to 100 when both fields have values
    if (_investorPercentageController.text.isNotEmpty && _userPercentageController.text.isNotEmpty) {
      final investorPercentage = double.tryParse(_investorPercentageController.text) ?? 0;
      final userPercentage = double.tryParse(_userPercentageController.text) ?? 0;
      final total = investorPercentage + userPercentage;
      
      if ((total - 100).abs() > 0.1) {
        return AppLocalizations.of(context)?.percentageSumValidation ?? 'Сумма долей должна равняться 100%';
      }
    }
    
    return null;
  }
} 