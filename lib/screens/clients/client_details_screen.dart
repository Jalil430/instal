import 'package:fluent_ui/fluent_ui.dart';
import 'package:intl/intl.dart';
import '../../models/client.dart';
import '../../models/installment.dart';
import '../../services/database_service.dart';
import '../../utils/theme.dart';
import '../installments/installment_details_screen.dart';
import 'add_edit_client_screen.dart';

class ClientDetailsScreen extends StatefulWidget {
  final String clientId;

  const ClientDetailsScreen({
    super.key,
    required this.clientId,
  });

  @override
  State<ClientDetailsScreen> createState() => _ClientDetailsScreenState();
}

class _ClientDetailsScreenState extends State<ClientDetailsScreen> {
  Client? _client;
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
      final client = await DatabaseService.getClient(widget.clientId);
      if (client != null) {
        final installments = await DatabaseService.getClientInstallments(client.id);
        setState(() {
          _client = client;
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

    if (_client == null) {
      return const Center(child: Text('Client not found'));
    }

    final dateFormat = DateFormat('MMM d, yyyy');
    final currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 2);

    return NavigationView(
      appBar: NavigationAppBar(
        title: Text('Client Details - ${_client!.fullName}'),
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
                    builder: (context) => AddEditClientScreen(client: _client),
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
            // Client Info Card
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
                          color: AppTheme.primaryColor.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            _client!.fullName.isNotEmpty
                                ? _client!.fullName[0].toUpperCase()
                                : '?',
                            style: TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 24),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _client!.fullName,
                              style: AppTheme.headlineStyle,
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                _InfoBadge(
                                  icon: FluentIcons.phone,
                                  label: _client!.contactNumber,
                                ),
                                const SizedBox(width: 16),
                                _InfoBadge(
                                  icon: FluentIcons.contact_card,
                                  label: _client!.passportNumber,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Divider(),
                  const SizedBox(height: 24),
                  _DetailSection(
                    title: 'Contact Information',
                    children: [
                      _DetailRow('Phone Number', _client!.contactNumber),
                      _DetailRow('Passport Number', _client!.passportNumber),
                      _DetailRow('Address', _client!.address),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _DetailSection(
                    title: 'Additional Information',
                    children: [
                      _DetailRow('Client Since', dateFormat.format(_client!.createdAt)),
                      _DetailRow('Total Installments', _installments.length.toString()),
                      _DetailRow(
                        'Total Investment',
                        currencyFormat.format(
                          _installments.fold<double>(
                            0,
                            (sum, installment) => sum + installment.installmentPrice,
                          ),
                        ),
                      ),
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
                      Text('Installments', style: AppTheme.subtitleStyle),
                      Text(
                        '${_installments.length} total',
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
                              'No installments found',
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

class _InfoBadge extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoBadge({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppTheme.textSecondaryColor),
          const SizedBox(width: 6),
          Text(label, style: AppTheme.bodyStyle),
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
            width: 140,
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
  final VoidCallback onTap;

  const _InstallmentListItem({
    required this.installment,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
    final dateFormat = DateFormat('MMM d, yyyy');

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
                    currencyFormat.format(installment.installmentPrice),
                    style: AppTheme.bodyStyle.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${installment.term} months',
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