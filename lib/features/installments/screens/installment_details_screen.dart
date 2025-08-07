import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../shared/widgets/custom_icon_button.dart';
import '../domain/entities/installment.dart';
import '../domain/entities/installment_payment.dart';
import '../domain/repositories/installment_repository.dart';
import '../data/repositories/installment_repository_impl.dart';
import '../data/datasources/installment_remote_datasource.dart';
import '../../clients/domain/entities/client.dart';
import '../../clients/domain/repositories/client_repository.dart';
import '../../clients/data/repositories/client_repository_impl.dart';
import '../../clients/data/datasources/client_remote_datasource.dart';
import '../../investors/domain/entities/investor.dart';
import '../../investors/domain/repositories/investor_repository.dart';
import '../../investors/data/repositories/investor_repository_impl.dart';
import '../../investors/data/datasources/investor_remote_datasource.dart';
import '../widgets/installment_payment_item.dart';
import '../../../shared/widgets/custom_confirmation_dialog.dart';
import '../../../shared/widgets/responsive_layout.dart';
import 'desktop/installment_details_screen_desktop.dart';
import 'mobile/installment_details_screen_mobile.dart';

class InstallmentDetailsScreen extends StatefulWidget {
  final String installmentId;

  const InstallmentDetailsScreen({
    super.key,
    required this.installmentId,
  });

  @override
  State<InstallmentDetailsScreen> createState() => _InstallmentDetailsScreenState();
}

class _InstallmentDetailsScreenState extends State<InstallmentDetailsScreen> {
  late InstallmentRepository _installmentRepository;
  late ClientRepository _clientRepository;
  late InvestorRepository _investorRepository;

  Installment? _installment;
  Client? _client;
  Investor? _investor;
  List<InstallmentPayment> _payments = [];
  bool _isLoading = true;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeRepositories();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      _loadData();
      _isInitialized = true;
    }
  }

  void _initializeRepositories() {
    _installmentRepository = InstallmentRepositoryImpl(
      InstallmentRemoteDataSourceImpl(),
    );
    _clientRepository = ClientRepositoryImpl(
      ClientRemoteDataSourceImpl(),
    );
    _investorRepository = InvestorRepositoryImpl(
      InvestorRemoteDataSourceImpl(),
    );
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    
    try {
      final installment = await _installmentRepository.getInstallmentById(widget.installmentId);
      
      if (!mounted) return;
      
      if (installment == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Рассрочка не найдена')),
          );
          context.go('/installments');
        }
        return;
      }

      final client = await _clientRepository.getClientById(installment.clientId);
      
      if (!mounted) return;
      
      final investor = installment.investorId.isNotEmpty
          ? await _investorRepository.getInvestorById(installment.investorId)
          : null;
          
      if (!mounted) return;
      
      final payments = await _installmentRepository.getPaymentsByInstallmentId(widget.installmentId);
      
      setState(() {
        _installment = installment;
        _client = client;
        _investor = investor;
        _payments = payments;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppLocalizations.of(context)?.errorLoading ?? 'Ошибка загрузки'}: $e')),
        );
      }
    }
  }

  Future<void> _handleDelete() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showCustomConfirmationDialog(
      context: context,
      title: l10n?.deleteInstallmentTitle ?? 'Удалить рассрочку',
      content: l10n?.deleteInstallmentConfirmation ?? 'Вы уверены, что хотите удалить рассрочку?',
    );
    
    if (confirmed == true) {
      try {
        await _installmentRepository.deleteInstallment(_installment!.id);
        if (mounted) {
          // Update the installments list by returning a result
          context.go('/installments', extra: {'refresh': true});
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n?.installmentDeleted ?? 'Рассрочка удалена')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n?.installmentDeleteError != null 
                ? l10n?.installmentDeleteError(e.toString()) ?? 'Ошибка при удалении: $e' 
                : 'Ошибка при удалении: $e')),
          );
        }
      }
    }
  }

  void _handlePaymentPress(InstallmentPayment payment) {
    // Show payment update dialog or navigate to payment edit screen
    // This could be implemented based on requirements
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_installment == null || _client == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              Text(AppLocalizations.of(context)?.installmentNotFound ?? 'Рассрочка не найдена'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.go('/installments'),
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

    return ResponsiveLayout(
      mobile: InstallmentDetailsScreenMobile(
        installment: _installment!,
        client: _client!,
        investor: _investor,
        payments: _payments,
        dateFormat: dateFormat,
        currencyFormat: currencyFormat,
        onDelete: _handleDelete,
        onPaymentPress: _handlePaymentPress,
      ),
      desktop: InstallmentDetailsScreenDesktop(
        installment: _installment!,
        client: _client!,
        investor: _investor,
        payments: _payments,
        dateFormat: dateFormat,
        currencyFormat: currencyFormat,
        onDelete: _handleDelete,
        onPaymentPress: _handlePaymentPress,
      ),
    );
  }
} 