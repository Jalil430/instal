import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/themes/app_theme.dart';
import '../providers/investor_provider.dart';
import '../screens/add_investor_screen.dart';
import '../screens/investor_details_screen.dart';
import '../widgets/investor_list_item.dart';

class InvestorsPage extends StatefulWidget {
  const InvestorsPage({super.key});

  @override
  State<InvestorsPage> createState() => _InvestorsPageState();
}

class _InvestorsPageState extends State<InvestorsPage> {
  final TextEditingController _searchController = TextEditingController();
  InvestorSortOption _currentSortOption = InvestorSortOption.createdDateNewest;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInvestors();
    });
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _loadInvestors() {
    final investorProvider = Provider.of<InvestorProvider>(context, listen: false);
    investorProvider.loadInvestors('user_1'); // TODO: Replace with actual user ID
  }

  void _onSearchChanged() {
    final investorProvider = Provider.of<InvestorProvider>(context, listen: false);
    investorProvider.searchInvestors('user_1', _searchController.text);
  }

  void _onSortChanged(InvestorSortOption? option) {
    if (option != null) {
      setState(() {
        _currentSortOption = option;
      });
      final investorProvider = Provider.of<InvestorProvider>(context, listen: false);
      investorProvider.sortInvestors(option);
    }
  }

  void _navigateToAddInvestor() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const AddInvestorScreen(),
      ),
    ).then((_) {
      // Refresh investors list when returning from add investor screen
      _loadInvestors();
    });
  }
  
  void _navigateToInvestorDetails(String investorId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => InvestorDetailsScreen(
          investorId: investorId,
        ),
      ),
    ).then((_) {
      // Refresh investors list when returning from details screen
      _loadInvestors();
    });
  }
  
  void _navigateToEditInvestor(String investorId) {
    final investor = Provider.of<InvestorProvider>(context, listen: false)
        .investors
        .firstWhere((investor) => investor.id == investorId);
        
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => AddInvestorScreen(
          initialInvestor: investor,
        ),
      ),
    ).then((_) {
      // Refresh investors list when returning from edit screen
      _loadInvestors();
    });
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
                  'Инвесторы',
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                const Spacer(),
                SizedBox(
                  width: 400,
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: 'Поиск инвесторов...',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Sort Dropdown
                DropdownButton<InvestorSortOption>(
                  value: _currentSortOption,
                  onChanged: _onSortChanged,
                  items: const [
                    DropdownMenuItem(
                      value: InvestorSortOption.nameAZ,
                      child: Text('Имя А-Я'),
                    ),
                    DropdownMenuItem(
                      value: InvestorSortOption.nameZA,
                      child: Text('Имя Я-А'),
                    ),
                    DropdownMenuItem(
                      value: InvestorSortOption.createdDateNewest,
                      child: Text('Новые'),
                    ),
                    DropdownMenuItem(
                      value: InvestorSortOption.createdDateOldest,
                      child: Text('Старые'),
                    ),
                    DropdownMenuItem(
                      value: InvestorSortOption.investmentAmountHighest,
                      child: Text('Сумма ↓'),
                    ),
                    DropdownMenuItem(
                      value: InvestorSortOption.investmentAmountLowest,
                      child: Text('Сумма ↑'),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: _navigateToAddInvestor,
                  icon: const Icon(Icons.add, size: 20),
                  label: const Text('Добавить инвестора'),
                ),
              ],
            ),
          ),
          
          // Content Area
          Expanded(
            child: Container(
              color: AppTheme.backgroundColor,
              child: Consumer<InvestorProvider>(
                builder: (context, investorProvider, child) {
                  if (investorProvider.isLoading) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  if (investorProvider.error != null) {
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
                            investorProvider.error!,
                            style: Theme.of(context).textTheme.bodyMedium,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _loadInvestors,
                            child: const Text('Повторить'),
                          ),
                        ],
                      ),
                    );
                  }

                  if (!investorProvider.hasInvestors) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.business_outlined,
                            size: 64,
                            color: AppTheme.textTertiary,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Инвесторы не найдены',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Добавьте первого инвестора для создания рассрочек',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: _navigateToAddInvestor,
                            icon: const Icon(Icons.add),
                            label: const Text('Добавить инвестора'),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(24),
                    itemCount: investorProvider.investors.length,
                    itemBuilder: (context, index) {
                      final investor = investorProvider.investors[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: InvestorListItem(
                          investor: investor,
                          onTap: () {
                            _navigateToInvestorDetails(investor.id);
                          },
                          onEdit: () {
                            _navigateToEditInvestor(investor.id);
                          },
                          onDelete: () {
                            _showDeleteConfirmation(investor.id);
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

  void _showDeleteConfirmation(String investorId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить инвестора'),
        content: const Text('Вы уверены, что хотите удалить этого инвестора?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              final investorProvider = Provider.of<InvestorProvider>(context, listen: false);
              investorProvider.deleteInvestor(investorId, 'user_1');
            },
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
  }
} 