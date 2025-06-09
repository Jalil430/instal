import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/localization/app_localizations.dart';
import '../domain/entities/installment.dart';
import '../domain/entities/installment_payment.dart';
import '../domain/repositories/installment_repository.dart';
import '../data/repositories/installment_repository_impl.dart';
import '../data/datasources/installment_local_datasource.dart';
import '../../clients/domain/entities/client.dart';
import '../../clients/domain/repositories/client_repository.dart';
import '../../clients/data/repositories/client_repository_impl.dart';
import '../../clients/data/datasources/client_local_datasource.dart';
import '../../investors/domain/entities/investor.dart';
import '../../investors/domain/repositories/investor_repository.dart';
import '../../investors/data/repositories/investor_repository_impl.dart';
import '../../investors/data/datasources/investor_local_datasource.dart';
import '../../../shared/widgets/custom_icon_button.dart';
import '../../../shared/database/database_helper.dart';
import '../../../shared/widgets/custom_button.dart';
import '../../../shared/widgets/custom_dropdown.dart';

class AddInstallmentScreen extends StatefulWidget {
  const AddInstallmentScreen({super.key});

  @override
  State<AddInstallmentScreen> createState() => _AddInstallmentScreenState();
}

class _AddInstallmentScreenState extends State<AddInstallmentScreen> {
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

  // Form values
  Client? _selectedClient;
  Investor? _selectedInvestor;
  DateTime? _buyingDate;
  DateTime? _installmentStartDate;

  // Data lists
  List<Client> _clients = [];
  List<Investor> _investors = [];
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isFormSubmitted = false;

  @override
  void initState() {
    super.initState();
    _initializeRepositories();
    _loadData();
    
    // Set buying date to today
    _buyingDate = DateTime.now();
    
    // Set installment start date to one month from today
    final now = DateTime.now();
    _installmentStartDate = DateTime(now.year, now.month + 1, now.day);
  }

