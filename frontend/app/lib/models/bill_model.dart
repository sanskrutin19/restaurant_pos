import '../utils/time_utils.dart';

class Bill {
  final int id;
  final int orderId;
  final String? billNumber;
  final double subtotal;
  final double taxableSubtotal;
  final double nonTaxableSubtotal;
  final double discountableSubtotal;
  final double nonDiscountableSubtotal;
  final double totalAmount;
  final double tax;
  final double cgst;
  final double sgst;
  final double discount;
  final String discountType;
  final double discountValue;
  final String? discountNote;
  final double roundOff;
  final bool isReprint;
  final DateTime createdAt;

  Bill({
    required this.id,
    required this.orderId,
    this.billNumber,
    this.subtotal = 0.0,
    this.taxableSubtotal = 0.0,
    this.nonTaxableSubtotal = 0.0,
    this.discountableSubtotal = 0.0,
    this.nonDiscountableSubtotal = 0.0,
    required this.totalAmount,
    required this.tax,
    this.cgst = 0.0,
    this.sgst = 0.0,
    required this.discount,
    this.discountType = 'flat',
    this.discountValue = 0.0,
    this.discountNote,
    this.roundOff = 0.0,
    this.isReprint = false,
    required this.createdAt,
  });

  factory Bill.fromJson(Map<String, dynamic> json) {
    return Bill(
      id: json['id'],
      orderId: json['order_id'],
      billNumber: json['bill_number'],
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0.0,
      taxableSubtotal: (json['taxable_subtotal'] as num?)?.toDouble() ?? 0.0,
      nonTaxableSubtotal: (json['non_taxable_subtotal'] as num?)?.toDouble() ?? 0.0,
      discountableSubtotal: (json['discountable_subtotal'] as num?)?.toDouble() ?? 0.0,
      nonDiscountableSubtotal: (json['non_discountable_subtotal'] as num?)?.toDouble() ?? 0.0,
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0.0,
      tax: (json['tax'] as num?)?.toDouble() ?? 0.0,
      cgst: (json['cgst'] as num?)?.toDouble() ?? 0.0,
      sgst: (json['sgst'] as num?)?.toDouble() ?? 0.0,
      discount: (json['discount'] as num?)?.toDouble() ?? 0.0,
      discountType: json['discount_type'] ?? 'flat',
      discountValue: (json['discount_value'] as num?)?.toDouble() ?? 0.0,
      discountNote: json['discount_note'],
      roundOff: (json['round_off'] as num?)?.toDouble() ?? 0.0,
      isReprint: (json['is_reprint'] == 1 || json['is_reprint'] == true),
      createdAt: TimeUtils.parseUtc(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'order_id': orderId,
        'bill_number': billNumber,
        'subtotal': subtotal,
        'taxable_subtotal': taxableSubtotal,
        'non_taxable_subtotal': nonTaxableSubtotal,
        'discountable_subtotal': discountableSubtotal,
        'non_discountable_subtotal': nonDiscountableSubtotal,
        'total_amount': totalAmount,
        'tax': tax,
        'cgst': cgst,
        'sgst': sgst,
        'discount': discount,
        'discount_type': discountType,
        'discount_value': discountValue,
        'discount_note': discountNote,
        'round_off': roundOff,
        'is_reprint': isReprint ? 1 : 0,
        'created_at': createdAt.toIso8601String(),
      };
}
