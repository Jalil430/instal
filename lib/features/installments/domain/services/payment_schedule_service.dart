import 'package:uuid/uuid.dart';
import '../entities/installment.dart';
import '../entities/installment_payment.dart';

class PaymentScheduleService {
  static const Uuid _uuid = Uuid();

  /// Generate payment schedule for an installment
  static List<InstallmentPayment> generatePaymentSchedule(Installment installment) {
    final List<InstallmentPayment> payments = [];
    final now = DateTime.now();

    // Generate down payment (payment number 0)
    if (installment.downPayment > 0) {
      payments.add(InstallmentPayment(
        id: _uuid.v4(),
        installmentId: installment.id,
        paymentNumber: 0,
        dueDate: installment.downPaymentDate,
        expectedAmount: installment.downPayment,
        paidAmount: 0.0,
        status: 'предстоящий',
        createdAt: now,
        updatedAt: now,
      ));
    }

    // Generate monthly payments (payment numbers 1 to termMonths)
    for (int i = 1; i <= installment.termMonths; i++) {
      final dueDate = DateTime(
        installment.installmentStartDate.year,
        installment.installmentStartDate.month + i - 1,
        installment.installmentStartDate.day,
      );

      payments.add(InstallmentPayment(
        id: _uuid.v4(),
        installmentId: installment.id,
        paymentNumber: i,
        dueDate: dueDate,
        expectedAmount: installment.monthlyPayment,
        paidAmount: 0.0,
        status: 'предстоящий',
        createdAt: now,
        updatedAt: now,
      ));
    }

    return payments;
  }

  /// Calculate installment end date based on start date and term
  static DateTime calculateInstallmentEndDate(DateTime startDate, int termMonths) {
    return DateTime(
      startDate.year,
      startDate.month + termMonths,
      startDate.day,
    );
  }

  /// Calculate monthly payment amount
  static double calculateMonthlyPayment({
    required double installmentPrice,
    required double downPayment,
    required int termMonths,
  }) {
    if (termMonths <= 0) {
      throw ArgumentError('Term months must be greater than 0');
    }
    
    final remainingAmount = installmentPrice - downPayment;
    return remainingAmount / termMonths;
  }

  /// Validate installment data before creating payment schedule
  static void validateInstallmentData(Installment installment) {
    if (installment.termMonths <= 0) {
      throw ArgumentError('Term months must be greater than 0');
    }
    
    if (installment.installmentPrice <= 0) {
      throw ArgumentError('Installment price must be greater than 0');
    }
    
    if (installment.downPayment < 0) {
      throw ArgumentError('Down payment cannot be negative');
    }
    
    if (installment.downPayment >= installment.installmentPrice) {
      throw ArgumentError('Down payment cannot be greater than or equal to installment price');
    }
    
    if (installment.monthlyPayment <= 0) {
      throw ArgumentError('Monthly payment must be greater than 0');
    }
    
    if (installment.installmentStartDate.isBefore(installment.downPaymentDate)) {
      throw ArgumentError('Installment start date cannot be before down payment date');
    }
  }

  /// Calculate total expected payment amount
  static double calculateTotalExpectedAmount(Installment installment) {
    return installment.downPayment + (installment.monthlyPayment * installment.termMonths);
  }

  /// Check if payment amounts are consistent
  static bool isPaymentAmountConsistent(Installment installment) {
    final totalExpected = calculateTotalExpectedAmount(installment);
    const tolerance = 0.01; // Allow small rounding differences
    return (totalExpected - installment.installmentPrice).abs() <= tolerance;
  }

  /// Recalculate payment schedule if installment is modified
  static List<InstallmentPayment> recalculatePaymentSchedule(
    Installment installment,
    List<InstallmentPayment> existingPayments,
  ) {
    // Keep paid payments as they are
    final paidPayments = existingPayments.where((payment) => payment.isPaid).toList();
    
    // Generate new schedule
    final newSchedule = generatePaymentSchedule(installment);
    
    // Merge paid payments with new schedule
    final mergedPayments = <InstallmentPayment>[];
    
    for (final newPayment in newSchedule) {
      final existingPaidPayment = paidPayments.firstWhere(
        (paid) => paid.paymentNumber == newPayment.paymentNumber,
        orElse: () => newPayment,
      );
      
      if (existingPaidPayment.isPaid) {
        mergedPayments.add(existingPaidPayment);
      } else {
        mergedPayments.add(newPayment);
      }
    }
    
    return mergedPayments;
  }
} 