import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../shared/widgets/custom_icon_button.dart';
import '../domain/entities/investor.dart';
import '../domain/repositories/investor_repository.dart';
import '../data/repositories/investor_repository_impl.dart';
import '../data/datasources/investor_remote_datasource.dart';
import '../../installments/domain/entities/installment.dart';
import '../../installments/domain/repositories/installment_repository.dart';
import '../../installments/data/repositories/installment_repository_impl.dart';
import '../../installments/data/datasources/installment_remote_datasource.dart';
import '../../../shared/widgets/custom_confirmation_dialog.dart';
import '../../../shared/widgets/custom_button.dart';
import '../../../shared/widgets/create_edit_investor_dialog.dart';
import '../../../shared/widgets/responsive_layout.dart';
import 'desktop/investor_details_screen_desktop.dart';
import 'mobile/investor_details_screen_mobile.dart';

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
    _investorRepository = InvestorRepositoryImpl(
      InvestorRemoteDataSourceImpl(),
    );
    _installmentRepository = InstallmentRepositoryImpl(
      InstallmentRemoteDataSourceImpl(),
    );
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    
    try {
      final investor = await _investorRepository.getInvestorById(widget.investorId);
      
      if (!mounted) return;
      
      if (investor == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context)?.investorNotFound ?? 'Инвестор не найден')),
          );
          context.go('/investors');
        }
        return;
      }

      final installments = await _installmentRepository.getInstallmentsByInvestorId(widget.investorId);
      
      if (!mounted) return;
      
      // Filter installments to ensure only investor's installments are shown
      final filteredInstallments = installments.where((installment) => 
        installment.investorId == widget.investorId
      ).toList();

      setState(() {
        _investor = investor;
        _installments = filteredInstallments;
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

  Future<void> _showEditDialog() async {
    if (_investor == null) return;
    
    await showDialog(
      context: context,
      builder: (context) => CreateEditInvestorDialog(
        investor: _investor,
        onSuccess: _loadData, // Reload data after successful edit
      ),
    );
  }

  Future<void> _handleDelete() async {
    final l10n = AppLocalizations.of(context);
    String confirmationMessage = 'Вы уверены, что хотите удалить инвестора ${_investor!.fullName}?';
    if (l10n != null) {
      confirmationMessage = l10n.deleteInvestorConfirmation(_investor!.fullName);
    }
    
    final confirmed = await showCustomConfirmationDialog(
      context: context,
      title: l10n?.deleteInvestorTitle ?? 'Удалить инвестора',
      content: confirmationMessage,
    );
    
    if (confirmed == true) {
      try {
        await _investorRepository.deleteInvestor(_investor!.id);
        if (mounted) {
          // Update the investors list by returning a result
          context.go('/investors', extra: {'refresh': true});
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n?.investorDeleted ?? 'Инвестор удален')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n?.investorDeleteError != null 
                ? l10n?.investorDeleteError(e.toString()) ?? 'Ошибка при удалении: $e' 
                : 'Ошибка при удалении: $e')),
          );
        }
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
              Text(AppLocalizations.of(context)?.investorNotFound ?? 'Инвестор не найден'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.go('/investors'),
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
      mobile: InvestorDetailsScreenMobile(
        investor: _investor!,
        installments: _installments,
        dateFormat: dateFormat,
        currencyFormat: currencyFormat,
        onDelete: _handleDelete,
        onEdit: _showEditDialog,
      ),
      desktop: InvestorDetailsScreenDesktop(
        investor: _investor!,
        installments: _installments,
        dateFormat: dateFormat,
        currencyFormat: currencyFormat,
        onDelete: _handleDelete,
        onEdit: _showEditDialog,
      ),
    );
  }
} 