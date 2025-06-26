import 'package:uuid/uuid.dart';
import '../entities/client.dart';
import '../repositories/client_repository.dart';

class CreateClient {
  final ClientRepository _repository;
  final Uuid _uuid = const Uuid();

  CreateClient(this._repository);

  Future<String> call({
    required String userId,
    required String fullName,
    required String contactNumber,
    required String passportNumber,
    required String address,
  }) async {
    // Validate input
    if (fullName.trim().isEmpty) {
      throw ArgumentError('Full name cannot be empty');
    }
    if (contactNumber.trim().isEmpty) {
      throw ArgumentError('Contact number cannot be empty');
    }
    if (passportNumber.trim().isEmpty) {
      throw ArgumentError('Passport number cannot be empty');
    }
    if (address.trim().isEmpty) {
      throw ArgumentError('Address cannot be empty');
    }

    final now = DateTime.now();
    final client = Client(
      id: _uuid.v4(),
      userId: userId,
      fullName: fullName.trim(),
      contactNumber: contactNumber.trim(),
      passportNumber: passportNumber.trim(),
      address: address.trim(),
      createdAt: now,
      updatedAt: now,
    );

    return await _repository.createClient(client);
  }
} 