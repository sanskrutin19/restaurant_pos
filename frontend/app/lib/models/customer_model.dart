import '../utils/time_utils.dart';

class Customer {
  final int id;
  final String? name;
  final String phone;
  final String? email;
  final int points;
  final int visitsCount;
  final double totalSpend;
  final DateTime? lastVisit;

  Customer({
    required this.id,
    this.name,
    required this.phone,
    this.email,
    required this.points,
    required this.visitsCount,
    this.totalSpend = 0.0,
    this.lastVisit,
  });

  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      id: json['id'],
      name: json['name'],
      phone: json['phone'],
      email: json['email'],
      points: json['points'],
      visitsCount: json['visits_count'],
      totalSpend: (json['total_spend'] as num?)?.toDouble() ?? 0.0,
      lastVisit: TimeUtils.parseUtcNullable(json['last_visit']),
    );
  }
}
