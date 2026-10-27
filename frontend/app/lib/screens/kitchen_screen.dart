import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers.dart';
import '../models/order_model.dart';
import '../models/table_model.dart';
import '../services/websocket_service.dart';
import '../models/system_model.dart';
import '../services/printer_service.dart';
import '../models/menu_model.dart';

class KitchenScreen extends ConsumerStatefulWidget {
  const KitchenScreen({super.key});

  @override
  ConsumerState<KitchenScreen> createState() => _KitchenScreenState();
}

class _KitchenScreenState extends ConsumerState<KitchenScreen> with SingleTickerProviderStateMixin {
  WebSocketService? _webSocketService;
  bool _isWsConnected = false;
  Timer? _reconnectTimer;
  Timer? _tickTimer;
  Timer? _pollingTimer;
  int? _highlightedOrderId;
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchInitialOrders();
      _connectWebSocket();
      _tickTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        if (mounted) setState(() {});
      });
      _pollingTimer = Timer.periodic(const Duration(seconds: 10), (_) {
        if (mounted && !_isWsConnected) {
          _fetchInitialOrders();
        }
      });
    });
  }

  Future<void> _fetchInitialOrders() async {
    try {
      final allOrders = await ref.read(apiClientProvider).getOrders();
      if (!mounted) return;
      final active = allOrders.where((o) {
        final s = o.status.toLowerCase();
        return s == 'pending' || s == 'preparing' || s == 'created';
      }).toList();
      active.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      ref.read(activeOrdersProvider.notifier).setOrders(active);
    } catch (e) {
      debugPrint('Error fetching initial kitchen orders: $e');
    }
  }

  void _connectWebSocket() {
    try {
      final settings = ref.read(settingsProvider);
      _webSocketService = WebSocketService(
        url: settings.apiBaseUrl,
        onMessage: _handleWsMessage,
        onDisconnect: _handleWsDisconnect,
      );
      _webSocketService!.connect();
      setState(() => _isWsConnected = true);
    } catch (e) {
      debugPrint('WebSocket connection failed: $e - Using polling fallback');
      setState(() => _isWsConnected = false);
    }
  }

  void _handleWsMessage(dynamic data) {
    if (!mounted) return;

    final event = data['event'];
    final payload = data['data'];

    if (event == 'order_created') {
      final order = Order.fromJson(payload);
      final s = order.status.toLowerCase();
      if (s == 'pending' || s == 'preparing' || s == 'created') {
        ref.read(activeOrdersProvider.notifier).addOrder(order);
        _highlightOrder(order.id);
        _playSound();
      }
    } else if (event == 'order_status_updated') {
      final orderId = payload['order_id'];
      final status = payload['status'];

      final activeOrders = ref.read(activeOrdersProvider);
      final existingOrder = activeOrders.firstWhere(
        (o) => o.id == orderId,
        orElse: () => Order(id: -1, tableNumber: 0, status: '', items: [], createdAt: DateTime.now()),
      );

      if (existingOrder.id != -1) {
        final s = status.toLowerCase();
        if (s == 'pending' || s == 'preparing' || s == 'created') {
          final updated = Order(
            id: existingOrder.id,
            tableNumber: existingOrder.tableNumber,
            status: status,
            paymentMethod: existingOrder.paymentMethod,
            createdAt: existingOrder.createdAt,
            items: existingOrder.items,
          );
          ref.read(activeOrdersProvider.notifier).updateOrder(updated);
        } else {
          ref.read(activeOrdersProvider.notifier).removeOrder(orderId);
          if (status == 'ready' || status == 'cancelled') {
            ref.read(tableStatusesProvider.notifier).updateTableStatus(
              existingOrder.tableNumber, 
              TableStatus.Available
            );
          }
        }
      }
    } else if (event == 'order_cancelled') {
      final orderId = payload['order_id'];
      final activeOrders = ref.read(activeOrdersProvider);
      final order = activeOrders.cast<Order?>().firstWhere(
        (o) => o?.id == orderId,
        orElse: () => null,
      );
      if (order != null) {
        ref.read(activeOrdersProvider.notifier).removeOrder(orderId);
        ref.read(tableStatusesProvider.notifier).updateTableStatus(
          order.tableNumber, 
          TableStatus.Available
        );
      }
    } else if (event == 'ItemAdded') {
      // Logic for item added in real-time
      final orderId = payload['order_id'];
      final activeOrders = ref.read(activeOrdersProvider);
      final existingIndex = activeOrders.indexWhere((o) => o.id == orderId);
      
      if (existingIndex != -1) {
        final existingOrder = activeOrders[existingIndex];
        // We could fetch the full order or just add the item if payload has it
        // For simplicity and accuracy, let's re-fetch the specific order if it's already there
        // or just update our local list if we have enough info.
        _fetchInitialOrders(); // Simple way to ensure consistency until more granular update is added
      }
    }
  }

  void _handleWsDisconnect() {
    if (_isDisposed || !mounted) return;
    setState(() => _isWsConnected = false);

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (_isDisposed || !mounted) {
        timer.cancel();
        return;
      }
      if (!_isWsConnected) {
        try {
          _connectWebSocket();
        } catch (e) {
          debugPrint('Reconnection attempt failed: $e');
        }
      }
    });
  }

  void _highlightOrder(int orderId) {
    if (!mounted) return;
    setState(() => _highlightedOrderId = orderId);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && _highlightedOrderId == orderId) {
        setState(() => _highlightedOrderId = null);
      }
    });
  }

  void _playSound() {
    final settings = ref.read(settingsProvider);
    if (settings.kitchenSoundEnabled) {
      // Use system beep (works offline without asset files)
      SystemSound.play(SystemSoundType.alert);
      // Also try audio player with bundled asset if available
      try {
        _audioPlayer.play(AssetSource('notification.mp3'), volume: 1.0);
      } catch (_) {
        // Fallback to system beep already played above
      }
    }
  }

  Future<void> _printKot(int orderId) async {
    try {
      final activeOrders = ref.read(activeOrdersProvider);
      final order = activeOrders.firstWhere((o) => o.id == orderId);
      final counters = ref.read(kitchenCountersProvider).value ?? [];
      
      // Calculate version and action for reprint
      int kotVersion = 1;
      String? kotAction;
      if (order.items.isNotEmpty) {
         kotVersion = order.items.map((i) => i.kotVersion).reduce((a, b) => a > b ? a : b);
         if (kotVersion > 1) kotAction = 'modified';
      }

      await PrinterService().printKOT(
        order: order,
        items: order.items,
        counters: counters,
        isReprint: true,
        kotVersion: kotVersion,
        kotAction: kotAction,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('KOT Reprint sent to thermal printers'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      // Fallback to browser print if direct print fails
      try {
        final url = ref.read(apiClientProvider).getKotPrintUrl(orderId);
        if (await canLaunchUrl(Uri.parse(url))) {
          await launchUrl(Uri.parse(url));
        }
      } catch (err) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Print Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _updateStatus(int orderId, String newStatus) async {
    try {
      await ref.read(apiClientProvider).updateOrderStatus(orderId, newStatus);
      await _fetchInitialOrders();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Order updated to $newStatus'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update status: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showCancelDialog(int orderId) async {
    final pinController = TextEditingController();
    final reasonController = TextEditingController();
    
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel KOT', style: TextStyle(color: Colors.red)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter Manager/Admin PIN to cancel this KOT:'),
            const SizedBox(height: 12),
            TextField(
              controller: pinController,
              obscureText: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'PIN', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(labelText: 'Reason (Optional)', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Back')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              final pin = pinController.text.trim();
              if (pin.isEmpty) {
                 ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('PIN is required'), backgroundColor: Colors.red));
                 return;
              }
              Navigator.pop(ctx);
              try {
                 await ref.read(apiClientProvider).cancelKot(orderId, pin, reasonController.text.trim());
                 
                 // PRINT CANCELLATION TICKET TO KITCHEN
                 try {
                   final allOrders = await ref.read(apiClientProvider).getOrders();
                   final cancelledOrder = allOrders.firstWhere((o) => o.id == orderId);
                   final counters = ref.read(kitchenCountersProvider).value ?? [];
                   
                   // New version for cancellation
                   int kotVersion = (cancelledOrder.items.isNotEmpty 
                      ? cancelledOrder.items.map((i) => i.kotVersion).reduce((a, b) => a > b ? a : b)
                      : 0) + 1;

                   await PrinterService().printKOT(
                     order: cancelledOrder,
                     items: cancelledOrder.items,
                     counters: counters,
                     kotAction: 'cancelled',
                     kotVersion: kotVersion,
                   );
                 } catch (printErr) {
                   debugPrint('Error printing cancellation KOT: $printErr');
                 }

                 await _fetchInitialOrders();
                 if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('KOT Cancelled & Kitchen notified'), backgroundColor: Colors.green));
                 }
              } catch (e) {
                 if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to cancel KOT: $e'), backgroundColor: Colors.red));
                 }
              }
            },
            child: const Text('Confirm Cancel'),
          ),
        ],
      ),
    );
  }

  String _timeElapsed(DateTime createdAt) {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 1) return "Just now";
    return "${diff.inMinutes} min${diff.inMinutes > 1 ? 's' : ''} ago";
  }

  @override
  void dispose() {
    _isDisposed = true;
    _tickTimer?.cancel();
    _pollingTimer?.cancel();
    _reconnectTimer?.cancel();
    _webSocketService?.disconnect();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final activeOrders = ref.watch(activeOrdersProvider);
    final theme = Theme.of(context);

    // Calculate stats
    final pendingCount = activeOrders.where((o) => o.status.toLowerCase() == 'pending' || o.status.toLowerCase() == 'created').length;
    final preparingCount = activeOrders.where((o) => o.status.toLowerCase() == 'preparing').length;
    final readyCount = activeOrders.where((o) => o.status.toLowerCase() == 'ready').length;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Slate 900
      body: Column(
        children: [
          // Premium Header
          _buildKitchenDashboardHeader(pendingCount, preparingCount, readyCount),

          if (!_isWsConnected)
            _buildOfflineBanner(),

          // Main Display Grid
          Expanded(
            child: activeOrders.isEmpty
                ? _buildEmptyState()
                : _buildOrderGrid(activeOrders),
          ),
        ],
      ),
    );
  }

  Widget _buildKitchenDashboardHeader(int pending, int preparing, int ready) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B), // Slate 800
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.soup_kitchen_rounded, color: Colors.amber, size: 36),
          const SizedBox(width: 16),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('KITCHEN OPS', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
              Text('Live Order Management', style: TextStyle(color: Colors.white60, fontSize: 13, fontWeight: FontWeight.w500)),
            ],
          ),
          const Spacer(),
          _buildStatItem('PENDING', pending.toString(), Colors.orange),
          const SizedBox(width: 24),
          _buildStatItem('PREPARING', preparing.toString(), Colors.blue),
          const SizedBox(width: 24),
          _buildStatItem('READY', ready.toString(), Colors.green),
          const SizedBox(width: 24),
          _buildDigitalClock(),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  Widget _buildDigitalClock() {
    return StreamBuilder(
      stream: Stream.periodic(const Duration(seconds: 1)),
      builder: (context, snapshot) {
        return Text(
          DateFormat('HH:mm').format(DateTime.now()),
          style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w300, fontFamily: 'monospace'),
        );
      },
    );
  }

  Widget _buildOfflineBanner() {
    return Container(
      width: double.infinity,
      color: Colors.redAccent,
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.wifi_off_rounded, color: Colors.white, size: 16),
          SizedBox(width: 8),
          Text('OFFLINE MODE — POLLING ACTIVE', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_outline_rounded, color: Colors.white.withOpacity(0.05), size: 200),
          const SizedBox(height: 24),
          const Text('ALL CLEAR', style: TextStyle(color: Colors.white24, fontSize: 40, fontWeight: FontWeight.w900, letterSpacing: 2)),
          const Text('No pending orders in the queue', style: TextStyle(color: Colors.white24, fontSize: 18)),
        ],
      ),
    );
  }

  Widget _buildOrderGrid(List<Order> orders) {
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 220,
        childAspectRatio: 0.58,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: orders.length,
      itemBuilder: (context, index) => _KitchenTicket(
        order: orders[index],
        isHighlighted: _highlightedOrderId == orders[index].id,
        onUpdateStatus: _updateStatus,
        onCancel: _showCancelDialog,
        onPrint: _printKot,
        timeElapsed: _timeElapsed(orders[index].createdAt),
      ),
    );
  }
}

