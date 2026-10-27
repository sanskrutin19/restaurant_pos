import 'menu_model.dart';

class CartItemModifier {
  final String name;
  final double priceDelta;

  CartItemModifier({required this.name, required this.priceDelta});

  Map<String, dynamic> toJson() => {'name': name, 'price_delta': priceDelta};
}

class CartItem {
  final MenuItem menuItem;
  int quantity;
  final bool isExisting;
  final String? notes;
  final List<CartItemModifier> modifiers;
  final double discountAmount;
  final double? priceOverride;
  final bool isSentToKitchen;

  CartItem({
    required this.menuItem,
    this.quantity = 1,
    this.isExisting = false,
    this.notes,
    this.modifiers = const [],
    this.discountAmount = 0.0,
    this.priceOverride,
    this.isSentToKitchen = false,
  });

  double get baseUnitPrice =>
      (priceOverride ?? menuItem.price) + modifiers.fold(0.0, (sum, m) => sum + m.priceDelta);

  double get unitPrice => baseUnitPrice - (discountAmount / quantity);

  double get total => (baseUnitPrice * quantity) - discountAmount;

  CartItem copyWith({
    MenuItem? menuItem,
    int? quantity,
    bool? isExisting,
    String? notes,
    List<CartItemModifier>? modifiers,
    double? discountAmount,
    double? priceOverride,
    bool? isSentToKitchen,
  }) {
    return CartItem(
      menuItem: menuItem ?? this.menuItem,
      quantity: quantity ?? this.quantity,
      isExisting: isExisting ?? this.isExisting,
      notes: notes ?? this.notes,
      modifiers: modifiers ?? this.modifiers,
      discountAmount: discountAmount ?? this.discountAmount,
      priceOverride: priceOverride ?? this.priceOverride,
      isSentToKitchen: isSentToKitchen ?? this.isSentToKitchen,
    );
  }
}

// ADD THIS CART CLASS
class Cart {
  final List<CartItem> items;

  Cart({required this.items});

  double get subtotal => items.fold(0.0, (sum, item) => sum + item.total);

  double get total => subtotal;

  int get itemCount => items.fold(0, (sum, item) => sum + item.quantity);
}