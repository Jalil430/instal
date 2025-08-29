import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/localization/app_localizations.dart';
import '../domain/entities/wallet.dart';
import '../domain/repositories/wallet_repository.dart';
import '../data/repositories/wallet_repository_impl.dart';
import '../data/datasources/wallet_remote_datasource_impl.dart';
import '../../../core/api/api_client.dart';
import '../../../core/api/cache_service.dart';
import '../../auth/presentation/widgets/auth_service_provider.dart';

import '../../../shared/widgets/responsive_layout.dart';
import 'dialogs/desktop/create_edit_wallet_dialog_desktop.dart';
import 'dialogs/mobile/create_edit_wallet_dialog_mobile.dart';

class CreateEditWalletDialog extends StatefulWidget {
  final Wallet? wallet; // null for create, wallet for edit
  final VoidCallback? onSuccess;
  final String? initialName; // Pre-fill name when creating from search

  const CreateEditWalletDialog({
    super.key,
    this.wallet,
    this.onSuccess,
    this.initialName,
  });

  @override
  State<CreateEditWalletDialog> createState() => _CreateEditWalletDialogState();
}

class _CreateEditWalletDialogState extends State<CreateEditWalletDialog> {
  final _formKey = GlobalKey<FormState>();
  late WalletRepository _walletRepository;

  // Form controllers
  final _nameController = TextEditingController();
  final _investmentAmountController = TextEditingController();
  final _investorPercentageController = TextEditingController();
  final _userPercentageController = TextEditingController();

  // Focus nodes for automatic navigation
  final _nameFocus = FocusNode();
  final _investmentAmountFocus = FocusNode();
  final _investorPercentageFocus = FocusNode();
  final _userPercentageFocus = FocusNode();

  WalletType _selectedType = WalletType.personal;
  DateTime? _returnDate;
  bool _isSaving = false;

  bool get _isEditing => widget.wallet != null;

  @override
  void initState() {
    super.initState();
    _initializeRepository();
    _initializeForm();
  }

  void _initializeRepository() {
    _walletRepository = WalletRepositoryImpl(
      WalletRemoteDataSourceImpl(
        apiClient: ApiClient(),
        cacheService: CacheService(),
      ),
    );
  }

  void _initializeForm() {
    // Add listeners to auto-calculate percentages
    _investorPercentageController.addListener(_calculateUserPercentage);

    // Auto-focus first field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _nameFocus.requestFocus();
    });

    if (_isEditing) {
      final wallet = widget.wallet!;
      _nameController.text = wallet.name;
      _selectedType = wallet.type;
      if (wallet.isInvestorWallet) {
        _investmentAmountController.text = wallet.investmentAmount?.toStringAsFixed(0) ?? '';
        _investorPercentageController.text = wallet.investorPercentage?.toStringAsFixed(1) ?? '';
        _userPercentageController.text = wallet.userPercentage?.toStringAsFixed(1) ?? '';
        _returnDate = wallet.investmentReturnDate;
      }
    } else if (widget.initialName != null) {
      // Pre-fill name when creating from search
      _nameController.text = widget.initialName!;
    }
  }

  void _calculateUserPercentage() {
    if (_investorPercentageController.text.isEmpty) {
      _userPercentageController.text = '';
      return;
    }

    final investorPercentage = double.tryParse(_investorPercentageController.text) ?? 0;
    final userPercentage = 100.0 - investorPercentage;

    if (userPercentage >= 0) {
      _userPercentageController.text = userPercentage.toStringAsFixed(1);
    } else {
      _userPercentageController.text = '';
    }
  }

  Future<void> _saveWallet() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      // Get current user from authentication
      final authService = AuthServiceProvider.of(context);
      final currentUser = await authService.getCurrentUser();

      if (currentUser == null) {
        throw Exception('User not authenticated');
      }

      if (_isEditing) {
        final updatedWallet = widget.wallet!.copyWith(
          name: _nameController.text,
          type: _selectedType,
          investmentAmount: _selectedType == WalletType.investor
              ? double.parse(_investmentAmountController.text)
              : null,
          investorPercentage: _selectedType == WalletType.investor
              ? double.parse(_investorPercentageController.text)
              : null,
          userPercentage: _selectedType == WalletType.investor
              ? double.parse(_userPercentageController.text)
              : null,
          investmentReturnDate: _selectedType == WalletType.investor
              ? _returnDate
              : null,
          updatedAt: DateTime.now(),
        );

        await _walletRepository.updateWallet(updatedWallet);

        if (mounted) {
          Navigator.of(context).pop(); // Close dialog first

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)?.walletUpdatedSuccess ?? 'Wallet updated successfully'),
              backgroundColor: AppTheme.successColor,
            ),
          );

          widget.onSuccess?.call(); // Then call success callback
        }
      } else {
        final newWallet = Wallet(
          id: const Uuid().v4(),
          userId: currentUser.id,
          name: _nameController.text,
          type: _selectedType,
          investmentAmount: _selectedType == WalletType.investor
              ? double.parse(_investmentAmountController.text)
              : null,
          investorPercentage: _selectedType == WalletType.investor
              ? double.parse(_investorPercentageController.text)
              : null,
          userPercentage: _selectedType == WalletType.investor
              ? double.parse(_userPercentageController.text)
              : null,
          investmentReturnDate: _selectedType == WalletType.investor
              ? _returnDate
              : null,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await _walletRepository.createWallet(newWallet);

        if (mounted) {
          Navigator.of(context).pop(); // Close dialog first

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)?.walletCreatedSuccess ?? 'Wallet created successfully'),
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
            content: Text('${AppLocalizations.of(context)?.errorSaving ?? 'Error saving wallet'}: $e'),
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
  void dispose() {
    _nameController.dispose();
    _investmentAmountController.dispose();
    _investorPercentageController.dispose();
    _userPercentageController.dispose();
    _nameFocus.dispose();
    _investmentAmountFocus.dispose();
    _investorPercentageFocus.dispose();
    _userPercentageFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayout(
      mobile: CreateEditWalletDialogMobile(
        formKey: _formKey,
        nameController: _nameController,
        investmentAmountController: _investmentAmountController,
        investorPercentageController: _investorPercentageController,
        userPercentageController: _userPercentageController,
        nameFocus: _nameFocus,
        investmentAmountFocus: _investmentAmountFocus,
        investorPercentageFocus: _investorPercentageFocus,
        userPercentageFocus: _userPercentageFocus,
        selectedType: _selectedType,
        returnDate: _returnDate,
        isSaving: _isSaving,
        isEditing: _isEditing,
        onTypeChanged: (type) => setState(() => _selectedType = type),
        onReturnDateChanged: (date) => setState(() => _returnDate = date),
        onSave: _saveWallet,
      ),
      desktop: CreateEditWalletDialogDesktop(
        formKey: _formKey,
        nameController: _nameController,
        investmentAmountController: _investmentAmountController,
        investorPercentageController: _investorPercentageController,
        userPercentageController: _userPercentageController,
        nameFocus: _nameFocus,
        investmentAmountFocus: _investmentAmountFocus,
        investorPercentageFocus: _investorPercentageFocus,
        userPercentageFocus: _userPercentageFocus,
        selectedType: _selectedType,
        returnDate: _returnDate,
        isSaving: _isSaving,
        isEditing: _isEditing,
        onTypeChanged: (type) => setState(() => _selectedType = type),
        onReturnDateChanged: (date) => setState(() => _returnDate = date),
        onSave: _saveWallet,
      ),
    );
  }
}
