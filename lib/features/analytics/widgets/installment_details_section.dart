import 'package:flutter/material.dart';
import 'package:instal_app/features/analytics/domain/entities/analytics_data.dart';
import 'package:instal_app/features/analytics/widgets/detail_row.dart';
import 'package:intl/intl.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../shared/widgets/analytics_card.dart';

class InstallmentDetailsSection extends StatelessWidget {
  final InstallmentDetailsData data;

  const InstallmentDetailsSection({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final currencyFormatter =
        NumberFormat.currency(locale: 'ru_RU', symbol: '₽', decimalDigits: 2);
    return AnalyticsCard(
      title: l10n.portfolioDetails,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          DetailRow(label: l10n.activeInstallments, value: data.activeInstallments.toString()),
          DetailRow(label: l10n.overdueInstallments, value: data.overdueInstallments.toString()),
          DetailRow(label: l10n.averageInstallmentValue, value: currencyFormatter.format(data.averageInstallmentValue)),
          DetailRow(label: l10n.averageTerm, value: '${data.averageTerm.toStringAsFixed(1)} ${l10n.months}'),
          DetailRow(label: l10n.topProduct, value: data.topProduct),
          DetailRow(
              label: l10n.upcomingRevenue30Days, value: currencyFormatter.format(data.upcomingRevenue30Days)),
        ],
      ),
    );
  }
} 