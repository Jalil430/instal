import 'package:flutter/material.dart';
import 'package:instal_app/features/analytics/data/repositories/analytics_repository.dart';
import 'package:instal_app/features/analytics/domain/entities/analytics_data.dart';
import 'package:instal_app/features/analytics/domain/usecases/get_analytics_data.dart';
import 'package:instal_app/features/installments/data/datasources/installment_local_datasource.dart';
import 'package:instal_app/features/installments/data/repositories/installment_repository_impl.dart';
import 'package:instal_app/shared/database/database_helper.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../widgets/total_sales_section.dart';
import '../widgets/key_metrics_section.dart';
import '../widgets/installment_details_section.dart';
import '../widgets/installment_status_section.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  late Future<AnalyticsData> _analyticsDataFuture;
  late GetAnalyticsData _getAnalyticsData;

  @override
  void initState() {
    super.initState();
    final db = DatabaseHelper.instance;
    final installmentRepository = InstallmentRepositoryImpl(
      InstallmentLocalDataSourceImpl(db),
    );
    final analyticsRepository = AnalyticsRepository(installmentRepository);
    _getAnalyticsData = GetAnalyticsData(analyticsRepository);
    _analyticsDataFuture = _getAnalyticsData('user123');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: AppTheme.surfaceColor,
      body: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(32, 28, 32, 20),
            decoration: const BoxDecoration(
              color: AppTheme.surfaceColor,
            ),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.analytics,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                // TODO: Add dropdowns or other actions here if needed
              ],
            ),
          ),

          // Main Content
          Expanded(
            child: FutureBuilder<AnalyticsData>(
              future: _analyticsDataFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                } else if (!snapshot.hasData) {
                  return const Center(child: Text('No data available'));
                }

                final analyticsData = snapshot.data!;

                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  child: Column(
                    children: [
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(child: TotalSalesSection(data: analyticsData.totalSales)),
                            const SizedBox(width: 16),
                            Expanded(child: KeyMetricsSection(data: analyticsData.keyMetrics)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(child: InstallmentDetailsSection(data: analyticsData.installmentDetails)),
                            const SizedBox(width: 16),
                            Expanded(child: InstallmentStatusSection(data: analyticsData.installmentStatus)),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
