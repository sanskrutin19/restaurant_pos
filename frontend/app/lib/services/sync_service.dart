import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api_client.dart';
import '../models/order_model.dart';
import '../providers.dart';


class SyncService {
  final Ref _ref;
  final _connectivity = Connectivity();
  StreamSubscription? _connectivitySubscription;
  bool _isSyncing = false;

  SyncService(this._ref) {
    _init();
  }

  void _init() {
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((results) {
      if (results.any((result) => result != ConnectivityResult.none)) {
        syncPendingOrders();
      }
    });
  }

  void dispose() {
    _connectivitySubscription?.cancel();
  }

  Future<void> cacheMenuItems(List<dynamic> items) async {
    final box = Hive.box('menu_cache');
    await box.put('items', items);
  }

  List<dynamic>? getCachedMenuItems() {
    final box = Hive.box('menu_cache');
    return box.get('items');
  }

  Future<void> queueOrder(Map<String, dynamic> orderData) async {
    final box = Hive.box('pending_orders');
    final List<dynamic> pending = box.get('queue', defaultValue: []);
    pending.add(orderData);
    await box.put('queue', pending);
    
    // Update provider
    _ref.read(pendingSyncCountProvider.notifier).state = pending.length;
    
    debugPrint('Order queued locally');
  }

  Future<void> syncPendingOrders() async {
    if (_isSyncing) return;
    
    final box = Hive.box('pending_orders');
    final List<dynamic> queue = List.from(box.get('queue', defaultValue: []));
    
    if (queue.isEmpty) return;

    _isSyncing = true;
    debugPrint('Starting background sync for ${queue.length} orders...');

    final apiClient = _ref.read(apiClientProvider);
    final remaining = [];

    for (final orderData in queue) {
      try {
        // Simple create single order logic
        if (orderData['order_id'] != null) {
          // It's an addition to existing order
          await apiClient.addItemsToOrder(
            orderData['order_id'], 
            (orderData['items'] as List).map((i) => Map<String, dynamic>.from(i)).toList()
          );
        } else {
          // It's a new order - use named parameters
          await apiClient.createOrder(
            tableNumber: orderData['table_id'],
            items: (orderData['items'] as List).map((i) => Map<String, dynamic>.from(i)).toList(),
            paymentMethod: orderData['payment_method'] ?? 1,
            customerName: orderData['customer_name'],
            customerPhone: orderData['customer_phone'],
            orderType: orderData['order_type'] ?? 'dine_in',
            discountAmount: orderData['discount_amount'] ?? 0.0,
            taxRate: orderData['tax_rate'] ?? 5.0,
          );
        }
      } catch (e) {
        debugPrint('Sync failed for order: $e');
        remaining.add(orderData);
      }
    }

    await box.put('queue', remaining);
    
    // Update provider
    _ref.read(pendingSyncCountProvider.notifier).state = remaining.length;
    
    _isSyncing = false;
    
    if (remaining.isEmpty) {
      debugPrint('Sync completed successfully');
      // Invalidate orders provider to refresh UI
      _ref.invalidate(ordersProvider);
    }
  }

  int get pendingCount {
    final box = Hive.box('pending_orders');
    final List<dynamic> queue = box.get('queue', defaultValue: []);
    return queue.length;
  }
}