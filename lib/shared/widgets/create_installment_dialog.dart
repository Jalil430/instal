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

  // Focus nodes for automatic navigation
  final _productNameFocus = FocusNode();
  final _cashPriceFocus = FocusNode();
  final _installmentPriceFocus = FocusNode();
  final _termFocus = FocusNode();
  final _downPaymentFocus = FocusNode();
  final _monthlyPaymentFocus = FocusNode();

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
  String _clientSearchQuery = '';
  String _investorSearchQuery = '';
  
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
    _productNameFocus.dispose();
    _cashPriceFocus.dispose();
    _installmentPriceFocus.dispose();
    _termFocus.dispose();
    _downPaymentFocus.dispose();
    _monthlyPaymentFocus.dispose();
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
    final l10n = AppLocalizations.of(context);
    
    print('🎨 Dialog build called - _isLoadingData: $_isLoadingData, clients: ${_clients.length}, investors: ${_investors.length}');



    return Dialog(
      backgroundColor: AppTheme.surfaceColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: 600,
        constraints: const BoxConstraints(maxHeight: 700),
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
                    l10n?.addInstallment ?? 'Add Installment',
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
              
              // Scrollable Form Content
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Client and Investor Selection
                      Row(
                        children: [
                          Expanded(child: _buildClientDropdown()),
                          const SizedBox(width: 16),
                          Expanded(child: _buildInvestorDropdown()),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      // Product Name
                      _buildTextField(
                        controller: _productNameController,
                        focusNode: _productNameFocus,
                        nextFocusNode: _cashPriceFocus,
                        label: l10n?.productName ?? 'Product Name',
                        validator: (value) => value?.isEmpty == true ? l10n?.enterProductName ?? 'Enter product name' : null,
                      ),
                      const SizedBox(height: 16),
                      
                      // Prices
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _cashPriceController,
                              focusNode: _cashPriceFocus,
                              nextFocusNode: _installmentPriceFocus,
                              label: l10n?.cashPrice ?? 'Cash Price',
                              keyboardType: TextInputType.number,
                              suffix: '₽',
                              validator: (value) => _validateNumber(value, l10n?.enterValidPrice ?? 'Enter valid price'),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildTextField(
                              controller: _installmentPriceController,
                              focusNode: _installmentPriceFocus,
                              nextFocusNode: _termFocus,
                              label: l10n?.installmentPrice ?? 'Installment Price',
                              keyboardType: TextInputType.number,
                              suffix: '₽',
                              validator: (value) => _validateNumber(value, l10n?.enterValidPrice ?? 'Enter valid price'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      // Term and Down Payment
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _termController,
                              focusNode: _termFocus,
                              nextFocusNode: _downPaymentFocus,
                              label: l10n?.term ?? 'Term (months)',
                              keyboardType: TextInputType.number,
                              suffix: l10n?.monthShort ?? 'mo.',
                              validator: (value) => _validateNumber(value, l10n?.enterValidTerm ?? 'Enter valid term'),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildTextField(
                              controller: _downPaymentController,
                              focusNode: _downPaymentFocus,
                              label: l10n?.downPaymentFull ?? 'Down Payment',
                              keyboardType: TextInputType.number,
                              suffix: '₽',
                              validator: (value) => _validateNumber(value, l10n?.enterValidDownPayment ?? 'Enter valid down payment', allowZero: true),
                              isLast: true,
                              onSubmit: _saveInstallment,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      // Monthly Payment (calculated)
                      _buildTextField(
                        controller: _monthlyPaymentController,
                        focusNode: _monthlyPaymentFocus,
                        label: l10n?.monthlyPayment ?? 'Monthly Payment',
                        keyboardType: TextInputType.number,
                        suffix: '₽',
                        readOnly: true,
                        validator: (value) => _validateNumber(value, l10n?.validateMonthlyPayment ?? 'Monthly payment must be greater than 0'),
                      ),
                      const SizedBox(height: 16),
                      
                      // Dates
                      Row(
                        children: [
                          Expanded(child: _buildDateField(
                            label: l10n?.buyingDate ?? 'Buying Date',
                            value: _buyingDate,
                            onChanged: (date) => setState(() => _buyingDate = date),
                          )),
                          const SizedBox(width: 16),
                          Expanded(child: _buildDateField(
                            label: l10n?.installmentStartDate ?? 'Installment Start Date',
                            value: _installmentStartDate,
                            onChanged: (date) => setState(() => _installmentStartDate = date),
                          )),
                        ],
                      ),
                    ],
                  ),
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
                    onPressed: _isSaving ? null : _saveInstallment,
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

  Widget _buildClientDropdown() {
    final l10n = AppLocalizations.of(context)!;
    
    if (_isLoadingData) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.client ?? 'Client',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: AppTheme.subtleBackgroundColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Loading clients...',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return KeyboardNavigableDropdown<Client>(
      key: _clientDropdownKey,
      value: _selectedClient,
      items: _clients,
      getDisplayText: (client) => client.fullName,
      getSearchText: (client) => client.fullName,
      onChanged: (client) {
        setState(() => _selectedClient = client);
        _focusInvestorDropdown();
      },
      onNext: _focusInvestorDropdown,
      label: l10n.client ?? 'Client',
      hint: '${l10n.search ?? 'Search'}...',
      noItemsMessage: 'No clients found',
      onCreateNew: _showCreateClientDialog,
      autoFocus: _currentStep == 0 && !_isLoadingData,
    );
  }

  Widget _buildInvestorDropdown() {
    final l10n = AppLocalizations.of(context)!;
    
    if (_isLoadingData) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.investorOptional ?? 'Investor (Optional)',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: AppTheme.subtleBackgroundColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Loading investors...',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    // Create a list with "Without Investor" option
    final investorOptions = <Investor?>[
      null, // Represents "Without Investor"
      ..._investors,
    ];

    return KeyboardNavigableDropdown<Investor?>(
      key: _investorDropdownKey,
      value: _selectedInvestor,
      items: investorOptions,
      getDisplayText: (investor) => investor?.fullName ?? (l10n.withoutInvestor ?? 'Without Investor'),
      getSearchText: (investor) => investor?.fullName ?? (l10n.withoutInvestor ?? 'Without Investor'),
      onChanged: (investor) {
        setState(() => _selectedInvestor = investor);
        _focusProductName();
      },
      onNext: _focusProductName,
      label: l10n.investorOptional ?? 'Investor (Optional)',
      hint: '${l10n.search ?? 'Search'}...',
      noItemsMessage: 'No investors found',
      onCreateNew: _showCreateInvestorDialog,
      autoFocus: _currentStep == 1 && !_isLoadingData,
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

  Widget _buildDateField({
    required String label,
    required DateTime? value,
    required Function(DateTime) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: value ?? DateTime.now(),
              firstDate: DateTime(2020),
              lastDate: DateTime(2030),
            );
            if (date != null) {
              onChanged(date);
            }
          },
          child: Container(
            width: double.infinity,
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    value != null
                        ? '${value.day.toString().padLeft(2, '0')}.${value.month.toString().padLeft(2, '0')}.${value.year}'
                        : AppLocalizations.of(context)?.selectDate ?? 'Select date',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: value != null ? AppTheme.textPrimary : AppTheme.textHint,
                    ),
                  ),
                ),
                Icon(
                  Icons.calendar_today,
                  color: AppTheme.textSecondary,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String? _validateNumber(String? value, String message, {bool allowZero = false}) {
    if (value?.isEmpty == true) return message;
    final number = double.tryParse(value!);
    if (number == null) return message;
    if (!allowZero && number <= 0) return message;
    if (allowZero && number < 0) return message;
    return null;
  }
}