import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import '../../core/theme/app_theme.dart';
import '../../core/localization/app_localizations.dart';
import '../../features/investors/domain/entities/investor.dart';
import '../../features/investors/domain/repositories/investor_repository.dart';
import '../../features/investors/data/repositories/investor_repository_impl.dart';
import '../../features/investors/data/datasources/investor_remote_datasource.dart';
import '../../features/auth/presentation/widgets/auth_service_provider.dart';
import 'custom_button.dart';

class CreateEditInvestorDialog extends StatefulWidget {
  final Investor? investor; // null for create, investor for edit
  final VoidCallback? onSuccess;
  final String? initialName; // Pre-fill name when creating from search

  const CreateEditInvestorDialog({
    super.key,
    this.investor,
    this.onSuccess,
    this.initialName,
  });

  @override
  State<CreateEditInvestorDialog> createState() => _CreateEditInvestorDialogState();
}

class _CreateEditInvestorDialogState extends State<CreateEditInvestorDialog> {
  final _formKey = GlobalKey<FormState>();
  late InvestorRepository _investorRepository;

  // Form controllers
  final _fullNameController = TextEditingController();
  final _investmentAmountController = TextEditingController();
  final _investorPercentageController = TextEditingController();
  final _userPercentageController = TextEditingController();

  // Focus nodes for automatic navigation
  final _fullNameFocus = FocusNode();
  final _investmentAmountFocus = FocusNode();
  final _investorPercentageFocus = FocusNode();
  final _userPercentageFocus = FocusNode();

  bool _isSaving = false;

  bool get _isEditing => widget.investor != null;

