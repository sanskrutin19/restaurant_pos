class Room {
  final int id;
  final String roomNumber;
  final String? floor;
  final String? guestName;
  final String status;
  final double serviceCharge;
  final bool isActive;

  Room({
    required this.id,
    required this.roomNumber,
    this.floor,
    this.guestName,
    required this.status,
    required this.serviceCharge,
    required this.isActive,
  });

  factory Room.fromJson(Map<String, dynamic> json) {
    return Room(
      id: json['id'],
      roomNumber: json['room_number'],
      floor: json['floor'],
      guestName: json['guest_name'],
      status: json['status'] ?? 'available',
      serviceCharge: (json['service_charge'] as num?)?.toDouble() ?? 0.0,
      isActive: json['is_active'] ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'room_number': roomNumber,
        'floor': floor,
        'guest_name': guestName,
        'status': status,
        'service_charge': serviceCharge,
        'is_active': isActive,
      };
}
