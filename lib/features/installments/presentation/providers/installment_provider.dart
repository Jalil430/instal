import 'package:flutter/foundation.dart';
import '../../domain/entities/installment.dart';
import '../../domain/entities/installment_payment.dart';
import '../../domain/usecases/get_all_installments.dart';
import '../../domain/usecases/create_installment.dart';
import '../../domain/usecases/get_installment_payments.dart';
import '../../domain/usecases/register_payment.dart';
import '../../domain/repositories/installment_repository.dart';

class InstallmentProvider extends ChangeNotifier {
  final InstallmentRepository _repository;
  late final GetAllInstallments _getAllInstallments;
  late final CreateInstallment _createInstallment;
  late final GetInstallmentPayments _getInstallmentPayments;
  late final RegisterPayment _registerPayment;

  InstallmentProvider(this._repository) {
    _getAllInstallments = GetAllInstallments(_repository);
    _createInstallment = CreateInstallment(_repository);
    _getInstallmentPayments = GetInstallmentPayments(_repository);
    _registerPayment = RegisterPayment(_repository);
  }

  List<Installment> _installments = [];
  List<Installment> _filteredInstallments = [];
  Map<String, List<InstallmentPayment>> _installmentPayments = {};
  bool _isLoading = false;
  String? _error;
  String _searchQuery = '';

  List<Installment> get installments => _filteredInstallments.isEmpty && _searchQuery.isEmpty 
      ? _installments 
      : _filteredInstallments;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get searchQuery => _searchQuery;
  bool get hasInstallments => _installments.isNotEmpty;

