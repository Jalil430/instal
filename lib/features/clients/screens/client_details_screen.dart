import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../shared/widgets/custom_icon_button.dart';
import '../../../shared/widgets/custom_icon_button.dart';
import '../domain/entities/client.dart';
import '../domain/repositories/client_repository.dart';
import '../data/repositories/client_repository_impl.dart';
import '../data/datasources/client_local_datasource.dart';
import '../../installments/domain/entities/installment.dart';
import '../../installments/domain/repositories/installment_repository.dart';
import '../../installments/data/repositories/installment_repository_impl.dart';
import '../../installments/data/datasources/installment_local_datasource.dart';
import '../../../shared/database/database_helper.dart';
import '../../../shared/widgets/custom_confirmation_dialog.dart';
import '../../../shared/widgets/custom_button.dart';

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
  late ClientRepository _clientRepository;
  late InstallmentRepository _installmentRepository;

  Client? _client;
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
    _clientRepository = ClientRepositoryImpl(
      ClientLocalDataSourceImpl(db),
    );
    _installmentRepository = InstallmentRepositoryImpl(
      InstallmentLocalDataSourceImpl(db),
    );
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final client = await _clientRepository.getClientById(widget.clientId);
      if (client == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context)?.clientNotFound ?? 'Клиент не найден')),
          );
          context.go('/clients');
        }
        return;
      }

      final installments = await _installmentRepository.getInstallmentsByClientId(widget.clientId);

      setState(() {
        _client = client;
        _installments = installments;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppLocalizations.of(context)?.errorLoading ?? 'Ошибка загрузки'}: $e')),
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

    if (_client == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text(AppLocalizations.of(context)?.clientNotFound ?? 'Клиент не найден'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.go('/clients'),
                child: Text(AppLocalizations.of(context)?.backToList ?? 'Вернуться к списку'),
              ),
            ],
          ),
        ),
      );
    }

    final dateFormat = DateFormat('dd.MM.yyyy');
    final currencyFormat = NumberFormat.currency(
      locale: AppLocalizations.of(context)?.locale.languageCode == 'ru' ? 'ru_RU' : 'en_US',
      symbol: AppLocalizations.of(context)?.locale.languageCode == 'ru' ? '₽' : '\$',
      decimalDigits: 0,
    );

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(32, 28, 32, 20),
            color: AppTheme.surfaceColor,
            child: Row(
              children: [
                CustomIconButton(
                  routePath: '/clients',
                ),
                const SizedBox(width: 16),
                Text(
                  '${AppLocalizations.of(context)?.clientDetails ?? 'Детали клиента'} - ${_client!.fullName}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.5,
                  ),
                ),
                const Spacer(),
                CustomIconButton(
                  icon: Icons.edit_outlined,
                  onPressed: () => context.go('/clients/${widget.clientId}/edit'),
                ),
                const SizedBox(width: 12),
                CustomIconButton(
                  icon: Icons.delete_outline,
                  onPressed: () async {
                    final confirmed = await showCustomConfirmationDialog(
                      context: context,
                      title: AppLocalizations.of(context)!.deleteClientTitle,
                      content: AppLocalizations.of(context)!.deleteClientConfirmation(_client!.fullName),
                    );
                    if (confirmed == true) {
                      try {
                        await _clientRepository.deleteClient(_client!.id);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(AppLocalizations.of(context)!.clientDeleted)),
                          );
                          context.go('/clients');
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(AppLocalizations.of(context)!.clientDeleteError(e))),
                          );
                        }
                      }
                    }
                  },
                  hoverBackgroundColor: AppTheme.errorColor.withOpacity(0.1),
                  hoverIconColor: AppTheme.errorColor,
                  hoverBorderColor: AppTheme.errorColor.withOpacity(0.3),
                ),
              ],
            ),
          ),
          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Client Info
                  Text(
                    AppLocalizations.of(context)?.information ?? 'Информация',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildInfoRow(AppLocalizations.of(context)?.fullName ?? 'Полное имя', _client!.fullName),
                  _buildInfoRow(AppLocalizations.of(context)?.contactNumber ?? 'Контактный номер', _client!.contactNumber),
                  _buildInfoRow(AppLocalizations.of(context)?.passportNumber ?? 'Номер паспорта', _client!.passportNumber),
                  _buildInfoRow(AppLocalizations.of(context)?.address ?? 'Адрес', _client!.address),
                  _buildInfoRow(AppLocalizations.of(context)?.creationDate ?? 'Дата создания', dateFormat.format(_client!.createdAt)),

                  const SizedBox(height: 20),

                  // Installments List
                  Row(
                    children: [
                      Text(
                        '${AppLocalizations.of(context)?.clientInstallments ?? 'Рассрочки клиента'} (${_installments.length})',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      CustomButton(
                        onPressed: () => context.go('/installments/add?clientId=${widget.clientId}'),
                        text: AppLocalizations.of(context)?.addInstallment ?? 'Добавить рассрочку',
                        icon: Icons.add,
                        showIcon: true,
                        height: 40
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        _buildTableHeader(context),
                        if (_installments.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(24),
                            child: Center(
                              child: Text(AppLocalizations.of(context)?.noInstallments ?? 'Нет рассрочек'),
                            ),
                          )
                        else
                          ..._installments.map((installment) {
                            return _InstallmentListItem(
                              installment: installment,
                              onTap: () => context.go('/installments/${installment.id}'),
                              currencyFormat: currencyFormat,
                              dateFormat: dateFormat,
                            );
                          }).toList(),
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

  Widget _buildTableHeader(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: AppTheme.subtleBackgroundColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(11),
          topRight: Radius.circular(11),
        ),
        border: Border(
          bottom: BorderSide(
            color: AppTheme.subtleBorderColor,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              l10n?.productNameHeader ?? 'ТОВАР',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w400,
                    fontSize: 12,
                    letterSpacing: 0.5,
                  ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              l10n?.amountHeader ?? 'СУММА',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w400,
                    fontSize: 12,
                    letterSpacing: 0.5,
                  ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              l10n?.termHeader ?? 'СРОК',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w400,
                    fontSize: 12,
                    letterSpacing: 0.5,
                  ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              l10n?.buyingDateHeader ?? 'ДАТА ПОКУПКИ',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w400,
                    fontSize: 12,
                    letterSpacing: 0.5,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 200,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: Colors.grey,
              ),
            ),
          ),
          const SizedBox(width: 32),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppTheme.textPrimary,
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
  final NumberFormat currencyFormat;
  final DateFormat dateFormat;

  const _InstallmentListItem({
    required this.installment,
    required this.onTap,
    required this.currencyFormat,
    required this.dateFormat,
  });

  @override
  State<_InstallmentListItem> createState() => _InstallmentListItemState();
}

class _InstallmentListItemState extends State<_InstallmentListItem> with TickerProviderStateMixin {
  bool _isHovered = false;
  late AnimationController _hoverController;
  late Animation<double> _hoverAnimation;

  @override
  void initState() {
    super.initState();
    _hoverController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    
    _hoverAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _hoverController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _hoverController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return MouseRegion(
      onEnter: (_) {
        setState(() => _isHovered = true);
        _hoverController.forward();
      },
      onExit: (_) {
        setState(() => _isHovered = false);
        _hoverController.reverse();
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _hoverAnimation,
          builder: (context, child) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: Color.lerp(
                  AppTheme.surfaceColor,
                  AppTheme.backgroundColor,
                  _hoverAnimation.value * 0.6,
                ),
                border: Border(
                  bottom: BorderSide(
                    color: AppTheme.borderColor.withOpacity(0.3),
                    width: 1,
                  ),
                ),
              ),
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
                      widget.currencyFormat.format(widget.installment.installmentPrice),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      '${widget.installment.termMonths} ${AppLocalizations.of(context)?.months ?? 'месяцев'}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      widget.dateFormat.format(widget.installment.downPaymentDate),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
} 