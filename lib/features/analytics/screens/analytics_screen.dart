import 'package:flutter/material.dart';
import 'package:instal_app/features/analytics/data/repositories/analytics_repository.dart';
import 'package:instal_app/features/analytics/domain/entities/analytics_data.dart';
import 'package:instal_app/features/analytics/domain/usecases/get_analytics_data.dart';
import 'package:instal_app/features/installments/data/datasources/installment_remote_datasource.dart';
import 'package:instal_app/features/installments/data/repositories/installment_repository_impl.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/api/cache_service.dart';
import '../../../shared/widgets/custom_icon_button.dart';
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
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _initializeAnalytics();
  }

  void _initializeAnalytics() {
    final installmentRepository = InstallmentRepositoryImpl(
      InstallmentRemoteDataSourceImpl(),
    );
    final analyticsRepository = AnalyticsRepository(installmentRepository);
    _getAnalyticsData = GetAnalyticsData(analyticsRepository);
    _analyticsDataFuture = _getAnalyticsData('user123');
  }

  Future<void> _refreshAnalytics() async {
    if (_isRefreshing) return; // Prevent multiple refresh calls
    
    setState(() => _isRefreshing = true);
    
    try {
      // Clear analytics cache to force fresh data
      final cache = CacheService();
      cache.remove(CacheService.analyticsKey('user123'));
      
      // Reload data
      final newFuture = _getAnalyticsData('user123');
      setState(() {
        _analyticsDataFuture = newFuture;
      });
      
      // Wait for completion to stop the refresh indicator
      await newFuture;
    } catch (e) {
      // Handle error silently or show snackbar
      print('Error refreshing analytics: $e');
    } finally {
      setState(() => _isRefreshing = false);
    }
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
                // Refresh button
                CustomIconButton(
                  icon: Icons.refresh_rounded,
                  onPressed: _refreshAnalytics,
                  size: 36,
                  animate: _isRefreshing,
                  rotation: _isRefreshing ? 1.0 : 0.0,
                  animationDuration: const Duration(milliseconds: 1000),
                  interactive: !_isRefreshing,
                ),
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
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Error: ${snapshot.error}'),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _refreshAnalytics,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
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
