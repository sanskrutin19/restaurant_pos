import '../utils/time_utils.dart';

class KOTLog {
  final int id;
  final int orderId;
  final int version;
  final String action;
  final List<dynamic>? addedItems;
  final List<dynamic>? removedItems;
  final List<dynamic>? modifiedItems;
  final String? cancelReason;
  final String? captainName;
  final DateTime createdAt;

  KOTLog({
    required this.id,
    required this.orderId,
    required this.version,
    required this.action,
    this.addedItems,
    this.removedItems,
    this.modifiedItems,
    this.cancelReason,
    this.captainName,
    required this.createdAt,
  });

  factory KOTLog.fromJson(Map<String, dynamic> json) {
    return KOTLog(
      id: json['id'],
      orderId: json['order_id'],
      version: json['version'],
      action: json['action'] ?? 'created',
      addedItems: json['added_items'],
      removedItems: json['removed_items'],
      modifiedItems: json['modified_items'],
      cancelReason: json['cancel_reason'],
      captainName: json['captain_name'],
      createdAt: TimeUtils.parseUtc(json['created_at']),
    );
  }
}
