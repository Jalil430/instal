import '../entities/installment_payment.dart';
import '../repositories/installment_repository.dart';

class GetInstallmentPayments {
  final InstallmentRepository repository;

  GetInstallmentPayments(this.repository);

  Future<List<InstallmentPayment>> call(String installmentId) async {
    return await repository.getPaymentsByInstallmentId(installmentId);
  }
} 