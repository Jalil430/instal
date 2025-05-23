import 'package:fluent_ui/fluent_ui.dart';
import '../../models/investor.dart';
import '../../services/database_service.dart';
import '../../utils/theme.dart';

class AddEditInvestorScreen extends StatefulWidget {
  final Investor? investor;

  const AddEditInvestorScreen({
    super.key,
    this.investor,
  });

  @override
  State<AddEditInvestorScreen> createState() => _AddEditInvestorScreenState();
}

class _AddEditInvestorScreenState extends State<AddEditInvestorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _investmentAmountController = TextEditingController();
  final _investorPercentageController = TextEditingController();
  final _userPercentageController = TextEditingController();
  
  bool _isLoading = false;
  bool get isEditing => widget.investor != null;

  @override
  void initState() {
    super.initState();
    if (isEditing) {
      _fullNameController.text = widget.investor!.fullName;
      _investmentAmountController.text = widget.investor!.investmentAmount.toStringAsFixed(2);
      _investorPercentageController.text = widget.investor!.investorPercentage.toStringAsFixed(1);
      _userPercentageController.text = widget.investor!.userPercentage.toStringAsFixed(1);
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _investmentAmountController.dispose();
    _investorPercentageController.dispose();
    _userPercentageController.dispose();
    super.dispose();
  }

  bool _validatePercentages() {
    final investorPercentage = double.tryParse(_investorPercentageController.text) ?? 0;
    final userPercentage = double.tryParse(_userPercentageController.text) ?? 0;
    return (investorPercentage + userPercentage) == 100;
  }

  Future<void> _saveInvestor() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (!_validatePercentages()) {
      showDialog(
        context: context,
        builder: (context) => ContentDialog(
          title: const Text('Invalid Percentages'),
          content: const Text('Investor and user percentages must add up to 100%'),
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
      if (isEditing) {
        final updatedInvestor = widget.investor!.copyWith(
          fullName: _fullNameController.text,
          investmentAmount: double.parse(_investmentAmountController.text),
          investorPercentage: double.parse(_investorPercentageController.text),
          userPercentage: double.parse(_userPercentageController.text),
        );
        await DatabaseService.updateInvestor(updatedInvestor);
      } else {
        final newInvestor = Investor(
          id: '',
          userId: '',
          fullName: _fullNameController.text,
          investmentAmount: double.parse(_investmentAmountController.text),
          investorPercentage: double.parse(_investorPercentageController.text),
          userPercentage: double.parse(_userPercentageController.text),
          createdAt: DateTime.now(),
        );
        await DatabaseService.insertInvestor(newInvestor);
      }

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
            content: Text('Failed to save investor: $e'),
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
  Widget build(BuildContext context) {
    return NavigationView(
      appBar: NavigationAppBar(
        title: Text(isEditing ? 'Edit Investor' : 'Add Investor'),
        leading: IconButton(
          icon: const Icon(FluentIcons.back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      content: ScaffoldPage(
        content: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 500),
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: ListView(
                children: [
                  Card(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Investor Information',
                          style: AppTheme.subtitleStyle,
                        ),
                        const SizedBox(height: 24),
                        
                        InfoLabel(
                          label: 'Full Name',
                          isHeader: true,
                          child: TextFormBox(
                            controller: _fullNameController,
                            placeholder: 'Enter investor\'s full name',
                            prefix: const Padding(
                              padding: EdgeInsets.only(left: 8),
                              child: Icon(FluentIcons.contact),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Full name is required';
                              }
                              if (value.length < 3) {
                                return 'Name must be at least 3 characters';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(height: 20),
                        
                        InfoLabel(
                          label: 'Investment Amount',
                          isHeader: true,
                          child: TextFormBox(
                            controller: _investmentAmountController,
                            placeholder: '0.00',
                            prefix: const Padding(
                              padding: EdgeInsets.only(left: 8),
                              child: Text('\$'),
                            ),
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Investment amount is required';
                              }
                              final amount = double.tryParse(value);
                              if (amount == null || amount <= 0) {
                                return 'Invalid amount';
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
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Profit Sharing',
                          style: AppTheme.subtitleStyle,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Specify how profits will be shared. Total must equal 100%.',
                          style: AppTheme.captionStyle,
                        ),
                        const SizedBox(height: 20),
                        
                        Row(
                          children: [
                            Expanded(
                              child: InfoLabel(
                                label: 'Investor Percentage',
                                isHeader: true,
                                child: TextFormBox(
                                  controller: _investorPercentageController,
                                  placeholder: '0.0',
                                  suffix: const Padding(
                                    padding: EdgeInsets.only(right: 8),
                                    child: Text('%'),
                                  ),
                                  keyboardType: TextInputType.number,
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Required';
                                    }
                                    final percentage = double.tryParse(value);
                                    if (percentage == null || percentage < 0 || percentage > 100) {
                                      return 'Invalid %';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: InfoLabel(
                                label: 'Your Percentage',
                                isHeader: true,
                                child: TextFormBox(
                                  controller: _userPercentageController,
                                  placeholder: '0.0',
                                  suffix: const Padding(
                                    padding: EdgeInsets.only(right: 8),
                                    child: Text('%'),
                                  ),
                                  keyboardType: TextInputType.number,
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Required';
                                    }
                                    final percentage = double.tryParse(value);
                                    if (percentage == null || percentage < 0 || percentage > 100) {
                                      return 'Invalid %';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.warningColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppTheme.warningColor.withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                FluentIcons.info,
                                size: 16,
                                color: AppTheme.warningColor,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Total percentage must equal 100%. Currently: ${_calculateTotal()}%',
                                  style: AppTheme.captionStyle.copyWith(
                                    color: AppTheme.warningColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
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
                        onPressed: _isLoading ? null : _saveInvestor,
                        child: _isLoading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: ProgressRing(strokeWidth: 2),
                              )
                            : Text(isEditing ? 'Save Changes' : 'Add Investor'),
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

  String _calculateTotal() {
    final investorPercentage = double.tryParse(_investorPercentageController.text) ?? 0;
    final userPercentage = double.tryParse(_userPercentageController.text) ?? 0;
    return (investorPercentage + userPercentage).toStringAsFixed(1);
  }
} 