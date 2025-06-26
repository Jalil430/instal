import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/themes/app_theme.dart';
import '../providers/installment_provider.dart';
import '../screens/add_installment_screen.dart';
import '../screens/installment_details_screen.dart';
import '../widgets/installment_list_item.dart';

class InstallmentsPage extends StatefulWidget {
  const InstallmentsPage({super.key});

  @override
  State<InstallmentsPage> createState() => _InstallmentsPageState();
}

class _InstallmentsPageState extends State<InstallmentsPage> {
  final TextEditingController _searchController = TextEditingController();
  InstallmentSortOption _currentSortOption = InstallmentSortOption.createdDateNewest;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInstallments();
    });
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _loadInstallments() {
    final installmentProvider = Provider.of<InstallmentProvider>(context, listen: false);
    installmentProvider.loadInstallments('user_1'); // TODO: Replace with actual user ID
  }

  void _onSearchChanged() {
    final installmentProvider = Provider.of<InstallmentProvider>(context, listen: false);
    installmentProvider.searchInstallments('user_1', _searchController.text);
  }

  void _onSortChanged(InstallmentSortOption? option) {
    if (option != null) {
      setState(() {
        _currentSortOption = option;
      });
      final installmentProvider = Provider.of<InstallmentProvider>(context, listen: false);
      installmentProvider.sortInstallments(option);
    }
  }

  void _navigateToAddInstallment() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const AddInstallmentScreen(),
      ),
    ).then((_) {
      // Refresh installments list when returning from add installment screen
      _loadInstallments();
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
      // Refresh installments list when returning from details screen
      _loadInstallments();
    });
  }
  
  void _showRegisterPaymentDialog(String installmentId) {
    // Navigate to details screen and open payment dialog
    _navigateToInstallmentDetails(installmentId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Column(
        children: [
          // Top Bar
          Container(
            height: 72,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: const BoxDecoration(
              color: AppTheme.surfaceColor,
              border: Border(
                bottom: BorderSide(
                  color: AppTheme.dividerColor,
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Text(
                  'Рассрочки',
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                const Spacer(),
                SizedBox(
                  width: 400,
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: 'Поиск по клиенту или продукту...',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Sort Dropdown
                DropdownButton<InstallmentSortOption>(
                  value: _currentSortOption,
                  onChanged: _onSortChanged,
                  items: const [
                    DropdownMenuItem(
                      value: InstallmentSortOption.createdDateNewest,
                      child: Text('Новые'),
                    ),
                    DropdownMenuItem(
                      value: InstallmentSortOption.createdDateOldest,
                      child: Text('Старые'),
                    ),
                    DropdownMenuItem(
                      value: InstallmentSortOption.amountHighest,
                      child: Text('Сумма ↓'),
                    ),
                    DropdownMenuItem(
                      value: InstallmentSortOption.amountLowest,
                      child: Text('Сумма ↑'),
                    ),
                    DropdownMenuItem(
                      value: InstallmentSortOption.statusPaid,
                      child: Text('Оплачено'),
                    ),
                    DropdownMenuItem(
                      value: InstallmentSortOption.statusOverdue,
                      child: Text('Просрочено'),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: _navigateToAddInstallment,
                  icon: const Icon(Icons.add, size: 20),
                  label: const Text('Добавить рассрочку'),
                ),
              ],
            ),
          ),
          
          // Content Area
          Expanded(
            child: Container(
              color: AppTheme.backgroundColor,
              child: Consumer<InstallmentProvider>(
                builder: (context, installmentProvider, child) {
                  if (installmentProvider.isLoading) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  if (installmentProvider.error != null) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 64,
                            color: AppTheme.textTertiary,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Ошибка загрузки',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            installmentProvider.error!,
                            style: Theme.of(context).textTheme.bodyMedium,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _loadInstallments,
                            child: const Text('Повторить'),
                          ),
                        ],
                      ),
                    );
                  }

                  if (!installmentProvider.hasInstallments) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.receipt_long_outlined,
                            size: 64,
                            color: AppTheme.textTertiary,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Рассрочки не найдены',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Добавьте первую рассрочку, чтобы начать отслеживание',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: _navigateToAddInstallment,
                            icon: const Icon(Icons.add),
                            label: const Text('Добавить рассрочку'),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(24),
                    itemCount: installmentProvider.installments.length,
                    itemBuilder: (context, index) {
                      final installment = installmentProvider.installments[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: InstallmentListItem(
                          installment: installment,
                          onTap: () {
                            _navigateToInstallmentDetails(installment.id);
                          },
                          onEdit: () {
                            // TODO: Navigate to edit installment
                          },
                          onDelete: () {
                            _showDeleteConfirmation(installment.id);
                          },
                          onRegisterPayment: () {
                            _showRegisterPaymentDialog(installment.id);
                          },
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(String installmentId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить рассрочку'),
        content: const Text('Вы уверены, что хотите удалить эту рассрочку? Все связанные платежи также будут удалены.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              final installmentProvider = Provider.of<InstallmentProvider>(context, listen: false);
              installmentProvider.deleteInstallment(installmentId, 'user_1');
            },
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
  }
} 