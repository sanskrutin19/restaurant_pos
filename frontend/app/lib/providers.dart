import 'dart:async';
import 'package:flutter/foundation.dart' hide Category;
import 'package:nsd/nsd.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:dio/dio.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'models/auth_model.dart';
import 'models/cart_model.dart';
import 'models/settings_model.dart';
import 'models/menu_model.dart';
import 'models/order_model.dart' hide CartItemModifier;
import 'models/customer_model.dart';
import 'models/table_model.dart';
import 'models/room_model.dart';
import 'models/kot_model.dart';

import 'models/system_model.dart';
import 'services/api_client.dart';
import 'services/sync_service.dart';
import 'services/websocket_service.dart';

// Settings Provider
final settingsProvider = StateNotifierProvider<SettingsNotifier, AppSettings>((ref) {
  return SettingsNotifier(ref);
});

class SettingsNotifier extends StateNotifier<AppSettings> {
  final Ref _ref;
  SettingsNotifier(this._ref) : super(AppSettings.loadFromHive());

  /// Creates a standalone Dio instance to avoid circular dependency
  /// (settingsProvider → dioProvider → settingsProvider)
  Dio _createStandaloneDio() {
    final box = Hive.box('settings');
    final token = box.get('auth_token');
    final dio = Dio(BaseOptions(
      baseUrl: state.effectiveApiUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
    ));
    if (token != null) {
      dio.options.headers['Authorization'] = 'Bearer $token';
    }
    return dio;
  }

  Future<void> syncWithBackend() async {
    try {
      final dio = _createStandaloneDio();
      final response = await dio.get('/menu/settings');
      final Map<String, String> remoteSettings = {};
      
      if (response.data is Map) {
        (response.data as Map).forEach((k, v) {
          remoteSettings[k.toString()] = v.toString();
        });
      } else if (response.data is List) {
        // Fallback for old list-style response
        for (var s in (response.data as List)) {
          remoteSettings[s['key']] = s['value'].toString();
        }
      }

      if (remoteSettings.isNotEmpty) {
        final newState = state.copyWith(
          restaurantName: remoteSettings['restaurant_name'],
          restaurantAddress: remoteSettings['restaurant_address'],
          restaurantPhone: remoteSettings['restaurant_phone'],
          gstin: remoteSettings['gstin'],
          fssaiLicense: remoteSettings['fssai_license'],
          taxRate: double.tryParse(remoteSettings['tax_rate'] ?? ''),
          taxLabel: remoteSettings['tax_label'],
          billFooter: remoteSettings['bill_footer'],
          currencySymbol: remoteSettings['currency_symbol'],
        );
        
        if (newState != state) {
          await newState.saveToHive();
          state = newState;
        }
      }
    } catch (e) {
      debugPrint('Initial settings sync failed: $e');
    }
  }

  Future<void> saveSettings(AppSettings settings) async {
    await settings.saveToHive();
    state = settings;
    
    // Sync with backend if possible (use standalone Dio to avoid circular dependency)
    try {
      final dio = _createStandaloneDio();
      await dio.post('/admin/settings/bulk', data: {
        'settings': {
          'restaurant_name': settings.restaurantName,
          'restaurant_address': settings.restaurantAddress,
          'restaurant_phone': settings.restaurantPhone,
          'gstin': settings.gstin,
          'fssai_license': settings.fssaiLicense,
          'tax_rate': settings.taxRate.toString(),
          'tax_label': settings.taxLabel,
          'bill_footer': settings.billFooter,
          'currency_symbol': settings.currencySymbol,
        }
      });
    } catch (e) {
      debugPrint('Failed to sync settings to cloud: $e');
    }
  }

  Future<bool> autoDiscoverServer() async {
    try {
      debugPrint('Starting Auto-Discovery for _pos-api._tcp.local...');
      final discovery = await startDiscovery('_pos-api._tcp.local.');
      
      final completer = Completer<Service>();
      
      discovery.addListener(() {
        if (discovery.services.isNotEmpty) {
          completer.complete(discovery.services.first);
        }
      });

      // Timeout after 5 seconds
      final service = await completer.future.timeout(const Duration(seconds: 5));
      await stopDiscovery(discovery);

      if (service.addresses != null && service.addresses!.isNotEmpty) {
        final host = service.addresses!.first.address;
        final port = service.port ?? 8000;
        final newUrl = 'http://$host:$port';
        
        debugPrint('Auto-Discovered Server at: $newUrl');
        
        final updatedSettings = state.copyWith(apiBaseUrl: newUrl);
        await saveSettings(updatedSettings);
        return true;
      }
    } catch (e) {
      debugPrint('Auto-Discovery failed or timed out: $e');
    }
    return false;
  }
}

