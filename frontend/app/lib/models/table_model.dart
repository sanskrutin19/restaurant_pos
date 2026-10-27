enum TableStatus { Available, Occupied, Billing, Reserved, Held, Preparing, Ready }

class TableModel {
  final int id;
  final String name;
  final TableStatus status;
  final int capacity;
  final String section;
  final bool isReserved;
  final String? reservedFor;

  TableModel({
    required this.id,
    required this.name,
    required this.status,
    this.capacity = 4,
    this.section = 'Main',
    this.isReserved = false,
    this.reservedFor,
  });

  factory TableModel.fromJson(Map<String, dynamic> json) {
    return TableModel(
      id: json['id'],
      name: json['name'] ?? json['id'].toString(),
      status: parseStatus(json['status'] ?? 'Available'),
      capacity: json['capacity'] ?? 4,
      section: json['section'] ?? 'Main',
      isReserved: json['is_reserved'] ?? false,
      reservedFor: json['reserved_for'],
    );
  }

  static TableStatus parseStatus(String status) {
    switch (status.toLowerCase()) {
      case 'occupied': return TableStatus.Occupied;
      case 'billing': return TableStatus.Billing;
      case 'reserved': return TableStatus.Reserved;
      case 'held': return TableStatus.Held;
      case 'preparing': return TableStatus.Preparing;
      case 'ready': return TableStatus.Ready;
      case 'available': return TableStatus.Available;
      default: return TableStatus.Available;
    }
  }
  
  TableModel copyWith({
    TableStatus? status,
    bool? isReserved,
    String? reservedFor,
  }) {
    return TableModel(
      id: id,
      name: name,
      status: status ?? this.status,
      capacity: capacity,
      section: section,
      isReserved: isReserved ?? this.isReserved,
      reservedFor: reservedFor ?? this.reservedFor,
    );
  }
}
