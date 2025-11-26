import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:instal_app/core/theme/app_theme.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../shared/widgets/analytics_card.dart';
import '../domain/entities/analytics_data.dart';

class ProfitAnalyticsSection extends StatelessWidget {
  final ProfitAnalyticsData data;
  final String walletLabel;
  final bool isLoading;

  const ProfitAnalyticsSection({
    super.key,
    required this.data,
    required this.walletLabel,
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

    final metrics = [
      _ProfitMetric(
        label: l10n.profitEarnedToDate,
        value: data.profitEarnedToDate,
      ),
      _ProfitMetric(label: l10n.profitOverdue, value: data.profitOverdue),
      _ProfitMetric(label: l10n.profitNext30Days, value: data.profitNext30Days),
      _ProfitMetric(label: l10n.profitNext90Days, value: data.profitNext90Days),
      _ProfitMetric(
        label: l10n.profitNext365Days,
        value: data.profitNext365Days,
      ),
      _ProfitMetric(
        label: l10n.totalRemainingProfit,
        value: data.totalRemainingProfit,
      ),
    ];

    final content =
        isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children:
                      metrics.map((metric) {
                        return _ProfitSummaryTile(
                          label: metric.label,
                          value: currencyFormatter.format(metric.value),
                        );
                      }).toList(),
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.upcomingProfitPayments,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child:
                      data.upcomingPayments.isEmpty
                          ? Center(
                            child: Text(
                              l10n.noUpcomingPayments,
                              style: const TextStyle(
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          )
                          : ListView.separated(
                            physics: const BouncingScrollPhysics(),
                            itemCount: data.upcomingPayments.length,
                            separatorBuilder:
                                (_, __) => Divider(
                                  color: AppTheme.subtleBorderColor,
                                  height: 12,
                                ),
                            itemBuilder: (context, index) {
                              final payment = data.upcomingPayments[index];
                              return _UpcomingPaymentTile(
                                payment: payment,
                                currencyFormatter: currencyFormatter,
                                l10n: l10n,
                              );
                            },
                          ),
                ),
              ],
            );

    return AnalyticsCard(
      title: l10n.profitAnalytics,
      header: Text(
        walletLabel,
        style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
      ),
      child: content,
    );
  }
}

class _ProfitMetric {
  final String label;
  final double value;

  _ProfitMetric({required this.label, required this.value});
}

class _ProfitSummaryTile extends StatelessWidget {
  final String label;
  final String value;

  const _ProfitSummaryTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 140, maxWidth: 220),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.subtleBackgroundColor,
          borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
          border: Border.all(color: AppTheme.subtleBorderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class _UpcomingPaymentTile extends StatelessWidget {
  final PaymentProfitItem payment;
  final NumberFormat currencyFormatter;
  final AppLocalizations l10n;

  const _UpcomingPaymentTile({
    required this.payment,
    required this.currencyFormatter,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    final dueDate =
        payment.dueDate != null
            ? DateFormat(
              'd MMM',
              l10n.locale.languageCode,
            ).format(payment.dueDate!)
            : '—';
    final subtitle = [
      if (payment.productName != null && payment.productName!.isNotEmpty)
        payment.productName!,
      '${l10n.paymentAmountLabel}: ${currencyFormatter.format(payment.paymentAmount)}',
    ].join(' · ');

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 80,
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.subtleBackgroundColor,
            borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
          ),
          child: Column(
            children: [
              Text(
                dueDate,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              Text(
                payment.paymentNumber != null
                    ? '#${payment.paymentNumber}'
                    : '',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                payment.clientName ?? '-',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              l10n.paymentProfitLabel,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
            Text(
              currencyFormatter.format(payment.profitAmount),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.successColor,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
