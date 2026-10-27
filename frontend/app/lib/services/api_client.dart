import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../models/auth_model.dart';
import '../models/menu_model.dart';
import '../models/order_model.dart';
import '../models/customer_model.dart';
import '../models/room_model.dart';
import '../models/kot_model.dart';

import '../models/system_model.dart';
import 'sync_service.dart';
import '../providers.dart';

class ApiClient {
  final Dio _refDio;
  final Ref _ref;
  
  ApiClient(this._refDio, this._ref);

  Dio get _dio => _refDio;

  // Auth
  Future<AuthUser> login(String username, String password) async {
    final response = await _dio.post(
      '/auth/token',
      data: {
        'username': username,
        'password': password,
      },
      options: Options(contentType: 'application/x-www-form-urlencoded'),
    );
    return AuthUser.fromJson(response.data);
  }

  Future<void> forgotPassword(String username) async {
    await _dio.post('/auth/forgot-password', data: {'username': username});
  }

  Future<void> resetPassword(String username, String code, String newPassword) async {
    await _dio.post('/auth/reset-password', data: {
      'username': username,
      'code': code,
      'new_password': newPassword,
    });
  }

  Future<void> changePassword(String currentPassword, String newPassword) async {
    await _dio.post('/auth/change-password', data: {
      'current_password': currentPassword,
      'new_password': newPassword,
    });
  }

  // Menu Categories
  Future<List<Category>> getCategories() async {
    // Add cache buster to bypass any stale network caches
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final response = await _dio.get('/menu/categories', queryParameters: {'_cb': timestamp});
    final list = (response.data as List).map((c) => Category.fromJson(Map<String, dynamic>.from(c as Map))).toList();
    // Ensure consistent display order by ID
    list.sort((a, b) => a.id.compareTo(b.id));
    return list;
  }

  Future<Category> createCategory(String name, String? description, {int? parentId, int? kitchenCounterId}) async {
    final response = await _dio.post('/menu/categories', data: {
      'name': name,
      'description': description,
      'parent_id': parentId,
      'kitchen_counter_id': kitchenCounterId,
    });
    return Category.fromJson(response.data);
  }

  Future<Category> updateCategory(int id, String name, String? description, {int? parentId, int? kitchenCounterId}) async {
    final response = await _dio.put('/menu/categories/$id', data: {
      'name': name,
      'description': description,
      'parent_id': parentId,
      'kitchen_counter_id': kitchenCounterId,
    });
    return Category.fromJson(response.data);
  }

  Future<void> deleteCategory(int id) async {
    await _dio.delete('/menu/categories/$id');
  }

  // Menu Items
  Future<List<MenuItem>> getMenuItems() async {
    final response = await _dio.get('/menu/items');
    return (response.data as List).map((i) => MenuItem.fromJson(Map<String, dynamic>.from(i as Map))).toList();
  }

  Future<MenuItem> createMenuItem(String name, double price, int categoryId, String? description, bool isAvailable, int stockQuantity, {
    int? kitchenCounterId,
    bool allowDiscount = true,
    bool taxEnabled = true,
    double taxPercentage = 5.0,
  }) async {
    final response = await _dio.post('/menu/items', data: {
      'name': name,
      'price': price,
      'category_id': categoryId,
      'description': description,
      'is_available': isAvailable,
      'stock_level': stockQuantity,
      'kitchen_counter_id': kitchenCounterId,
      'allow_discount': allowDiscount,
      'tax_enabled': taxEnabled,
      'tax_percentage': taxPercentage,
    });
    return MenuItem.fromJson(response.data);
  }

  Future<MenuItem> updateMenuItem(int id, String name, double price, int categoryId, String? description, bool isAvailable, int stockQuantity, {
    int? kitchenCounterId,
    bool allowDiscount = true,
    bool taxEnabled = true,
    double taxPercentage = 5.0,
  }) async {
    final response = await _dio.put('/menu/items/$id', data: {
      'name': name,
      'price': price,
      'category_id': categoryId,
      'description': description,
      'is_available': isAvailable,
      'stock_level': stockQuantity,
      'kitchen_counter_id': kitchenCounterId,
      'allow_discount': allowDiscount,
      'tax_enabled': taxEnabled,
      'tax_percentage': taxPercentage,
    });
    return MenuItem.fromJson(response.data);
  }

