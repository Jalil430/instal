import '../../domain/entities/wallet.dart';
import '../../domain/entities/wallet_balance.dart';
import '../../domain/entities/ledger_transaction.dart';
import '../../domain/entities/investment_summary.dart';

abstract class WalletRepository {
  // Wallet CRUD operations
  Future<List<Wallet>> getAllWallets(String userId);
  Future<Wallet?> getWalletById(String walletId);
  Future<Wallet> createWallet(Wallet wallet);
  Future<Wallet> updateWallet(Wallet wallet);
  Future<void> deleteWallet(String walletId);
  Future<void> archiveWallet(String walletId);

  // Wallet balance operations
  Future<WalletBalance?> getWalletBalance(String walletId);
  Future<List<WalletBalance>> getAllWalletBalances(String userId);

  // Transaction operations
  Future<List<LedgerTransaction>> getWalletTransactions(
    String walletId, {
    DateTime? fromDate,
    DateTime? toDate,
    int? limit,
    int? offset,
  });
  Future<LedgerTransaction> createTransaction(LedgerTransaction transaction);

  // Investment calculations
  Future<InvestmentSummary?> getInvestmentSummary(String walletId);

  // Search and filtering
  Future<List<Wallet>> searchWallets(String userId, String query);
  Future<List<Wallet>> getWalletsByType(String userId, WalletType type);
  Future<List<Wallet>> getActiveWallets(String userId);
}
