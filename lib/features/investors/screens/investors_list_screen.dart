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
import '../../../shared/widgets/custom_search_bar.dart';
import '../../../shared/widgets/custom_dropdown.dart';
import '../../../shared/widgets/custom_button.dart';
import '../widgets/investor_list_item.dart';
import '../../../shared/widgets/custom_confirmation_dialog.dart';

class InvestorsListScreen extends StatefulWidget {
  const InvestorsListScreen({super.key});

  @override
  State<InvestorsListScreen> createState() => _InvestorsListScreenState();
}

class _InvestorsListScreenState extends State<InvestorsListScreen> with TickerProviderStateMixin {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String? _sortBy = 'creationDate';
  late InvestorRepository _investorRepository;
  List<Investor> _investors = [];
  bool _isLoading = true;
  
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut),
    );
    
    _initializeRepository();
    _loadData();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
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
      
      _fadeController.forward();
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
    if (_sortBy != null) {
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
    }
    
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: Column(
        children: [
          // Enhanced Header with search and sort
          Container(
            padding: const EdgeInsets.fromLTRB(32, 28, 32, 20),
            decoration: const BoxDecoration(
              color: AppTheme.surfaceColor,
            ),
            child: Column(
              children: [
                // Title and Actions Row
                Row(
                  children: [
                    // Title without Icon
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n?.investors ?? 'Инвесторы',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.5,
                          ),
                        ),
                        Text(
                          '${_filteredAndSortedInvestors.length} ${l10n?.investors?.toLowerCase() ?? 'инвесторы'}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    // Enhanced Search field
                    CustomSearchBar(
                      value: _searchQuery,
                      onChanged: (value) => setState(() => _searchQuery = value),
                      hintText: '${l10n?.search ?? 'Поиск'} ${(l10n?.investors ?? 'инвесторы').toLowerCase()}...',
                      width: 320,
                    ),
                    const SizedBox(width: 16),
                    // Enhanced Sort dropdown
                    CustomDropdown<String>(
                      value: _sortBy,
                      width: 200,
                      items: {
                        'creationDate': l10n?.creationDate ?? 'Дата создания',
                        'name': 'Имени',
                        'investment': 'Инвестиции',
                      },
                      onChanged: (value) => setState(() => _sortBy = value),
                    ),
                    const SizedBox(width: 16),
                    // Custom Add button
                    CustomButton(
                      text: l10n?.addInvestor ?? 'Добавить инвестора',
                      onPressed: () => context.go('/investors/add'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Continuous Table Section
          Expanded(
            child: Container(
              color: AppTheme.surfaceColor,
              child: _isLoading
                  ? Center(
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          valueColor: AlwaysStoppedAnimation<Color>(AppTheme.brightPrimaryColor),
                        ),
                      ),
                    )
                  : Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceColor,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.02),
                            offset: const Offset(0, 1),
                            blurRadius: 3,
                            spreadRadius: 0,
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          // Table Header
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                            decoration: BoxDecoration(
                              color: AppTheme.subtleBackgroundColor,
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(12),
                                topRight: Radius.circular(12),
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
                                  flex: 2,
                                  child: Text(
                                    l10n?.fullNameHeader ?? 'ПОЛНОЕ ИМЯ',
                                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                          color: AppTheme.textSecondary,
                                          fontWeight: FontWeight.w400,
                                          fontSize: 12,
                                          letterSpacing: 0.5,
                                        ),
                                  ),
                                ),
                                Expanded(
                                  flex: 1,
                                  child: Padding(
                                    padding: const EdgeInsets.only(right: 20),
                                    child: Text(
                                      l10n?.investmentAmountHeader ?? 'СУММА ИНВЕСТИЦИИ',
                                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                            color: AppTheme.textSecondary,
                                            fontWeight: FontWeight.w400,
                                            fontSize: 12,
                                            letterSpacing: 0.5,
                                          ),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 1,
                                  child: Padding(
                                    padding: const EdgeInsets.only(right: 20),
                                    child: Text(
                                      l10n?.investorShareHeader ?? 'ДОЛЯ ИНВЕСТОРА',
                                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                            color: AppTheme.textSecondary,
                                            fontWeight: FontWeight.w400,
                                            fontSize: 12,
                                            letterSpacing: 0.5,
                                          ),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 1,
                                  child: Padding(
                                    padding: const EdgeInsets.only(right: 20),
                                    child: Text(
                                      l10n?.userShareHeader ?? 'ДОЛЯ ПОЛЬЗОВАТЕЛЯ',
                                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                            color: AppTheme.textSecondary,
                                            fontWeight: FontWeight.w400,
                                            fontSize: 12,
                                            letterSpacing: 0.5,
                                          ),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 1,
                                  child: Text(
                                    l10n?.creationDateHeader ?? 'ДАТА СОЗДАНИЯ',
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
                          ),
                          
                          // Table Content
                          Expanded(
                            child: _filteredAndSortedInvestors.isEmpty
                                ? Center(
                                    child: Text(
                                      l10n?.notFound ?? 'Ничего не найдено',
                                      style: TextStyle(
                                        color: AppTheme.textSecondary,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                  )
                                : ListView.builder(
                                    padding: EdgeInsets.zero,
                                    itemCount: _filteredAndSortedInvestors.length,
                                    itemBuilder: (context, index) {
                                      final investor = _filteredAndSortedInvestors[index];
                                      return InvestorListItem(
                                        investor: investor,
                                        onTap: () => context.go('/investors/${investor.id}'),
                                        onEdit: () => context.go('/investors/${investor.id}/edit'),
                                        onDelete: () => _deleteInvestor(investor),
                                        onSelect: () {
                                          print('Selected investor: \'${investor.fullName}\'');
                                        },
                                      );
                                    },
                                  ),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteInvestor(Investor investor) async {
    final confirmed = await showCustomConfirmationDialog(
      context: context,
      title: AppLocalizations.of(context)!.deleteInvestorTitle,
      content: AppLocalizations.of(context)!.deleteInvestorConfirmation(investor.fullName),
    );

    if (confirmed == true) {
      try {
        await _investorRepository.deleteInvestor(investor.id);
        _loadData();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.investorDeleted)),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.investorDeleteError(e))),
        );
      }
    }
  }
} 