// License Provider
final licenseProvider = StateNotifierProvider<LicenseNotifier, AsyncValue<Map<String, dynamic>>>((ref) {
  return LicenseNotifier(ref);
});

class LicenseNotifier extends StateNotifier<AsyncValue<Map<String, dynamic>>> {
  final Ref _ref;
  LicenseNotifier(this._ref) : super(const AsyncValue.loading()) {
    checkLicense();
  }

  Future<void> checkLicense() async {
    try {
      final apiClient = _ref.read(apiClientProvider);
      final status = await apiClient.getLicenseStatus();
      state = AsyncValue.data(status);
    } catch (e, st) {
      if (e is DioException && e.response?.statusCode == 402) {
        state = AsyncValue.data(Map<String, dynamic>.from(e.response?.data as Map));
      } else {
        state = AsyncValue.error(e, st);
      }
    }
  }

  Future<bool> activate(String key) async {
    try {
      final apiClient = _ref.read(apiClientProvider);
      await apiClient.activateLicense(key);
      await checkLicense();
      return true;
    } catch (e) {
      debugPrint('Activation failed: $e');
      return false;
    }
  }
}

// Dio Provider
final dioProvider = Provider<Dio>((ref) {
  final settings = ref.watch(settingsProvider);
  final dio = Dio(
    BaseOptions(
      baseUrl: settings.effectiveApiUrl,
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      followRedirects: true,
      maxRedirects: 5,
      validateStatus: (status) {
        return status != null && (status < 400 || status == 402); // Let 402 pass to LicenseGate, throw others
      },
    ),
  );

  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) {
      final box = Hive.box('settings');
      final token = box.get('auth_token');
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
      }
      return handler.next(options);
    },
    onError: (error, handler) {
      if (error.response?.statusCode == 401) {
        ref.read(authProvider.notifier).logout();
      }
      // 402 is handled by the high-level license gate in the UI
      return handler.next(error);
    },
  ));

  return dio;
});

// API Client Provider
final apiClientProvider = Provider<ApiClient>((ref) {
  final dio = ref.watch(dioProvider);
  return ApiClient(dio, ref);
});

// Auth Provider
final authProvider = StateNotifierProvider<AuthNotifier, AuthUser?>((ref) {
  return AuthNotifier(ref);
});

class AuthNotifier extends StateNotifier<AuthUser?> {
  final Ref _ref;

  AuthNotifier(this._ref) : super(null) {
    _loadUser();
  }

  void _loadUser() {
    final box = Hive.box('settings');
    final token = box.get('auth_token');
    final username = box.get('username');
    final role = box.get('role');
    final userId = box.get('user_id');

    if (token != null && username != null) {
      state = AuthUser(
        token: token,
        username: username,
        role: role ?? 'staff',
        id: userId,
      );
    }
  }

  Future<void> login(String username, String password) async {
    final apiClient = _ref.read(apiClientProvider);
    final user = await apiClient.login(username, password);

    final box = Hive.box('settings');
    await box.put('auth_token', user.token);
    await box.put('username', user.username);
    await box.put('role', user.role);
    await box.put('user_id', user.id);

    state = user;
  }

  Future<void> logout() async {
    final box = Hive.box('settings');
    await box.delete('auth_token');
    await box.delete('username');
    await box.delete('role');
    await box.delete('user_id');
    state = null;
  }
}

// —— Cart Provider ——
final cartProvider = StateNotifierProvider<CartNotifier, List<CartItem>>((ref) {
  return CartNotifier();
});

class CartNotifier extends StateNotifier<List<CartItem>> {
  CartNotifier() : super([]);

  double get subtotal => state.fold(0.0, (sum, item) => sum + item.total);

