import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../shared/widgets/custom_add_button.dart';
import '../domain/entities/investor.dart';
import '../domain/repositories/investor_repository.dart';
import '../data/repositories/investor_repository_impl.dart';
import '../data/datasources/investor_local_datasource.dart';
import '../../installments/domain/entities/installment.dart';
import '../../installments/domain/repositories/installment_repository.dart';
import '../../installments/data/repositories/installment_repository_impl.dart';
import '../../installments/data/datasources/installment_local_datasource.dart';
import '../../../shared/database/database_helper.dart';

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
  late InvestorRepository _investorRepository;
  late InstallmentRepository _installmentRepository;

  Investor? _investor;
  List<Installment> _installments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeRepositories();
    _loadData();
  }

  void _initializeRepositories() {
    final db = DatabaseHelper.instance;
    _investorRepository = InvestorRepositoryImpl(
      InvestorLocalDataSourceImpl(db),
    );
    _installmentRepository = InstallmentRepositoryImpl(
      InstallmentLocalDataSourceImpl(db),
    );
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final investor = await _investorRepository.getInvestorById(widget.investorId);
      if (investor == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Инвестор не найден')),
          );
          context.go('/investors');
        }
        return;
      }

      final installments = await _installmentRepository.getInstallmentsByInvestorId(widget.investorId);

      setState(() {
        _investor = investor;
        _installments = installments;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки: $e')),
        );
      }
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

    if (_investor == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              const Text('Инвестор не найден'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.go('/investors'),
                child: const Text('Вернуться к списку'),
              ),
            ],
          ),
        ),
      );
    }

    final currencyFormat = NumberFormat.currency(
      locale: 'ru_RU',
      symbol: '₽',
      decimalDigits: 0,
    );
    final dateFormat = DateFormat('dd.MM.yyyy');

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
                  onPressed: () => context.go('/investors'),
                  icon: const Icon(Icons.arrow_back),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _investor!.fullName,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Инвестиция: ${currencyFormat.format(_investor!.investmentAmount)}',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => context.go('/investors/${widget.investorId}/edit'),
                  icon: const Icon(Icons.edit),
                  label: const Text('Редактировать'),
                ),
              ],
            ),
          ),
          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // Investment Info Cards
                  Row(
                    children: [
                      Expanded(
                        child: _buildInfoCard(
                          title: 'Сумма инвестиции',
                          value: currencyFormat.format(_investor!.investmentAmount),
                          icon: Icons.account_balance_wallet,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildInfoCard(
                          title: 'Доля инвестора',
                          value: '${_investor!.investorPercentage.toStringAsFixed(1)}%',
                          icon: Icons.pie_chart,
                          color: AppTheme.successColor,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildInfoCard(
                          title: 'Доля пользователя',
                          value: '${_investor!.userPercentage.toStringAsFixed(1)}%',
                          icon: Icons.person,
                          color: AppTheme.warningColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Investor Details
                  Container(
                    padding: const EdgeInsets.all(24),
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
                        Text(
                          'Информация об инвесторе',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        const SizedBox(height: 20),
                        _buildDetailRow('Полное имя', _investor!.fullName),
                        _buildDetailRow('Сумма инвестиции', currencyFormat.format(_investor!.investmentAmount)),
                        _buildDetailRow('Доля инвестора', '${_investor!.investorPercentage.toStringAsFixed(1)}%'),
                        _buildDetailRow('Доля пользователя', '${_investor!.userPercentage.toStringAsFixed(1)}%'),
                        _buildDetailRow('Дата создания', dateFormat.format(_investor!.createdAt)),
                        _buildDetailRow('Последнее обновление', dateFormat.format(_investor!.updatedAt)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Installments List
                  Container(
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
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: Row(
                            children: [
                              Text(
                                'Рассрочки инвестора (${_installments.length})',
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                              const Spacer(),
                              CustomAddButton(
                                text: 'Добавить рассрочку',
                                onPressed: () => context.go('/installments/add'),
                                icon: Icons.add,
                              ),
                            ],
                          ),
                        ),
                        if (_installments.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(24),
                            child: Center(
                              child: Text('Нет рассрочек'),
                            ),
                          )
                        else
                          Column(
                            children: _installments.map((installment) {
                              return _InstallmentListItem(
                                installment: installment,
                                onTap: () => context.go('/installments/${installment.id}'),
                              );
                            }).toList(),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textSecondary,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 200,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InstallmentListItem extends StatefulWidget {
  final Installment installment;
  final VoidCallback onTap;

  const _InstallmentListItem({
    required this.installment,
    required this.onTap,
  });

  @override
  State<_InstallmentListItem> createState() => _InstallmentListItemState();
}

class _InstallmentListItemState extends State<_InstallmentListItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(
      locale: 'ru_RU',
      symbol: '₽',
      decimalDigits: 0,
    );
    final dateFormat = DateFormat('dd.MM.yyyy');

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 1),
          decoration: BoxDecoration(
            color: _isHovered ? AppTheme.backgroundColor : AppTheme.surfaceColor,
            border: const Border(
              bottom: BorderSide(
                color: AppTheme.borderColor,
                width: 1,
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 16),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    widget.installment.productName,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    currencyFormat.format(widget.installment.installmentPrice),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    '${widget.installment.termMonths} месяцев',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    dateFormat.format(widget.installment.installmentStartDate),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.textSecondary,
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