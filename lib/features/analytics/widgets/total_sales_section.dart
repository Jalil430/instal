import 'dart:math';
import 'package:flutter/material.dart';
import '../../../shared/widgets/analytics_card.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/localization/app_localizations.dart';
import 'package:intl/intl.dart';

class TotalSalesSection extends StatefulWidget {
  const TotalSalesSection({super.key});

  @override
  State<TotalSalesSection> createState() => _TotalSalesSectionState();
}

class _TotalSalesSectionState extends State<TotalSalesSection> {
  late List<double> _chartData;
  late double _averageSales;
  late double _lastWeekAverageSales;
  late double _percentageChange;
  late int _currentDayIndex;
  int? _hoveredIndex;

  @override
  void initState() {
    super.initState();
    _chartData = _getWeeklyData(isCurrentWeek: true);
    final lastWeekData = _getWeeklyData(isCurrentWeek: false);

    _averageSales = _chartData.isNotEmpty ? _chartData.reduce((a, b) => a + b) / _chartData.length : 0;
    _lastWeekAverageSales = lastWeekData.isNotEmpty ? lastWeekData.reduce((a, b) => a + b) / lastWeekData.length : 0;
    
    _percentageChange = _lastWeekAverageSales > 0
        ? ((_averageSales - _lastWeekAverageSales) / _lastWeekAverageSales) * 100
        : 0;

    // Monday is 1 and Sunday is 7. We need an index from 0 to 6.
    _currentDayIndex = DateTime.now().weekday - 1;
  }

  List<double> _getWeeklyData({bool isCurrentWeek = true}) {
    // Generates random data for 7 days of the week
    // A simple way to get different (but deterministic) data for current/last week
    final seed = isCurrentWeek ? 1 : 2;
    return List.generate(7, (i) => (Random(seed * (i+1)).nextDouble() * 45000) + 10000);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final currencyFormatter = NumberFormat.currency(locale: 'ru_RU', symbol: '₽');

    return AnalyticsCard(
      title: l10n.paymentsThisWeek, // Title updated as requested
      header: _buildHeader(l10n, currencyFormatter), // Header now shows average sales
      child: SizedBox(
        height: 300, 
        child: Padding(
          padding: const EdgeInsets.only(top: 8.0), // Reduced spacing
          child: BarChart(
            BarChartData(
              maxY: _chartData.reduce(max) * 1.2, // Dynamic maxY
              barTouchData: _barTouchData(),
              titlesData: _titlesData(),
              borderData: FlBorderData(show: false),
              gridData: const FlGridData(show: false),
              alignment: BarChartAlignment.spaceAround,
              barGroups: _barGroups(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(AppLocalizations l10n, NumberFormat currencyFormatter) {
    final isPositive = _percentageChange >= 0;
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Average per day metric in one line
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
              currencyFormatter.format(_averageSales),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(width: 8), // Reduced spacing
        // Compact comparison metric, styled like key_metrics_section
        Padding(
          padding: const EdgeInsets.only(top: 4.0), // Move percentage down
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                isPositive ? Icons.arrow_upward : Icons.arrow_downward,
                color: isPositive ? AppTheme.successColor : AppTheme.errorColor,
                size: 14,
              ),
              const SizedBox(width: 4),
              Text(
                '${_percentageChange.toStringAsFixed(1)}%',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: isPositive ? AppTheme.successColor : AppTheme.errorColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  BarTouchData _barTouchData() => BarTouchData(
        touchTooltipData: BarTouchTooltipData(
          getTooltipColor: (group) => AppTheme.sidebarBackground,
          tooltipRoundedRadius: 8,
          tooltipPadding: const EdgeInsets.fromLTRB(10, 6, 10, 2),
          tooltipMargin: 8,
          getTooltipItem: (group, groupIndex, rod, rodIndex) {
            final currencyFormatter = NumberFormat.currency(locale: 'ru_RU', symbol: '₽');
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
        touchCallback: (FlTouchEvent event, BarTouchResponse? response) {
          setState(() {
            if (event.isInterestedForInteractions && response?.spot != null) {
              _hoveredIndex = response!.spot!.touchedBarGroupIndex;
            } else {
              _hoveredIndex = null;
            }
          });
        },
      );

  FlTitlesData _titlesData() => FlTitlesData(
        show: true,
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 30,
            getTitlesWidget: _bottomTitles,
          ),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 40,
            getTitlesWidget: _leftTitles,
          ),
        ),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      );

  List<BarChartGroupData> _barGroups() {
    return List.generate(7, (index) {
      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: _chartData[index],
            color: index == _currentDayIndex
                ? AppTheme.primaryColor // Use theme's primary color
                : AppTheme.primaryColor.withOpacity(0.3), // Lighter shade for other days
            width: 16,
            borderRadius: BorderRadius.circular(8), // More rounded corners
          )
        ],
        showingTooltipIndicators: _hoveredIndex == index ? [0] : [],
      );
    });
  }

  Widget _leftTitles(double value, TitleMeta meta) {
    if (value == meta.max) return Container(); // Hide the top label

    final l10n = AppLocalizations.of(context)!;
    final isRussian = l10n.locale.languageCode == 'ru';
    final thousandsSuffix = isRussian ? 'т' : 'k';

    String text;
    if (value == 0) {
      text = '0';
    } else if (value >= 1000) {
      text = '${(value / 1000).toStringAsFixed(0)}$thousandsSuffix';
    } else {
      text = value.toStringAsFixed(0);
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

  Widget _bottomTitles(double value, TitleMeta meta) {
    final l10n = AppLocalizations.of(context)!;
    
    // Day titles for the current week
    final titles = [
      l10n.dayMon,
      l10n.dayTue,
      l10n.dayWed,
      l10n.dayThu,
      l10n.dayFri,
      l10n.daySat,
      l10n.daySun,
    ];

    final Widget text = Text(
      titles[value.toInt()],
      style: const TextStyle(
        color: AppTheme.textSecondary,
        fontWeight: FontWeight.w500,
        fontSize: 12,
      ),
    );

    return SideTitleWidget(
      axisSide: meta.axisSide,
      space: 10,
      child: text,
    );
  }
} 