  // Kitchen Counters
  Future<List<KitchenCounter>> getKitchenCounters() async {
    final response = await _dio.get('/admin/kitchen-counters');
    return (response.data as List).map((s) => KitchenCounter.fromJson(Map<String, dynamic>.from(s as Map))).toList();
  }

  Future<KitchenCounter> createKitchenCounter(String name, {
    String icon = 'store', 
    String color = '#000000', 
    String printerType = 'network',
    String? printerAddress,
    int printerPort = 9100,
  }) async {
    final response = await _dio.post('/admin/kitchen-counters', data: {
      'name': name,
      'icon': icon,
      'color': color,
      'printer_type': printerType,
      'printer_address': printerAddress,
      'printer_port': printerPort,
    });
    return KitchenCounter.fromJson(response.data);
  }

  Future<KitchenCounter> updateKitchenCounter(int id, String name, {
    bool isActive = true,
    String icon = 'store',
    String color = '#000000',
    String printerType = 'network',
    String? printerAddress,
    int printerPort = 9100,
  }) async {
    final response = await _dio.put('/admin/kitchen-counters/$id', data: {
      'name': name,
      'is_active': isActive,
      'icon': icon,
      'color': color,
      'printer_type': printerType,
      'printer_address': printerAddress,
      'printer_port': printerPort,
    });
    return KitchenCounter.fromJson(response.data);
  }

  Future<void> deleteKitchenCounter(int id) async {
    await _dio.delete('/admin/kitchen-counters/$id');
  }

  Future<void> resetOrders() async {
    await _dio.post('/admin/reset-orders');
  }

  Future<void> deleteMenuItem(int id) async {
    await _dio.delete('/menu/items/$id');
  }

  // Orders
  Future<List<Order>> getOrders({String? date}) async {
    final response = await _dio.get('/orders', queryParameters: {
      if (date != null) 'date': date,
    });
    if (response.data is! List) return [];
    return (response.data as List).map((o) => Order.fromJson(Map<String, dynamic>.from(o as Map))).toList();
  }

  Future<Order> createOrder({
    required int tableNumber,
    required List<Map<String, dynamic>> items,
    int paymentMethod = 1,
    String? customerName,
    String? customerPhone,
    String? customerMobile,
    String orderType = 'dine_in',
    double discountAmount = 0.0,
    double taxRate = 5.0,
    String? counterId,
    String? roomNumber,
    String? guestName,
    int paxCount = 1,
    double roomServiceCharge = 0.0,
  }) async {
    final authUser = _ref.read(authProvider);
    final orderData = {
      'table_id': tableNumber,
      'user_id': authUser?.id ?? 1,
      'device_id': 1, // Default till we have multi-device support
      'payment_method': paymentMethod,
      'customer_name': customerName,
      'customer_phone': customerPhone,
      'customer_mobile': customerMobile,
      'order_type': orderType,
      'discount_amount': discountAmount,
      'tax_rate': taxRate,
      'items': items,
      'counter_id': counterId,
      'room_number': roomNumber,
      'guest_name': guestName,
      'pax_count': paxCount,
      'room_service_charge': roomServiceCharge,
    };

    try {
      final response = await _dio.post('/orders', data: orderData);
      return Order.fromJson(response.data);
    } catch (e) {
      if (e is DioException && (e.type == DioExceptionType.connectionTimeout || e.type == DioExceptionType.unknown)) {
        final syncService = _ref.read(syncServiceProvider);
        await syncService.queueOrder(orderData);
        throw Exception('Offline: Order queued locally');
      }
      rethrow;
    }
  }

  Future<void> updateOrderStatus(int orderId, String status) async {
    await _dio.patch('/orders/$orderId/status', data: {'status': status});
  }

  Future<void> updateOrder(int orderId, {String? customerName, String? customerPhone, String? customerMobile, String? orderType, double? discountAmount, double? taxRate, String? roomNumber}) async {
    final authUser = _ref.read(authProvider);
    await _dio.patch('/orders/$orderId', data: {
      if (customerName != null) 'customer_name': customerName,
      if (customerPhone != null) 'customer_phone': customerPhone,
      if (customerMobile != null) 'customer_mobile': customerMobile,
      if (orderType != null) 'order_type': orderType,
      if (discountAmount != null) 'discount_amount': discountAmount,
      if (taxRate != null) 'tax_rate': taxRate,
      if (roomNumber != null) 'room_number': roomNumber,
      'user_id': authUser?.id ?? 1,
      'device_id': 1,
    });
  }

