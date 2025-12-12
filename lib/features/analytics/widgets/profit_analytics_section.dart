import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:instal_app/core/theme/app_theme.dart';
import 'package:month_picker_dialog/month_picker_dialog.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../shared/widgets/analytics_card.dart';
import '../domain/entities/analytics_data.dart';

enum _ProfitViewMode { expected, received }

class ProfitAnalyticsSection extends StatefulWidget {
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
  State<ProfitAnalyticsSection> createState() => _ProfitAnalyticsSectionState();
}

class _ProfitAnalyticsSectionState extends State<ProfitAnalyticsSection> {
  _ProfitViewMode _mode = _ProfitViewMode.expected;
  int _selectedMonthIndex = 0;
  bool _isMonthPickerOpen = false;

  @override
  void initState() {
    super.initState();
    _selectedMonthIndex = _initialMonthIndex(widget.data.months);
  }

  @override
  void didUpdateWidget(covariant ProfitAnalyticsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    final monthsChanged = oldWidget.data.months != widget.data.months;
    if (monthsChanged && widget.data.months.isNotEmpty) {
      final newIndex = _initialMonthIndex(widget.data.months);
      final selectedMonth = widget.data.months[_selectedMonthIndex.clamp(
        0,
        widget.data.months.length - 1,
      )];
      final selectedStillExists = widget.data.months.any(
        (m) =>
            m.month.year == selectedMonth.month.year &&
            m.month.month == selectedMonth.month.month,
      );
      if (!selectedStillExists || _selectedMonthIndex >= widget.data.months.length) {
        setState(() => _selectedMonthIndex = newIndex);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final currencyFormatter = NumberFormat.currency(
      locale: l10n.locale.languageCode == 'ru' ? 'ru_RU' : 'en_US',
      symbol: '₽',
      decimalDigits: 0,
    );

    final months = widget.data.months;
    final hasData = months.isNotEmpty;
    final selectedMonth =
        hasData ? months[_selectedMonthIndex.clamp(0, months.length - 1)] : null;

    const title = 'Динамика прибыли';
    Widget content;
    if (widget.isLoading) {
      content = const Center(child: CircularProgressIndicator());
    } else if (!hasData || selectedMonth == null) {
      content = _EmptyProfitState(l10n: l10n);
    } else {
      final expectedMetrics = _ExpectedMetrics.fromMonth(selectedMonth);
      final receivedMetrics = _ReceivedMetrics.fromMonth(selectedMonth);

      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HeaderRow(
            title: title,
            mode: _mode,
            onModeChanged: (mode) => setState(() => _mode = mode),
            l10n: l10n,
            onPickMonth: () {
              if (_isMonthPickerOpen) return;
              _isMonthPickerOpen = true;
              WidgetsBinding.instance.addPostFrameCallback(
                (_) => _openMonthPicker(context, l10n, months),
              );
            },
            selectedMonthLabel:
                hasData
                    ? DateFormat('MMM yyyy', l10n.locale.languageCode).format(
                      selectedMonth.month,
                    )
                    : l10n.selectMonth,
          ),
          const SizedBox(height: 12),
          _SummaryRow(
            mode: _mode,
            expectedMetrics: expectedMetrics,
            receivedMetrics: receivedMetrics,
            l10n: l10n,
            currencyFormatter: currencyFormatter,
            outsideMonthPaid: selectedMonth.outsideMonthPaid,
          ),
          const SizedBox(height: 24),
          Expanded(
            child: _ProfitBarChart(
              mode: _mode,
              monthData: selectedMonth,
              expectedMetrics: expectedMetrics,
              receivedMetrics: receivedMetrics,
              currencyFormatter: currencyFormatter,
              l10n: l10n,
            ),
          ),
        ],
      );
    }

    return AnalyticsCard(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: content,
      ),
    );
  }

  int _initialMonthIndex(List<MonthlyProfitData> months) {
    if (months.isEmpty) return 0;
    final now = DateTime.now();
    final currentIndex = months.indexWhere(
      (m) => m.month.year == now.year && m.month.month == now.month,
    );
    if (currentIndex != -1) return currentIndex;

    // fallback to latest available
    DateTime latest = months.first.month;
    int index = 0;
    for (var i = 1; i < months.length; i++) {
      if (months[i].month.isAfter(latest)) {
        latest = months[i].month;
        index = i;
      }
    }
    return index;
  }

  Future<void> _showInfoDialog(
    BuildContext context,
    AppLocalizations l10n,
  ) async {
    return showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(
            l10n.profitChartInfoTitle,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '• ${l10n.profitChartExpectedInfo}',
                style: const TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 8),
              Text(
                '• ${l10n.profitChartReceivedInfo}',
                style: const TextStyle(fontSize: 14),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(l10n.close),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openMonthPicker(
    BuildContext context,
    AppLocalizations l10n,
    List<MonthlyProfitData> months,
  ) async {
    if (months.isEmpty) return;
    try {
      // Determine min/max from available data
      DateTime minMonth = months.first.month;
      DateTime maxMonth = months.first.month;
      for (final m in months) {
        if (m.month.isBefore(minMonth)) minMonth = m.month;
        if (m.month.isAfter(maxMonth)) maxMonth = m.month;
      }

      // Keep currently selected month as initial
      final DateTime initial = months[_selectedMonthIndex.clamp(0, months.length - 1)].month;

      final picked = await showMonthPicker(
        context: context,
        initialDate: initial,
        firstDate: DateTime(minMonth.year, minMonth.month),
        lastDate: DateTime(maxMonth.year, maxMonth.month),
        monthPickerDialogSettings: MonthPickerDialogSettings(
          dialogSettings: defaultPickerDialogSettings.copyWith(
            dialogRoundedCornersRadius: 16,
            insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            dismissible: true,
          ),
          actionBarSettings: defaultPickerActionBarSettings.copyWith(
            actionBarPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            buttonSpacing: 12,
          ),
          dateButtonsSettings: defaultPickerDateButtonsSettings.copyWith(
            selectedMonthBackgroundColor: AppTheme.primaryColor,
            selectedMonthTextColor: Colors.white,
            currentMonthTextColor: AppTheme.primaryColor,
          ),
        ),
      );
      if (picked == null) return;

      final idx = months.indexWhere(
        (m) => m.month.year == picked.year && m.month.month == picked.month,
      );
      if (idx != -1) {
        setState(() => _selectedMonthIndex = idx);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.noDataForSelectedMonth)),
        );
      }
    } finally {
      _isMonthPickerOpen = false;
    }
  }
}

