import 'package:fluent_ui/fluent_ui.dart';
import 'package:intl/intl.dart';
import '../../models/investor.dart';
import '../../services/database_service.dart';
import '../../utils/theme.dart';
import 'investor_details_screen.dart';
import 'add_edit_investor_screen.dart';

class InvestorsScreen extends StatefulWidget {
  const InvestorsScreen({super.key});

  @override
  State<InvestorsScreen> createState() => _InvestorsScreenState();
}

class _InvestorsScreenState extends State<InvestorsScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Investor> _investors = [];
  List<Investor> _filteredInvestors = [];
  String _sortBy = 'creationDate';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInvestors();
    _searchController.addListener(_filterInvestors);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInvestors() async {
    setState(() => _isLoading = true);

    try {
      final investors = await DatabaseService.getInvestors();
      setState(() {
        _investors = investors;
        _filteredInvestors = investors;
        _isLoading = false;
      });
      _sortInvestors();
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => ContentDialog(
            title: const Text('Error'),
            content: Text('Failed to load investors: $e'),
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

  void _filterInvestors() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredInvestors = _investors.where((investor) {
        return investor.fullName.toLowerCase().contains(query);
      }).toList();
      _sortInvestors();
    });
  }

  void _sortInvestors() {
    setState(() {
      switch (_sortBy) {
        case 'creationDate':
          _filteredInvestors.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          break;
        case 'name':
          _filteredInvestors.sort((a, b) => a.fullName.compareTo(b.fullName));
          break;
        case 'investment':
          _filteredInvestors.sort((a, b) => b.investmentAmount.compareTo(a.investmentAmount));
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 2);

    return ScaffoldPage(
      header: Container(
        height: 60,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          border: Border(
            bottom: BorderSide(color: AppTheme.borderColor, width: 1),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextBox(
                controller: _searchController,
                placeholder: 'Search investors...',
                prefix: const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: Icon(FluentIcons.search),
                ),
              ),
            ),
            const SizedBox(width: 12),
            ComboBox<String>(
              value: _sortBy,
              items: const [
                ComboBoxItem(value: 'creationDate', child: Text('Creation Date')),
                ComboBoxItem(value: 'name', child: Text('A-Z')),
                ComboBoxItem(value: 'investment', child: Text('Investment Amount')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _sortBy = value);
                  _sortInvestors();
                }
              },
            ),
            const SizedBox(width: 12),
            FilledButton(
              child: const Text('Add Investor'),
              onPressed: () async {
                await Navigator.push(
                  context,
                  FluentPageRoute(
                    builder: (context) => const AddEditInvestorScreen(),
                  ),
                );
                _loadInvestors();
              },
            ),
          ],
        ),
      ),
      content: _isLoading
          ? const Center(child: ProgressRing())
          : _filteredInvestors.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        FluentIcons.money,
                        size: 64,
                        color: AppTheme.textSecondaryColor,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No investors found',
                        style: AppTheme.subtitleStyle,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Add your first investor to get started',
                        style: AppTheme.captionStyle,
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: _filteredInvestors.length,
                  itemBuilder: (context, index) {
                    final investor = _filteredInvestors[index];
                    return _InvestorListItem(
                      investor: investor,
                      onTap: () async {
                        await Navigator.push(
                          context,
                          FluentPageRoute(
                            builder: (context) => InvestorDetailsScreen(
                              investorId: investor.id,
                            ),
                          ),
                        );
                        _loadInvestors();
                      },
                      onEdit: () async {
                        await Navigator.push(
                          context,
                          FluentPageRoute(
                            builder: (context) => AddEditInvestorScreen(
                              investor: investor,
                            ),
                          ),
                        );
                        _loadInvestors();
                      },
                      onDelete: () async {
                        final result = await showDialog<bool>(
                          context: context,
                          builder: (context) => ContentDialog(
                            title: const Text('Delete Investor'),
                            content: const Text(
                              'Are you sure you want to delete this investor? This action cannot be undone.',
                            ),
                            actions: [
                              Button(
                                child: const Text('Cancel'),
                                onPressed: () => Navigator.of(context).pop(false),
                              ),
                              FilledButton(
                                child: const Text('Delete'),
                                onPressed: () => Navigator.of(context).pop(true),
                              ),
                            ],
                          ),
                        );

                        if (result == true) {
                          await DatabaseService.deleteInvestor(investor.id);
                          _loadInvestors();
                        }
                      },
                    );
                  },
                ),
    );
  }
}

class _InvestorListItem extends StatelessWidget {
  final Investor investor;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _InvestorListItem({
    required this.investor,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 2);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: AppTheme.cardDecoration,
      child: GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.successColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(
                    FluentIcons.money,
                    size: 24,
                    color: AppTheme.successColor,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      investor.fullName,
                      style: AppTheme.subtitleStyle,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          currencyFormat.format(investor.investmentAmount),
                          style: AppTheme.bodyStyle.copyWith(
                            fontWeight: FontWeight.w600,
                            color: AppTheme.successColor,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${investor.investorPercentage}% / ${investor.userPercentage}%',
                            style: AppTheme.captionStyle.copyWith(
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(FluentIcons.edit),
                onPressed: onEdit,
              ),
              IconButton(
                icon: const Icon(FluentIcons.delete),
                onPressed: onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }
} 