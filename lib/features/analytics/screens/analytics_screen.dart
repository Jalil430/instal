import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:instal_app/features/analytics/data/repositories/analytics_repository.dart';
import 'package:instal_app/features/analytics/domain/entities/analytics_data.dart';
import 'package:instal_app/features/analytics/domain/usecases/get_analytics_data.dart';
import 'package:instal_app/features/installments/data/datasources/installment_remote_datasource.dart';
import 'package:instal_app/features/installments/data/repositories/installment_repository_impl.dart';
import '../../../core/api/cache_service.dart';
import '../../../shared/widgets/responsive_layout.dart';
import '../../auth/presentation/widgets/auth_service_provider.dart';
import 'desktop/analytics_screen_desktop.dart';
import 'mobile/analytics_screen_mobile.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  Future<AnalyticsData>? _analyticsDataFuture;
  late GetAnalyticsData _getAnalyticsData;
  bool _isRefreshing = false;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    final installmentRepository = InstallmentRepositoryImpl(
      InstallmentRemoteDataSourceImpl(),
    );
    final analyticsRepository = AnalyticsRepository(installmentRepository);
    _getAnalyticsData = GetAnalyticsData(analyticsRepository);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      _isInitialized = true;
      _loadAnalyticsData();
    }
  }

  Future<void> _loadAnalyticsData() async {
    if (!mounted) return;
    
    try {
      // Get current user from authentication
      final authService = AuthServiceProvider.of(context);
      final currentUser = await authService.getCurrentUser();
      
      if (!mounted) return;
      
      if (currentUser == null) {
        // Redirect to login if not authenticated
        if (mounted) {
          context.go('/auth/login');
        }
        return;
      }
      
      if (mounted) {
        setState(() {
          _analyticsDataFuture = _getAnalyticsData(currentUser.id);
        });
      }
    } catch (e) {
      print('Error loading analytics: $e');
      if (mounted) {
        setState(() {
          _analyticsDataFuture = Future.error(e);
        });
      }
    }
  }

  Future<void> _refreshAnalytics() async {
    if (_isRefreshing || !mounted) return; // Prevent multiple refresh calls
    
    setState(() => _isRefreshing = true);
    
    try {
      // Get current user from authentication
      final authService = AuthServiceProvider.of(context);
      final currentUser = await authService.getCurrentUser();
      
      if (!mounted) return;
      
      if (currentUser == null) {
        // Redirect to login if not authenticated
        if (mounted) {
          context.go('/auth/login');
        }
        return;
      }
      
      // Clear analytics cache to force fresh data
      final cache = CacheService();
      cache.remove(CacheService.analyticsKey(currentUser.id));
      
      if (!mounted) return;
      
      // Reload data
      final newFuture = _getAnalyticsData(currentUser.id);
      setState(() {
        _analyticsDataFuture = newFuture;
      });
      
      // Wait for completion to stop the refresh indicator
      await newFuture;
    } catch (e) {
      // Handle error silently or show snackbar
      print('Error refreshing analytics: $e');
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  bool _isAnalyticsDataEmpty(AnalyticsData data) {
    // Check if there are no active installments
    return data.installmentDetails.activeInstallments == 0;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AnalyticsData>(
      future: _analyticsDataFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting || snapshot.connectionState == ConnectionState.none) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        } else if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.analytics_outlined, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    'Ошибка загрузки аналитики',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Попробуйте обновить данные или добавьте рассрочки',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _refreshAnalytics,
                    child: Text('Повторить'),
                  ),
                ],
              ),
            ),
          );
        } else if (snapshot.data != null && _isAnalyticsDataEmpty(snapshot.data!)) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.analytics_outlined, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    'Нет данных для аналитики',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Добавьте рассрочки для просмотра аналитики',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        final analyticsData = snapshot.data!;

        return ResponsiveLayout(
          mobile: AnalyticsScreenMobile(
            analyticsData: analyticsData,
            isRefreshing: _isRefreshing,
            refreshAnalytics: _refreshAnalytics,
          ),
          desktop: AnalyticsScreenDesktop(
            analyticsData: analyticsData,
            isRefreshing: _isRefreshing,
            refreshAnalytics: _refreshAnalytics,
          ),
        );
      },
    );
  }
}
