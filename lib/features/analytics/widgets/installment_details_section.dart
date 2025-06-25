import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/analytics_card.dart';
import '../../../core/localization/app_localizations.dart';

class InstallmentDetailsSection extends StatelessWidget {
  const InstallmentDetailsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AnalyticsCard(
      title: l10n.details,
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        children: [
          _DetailRow(label: l10n.activeInstallments, value: '128'),
          _DetailRow(label: l10n.overdueInstallments, value: '15'),
          _DetailRow(label: l10n.averageInstallmentAmount, value: '\$450.75'),
          _DetailRow(label: l10n.totalPortfolio, value: '\$57,696.00'),
          _DetailRow(label: l10n.averageOverdueDays, value: '22 days'),
          _DetailRow(label: l10n.mostCommonProduct, value: 'iPhone 15 Pro'),
          _DetailRow(label: l10n.highestRiskClient, value: 'A. Volkov'),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w400,

            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
} 