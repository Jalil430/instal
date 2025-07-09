import '../entities/user.dart';
import '../repositories/auth_repository.dart';

class UpdateUser {
  final AuthRepository repository;

  UpdateUser(this.repository);

  Future<User> call({
    required String userId,
    String? fullName,
    String? phone,
  }) async {
    return await repository.updateUser(
      userId: userId,
      fullName: fullName,
      phone: phone,
    );
  }
} 