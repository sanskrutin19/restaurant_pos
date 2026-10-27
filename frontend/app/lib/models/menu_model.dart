import 'system_model.dart';
import '../utils/time_utils.dart';

class Category {
  final int id;
  final int? parentId;
  final String name;
  final String? description;
  final int? kitchenCounterId;
  final bool allowDiscount;

  Category({
    required this.id,
    this.parentId,
    required this.name,
    this.description,
    this.kitchenCounterId,
    this.allowDiscount = true,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'],
      parentId: json['parent_id'],
      name: json['name'],
      description: json['description'],
      kitchenCounterId: json['kitchen_counter_id'],
      allowDiscount: json['allow_discount'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'parent_id': parentId,
      'name': name,
      'description': description,
      'kitchen_counter_id': kitchenCounterId,
      'allow_discount': allowDiscount,
    };
  }
}

class MenuItem {
  final int id;
  final String name;
  final String? description;
  final double price;
  final int categoryId;
  final bool isAvailable;
  final int? kitchenCounterId;
  final int stockQuantity;
  final DateTime createdAt;
  final bool allowDiscount;
  final bool taxEnabled;
  final double taxPercentage;
  final List<MenuItemModifier> modifiers;
  final List<ComboItem> comboItems;

  MenuItem({
    required this.id,
    required this.name,
    this.description,
    required this.price,
    required this.categoryId,
    required this.isAvailable,
    this.kitchenCounterId,
    this.stockQuantity = 0,
    required this.createdAt,
    this.allowDiscount = true,
    this.taxEnabled = true,
    this.taxPercentage = 5.0,
    this.modifiers = const [],
    this.comboItems = const [],
  });

  factory MenuItem.fromJson(Map<String, dynamic> json) {
    return MenuItem(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      price: (json['price'] as num).toDouble(),
      categoryId: json['category_id'],
      isAvailable: json['is_available'] ?? true,
      kitchenCounterId: json['kitchen_counter_id'],
      stockQuantity: json['stock_level'] ?? 100,
      createdAt: TimeUtils.parseUtc(json['created_at']),
      allowDiscount: json['allow_discount'] ?? true,
      taxEnabled: json['tax_enabled'] ?? true,
      taxPercentage: (json['tax_percentage'] as num?)?.toDouble() ?? 5.0,
      modifiers: (json['modifiers'] as List?)?.map((m) => MenuItemModifier.fromJson(m)).toList() ?? [],
      comboItems: (json['combo_items'] as List?)?.map((c) => ComboItem.fromJson(c)).toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'price': price,
      'category_id': categoryId,
      'is_available': isAvailable,
      'kitchen_counter_id': kitchenCounterId,
      'stock_level': stockQuantity,
      'created_at': createdAt.toIso8601String(),
      'allow_discount': allowDiscount,
      'tax_enabled': taxEnabled,
      'tax_percentage': taxPercentage,
    };
  }
}

class MenuItemModifier {
  final int id;
  final String name;
  final double priceDelta;
  final String modifierGroup;
  final bool isDefault;

  MenuItemModifier({
    required this.id,
    required this.name,
    required this.priceDelta,
    this.modifierGroup = 'default',
    this.isDefault = false,
  });

  factory MenuItemModifier.fromJson(Map<String, dynamic> json) {
    return MenuItemModifier(
      id: json['id'],
      name: json['name'],
      priceDelta: (json['price_delta'] as num).toDouble(),
      modifierGroup: json['modifier_group'] ?? 'default',
      isDefault: json['is_default'] ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'price_delta': priceDelta,
    'modifier_group': modifierGroup,
    'is_default': isDefault,
  };
}

class ComboItem {
  final int id;
  final int componentItemId;
  final int quantity;
  final String? name;
  final double? price;

  ComboItem({
    required this.id,
    required this.componentItemId,
    this.quantity = 1,
    this.name,
    this.price,
  });

  factory ComboItem.fromJson(Map<String, dynamic> json) {
    return ComboItem(
      id: json['id'],
      componentItemId: json['component_item_id'],
      quantity: json['quantity'] ?? 1,
      name: json['name'],
      price: (json['price'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'component_item_id': componentItemId,
    'quantity': quantity,
    'name': name,
    'price': price,
  };
}
