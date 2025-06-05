import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/localization/app_localizations.dart';
import '../domain/entities/investor.dart';
import '../domain/repositories/investor_repository.dart';
import '../data/repositories/investor_repository_impl.dart';
import '../data/datasources/investor_local_datasource.dart';
import '../../../shared/database/database_helper.dart';

class InvestorsListScreen extends StatefulWidget {
  const InvestorsListScreen({super.key});

  @override
  State<InvestorsListScreen> createState() => _InvestorsListScreenState();
}

class _InvestorsListScreenState extends State<InvestorsListScreen> {
  String _searchQuery = '';
  String _sortBy = 'creationDate';
  late InvestorRepository _investorRepository;
  List<Investor> _investors = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeRepository();
    _loadData();
  }

  void _initializeRepository() {
    final db = DatabaseHelper.instance;
    _investorRepository = InvestorRepositoryImpl(
      InvestorLocalDataSourceImpl(db),
    );
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      // TODO: Replace with actual user ID from auth
      const userId = 'user123';
      
      final investors = await _investorRepository.getAllInvestors(userId);
      
      setState(() {
        _investors = investors;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      print('Error loading data: $e');
    }
  }

  List<Investor> get _filteredAndSortedInvestors {
    var filtered = _investors.where((investor) {
      if (_searchQuery.isEmpty) return true;
      
      final fullName = investor.fullName.toLowerCase();
      final query = _searchQuery.toLowerCase();
      
      return fullName.contains(query);
    }).toList();
    
    // Sort
    switch (_sortBy) {
      case 'name':
        filtered.sort((a, b) => a.fullName.compareTo(b.fullName));
        break;
      case 'investment':
        filtered.sort((a, b) => b.investmentAmount.compareTo(a.investmentAmount));
        break;
      case 'creationDate':
      default:
        filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }
    
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final currencyFormat = NumberFormat.currency(
      locale: 'ru_RU',
      symbol: '₽',
      decimalDigits: 0,
    );

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Column(
        children: [
          // Header with search and sort
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
            child: Column(
              children: [
                Row(
                  children: [
                    Text(
                      l10n?.investors ?? 'Инвесторы',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const Spacer(),
                    // Search field
                    SizedBox(
                      width: 300,
                      height: 40,
                      child: TextField(
                        onChanged: (value) => setState(() => _searchQuery = value),
                        decoration: InputDecoration(
                          hintText: '${l10n?.search ?? 'Поиск'} ${(l10n?.investors ?? 'инвесторы').toLowerCase()}...',
                          prefixIcon: const Icon(Icons.search, size: 20),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: AppTheme.borderColor),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Sort dropdown
                    Container(
                      height: 40,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppTheme.borderColor),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButton<String>(
                        value: _sortBy,
                        underline: const SizedBox(),
                        icon: const Icon(Icons.arrow_drop_down),
                        items: {
                          'creationDate': l10n?.creationDate ?? 'Дате создания',
                          'name': 'Имени',
                          'investment': 'Инвестиции',
                        }.entries.map((entry) {
                          return DropdownMenuItem(
                            value: entry.key,
                            child: Text(entry.value),
                          );
                        }).toList(),
                        onChanged: (value) => setState(() => _sortBy = value!),
                      ),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton.icon(
                      onPressed: () => context.go('/investors/add'),
                      icon: const Icon(Icons.add),
                      label: Text(l10n?.addInvestor ?? 'Добавить инвестора'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Table Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
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
                Expanded(
                  flex: 3,
                  child: Text(
                    'Полное имя',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Сумма инвестиции',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Доля инвестора',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Доля пользователя',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Дата создания',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                  ),
                ),
                const SizedBox(width: 100), // Space for actions
              ],
            ),
          ),
          // List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredAndSortedInvestors.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.account_balance_wallet_outlined,
                              size: 64,
                              color: AppTheme.textSecondary.withOpacity(0.5),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Нет инвесторов',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    color: AppTheme.textSecondary,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            ElevatedButton.icon(
                              onPressed: () => context.go('/investors/add'),
                              icon: const Icon(Icons.add),
                              label: const Text('Добавить первого инвестора'),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 24),
                        itemCount: _filteredAndSortedInvestors.length,
                        itemBuilder: (context, index) {
                          final investor = _filteredAndSortedInvestors[index];
                          final dateFormat = DateFormat('dd.MM.yyyy');
                          
                          return _InvestorListItem(
                            investor: investor,
                            currencyFormat: currencyFormat,
                            dateFormat: dateFormat,
                            onTap: () => context.go('/investors/${investor.id}'),
                            onEdit: () => context.go('/investors/${investor.id}/edit'),
                            onDelete: () => _deleteInvestor(investor),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteInvestor(Investor investor) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить инвестора'),
        content: Text('Вы уверены, что хотите удалить инвестора "${investor.fullName}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _investorRepository.deleteInvestor(investor.id);
        _loadData();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Инвестор удален')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка удаления: $e')),
        );
      }
    }
  }
}

class _InvestorListItem extends StatefulWidget {
  final Investor investor;
  final NumberFormat currencyFormat;
  final DateFormat dateFormat;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _InvestorListItem({
    required this.investor,
    required this.currencyFormat,
    required this.dateFormat,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_InvestorListItem> createState() => _InvestorListItemState();
}

class _InvestorListItemState extends State<_InvestorListItem> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
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
                // Full Name
                Expanded(
                  flex: 3,
                  child: Text(
                    widget.investor.fullName,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                ),
                // Investment Amount
                Expanded(
                  flex: 2,
                  child: Text(
                    widget.currencyFormat.format(widget.investor.investmentAmount),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                ),
                // Investor Percentage
                Expanded(
                  child: Text(
                    '${widget.investor.investorPercentage.toStringAsFixed(1)}%',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                // User Percentage
                Expanded(
                  child: Text(
                    '${widget.investor.userPercentage.toStringAsFixed(1)}%',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                // Created Date
                Expanded(
                  child: Text(
                    widget.dateFormat.format(widget.investor.createdAt),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                  ),
                ),
                // Actions
                SizedBox(
                  width: 100,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      IconButton(
                        onPressed: widget.onEdit,
                        icon: const Icon(Icons.edit, size: 20),
                        tooltip: 'Редактировать',
                      ),
                      IconButton(
                        onPressed: widget.onDelete,
                        icon: const Icon(Icons.delete, size: 20),
                        tooltip: 'Удалить',
                        color: AppTheme.errorColor,
                      ),
                    ],
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