class _KitchenTicket extends ConsumerWidget {
  final Order order;
  final bool isHighlighted;
  final Function(int, String) onUpdateStatus;
  final Function(int) onCancel;
  final Function(int) onPrint;
  final String timeElapsed;

  const _KitchenTicket({
    required this.order,
    required this.isHighlighted,
    required this.onUpdateStatus,
    required this.onCancel,
    required this.onPrint,
    required this.timeElapsed,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final diff = DateTime.now().difference(order.createdAt);
    final bool isUrgent = diff.inMinutes >= 15;
    final bool isVeryUrgent = diff.inMinutes >= 30;

    final Color statusColor = _getStatusColor(order.status);
    final Color ticketBg = isVeryUrgent ? const Color(0xFF450A0A) : const Color(0xFF1E293B);
    final Color accentColor = isUrgent ? Colors.redAccent : statusColor;

    return AnimatedScale(
      scale: isHighlighted ? 1.02 : 1.0,
      duration: const Duration(milliseconds: 200),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: ticketBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isHighlighted ? Colors.white : (isUrgent ? Colors.redAccent : Colors.white10),
            width: isHighlighted ? 2 : 1,
          ),
          boxShadow: [
            if (isHighlighted || isUrgent)
              BoxShadow(color: accentColor.withOpacity(0.3), blurRadius: 10, spreadRadius: 1),
          ],
        ),
        child: Column(
          children: [
            _buildHeader(isUrgent, accentColor),
            Expanded(child: _buildItemList(ref)),
            _buildActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isUrgent, Color accentColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            accentColor.withOpacity(isUrgent ? 0.3 : 0.15),
            Colors.transparent,
          ],
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TABLE ${order.tableNumber}',
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                    ),
                    Text(
                      'ID: #${order.id}',
                      style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: accentColor.withOpacity(0.3)),
                ),
                child: Text(
                  order.status.toUpperCase(),
                  style: TextStyle(color: accentColor, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.access_time_filled_rounded, color: isUrgent ? Colors.redAccent : Colors.white24, size: 12),
              const SizedBox(width: 4),
              Text(
                timeElapsed,
                style: TextStyle(
                  color: isUrgent ? Colors.redAccent : Colors.white24,
                  fontSize: 11,
                  fontWeight: isUrgent ? FontWeight.w900 : FontWeight.w600,
                ),
              ),
              const Spacer(),
              if (order.customerName != null)
                Text(
                  order.customerName!.toUpperCase(),
                  style: const TextStyle(color: Colors.blueAccent, fontSize: 9, fontWeight: FontWeight.w900),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildItemList(WidgetRef ref) {
    final itemsMapAsync = ref.watch(menuItemsMapProvider);
    
    return itemsMapAsync.when(
      data: (itemsMap) => ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: order.items.length,
        separatorBuilder: (_, __) => Divider(color: Colors.white.withOpacity(0.05), height: 16),
        itemBuilder: (context, iIndex) {
          final item = order.items[iIndex];
          final itemName = item.name.isNotEmpty ? item.name : (itemsMap[item.menuItemId]?.name ?? 'Loading...');
          
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${item.quantity}',
                style: const TextStyle(color: Colors.amber, fontSize: 16, fontWeight: FontWeight.w900),
              ),
              const SizedBox(width: 4),
              const Text('x', style: TextStyle(color: Colors.white24, fontSize: 10)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      itemName,
                      style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600, height: 1.2),
                    ),
                    if (item.notes != null && item.notes!.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.orange.withOpacity(0.1)),
                        ),
                        child: Text(
                          item.notes!,
                          style: const TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.w600, fontStyle: FontStyle.italic),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const Center(child: Text('Error')),
    );
  }

