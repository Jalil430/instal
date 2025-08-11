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
import '../../features/investors/domain/entities/investor.dart';
import '../../features/investors/domain/repositories/investor_repository.dart';
import '../../features/investors/data/repositories/investor_repository_impl.dart';
import '../../features/investors/data/datasources/investor_remote_datasource.dart';
import '../../features/auth/presentation/widgets/auth_service_provider.dart';
import '../widgets/responsive_layout.dart';
import 'dialogs/desktop/create_installment_dialog_desktop.dart';
import 'dialogs/mobile/create_installment_dialog_mobile.dart';
import 'custom_button.dart';
import 'custom_dropdown.dart';
import 'keyboard_navigable_dropdown.dart';
import 'create_edit_client_dialog.dart';
import 'create_edit_investor_dialog.dart';

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
  late InvestorRepository _investorRepository;

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
  Investor? _selectedInvestor;
  DateTime? _buyingDate;
  DateTime? _installmentStartDate;

  // Data lists
  List<Client> _clients = [];
  List<Investor> _investors = [];
  bool _isLoadingData = true;
  bool _isSaving = false;
  
  // Navigation state
  int _currentStep = 0; // 0: client, 1: investor, 2: product name, etc.
  
  // Keys for keyboard navigation
  final GlobalKey<KeyboardNavigableDropdownState<Client>> _clientDropdownKey = GlobalKey();
  final GlobalKey<KeyboardNavigableDropdownState<Investor?>> _investorDropdownKey = GlobalKey();

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
    _investorRepository = InvestorRepositoryImpl(
      InvestorRemoteDataSourceImpl(),
    );
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
      
      print('📞 Calling getAllInvestors...');
      final investors = await _investorRepository.getAllInvestors(currentUser.id);
      print('✅ getAllInvestors returned: ${investors.length} investors');
      
      // Debug logging before setState
      print('🚀 About to update state...');
      print('📋 Clients to set: ${clients.length}');
      for (int i = 0; i < clients.length && i < 3; i++) {
        print('   - ${clients[i].fullName}');
      }
      print('💰 Investors to set: ${investors.length}');
      for (int i = 0; i < investors.length && i < 3; i++) {
        print('   - ${investors[i].fullName}');
      }
      
      setState(() {
        _clients = clients;
        _investors = investors;
        _isLoadingData = false;
      });
      
      print('✅ State updated successfully');
      print('📊 Current _clients.length: ${_clients.length}');
      print('📊 Current _investors.length: ${_investors.length}');
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

  void _focusInvestorDropdown() {
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

  void _showCreateInvestorDialog() {
    final searchQuery = _investorDropdownKey.currentState?.searchQuery ?? '';
    showDialog(
      context: context,
      builder: (context) => CreateEditInvestorDialog(
        onSuccess: () {
          _loadData(); // Reload investors after creating new one
          _focusInvestorDropdown(); // Return focus to investor dropdown
        },
        initialName: searchQuery.isNotEmpty ? searchQuery : null, // Pre-fill the name field
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
        investorId: _selectedInvestor?.id ?? '',
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
    print('🎨 Dialog build called - _isLoadingData: $_isLoadingData, clients: ${_clients.length}, investors: ${_investors.length}');

    // Create a list with "Without Investor" option
    final investorOptions = <Investor?>[
      null, // Represents "Without Investor"
      ..._investors,
    ];

    return ResponsiveLayout(
      mobile: CreateInstallmentDialogMobile(
        formKey: _formKey,
        clients: _clients,
        investorOptions: investorOptions,
        selectedClient: _selectedClient,
        selectedInvestor: _selectedInvestor,
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
            _focusInvestorDropdown();
          }
        },
        onInvestorSelected: (investor) {
          setState(() => _selectedInvestor = investor);
          _focusProductName();
        },
        onClientDropdownFocus: _focusClientDropdown,
        onInvestorDropdownFocus: _focusInvestorDropdown,
        onProductNameFocus: _focusProductName,
        onCreateClient: _showCreateClientDialog,
        onCreateInvestor: _showCreateInvestorDialog,
        onSave: _saveInstallment,
        onBuyingDateChanged: (date) => setState(() => _buyingDate = date),
        onInstallmentStartDateChanged: (date) => setState(() => _installmentStartDate = date),
        clientDropdownKey: _clientDropdownKey,
        investorDropdownKey: _investorDropdownKey,
      ),
      desktop: CreateInstallmentDialogDesktop(
        formKey: _formKey,
        clients: _clients,
        investorOptions: investorOptions,
        selectedClient: _selectedClient,
        selectedInvestor: _selectedInvestor,
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
            _focusInvestorDropdown();
          }
        },
        onInvestorSelected: (investor) {
          setState(() => _selectedInvestor = investor);
          _focusProductName();
        },
        onClientDropdownFocus: _focusClientDropdown,
        onInvestorDropdownFocus: _focusInvestorDropdown,
        onProductNameFocus: _focusProductName,
        onCreateClient: _showCreateClientDialog,
        onCreateInvestor: _showCreateInvestorDialog,
        onSave: _saveInstallment,
        onBuyingDateChanged: (date) => setState(() => _buyingDate = date),
        onInstallmentStartDateChanged: (date) => setState(() => _installmentStartDate = date),
        clientDropdownKey: _clientDropdownKey,
        investorDropdownKey: _investorDropdownKey,
      ),
    );
  }
}