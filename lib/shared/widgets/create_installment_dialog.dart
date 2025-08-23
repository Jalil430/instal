import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../../features/wallets/widgets/wallet_selector.dart';
import '../../features/wallets/widgets/quick_create_wallet_dialog.dart';
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

  const CreateInstallmentDialog({
    super.key,
    this.onSuccess,
  });

  @override
  State<CreateInstallmentDialog> createState() => _CreateInstallmentDialogState();
}

class _CreateInstallmentDialogState extends State<CreateInstallmentDialog> {
  final _formKey = GlobalKey<FormState>();
  late InstallmentRepository _installmentRepository;
  late ClientRepository _clientRepository;

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

  // Keys for keyboard navigation
  final GlobalKey<KeyboardNavigableDropdownState<Client>> _clientDropdownKey = GlobalKey();
  final GlobalKey<KeyboardNavigableDropdownState<Wallet?>> _walletDropdownKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    print('🚀 CreateInstallmentDialog initState called');
    _initializeRepositories();
    _initializeDates();
    
    // Add listeners for automatic calculations
    _installmentPriceController.addListener(_calculateMonthlyPayment);
    _termController.addListener(_calculateMonthlyPayment);
    _downPaymentController.addListener(_calculateMonthlyPayment);
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
    // TODO: Initialize wallet repository
    // _walletRepository = WalletRepositoryImpl(WalletRemoteDataSourceImpl());
  }

  void _initializeDates() {
    // Set buying date to today
    _buyingDate = DateTime.now();
    
    // Set installment start date to one month from today
    final now = DateTime.now();
    _installmentStartDate = DateTime(now.year, now.month + 1, now.day);
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
      // TODO: Load wallets from repository
      // final wallets = await _walletRepository.getAllWallets(currentUser.id);
      // final balances = await _walletRepository.getAllWalletBalances(currentUser.id);

      // Mock data for now
      final mockWallets = [
        Wallet(
          id: '1',
          userId: currentUser.id,
          name: 'My Wallet',
          type: WalletType.personal,
          createdAt: DateTime.now().subtract(const Duration(days: 30)),
          updatedAt: DateTime.now(),
        ),
        Wallet(
          id: '2',
          userId: currentUser.id,
          name: 'Investor A',
          type: WalletType.investor,
          investmentAmount: 1000000,
          investorPercentage: 70,
          userPercentage: 30,
          investmentReturnDate: DateTime.now().add(const Duration(days: 365)),
          createdAt: DateTime.now().subtract(const Duration(days: 15)),
          updatedAt: DateTime.now(),
        ),
      ];

      final mockBalances = {
        '1': WalletBalance(
          walletId: '1',
          userId: currentUser.id,
          balanceMinorUnits: 50000000, // 500K RUB
          version: 1,
          updatedAt: DateTime.now(),
        ),
        '2': WalletBalance(
          walletId: '2',
          userId: currentUser.id,
          balanceMinorUnits: 345000000, // 3.45M RUB
          version: 1,
          updatedAt: DateTime.now(),
        ),
      };

      print('✅ getAllWallets returned: ${mockWallets.length} wallets');

      // Debug logging before setState
      print('🚀 About to update state...');
      print('📋 Clients to set: ${clients.length}');
      for (int i = 0; i < clients.length && i < 3; i++) {
        print('   - ${clients[i].fullName}');
      }
      print('💰 Wallets to set: ${mockWallets.length}');
      for (int i = 0; i < mockWallets.length && i < 3; i++) {
        print('   - ${mockWallets[i].name}');
      }

      setState(() {
        _clients = clients;
        _wallets = mockWallets;
        _walletBalances = mockBalances;
        _isLoadingData = false;
      });
      
      print('✅ State updated successfully');
      print('📊 Current _clients.length: ${_clients.length}');
      print('📊 Current _wallets.length: ${_wallets.length}');
      print('📊 Current _isLoadingData: $_isLoadingData');
      

      
      // Auto-focus client dropdown after loading
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _focusClientDropdown();
        }
      });
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
      builder: (context) => QuickCreateWalletDialog(
        onWalletCreated: (name, type) {
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

    setState(() => _isSaving = true);
    
    try {
      final authService = AuthServiceProvider.of(context);
      final currentUser = await authService.getCurrentUser();
      
      if (currentUser == null) {
        throw Exception('User not authenticated');
      }
      
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
        investorId: _selectedWallet?.id ?? '', // Keep for backward compatibility
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
      ..._wallets,
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
          _focusProductName();
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
          _focusProductName();
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
      ),
    );
  }
}