  void addItem(MenuItem menuItem, {int quantity = 1, String? notes, List<CartItemModifier> modifiers = const [], bool isSentToKitchen = false}) {
    // Unique key for item + modifiers combinations
    final modKey = modifiers.map((m) => m.name).join('|');
    final existingIndex = state.indexWhere((i) => 
      i.menuItem.id == menuItem.id && 
      i.modifiers.map((m) => m.name).join('|') == modKey &&
      i.isSentToKitchen == isSentToKitchen
    );

    if (existingIndex >= 0) {
      final updated = [...state];
      updated[existingIndex] = updated[existingIndex].copyWith(
        quantity: updated[existingIndex].quantity + quantity,
        notes: notes ?? updated[existingIndex].notes,
      );
      state = updated;
    } else {
      state = [
        ...state,
        CartItem(
          menuItem: menuItem, 
          quantity: quantity, 
          notes: notes,
          modifiers: modifiers,
          isSentToKitchen: isSentToKitchen,
        ),
      ];
    }
  }

  void addExistingItem(MenuItem menuItem, int quantity, {String? notes, bool isSentToKitchen = false}) {
    state = [
      ...state,
      CartItem(
        menuItem: menuItem,
        quantity: quantity,
        isExisting: true,
        notes: notes,
        isSentToKitchen: isSentToKitchen,
      ),
    ];
  }

  void removeItem(int menuItemId) {
    state = state.where((i) => i.menuItem.id != menuItemId).toList();
  }

  void updateQuantity(int menuItemId, int quantity, {String? modKey}) {
    if (quantity <= 0) {
      if (modKey != null) {
        state = state.where((i) => 
          !(i.menuItem.id == menuItemId && i.modifiers.map((m) => m.name).join('|') == modKey)
        ).toList();
      } else {
        state = state.where((i) => i.menuItem.id != menuItemId).toList();
      }
      return;
    }

    state = state.map((item) {
      final itemModKey = item.modifiers.map((m) => m.name).join('|');
      if (item.menuItem.id == menuItemId && (modKey == null || itemModKey == modKey)) {
        return item.copyWith(quantity: quantity);
      }
      return item;
    }).toList();
  }

  void updateItemNotes(int menuItemId, String notes, {String? modKey}) {
    state = state.map((item) {
      final itemModKey = item.modifiers.map((m) => m.name).join('|');
      if (item.menuItem.id == menuItemId && (modKey == null || itemModKey == modKey)) {
        return item.copyWith(notes: notes);
      }
      return item;
    }).toList();
  }

  void updateItemDiscount(int menuItemId, double discount, {String? modKey}) {
    state = state.map((item) {
      final itemModKey = item.modifiers.map((m) => m.name).join('|');
      if (item.menuItem.id == menuItemId && (modKey == null || itemModKey == modKey)) {
        return item.copyWith(discountAmount: discount);
      }
      return item;
    }).toList();
  }

  void updateItemPrice(int menuItemId, double newPrice, {String? modKey}) {
    state = state.map((item) {
      final itemModKey = item.modifiers.map((m) => m.name).join('|');
      if (item.menuItem.id == menuItemId && (modKey == null || itemModKey == modKey)) {
        return item.copyWith(priceOverride: newPrice);
      }
      return item;
    }).toList();
  }

  void clearCart() {
    state = [];
  }
}

// Table Provider
final tableProvider = StateProvider<int?>((ref) => null);

// Room Provider
final roomProvider = StateProvider<String?>((ref) => null);

// View toggle for Table (0) vs Room (1) in POS selection
final posViewTabProvider = StateProvider<int>((ref) => 0);

// Manual refresh trigger
final refreshedTablesProvider = StateProvider<DateTime>((ref) => DateTime.now());

// Table Statuses Provider (Full real-time state)
final tableStatusesProvider = StateNotifierProvider<TableStatusNotifier, Map<int, TableModel>>((ref) {
  return TableStatusNotifier(ref);
});

class TableStatusNotifier extends StateNotifier<Map<int, TableModel>> {
  final Ref _ref;
  WebSocketService? _ws;
  int _retryCount = 0;
  Timer? _reconnectTimer;

  TableStatusNotifier(this._ref) : super({});

