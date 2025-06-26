import '../entities/installment.dart';
import '../entities/installment_payment.dart';
import '../repositories/installment_repository.dart';

class CreateInstallment {
  final InstallmentRepository repository;

  CreateInstallment(this.repository);

  Future<void> call({
    required String userId,
    required String clientId,
    required String investorId,
    required String productName,
    required double cashPrice,
    required double installmentPrice,
    required int termMonths,
    required double downPayment,
    required double monthlyPayment,
    required DateTime downPaymentDate,
    required DateTime installmentStartDate,
  }) async {
    final installmentId = DateTime.now().millisecondsSinceEpoch.toString();
    
    // Calculate installment end date
    final installmentEndDate = DateTime(
      installmentStartDate.year,
      installmentStartDate.month + termMonths,
      installmentStartDate.day,
    );

    final installment = Installment(
      id: installmentId,
      userId: userId,
      clientId: clientId,
      investorId: investorId,
      productName: productName,
      cashPrice: cashPrice,
      installmentPrice: installmentPrice,
      termMonths: termMonths,
      downPayment: downPayment,
      monthlyPayment: monthlyPayment,
      downPaymentDate: downPaymentDate,
      installmentStartDate: installmentStartDate,
      installmentEndDate: installmentEndDate,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    // Generate payment schedule
    final payments = _generatePaymentSchedule(
      installmentId: installmentId,
      downPayment: downPayment,
      monthlyPayment: monthlyPayment,
      downPaymentDate: downPaymentDate,
      installmentStartDate: installmentStartDate,
      termMonths: termMonths,
    );

    await repository.createInstallment(installment);
    
    // Create all payments using the correct method name
    for (final payment in payments) {
      await repository.createPayment(payment);
    }
  }

  List<InstallmentPayment> _generatePaymentSchedule({
    required String installmentId,
    required double downPayment,
    required double monthlyPayment,
    required DateTime downPaymentDate,
    required DateTime installmentStartDate,
    required int termMonths,
  }) {
    final payments = <InstallmentPayment>[];
    final now = DateTime.now();

    // Create down payment if there is one
    if (downPayment > 0) {
      final downPaymentStatus = _calculatePaymentStatus(downPaymentDate, now);
      payments.add(InstallmentPayment(
        id: '${installmentId}_0',
        installmentId: installmentId,
        paymentNumber: 0,
        dueDate: downPaymentDate,
        expectedAmount: downPayment,
        paidAmount: 0,
        status: downPaymentStatus,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));
    }

    // Create monthly payments
    for (int i = 1; i <= termMonths; i++) {
      final dueDate = DateTime(
        installmentStartDate.year,
        installmentStartDate.month + i - 1,
        installmentStartDate.day,
      );
      
      final status = _calculatePaymentStatus(dueDate, now);
      
      payments.add(InstallmentPayment(
        id: '${installmentId}_$i',
        installmentId: installmentId,
        paymentNumber: i,
        dueDate: dueDate,
        expectedAmount: monthlyPayment,
        paidAmount: 0,
        status: status,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));
    }

    return payments;
  }

  String _calculatePaymentStatus(DateTime dueDate, DateTime now) {
    final difference = dueDate.difference(now).inDays;
    
    if (difference < -2) {
      return 'просрочено'; // Overdue (more than 2 days past due)
    } else if (difference <= 0) {
      return 'к оплате'; // Due (today or yesterday)
    } else {
      return 'предстоящий'; // Upcoming
    }
  }
} 