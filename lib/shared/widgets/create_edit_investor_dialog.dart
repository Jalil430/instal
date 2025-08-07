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
import '../widgets/responsive_layout.dart';
import 'dialogs/desktop/create_edit_investor_dialog_desktop.dart';
import 'dialogs/mobile/create_edit_investor_dialog_mobile.dart';
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
    return ResponsiveLayout(
      mobile: CreateEditInvestorDialogMobile(
        formKey: _formKey,
        fullNameController: _fullNameController,
        investmentAmountController: _investmentAmountController,
        investorPercentageController: _investorPercentageController,
        userPercentageController: _userPercentageController,
        fullNameFocus: _fullNameFocus,
        investmentAmountFocus: _investmentAmountFocus,
        investorPercentageFocus: _investorPercentageFocus,
        userPercentageFocus: _userPercentageFocus,
        isSaving: _isSaving,
        isEditing: _isEditing,
        onSave: _saveInvestor,
      ),
      desktop: CreateEditInvestorDialogDesktop(
        formKey: _formKey,
        fullNameController: _fullNameController,
        investmentAmountController: _investmentAmountController,
        investorPercentageController: _investorPercentageController,
        userPercentageController: _userPercentageController,
        fullNameFocus: _fullNameFocus,
        investmentAmountFocus: _investmentAmountFocus,
        investorPercentageFocus: _investorPercentageFocus,
        userPercentageFocus: _userPercentageFocus,
        isSaving: _isSaving,
        isEditing: _isEditing,
        onSave: _saveInvestor,
      ),
    );
  }
}