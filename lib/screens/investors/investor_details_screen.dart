import 'package:fluent_ui/fluent_ui.dart';
import 'package:intl/intl.dart';
import '../../models/investor.dart';
import '../../models/installment.dart';
import '../../services/database_service.dart';
import '../../utils/theme.dart';
import '../installments/installment_details_screen.dart';
import 'add_edit_investor_screen.dart';

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
  Investor? _investor;
  List<Installment> _installments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final investor = await DatabaseService.getInvestor(widget.investorId);
      if (investor != null) {
        final installments = await DatabaseService.getInvestorInstallments(investor.id);
        setState(() {
          _investor = investor;
          _installments = installments;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
        if (mounted) {
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: ProgressRing());
    }

    if (_investor == null) {
      return const Center(child: Text('Investor not found'));
    }

    final dateFormat = DateFormat('MMM d, yyyy');
    final currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
    final percentFormat = NumberFormat.percentPattern();
    
    // Calculate total returns
    final totalInvested = _installments.fold<double>(
      0,
      (sum, installment) => sum + (installment.installmentPrice * (_investor!.investorPercentage / 100)),
    );
    final potentialReturns = totalInvested * 1.2; // Example calculation

    return NavigationView(
      appBar: NavigationAppBar(
        title: Text('Investor Details - ${_investor!.fullName}'),
        leading: IconButton(
          icon: const Icon(FluentIcons.back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            IconButton(
              icon: const Icon(FluentIcons.edit),
              onPressed: () async {
                await Navigator.push(
                  context,
                  FluentPageRoute(
                    builder: (context) => AddEditInvestorScreen(investor: _investor),
                  ),
                );
                _loadData();
              },
            ),
            const SizedBox(width: 8),
          ],
        ),
      ),
      content: ScaffoldPage(
        content: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            // Investor Info Card
            Card(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: AppTheme.successColor.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Icon(
                            FluentIcons.money,
                            size: 36,
                            color: AppTheme.successColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _investor!.fullName,
                              style: AppTheme.headlineStyle,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Investment Amount: ${currencyFormat.format(_investor!.investmentAmount)}',
                              style: AppTheme.subtitleStyle.copyWith(
                                color: AppTheme.successColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  // Investment Stats
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          title: 'Investor Share',
                          value: '${_investor!.investorPercentage}%',
                          icon: FluentIcons.pie_single,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _StatCard(
                          title: 'Your Share',
                          value: '${_investor!.userPercentage}%',
                          icon: FluentIcons.contact,
                          color: AppTheme.warningColor,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _StatCard(
                          title: 'Active Deals',
                          value: _installments.length.toString(),
                          icon: FluentIcons.money,
                          color: AppTheme.successColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Divider(),
                  const SizedBox(height: 24),
                  
                  _DetailSection(
                    title: 'Investment Information',
                    children: [
                      _DetailRow('Total Investment', currencyFormat.format(_investor!.investmentAmount)),
                      _DetailRow('Investor Percentage', '${_investor!.investorPercentage}%'),
                      _DetailRow('User Percentage', '${_investor!.userPercentage}%'),
                      _DetailRow('Investor Since', dateFormat.format(_investor!.createdAt)),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _DetailSection(
                    title: 'Portfolio Summary',
                    children: [
                      _DetailRow('Active Installments', _installments.length.toString()),
                      _DetailRow('Total Invested in Deals', currencyFormat.format(totalInvested)),
                      _DetailRow('Potential Returns', currencyFormat.format(potentialReturns)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            // Installments Section
            Card(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Investment Portfolio', style: AppTheme.subtitleStyle),
                      Text(
                        '${_installments.length} active',
                        style: AppTheme.captionStyle,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (_installments.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(40),
                        child: Column(
                          children: [
                            Icon(
                              FluentIcons.document,
                              size: 48,
                              color: AppTheme.textSecondaryColor,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No active investments',
                              style: AppTheme.bodyStyle.copyWith(
                                color: AppTheme.textSecondaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ..._installments.map((installment) => _InstallmentListItem(
                      installment: installment,
                      investorPercentage: _investor!.investorPercentage,
                      onTap: () async {
                        await Navigator.push(
                          context,
                          FluentPageRoute(
                            builder: (context) => InstallmentDetailsScreen(
                              installmentId: installment.id,
                            ),
                          ),
                        );
                        _loadData();
                      },
                    )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: AppTheme.captionStyle.copyWith(color: color),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: AppTheme.headlineStyle.copyWith(
              fontSize: 24,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _DetailSection({
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTheme.bodyStyle.copyWith(
            fontWeight: FontWeight.w600,
            color: AppTheme.textSecondaryColor,
          ),
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 160,
            child: Text(
              label,
              style: AppTheme.bodyStyle.copyWith(
                color: AppTheme.textSecondaryColor,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTheme.bodyStyle,
            ),
          ),
        ],
      ),
    );
  }
}

class _InstallmentListItem extends StatelessWidget {
  final Installment installment;
  final double investorPercentage;
  final VoidCallback onTap;

  const _InstallmentListItem({
    required this.installment,
    required this.investorPercentage,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
    final dateFormat = DateFormat('MMM d, yyyy');
    final investorShare = installment.installmentPrice * (investorPercentage / 100);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderColor, width: 1),
      ),
      child: GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      installment.productName,
                      style: AppTheme.bodyStyle.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Started ${dateFormat.format(installment.installmentStartDate)}',
                      style: AppTheme.captionStyle,
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    currencyFormat.format(investorShare),
                    style: AppTheme.bodyStyle.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.successColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'of ${currencyFormat.format(installment.installmentPrice)}',
                    style: AppTheme.captionStyle,
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Icon(
                FluentIcons.chevron_right,
                size: 16,
                color: AppTheme.textSecondaryColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
} 