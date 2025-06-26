import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/themes/app_theme.dart';
import '../../../installments/domain/entities/installment.dart';
import '../../../installments/presentation/providers/installment_provider.dart';
import '../../../installments/presentation/screens/installment_details_screen.dart';
import '../../../installments/presentation/widgets/installment_list_item.dart';
import '../../domain/entities/investor.dart';
import '../providers/investor_provider.dart';
import 'add_investor_screen.dart';

class InvestorDetailsScreen extends StatefulWidget {
  final String investorId;

  const InvestorDetailsScreen({
    super.key,
    required this.investorId,
  });

  @override
  State<InvestorDetailsScreen> createState() => _InvestorDetailsScreenState();
}

class _InvestorDetailsScreenState extends State<InvestorDetailsScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  Investor? _investor;
  List<Installment> _investorInstallments = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final investorProvider = Provider.of<InvestorProvider>(context, listen: false);
      final installmentProvider = Provider.of<InstallmentProvider>(context, listen: false);
      
      // Load investor
      final investor = await investorProvider.getInvestorById(widget.investorId);
      
      if (investor == null) {
        setState(() {
          _errorMessage = 'Инвестор не найден';
          _isLoading = false;
        });
        return;
      }
      
      // Load investor's installments
      final installments = await installmentProvider.getInstallmentsByInvestorId(investor.id);
      
      if (mounted) {
        setState(() {
          _investor = investor;
          _investorInstallments = installments;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Ошибка загрузки данных: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  void _navigateToEditInvestor() {
    if (_investor == null) return;
    
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AddInvestorScreen(
          initialInvestor: _investor,
        ),
      ),
    ).then((_) {
      // Refresh data when returning from edit screen
      _loadData();
    });
  }

  void _navigateToInstallmentDetails(String installmentId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => InstallmentDetailsScreen(
          installmentId: installmentId,
        ),
      ),
    ).then((_) {
      // Refresh data when returning from details screen
      _loadData();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Детали инвестора'),
        elevation: 0,
        backgroundColor: AppTheme.surfaceColor,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: _investor != null ? _navigateToEditInvestor : null,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: AppTheme.textTertiary),
                      const SizedBox(height: 16),
                      Text(
                        'Ошибка',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _errorMessage!,
                        style: Theme.of(context).textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadData,
                        child: const Text('Повторить'),
                      ),
                    ],
                  ),
                )
              : Container(
                  color: AppTheme.backgroundColor,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Investor Card with basic information
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
                                Row(
                                  children: [
                                    Container(
                                      width: 64,
                                      height: 64,
                                      decoration: BoxDecoration(
                                        color: AppTheme.primaryColor.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(32),
                                      ),
                                      child: const Center(
                                        child: Icon(
                                          Icons.business,
                                          size: 32,
                                          color: AppTheme.primaryColor,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _investor!.fullName,
                                            style: Theme.of(context).textTheme.headlineSmall,
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.pie_chart,
                                                size: 16,
                                                color: AppTheme.textSecondary,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                '${_investor!.investorPercentage}% / ${_investor!.userPercentage}%',
                                                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                                      color: AppTheme.textSecondary,
                                                    ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppTheme.primaryColor.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Column(
                                        children: [
                                          Text(
                                            '${_investorInstallments.length}',
                                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                                  color: AppTheme.primaryColor,
                                                ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            _getInstallmentsLabel(_investorInstallments.length),
                                            style: Theme.of(context).textTheme.bodySmall,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 24),
                                const Divider(),
                                const SizedBox(height: 16),
                                
                                // Investor details
                                _buildDetailRow('Сумма инвестиций:', '${_investor!.investmentAmount} ₽'),
                                _buildDetailRow('Доля инвестора:', '${_investor!.investorPercentage}%'),
                                _buildDetailRow('Ваша доля:', '${_investor!.userPercentage}%'),
                              ],
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // Investor installments
                        Text(
                          'Рассрочки с участием инвестора',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 16),
                        
                        if (_investorInstallments.isEmpty)
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.receipt_long_outlined,
                                    size: 48,
                                    color: AppTheme.textTertiary,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'У инвестора нет рассрочек',
                                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                          color: AppTheme.textSecondary,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        else
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _investorInstallments.length,
                            itemBuilder: (context, index) {
                              final installment = _investorInstallments[index];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: InstallmentListItem(
                                  installment: installment,
                                  onTap: () => _navigateToInstallmentDetails(installment.id),
                                  onEdit: () => _navigateToInstallmentDetails(installment.id),
                                  onDelete: () {
                                    // TODO: Implement delete action if needed
                                  },
                                  onRegisterPayment: () => _navigateToInstallmentDetails(installment.id),
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 1,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
  
  String _getInstallmentsLabel(int count) {
    if (count == 0) {
      return 'рассрочек';
    } else if (count == 1) {
      return 'рассрочка';
    } else if (count >= 2 && count <= 4) {
      return 'рассрочки';
    } else {
      return 'рассрочек';
    }
  }
} 