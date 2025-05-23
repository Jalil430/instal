class Client {
  final String id;
  final String userId;
  final String fullName;
  final String contactNumber;
  final String passportNumber;
  final String address;
  final DateTime createdAt;

  Client({
    required this.id,
    required this.userId,
    required this.fullName,
    required this.contactNumber,
    required this.passportNumber,
    required this.address,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'fullName': fullName,
      'contactNumber': contactNumber,
      'passportNumber': passportNumber,
      'address': address,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Client.fromMap(Map<String, dynamic> map) {
    return Client(
      id: map['id'] as String,
      userId: map['userId'] as String,
      fullName: map['fullName'] as String,
      contactNumber: map['contactNumber'] as String,
      passportNumber: map['passportNumber'] as String,
      address: map['address'] as String,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }

  Client copyWith({
    String? id,
    String? userId,
    String? fullName,
    String? contactNumber,
    String? passportNumber,
    String? address,
    DateTime? createdAt,
  }) {
    return Client(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      fullName: fullName ?? this.fullName,
      contactNumber: contactNumber ?? this.contactNumber,
      passportNumber: passportNumber ?? this.passportNumber,
      address: address ?? this.address,
      createdAt: createdAt ?? this.createdAt,
    );
  }
} 