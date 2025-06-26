import '../../domain/entities/client.dart';

class ClientModel extends Client {
  const ClientModel({
    required super.id,
    required super.userId,
    required super.fullName,
    required super.contactNumber,
    required super.passportNumber,
    required super.address,
    required super.createdAt,
    required super.updatedAt,
  });

  factory ClientModel.fromMap(Map<String, dynamic> map) {
    return ClientModel(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      fullName: map['full_name'] as String,
      contactNumber: map['contact_number'] as String,
      passportNumber: map['passport_number'] as String,
      address: map['address'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
    );
  }

  factory ClientModel.fromEntity(Client client) {
    return ClientModel(
      id: client.id,
      userId: client.userId,
      fullName: client.fullName,
      contactNumber: client.contactNumber,
      passportNumber: client.passportNumber,
      address: client.address,
      createdAt: client.createdAt,
      updatedAt: client.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'full_name': fullName,
      'contact_number': contactNumber,
      'passport_number': passportNumber,
      'address': address,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  @override
  String toString() {
    return 'ClientModel(id: $id, fullName: $fullName, contactNumber: $contactNumber)';
  }

  @override
  ClientModel copyWith({
    String? id,
    String? userId,
    String? fullName,
    String? contactNumber,
    String? passportNumber,
    String? address,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ClientModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      fullName: fullName ?? this.fullName,
      contactNumber: contactNumber ?? this.contactNumber,
      passportNumber: passportNumber ?? this.passportNumber,
      address: address ?? this.address,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
} 