import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../domain/entities/investor.dart';
import '../providers/investor_provider.dart';

class SelectInvestorDialog extends StatefulWidget {
  const SelectInvestorDialog({super.key});

  @override
  State<SelectInvestorDialog> createState() => _SelectInvestorDialogState();
}

class _SelectInvestorDialogState extends State<SelectInvestorDialog> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Investor> _filterInvestors(List<Investor> investors) {
    if (_searchQuery.isEmpty) return investors;
    return investors.where((investor) {
      final searchLower = _searchQuery.toLowerCase();
      return investor.fullName.toLowerCase().contains(searchLower);
    }).toList();
  }

  String _formatCurrency(double amount) {
    return amount.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Text(
                  'Выберите инвестора',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Поиск инвестора...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Consumer<InvestorProvider>(
              builder: (context, investorProvider, child) {
                final filteredInvestors = _filterInvestors(investorProvider.investors);
                return SizedBox(
                  height: 300,
                  child: ListView.builder(
                    itemCount: filteredInvestors.length,
                    itemBuilder: (context, index) {
                      final investor = filteredInvestors[index];
                      return ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.business),
                        ),
                        title: Text(investor.fullName),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${_formatCurrency(investor.investmentAmount)} сум'),
                            Text(
                              '${investor.investorPercentage}% / ${investor.userPercentage}%',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                        isThreeLine: true,
                        onTap: () => Navigator.of(context).pop(investor),
                      );
                    },
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
} 