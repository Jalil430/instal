import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/navigation/responsive_main_layout.dart';
import '../../../shared/widgets/analytics_card.dart';
import '../../../shared/widgets/create_installment_dialog.dart';
import '../../../shared/widgets/custom_button.dart';
import '../../../shared/widgets/custom_confirmation_dialog.dart';
import '../../../shared/widgets/custom_dropdown.dart';
import '../../../shared/widgets/custom_icon_button.dart';
import '../../../shared/widgets/custom_search_bar.dart';
import '../../../shared/widgets/responsive_layout.dart';
import '../../auth/domain/entities/user.dart';
import '../../auth/presentation/widgets/auth_service_provider.dart';
import '../../clients/data/datasources/client_remote_datasource.dart';
import '../../clients/data/repositories/client_repository_impl.dart';
import '../../clients/domain/repositories/client_repository.dart';
import 'desktop/installments_list_screen_desktop.dart';
import 'mobile/installments_list_screen_mobile.dart';
import '../data/datasources/installment_remote_datasource.dart';
import '../data/models/installment_model.dart';
import '../data/repositories/installment_repository_impl.dart';
import '../domain/entities/installment.dart';
import '../domain/entities/installment_payment.dart';
import '../domain/repositories/installment_repository.dart';
import '../services/reminder_service.dart';
import '../../../core/api/cache_service.dart';

class InstallmentsListScreen extends StatefulWidget {
  const InstallmentsListScreen({super.key});

  @override
  InstallmentsListScreenState createState() => InstallmentsListScreenState();
}

