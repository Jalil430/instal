import '../../domain/entities/installment.dart';
import '../../domain/entities/installment_payment.dart';
import '../../domain/repositories/installment_repository.dart';
import '../datasources/installment_local_datasource.dart';
import '../models/installment_model.dart';
import '../models/installment_payment_model.dart';

class InstallmentRepositoryImpl implements InstallmentRepository {
  final InstallmentLocalDataSource _localDataSource;

  InstallmentRepositoryImpl(this._localDataSource);

  @override
  Future<List<Installment>> getAllInstallments(String userId) async {
    final installmentModels = await _localDataSource.getAllInstallments(userId);
    return installmentModels.cast<Installment>();
  }

  @override
  Future<Installment?> getInstallmentById(String id) async {
    final installmentModel = await _localDataSource.getInstallmentById(id);
    return installmentModel;
  }

  @override
  Future<String> createInstallment(Installment installment) async {
    final installmentModel = InstallmentModel.fromEntity(installment);
    return await _localDataSource.createInstallment(installmentModel);
  }

  @override
  Future<void> updateInstallment(Installment installment) async {
    final installmentModel = InstallmentModel.fromEntity(installment);
    await _localDataSource.updateInstallment(installmentModel);
  }

  @override
  Future<void> deleteInstallment(String id) async {
    await _localDataSource.deleteInstallment(id);
  }

  @override
  Future<List<Installment>> searchInstallments(String userId, String query) async {
    final installmentModels = await _localDataSource.searchInstallments(userId, query);
    return installmentModels.cast<Installment>();
  }

  @override
  Future<List<Installment>> getInstallmentsByClientId(String clientId) async {
    final installmentModels = await _localDataSource.getInstallmentsByClientId(clientId);
    return installmentModels.cast<Installment>();
  }

  @override
  Future<List<Installment>> getInstallmentsByInvestorId(String investorId) async {
    final installmentModels = await _localDataSource.getInstallmentsByInvestorId(investorId);
    return installmentModels.cast<Installment>();
  }

  // Payment operations
  @override
  Future<List<InstallmentPayment>> getPaymentsByInstallmentId(String installmentId) async {
    final paymentModels = await _localDataSource.getPaymentsByInstallmentId(installmentId);
    return paymentModels.cast<InstallmentPayment>();
  }

  @override
  Future<InstallmentPayment?> getPaymentById(String id) async {
    final paymentModel = await _localDataSource.getPaymentById(id);
    return paymentModel;
  }

  @override
  Future<String> createPayment(InstallmentPayment payment) async {
    final paymentModel = InstallmentPaymentModel.fromEntity(payment);
    return await _localDataSource.createPayment(paymentModel);
  }

  @override
  Future<void> updatePayment(InstallmentPayment payment) async {
    final paymentModel = InstallmentPaymentModel.fromEntity(payment);
    await _localDataSource.updatePayment(paymentModel);
  }

  @override
  Future<void> deletePayment(String id) async {
    await _localDataSource.deletePayment(id);
  }

  @override
  Future<List<InstallmentPayment>> getOverduePayments(String userId) async {
    final paymentModels = await _localDataSource.getOverduePayments(userId);
    return paymentModels.cast<InstallmentPayment>();
  }

  @override
  Future<List<InstallmentPayment>> getDuePayments(String userId) async {
    final paymentModels = await _localDataSource.getDuePayments(userId);
    return paymentModels.cast<InstallmentPayment>();
  }
} 