  Widget _buildActions() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.2),
      ),
      child: Row(
        children: [
          _buildToolBtn(Icons.cancel_outlined, Colors.redAccent, () => onCancel(order.id)),
          const SizedBox(width: 8),
          _buildToolBtn(Icons.print_rounded, Colors.white30, () => onPrint(order.id)),
          const SizedBox(width: 8),
          Expanded(child: _buildMainActionButton()),
        ],
      ),
    );
  }

  Widget _buildToolBtn(IconData icon, Color color, VoidCallback onPressed) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.1)),
        ),
        child: Icon(icon, color: color, size: 16),
      ),
    );
  }

  Widget _buildMainActionButton() {
    final status = order.status.toLowerCase();
    String label = "DONE";
    IconData icon = Icons.check_circle_rounded;
    Color color = Colors.green;
    String nextStatus = "ready";

    if (status == 'pending' || status == 'created') {
      label = "PREP";
      icon = Icons.play_arrow_rounded;
      color = Colors.blue;
      nextStatus = "preparing";
    } else if (status == 'preparing') {
      label = "READY";
      icon = Icons.check_circle_rounded;
      color = Colors.green;
      nextStatus = "ready";
    } else if (status == 'ready') {
      label = "SERVED";
      icon = Icons.delivery_dining_rounded;
      color = Colors.teal;
      nextStatus = "served";
    }

    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        elevation: 0,
      ),
      onPressed: () => onUpdateStatus(order.id, nextStatus),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1)),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending': return Colors.orange;
      case 'preparing': return Colors.blue;
      case 'ready': return Colors.green;
      default: return Colors.white60;
    }
  }
}