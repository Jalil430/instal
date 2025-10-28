import 'package:flutter/material.dart';

import 'package:uuid/uuid.dart';
import '../../core/theme/app_theme.dart';
import '../../core/localization/app_localizations.dart';
import '../../features/installments/domain/entities/installment.dart';
import '../../features/installments/domain/repositories/installment_repository.dart';
import '../../features/installments/data/repositories/installment_repository_impl.dart';
import '../../features/installments/data/datasources/installment_remote_datasource.dart';
import '../../features/clients/domain/entities/client.dart';
import '../../features/clients/domain/repositories/client_repository.dart';
import '../../features/clients/data/repositories/client_repository_impl.dart';
import '../../features/clients/data/datasources/client_remote_datasource.dart';
import '../../features/wallets/domain/entities/wallet.dart';
import '../../features/wallets/domain/entities/wallet_balance.dart';
import '../../features/wallets/domain/repositories/wallet_repository.dart';
import '../../features/wallets/data/repositories/wallet_repository_impl.dart';
import '../../features/wallets/data/datasources/wallet_remote_datasource_impl.dart';
import '../../features/wallets/widgets/wallet_selector.dart';
import '../../features/wallets/widgets/create_edit_wallet_dialog.dart';
import '../../features/auth/presentation/widgets/auth_service_provider.dart';
import '../widgets/responsive_layout.dart';
import 'dialogs/desktop/create_installment_dialog_desktop.dart';
import 'dialogs/mobile/create_installment_dialog_mobile.dart';
import 'custom_button.dart';
import 'custom_dropdown.dart';
import 'keyboard_navigable_dropdown.dart';
import 'create_edit_client_dialog.dart';

class CreateInstallmentDialog extends StatefulWidget {
  final VoidCallback? onSuccess;
  final Installment? installment; // null for create, installment for edit

  const CreateInstallmentDialog({
    super.key,
    this.onSuccess,
    this.installment, // Add installment parameter for edit mode
  });

  @override
  State<CreateInstallmentDialog> createState() => _CreateInstallmentDialogState();
}

class _CreateInstallmentDialogState extends State<CreateInstallmentDialog> {
  final _formKey = GlobalKey<FormState>();
  late InstallmentRepository _installmentRepository;
  late ClientRepository _clientRepository;
  late WalletRepository _walletRepository;

  // Form controllers
  final _productNameController = TextEditingController();
  final _cashPriceController = TextEditingController();
  final _installmentPriceController = TextEditingController();
  final _termController = TextEditingController();
  final _downPaymentController = TextEditingController();
  final _monthlyPaymentController = TextEditingController();
  final _installmentNumberController = TextEditingController();

  // Focus nodes for automatic navigation
  final _productNameFocus = FocusNode();
  final _cashPriceFocus = FocusNode();
  final _installmentPriceFocus = FocusNode();
  final _termFocus = FocusNode();
  final _downPaymentFocus = FocusNode();
  final _monthlyPaymentFocus = FocusNode();
  final _installmentNumberFocus = FocusNode();

  // Form values
  Client? _selectedClient;
  Wallet? _selectedWallet;
  DateTime? _buyingDate;
  DateTime? _installmentStartDate;

  // Data lists
  List<Client> _clients = [];
  List<Wallet> _wallets = [];
  Map<String, WalletBalance> _walletBalances = {};
  bool _isLoadingData = true;
  bool _isSaving = false;
  
  // Navigation state
  int _currentStep = 0; // 0: client, 1: wallet, 2: product name, etc.
  
  // Edit mode state
  bool get isEditMode => widget.installment != null;

  // Keys for keyboard navigation
  final GlobalKey<KeyboardNavigableDropdownState<Client>> _clientDropdownKey = GlobalKey();
  final GlobalKey<KeyboardNavigableDropdownState<Wallet?>> _walletDropdownKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    print('🚀 CreateInstallmentDialog initState called');
    _initializeRepositories();
    _initializeDates();
    
    // Populate form fields if in edit mode
    if (isEditMode) {
      _populateFormFromInstallment();
    }
    