class InstallmentsListScreenState extends State<InstallmentsListScreen>
    with TickerProviderStateMixin {
  // WhatsApp brand color - static so it can be accessed from dialog
  static const Color whatsAppColor = Color(0xFF25D366);

  final TextEditingController searchController = TextEditingController();
  String searchQuery = '';
  String statusFilter =
      'all'; // Changed from sortBy to statusFilter with default 'all'
  String sortBy = 'status'; // Keep sortBy separate from filtering
  bool sortAscending = true;
  String walletFilter = 'all';
  String createdDateFilter = 'all';
  late InstallmentRepository installmentRepository;
  late ClientRepository clientRepository;
  List<Installment> installments = [];
  Map<String, String> clientNames = {};
  Map<String, List<InstallmentPayment>> installmentPayments = {};
  final Map<String, bool> expandedStates =
      {}; // Track expansion state by installment ID
  final Set<String> selectedInstallmentIds = {}; // Track selected installments
  final Set<String> loadingPayments =
      {}; // Track which installments are loading payments
  final Set<String> loadingItemOperations =
      {}; // Track per-item background ops (delete, payment updates)
  bool isLoading = true;
  bool isInitialized = false;
  bool isSelectionMode = false;

  // Available status filters
  static const Map<String, String> statusFilters = {
    'all': 'All',
    'просрочено': 'Overdue',
    'к оплате': 'Due to Pay',
    'предстоящий': 'Upcoming',
    'оплачено': 'Paid',
  };

  late AnimationController fadeController;
  late Animation<double> fadeAnimation;

  @override
  void initState() {
    super.initState();
    fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: fadeController, curve: Curves.easeInOut));

    initializeRepositories();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!isInitialized) {
      loadData();
      isInitialized = true;
    }

    // Check if we need to refresh the data (e.g., coming back from details page)
    try {
      final GoRouterState goState = GoRouterState.of(context);
      if (goState.extra != null && goState.extra is Map<String, dynamic>) {
        final Map<String, dynamic> extra =
            goState.extra as Map<String, dynamic>;
        print('Got navigation extra: $extra');
        if (extra['refresh'] == true) {
          print(
            'Refreshing installments list because refresh parameter was true',
          );
          // Add a small delay to ensure the widget tree is built
          Future.delayed(Duration.zero, () {
            if (mounted) {
              loadData();
            }
          });
        }
      }
    } catch (e) {
      print('Error checking navigation extras: $e');
    }
  }

  @override
  void dispose() {
    searchController.dispose();
    fadeController.dispose();
    super.dispose();
  }

  // Get translated status filter names
  Map<String, String> getTranslatedStatusFilters() {
    final l10n = AppLocalizations.of(context);
    return {
      'all': l10n?.all ?? 'Все',
      'просрочено': l10n?.overdue ?? 'Просрочено',
      'к оплате': l10n?.dueToPay ?? 'К оплате',
      'предстоящий': l10n?.upcoming ?? 'Предстоящий',
      'оплачено': l10n?.paid ?? 'Оплачено',
    };
  }

  Map<String, String> getSortOptions() {
    return {
      'status': 'Статус',
      'installmentNumber': 'Номер',
      'amount': 'Стоимость',
    };
  }

  Map<String, String> getWalletFilterOptions() {
    final l10n = AppLocalizations.of(context);
    final options = <String, String>{
      'all': l10n?.all ?? 'Все',
      'noWallet': l10n?.withoutWallet ?? 'Без кошелька',
    };

    final walletEntries = <String, String>{};
    for (final installment in installments) {
      final walletId = installment.walletId;
      if (walletId == null || walletId.isEmpty) {
        continue;
      }
      final walletName =
          installment is InstallmentModel
              ? (installment.walletName ?? walletId)
              : walletId;
      walletEntries[walletId] = walletName;
    }

    final sortedEntries =
        walletEntries.entries.toList()..sort(
          (a, b) => a.value.toLowerCase().compareTo(b.value.toLowerCase()),
        );

    for (final entry in sortedEntries) {
      options[entry.key] = entry.value;
    }

    return options;
  }

  bool get hasActiveFilters =>
      statusFilter != 'all' ||
      walletFilter != 'all' ||
      createdDateFilter != 'all' ||
      searchQuery.isNotEmpty;

  void resetFilters() {
    setState(() {
      searchQuery = '';
      statusFilter = 'all';
      walletFilter = 'all';
      createdDateFilter = 'all';
      sortBy = 'status';
      sortAscending = true;
    });
    searchController.text = '';
  }

  void setSearchQuery(String value) {
    if (searchQuery == value) {
      // Ensure controller stays in sync when external reset happens.
      if (searchController.text != value) {
        searchController.text = value;
        searchController.selection = TextSelection.fromPosition(
          TextPosition(offset: value.length),
        );
      }
      return;
    }

    setState(() {
      searchQuery = value;
      if (searchController.text != value) {
        searchController.text = value;
        searchController.selection = TextSelection.fromPosition(
          TextPosition(offset: value.length),
        );
      }
    });
  }

  // Set status filter
  void setStatusFilter(String value) {
    setState(() {
      statusFilter = value;
    });
  }

  void setWalletFilter(String value) {
    setState(() {
      walletFilter = value;
    });
  }

  void setCreatedDateFilter(String value) {
    setState(() {
      createdDateFilter = value;
    });
  }

  void setSortBy(String value) {
    setState(() {
      if (sortBy == value) {
        sortAscending = !sortAscending;
      } else {
        sortBy = value;
        // Default direction per sort type
        if (value == 'nextPayment' || value == 'client' || value == 'status' || 
            value == 'installmentNumber' || value == 'dueDate' || value == 'creationDate') {
          sortAscending = true;
        } else {
          sortAscending = false;
        }
      }
    });
  }

  void setSortAscending(bool value) {
    if (sortAscending == value) return;
    setState(() {
      sortAscending = value;
    });
  }

  void initializeRepositories() {
    installmentRepository = InstallmentRepositoryImpl(
      InstallmentRemoteDataSourceImpl(),
    );
    clientRepository = ClientRepositoryImpl(ClientRemoteDataSourceImpl());
  }

  Future<void> loadData() async {
    if (!mounted) return;
    setState(() => isLoading = true);

    // Performance measurement
    final stopwatch = Stopwatch()..start();

    try {
      // Get current user from authentication
      final authService = AuthServiceProvider.of(context);
      final currentUser = await authService.getCurrentUser();

      if (!mounted) return;

      if (currentUser == null) {
        // Redirect to login if not authenticated
        if (mounted) {
          context.go('/auth/login');
        }
        return;
      }

      // Get all installments with pre-calculated fields (single optimized call!)
      final loadedInstallments = await installmentRepository.getAllInstallments(
        currentUser.id,
      );

      if (!mounted) return;

      // Extract pre-calculated data from optimized response
      final clientNames = <String, String>{};
      final paymentsMap = <String, List<InstallmentPayment>>{};

      for (final installment in loadedInstallments) {
        // Client names are now included in the installment data
        if (installment is InstallmentModel && installment.clientName != null) {
          clientNames[installment.clientId] = installment.clientName!;
        }

        // For now, keep payments empty since we have summary data
        // Individual payments will be loaded only when needed (on expand)
        paymentsMap[installment.id] = [];
      }

      setState(() {
        installments = loadedInstallments;
        this.clientNames = clientNames;
        installmentPayments = paymentsMap;
        isLoading = false;
      });

      if (mounted) {
        fadeController.forward();
      }

      // Performance logging
      stopwatch.stop();
      print(
        '🚀 Installments loaded in ${stopwatch.elapsedMilliseconds}ms (${loadedInstallments.length} installments, ${paymentsMap.values.fold(0, (sum, payments) => sum + payments.length)} payments)',
      );
    } catch (e) {
      stopwatch.stop();
      print('Error loading installments data: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
          installments = [];
          this.clientNames = {};
          installmentPayments = {};
        });

        // Show more specific error messages
        String errorMessage;
        if (e.toString().contains('502') ||
            e.toString().contains('Bad Gateway')) {
          errorMessage = 'Сервер временно недоступен. Попробуйте позже.';
        } else if (e.toString().contains('500') ||
            e.toString().contains('ServerException')) {
          errorMessage = 'Ошибка сервера. Попробуйте позже.';
        } else if (e.toString().contains('Network error')) {
          errorMessage = 'Ошибка сети. Проверьте подключение к интернету.';
        } else {
          errorMessage =
              '${AppLocalizations.of(context)?.errorLoadingData ?? 'Ошибка загрузки данных'}: ${e.toString().replaceAll('ApiException: ', '').replaceAll('ServerException: ', '')}';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: AppTheme.errorColor,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> refreshData() async {
    // Refresh without showing loading spinner - use cached data while loading
    try {
      // Get current user from authentication
      final authService = AuthServiceProvider.of(context);
      final currentUser = await authService.getCurrentUser();

      if (currentUser == null) {
        // Redirect to login if not authenticated
        if (mounted) {
          context.go('/auth/login');
        }
        return;
      }

      // Get all installments with pre-calculated fields (single optimized call!)
      final loadedInstallments = await installmentRepository.getAllInstallments(
        currentUser.id,
      );

      // Extract pre-calculated data from optimized response
      final clientNames = <String, String>{};
      final paymentsMap = <String, List<InstallmentPayment>>{};

      for (final installment in loadedInstallments) {
        // Client names are now included in the installment data
        if (installment is InstallmentModel && installment.clientName != null) {
          clientNames[installment.clientId] = installment.clientName!;
        }

        // Keep existing payments if already loaded, otherwise empty
        if (!installmentPayments.containsKey(installment.id)) {
          paymentsMap[installment.id] = [];
        } else {
          paymentsMap[installment.id] = installmentPayments[installment.id]!;
        }
      }

      setState(() {
        installments = loadedInstallments;
        this.clientNames = clientNames;
        installmentPayments = paymentsMap;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${AppLocalizations.of(context)?.errorLoadingData ?? 'Error loading data'}: $e',
            ),
          ),
        );
      }
    }
  }

  /// Load payments for a specific installment (lazy loading)
  Future<void> loadPaymentsForInstallment(String installmentId) async {
    // Set loading state
    setState(() {
      loadingPayments.add(installmentId);
    });

    try {
      final payments = await installmentRepository.getPaymentsByInstallmentId(
        installmentId,
      );
      setState(() {
        installmentPayments[installmentId] = payments;
        loadingPayments.remove(installmentId);
      });
    } catch (e) {
      print('Failed to load payments for installment $installmentId: $e');
      setState(() {
        loadingPayments.remove(installmentId);
      });
      // Don't show error to user for individual payment loading failures
    }
  }

  /// Submit a payment register/delete in background and show item-level spinner
  Future<void> submitPaymentInBackground(
    InstallmentPayment updatedPayment,
  ) async {
    final installmentId = updatedPayment.installmentId;
    if (!mounted) return;
    setState(() {
      loadingItemOperations.add(installmentId);
    });

    try {
      final updatedInstallment = await installmentRepository.updatePayment(
        updatedPayment,
      );
      if (!mounted) return;
      setState(() {
        final index = installments.indexWhere(
          (i) => i.id == updatedInstallment.id,
        );
        if (index != -1) {
          final prev = installments[index];
          final merged = () {
            if (updatedInstallment.installmentNumber != null) {
              return updatedInstallment;
            }
            if (updatedInstallment is InstallmentModel) {
              final u = updatedInstallment;
              return InstallmentModel(
                id: u.id,
                userId: u.userId,
                clientId: u.clientId,
                investorId: u.investorId,
                walletId: u.walletId,
                productName: u.productName,
                cashPrice: u.cashPrice,
                installmentPrice: u.installmentPrice,
                termMonths: u.termMonths,
                downPayment: u.downPayment,
                monthlyPayment: u.monthlyPayment,
                downPaymentDate: u.downPaymentDate,
                installmentStartDate: u.installmentStartDate,
                installmentEndDate: u.installmentEndDate,
                installmentNumber: prev.installmentNumber,
                createdAt: u.createdAt,
                updatedAt: u.updatedAt,
                // optimized fields
                clientName: u.clientName,
                walletName: u.walletName,
                paidAmount: u.paidAmount,
                remainingAmount: u.remainingAmount,
                nextPaymentDate: u.nextPaymentDate,
                nextPaymentAmount: u.nextPaymentAmount,
                paymentStatus: u.paymentStatus,
                overdueCount: u.overdueCount,
                totalPayments: u.totalPayments,
                paidPayments: u.paidPayments,
                lastPaymentDate: u.lastPaymentDate,
              );
            }
            return updatedInstallment.copyWith(
              installmentNumber: prev.installmentNumber,
            );
          }();

          installments[index] = merged;
          // Collapse and clear payments so the user can re-expand to refresh
          expandedStates[merged.id] = false;
          installmentPayments[merged.id] = [];
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${AppLocalizations.of(context)?.error ?? 'Ошибка'}: $e',
            ),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          loadingItemOperations.remove(installmentId);
        });
      }
    }
  }

  List<Installment> get filteredAndSortedInstallments {
    final query = searchQuery.trim().toLowerCase();

    var filtered =
        installments.where((installment) {
          if (query.isEmpty) return true;

          final clientName =
              installment is InstallmentModel
                  ? (installment.clientName?.toLowerCase() ?? '')
                  : '';
          final productName = installment.productName.toLowerCase();

          return clientName.contains(query) || productName.contains(query);
        }).toList();

    if (statusFilter != 'all') {
      filtered =
          filtered.where((installment) {
            final status =
                installment is InstallmentModel
                    ? installment.dynamicStatus
                    : 'предстоящий';
            return status == statusFilter;
          }).toList();
    }

    if (walletFilter == 'noWallet') {
      filtered =
          filtered
              .where(
                (installment) =>
                    installment.walletId == null ||
                    installment.walletId!.isEmpty,
              )
              .toList();
    } else if (walletFilter != 'all') {
      filtered =
          filtered
              .where((installment) => installment.walletId == walletFilter)
              .toList();
    }

    if (createdDateFilter != 'all') {
      filtered =
          filtered
              .where((installment) => _matchesCreatedDateFilter(installment))
              .toList();
    }

    filtered.sort((a, b) {
      final comparison = _compareInstallments(a, b);
      return sortAscending ? comparison : -comparison;
    });

    return filtered;
  }

  InstallmentsListMetrics get metrics =>
      InstallmentsListMetrics.fromInstallments(filteredAndSortedInstallments);

  bool _matchesCreatedDateFilter(Installment installment) {
    final now = DateTime.now();
    final createdDate = installment.createdAt;
    
    switch (createdDateFilter) {
      case 'today':
        return _isSameDay(createdDate, now);
      case 'yesterday':
        final yesterday = now.subtract(const Duration(days: 1));
        return _isSameDay(createdDate, yesterday);
      case 'thisWeek':
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        return createdDate.isAfter(startOfWeek.subtract(const Duration(days: 1)));
      case 'lastWeek':
        final startOfThisWeek = now.subtract(Duration(days: now.weekday - 1));
        final startOfLastWeek = startOfThisWeek.subtract(const Duration(days: 7));
        return createdDate.isAfter(startOfLastWeek.subtract(const Duration(days: 1))) &&
               createdDate.isBefore(startOfThisWeek);
      case 'thisMonth':
        return createdDate.year == now.year && createdDate.month == now.month;
      case 'lastMonth':
        final lastMonth = DateTime(now.year, now.month - 1);
        return createdDate.year == lastMonth.year && createdDate.month == lastMonth.month;
      case 'last3Months':
        final threeMonthsAgo = DateTime(now.year, now.month - 3, now.day);
        return createdDate.isAfter(threeMonthsAgo.subtract(const Duration(days: 1)));
      case 'last6Months':
        final sixMonthsAgo = DateTime(now.year, now.month - 6, now.day);
        return createdDate.isAfter(sixMonthsAgo.subtract(const Duration(days: 1)));
      case 'thisYear':
        return createdDate.year == now.year;
      default:
        return true;
    }
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
           date1.month == date2.month &&
           date1.day == date2.day;
  }

  bool _isInstallmentPaid(Installment installment) {
    if (installment is InstallmentModel) {
      final status = installment.dynamicStatus;
      return status == 'оплачено';
    }
    return false;
  }

  int _compareInstallments(Installment a, Installment b) {
    switch (sortBy) {
      case 'status':
        final statusA = a is InstallmentModel ? a.dynamicStatus : 'предстоящий';
        final statusB = b is InstallmentModel ? b.dynamicStatus : 'предстоящий';
        return _statusPriority(statusA).compareTo(_statusPriority(statusB));
      case 'nextPayment':
        final dateA = _getNextPaymentDate(a);
        final dateB = _getNextPaymentDate(b);
        return dateA.compareTo(dateB);
      case 'amount':
        return a.installmentPrice.compareTo(b.installmentPrice);
      case 'paid':
        return _getPaidAmount(a).compareTo(_getPaidAmount(b));
      case 'remaining':
        return _getRemainingAmount(a).compareTo(_getRemainingAmount(b));
      case 'client':
        final nameA = a is InstallmentModel ? (a.clientName ?? '') : '';
        final nameB = b is InstallmentModel ? (b.clientName ?? '') : '';
        return nameA.toLowerCase().compareTo(nameB.toLowerCase());
      case 'installmentNumber':
        final numberA = a.installmentNumber ?? 0;
        final numberB = b.installmentNumber ?? 0;
        return numberA.compareTo(numberB);
      case 'dueDate':
        final dateA = _getNextPaymentDate(a);
        final dateB = _getNextPaymentDate(b);
        return dateA.compareTo(dateB);
      case 'creationDate':
      default:
        return a.createdAt.compareTo(b.createdAt);
    }
  }

  int _statusPriority(String status) {
    switch (status.toLowerCase()) {
      case 'просрочено':
        return 0;
      case 'к оплате':
        return 1;
      case 'предстоящий':
        return 2;
      case 'оплачено':
        return 3;
      default:
        return 4;
    }
  }

  DateTime _getNextPaymentDate(Installment installment) {
    if (installment is InstallmentModel &&
        installment.nextPaymentDate != null) {
      return installment.nextPaymentDate!;
    }
    return installment.installmentStartDate;
  }

  double _getPaidAmount(Installment installment) {
    if (installment is InstallmentModel) {
      return installment.paidAmount ?? installment.downPayment;
    }
    return installment.downPayment;
  }

  double _getRemainingAmount(Installment installment) {
    if (installment is InstallmentModel) {
      if (installment.remainingAmount != null) {
        return installment.remainingAmount!;
      }
      final paid = installment.paidAmount ?? installment.downPayment;
      return (installment.installmentPrice - paid).clamp(0, double.infinity);
    }
    final remaining = installment.installmentPrice - installment.downPayment;
    return remaining.clamp(0, double.infinity);
  }

  // Selection methods
  void toggleSelection(String installmentId) {
    setState(() {
      if (selectedInstallmentIds.contains(installmentId)) {
        selectedInstallmentIds.remove(installmentId);
        if (selectedInstallmentIds.isEmpty) {
          isSelectionMode = false;
        }
      } else {
        selectedInstallmentIds.add(installmentId);
        isSelectionMode = true;
      }
    });
  }

  // Public setState method for external widgets to call
  void setStateWrapper(VoidCallback fn) {
    setState(fn);
  }

  void selectAll() {
    setState(() {
      selectedInstallmentIds.clear();
      selectedInstallmentIds.addAll(
        filteredAndSortedInstallments.map((i) => i.id),
      );
      isSelectionMode = true;
    });
  }

  void selectAllOverdue() {
    setState(() {
      selectedInstallmentIds.clear();

      // Find all installments with overdue status using dynamic status
      for (final installment in filteredAndSortedInstallments) {
        final status =
            installment is InstallmentModel
                ? installment.dynamicStatus
                : 'предстоящий';

        // Add to selection if status is overdue
        if (status == 'просрочено') {
          selectedInstallmentIds.add(installment.id);
        }
      }

      isSelectionMode = selectedInstallmentIds.isNotEmpty;
    });
  }

  void clearSelection() {
    setState(() {
      selectedInstallmentIds.clear();
      isSelectionMode = false;
    });
  }

  void sendBulkReminders() async {
    if (selectedInstallmentIds.isEmpty) return;

    // Show confirmation dialog
    final confirmed = await _showBulkReminderConfirmationDialog();
    if (!confirmed) return;

    await ReminderService.sendBulkReminders(
      context: context,
      installmentIds: selectedInstallmentIds.toList(),
      templateType: 'manual',
    );

    // Clear selection after sending
    clearSelection();
  }

  Future<void> deleteBulkInstallments() async {
    if (selectedInstallmentIds.isEmpty) return;

    final l10n = AppLocalizations.of(context);

    // Show confirmation dialog
    final confirmed = await showCustomConfirmationDialog(
      context: context,
      title: l10n?.deleteInstallmentTitle ?? 'Delete Installment',
      content:
          selectedInstallmentIds.length == 1
              ? l10n?.deleteInstallmentConfirmation ??
                  'Are you sure you want to delete this installment?'
              : '${l10n?.deleteInstallmentConfirmation ?? 'Are you sure you want to delete these installments?'} (${selectedInstallmentIds.length})',
    );

    if (confirmed != true) return;

    try {
      // Clear cache to ensure fresh data after deletion
      final cache = CacheService();
      final authService = AuthServiceProvider.of(context);
      final currentUser = await authService.getCurrentUser();

      if (currentUser != null) {
        cache.remove(CacheService.installmentsKey(currentUser.id));
        cache.remove(CacheService.analyticsKey(currentUser.id));
      }

      // Show loading indicator (ensure any existing is hidden first)
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              const SizedBox(width: 16),
              Text(l10n?.deleting ?? 'Deleting...'),
            ],
          ),
          duration: const Duration(seconds: 60),
        ),
      );

      // Mark selected as busy
      setState(() {
        loadingItemOperations.addAll(selectedInstallmentIds);
      });

      // Delete all selected installments
      for (final id in selectedInstallmentIds) {
        cache.remove(CacheService.installmentKey(id));
        cache.remove(CacheService.paymentsKey(id));
        await installmentRepository.deleteInstallment(id);
      }

      // Clear the current snackbar
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      // Immediately remove from local state to update UI
      setState(() {
        installments.removeWhere((i) => selectedInstallmentIds.contains(i.id));
        for (final id in selectedInstallmentIds) {
          installmentPayments.remove(id);
          expandedStates.remove(id);
          loadingPayments.remove(id);
          loadingItemOperations.remove(id);
        }
      });

      // Clear selection
      clearSelection();

      // Keep list persistent without full reload

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              selectedInstallmentIds.length == 1
                  ? l10n?.installmentDeleted ?? 'Installment deleted'
                  : l10n?.installmentsDeleted ?? 'Installments deleted',
            ),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l10n?.installmentDeleteError(e) ?? 'Error deleting: $e',
            ),
            backgroundColor: AppTheme.errorColor,
          ),
        );
        // Keep list persistent without full reload
        setState(() {
          loadingItemOperations.removeAll(selectedInstallmentIds);
        });
      }
    } finally {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
      }
    }
  }

  Future<bool> _showBulkReminderConfirmationDialog() async {
    final l10n = AppLocalizations.of(context);

    return await showDialog<bool>(
          context: context,
          builder:
              (context) => AlertDialog(
                title: Text(l10n?.sendWhatsAppReminder ?? 'Send Reminder'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n?.sendReminderConfirmation ??
                          'Are you sure you want to send reminders to the selected installments?',
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: whatsAppColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: whatsAppColor.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: whatsAppColor,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              l10n?.sendReminderInfo ??
                                  'This will send individual messages to each client.',
                              style: TextStyle(
                                color: whatsAppColor,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text(
                      l10n?.cancel ?? 'Cancel',
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: whatsAppColor,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(l10n?.confirm ?? 'Send'),
                  ),
                ],
              ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayout(
      mobile: InstallmentsListScreenMobile(state: this),
      desktop: InstallmentsListScreenDesktop(state: this),
    );
  }

  String getItemsText(int count) {
    final l10n = AppLocalizations.of(context)!;
    if (count % 10 == 1 && count % 100 != 11) {
      return l10n.installment_one;
    } else if ([2, 3, 4].contains(count % 10) &&
        ![12, 13, 14].contains(count % 100)) {
      return l10n.installment_few;
    } else {
      return l10n.installment_many;
    }
  }

  Future<void> deleteInstallment(Installment installment) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showCustomConfirmationDialog(
      context: context,
      title: l10n?.deleteInstallmentTitle ?? 'Удалить рассрочку',
      content:
          l10n?.deleteInstallmentConfirmation ??
          'Вы уверены, что хотите удалить рассрочку?',
    );
    if (confirmed == true) {
      try {
        // Ensure any previous progress snackbar is hidden
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        setState(() {
          loadingItemOperations.add(installment.id);
        });
        // Clear cache to ensure fresh data after deletion
        final cache = CacheService();
        final authService = AuthServiceProvider.of(context);
        final currentUser = await authService.getCurrentUser();

        if (currentUser != null) {
          cache.remove(CacheService.installmentsKey(currentUser.id));
          cache.remove(CacheService.analyticsKey(currentUser.id));
        }
        cache.remove(CacheService.installmentKey(installment.id));
        cache.remove(CacheService.paymentsKey(installment.id));

        // Delete from server
        await installmentRepository.deleteInstallment(installment.id);

        // Immediately remove from local state to update UI
        setState(() {
          installments.removeWhere((i) => i.id == installment.id);
          installmentPayments.remove(installment.id);
          expandedStates.remove(installment.id);
          loadingPayments.remove(installment.id);
        });

        // No full reload; list stays persistent

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n?.installmentDeleted ?? 'Рассрочка удалена'),
              backgroundColor: AppTheme.successColor,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                l10n?.installmentDeleteError(e) ?? 'Ошибка удаления: $e',
              ),
              backgroundColor: AppTheme.errorColor,
            ),
          );
          // Keep list as-is; user can retry
        }
      } finally {
        if (mounted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          setState(() {
            loadingItemOperations.remove(installment.id);
          });
        }
      }
    }
  }

  void showCreateInstallmentDialog() {
    showDialog(
      context: context,
      builder: (context) => CreateInstallmentDialog(onSuccess: loadData),
    );
  }

  // Force a complete refresh by reinitializing all data
  void forceRefresh() {
    if (!mounted) return;

    // Clear data and show loading
    setState(() {
      isLoading = true;
      installments = [];
      clientNames = {};
      installmentPayments = {};
      expandedStates.clear();
      selectedInstallmentIds.clear();
    });

    // First clear the cache to ensure fresh data from API
    final cacheService = CacheService();
    // Get current user to build cache key
    AuthServiceProvider.of(context).getCurrentUser().then((user) {
      if (user != null) {
        // Clear all related caches
        cacheService.clear(); // Clear entire cache to be safe
        print('🔄 Cache cleared for full refresh');

        // Wait a moment before reloading to ensure UI shows loading state
        Future.delayed(Duration(milliseconds: 300), () {
          if (mounted) {
            print('🔄 Force-refreshing installments data from API');
            loadData();
          }
        });
      }
    });
  }
}

