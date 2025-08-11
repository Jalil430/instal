class Client {
  final String id;
  final String userId;
  final String fullName;
  final String contactNumber;
  final String passportNumber;
  final String? address;
  final String? guarantorFullName;
  final String? guarantorContactNumber;
  final String? guarantorPassportNumber;
  final String? guarantorAddress;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Client({
    required this.id,
    required this.userId,
    required this.fullName,
    required this.contactNumber,
    required this.passportNumber,
    this.address,
    this.guarantorFullName,
    this.guarantorContactNumber,
    this.guarantorPassportNumber,
    this.guarantorAddress,
    required this.createdAt,
    required this.updatedAt,
  });

  Client copyWith({
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
    return Client(
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

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Client && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'Client(id: $id, fullName: $fullName, contactNumber: $contactNumber)';
  }
} 