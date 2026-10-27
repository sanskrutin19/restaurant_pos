import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers.dart';
import '../models/order_model.dart';
import '../models/table_model.dart';

class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key});

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen> {
  String _statusFilter = 'All';
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      ref.invalidate(ordersProvider);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(ordersProvider);
    final settings = ref.watch(settingsProvider);

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Order History', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
              Row(
                children: [
                   _DateFilterWidget(),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: () {
                        ref.invalidate(ordersProvider);
                        ref.invalidate(selectedOrderDateProvider);
                    },
                    tooltip: 'Reset and Refresh',
                  ),
                ],
              )
            ],
          ),
          const SizedBox(height: 16),
          // Filters
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ['All', 'Pending', 'Preparing', 'Ready', 'Served', 'Paid', 'Cancelled'].map((status) {
                final isSelected = _statusFilter == status;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: FilterChip(
                    label: Text(status == 'All' ? 'All Orders' : status.toUpperCase()),
                    selected: isSelected,
                    onSelected: (_) => setState(() => _statusFilter = status),
                    selectedColor: Colors.deepOrange.withAlpha(51),
                    checkmarkColor: Colors.deepOrange,
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 24),
          // List
          Expanded(
            child: ordersAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (orders) {
                final filtered = _statusFilter == 'All' ? orders : orders.where((o) => o.status.toLowerCase() == _statusFilter.toLowerCase()).toList();
                
                // Sort by latest first
                filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));

                if (filtered.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.receipt_long, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('No orders found', style: TextStyle(fontSize: 18, color: Colors.grey)),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final order = filtered[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 2,
                      child: ExpansionTile(
                        leading: CircleAvatar(
                          backgroundColor: _getStatusColor(order.status),
                          child: const Icon(Icons.receipt, color: Colors.white),
                        ),
                        title: Row(
                          children: [
                            Text('Order #${order.id}', style: const TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(width: 16),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(color: _getStatusColor(order.status), borderRadius: BorderRadius.circular(12)),
                              child: Text(order.status.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 12)),
                            ),
                          ],
                        ),
                        subtitle: Text(
                          'Table ${order.tableNumber} • ${DateFormat('MMM dd, yyyy - hh:mm a').format(order.createdAt)} • ${settings.currencySymbol}${order.totalAmount.toStringAsFixed(2)}',
                        ),
                        trailing: _buildActionButtons(context, ref, order),
                        children: [
                          const Divider(),
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Order Items:', style: TextStyle(fontWeight: FontWeight.bold)),
                                const SizedBox(height: 8),
                                ...order.items.map((item) => Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('${item.quantity}x ${item.name}'),
                                      Text('${settings.currencySymbol}${(item.price * item.quantity).toStringAsFixed(2)}'),
                                    ],
                                  ),
                                )),
                                const Divider(),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Payment Method:', style: TextStyle(fontWeight: FontWeight.bold)),
                                    Text(order.paymentMethod?.toUpperCase() ?? 'N/A'),
                                  ],
                                ),
                              ],
                            ),
                          )
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
      case 'created': return Colors.orange;
      case 'preparing': return Colors.blue;
      case 'ready': return Colors.green;
      case 'served': return Colors.teal;
      case 'paid': return Colors.grey;
      case 'cancelled': return Colors.red;
      default: return Colors.black;
    }
  }

  Widget _buildActionButtons(BuildContext context, WidgetRef ref, Order order) {
    final s = order.status.toLowerCase();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (s == 'pending' || s == 'created')
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => _updateStatusAndFreeTable(context, ref, order, 'cancelled', 'Cancel Order?'),
            child: const Text('Cancel Order'),
          ),
        if (s == 'ready')
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.teal, 
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => _updateStatus(context, ref, order.id, 'served'),
            child: const Text('Mark Served', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        if (s == 'ready') const SizedBox(width: 12),
        if (s == 'served' || s == 'ready')
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: s == 'served' ? Colors.grey[700] : Colors.blueGrey, 
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => _updateStatus(context, ref, order.id, 'paid'),
            child: const Text('Mark Paid', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        const SizedBox(width: 8),
        const Icon(Icons.expand_more)
      ],
    );
  }

  Future<void> _updateStatus(BuildContext context, WidgetRef ref, int id, String status) async {
    try {
      final api = ref.read(apiClientProvider);
      await api.updateOrderStatus(id, status);


      ref.invalidate(ordersProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Order marked as $status ${status.toLowerCase() == 'paid' ? '& Stock Deducted' : ''}'), 
        backgroundColor: Colors.green
      ));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _updateStatusAndFreeTable(BuildContext context, WidgetRef ref, Order order, String status, String title) async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: const Text('Are you sure you want to perform this action?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('No')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref.read(apiClientProvider).updateOrderStatus(order.id, status);
                
                // Free table if cancelled
                ref.read(tableStatusesProvider.notifier).updateTableStatus(
                  order.tableNumber, 
                  TableStatus.Available
                );

                ref.invalidate(ordersProvider);
                if (mounted && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Order marked as $status'), backgroundColor: Colors.green));
                }
              } catch (e) {
                if (mounted && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red));
                }
              }
            },
            child: const Text('Yes'),
          ),
        ],
      ),
    );
  }
}
class _DateFilterWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDate = ref.watch(selectedOrderDateProvider);
    
    return OutlinedButton.icon(
      icon: const Icon(Icons.calendar_today, size: 18),
      label: Text(
        selectedDate == null 
          ? 'Today' 
          : DateFormat('MMM dd, yyyy').format(selectedDate),
      ),
      onPressed: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: selectedDate ?? DateTime.now(),
          firstDate: DateTime(2023),
          lastDate: DateTime.now(),
        );
        if (picked != null) {
          ref.read(selectedOrderDateProvider.notifier).state = picked;
        }
      },
      style: OutlinedButton.styleFrom(
        foregroundColor: selectedDate != null ? Colors.deepOrange : Colors.grey[700],
        side: BorderSide(
          color: selectedDate != null ? Colors.deepOrange : Colors.grey[300]!,
        ),
      ),
    );
  }
}