  Future<void> syncWithBackend() async {
    // Initial fetch
    try {
      final dio = _ref.read(dioProvider);
      final response = await dio.get('/menu/tables');
      final Map<int, TableModel> initial = {};
      for (var t in (response.data as List)) {
        final table = TableModel.fromJson(Map<String, dynamic>.from(t as Map));
        initial[table.id] = table;
      }
      if (!mounted) return;
      state = initial;
      _retryCount = 0;
    } catch (e) {
      debugPrint('Error fetching initial tables: $e');
    }

    _connectWs();
  }

  void _connectWs() {
    final settings = _ref.read(settingsProvider);
    _ws?.disconnect();
    _ws = WebSocketService(
      url: settings.effectiveApiUrl,
      onMessage: _handleWsMessage,
      onDisconnect: () => _scheduleReconnect(),
    );
    _ws?.connect();
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _retryCount++;
    final delay = Duration(seconds: (2 * _retryCount).clamp(1, 30));
    _reconnectTimer = Timer(delay, () {
      if (!mounted) return;
      _connectWs();
    });
  }

  void _handleWsMessage(dynamic data) {
    if (!mounted) return;
    _retryCount = 0;
    if (data['event_type'] == 'TableUpdated') {
      final payload = data;
      final tableId = payload['table_id'];
      final newStatus = payload['status'];
      
      if (state.containsKey(tableId)) {
        final updated = state[tableId]!.copyWith(
          status: TableModel.parseStatus(newStatus),
          isReserved: payload['is_reserved'] ?? false,
          reservedFor: payload['reserved_for'],
        );
        final newState = Map<int, TableModel>.from(state);
        newState[tableId] = updated;
        state = newState;
      }

    }
  }

  void updateTableStatus(int tableId, TableStatus status) {
    if (state.containsKey(tableId)) {
      final newState = Map<int, TableModel>.from(state);
      newState[tableId] = state[tableId]!.copyWith(status: status);
      state = newState;
    }
  }

  @override
  void dispose() {
    _reconnectTimer?.cancel();
    _ws?.disconnect();
    super.dispose();
  }
}

// Occupied Tables Provider (Derived for convenience)
final occupiedTablesProvider = Provider<Set<int>>((ref) {
  final statuses = ref.watch(tableStatusesProvider);
  return statuses.entries
      .where((e) => e.value.status != TableStatus.Available)
      .map((e) => e.key)
      .toSet();
});

// Selected Screen Provider (for app_shell navigation)
final selectedScreenProvider = StateProvider<int>((ref) => 0);

// Menu Categories Provider
final menuCategoriesProvider = FutureProvider<List<Category>>((ref) async {
  final apiClient = ref.watch(apiClientProvider);
  return await apiClient.getCategories();
});

// Menu Items Provider
final menuItemsProvider = FutureProvider<List<MenuItem>>((ref) async {
  final apiClient = ref.watch(apiClientProvider);
  return await apiClient.getMenuItems();
});

// Menu Items Map Provider
final menuItemsMapProvider = FutureProvider<Map<int, MenuItem>>((ref) async {
  final items = await ref.watch(menuItemsProvider.future);
  return {for (var item in items) item.id: item};
});

// Orders Provider
final selectedOrderDateProvider = StateProvider<DateTime?>((ref) => null);

final ordersProvider = FutureProvider<List<Order>>((ref) async {
  final apiClient = ref.watch(apiClientProvider);
  final selectedDate = ref.watch(selectedOrderDateProvider);
  String? dateStr;
  if (selectedDate != null) {
      dateStr = "${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}";
  }
  return await apiClient.getOrders(date: dateStr);
});

// Held Orders Provider
final heldOrdersProvider = FutureProvider<List<Order>>((ref) async {
  final apiClient = ref.watch(apiClientProvider);
  return await apiClient.getHeldOrders();
});

// Order Summary Provider
final orderSummaryProvider = FutureProvider<OrderSummary>((ref) async {
  final apiClient = ref.watch(apiClientProvider);
  return await apiClient.getOrderSummary();
});

// Active Orders Provider (Kitchen)
final activeOrdersProvider = StateNotifierProvider<ActiveOrdersNotifier, List<Order>>((ref) {
  return ActiveOrdersNotifier();
});

class ActiveOrdersNotifier extends StateNotifier<List<Order>> {
  ActiveOrdersNotifier() : super([]);

  void setOrders(List<Order> orders) {
    state = orders;
  }

