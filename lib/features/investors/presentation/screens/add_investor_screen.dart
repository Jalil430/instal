import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/themes/app_theme.dart';
import '../../domain/entities/investor.dart';
import '../providers/investor_provider.dart';

class AddInvestorScreen extends StatefulWidget {
  final Investor? initialInvestor; // If provided, we're in edit mode
  
  const AddInvestorScreen({
    super.key,
    this.initialInvestor,
  });

  @override
  State<AddInvestorScreen> createState() => _AddInvestorScreenState();
}

class _AddInvestorScreenState extends State<AddInvestorScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Form controllers
  final _fullNameController = TextEditingController();
  final _investmentAmountController = TextEditingController();
  final _investorPercentageController = TextEditingController();
  final _userPercentageController = TextEditingController();
  
  bool _isLoading = false;
  String? _errorMessage;
  bool get _isEditMode => widget.initialInvestor != null;

  @override
  void initState() {
    super.initState();
    
    // Populate form if in edit mode
    if (_isEditMode) {
      _fullNameController.text = widget.initialInvestor!.fullName;
      _investmentAmountController.text = widget.initialInvestor!.investmentAmount.toString();
      _investorPercentageController.text = widget.initialInvestor!.investorPercentage.toString();
      _userPercentageController.text = widget.initialInvestor!.userPercentage.toString();
    } else {
      // Default values for new investor
      _investorPercentageController.text = '70'; // 70% for investor
      _userPercentageController.text = '30'; // 30% for user
    }
    
    // Add listeners to update percentages
    _investorPercentageController.addListener(_updateUserPercentage);
    _userPercentageController.addListener(_updateInvestorPercentage);
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _investmentAmountController.dispose();
    _investorPercentageController.dispose();
    _userPercentageController.dispose();
    
    _investorPercentageController.removeListener(_updateUserPercentage);
    _userPercentageController.removeListener(_updateInvestorPercentage);
    super.dispose();
  }
  
  void _updateUserPercentage() {
    final investorPercentage = double.tryParse(_investorPercentageController.text) ?? 0;
    _userPercentageController.removeListener(_updateInvestorPercentage);
    _userPercentageController.text = (100 - investorPercentage).toString();
    _userPercentageController.addListener(_updateInvestorPercentage);
  }
  
  void _updateInvestorPercentage() {
    final userPercentage = double.tryParse(_userPercentageController.text) ?? 0;
    _investorPercentageController.removeListener(_updateUserPercentage);
    _investorPercentageController.text = (100 - userPercentage).toString();
    _investorPercentageController.addListener(_updateUserPercentage);
  }

  Future<void> _saveInvestor() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      try {
        final investorProvider = Provider.of<InvestorProvider>(context, listen: false);
        
        // Create investor object
        final investor = Investor(
          id: _isEditMode ? widget.initialInvestor!.id : '', // Will be assigned by repository if new
          userId: 'user_1', // TODO: Replace with actual user ID
          fullName: _fullNameController.text,
          investmentAmount: double.parse(_investmentAmountController.text),
          investorPercentage: double.parse(_investorPercentageController.text),
          userPercentage: double.parse(_userPercentageController.text),
          createdAt: _isEditMode ? widget.initialInvestor!.createdAt : DateTime.now(),
          updatedAt: DateTime.now(),
        );
        
        if (_isEditMode) {
          // Update existing investor
          await investorProvider.updateInvestor(investor);
        } else {
          // Create new investor
          await investorProvider.createInvestor(investor);
        }
        
        if (mounted) {
          Navigator.of(context).pop();
        }
      } catch (e) {
        setState(() {
          _errorMessage = 'Ошибка при ${_isEditMode ? 'обновлении' : 'создании'} инвестора: ${e.toString()}';
        });
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Редактировать инвестора' : 'Добавить инвестора'),
        elevation: 0,
        backgroundColor: AppTheme.surfaceColor,
        actions: [
          TextButton.icon(
            onPressed: _isLoading ? null : _saveInvestor,
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
                          'Информация об инвесторе',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 24),
                        
                        // Full Name
                        TextFormField(
                          controller: _fullNameController,
                          decoration: const InputDecoration(
                            labelText: 'ФИО инвестора',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.person),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Пожалуйста, введите ФИО инвестора';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        
                        // Investment Amount
                        TextFormField(
                          controller: _investmentAmountController,
                          decoration: const InputDecoration(
                            labelText: 'Сумма инвестиций',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.attach_money),
                            suffixText: '₽',
                          ),
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Пожалуйста, введите сумму инвестиций';
                            }
                            if (double.tryParse(value) == null) {
                              return 'Пожалуйста, введите корректную сумму';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        
                        // Percentages
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _investorPercentageController,
                                decoration: const InputDecoration(
                                  labelText: 'Доля инвестора',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.pie_chart),
                                  suffixText: '%',
                                ),
                                keyboardType: TextInputType.number,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Введите долю';
                                  }
                                  final percentage = double.tryParse(value);
                                  if (percentage == null) {
                                    return 'Некорректное число';
                                  }
                                  if (percentage < 0 || percentage > 100) {
                                    return 'От 0 до 100%';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextFormField(
                                controller: _userPercentageController,
                                decoration: const InputDecoration(
                                  labelText: 'Ваша доля',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.person_pin),
                                  suffixText: '%',
                                ),
                                keyboardType: TextInputType.number,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Введите долю';
                                  }
                                  final percentage = double.tryParse(value);
                                  if (percentage == null) {
                                    return 'Некорректное число';
                                  }
                                  if (percentage < 0 || percentage > 100) {
                                    return 'От 0 до 100%';
                                  }
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Сумма долей должна составлять 100%',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textTertiary,
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