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
import '../../../shared/database/database_helper.dart';

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

  @override
  void initState() {
    super.initState();
    _initializeRepositories();
    _loadData();
    _buyingDate = DateTime.now();
    _installmentStartDate = DateTime.now();
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
      final monthlyPayment = remainingAmount / term;
      _monthlyPaymentController.text = monthlyPayment.toStringAsFixed(0);
    }
  }

  Future<void> _saveInstallment() async {
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
    
    // Down payment (payment number 0)
    if (installment.downPayment > 0) {
      payments.add(InstallmentPayment(
        id: const Uuid().v4(),
        installmentId: installmentId,
        paymentNumber: 0,
        dueDate: installment.downPaymentDate,
        expectedAmount: installment.downPayment,
        paidAmount: 0,
        status: 'предстоящий',
        paidDate: null,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));
    }
    
    // Monthly payments
    for (int i = 1; i <= installment.termMonths; i++) {
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
        paidAmount: 0,
        status: _getPaymentStatus(dueDate),
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

  String _getPaymentStatus(DateTime dueDate) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final due = DateTime(dueDate.year, dueDate.month, dueDate.day);
    
    if (due.isBefore(today.subtract(const Duration(days: 2)))) {
      return 'просрочено';
    } else if (due.isAtSameMomentAs(today) || due.isAtSameMomentAs(today.subtract(const Duration(days: 1)))) {
      return 'к оплате';
    } else {
      return 'предстоящий';
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
                  onPressed: () => context.go('/installments'),
                  icon: const Icon(Icons.arrow_back),
                ),
                const SizedBox(width: 16),
                Text(
                  l10n?.addInstallment ?? 'Добавить рассрочку',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const Spacer(),
                if (_isSaving) ...[
                  const CircularProgressIndicator(),
                  const SizedBox(width: 16),
                ],
                ElevatedButton(
                  onPressed: _isSaving ? null : _saveInstallment,
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
                      const SizedBox(height: 24),
                      // Product Name
                      _buildTextField(
                        controller: _productNameController,
                        label: 'Название товара',
                        validator: (value) => value?.isEmpty == true ? 'Введите название товара' : null,
                      ),
                      const SizedBox(height: 24),
                      // Prices
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _cashPriceController,
                              label: 'Цена при покупке без рассрочки',
                              keyboardType: TextInputType.number,
                              suffix: '₽',
                              validator: (value) => _validateNumber(value, 'Введите корректную цену'),
                            ),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            child: _buildTextField(
                              controller: _installmentPriceController,
                              label: 'Цена при покупке в рассрочку',
                              keyboardType: TextInputType.number,
                              suffix: '₽',
                              validator: (value) => _validateNumber(value, 'Введите корректную цену'),
                              onChanged: (value) => _calculateMonthlyPayment(),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      // Term and Down Payment
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _termController,
                              label: 'Срок (месяцы)',
                              keyboardType: TextInputType.number,
                              suffix: 'мес.',
                              validator: (value) => _validateNumber(value, 'Введите срок в месяцах'),
                              onChanged: (value) => _calculateMonthlyPayment(),
                            ),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            child: _buildTextField(
                              controller: _downPaymentController,
                              label: 'Первоначальный взнос',
                              keyboardType: TextInputType.number,
                              suffix: '₽',
                              validator: (value) => _validateNumber(value, 'Введите сумму первоначального взноса', allowZero: true),
                              onChanged: (value) => _calculateMonthlyPayment(),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      // Monthly Payment (calculated)
                      _buildTextField(
                        controller: _monthlyPaymentController,
                        label: 'Ежемесячный платеж',
                        keyboardType: TextInputType.number,
                        suffix: '₽',
                        readOnly: true,
                        validator: (value) => _validateNumber(value, 'Ежемесячный платеж должен быть больше 0'),
                      ),
                      const SizedBox(height: 24),
                      // Dates
                      Row(
                        children: [
                          Expanded(
                            child: _buildDateField(
                              label: 'Дата покупки',
                              value: _buyingDate,
                              onChanged: (date) => setState(() => _buyingDate = date),
                            ),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            child: _buildDateField(
                              label: 'Дата начала рассрочки',
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
    return DropdownButtonFormField<Client>(
      value: _selectedClient,
      decoration: const InputDecoration(
        labelText: 'Клиент',
        border: OutlineInputBorder(),
      ),
      items: _clients.map((client) {
        return DropdownMenuItem(
          value: client,
          child: Text(client.fullName),
        );
      }).toList(),
      onChanged: (client) => setState(() => _selectedClient = client),
      validator: (value) => value == null ? 'Выберите клиента' : null,
    );
  }

  Widget _buildInvestorDropdown() {
    return DropdownButtonFormField<Investor>(
      value: _selectedInvestor,
      decoration: const InputDecoration(
        labelText: 'Инвестор (необязательно)',
        border: OutlineInputBorder(),
      ),
      items: _investors.map((investor) {
        return DropdownMenuItem(
          value: investor,
          child: Text(investor.fullName),
        );
      }).toList(),
      onChanged: (investor) => setState(() => _selectedInvestor = investor),
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
      decoration: InputDecoration(
        labelText: label,
        suffixText: suffix,
        border: const OutlineInputBorder(),
        filled: readOnly,
        fillColor: readOnly ? AppTheme.backgroundColor : null,
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
        decoration: const InputDecoration(
          labelText: 'Дата',
          border: OutlineInputBorder(),
          suffixIcon: Icon(Icons.calendar_today),
        ),
        child: Text(
          value != null
              ? '${value!.day.toString().padLeft(2, '0')}.${value!.month.toString().padLeft(2, '0')}.${value!.year}'
              : 'Выберите дату',
          style: value != null ? null : TextStyle(color: Colors.grey[600]),
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