  void addOrder(Order order) {
    if (!state.any((o) => o.id == order.id)) {
      state = [order, ...state];
    }
  }

  void updateOrder(Order order) {
    state = state.map((o) => o.id == order.id ? order : o).toList();
  }

  void removeOrder(int orderId) {
    state = state.where((o) => o.id != orderId).toList();
  }
}

// Active Order ID Provider (for POS screen)
final activeOrderIdProvider = StateProvider<int?>((ref) => null);

// Customer Providers
final currentCustomerProvider = StateProvider<Customer?>((ref) => null);
final customerProvider = StateProvider<Customer?>((ref) => null);
final customerNameProvider = StateProvider<String?>((ref) => null);
final customerPhoneProvider = StateProvider<String?>((ref) => null);
final customerMobileProvider = StateProvider<String?>((ref) => null);

// Discount Provider
final cartDiscountProvider = StateProvider<double>((ref) => 0.0);

// Order Type Provider
final orderTypeProvider = StateProvider<String>((ref) => 'dine_in');

// POS Operation Processing Provider (Debouncing)
final posProcessingProvider = StateProvider<bool>((ref) => false);

// Connectivity Provider
final connectivityProvider = StreamProvider<List<ConnectivityResult>>((ref) {
  return Connectivity().onConnectivityChanged;
});

// Sync Service Provider
final syncServiceProvider = Provider((ref) => SyncService(ref));





final systemInfoProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final apiClient = ref.watch(apiClientProvider);
  return await apiClient.getSystemInfo();
});

final pendingSyncCountProvider = StateProvider<int>((ref) {
  final box = Hive.box('pending_orders');
  final List<dynamic> queue = box.get('queue', defaultValue: []);
  return queue.length;
});

// —— Report Providers ——

final dashboardUnifiedProvider = FutureProvider.family<Map<String, dynamic>, String?>((ref, date) async {
  return ref.watch(apiClientProvider).getDashboardUnified(date: date);
});

final insightsUnifiedProvider = FutureProvider.family<Map<String, dynamic>, String?>((ref, date) async {
  return ref.watch(apiClientProvider).getInsightsUnified(date: date);
});

// —— Kitchen Counter Providers ——

final kitchenCountersProvider = StateNotifierProvider<KitchenCountersNotifier, AsyncValue<List<KitchenCounter>>>((ref) {
  return KitchenCountersNotifier(ref);
});

class KitchenCountersNotifier extends StateNotifier<AsyncValue<List<KitchenCounter>>> {
  final Ref _ref;
  KitchenCountersNotifier(this._ref) : super(const AsyncValue.loading()) {
    refresh();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    try {
      final apiClient = _ref.read(apiClientProvider);
      final counters = await apiClient.getKitchenCounters();
      state = AsyncValue.data(counters);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> addCounter(String name, {
    String icon = 'store', 
    String color = '#000000', 
    String? printerAddress,
    int? printerPort = 9100,
    String? printerType = 'network'
  }) async {
    try {
      final apiClient = _ref.read(apiClientProvider);
      await apiClient.createKitchenCounter(
        name, 
        icon: icon, 
        color: color, 
        printerAddress: printerAddress,
        printerPort: printerPort ?? 9100,
        printerType: printerType ?? 'network'
      );
      await refresh();
    } catch (e) {
      debugPrint('Error adding counter: $e');
      rethrow;
    }
  }

  Future<void> removeCounter(int id) async {
    try {
      final apiClient = _ref.read(apiClientProvider);
      await apiClient.deleteKitchenCounter(id);
      await refresh();
    } catch (e) {
      debugPrint('Error removing counter: $e');
      rethrow;
    }
  }
}

// —— Rooms Provider ——
final roomsProvider = FutureProvider<List<Room>>((ref) async {
  final apiClient = ref.watch(apiClientProvider);
  return await apiClient.getRooms();
});

// —— Roles Provider ——
final rolesProvider = FutureProvider<List<Role>>((ref) async {
  final apiClient = ref.watch(apiClientProvider);
  return await apiClient.getRoles();
});

// —— KOT History Provider Family ——
final kotHistoryProvider = FutureProvider.family<List<KOTLog>, int>((ref, orderId) async {
  final apiClient = ref.watch(apiClientProvider);
  return await apiClient.getKotHistory(orderId);
});