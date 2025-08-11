import '../../domain/entities/client.dart';

class ClientModel extends Client {
  const ClientModel({
    required super.id,
    required super.userId,
    required super.fullName,
    required super.contactNumber,
    required super.passportNumber,
    super.address,
    super.guarantorFullName,
    super.guarantorContactNumber,
    super.guarantorPassportNumber,
    super.guarantorAddress,
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
      address: map['address'] as String?,
      guarantorFullName: map['guarantor_full_name'] as String?,
      guarantorContactNumber: map['guarantor_contact_number'] as String?,
      guarantorPassportNumber: map['guarantor_passport_number'] as String?,
      guarantorAddress: map['guarantor_address'] as String?,
      createdAt: _parseDateTime(map['created_at']),
      updatedAt: _parseDateTime(map['updated_at']),
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
      guarantorFullName: client.guarantorFullName,
      guarantorContactNumber: client.guarantorContactNumber,
      guarantorPassportNumber: client.guarantorPassportNumber,
      guarantorAddress: client.guarantorAddress,
      createdAt: client.createdAt,
      updatedAt: client.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    final map = {
      'id': id,
      'user_id': userId,
      'full_name': fullName,
      'contact_number': contactNumber,
      'passport_number': passportNumber,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
    
    if (address != null) {
      map['address'] = address!;
    }
    if (guarantorFullName != null) {
      map['guarantor_full_name'] = guarantorFullName!;
    }
    if (guarantorContactNumber != null) {
      map['guarantor_contact_number'] = guarantorContactNumber!;
    }
    if (guarantorPassportNumber != null) {
      map['guarantor_passport_number'] = guarantorPassportNumber!;
    }
    if (guarantorAddress != null) {
      map['guarantor_address'] = guarantorAddress!;
    }
    
    return map;
  }

  // For API requests, we need to format data properly
  Map<String, dynamic> toApiMap() {
    final map = {
      'user_id': userId,
      'full_name': fullName,
      'contact_number': contactNumber,
      'passport_number': passportNumber,
    };
    
    if (address != null) {
      // Replace newlines with spaces to prevent JSON parsing issues
      map['address'] = address!.replaceAll('\n', ' ').replaceAll('\r', ' ');
    }
    if (guarantorFullName != null) {
      map['guarantor_full_name'] = guarantorFullName!;
    }
    if (guarantorContactNumber != null) {
      map['guarantor_contact_number'] = guarantorContactNumber!;
    }
    if (guarantorPassportNumber != null) {
      map['guarantor_passport_number'] = guarantorPassportNumber!;
    }
    if (guarantorAddress != null) {
      map['guarantor_address'] = guarantorAddress!;
    }
    
    return map;
  }

  static DateTime _parseDateTime(dynamic value) {
    if (value is int) {
      // Local database format (milliseconds since epoch)
      return DateTime.fromMillisecondsSinceEpoch(value);
    } else if (value is String) {
      // API format (ISO string)
      return DateTime.parse(value);
    } else {
      throw ArgumentError('Invalid datetime format: $value');
    }
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
    String? guarantorFullName,
    String? guarantorContactNumber,
    String? guarantorPassportNumber,
    String? guarantorAddress,
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
      guarantorFullName: guarantorFullName ?? this.guarantorFullName,
      guarantorContactNumber: guarantorContactNumber ?? this.guarantorContactNumber,
      guarantorPassportNumber: guarantorPassportNumber ?? this.guarantorPassportNumber,
      guarantorAddress: guarantorAddress ?? this.guarantorAddress,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
} 