class InstallmentsListMetrics {
  final int totalCount;
  final int overdueCount;
  final int dueSoonCount;
  final double totalIssued;
  final double totalPaid;
  final double totalRemaining;

  const InstallmentsListMetrics({
    required this.totalCount,
    required this.overdueCount,
    required this.dueSoonCount,
    required this.totalIssued,
    required this.totalPaid,
    required this.totalRemaining,
  });

  double get collectionRate =>
      totalIssued == 0 ? 0 : (totalPaid / totalIssued).clamp(0.0, 1.0);

  factory InstallmentsListMetrics.fromInstallments(
    List<Installment> installments,
  ) {
    var totalIssued = 0.0;
    var totalPaid = 0.0;
    var totalRemaining = 0.0;
    var overdueCount = 0;
    var dueSoonCount = 0;

    for (final installment in installments) {
      totalIssued += installment.installmentPrice;
      final paid =
          installment is InstallmentModel
              ? (installment.paidAmount ?? installment.downPayment)
              : installment.downPayment;
      final remaining =
          installment is InstallmentModel
              ? (installment.remainingAmount ??
                  (installment.installmentPrice - paid).clamp(
                    0,
                    double.infinity,
                  ))
              : (installment.installmentPrice - installment.downPayment).clamp(
                0,
                double.infinity,
              );

      totalPaid += paid;
      totalRemaining += remaining;

      final status =
          installment is InstallmentModel
              ? installment.dynamicStatus
              : 'предстоящий';
      if (status == 'просрочено') {
        overdueCount++;
      } else if (status == 'к оплате') {
        dueSoonCount++;
      }
    }

    return InstallmentsListMetrics(
      totalCount: installments.length,
      overdueCount: overdueCount,
      dueSoonCount: dueSoonCount,
      totalIssued: totalIssued,
      totalPaid: totalPaid,
      totalRemaining: totalRemaining,
    );
  }
}