class _HeaderRow extends StatelessWidget {
  final String title;
  final _ProfitViewMode mode;
  final ValueChanged<_ProfitViewMode> onModeChanged;
  final AppLocalizations l10n;
  final VoidCallback onPickMonth;
  final String selectedMonthLabel;

  const _HeaderRow({
    required this.title,
    required this.mode,
    required this.onModeChanged,
    required this.l10n,
    required this.onPickMonth,
    required this.selectedMonthLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
        children: [
            Expanded(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      title,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final controls = [
                  _TabControl<_ProfitViewMode>(
                    options: [
                      _TabOption(
                        value: _ProfitViewMode.expected,
                        label: l10n.expectedByDueDate,
                      ),
                      _TabOption(
                        value: _ProfitViewMode.received,
                        label: l10n.receivedByPaidDate,
                      ),
                    ],
                    value: mode,
                    onChanged: onModeChanged,
                  ),
                  _MonthPickerButton(
                    label: selectedMonthLabel,
                    onTap: onPickMonth,
                  ),
                ];

                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < controls.length; i++) ...[
                        controls[i],
                        if (i != controls.length - 1) const SizedBox(width: 10),
                      ],
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ],
    );
  }
}

class _MonthPickerButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _MonthPickerButton({required this.label, required this.onTap, super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: OutlinedButton.icon(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          side: BorderSide(color: AppTheme.subtleBorderColor),
          backgroundColor: AppTheme.subtleBackgroundColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        icon: const Icon(Icons.calendar_month, size: 16, color: AppTheme.textSecondary),
        label: Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 14,
            color: AppTheme.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _TabOption<T> {
  final T value;
  final String label;

  _TabOption({
    required this.value,
    required this.label,
  });
}

class _TabControl<T> extends StatelessWidget {
  final List<_TabOption<T>> options;
  final T value;
  final ValueChanged<T> onChanged;

  const _TabControl({
    required this.options,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    const double optionWidth = 120;

    return Container(
      padding: EdgeInsets.zero,
      decoration: BoxDecoration(
        color: AppTheme.subtleBackgroundColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.subtleBorderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: options.asMap().entries.map((entry) {
          final index = entry.key;
          final opt = entry.value;
          final isSelected = opt.value == value;
          final radius = BorderRadius.horizontal(
            left: index == 0 ? const Radius.circular(12) : Radius.zero,
            right: index == options.length - 1 ? const Radius.circular(12) : Radius.zero,
          );

          return SizedBox(
            width: optionWidth,
            height: 40,
            child: TextButton(
              onPressed: () => onChanged(opt.value),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                backgroundColor:
                    isSelected ? AppTheme.subtleAccentColor : Colors.transparent,
                foregroundColor: isSelected ? AppTheme.textPrimary : AppTheme.textSecondary,
                overlayColor: Colors.transparent,
                textStyle: TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                  letterSpacing: 0.05,
                ),
                shape: RoundedRectangleBorder(borderRadius: radius, side: BorderSide.none),
              ),
              child: Center(
                child: Text(
                  opt.label,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final _ProfitViewMode mode;
  final _ExpectedMetrics expectedMetrics;
  final _ReceivedMetrics receivedMetrics;
  final AppLocalizations l10n;
  final NumberFormat currencyFormatter;
  final double outsideMonthPaid;

  const _SummaryRow({
    required this.mode,
    required this.expectedMetrics,
    required this.receivedMetrics,
    required this.l10n,
    required this.currencyFormatter,
    required this.outsideMonthPaid,
  });

  @override
  Widget build(BuildContext context) {
    final tiles =
        mode == _ProfitViewMode.expected
            ? [
              _SummaryTile(
                label: l10n.expectedByDueDate,
                value: currencyFormatter.format(expectedMetrics.total),
              ),
              _SummaryTile(
                label: l10n.collected,
                value: currencyFormatter.format(receivedMetrics.total),
              ),
              _SummaryTile(
                label: l10n.toReceive,
                value: currencyFormatter.format(
                  max(0.0, expectedMetrics.total - receivedMetrics.total),
                ),
              ),
              _SummaryTile(
                label: l10n.overdue,
                value: currencyFormatter.format(expectedMetrics.overdue),
                valueColor:
                    expectedMetrics.overdue > 0
                        ? AppTheme.errorColor
                        : AppTheme.textPrimary,
              ),
            ]
            : [
              _SummaryTile(
                label: l10n.receivedByPaidDate,
                value: currencyFormatter.format(receivedMetrics.total),
              ),
              _SummaryTile(
                label: l10n.averagePerDay,
                value: currencyFormatter.format(receivedMetrics.averagePerDay),
              ),
            ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: tiles,
        ),
        if (mode == _ProfitViewMode.expected && outsideMonthPaid > 0)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              '${l10n.paidOutsideMonth}: ${currencyFormatter.format(outsideMonthPaid)}',
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
          ),
      ],
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _SummaryTile({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 150, maxWidth: 220),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
          border: Border.all(color: AppTheme.subtleBorderColor),
          boxShadow: const [
            BoxShadow(
              color: Color(0x08000000),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: valueColor ?? AppTheme.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfitBarChart extends StatelessWidget {
  final _ProfitViewMode mode;
  final MonthlyProfitData monthData;
  final _ExpectedMetrics expectedMetrics;
  final _ReceivedMetrics receivedMetrics;
  final NumberFormat currencyFormatter;
  final AppLocalizations l10n;

  const _ProfitBarChart({
    required this.mode,
    required this.monthData,
    required this.expectedMetrics,
    required this.receivedMetrics,
    required this.currencyFormatter,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    final isExpected = mode == _ProfitViewMode.expected;
    final daysInMonth = DateTime(monthData.month.year, monthData.month.month + 1, 0).day;
    final barGroups = isExpected
        ? _buildExpectedGroups(monthData, daysInMonth)
        : _buildReceivedGroups(monthData, daysInMonth);

    double maxY = 0;
    for (final group in barGroups) {
      for (final rod in group.barRods) {
        maxY = max(maxY, rod.toY);
      }
    }
    if (maxY <= 0) {
      maxY = 100;
    } else {
      maxY *= 1.25;
    }

    final double gridInterval = _gridInterval(maxY);

    return BarChart(
      BarChartData(
        maxY: maxY,
        extraLinesData: const ExtraLinesData(),
        alignment: BarChartAlignment.spaceAround,
        borderData: FlBorderData(show: false),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: gridInterval,
          checkToShowHorizontalLine: (value) {
            if (value == 0) return true;
            if (value < 1000) return false;
            return (value % gridInterval).abs() < 0.01;
          },
          getDrawingHorizontalLine: (_) => FlLine(
            color: AppTheme.subtleBorderColor,
            strokeWidth: 1,
          ),
        ),
        titlesData: _titlesData(daysInMonth, l10n),
        barTouchData: _barTouchData(),
        barGroups: barGroups,
      ),
    );
  }

  double _gridInterval(double maxY) {
    if (maxY <= 2000) return 500;
    if (maxY <= 5000) return 1000;
    if (maxY <= 10000) return 2000;
    if (maxY <= 20000) return 5000;
    return 10000;
  }

  BarTouchData _barTouchData() => BarTouchData(enabled: false);

  FlTitlesData _titlesData(int daysInMonth, AppLocalizations l10n) {
    return FlTitlesData(
      show: true,
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 40,
          getTitlesWidget: (value, meta) => _leftTitles(value, meta, l10n),
        ),
      ),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 26,
          getTitlesWidget: (value, meta) => _bottomTitles(value, meta, daysInMonth),
        ),
      ),
    );
  }

  Widget _leftTitles(double value, TitleMeta meta, AppLocalizations l10n) {
    if (value == 0) {
      return SideTitleWidget(
        axisSide: meta.axisSide,
        space: 8,
        child: const Text(
          '0',
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 11,
          ),
        ),
      );
    }
    if (value == meta.max) return Container();

    final isRussian = l10n.locale.languageCode == 'ru';
    final thousandsSuffix = isRussian ? 'т' : 'k';

    String text;
    if (value >= 1000) {
      text = '${(value / 1000).toStringAsFixed(0)}$thousandsSuffix';
    } else {
      return Container();
    }

    return SideTitleWidget(
      axisSide: meta.axisSide,
      space: 8,
      child: Text(
        text,
        style: const TextStyle(
          color: AppTheme.textSecondary,
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _bottomTitles(double value, TitleMeta meta, int daysInMonth) {
    final day = value.toInt();
    if (day <= 0 || day > daysInMonth) return const SizedBox.shrink();
    return SideTitleWidget(
      axisSide: meta.axisSide,
      space: 6,
      child: Text(
        day.toString(),
        style: const TextStyle(
          color: AppTheme.textSecondary,
          fontWeight: FontWeight.w500,
          fontSize: 11,
        ),
      ),
    );
  }

  List<BarChartGroupData> _buildExpectedGroups(
    MonthlyProfitData monthData,
    int daysInMonth,
  ) {
    final expectedByDay = {
      for (final item in monthData.expectedDaily) item.day: item,
    };

    return List.generate(daysInMonth, (index) {
      final day = index + 1;
      final point = expectedByDay[day];
      final amount = point?.expectedAmount ?? 0.0;

      return BarChartGroupData(
        x: day,
        barRods: [
          BarChartRodData(
            toY: amount,
            width: 8,
            color: AppTheme.primaryColor,
            borderRadius: BorderRadius.circular(6),
          ),
        ],
      );
    });
  }

  List<BarChartGroupData> _buildReceivedGroups(
    MonthlyProfitData monthData,
    int daysInMonth,
  ) {
    final receivedByDay = {
      for (final item in monthData.receivedDaily) item.day: item,
    };

    return List.generate(daysInMonth, (index) {
      final day = index + 1;
      final point = receivedByDay[day];
      final amount = point?.amount ?? 0.0;

      return BarChartGroupData(
        x: day,
        barRods: [
          BarChartRodData(
            toY: amount,
            width: 8,
            color: AppTheme.primaryColor,
            borderRadius: BorderRadius.circular(6),
          ),
        ],
      );
    });
  }
}

class _EmptyProfitState extends StatelessWidget {
  final AppLocalizations l10n;

  const _EmptyProfitState({required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppTheme.subtleBackgroundColor,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.leaderboard_outlined,
              color: AppTheme.textSecondary,
              size: 32,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            l10n.noPaymentsThisMonth,
            style: const TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.checkBackSoon,
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpectedMetrics {
  final double total;
  final double collected;
  final double toReceive;
  final double overdue;

  _ExpectedMetrics({
    required this.total,
    required this.collected,
    required this.toReceive,
    required this.overdue,
  });

  factory _ExpectedMetrics.fromMonth(MonthlyProfitData month) {
    double total = 0;
    double collected = 0;
    double overdue = month.overdueAmount;
    final shouldComputeOverdue = overdue == 0;

    for (final item in month.expectedDaily) {
      final expAmt = item.expectedAmount;
      final paidAmt = item.paidAmount;

      total += expAmt.isFinite ? expAmt : 0.0;
      collected += min(paidAmt.isFinite ? paidAmt : 0.0, expAmt.isFinite ? expAmt : 0.0);
      if (shouldComputeOverdue && item.isOverdue) {
        overdue += max(
          0,
          (expAmt.isFinite ? expAmt : 0.0) - (paidAmt.isFinite ? paidAmt : 0.0),
        );
      }
    }

    final toReceive = max(0.0, total - collected);

    return _ExpectedMetrics(
      total: total,
      collected: collected,
      toReceive: toReceive,
      overdue: overdue,
    );
  }
}

class _ReceivedMetrics {
  final double total;
  final double averagePerDay;

  _ReceivedMetrics({
    required this.total,
    required this.averagePerDay,
  });

  factory _ReceivedMetrics.fromMonth(MonthlyProfitData month) {
    double total = 0;
    for (final item in month.receivedDaily) {
      total += item.amount;
    }
    final daysInMonth = DateTime(month.month.year, month.month.month + 1, 0).day;
    final average = daysInMonth == 0 ? 0.0 : total / daysInMonth;

    return _ReceivedMetrics(
      total: total,
      averagePerDay: average,
    );
  }
}
class _WheelColumn extends StatelessWidget {
  final FixedExtentScrollController controller;
  final int itemCount;
  final String Function(int) labelBuilder;
  final ValueChanged<int> onChanged;

  const _WheelColumn({
    required this.controller,
    required this.itemCount,
    required this.labelBuilder,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ListWheelScrollView.useDelegate(
          controller: controller,
          itemExtent: 32,
          physics: const FixedExtentScrollPhysics(),
          onSelectedItemChanged: onChanged,
          childDelegate: ListWheelChildBuilderDelegate(
            builder: (_, idx) => Center(
              child: Text(
                labelBuilder(idx),
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
            childCount: itemCount,
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: IconButton(
            icon: const Icon(Icons.keyboard_arrow_up),
            onPressed: () => controller.animateToItem(
              (controller.selectedItem - 1).clamp(0, itemCount - 1),
              duration: const Duration(milliseconds: 120),
              curve: Curves.easeOut,
            ),
          ),
        ),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: IconButton(
            icon: const Icon(Icons.keyboard_arrow_down),
            onPressed: () => controller.animateToItem(
              (controller.selectedItem + 1).clamp(0, itemCount - 1),
              duration: const Duration(milliseconds: 120),
              curve: Curves.easeOut,
            ),
          ),
        ),
      ],
    );
  }
}
