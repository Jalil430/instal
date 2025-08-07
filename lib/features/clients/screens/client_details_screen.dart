import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../shared/widgets/custom_icon_button.dart';
import '../domain/entities/client.dart';
import '../domain/repositories/client_repository.dart';
import '../data/repositories/client_repository_impl.dart';
import '../data/datasources/client_remote_datasource.dart';
import '../../installments/domain/entities/installment.dart';
import '../../installments/domain/repositories/installment_repository.dart';
import '../../installments/data/repositories/installment_repository_impl.dart';
import '../../installments/data/datasources/installment_remote_datasource.dart';
import '../../../shared/widgets/custom_confirmation_dialog.dart';
import '../../../shared/widgets/custom_button.dart';
import '../../../shared/widgets/create_edit_client_dialog.dart';
import '../../../shared/widgets/responsive_layout.dart';
import 'desktop/client_details_screen_desktop.dart';
import 'mobile/client_details_screen_mobile.dart';

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
    _clientRepository = ClientRepositoryImpl(
      ClientRemoteDataSourceImpl(),
    );
    _installmentRepository = InstallmentRepositoryImpl(
      InstallmentRemoteDataSourceImpl(),
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
      
      // Filter installments to ensure only client's installments are shown
      final filteredInstallments = installments.where((installment) => 
        installment.clientId == widget.clientId
      ).toList();

      setState(() {
        _client = client;
        _installments = filteredInstallments;
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

  Future<void> _showEditDialog() async {
    if (_client == null) return;
    
    await showDialog(
      context: context,
      builder: (context) => CreateEditClientDialog(
        client: _client,
        onSuccess: _loadData, // Reload data after successful edit
      ),
    );
  }

  Future<void> _handleDelete() async {
    final confirmed = await showCustomConfirmationDialog(
      context: context,
      title: AppLocalizations.of(context)!.deleteClientTitle,
      content: AppLocalizations.of(context)!.deleteClientConfirmation(_client!.fullName),
    );
    if (confirmed == true) {
      try {
        await _clientRepository.deleteClient(_client!.id);
        if (mounted) {
          // Update the clients list by returning a result
          context.go('/clients', extra: {'refresh': true});
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context)!.clientDeleted)),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context)!.clientDeleteError(e))),
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

    return ResponsiveLayout(
      mobile: ClientDetailsScreenMobile(
        client: _client!,
        installments: _installments,
        dateFormat: dateFormat,
        currencyFormat: currencyFormat,
        onDelete: _handleDelete,
        onEdit: _showEditDialog,
      ),
      desktop: ClientDetailsScreenDesktop(
        client: _client!,
        installments: _installments,
        dateFormat: dateFormat,
        currencyFormat: currencyFormat,
        onDelete: _handleDelete,
        onEdit: _showEditDialog,
      ),
    );
  }
} 