  Future<void> loadInstallments(String userId) async {
    _setLoading(true);
    _setError(null);

    try {
      _installments = await _getAllInstallments(userId);
      if (_searchQuery.isNotEmpty) {
        await _performSearch(userId, _searchQuery);
      } else {
        _filteredInstallments = [];
      }
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<void> createInstallment(Installment installment) async {
    _setLoading(true);
    _setError(null);

    try {
      await _createInstallment(
        userId: installment.userId,
        clientId: installment.clientId,
        investorId: installment.investorId,
        productName: installment.productName,
        cashPrice: installment.cashPrice,
        installmentPrice: installment.installmentPrice,
        termMonths: installment.termMonths,
        downPayment: installment.downPayment,
        monthlyPayment: installment.monthlyPayment,
        downPaymentDate: installment.downPaymentDate,
        installmentStartDate: installment.installmentStartDate,
      );
      await loadInstallments(installment.userId);
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
    }
  }

  Future<void> deleteInstallment(String installmentId, String userId) async {
    _setLoading(true);
    _setError(null);

    try {
      await _repository.deleteInstallment(installmentId);
      await loadInstallments(userId);
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
    }
  }

  Future<List<InstallmentPayment>> getInstallmentPayments(String installmentId) async {
    try {
      if (_installmentPayments.containsKey(installmentId)) {
        return _installmentPayments[installmentId]!;
      }
      
      final payments = await _getInstallmentPayments(installmentId);
      _installmentPayments[installmentId] = payments;
      return payments;
    } catch (e) {
      _setError(e.toString());
      return [];
    }
  }

  Future<void> registerPayment({
    required String paymentId,
    required double paidAmount,
    required DateTime paidDate,
    required String installmentId,
  }) async {
    _setLoading(true);
    _setError(null);

    try {
      await _registerPayment(
        paymentId: paymentId,
        paidAmount: paidAmount,
        paidDate: paidDate,
      );
      
      // Refresh payments for this installment
      final payments = await _getInstallmentPayments(installmentId);
      _installmentPayments[installmentId] = payments;
      
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<void> searchInstallments(String userId, String query) async {
    _searchQuery = query;
    
    if (query.trim().isEmpty) {
      _filteredInstallments = [];
      notifyListeners();
      return;
    }

    _setLoading(true);
    _setError(null);

    try {
      await _performSearch(userId, query);
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _performSearch(String userId, String query) async {
    // Simple search by product name for now
    _filteredInstallments = _installments.where((installment) =>
        installment.productName.toLowerCase().contains(query.toLowerCase())).toList();
  }

  void clearSearch() {
    _searchQuery = '';
    _filteredInstallments = [];
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String? error) {
    _error = error;
    notifyListeners();
  }

  Installment? getInstallmentById(String id) {
    try {
      return _installments.firstWhere((installment) => installment.id == id);
    } catch (e) {
      return null;
    }
  }

  void sortInstallments(InstallmentSortOption sortOption) {
    switch (sortOption) {
      case InstallmentSortOption.createdDateNewest:
        _installments.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        _filteredInstallments.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case InstallmentSortOption.createdDateOldest:
        _installments.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        _filteredInstallments.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        break;
      case InstallmentSortOption.amountHighest:
        _installments.sort((a, b) => b.installmentPrice.compareTo(a.installmentPrice));
        _filteredInstallments.sort((a, b) => b.installmentPrice.compareTo(a.installmentPrice));
        break;
      case InstallmentSortOption.amountLowest:
        _installments.sort((a, b) => a.installmentPrice.compareTo(b.installmentPrice));
        _filteredInstallments.sort((a, b) => a.installmentPrice.compareTo(b.installmentPrice));
        break;
      case InstallmentSortOption.statusPaid:
        // TODO: Implement status-based sorting
        break;
      case InstallmentSortOption.statusOverdue:
        // TODO: Implement status-based sorting
        break;
    }
    notifyListeners();
  }

  // Helper methods for calculating installment statistics
  double getTotalPaidAmount(String installmentId) {
    final payments = _installmentPayments[installmentId];
    if (payments == null) return 0.0;
    
    return payments.fold(0.0, (sum, payment) => sum + payment.paidAmount);
  }

  double getRemainingAmount(String installmentId) {
    final installment = getInstallmentById(installmentId);
    if (installment == null) return 0.0;
    
    final totalPaid = getTotalPaidAmount(installmentId);
    return installment.installmentPrice - totalPaid;
  }

  InstallmentPayment? getNextPayment(String installmentId) {
    final payments = _installmentPayments[installmentId];
    if (payments == null) return null;
    
    // Find the next unpaid payment
    final unpaidPayments = payments.where((payment) => !payment.isPaid).toList();
    if (unpaidPayments.isEmpty) return null;
    
    // Sort by due date and return the earliest
    unpaidPayments.sort((a, b) => a.dueDate.compareTo(b.dueDate));
    return unpaidPayments.first;
  }

  Future<List<InstallmentPayment>> getPaymentsByInstallmentId(String installmentId) async {
    return getInstallmentPayments(installmentId);
  }

  Future<List<Installment>> getInstallmentsByClientId(String clientId) async {
    _setLoading(true);
    _setError(null);

    try {
      final clientInstallments = _installments.where(
        (installment) => installment.clientId == clientId
      ).toList();
      
      _setLoading(false);
      return clientInstallments;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return [];
    }
  }

  Future<List<Installment>> getInstallmentsByInvestorId(String investorId) async {
    _setLoading(true);
    _setError(null);

    try {
      final investorInstallments = _installments.where(
        (installment) => installment.investorId == investorId
      ).toList();
      
      _setLoading(false);
      return investorInstallments;
    } catch (e) {
      _setError(e.toString());
      _setLoading(false);
      return [];
    }
  }

  Future<void> updatePayment(InstallmentPayment payment) async {
    _setLoading(true);
    _setError(null);

    try {
      await _registerPayment(
        paymentId: payment.id,
        paidAmount: payment.paidAmount,
        paidDate: payment.paidDate!,
      );
      
      // Refresh payments for this installment
      final payments = await _getInstallmentPayments(payment.installmentId);
      _installmentPayments[payment.installmentId] = payments;
      
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }
}

enum InstallmentSortOption {
  createdDateNewest,
  createdDateOldest,
  amountHighest,
  amountLowest,
  statusPaid,
  statusOverdue,
} 