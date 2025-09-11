import 'dart:convert';
import '../../../../core/api/api_client.dart' as api;
import '../../../../core/api/cache_service.dart';
import '../../domain/entities/wallet.dart';
import '../models/wallet_model.dart';
import '../models/wallet_balance_model.dart';
import '../models/ledger_transaction_model.dart';
import '../models/investment_summary_model.dart';
import 'wallet_remote_datasource.dart';

class WalletRemoteDataSourceImpl implements WalletRemoteDataSource {
  final CacheService _cache = CacheService();

  // Public method to clear cache from outside
  void clearCache() {
    _cache.clearWalletCaches();
  }

  @override
  Future<List<WalletModel>> getAllWallets(String userId) async {
    try {
      final cacheKey = CacheService.walletsKey(userId);
      final cached = _cache.get<List<WalletModel>>(cacheKey);
      if (cached != null) {
        return cached;
      }

      final response = await api.ApiClient.get('/wallets');

      if (response.statusCode == 200) {
        final List<dynamic> walletsJson = json.decode(response.body) as List<dynamic>;
        final wallets = walletsJson.map((json) => WalletModel.fromJson(json)).toList();

        _cache.set(cacheKey, wallets, duration: const Duration(minutes: 30));
        return wallets;
      } else {
        throw Exception('Failed to load wallets: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error loading wallets: $e');
    }
  }

  @override
  Future<WalletModel?> getWalletById(String walletId) async {
    try {
      print('🔍 getWalletById: Fetching wallet $walletId');

      final cacheKey = CacheService.walletKey(walletId);
      final cached = _cache.get<WalletModel>(cacheKey);
      if (cached != null) {
        print('📦 getWalletById: Found cached wallet $walletId');
        return cached;
      }

      print('🌐 getWalletById: Making API call to /wallets/$walletId');
      final response = await api.ApiClient.get('/wallets/$walletId');
      print('📡 getWalletById: Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        print('✅ getWalletById: Successfully received wallet data');
        final walletJson = json.decode(response.body) as Map<String, dynamic>;
        final wallet = WalletModel.fromJson(walletJson);

        _cache.set(cacheKey, wallet);
        print('💾 getWalletById: Cached wallet $walletId');
        return wallet;
      } else if (response.statusCode == 404) {
        print('⚠️ getWalletById: Wallet $walletId not found');
        return null;
      } else {
        print('❌ getWalletById: Failed with status ${response.statusCode}, body: ${response.body}');
        throw Exception('Failed to load wallet: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('💥 getWalletById: Error loading wallet $walletId: $e');
      throw Exception('Error loading wallet: $e');
    }
  }

  @override
  Future<WalletModel> createWallet(WalletModel wallet) async {
    try {
      final walletData = wallet.toJson();
      walletData.remove('id');
      walletData.remove('created_at');
      walletData.remove('updated_at');

      final response = await api.ApiClient.post('/wallets', walletData);

      if (response.statusCode == 201) {
        final createdWalletJson = json.decode(response.body) as Map<String, dynamic>;
        final createdWallet = WalletModel.fromJson(createdWalletJson);

        // Invalidate list and balances caches for the user
        _cache.remove(CacheService.walletsKey(createdWallet.userId));
        _cache.remove(CacheService.walletBalancesKey(createdWallet.userId));
        return createdWallet;
      } else {
        throw Exception('Failed to create wallet: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error creating wallet: $e');
    }
  }

  @override
  Future<WalletModel> updateWallet(WalletModel wallet) async {
    try {
      final walletData = wallet.toJson();
      walletData.remove('created_at');

      final response = await api.ApiClient.put('/wallets/${wallet.id}', walletData);

      if (response.statusCode == 200) {
        final updatedWalletJson = json.decode(response.body) as Map<String, dynamic>;
        final updatedWallet = WalletModel.fromJson(updatedWalletJson);

        _cache.remove(CacheService.walletKey(wallet.id));
        _cache.remove(CacheService.walletsKey(wallet.userId));
        _cache.remove(CacheService.walletBalancesKey(wallet.userId));
        return updatedWallet;
      } else {
        throw Exception('Failed to update wallet: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error updating wallet: $e');
    }
  }

  @override
  Future<void> deleteWallet(String walletId) async {
    try {
      // Try to fetch wallet to get userId for targeted invalidation
      String? userId;
      try {
        final existing = await getWalletById(walletId);
        userId = existing?.userId;
      } catch (_) {}

      final response = await api.ApiClient.delete('/wallets/$walletId');

      if (response.statusCode == 200 || response.statusCode == 204) {
        _cache.remove(CacheService.walletKey(walletId));
        if (userId != null) {
          _cache.remove(CacheService.walletsKey(userId));
          _cache.remove(CacheService.walletBalancesKey(userId));
        } else {
          _cache.clearWalletCaches();
        }
      } else {
        throw Exception('Failed to delete wallet: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error deleting wallet: $e');
    }
  }

  @override
  Future<void> archiveWallet(String walletId) async {
    try {
      // Use update-wallet for archiving
      final response = await api.ApiClient.put('/wallets/$walletId', {'status': 'archived'});

      if (response.statusCode == 200) {
        _cache.clearWalletCaches();
      } else {
        throw Exception('Failed to archive wallet: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error archiving wallet: $e');
    }
  }

  @override
  Future<void> unarchiveWallet(String walletId) async {
    try {
      final response = await api.ApiClient.put('/wallets/$walletId', {'status': 'active'});

      if (response.statusCode == 200) {
        _cache.clearWalletCaches();
      } else {
        throw Exception('Failed to unarchive wallet: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error unarchiving wallet: $e');
    }
  }

  @override
  Future<WalletBalanceModel?> getWalletBalance(String walletId) async {
    try {
      final cacheKey = CacheService.walletBalanceKey(walletId);
      final cached = _cache.get<WalletBalanceModel>(cacheKey);
      if (cached != null) {
        return cached;
      }

      final response = await api.ApiClient.get('/wallets/$walletId/balance');

      if (response.statusCode == 200) {
        final balanceJson = json.decode(response.body) as Map<String, dynamic>;
        final balance = WalletBalanceModel.fromJson(balanceJson);

        _cache.set(cacheKey, balance);
        return balance;
      } else if (response.statusCode == 404) {
        return null;
      } else {
        throw Exception('Failed to load wallet balance: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error loading wallet balance: $e');
    }
  }

  @override
  Future<List<WalletBalanceModel>> getAllWalletBalances(String userId) async {
    try {
      final cacheKey = CacheService.walletBalancesKey(userId);
      final cached = _cache.get<List<WalletBalanceModel>>(cacheKey);
      if (cached != null) {
        return cached;
      }

      // Try dedicated balances endpoint first
      final response = await api.ApiClient.get('/wallets/balances');
      if (response.statusCode == 200) {
        final List<dynamic> balancesJson = json.decode(response.body) as List<dynamic>;
        // If endpoint returned no balances, synthesize from /wallets
        if (balancesJson.isEmpty) {
          final walletsResp = await api.ApiClient.get('/wallets');
          if (walletsResp.statusCode == 200) {
            final List<dynamic> walletsJson = json.decode(walletsResp.body) as List<dynamic>;
            final synthesized = walletsJson.map((w) => {
              'wallet_id': w['id'],
              'user_id': w['user_id'],
              'balance_minor_units': ((w['balance'] ?? {})['balance_minor_units'] ?? 0),
              'version': ((w['balance'] ?? {})['version'] ?? 1),
              'updated_at': ((w['balance'] ?? {})['updated_at'] ?? DateTime.now().toIso8601String()),
            }).toList();
            final models = synthesized.map((json) => WalletBalanceModel.fromJson(json as Map<String, dynamic>)).toList();
            _cache.set(cacheKey, models, duration: const Duration(minutes: 3));
            return models;
          }
        }
        final models = balancesJson.map((json) => WalletBalanceModel.fromJson(json as Map<String, dynamic>)).toList();
        _cache.set(cacheKey, models, duration: const Duration(minutes: 3));
        return models;
      } else {
        // On failure, synthesize from /wallets as fallback
        final walletsResp = await api.ApiClient.get('/wallets');
        if (walletsResp.statusCode == 200) {
          final List<dynamic> walletsJson = json.decode(walletsResp.body) as List<dynamic>;
          final synthesized = walletsJson.map((w) => {
            'wallet_id': w['id'],
            'user_id': w['user_id'],
            'balance_minor_units': ((w['balance'] ?? {})['balance_minor_units'] ?? 0),
            'version': ((w['balance'] ?? {})['version'] ?? 1),
            'updated_at': ((w['balance'] ?? {})['updated_at'] ?? DateTime.now().toIso8601String()),
          }).toList();
          final models = synthesized.map((json) => WalletBalanceModel.fromJson(json as Map<String, dynamic>)).toList();
          _cache.set(cacheKey, models, duration: const Duration(minutes: 3));
          return models;
        }
        throw Exception('Failed to load wallet balances: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error loading wallet balances: $e');
    }
  }

  @override
  Future<List<LedgerTransactionModel>> getWalletTransactions(
    String walletId, {
    DateTime? fromDate,
    DateTime? toDate,
    int? limit,
    int? offset,
  }) async {
    try {
      final response = await api.ApiClient.get('/wallets/$walletId/ledger');

      if (response.statusCode == 200) {
        final ledgerData = json.decode(response.body) as Map<String, dynamic>;
        final List<dynamic> transactionsJson = ledgerData['transactions'] as List<dynamic>;
        return transactionsJson.map((json) => LedgerTransactionModel.fromJson(json)).toList();
      } else {
        throw Exception('Failed to load transactions: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error loading transactions: $e');
    }
  }

  @override
  Future<LedgerTransactionModel> createTransaction(LedgerTransactionModel transaction) async {
    try {
      final transactionData = transaction.toJson();
      transactionData.remove('id');
      transactionData.remove('created_at');

      final response = await api.ApiClient.post('/wallets/${transaction.walletId}/top-up', transactionData);

      if (response.statusCode == 200) {
        final resultData = json.decode(response.body) as Map<String, dynamic>;
        final createdTransaction = LedgerTransactionModel(
          id: resultData['transaction_id'] as String,
          walletId: transaction.walletId,
          userId: transaction.userId,
          direction: transaction.direction,
          amountMinorUnits: transaction.amountMinorUnits,
          currency: transaction.currency,
          referenceType: transaction.referenceType,
          referenceId: transaction.referenceId,
          description: transaction.description,
          createdBy: transaction.createdBy,
          createdAt: DateTime.now(),
        );

        _cache.remove(CacheService.walletBalanceKey(transaction.walletId));
        // Balance lists may change; clear all wallet caches for safety
        _cache.clearWalletCaches();
        return createdTransaction;
      } else {
        throw Exception('Failed to create transaction: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error creating transaction: $e');
    }
  }

  @override
  Future<InvestmentSummaryModel?> getInvestmentSummary(String walletId) async {
    try {
      final response = await api.ApiClient.get('/wallets/$walletId');

      if (response.statusCode == 200) {
        final walletJson = json.decode(response.body) as Map<String, dynamic>;
        final summaryJson = walletJson['investment_summary'] as Map<String, dynamic>?;

        if (summaryJson != null) {
          return InvestmentSummaryModel.fromJson(summaryJson);
        }
        return null;
      } else if (response.statusCode == 404) {
        return null;
      } else {
        throw Exception('Failed to load investment summary: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error loading investment summary: $e');
    }
  }

  @override
  Future<void> topUpWallet(String walletId, int amountMinorUnits, String description) async {
    try {
      final response = await api.ApiClient.post('/wallets/$walletId/top-up', {
        'amount_minor_units': amountMinorUnits,
        'description': description,
      });
      if (response.statusCode == 200) {
        _cache.remove(CacheService.walletBalanceKey(walletId));
        _cache.clearWalletCaches();
      } else {
        throw Exception('Top-up failed: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Top-up error: $e');
    }
  }

  @override
  Future<void> withdrawWallet(String walletId, int amountMinorUnits, String description) async {
    try {
      final response = await api.ApiClient.post('/wallets/$walletId/withdraw', {
        'amount_minor_units': amountMinorUnits,
        'description': description,
      });
      if (response.statusCode == 200) {
        _cache.remove(CacheService.walletBalanceKey(walletId));
        _cache.clearWalletCaches();
      } else {
        throw Exception('Withdraw failed: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Withdraw error: $e');
    }
  }

  @override
  Future<List<WalletModel>> searchWallets(String userId, String query) async {
    final allWallets = await getAllWallets(userId);
    return allWallets.where((wallet) =>
      wallet.name.toLowerCase().contains(query.toLowerCase())
    ).toList();
  }

  @override
  Future<List<WalletModel>> getWalletsByType(String userId, String type) async {
    final allWallets = await getAllWallets(userId);
    return allWallets.where((wallet) => wallet.type.toString().split('.').last == type).toList();
  }

  @override
  Future<List<WalletModel>> getActiveWallets(String userId) async {
    final allWallets = await getAllWallets(userId);
    return allWallets.where((wallet) => wallet.status == WalletStatus.active).toList();
  }
}
