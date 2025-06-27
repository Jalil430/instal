import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:instal_app/features/analytics/domain/entities/analytics_data.dart';
import 'package:intl/intl.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/analytics_card.dart';
import 'dart:math';

class TotalSalesSection extends StatelessWidget {
  final TotalSalesData data;

  const TotalSalesSection({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final currencyFormatter =
        NumberFormat.currency(locale: 'ru_RU', symbol: '₽');
    final chartData = data.weeklySales;
    final averageSales = data.averageSales;

    return AnalyticsCard(
      title: l10n.paymentsThisWeek,
      header: _buildHeader(l10n, currencyFormatter, averageSales, data.percentageChange),
      child: SizedBox(
        height: 300,
        child: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: BarChart(
            BarChartData(
              maxY: chartData.reduce(max) * 1.2,
              barTouchData: _barTouchData(currencyFormatter),
              titlesData: _titlesData(l10n),
              borderData: FlBorderData(show: false),
              gridData: const FlGridData(show: false),
              alignment: BarChartAlignment.spaceAround,
              barGroups: _barGroups(chartData),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(AppLocalizations l10n, NumberFormat currencyFormatter,
      double averageSales, double? percentageChange) {
    final hasChange = percentageChange != null;
    final isPositive = hasChange && percentageChange! >= 0;
    final changeText = hasChange
        ? '${percentageChange.toStringAsFixed(1)}%'
        : '— %';
    final color = hasChange
        ? (isPositive ? AppTheme.successColor : AppTheme.errorColor)
        : AppTheme.textSecondary;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              '${l10n.averagePerDay}: ',
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondary,
              ),
            ),
            Text(
              currencyFormatter.format(averageSales),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(width: 8),
        Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (hasChange)
                Icon(
                  isPositive ? Icons.arrow_upward : Icons.arrow_downward,
                  color: color,
                  size: 14,
                ),
              const SizedBox(width: 4),
              Text(
                changeText,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  BarTouchData _barTouchData(NumberFormat currencyFormatter) => BarTouchData(
        touchTooltipData: BarTouchTooltipData(
          getTooltipColor: (group) => AppTheme.sidebarBackground,
          tooltipRoundedRadius: 8,
          tooltipPadding: const EdgeInsets.fromLTRB(10, 6, 10, 2),
          tooltipMargin: 8,
          getTooltipItem: (group, groupIndex, rod, rodIndex) {
            return BarTooltipItem(
              currencyFormatter.format(rod.toY),
              const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w400,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            );
          },
        ),
      );

  FlTitlesData _titlesData(AppLocalizations l10n) => FlTitlesData(
        show: true,
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 30,
            getTitlesWidget: (value, meta) =>
                _bottomTitles(value, meta, l10n),
          ),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 40,
            getTitlesWidget: (value, meta) => _leftTitles(value, meta, l10n),
          ),
        ),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles:
            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      );

  List<BarChartGroupData> _barGroups(List<double> chartData) {
    final currentDayIndex = DateTime.now().weekday - 1;
    return List.generate(7, (index) {
      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: chartData[index],
            color: index == currentDayIndex
                ? AppTheme.primaryColor
                : AppTheme.primaryColor.withOpacity(0.3),
            width: 16,
            borderRadius: BorderRadius.circular(8),
          )
        ],
      );
    });
  }

  Widget _leftTitles(double value, TitleMeta meta, AppLocalizations l10n) {
    if (value == meta.max) return Container();

    final isRussian = l10n.locale.languageCode == 'ru';
    final thousandsSuffix = isRussian ? 'т' : 'k';

    String text;
    if (value == 0) {
      text = '0';
    } else if (value >= 1000) {
      text = '${(value / 1000).toStringAsFixed(0)}$thousandsSuffix';
    } else {
      return Container();
    }
    return SideTitleWidget(
      axisSide: meta.axisSide,
      space: 10,
      child: Text(text,
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 12,
          )),
    );
  }

  Widget _bottomTitles(
      double value, TitleMeta meta, AppLocalizations l10n) {
    final titles = [
      l10n.dayMon,
      l10n.dayTue,
      l10n.dayWed,
      l10n.dayThu,
      l10n.dayFri,
      l10n.daySat,
      l10n.daySun,
    ];

    return SideTitleWidget(
      axisSide: meta.axisSide,
      space: 10,
      child: Text(
        titles[value.toInt()],
        style: const TextStyle(
          color: AppTheme.textSecondary,
          fontWeight: FontWeight.w500,
          fontSize: 12,
        ),
      ),
    );
  }
} 