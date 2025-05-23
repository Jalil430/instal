import 'package:fluent_ui/fluent_ui.dart';
import 'package:intl/intl.dart';
import '../../models/installment.dart';
import '../../models/client.dart';
import '../../models/investor.dart';
import '../../services/database_service.dart';
import '../../utils/theme.dart';

class AddInstallmentScreen extends StatefulWidget {
  const AddInstallmentScreen({super.key});

  @override
  State<AddInstallmentScreen> createState() => _AddInstallmentScreenState();
}

class _AddInstallmentScreenState extends State<AddInstallmentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _productNameController = TextEditingController();
  final _cashPriceController = TextEditingController();
  final _installmentPriceController = TextEditingController();
  final _termController = TextEditingController();
  final _downPaymentController = TextEditingController();
  final _monthlyPaymentController = TextEditingController();
  
  Client? _selectedClient;
  Investor? _selectedInvestor;
  DateTime _buyingDate = DateTime.now();
  DateTime _installmentStartDate = DateTime.now();
  
  List<Client> _clients = [];
  List<Investor> _investors = [];
  bool _isLoading = false;
  bool _autoCalculateMonthlyPayment = true;

  @override
  void initState() {
    super.initState();
    _loadData();
    _setupControllerListeners();
  }

  void _setupControllerListeners() {
    _installmentPriceController.addListener(_calculateMonthlyPayment);
    _downPaymentController.addListener(_calculateMonthlyPayment);
    _termController.addListener(_calculateMonthlyPayment);
  }

  void _calculateMonthlyPayment() {
    if (!_autoCalculateMonthlyPayment) return;
    
    final installmentPrice = double.tryParse(_installmentPriceController.text) ?? 0;
    final downPayment = double.tryParse(_downPaymentController.text) ?? 0;
    final term = int.tryParse(_termController.text) ?? 0;
    
    if (term > 0) {
      final remainingAmount = installmentPrice - downPayment;
      final monthlyPayment = remainingAmount / term;
      _monthlyPaymentController.text = monthlyPayment.toStringAsFixed(2);
    }
  }

  Future<void> _loadData() async {
    try {
      final clients = await DatabaseService.getClients();
      final investors = await DatabaseService.getInvestors();
      
      setState(() {
        _clients = clients;
        _investors = investors;
      });
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => ContentDialog(
            title: const Text('Error'),
            content: Text('Failed to load data: $e'),
            actions: [
              Button(
                child: const Text('OK'),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        );
      }
    }
  }

  Future<void> _saveInstallment() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedClient == null) {
      showDialog(
        context: context,
        builder: (context) => ContentDialog(
          title: const Text('Error'),
          content: const Text('Please select a client'),
          actions: [
            Button(
              child: const Text('OK'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final installment = Installment(
        id: '',
        userId: '',
        clientId: _selectedClient!.id,
        investorId: _selectedInvestor?.id,
        productName: _productNameController.text,
        cashPrice: double.parse(_cashPriceController.text),
        installmentPrice: double.parse(_installmentPriceController.text),
        term: int.parse(_termController.text),
        downPayment: double.parse(_downPaymentController.text),
        monthlyPayment: double.parse(_monthlyPaymentController.text),
        downPaymentDate: _buyingDate,
        installmentStartDate: _installmentStartDate,
        installmentEndDate: DateTime(
          _installmentStartDate.year,
          _installmentStartDate.month + int.parse(_termController.text),
          _installmentStartDate.day,
        ),
        createdAt: DateTime.now(),
      );

      await DatabaseService.insertInstallment(installment);
      
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => ContentDialog(
            title: const Text('Error'),
            content: Text('Failed to save installment: $e'),
            actions: [
              Button(
                child: const Text('OK'),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        );
      }
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

  @override
  Widget build(BuildContext context) {
    return NavigationView(
      appBar: NavigationAppBar(
        title: const Text('Add Installment'),
        leading: IconButton(
          icon: const Icon(FluentIcons.back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      content: ScaffoldPage(
        content: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 600),
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: ListView(
                children: [
                  Card(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Basic Information', style: AppTheme.subtitleStyle),
                        const SizedBox(height: 20),
                        
                        InfoLabel(
                          label: 'Client',
                          isHeader: true,
                          child: ComboBox<Client>(
                            placeholder: const Text('Select a client'),
                            value: _selectedClient,
                            items: _clients.map((client) {
                              return ComboBoxItem(
                                value: client,
                                child: Text(client.fullName),
                              );
                            }).toList(),
                            onChanged: (client) => setState(() => _selectedClient = client),
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        InfoLabel(
                          label: 'Investor (Optional)',
                          child: ComboBox<Investor>(
                            placeholder: const Text('Select an investor'),
                            value: _selectedInvestor,
                            items: _investors.map((investor) {
                              return ComboBoxItem(
                                value: investor,
                                child: Text(investor.fullName),
                              );
                            }).toList(),
                            onChanged: (investor) => setState(() => _selectedInvestor = investor),
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        InfoLabel(
                          label: 'Product Name',
                          isHeader: true,
                          child: TextFormBox(
                            controller: _productNameController,
                            placeholder: 'Enter product name',
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Product name is required';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  Card(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Pricing Information', style: AppTheme.subtitleStyle),
                        const SizedBox(height: 20),
                        
                        Row(
                          children: [
                            Expanded(
                              child: InfoLabel(
                                label: 'Cash Price',
                                isHeader: true,
                                child: TextFormBox(
                                  controller: _cashPriceController,
                                  placeholder: '0.00',
                                  prefix: const Padding(
                                    padding: EdgeInsets.only(left: 8),
                                    child: Text('\$'),
                                  ),
                                  keyboardType: TextInputType.number,
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Cash price is required';
                                    }
                                    if (double.tryParse(value) == null) {
                                      return 'Invalid price format';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: InfoLabel(
                                label: 'Installment Price',
                                isHeader: true,
                                child: TextFormBox(
                                  controller: _installmentPriceController,
                                  placeholder: '0.00',
                                  prefix: const Padding(
                                    padding: EdgeInsets.only(left: 8),
                                    child: Text('\$'),
                                  ),
                                  keyboardType: TextInputType.number,
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Installment price is required';
                                    }
                                    if (double.tryParse(value) == null) {
                                      return 'Invalid price format';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        
                        Row(
                          children: [
                            Expanded(
                              child: InfoLabel(
                                label: 'Term (Months)',
                                isHeader: true,
                                child: TextFormBox(
                                  controller: _termController,
                                  placeholder: '0',
                                  keyboardType: TextInputType.number,
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Term is required';
                                    }
                                    final term = int.tryParse(value);
                                    if (term == null || term <= 0) {
                                      return 'Invalid term';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: InfoLabel(
                                label: 'Down Payment',
                                isHeader: true,
                                child: TextFormBox(
                                  controller: _downPaymentController,
                                  placeholder: '0.00',
                                  prefix: const Padding(
                                    padding: EdgeInsets.only(left: 8),
                                    child: Text('\$'),
                                  ),
                                  keyboardType: TextInputType.number,
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Down payment is required';
                                    }
                                    if (double.tryParse(value) == null) {
                                      return 'Invalid amount format';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        
                        InfoLabel(
                          label: 'Monthly Payment',
                          isHeader: true,
                          child: Row(
                            children: [
                              Expanded(
                                child: TextFormBox(
                                  controller: _monthlyPaymentController,
                                  placeholder: '0.00',
                                  prefix: const Padding(
                                    padding: EdgeInsets.only(left: 8),
                                    child: Text('\$'),
                                  ),
                                  keyboardType: TextInputType.number,
                                  onChanged: (_) => setState(() => _autoCalculateMonthlyPayment = false),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Monthly payment is required';
                                    }
                                    if (double.tryParse(value) == null) {
                                      return 'Invalid amount format';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Tooltip(
                                message: 'Auto-calculated based on installment price, down payment, and term',
                                child: Icon(
                                  FluentIcons.info,
                                  size: 16,
                                  color: AppTheme.textSecondaryColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  Card(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Important Dates', style: AppTheme.subtitleStyle),
                        const SizedBox(height: 20),
                        
                        Row(
                          children: [
                            Expanded(
                              child: InfoLabel(
                                label: 'Buying Date',
                                isHeader: true,
                                child: DatePicker(
                                  selected: _buyingDate,
                                  onChanged: (date) => setState(() => _buyingDate = date),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: InfoLabel(
                                label: 'Installment Start Date',
                                isHeader: true,
                                child: DatePicker(
                                  selected: _installmentStartDate,
                                  onChanged: (date) => setState(() => _installmentStartDate = date),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Button(
                        child: const Text('Cancel'),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const SizedBox(width: 12),
                      FilledButton(
                        onPressed: _isLoading ? null : _saveInstallment,
                        child: _isLoading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: ProgressRing(strokeWidth: 2),
                              )
                            : const Text('Add Installment'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
} 