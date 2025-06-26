import '../entities/installment.dart';
import '../entities/installment_payment.dart';

abstract class InstallmentRepository {
  Future<List<Installment>> getAllInstallments(String userId);
  Future<Installment?> getInstallmentById(String id);
  Future<String> createInstallment(Installment installment);
  Future<void> updateInstallment(Installment installment);
  Future<void> deleteInstallment(String id);
  Future<List<Installment>> searchInstallments(String userId, String query);
  Future<List<Installment>> getInstallmentsByClientId(String clientId);
  Future<List<Installment>> getInstallmentsByInvestorId(String investorId);
  
  // Payment operations
  Future<List<InstallmentPayment>> getPaymentsByInstallmentId(String installmentId);
  Future<InstallmentPayment?> getPaymentById(String id);
  Future<String> createPayment(InstallmentPayment payment);
  Future<void> updatePayment(InstallmentPayment payment);
  Future<void> deletePayment(String id);
  Future<List<InstallmentPayment>> getOverduePayments(String userId);
  Future<List<InstallmentPayment>> getDuePayments(String userId);
} 