  @override
  void initState() {
    super.initState();
    _initializeRepository();
    _initializeForm();
    
    // Add listeners to auto-calculate percentages
    _investorPercentageController.addListener(_calculateUserPercentage);
    
    // Auto-focus first field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fullNameFocus.requestFocus();
    });
  }

  void _initializeRepository() {
    _investorRepository = InvestorRepositoryImpl(
      InvestorRemoteDataSourceImpl(),
    );
  }

  void _initializeForm() {
    if (_isEditing) {
      final investor = widget.investor!;
      _fullNameController.text = investor.fullName;
      _investmentAmountController.text = investor.investmentAmount.toStringAsFixed(0);
      _investorPercentageController.text = investor.investorPercentage.toStringAsFixed(1);
      _userPercentageController.text = investor.userPercentage.toStringAsFixed(1);
    } else if (widget.initialName != null) {
      // Pre-fill name when creating from search
      _fullNameController.text = widget.initialName!;
    }
  }

  void _calculateUserPercentage() {
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

  @override
  void dispose() {
    _fullNameController.dispose();
    _investmentAmountController.dispose();
    _investorPercentageController.dispose();
    _userPercentageController.dispose();
    _fullNameFocus.dispose();
    _investmentAmountFocus.dispose();
    _investorPercentageFocus.dispose();
    _userPercentageFocus.dispose();
    super.dispose();
  }

  Future<void> _saveInvestor() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    
    try {
      final authService = AuthServiceProvider.of(context);
      final currentUser = await authService.getCurrentUser();
      
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }
      
      if (_isEditing) {
        final updatedInvestor = widget.investor!.copyWith(
          fullName: _fullNameController.text,
          investmentAmount: double.parse(_investmentAmountController.text),
          investorPercentage: double.parse(_investorPercentageController.text),
          userPercentage: double.parse(_userPercentageController.text),
          updatedAt: DateTime.now(),
        );
        
        await _investorRepository.updateInvestor(updatedInvestor);
        
        if (mounted) {
          Navigator.of(context).pop(); // Close dialog first
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)?.investorUpdatedSuccess ?? 'Investor updated successfully'),
              backgroundColor: AppTheme.successColor,
            ),
          );
          
          widget.onSuccess?.call(); // Then call success callback
        }
      } else {
        final newInvestor = Investor(
          id: const Uuid().v4(),
          userId: currentUser.id,
          fullName: _fullNameController.text,
          investmentAmount: double.parse(_investmentAmountController.text),
          investorPercentage: double.parse(_investorPercentageController.text),
          userPercentage: double.parse(_userPercentageController.text),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        
        await _investorRepository.createInvestor(newInvestor);
        
        if (mounted) {
          Navigator.of(context).pop(); // Close dialog first
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)?.investorCreatedSuccess ?? 'Investor created successfully'),
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
                        ? (l10n?.editInvestor ?? 'Edit Investor')
                        : (l10n?.addInvestor ?? 'Add Investor'),
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
                nextFocusNode: _investmentAmountFocus,
                label: l10n?.fullName ?? 'Full Name',
                validator: (value) => value?.isEmpty == true ? l10n?.enterFullName ?? 'Enter full name' : null,
              ),
              const SizedBox(height: 16),
              
              _buildTextField(
                controller: _investmentAmountController,
                focusNode: _investmentAmountFocus,
                nextFocusNode: _investorPercentageFocus,
                label: l10n?.investmentAmount ?? 'Investment Amount',
                keyboardType: TextInputType.number,
                suffix: '₽',
                validator: (value) => _validateNumber(value, l10n?.enterValidInvestmentAmount ?? 'Enter valid investment amount'),
              ),
              const SizedBox(height: 16),
              
              _buildTextField(
                controller: _investorPercentageController,
                focusNode: _investorPercentageFocus,
                label: l10n?.investorShare ?? 'Investor Share',
                keyboardType: TextInputType.number,
                suffix: '%',
                validator: (value) => _validatePercentage(value, l10n?.enterValidInvestorShare ?? 'Enter valid investor share'),
                isLast: true,
                onSubmit: _saveInvestor,
              ),
              const SizedBox(height: 16),
              
              _buildTextField(
                controller: _userPercentageController,
                focusNode: _userPercentageFocus,
                label: l10n?.userShare ?? 'User Share',
                keyboardType: TextInputType.number,
                suffix: '%',
                readOnly: true,
                validator: (value) => _validatePercentage(value, l10n?.enterValidUserShare ?? 'Enter valid user share'),
              ),
              const SizedBox(height: 12),
              
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
                        l10n?.userShareHelperText ?? 'User share is calculated automatically. Total must equal 100%.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
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
                    onPressed: _isSaving ? null : _saveInvestor,
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
    String? suffix,
    String? Function(String?)? validator,
    bool readOnly = false,
    bool isLast = false,
    VoidCallback? onSubmit,
  }) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: keyboardType,
      readOnly: readOnly,
      textInputAction: isLast ? TextInputAction.done : TextInputAction.next,
      onFieldSubmitted: (_) {
        if (isLast) {
          onSubmit?.call();
        } else if (nextFocusNode != null) {
          nextFocusNode.requestFocus();
        }
      },
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: readOnly ? AppTheme.textSecondary : AppTheme.textPrimary,
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
        filled: true,
        fillColor: readOnly ? AppTheme.subtleBackgroundColor : Colors.white,
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
    if (number == null || number < 0 || number > 100) {
      return AppLocalizations.of(context)?.percentageValidation ?? 'Percentage must be between 0 and 100';
    }
    
    // Check if percentages add up to 100 when both fields have values
    if (_investorPercentageController.text.isNotEmpty && _userPercentageController.text.isNotEmpty) {
      final investorPercentage = double.tryParse(_investorPercentageController.text) ?? 0;
      final userPercentage = double.tryParse(_userPercentageController.text) ?? 0;
      final total = investorPercentage + userPercentage;
      
      if ((total - 100).abs() > 0.1) {
        return AppLocalizations.of(context)?.percentageSumValidation ?? 'Total must equal 100%';
      }
    }
    
    return null;
  }
}