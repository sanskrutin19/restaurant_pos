import 'cart_model.dart';
import '../utils/time_utils.dart';

class OrderItem {
  final int menuItemId;
  final int quantity;
  final String name;
  final double price;
  final String? notes;
  final List<CartItemModifier> modifiers;
  final int? kitchenCounterId;
  final bool isSentToKitchen;
  final bool allowDiscount;
  final bool taxEnabled;
  final double taxPercentage;
  final int kotVersion;
  final String kotStatus;

  OrderItem({
    required this.menuItemId,
    required this.quantity,
    this.name = '',
    this.price = 0.0,
    this.notes,
    this.modifiers = const [],
    this.kitchenCounterId,
    this.isSentToKitchen = false,
    this.allowDiscount = true,
    this.taxEnabled = true,
    this.taxPercentage = 5.0,
    this.kotVersion = 1,
    this.kotStatus = 'active',
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      menuItemId: json['menu_item_id'] ?? json['item_id'] ?? 0,
      quantity: json['quantity'] ?? 1,
      name: json['name'] ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      notes: json['notes'],
      kitchenCounterId: json['kitchen_counter_id'],
      modifiers: (json['modifiers'] as List<dynamic>?)
          ?.map((m) => CartItemModifier(
                name: m['name'],
                priceDelta: (m['price_delta'] as num).toDouble(),
              ))
          .toList() ??
          [],
      isSentToKitchen: json['is_sent_to_kitchen'] ?? false,
      allowDiscount: json['allow_discount'] ?? true,
      taxEnabled: json['tax_enabled'] ?? true,
      taxPercentage: (json['tax_percentage'] as num?)?.toDouble() ?? 5.0,
      kotVersion: json['kot_version'] ?? 1,
      kotStatus: json['kot_status'] ?? 'active',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'menu_item_id': menuItemId,
      'quantity': quantity,
      'notes': notes,
      'kitchen_counter_id': kitchenCounterId,
      'modifiers': modifiers.map((m) => m.toJson()).toList(),
      'is_sent_to_kitchen': isSentToKitchen,
      'allow_discount': allowDiscount,
      'tax_enabled': taxEnabled,
      'tax_percentage': taxPercentage,
      'kot_version': kotVersion,
      'kot_status': kotStatus,
    };
  }
}

class Order {
  final int id;
  final int tableNumber;
  final String status;
  final String? paymentMethod;
  final String orderType;
  final DateTime createdAt;
  final List<OrderItem> items;
  final String? customerName;
  final String? customerPhone;
  final int? shiftId;
  final String? roomNumber;
  final String? guestName;
  final double roomServiceCharge;
  final int paxCount;
  final String? customerMobile;
  final String? billNumber;

  double get totalAmount {
    return items.fold(0, (sum, item) => sum + (item.price * item.quantity));
  }

  Order({
    required this.id,
    required this.tableNumber,
    required this.status,
    this.paymentMethod,
    this.orderType = 'dine_in',
    required this.createdAt,
    required this.items,
    this.customerName,
    this.customerPhone,
    this.shiftId,
    this.roomNumber,
    this.guestName,
    this.roomServiceCharge = 0.0,
    this.paxCount = 1,
    this.customerMobile,
    this.billNumber,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    // Convert payment_method from int to string
    String? paymentMethodStr;
    if (json['payment_method'] != null) {
      final pm = json['payment_method'];
      if (pm is int) {
        switch (pm) {
          case 1: paymentMethodStr = 'cash'; break;
          case 2: paymentMethodStr = 'card'; break;
          case 3: paymentMethodStr = 'upi'; break;
          default: paymentMethodStr = null;
        }
      } else if (pm is String) {
        paymentMethodStr = pm;
      }
    }

    return Order(
      id: json['id'] ?? 0,
      tableNumber: json['table_number'] ?? json['table_id'] ?? 0,
      status: json['status'] ?? 'Pending',
      paymentMethod: paymentMethodStr,
      orderType: json['order_type'] ?? 'dine_in',
      createdAt: TimeUtils.parseUtc(json['created_at']),
      items: (json['items'] as List<dynamic>?)
          ?.map((i) => OrderItem.fromJson(Map<String, dynamic>.from(i as Map)))
          .toList() ??
          [],
      customerName: json['customer_name'],
      customerPhone: json['customer_phone'],
      shiftId: json['shift_id'],
      roomNumber: json['room_number'],
      guestName: json['guest_name'],
      roomServiceCharge: (json['room_service_charge'] as num?)?.toDouble() ?? 0.0,
      paxCount: json['pax_count'] ?? 1,
      customerMobile: json['customer_mobile'],
      billNumber: json['bill_number'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'table_number': tableNumber,
      'status': status,
      'payment_method': paymentMethod,
      'order_type': orderType,
      'created_at': createdAt.toIso8601String(),
      'items': items.map((i) => i.toJson()).toList(),
      'customer_name': customerName,
      'customer_phone': customerPhone,
      'shift_id': shiftId,
      'room_number': roomNumber,
      'guest_name': guestName,
      'room_service_charge': roomServiceCharge,
      'pax_count': paxCount,
      'customer_mobile': customerMobile,
      'bill_number': billNumber,
    };
  }
}

class OrderSummary {
  final int totalOrders;
  final double totalRevenue;
  final Map<String, int> ordersByStatus;
  final List<TrendPoint> revenueTrend;

  OrderSummary({
    required this.totalOrders,
    required this.totalRevenue,
    required this.ordersByStatus,
    this.revenueTrend = const [],
  });

  factory OrderSummary.fromJson(Map<String, dynamic> json) {
    final rawStatus = json['orders_by_status'];
    Map<String, int> statusMap = {};
    if (rawStatus is Map) {
      rawStatus.forEach((key, value) {
        statusMap[key.toString()] = (value is int) ? value : int.tryParse(value.toString()) ?? 0;
      });
    }
    final rawTrend = json['revenue_trend'] as List<dynamic>?;
    List<TrendPoint> trend = [];
    if (rawTrend != null) {
      trend = rawTrend.map((t) => TrendPoint.fromJson(Map<String, dynamic>.from(t as Map))).toList();
    }

    return OrderSummary(
      totalOrders: json['total_orders'] ?? 0,
      totalRevenue: (json['total_revenue'] as num?)?.toDouble() ?? 0.0,
      ordersByStatus: statusMap,
      revenueTrend: trend,
    );
  }
}

class TrendPoint {
  final String day;
  final double revenue;

  TrendPoint({required this.day, required this.revenue});

  factory TrendPoint.fromJson(Map<String, dynamic> json) {
    return TrendPoint(
      day: json['day'] ?? '',
      revenue: (json['revenue'] as num?)?.toDouble() ?? 0.0,
    );
  }
}