import '../../domain/entities/wallet.dart';
import '../../domain/entities/wallet_balance.dart';
import '../../domain/entities/ledger_transaction.dart';
import '../../domain/entities/investment_summary.dart';
import '../../domain/repositories/wallet_repository.dart';
import '../datasources/wallet_remote_datasource.dart';
import '../models/wallet_model.dart';
import '../models/wallet_balance_model.dart';
import '../models/ledger_transaction_model.dart';
import '../models/investment_summary_model.dart';

class WalletRepositoryImpl implements WalletRepository {
  final WalletRemoteDataSource _remoteDataSource;

  WalletRepositoryImpl(this._remoteDataSource);

  @override
  Future<List<Wallet>> getAllWallets(String userId) async {
    final walletModels = await _remoteDataSource.getAllWallets(userId);
    return walletModels.map((model) => model.toEntity()).toList();
  }

  @override
  Future<Wallet?> getWalletById(String walletId) async {
    final walletModel = await _remoteDataSource.getWalletById(walletId);
    return walletModel?.toEntity();
  }

  @override
  Future<Wallet> createWallet(Wallet wallet) async {
    final walletModel = WalletModel.fromEntity(wallet);
    final createdModel = await _remoteDataSource.createWallet(walletModel);
    return createdModel.toEntity();
  }

  @override
  Future<Wallet> updateWallet(Wallet wallet) async {
    final walletModel = WalletModel.fromEntity(wallet);
    final updatedModel = await _remoteDataSource.updateWallet(walletModel);
    return updatedModel.toEntity();
  }

  @override
  Future<void> deleteWallet(String walletId) async {
    await _remoteDataSource.deleteWallet(walletId);
  }

  @override
  Future<void> archiveWallet(String walletId) async {
    await _remoteDataSource.archiveWallet(walletId);
  }

  @override
  Future<void> unarchiveWallet(String walletId) async {
    await _remoteDataSource.unarchiveWallet(walletId);
  }

  @override
  void clearCache() {
    _remoteDataSource.clearCache();
  }

  @override
  Future<WalletBalance?> getWalletBalance(String walletId) async {
    final balanceModel = await _remoteDataSource.getWalletBalance(walletId);
    return balanceModel?.toEntity();
  }

  @override
  Future<List<WalletBalance>> getAllWalletBalances(String userId) async {
    final balanceModels = await _remoteDataSource.getAllWalletBalances(userId);
    return balanceModels.map((model) => model.toEntity()).toList();
  }

  @override
  Future<List<LedgerTransaction>> getWalletTransactions(
    String walletId, {
    DateTime? fromDate,
    DateTime? toDate,
    int? limit,
    int? offset,
  }) async {
    final transactionModels = await _remoteDataSource.getWalletTransactions(
      walletId,
      fromDate: fromDate,
      toDate: toDate,
      limit: limit,
      offset: offset,
    );
    return transactionModels.map((model) => model.toEntity()).toList();
  }

  @override
  Future<LedgerTransaction> createTransaction(LedgerTransaction transaction) async {
    final transactionModel = LedgerTransactionModel.fromEntity(transaction);
    final createdModel = await _remoteDataSource.createTransaction(transactionModel);
    return createdModel.toEntity();
  }

  @override
  Future<InvestmentSummary?> getInvestmentSummary(String walletId) async {
    final summaryModel = await _remoteDataSource.getInvestmentSummary(walletId);
    return summaryModel?.toEntity();
  }

  @override
  Future<List<Wallet>> searchWallets(String userId, String query) async {
    final walletModels = await _remoteDataSource.searchWallets(userId, query);
    return walletModels.map((model) => model.toEntity()).toList();
  }

  @override
  Future<List<Wallet>> getWalletsByType(String userId, WalletType type) async {
    final walletModels = await _remoteDataSource.getWalletsByType(userId, type.name);
    return walletModels.map((model) => model.toEntity()).toList();
  }

  @override
  Future<List<Wallet>> getActiveWallets(String userId) async {
    final walletModels = await _remoteDataSource.getActiveWallets(userId);
    return walletModels.map((model) => model.toEntity()).toList();
  }

  @override
  Future<void> topUpWallet(String walletId, int amountMinorUnits, String description) async {
    await _remoteDataSource.topUpWallet(walletId, amountMinorUnits, description);
  }

  @override
  Future<void> withdrawWallet(String walletId, int amountMinorUnits, String description) async {
    await _remoteDataSource.withdrawWallet(walletId, amountMinorUnits, description);
  }
}