  // CRM
  Future<Customer> getCustomerByPhone(String phone) async {
    final response = await _dio.get('/loyalty/customer/$phone');
    return Customer.fromJson(Map<String, dynamic>.from(response.data as Map));
  }

  Future<List<Map<String, dynamic>>> searchCustomers(String query) async {
    final response = await _dio.get('/loyalty/customers/search', queryParameters: {'query': query});
    return (response.data as List).map((c) => Map<String, dynamic>.from(c as Map)).toList();
  }

  Future<List<Map<String, dynamic>>> getCustomerHistory(String phone) async {
    final response = await _dio.get('/loyalty/customer/$phone/history');
    return (response.data as List).map((o) => Map<String, dynamic>.from(o as Map)).toList();
  }

  Future<Map<String, dynamic>> createCustomer(String name, String phone, {String? email}) async {
    final response = await _dio.post('/loyalty/customer', data: {
      'phone': phone,
      'name': name,
      'email': email,
    });
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<void> redeemPoints(String phone, int points) async {
    await _dio.post('/loyalty/customer/redeem', queryParameters: {
      'phone': phone,
      'points': points,
    });
  }

  // Staff Management
  Future<void> clockIn(int userId) async {
    await _dio.post('/staff/clock-in/$userId');
  }

  Future<void> clockOut(int userId) async {
    await _dio.post('/staff/clock-out/$userId');
  }

  Future<List<Map<String, dynamic>>> getStaffUsers() async {
    final response = await _dio.get('/staff/users');
    if (response.data is! List) return [];
    return (response.data as List).map((u) => Map<String, dynamic>.from(u as Map)).toList();
  }

  Future<Map<String, dynamic>> createStaff(String username, String password, String role, {double hourlyRate = 100.0}) async {
    final response = await _dio.post('/staff/', data: {
      'username': username,
      'password': password,
      'role': role,
      'hourly_rate': hourlyRate,
    });
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> updateStaff(int userId, {String? username, String? password, String? role, double? hourlyRate}) async {
    final data = <String, dynamic>{};
    if (username != null) data['username'] = username;
    if (password != null) data['password'] = password;
    if (role != null) data['role'] = role;
    if (hourlyRate != null) data['hourly_rate'] = hourlyRate;

    final response = await _dio.put('/staff/$userId', data: data);
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<void> deleteStaff(int userId) async {
    await _dio.delete('/staff/$userId');
  }

  Future<void> registerStaff(String username, String password, String role) async {
    await _dio.post('/auth/register', data: {
      'username': username,
      'password': password,
      'role': role
    });
  }

  Future<List<Map<String, dynamic>>> getAttendanceLogs() async {
    final response = await _dio.get('/staff/attendance');
    return (response.data as List).map((a) => Map<String, dynamic>.from(a as Map)).toList();
  }

  Future<List<Map<String, dynamic>>> getAttendance(int userId) async {
    final response = await _dio.get('/staff/attendance/$userId');
    return (response.data as List).map((a) => Map<String, dynamic>.from(a as Map)).toList();
  }

  Future<void> addItemsToOrder(int orderId, List<Map<String, dynamic>> items) async {
    try {
      final authUser = _ref.read(authProvider);
      await _dio.post('/orders/$orderId/items', data: items);
    } catch (e) {
      if (e is DioException && (e.type == DioExceptionType.connectionTimeout || e.type == DioExceptionType.unknown)) {
        final syncService = _ref.read(syncServiceProvider);
        await syncService.queueOrder({
          'order_id': orderId,
          'items': items,
        });
        throw Exception('Offline: Items queued locally');
      }
      rethrow;
    }
  }

  Future<void> mergeOrders(int targetOrderId, int sourceOrderId) async {
    await _dio.post('/orders/$targetOrderId/merge', data: {
      'source_order_id': sourceOrderId,
    });
  }

  Future<void> transferOrder(int orderId, int newTableId) async {
    await _dio.post('/orders/$orderId/transfer', data: {
      'new_table_id': newTableId,
    });
  }

  Future<OrderSummary> getOrderSummary() async {
    try {
      final response = await _dio.get('/orders/summary');
      return OrderSummary.fromJson(Map<String, dynamic>.from(response.data as Map));
    } catch (e) {
      return OrderSummary(
        totalOrders: 0,
        totalRevenue: 0.0,
        ordersByStatus: {},
      );
    }
  }

  // Payment
  Future<void> recordPayment(int orderId, double amount, String paymentMethod) async {
    await _dio.post('/payments', data: {
      'order_id': orderId,
      'amount': amount,
      'payment_method': paymentMethod,
    });
  }

  // Billing
  Future<Map<String, dynamic>> generateBill(
    int orderId, {
    double taxRate = 5.0,
    double discount = 0.0,
    String discountType = 'flat',
    double discountValue = 0.0,
  }) async {
    final response = await _dio.post('/billing/$orderId/generate', queryParameters: {
      'tax_rate': taxRate,
      'discount': discount,
      'discount_type': discountType,
      'discount_value': discountValue,
    });
    return response.data;
  }

  // ── Hold / Resume Orders ──────────────────────────────────────────────

  Future<void> holdOrder(int orderId) async {
    await _dio.put('/orders/$orderId/hold');
  }

  Future<void> resumeOrder(int orderId) async {
    await _dio.put('/orders/$orderId/resume');
  }

  Future<List<Order>> getHeldOrders() async {
    final response = await _dio.get('/orders/held');
    if (response.data is! List) return [];
    return (response.data as List)
        .map((o) => Order.fromJson(Map<String, dynamic>.from(o as Map)))
        .toList();
  }

  // ── Modifiers ─────────────────────────────────────────────────────────

  Future<List<MenuItemModifier>> getItemModifiers(int itemId) async {
    final response = await _dio.get('/menu/items/$itemId/modifiers');
    return (response.data as List)
        .map((m) => MenuItemModifier.fromJson(Map<String, dynamic>.from(m as Map)))
        .toList();
  }

  Future<MenuItemModifier> addMenuItemModifier(int itemId, {
    required String name, 
    required double priceDelta, 
    String group = 'default', 
    bool isDefault = false
  }) async {
    final response = await _dio.post('/menu/items/$itemId/modifiers', data: {
      'name': name,
      'price_delta': priceDelta,
      'modifier_group': group,
      'is_default': isDefault,
    });
    return MenuItemModifier.fromJson(response.data);
  }

  Future<void> deleteMenuItemModifier(int modifierId) async {
    await _dio.delete('/menu/modifiers/$modifierId');
  }

  // ── Combo CRUD ──────────────────────────────────────────────────────────

  Future<void> addComboComponent(int comboId, int componentId, int quantity) async {
    await _dio.post('/menu/items/$comboId/combo', queryParameters: {
      'component_id': componentId,
      'quantity': quantity,
    });
  }

  Future<void> removeComboComponent(int comboId, int componentId) async {
    await _dio.delete('/menu/items/$comboId/combo/$componentId');
  }


  // ── Printing ─────────────────────────────────────────────────────────────
  
  String getBillPrintUrl(int orderId, {double? taxRate, double discount = 0.0}) {
    final settings = _ref.read(settingsProvider);
    final authUser = _ref.read(authProvider);
    final encodedName = Uri.encodeQueryComponent(settings.restaurantName);
    final encodedAddress = Uri.encodeQueryComponent(settings.restaurantAddress);
    final encodedFooter = Uri.encodeQueryComponent(settings.billFooter);
    final encodedTaxLabel = Uri.encodeQueryComponent(settings.taxLabel);
    
    final effectiveTax = taxRate ?? settings.taxRate;
    return '${settings.effectiveApiUrl}/orders/$orderId/bill?restaurant_name=$encodedName&address=$encodedAddress&phone=${settings.restaurantPhone}&gstin=${settings.gstin}&fssai=${settings.fssaiLicense}&footer=$encodedFooter&tax_label=$encodedTaxLabel&tax_rate=$effectiveTax&discount=$discount&counter_id=${settings.counterId}&token=${authUser?.token ?? ""}';
  }

  String getKotPrintUrl(int orderId, {String mode = 'all', int? targetCounterId}) {
    final settings = _ref.read(settingsProvider);
    final authUser = _ref.read(authProvider);
    return '${settings.effectiveApiUrl}/orders/$orderId/kot?mode=$mode${targetCounterId != null ? '&target_counter_id=$targetCounterId' : ''}&counter_id=${settings.counterId}&token=${authUser?.token ?? ""}';
  }

  // ── Split Payment Support ──────────────────────────────────────────────

  Future<Map<String, dynamic>> getPaymentBalance(int orderId) async {
    final response = await _dio.get('/payments/order/$orderId/balance');
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<List<Map<String, dynamic>>> getOrderPayments(int orderId) async {
    final response = await _dio.get('/payments/order/$orderId');
    return (response.data as List)
        .map((p) => Map<String, dynamic>.from(p as Map))
        .toList();
  }

  // ── Reports ───────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getCategorySalesReport({String? date}) async {
    final response = await _dio.get('/admin/reports/category-sales', queryParameters: {'date': date});
    return (response.data as List).map((r) => Map<String, dynamic>.from(r as Map)).toList();
  }

  Future<Map<String, dynamic>> getTaxSummaryReport({String? date}) async {
    final response = await _dio.get('/admin/reports/tax-summary', queryParameters: {'date': date});
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<List<Map<String, dynamic>>> getPaymentMethodsReport({String? date}) async {
    final response = await _dio.get('/admin/reports/payment-methods', queryParameters: {'date': date});
    return (response.data as List).map((r) => Map<String, dynamic>.from(r as Map)).toList();
  }

  Future<Map<String, dynamic>> getDailyReport({String? date}) async {
    final response = await _dio.get('/admin/reports/daily', queryParameters: {'date': date});
    return Map<String, dynamic>.from(response.data as Map);
  }

  


  Future<Map<String, dynamic>> getDashboardUnified({String? date}) async {
    final response = await _dio.get('/admin/reports/dashboard-unified', queryParameters: {
      if (date != null) 'date': date,
    });
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> getInsightsUnified({String? date}) async {
    final response = await _dio.get('/admin/reports/insights-unified', queryParameters: {
      if (date != null) 'date': date,
    });
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Uint8List> exportReport({String? date, String type = 'csv'}) async {
    final response = await _dio.get(
      '/admin/reports/export',
      queryParameters: {
        if (date != null) 'date': date,
        'type': type,
      },
      options: Options(responseType: ResponseType.bytes),
    );
    return Uint8List.fromList(response.data);
  }

  Future<Map<String, dynamic>> getSystemInfo() async {
    final response = await _dio.get('/admin/system/info');
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> updateTaxRate(double taxRate) async {
    final response = await _dio.post('/admin/settings/tax', data: {'tax_rate': taxRate});
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<void> updateSystemSettings(Map<String, dynamic> settings) async {
    await _dio.post('/admin/settings/bulk', data: {'settings': settings});
  }

  Future<Map<String, String>> getSystemSettings() async {
    final response = await _dio.get('/menu/settings');
    final Map<String, String> settings = {};
    if (response.data is Map) {
      (response.data as Map).forEach((k, v) {
        settings[k.toString()] = v.toString();
      });
    }
    return settings;
  }

  // ── Rooms ─────────────────────────────────────────────────────────────
  Future<List<Room>> getRooms() async {
    final response = await _dio.get('/rooms');
    return (response.data as List).map((r) => Room.fromJson(Map<String, dynamic>.from(r as Map))).toList();
  }

  Future<Room> checkinRoom(int roomId, {String? guestName}) async {
    final response = await _dio.post('/rooms/$roomId/checkin', queryParameters: {if (guestName != null) 'guest_name': guestName});
    return Room.fromJson(Map<String, dynamic>.from(response.data as Map));
  }

  Future<Room> checkoutRoom(int roomId) async {
    final response = await _dio.post('/rooms/$roomId/checkout');
    return Room.fromJson(Map<String, dynamic>.from(response.data as Map));
  }

  Future<Room> createRoom(String roomNumber, String? floor, {double serviceCharge = 0.0}) async {
    final response = await _dio.post('/rooms', data: {
      'room_number': roomNumber,
      'floor': floor,
      'service_charge': serviceCharge,
    });
    return Room.fromJson(Map<String, dynamic>.from(response.data as Map));
  }

  Future<Room> updateRoom(int roomId, {String? roomNumber, String? floor, double? serviceCharge, String? status}) async {
    final response = await _dio.put('/rooms/$roomId', data: {
      if (roomNumber != null) 'room_number': roomNumber,
      if (floor != null) 'floor': floor,
      if (serviceCharge != null) 'service_charge': serviceCharge,
      if (status != null) 'status': status,
    });
    return Room.fromJson(Map<String, dynamic>.from(response.data as Map));
  }

  Future<void> deleteRoom(int roomId) async {
    await _dio.delete('/rooms/$roomId');
  }

  // ── Roles ─────────────────────────────────────────────────────────────
  Future<List<Role>> getRoles() async {
    final response = await _dio.get('/admin/roles');
    if (response.data is! List) return [];
    return (response.data as List).map((r) => Role.fromJson(Map<String, dynamic>.from(r as Map))).toList();
  }

  Future<Map<String, dynamic>> getPermissionsMatrix() async {
    final response = await _dio.get('/admin/permissions/matrix');
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Role> createRole(String name, Map<String, dynamic> permissions) async {
    final response = await _dio.post('/admin/roles', data: {
      'name': name,
      'permissions': permissions,
    });
    return Role.fromJson(response.data);
  }

  Future<Role> updateRole(int roleId, String name, Map<String, dynamic> permissions) async {
    final response = await _dio.put('/admin/roles/$roleId', data: {
      'name': name,
      'permissions': permissions,
    });
    return Role.fromJson(response.data);
  }

  Future<void> deleteRole(int roleId) async {
    await _dio.delete('/admin/roles/$roleId');
  }

  // Printer Scanning & Testing
  Future<List<Map<String, dynamic>>> scanPrinters() async {
    final response = await _dio.get('/admin/printers/scan');
    // Backend returns {"status": "success", "printers": [...], "count": N}
    final data = response.data;
    if (data is Map && data['printers'] is List) {
      return (data['printers'] as List).map((p) => Map<String, dynamic>.from(p as Map)).toList();
    }
    // Fallback: if backend returns a plain list
    if (data is List) {
      return data.map((p) => Map<String, dynamic>.from(p as Map)).toList();
    }
    return [];
  }

  Future<void> testPrint(String printerName) async {
    await _dio.post('/admin/printers/test-print', data: {'printer_name': printerName});
  }

  Future<void> rawPrint(String printerName, String base64Bytes) async {
    await _dio.post('/admin/printers/raw-print', data: {
      'printer_name': printerName,
      'base64_bytes': base64Bytes,
    });
  }

  Future<void> remotePrintBill(int orderId, String printerName) async {
    await _dio.post('/billing/print', data: {
      'order_id': orderId,
      'printer_name': printerName,
    });
  }

  Future<bool> verifyAdminPin(String pin) async {
    try {
      await _dio.post('/admin/verify-pin', data: {'pin': pin});
      return true;
    } catch (_) {
      return false;
    }
  }

  // ── KOT ─────────────────────────────────────────────────────────────
  Future<List<KOTLog>> getKotHistory(int orderId) async {
    final response = await _dio.get('/orders/$orderId/kot/history');
    if (response.data is! List) return [];
    return (response.data as List).map((k) => KOTLog.fromJson(Map<String, dynamic>.from(k as Map))).toList();
  }

  Future<void> cancelKot(int orderId, String pin, String reason) async {
    await _dio.post('/orders/$orderId/kot/cancel', data: {'pin': pin, 'reason': reason});
  }

  Future<int> createKotVersion(int orderId, Map<String, dynamic> diff) async {
    final response = await _dio.post('/orders/$orderId/kot/version', data: diff);
    return response.data['version'];
  }

  // ── License ───────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> getLicenseStatus() async {
    final response = await _dio.get('/admin/license/status');
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<void> activateLicense(String key) async {
    await _dio.post('/admin/license/activate', data: {'key': key});
  }
}