    // Add listeners for automatic calculations (only in create mode)
    if (!isEditMode) {
      _installmentPriceController.addListener(_calculateMonthlyPayment);
      _termController.addListener(_calculateMonthlyPayment);
      _downPaymentController.addListener(_calculateMonthlyPayment);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isLoadingData) {
      print('🔄 didChangeDependencies - starting data load');
      _loadData();
    }
  }

  void _initializeRepositories() {
    _installmentRepository = InstallmentRepositoryImpl(
      InstallmentRemoteDataSourceImpl(),
    );
    _clientRepository = ClientRepositoryImpl(
      ClientRemoteDataSourceImpl(),
    );
    _walletRepository = WalletRepositoryImpl(
      WalletRemoteDataSourceImpl(),
    );
  }

  void _initializeDates() {
    if (isEditMode) {
      // Use dates from existing installment
      _buyingDate = widget.installment!.downPaymentDate;
      _installmentStartDate = widget.installment!.installmentStartDate;
    } else {
      // Set buying date to today
      _buyingDate = DateTime.now();
      
      // Set installment start date to one month from today
      final now = DateTime.now();
      _installmentStartDate = DateTime(now.year, now.month + 1, now.day);
    }
  }

  void _populateFormFromInstallment() {
    final installment = widget.installment!;
    
    // Populate all form fields with current values
    _productNameController.text = installment.productName;
    _cashPriceController.text = installment.cashPrice.toString();
    _installmentPriceController.text = installment.installmentPrice.toString();
    _termController.text = installment.termMonths.toString();
    _downPaymentController.text = installment.downPayment.toString();
    _monthlyPaymentController.text = installment.monthlyPayment.toString();
    _installmentNumberController.text = installment.installmentNumber?.toString() ?? '';
  }

  Future<void> _loadData() async {
    print('🚀 Starting _loadData...');
    setState(() => _isLoadingData = true);
    
    try {
      print('🔐 Getting auth service...');
      final authService = AuthServiceProvider.of(context);
      final currentUser = await authService.getCurrentUser();
      
      print('👤 Current user: ${currentUser?.id ?? 'NULL'}');
      
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }
      
      print('📞 Calling getAllClients...');
      final clients = await _clientRepository.getAllClients(currentUser.id);
      print('✅ getAllClients returned: ${clients.length} clients');
      
      print('📞 Calling getAllWallets...');
      final wallets = await _walletRepository.getAllWallets(currentUser.id);
      final List<WalletBalance> balances = await _walletRepository.getAllWalletBalances(currentUser.id);
      final Map<String, WalletBalance> balancesMap = {for (final b in balances) b.walletId: b};

      print('✅ getAllWallets returned: ${wallets.length} wallets');

      // Debug logging before setState
      print('🚀 About to update state...');
      print('📋 Clients to set: ${clients.length}');
      for (int i = 0; i < clients.length && i < 3; i++) {
        print('   - ${clients[i].fullName}');
      }
      print('💰 Wallets to set: ${wallets.length}');
      for (int i = 0; i < wallets.length && i < 3; i++) {
        print('   - ${wallets[i].name}');
      }

      setState(() {
        _clients = clients;
        _wallets = wallets;
        _walletBalances = balancesMap;
        
        // Set selected client and wallet if in edit mode
        if (isEditMode) {
          _selectedClient = clients.firstWhere(
            (client) => client.id == widget.installment!.clientId,
            orElse: () => clients.first,
          );
          
          if (widget.installment!.walletId != null) {
            try {
              _selectedWallet = wallets.firstWhere(
                (wallet) => wallet.id == widget.installment!.walletId,
              );
            } catch (e) {
              _selectedWallet = null; // Wallet might have been deleted
            }
          }
        }
        
        _isLoadingData = false;
      });
      
      print('✅ State updated successfully');
      print('📊 Current _clients.length: ${_clients.length}');
      print('📊 Current _wallets.length: ${_wallets.length}');
      print('📊 Current _isLoadingData: $_isLoadingData');
      

      
      // Auto-focus client dropdown after loading (only in create mode)
      if (!isEditMode) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _focusClientDropdown();
          }
        });
      }
    } catch (e) {
      print('❌ Error loading data: $e');
      setState(() => _isLoadingData = false);
      // Note: Can't show SnackBar here as context might not be ready
    }
  }

  void _focusClientDropdown() {
    setState(() => _currentStep = 0);
    // The KeyboardNavigableDropdown will auto-focus when autoFocus is true
  }

  void _focusWalletDropdown() {
    setState(() => _currentStep = 1);
    // Programmatically focus and open the wallet dropdown for smooth keyboard flow
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _walletDropdownKey.currentState?.requestFocusAndOpen();
    });
  }

  void _focusProductName() {
    setState(() => _currentStep = 2);
    _productNameFocus.requestFocus();
  }

  void _showCreateClientDialog() {
    final searchQuery = _clientDropdownKey.currentState?.searchQuery ?? '';
    showDialog(
      context: context,
      builder: (context) => CreateEditClientDialog(
        onSuccess: () {
          _loadData(); // Reload clients after creating new one
          _focusClientDropdown(); // Return focus to client dropdown
        },
        initialName: searchQuery.isNotEmpty ? searchQuery : null, // Pre-fill the name field
      ),
    );
  }

  void _showCreateWalletDialog() {
    showDialog(
      context: context,
      builder: (context) => CreateEditWalletDialog(
        onSuccess: () {
          _loadData(); // Reload wallets after creating new one
          _focusWalletDropdown(); // Return focus to wallet dropdown
        },
      ),
    );
  }

  void _calculateMonthlyPayment() {
    final installmentPrice = double.tryParse(_installmentPriceController.text) ?? 0;
    final downPayment = double.tryParse(_downPaymentController.text) ?? 0;
    final term = int.tryParse(_termController.text) ?? 1;
    
    if (installmentPrice > 0 && term > 0) {
      final remainingAmount = installmentPrice - downPayment;
      
      // Calculate monthly payments based on if there's a down payment
      final effectiveMonthlyPaymentCount = downPayment > 0 ? term - 1 : term;
      
      // Avoid division by zero if term is 1 and there's a down payment
      if (effectiveMonthlyPaymentCount <= 0) {
        _monthlyPaymentController.text = '0';
        return;
      }
      
      final monthlyPayment = remainingAmount / effectiveMonthlyPaymentCount;
      _monthlyPaymentController.text = monthlyPayment.toStringAsFixed(0);
    }
  }

  @override
  void dispose() {
    _productNameController.dispose();
    _cashPriceController.dispose();
    _installmentPriceController.dispose();
    _termController.dispose();
    _downPaymentController.dispose();
    _monthlyPaymentController.dispose();
    _installmentNumberController.dispose();
    _productNameFocus.dispose();
    _cashPriceFocus.dispose();
    _installmentPriceFocus.dispose();
    _termFocus.dispose();
    _downPaymentFocus.dispose();
    _monthlyPaymentFocus.dispose();
    _installmentNumberFocus.dispose();
    super.dispose();
  }

  Future<void> _saveInstallment() async {
    if (isEditMode) {
      // In edit mode, validate allowed fields
      if (_selectedClient == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)?.selectClient ?? 'Select client'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
        return;
      }
      
      // Validate product name is not empty
      if (_productNameController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)?.enterProductName ?? 'Enter product name'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
        return;
      }
    } else {
      // In create mode, validate full form
      if (!_formKey.currentState!.validate()) return;
      if (_selectedClient == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)?.selectClient ?? 'Select client'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
        return;
      }
    }

    setState(() => _isSaving = true);
    
    try {
      final authService = AuthServiceProvider.of(context);
      final currentUser = await authService.getCurrentUser();
      
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }
      
      if (isEditMode) {
        // Update mode - update allowed fields only
        final Map<String, dynamic> updates = {};
        
        // Check if client changed
        if (_selectedClient?.id != widget.installment!.clientId) {
          updates['client_id'] = _selectedClient?.id ?? '';
        }
        
        // Check if wallet changed
        if (_selectedWallet?.id != widget.installment!.walletId) {
          updates['wallet_id'] = _selectedWallet?.id ?? '';
        }
        
        // Check if installment number changed
        final newInstallmentNumber = int.tryParse(_installmentNumberController.text.trim());
        if (newInstallmentNumber != widget.installment!.installmentNumber) {
          updates['installment_number'] = newInstallmentNumber;
        }
        
        // Check if product name changed
        final newProductName = _productNameController.text.trim();
        if (newProductName != widget.installment!.productName) {
          updates['product_name'] = newProductName;
        }
        
        // If no changes, just close dialog
        if (updates.isEmpty) {
          Navigator.of(context).pop();
          return;
        }
        
        await _installmentRepository.updateInstallmentPartial(
          widget.installment!.id,
          updates,
        );
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)?.installmentCreatedSuccess ?? 'Installment updated successfully'),
              backgroundColor: AppTheme.successColor,
            ),
          );
        }
      } else {
        // Create mode - create new installment
        // Calculate installment end date
        final startDate = _installmentStartDate!;
        final term = int.parse(_termController.text);
        final downPayment = double.parse(_downPaymentController.text);
        
        final monthlyPaymentsCount = downPayment > 0 ? term - 1 : term;
        final monthsToAdd = monthlyPaymentsCount - 1;
        final endDate = DateTime(startDate.year, startDate.month + monthsToAdd, startDate.day);
        
        final newInstallment = Installment(
          id: const Uuid().v4(),
          userId: currentUser.id,
          clientId: _selectedClient!.id,
          // Do not populate investorId anymore; use walletId only
          investorId: '',
          walletId: _selectedWallet?.id,
          productName: _productNameController.text,
          cashPrice: double.parse(_cashPriceController.text),
          installmentPrice: double.parse(_installmentPriceController.text),
          termMonths: term,
          downPayment: double.parse(_downPaymentController.text),
          monthlyPayment: double.parse(_monthlyPaymentController.text),
          downPaymentDate: _buyingDate!,
          installmentStartDate: startDate,
          installmentEndDate: endDate,
          installmentNumber: _installmentNumberController.text.trim().isEmpty ? null : int.parse(_installmentNumberController.text.trim()),
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        
        await _installmentRepository.createInstallment(newInstallment);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)?.installmentCreatedSuccess ?? 'Installment created successfully'),
              backgroundColor: AppTheme.successColor,
            ),
          );
        }
      }
      
      if (mounted) {
        Navigator.of(context).pop();
        widget.onSuccess?.call();
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
    print('🎨 Dialog build called - _isLoadingData: $_isLoadingData, clients: ${_clients.length}, wallets: ${_wallets.length}');

    // Create a list with "Without Wallet" option
    final walletOptions = <Wallet?>[
      null, // Represents "Without Wallet"
      ..._wallets.where((w) => w.status == WalletStatus.active),
    ];

    return ResponsiveLayout(
      mobile: CreateInstallmentDialogMobile(
        formKey: _formKey,
        clients: _clients,
        walletOptions: walletOptions,
        walletBalances: _walletBalances,
        selectedClient: _selectedClient,
        selectedWallet: _selectedWallet,
        productNameController: _productNameController,
        cashPriceController: _cashPriceController,
        installmentPriceController: _installmentPriceController,
        termController: _termController,
        downPaymentController: _downPaymentController,
        monthlyPaymentController: _monthlyPaymentController,
        installmentNumberController: _installmentNumberController,
        productNameFocus: _productNameFocus,
        cashPriceFocus: _cashPriceFocus,
        installmentPriceFocus: _installmentPriceFocus,
        termFocus: _termFocus,
        downPaymentFocus: _downPaymentFocus,
        monthlyPaymentFocus: _monthlyPaymentFocus,
        installmentNumberFocus: _installmentNumberFocus,
        buyingDate: _buyingDate,
        installmentStartDate: _installmentStartDate,
        isLoadingData: _isLoadingData,
        isSaving: _isSaving,
        currentStep: _currentStep,
        onClientSelected: (client) {
          if (client != null) {
            setState(() => _selectedClient = client);
            _focusWalletDropdown();
          }
        },
        onWalletSelected: (wallet) {
          setState(() => _selectedWallet = wallet);
          // Do not shift focus to product name here; child moves focus to installment number directly
        },
        onClientDropdownFocus: _focusClientDropdown,
        onWalletDropdownFocus: _focusWalletDropdown,
        onProductNameFocus: _focusProductName,
        onCreateClient: _showCreateClientDialog,
        onCreateWallet: _showCreateWalletDialog,
        onSave: _saveInstallment,
        onBuyingDateChanged: (date) => setState(() => _buyingDate = date),
        onInstallmentStartDateChanged: (date) => setState(() => _installmentStartDate = date),
        clientDropdownKey: _clientDropdownKey,
        walletDropdownKey: _walletDropdownKey,
        isEditMode: isEditMode,
      ),
      desktop: CreateInstallmentDialogDesktop(
        formKey: _formKey,
        clients: _clients,
        walletOptions: walletOptions,
        walletBalances: _walletBalances,
        selectedClient: _selectedClient,
        selectedWallet: _selectedWallet,
        productNameController: _productNameController,
        cashPriceController: _cashPriceController,
        installmentPriceController: _installmentPriceController,
        termController: _termController,
        downPaymentController: _downPaymentController,
        monthlyPaymentController: _monthlyPaymentController,
        installmentNumberController: _installmentNumberController,
        productNameFocus: _productNameFocus,
        cashPriceFocus: _cashPriceFocus,
        installmentPriceFocus: _installmentPriceFocus,
        termFocus: _termFocus,
        downPaymentFocus: _downPaymentFocus,
        monthlyPaymentFocus: _monthlyPaymentFocus,
        installmentNumberFocus: _installmentNumberFocus,
        buyingDate: _buyingDate,
        installmentStartDate: _installmentStartDate,
        isLoadingData: _isLoadingData,
        isSaving: _isSaving,
        currentStep: _currentStep,
        onClientSelected: (client) {
          if (client != null) {
            setState(() => _selectedClient = client);
            _focusWalletDropdown();
          }
        },
        onWalletSelected: (wallet) {
          setState(() => _selectedWallet = wallet);
          // Do not shift focus to product name here; child moves focus to installment number directly
        },
        onClientDropdownFocus: _focusClientDropdown,
        onWalletDropdownFocus: _focusWalletDropdown,
        onProductNameFocus: _focusProductName,
        onCreateClient: _showCreateClientDialog,
        onCreateWallet: _showCreateWalletDialog,
        onSave: _saveInstallment,
        onBuyingDateChanged: (date) => setState(() => _buyingDate = date),
        onInstallmentStartDateChanged: (date) => setState(() => _installmentStartDate = date),
        clientDropdownKey: _clientDropdownKey,
        walletDropdownKey: _walletDropdownKey,
        isEditMode: isEditMode,
      ),
    );
  }
}
