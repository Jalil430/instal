import '../../domain/entities/installment.dart';
import '../../domain/entities/installment_payment.dart';
import '../../domain/repositories/installment_repository.dart';
import '../datasources/installment_remote_datasource.dart';
import '../models/installment_model.dart';
import '../models/installment_payment_model.dart';
import '../../../../core/api/api_client.dart';

class InstallmentRepositoryImpl implements InstallmentRepository {
  final InstallmentRemoteDataSource _remoteDataSource;

  InstallmentRepositoryImpl(this._remoteDataSource);

  @override
  Future<List<Installment>> getAllInstallments(String userId) async {
    final installmentModels = await _remoteDataSource.getAllInstallments(userId);
    return installmentModels.cast<Installment>();
  }

  @override
  Future<Installment?> getInstallmentById(String id) async {
    final installmentModel = await _remoteDataSource.getInstallmentById(id);
    return installmentModel;
  }

  @override
  Future<String> createInstallment(Installment installment) async {
    final installmentModel = InstallmentModel.fromEntity(installment);
    return await _remoteDataSource.createInstallment(installmentModel);
  }

  @override
  Future<void> updateInstallment(Installment installment) async {
    final installmentModel = InstallmentModel.fromEntity(installment);
    await _remoteDataSource.updateInstallment(installmentModel);
  }

  @override
  Future<void> deleteInstallment(String id) async {
    await _remoteDataSource.deleteInstallment(id);
  }

  @override
  Future<List<Installment>> searchInstallments(String userId, String query) async {
    final installmentModels = await _remoteDataSource.searchInstallments(userId, query);
    return installmentModels.cast<Installment>();
  }

  @override
  Future<List<Installment>> getInstallmentsByClientId(String clientId) async {
    final installmentModels = await _remoteDataSource.getInstallmentsByClientId(clientId);
    return installmentModels.cast<Installment>();
  }

  @override
  Future<List<Installment>> getInstallmentsByInvestorId(String investorId) async {
    final installmentModels = await _remoteDataSource.getInstallmentsByInvestorId(investorId);
    return installmentModels.cast<Installment>();
  }

  // Payment operations
  @override
  Future<List<InstallmentPayment>> getPaymentsByInstallmentId(String installmentId) async {
    final paymentModels = await _remoteDataSource.getPaymentsByInstallmentId(installmentId);
    return paymentModels.cast<InstallmentPayment>();
  }

  @override
  Future<InstallmentPayment?> getPaymentById(String id) async {
    try {
      final paymentModel = await _remoteDataSource.getPaymentById(id);
    return paymentModel;
    } on UnimplementedError {
      // For now, return null since this endpoint isn't implemented
      return null;
    }
  }

  @override
  Future<String> createPayment(InstallmentPayment payment) async {
    try {
    final paymentModel = InstallmentPaymentModel.fromEntity(payment);
      return await _remoteDataSource.createPayment(paymentModel);
    } on UnimplementedError {
      // Return the payment ID since payments are created with installments
      return payment.id;
    }
  }

  @override
  Future<Installment> updatePayment(InstallmentPayment payment) async {
    final paymentModel = InstallmentPaymentModel.fromEntity(payment);
    final updatedInstallmentModel = await _remoteDataSource.updatePayment(paymentModel);
    
    // InstallmentModel extends Installment, so we can return it directly
    return updatedInstallmentModel;
  }

  @override
  Future<void> deletePayment(String id) async {
    try {
      await _remoteDataSource.deletePayment(id);
    } on UnimplementedError {
      // Payment deletion not implemented in API
      throw UnsupportedError('Payment deletion not supported');
    }
  }

  @override
  Future<List<InstallmentPayment>> getOverduePayments(String userId) async {
    try {
      final paymentModels = await _remoteDataSource.getOverduePayments(userId);
    return paymentModels.cast<InstallmentPayment>();
    } on UnimplementedError {
      // For now, we'll need to filter on client side
      final installments = await getAllInstallments(userId);
      final List<InstallmentPayment> allPayments = [];
      
      for (final installment in installments) {
        final payments = await getPaymentsByInstallmentId(installment.id);
        allPayments.addAll(payments);
      }
      
      final now = DateTime.now();
      return allPayments.where((payment) => 
        !payment.isPaid && payment.dueDate.isBefore(now)
      ).toList();
    }
  }

  @override
  Future<List<InstallmentPayment>> getDuePayments(String userId) async {
    try {
      final paymentModels = await _remoteDataSource.getDuePayments(userId);
    return paymentModels.cast<InstallmentPayment>();
    } on UnimplementedError {
      // For now, we'll need to filter on client side
      final installments = await getAllInstallments(userId);
      final List<InstallmentPayment> allPayments = [];
      
      for (final installment in installments) {
        final payments = await getPaymentsByInstallmentId(installment.id);
        allPayments.addAll(payments);
      }
      
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      
      return allPayments.where((payment) => 
        !payment.isPaid && 
        DateTime(payment.dueDate.year, payment.dueDate.month, payment.dueDate.day)
          .isBefore(today.add(const Duration(days: 1)))
      ).toList();
    }
  }

  @override
  Future<List<InstallmentPayment>> getAllPayments(String userId) async {
    try {
      final paymentModels = await _remoteDataSource.getAllPayments(userId);
    return paymentModels.cast<InstallmentPayment>();
    } on UnimplementedError {
      // For now, we'll need to fetch all installments and their payments
      final installments = await getAllInstallments(userId);
      final List<InstallmentPayment> allPayments = [];
      
      for (final installment in installments) {
        final payments = await getPaymentsByInstallmentId(installment.id);
        allPayments.addAll(payments);
      }
      
      return allPayments;
    }
  }
} 