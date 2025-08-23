import '../models/wallet_model.dart';
import '../models/wallet_balance_model.dart';
import '../models/ledger_transaction_model.dart';
import '../models/investment_summary_model.dart';

abstract class WalletRemoteDataSource {
  Future<List<WalletModel>> getAllWallets(String userId);
  Future<WalletModel?> getWalletById(String walletId);
  Future<WalletModel> createWallet(WalletModel wallet);
  Future<WalletModel> updateWallet(WalletModel wallet);
  Future<void> deleteWallet(String walletId);
  Future<void> archiveWallet(String walletId);

  Future<WalletBalanceModel?> getWalletBalance(String walletId);
  Future<List<WalletBalanceModel>> getAllWalletBalances(String userId);

  Future<List<LedgerTransactionModel>> getWalletTransactions(
    String walletId, {
    DateTime? fromDate,
    DateTime? toDate,
    int? limit,
    int? offset,
  });
  Future<LedgerTransactionModel> createTransaction(LedgerTransactionModel transaction);

  Future<InvestmentSummaryModel?> getInvestmentSummary(String walletId);

  Future<List<WalletModel>> searchWallets(String userId, String query);
  Future<List<WalletModel>> getWalletsByType(String userId, String type);
  Future<List<WalletModel>> getActiveWallets(String userId);
}
