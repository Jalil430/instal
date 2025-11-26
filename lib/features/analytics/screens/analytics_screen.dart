import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:instal_app/features/analytics/data/repositories/analytics_repository.dart';
import 'package:instal_app/features/analytics/domain/entities/analytics_data.dart';
import 'package:instal_app/features/analytics/domain/usecases/get_analytics_data.dart';
import 'package:instal_app/features/installments/data/datasources/installment_remote_datasource.dart';
import 'package:instal_app/features/installments/data/repositories/installment_repository_impl.dart';
import '../../../core/api/cache_service.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../shared/widgets/responsive_layout.dart';
import '../../auth/presentation/widgets/auth_service_provider.dart';
import '../../wallets/data/datasources/wallet_remote_datasource_impl.dart';
import '../../wallets/data/repositories/wallet_repository_impl.dart';
import '../../wallets/domain/entities/wallet.dart';
import '../../wallets/domain/repositories/wallet_repository.dart';
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
  late WalletRepository _walletRepository;
  bool _isRefreshing = false;
  bool _isInitialized = false;
  bool _walletsLoaded = false;
  bool _isWalletsLoading = false;
  String? _selectedWalletId;
  AnalyticsData? _walletAnalyticsData;
  bool _isWalletAnalyticsLoading = false;
  List<Wallet> _wallets = [];
  final Map<String, AnalyticsData> _walletAnalyticsCache = {};
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    final installmentRepository = InstallmentRepositoryImpl(
      InstallmentRemoteDataSourceImpl(),
    );
    final analyticsRepository = AnalyticsRepository(installmentRepository);
    _getAnalyticsData = GetAnalyticsData(analyticsRepository);
    _walletRepository = WalletRepositoryImpl(WalletRemoteDataSourceImpl());
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

      _currentUserId = currentUser.id;

      if (mounted) {
        setState(() {
          _analyticsDataFuture = _getAnalyticsData(currentUser.id);
        });
      }

      _loadWalletsForUser(currentUser.id);
      if (_selectedWalletId != null) {
        _reloadSelectedWalletAnalytics();
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

  Future<void> _loadWalletsForUser(
    String userId, {
    bool forceReload = false,
  }) async {
    if (!mounted) return;
    if (_isWalletsLoading) return;
    if (_walletsLoaded && !forceReload) return;

    setState(() => _isWalletsLoading = true);

    try {
      final wallets = await _walletRepository.getAllWallets(userId);
      if (!mounted) return;
      setState(() {
        _wallets = wallets;
        _walletsLoaded = true;
        if (_selectedWalletId != null &&
            !_wallets.any((wallet) => wallet.id == _selectedWalletId)) {
          _selectedWalletId = null;
          _walletAnalyticsData = null;
          _isWalletAnalyticsLoading = false;
        }
      });
    } catch (e) {
      print('Error loading wallets: $e');
    } finally {
      if (mounted) {
        setState(() => _isWalletsLoading = false);
      }
    }
  }

  Future<void> _reloadSelectedWalletAnalytics() async {
    final walletId = _selectedWalletId;
    if (walletId == null) return;
    if (!mounted) return;
    setState(() {
      _walletAnalyticsData = _walletAnalyticsCache[walletId];
      _isWalletAnalyticsLoading = true;
    });
    await _loadWalletProfitAnalytics(walletId);
  }

  Future<void> _loadWalletProfitAnalytics(String walletId) async {
    if (_currentUserId == null) return;
    try {
      final data = await _getAnalyticsData(_currentUserId!, walletId: walletId);
      if (!mounted || _selectedWalletId != walletId) return;
      setState(() {
        _walletAnalyticsData = data;
        _walletAnalyticsCache[walletId] = data;
        _isWalletAnalyticsLoading = false;
      });
    } catch (e) {
      print('Error loading wallet-specific analytics: $e');
      if (mounted && _selectedWalletId == walletId) {
        setState(() {
          _isWalletAnalyticsLoading = false;
        });
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.walletAnalyticsLoadError)));
      }
    }
  }

  void _onWalletSelected(String? walletId) {
    if (!mounted) return;
    if (_selectedWalletId == walletId) return;
    setState(() {
      _selectedWalletId = walletId;
      if (walletId == null) {
        _walletAnalyticsData = null;
        _isWalletAnalyticsLoading = false;
      } else {
        _walletAnalyticsData = _walletAnalyticsCache[walletId];
        _isWalletAnalyticsLoading = _walletAnalyticsData == null;
      }
    });

    if (walletId != null) {
      _loadWalletProfitAnalytics(walletId);
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

      _currentUserId = currentUser.id;

      // Clear analytics cache to force fresh data
      final cache = CacheService();
      final analyticsKeys = cache.getKeysWithPrefix(
        'analytics_${currentUser.id}',
      );
      for (final key in analyticsKeys) {
        cache.remove(key);
      }

      if (!mounted) return;

      // Reload data
      final newFuture = _getAnalyticsData(currentUser.id);
      setState(() {
        _analyticsDataFuture = newFuture;
      });

      // Wait for completion to stop the refresh indicator
      await newFuture;

      _loadWalletsForUser(currentUser.id, forceReload: true);
      if (_selectedWalletId != null) {
        _reloadSelectedWalletAnalytics();
      }
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
        if (snapshot.connectionState == ConnectionState.waiting ||
            snapshot.connectionState == ConnectionState.none) {
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
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
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
        } else if (snapshot.data != null &&
            _isAnalyticsDataEmpty(snapshot.data!)) {
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
                    style: const TextStyle(fontSize: 14, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        final analyticsData = snapshot.data!;
        final selectedWalletAnalytics =
            _selectedWalletId == null ? null : _walletAnalyticsData;
        final profitAnalyticsData =
            selectedWalletAnalytics?.profitAnalytics ??
            analyticsData.profitAnalytics;
        final installmentDetailsData =
            selectedWalletAnalytics?.installmentDetails ??
            analyticsData.installmentDetails;
        final isWalletDataLoading =
            _selectedWalletId != null &&
            _isWalletAnalyticsLoading &&
            selectedWalletAnalytics == null;

        return ResponsiveLayout(
          mobile: AnalyticsScreenMobile(
            analyticsData: analyticsData,
            isRefreshing: _isRefreshing,
            refreshAnalytics: _refreshAnalytics,
            wallets: _wallets,
            isWalletsLoading: _isWalletsLoading,
            selectedWalletId: _selectedWalletId,
            onWalletSelected: _onWalletSelected,
            profitAnalyticsData: profitAnalyticsData,
            installmentDetailsData: installmentDetailsData,
            isWalletDataLoading: isWalletDataLoading,
          ),
          desktop: AnalyticsScreenDesktop(
            analyticsData: analyticsData,
            isRefreshing: _isRefreshing,
            refreshAnalytics: _refreshAnalytics,
            wallets: _wallets,
            isWalletsLoading: _isWalletsLoading,
            selectedWalletId: _selectedWalletId,
            onWalletSelected: _onWalletSelected,
            profitAnalyticsData: profitAnalyticsData,
            installmentDetailsData: installmentDetailsData,
            isWalletDataLoading: isWalletDataLoading,
          ),
        );
      },
    );
  }
}
