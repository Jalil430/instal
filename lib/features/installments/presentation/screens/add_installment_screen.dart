import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/themes/app_theme.dart';
import '../../../../core/utils/date_utils.dart' as app_date_utils;
import '../../../clients/domain/entities/client.dart';
import '../../../clients/presentation/providers/client_provider.dart';
import '../../../clients/presentation/widgets/select_client_dialog.dart';
import '../../../investors/domain/entities/investor.dart';
import '../../../investors/presentation/providers/investor_provider.dart';
import '../../../investors/presentation/widgets/select_investor_dialog.dart';
import '../../domain/entities/installment.dart';
import '../providers/installment_provider.dart';

class AddInstallmentScreen extends StatefulWidget {
  const AddInstallmentScreen({super.key});

  @override
  State<AddInstallmentScreen> createState() => _AddInstallmentScreenState();
}

class _AddInstallmentScreenState extends State<AddInstallmentScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Form controllers
  final _productNameController = TextEditingController();
  final _cashPriceController = TextEditingController();
  final _installmentPriceController = TextEditingController();
  final _termMonthsController = TextEditingController();
  final _downPaymentController = TextEditingController();
  final _monthlyPaymentController = TextEditingController();
  
  // Form values
  Client? _selectedClient;
  Investor? _selectedInvestor;
  DateTime _downPaymentDate = DateTime.now();
  DateTime _installmentStartDate = DateTime.now().add(const Duration(days: 30));
  
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadData();
    
    // Set up listeners for payment calculations
    _installmentPriceController.addListener(_calculateMonthlyPayment);
    _termMonthsController.addListener(_calculateMonthlyPayment);
    _downPaymentController.addListener(_calculateMonthlyPayment);
  }

  @override
  void dispose() {
    _productNameController.dispose();
    _cashPriceController.dispose();
    _installmentPriceController.dispose();
    _termMonthsController.dispose();
    _downPaymentController.dispose();
    _monthlyPaymentController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    // Load clients and investors data
    final clientProvider = Provider.of<ClientProvider>(context, listen: false);
    final investorProvider = Provider.of<InvestorProvider>(context, listen: false);
    
    await clientProvider.loadClients('user_1'); // TODO: Replace with actual user ID
    await investorProvider.loadInvestors('user_1'); // TODO: Replace with actual user ID
  }

  void _calculateMonthlyPayment() {
    if (_installmentPriceController.text.isNotEmpty && 
        _termMonthsController.text.isNotEmpty &&
        _downPaymentController.text.isNotEmpty) {
      
      final installmentPrice = double.tryParse(_installmentPriceController.text) ?? 0;
      final termMonths = int.tryParse(_termMonthsController.text) ?? 0;
      final downPayment = double.tryParse(_downPaymentController.text) ?? 0;
      
      if (termMonths > 0) {
        final remainingAmount = installmentPrice - downPayment;
        final monthlyPayment = remainingAmount / termMonths;
        _monthlyPaymentController.text = monthlyPayment.toStringAsFixed(2);
      }
    }
  }

  Future<void> _selectClient() async {
    final client = await showDialog<Client>(
      context: context,
      builder: (context) => const SelectClientDialog(),
    );
    
    if (client != null) {
      setState(() {
        _selectedClient = client;
      });
    }
  }

  Future<void> _selectInvestor() async {
    final investor = await showDialog<Investor>(
      context: context,
      builder: (context) => const SelectInvestorDialog(),
    );
    
    if (investor != null) {
      setState(() {
        _selectedInvestor = investor;
      });
    }
  }

  Future<void> _saveInstallment() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      try {
        final installmentProvider = Provider.of<InstallmentProvider>(context, listen: false);
        
        // Parse values from form
        final productName = _productNameController.text;
        final cashPrice = double.parse(_cashPriceController.text);
        final installmentPrice = double.parse(_installmentPriceController.text);
        final termMonths = int.parse(_termMonthsController.text);
        final downPayment = double.parse(_downPaymentController.text);
        final monthlyPayment = double.parse(_monthlyPaymentController.text);
        
        // Calculate end date
        final endDate = DateTime(_installmentStartDate.year, 
                                _installmentStartDate.month + termMonths, 
                                _installmentStartDate.day);
        
        // Create installment object
        final installment = Installment(
          id: '', // Will be assigned by repository
          userId: 'user_1', // TODO: Replace with actual user ID
          clientId: _selectedClient!.id,
          investorId: _selectedInvestor?.id ?? '',
          productName: productName,
          cashPrice: cashPrice,
          installmentPrice: installmentPrice,
          termMonths: termMonths,
          downPayment: downPayment,
          monthlyPayment: monthlyPayment,
          downPaymentDate: _downPaymentDate,
          installmentStartDate: _installmentStartDate,
          installmentEndDate: endDate,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        
        // Create installment and payment schedule
        await installmentProvider.createInstallment(installment);
        
        if (mounted) {
          Navigator.of(context).pop();
        }
      } catch (e) {
        setState(() {
          _errorMessage = 'Ошибка при создании рассрочки: ${e.toString()}';
        });
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _selectDownPaymentDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _downPaymentDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    
    if (picked != null && picked != _downPaymentDate) {
      setState(() {
        _downPaymentDate = picked;
        // By default, set installment start date to next month
        _installmentStartDate = DateTime(picked.year, picked.month + 1, 1);
      });
    }
  }

  Future<void> _selectInstallmentStartDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _installmentStartDate,
      firstDate: _downPaymentDate,
      lastDate: DateTime(2100),
    );
    
    if (picked != null && picked != _installmentStartDate) {
      setState(() {
        _installmentStartDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Добавить рассрочку'),
        elevation: 0,
        backgroundColor: AppTheme.surfaceColor,
        actions: [
          TextButton.icon(
            onPressed: _isLoading ? null : _saveInstallment,
            icon: _isLoading 
                ? const SizedBox(
                    width: 16, 
                    height: 16, 
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
            label: const Text('Сохранить'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Container(
        color: AppTheme.backgroundColor,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_errorMessage != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.only(bottom: 24),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: Colors.red.shade700),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(color: Colors.red.shade700),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            setState(() {
                              _errorMessage = null;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                
                // Main form content
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: AppTheme.dividerColor),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Основная информация',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 24),
                        
                        // Client Selection
                        InkWell(
                          onTap: _selectClient,
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Клиент',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.person),
                            ),
                            child: _selectedClient != null
                                ? Text(_selectedClient!.fullName)
                                : const Text(
                                    'Выберите клиента',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                          ),
                        ),
                        if (_selectedClient == null)
                          Container(
                            margin: const EdgeInsets.only(top: 8, left: 12),
                            child: Text(
                              'Пожалуйста, выберите клиента',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        const SizedBox(height: 16),
                        
                        // Investor Selection
                        InkWell(
                          onTap: _selectInvestor,
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Инвестор',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.business),
                            ),
                            child: _selectedInvestor != null
                                ? Text(_selectedInvestor!.fullName)
                                : const Text(
                                    'Выберите инвестора (необязательно)',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // Product Name
                        TextFormField(
                          controller: _productNameController,
                          decoration: const InputDecoration(
                            labelText: 'Название товара',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.shopping_bag),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Пожалуйста, введите название товара';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),
                        
                        // Price Section
                        Text(
                          'Информация о ценах',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 24),
                        
                        // Cash Price
                        TextFormField(
                          controller: _cashPriceController,
                          decoration: const InputDecoration(
                            labelText: 'Цена при оплате наличными',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.attach_money),
                          ),
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Пожалуйста, введите цену';
                            }
                            if (double.tryParse(value) == null) {
                              return 'Пожалуйста, введите корректную сумму';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        
                        // Installment Price
                        TextFormField(
                          controller: _installmentPriceController,
                          decoration: const InputDecoration(
                            labelText: 'Цена в рассрочку',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.payments),
                          ),
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Пожалуйста, введите цену в рассрочку';
                            }
                            if (double.tryParse(value) == null) {
                              return 'Пожалуйста, введите корректную сумму';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        
                        // Term
                        TextFormField(
                          controller: _termMonthsController,
                          decoration: const InputDecoration(
                            labelText: 'Срок (месяцев)',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.calendar_month),
                          ),
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Пожалуйста, введите срок';
                            }
                            if (int.tryParse(value) == null) {
                              return 'Пожалуйста, введите целое число';
                            }
                            if (int.parse(value) < 1) {
                              return 'Срок должен быть не менее 1 месяца';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        
                        // Down Payment
                        TextFormField(
                          controller: _downPaymentController,
                          decoration: const InputDecoration(
                            labelText: 'Первоначальный взнос',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.money),
                          ),
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Пожалуйста, введите сумму первоначального взноса';
                            }
                            if (double.tryParse(value) == null) {
                              return 'Пожалуйста, введите корректную сумму';
                            }
                            
                            final downPayment = double.parse(value);
                            final installmentPrice = double.tryParse(_installmentPriceController.text) ?? 0;
                            
                            if (downPayment > installmentPrice) {
                              return 'Первоначальный взнос не может быть больше полной цены';
                            }
                            
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        
                        // Monthly Payment (calculated)
                        TextFormField(
                          controller: _monthlyPaymentController,
                          decoration: const InputDecoration(
                            labelText: 'Ежемесячный платеж',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.account_balance_wallet),
                          ),
                          keyboardType: TextInputType.number,
                          readOnly: true,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Пожалуйста, рассчитайте ежемесячный платеж';
                            }
                            if (double.tryParse(value) == null) {
                              return 'Некорректный ежемесячный платеж';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),
                        
                        // Dates Section
                        Text(
                          'Даты',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 24),
                        
                        // Down Payment Date
                        InkWell(
                          onTap: _selectDownPaymentDate,
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Дата первоначального взноса',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.calendar_today),
                            ),
                            child: Text(
                              app_date_utils.formatDate(_downPaymentDate),
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // Installment Start Date
                        InkWell(
                          onTap: _selectInstallmentStartDate,
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Дата начала рассрочки',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.date_range),
                            ),
                            child: Text(
                              app_date_utils.formatDate(_installmentStartDate),
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
} 