  void _initializeRepositories() {
    final db = DatabaseHelper.instance;
    _installmentRepository = InstallmentRepositoryImpl(
      InstallmentLocalDataSourceImpl(db),
    );
    _clientRepository = ClientRepositoryImpl(
      ClientLocalDataSourceImpl(db),
    );
    _investorRepository = InvestorRepositoryImpl(
      InvestorLocalDataSourceImpl(db),
    );
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      // TODO: Replace with actual user ID from auth
      const userId = 'user123';
      
      final clients = await _clientRepository.getAllClients(userId);
      final investors = await _investorRepository.getAllInvestors(userId);
      
      setState(() {
        _clients = clients;
        _investors = investors;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading data: $e')),
      );
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
    super.dispose();
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

  Future<void> _saveInstallment() async {
    setState(() => _isFormSubmitted = true);
    
    if (!_formKey.currentState!.validate()) return;
    if (_selectedClient == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите клиента')),
      );
      return;
    }

    setState(() => _isSaving = true);
    
    try {
      const userId = 'user123'; // TODO: Replace with actual user ID
      
      // Calculate installment end date
      final startDate = _installmentStartDate!;
      final term = int.parse(_termController.text);
      final endDate = DateTime(startDate.year, startDate.month + term, startDate.day);
      
      // Create installment
      final installment = Installment(
        id: const Uuid().v4(),
        userId: userId,
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
      
      final installmentId = await _installmentRepository.createInstallment(installment);
      
      // Create payment schedule
      await _createPaymentSchedule(installmentId, installment);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Рассрочка успешно создана')),
        );
        context.go('/installments');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка создания рассрочки: $e')),
        );
      }
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _createPaymentSchedule(String installmentId, Installment installment) async {
    final payments = <InstallmentPayment>[];
    int paymentCount = 0;
    
    // Down payment (payment number 0)
    if (installment.downPayment > 0) {
      payments.add(InstallmentPayment(
        id: const Uuid().v4(),
        installmentId: installmentId,
        paymentNumber: 0,
        dueDate: installment.downPaymentDate,
        expectedAmount: installment.downPayment,
        isPaid: false,
        paidDate: null,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));
      
      // Increment payment count if there's a down payment
      paymentCount++;
    }
    
    // Monthly payments - adjust for down payment so total number of payments equals term
    final monthlyPaymentsCount = installment.termMonths - (installment.downPayment > 0 ? 1 : 0);
    
    for (int i = 1; i <= monthlyPaymentsCount; i++) {
      final dueDate = DateTime(
        installment.installmentStartDate.year,
        installment.installmentStartDate.month + i - 1,
        installment.installmentStartDate.day,
      );
      
      payments.add(InstallmentPayment(
        id: const Uuid().v4(),
        installmentId: installmentId,
        paymentNumber: i,
        dueDate: dueDate,
        expectedAmount: installment.monthlyPayment,
        isPaid: false,
        paidDate: null,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));
    }
    
    // Save all payments
    for (final payment in payments) {
      await _installmentRepository.createPayment(payment);
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
                  routePath: '/installments',
                ),
                const SizedBox(width: 16),
                Text(
                  l10n?.addInstallment ?? 'Добавить рассрочку',
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
                  onPressed: _isSaving ? null : () => _saveInstallment(),
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
                autovalidateMode: _isFormSubmitted ? AutovalidateMode.always : AutovalidateMode.disabled,
                child: Container(
                  color: AppTheme.surfaceColor,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Section Headers
                      Text(
                        'Основная информация',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 14),
                      
                      // Client and Investor Selection
                      Row(
                        children: [
                          Expanded(
                            child: _buildClientDropdown(),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            child: _buildInvestorDropdown(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      // Product Name
                      _buildTextField(
                        controller: _productNameController,
                        label: l10n?.productName ?? 'Название товара',
                        validator: (value) => value?.isEmpty == true ? l10n?.enterProductName ?? 'Введите название товара' : null,
                      ),
                      const SizedBox(height: 26),
                      // Pricing Section Header
                      Text(
                        l10n?.financialInfoHeader ?? 'Финансовая информация',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 14),
                      
                      // Prices
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _cashPriceController,
                              label: l10n?.cashPrice ?? 'Цена при покупке без рассрочки',
                              keyboardType: TextInputType.number,
                              suffix: '₽',
                              validator: (value) => _validateNumber(value, l10n?.enterValidPrice ?? 'Введите корректную цену'),
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: _buildTextField(
                              controller: _installmentPriceController,
                              label: l10n?.installmentPrice ?? 'Цена при покупке в рассрочку',
                              keyboardType: TextInputType.number,
                              suffix: '₽',
                              validator: (value) => _validateNumber(value, l10n?.enterValidPrice ?? 'Введите корректную цену'),
                              onChanged: (value) => _calculateMonthlyPayment(),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      // Term and Down Payment
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _termController,
                              label: l10n?.term ?? 'Срок (месяцы)',
                              keyboardType: TextInputType.number,
                              suffix: 'мес.',
                              validator: (value) => _validateNumber(value, l10n?.enterValidTerm ?? 'Введите срок в месяцах'),
                              onChanged: (value) => _calculateMonthlyPayment(),
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: _buildTextField(
                              controller: _downPaymentController,
                              label: l10n?.downPaymentFull ?? 'Первоначальный взнос',
                              keyboardType: TextInputType.number,
                              suffix: '₽',
                              validator: (value) => _validateNumber(value, l10n?.enterValidDownPayment ?? 'Введите сумму первоначального взноса', allowZero: true),
                              onChanged: (value) => _calculateMonthlyPayment(),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      // Monthly Payment (calculated)
                      _buildTextField(
                        controller: _monthlyPaymentController,
                        label: l10n?.monthlyPayment ?? 'Ежемесячный платеж',
                        keyboardType: TextInputType.number,
                        suffix: '₽',
                        readOnly: true,
                        validator: (value) => _validateNumber(value, l10n?.enterValidMonthlyPayment ?? 'Ежемесячный платеж должен быть больше 0'),
                      ),
                      const SizedBox(height: 26),
                      // Dates Section Header
                      Text(
                        l10n?.datesHeader ?? 'Сроки и даты',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 14),
                      
                      // Dates
                      Row(
                        children: [
                          Expanded(
                            child: _buildDateField(
                              label: l10n?.buyingDate ?? 'Дата покупки',
                              value: _buyingDate,
                              onChanged: (date) => setState(() => _buyingDate = date),
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: _buildDateField(
                              label: l10n?.installmentStartDate ?? 'Дата начала рассрочки',
                              value: _installmentStartDate,
                              onChanged: (date) => setState(() => _installmentStartDate = date),
                            ),
                          ),
                        ],
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

  Widget _buildClientDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Клиент',
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(height: 8),
        if (_clients.isEmpty)
          Container(
            width: double.infinity,
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: AppTheme.subtleBackgroundColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.subtleBorderColor,
                width: 1,
              ),
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Нет доступных клиентов',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          )
        else
          CustomDropdown<Client?>(
            value: _selectedClient,
            items: Map.fromEntries(
              _clients.map((client) => MapEntry(client, client.fullName)),
            ),
            onChanged: (client) => setState(() => _selectedClient = client),
            hint: 'Пусто',
            width: double.infinity,
            height: 44,
            showSearch: true,
          ),
        if (_selectedClient == null && _isFormSubmitted)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 16),
            child: Text(
              'Выберите клиента',
              style: TextStyle(
                color: AppTheme.errorColor,
                fontSize: 12,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildInvestorDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Инвестор (необязательно)',
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(height: 8),
        if (_investors.isEmpty)
          Container(
            width: double.infinity,
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: AppTheme.subtleBackgroundColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.subtleBorderColor,
                width: 1,
              ),
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Нет доступных инвесторов',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          )
        else
          CustomDropdown<Investor?>(
            value: _selectedInvestor,
            items: Map.fromEntries(
              _investors.map((investor) => MapEntry(investor, investor.fullName)),
            ),
            onChanged: (investor) => setState(() => _selectedInvestor = investor),
            hint: 'Без инвестора',
            width: double.infinity, 
            height: 44,
            showSearch: true,
          ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    TextInputType? keyboardType,
    String? suffix,
    String? Function(String?)? validator,
    Function(String)? onChanged,
    bool readOnly = false,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      readOnly: readOnly,
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
      onChanged: onChanged,
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
    return InkWell(
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
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
          filled: true,
          fillColor: Colors.white,
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
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          suffixIcon: Icon(
            Icons.calendar_today,
            color: AppTheme.textSecondary,
            size: 20,
          ),
        ),
        child: Text(
          value != null
              ? '${value!.day.toString().padLeft(2, '0')}.${value!.month.toString().padLeft(2, '0')}.${value!.year}'
              : 'Выберите дату',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: value != null ? AppTheme.textPrimary : AppTheme.textHint,
          ),
        ),
      ),
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