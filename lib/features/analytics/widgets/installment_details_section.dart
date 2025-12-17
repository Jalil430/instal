import 'package:flutter/material.dart';
import 'package:instal_app/features/analytics/domain/entities/analytics_data.dart';
import 'package:instal_app/features/analytics/widgets/detail_row.dart';
import 'package:intl/intl.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/analytics_card.dart';

class InstallmentDetailsSection extends StatelessWidget {
  final InstallmentDetailsData data;
  final String? walletLabel;
  final bool isLoading;

  const InstallmentDetailsSection({
    super.key,
    required this.data,
    this.walletLabel,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final currencyFormatter = NumberFormat.currency(
      locale: 'ru_RU',
      symbol: '₽',
      decimalDigits: 0,
    );

    return AnalyticsCard(
      title: l10n.portfolioDetails,
      child:
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : LayoutBuilder(
                builder: (context, constraints) {
                  final isSmallScreen = constraints.maxWidth < 400;

                  return Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const SizedBox(height: 1),
                      DetailRow(
                        label: l10n.activeInstallments,
                        value: data.activeInstallments.toString(),
                        isCompact: isSmallScreen,
                      ),
                      DetailRow(
                        label: l10n.totalInstallmentValue,
                        value: currencyFormatter.format(
                          data.totalInstallmentValue,
                        ),
                        isCompact: isSmallScreen,
                      ),
                      DetailRow(
                        label: l10n.totalCashPrice,
                        value: currencyFormatter.format(data.totalCashPrice),
                        isCompact: isSmallScreen,
                      ),
                      DetailRow(
                        label: l10n.totalOverdue,
                        value: currencyFormatter.format(data.totalOverdue),
                        isCompact: isSmallScreen,
                      ),
                      DetailRow(
                        label: l10n.averageInstallmentValue,
                        value: currencyFormatter.format(
                          data.averageInstallmentValue,
                        ),
                        isCompact: isSmallScreen,
                      ),
                      DetailRow(
                        label: l10n.averageTerm,
                        value:
                            '${data.averageTerm.toStringAsFixed(1)} ${l10n.months}',
                        isCompact: isSmallScreen,
                      ),
                    ],
                  );
                },
              ),
    );
  }
}
