import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/pos_theme.dart';
import '../models/order_model.dart' hide CartItemModifier;
import '../models/menu_model.dart';
import '../models/cart_model.dart';
import '../models/bill_model.dart';
import '../models/table_model.dart';
import '../models/room_model.dart';
import '../providers.dart';
import '../services/api_client.dart';
import '../services/printer_service.dart';
import '../models/system_model.dart';

// ══════════════════════════════════════════════════════════════════════
//  POS SCREEN — Entry point: Table Selection ↔ Order Screen
// ══════════════════════════════════════════════════════════════════════

class PosScreen extends ConsumerStatefulWidget {
  const PosScreen({super.key});

  @override
  ConsumerState<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends ConsumerState<PosScreen> {
  @override
  void initState() {
    super.initState();
    // Real-time table status is now managed by tableStatusesProvider in providers.dart
  }

  @override
  Widget build(BuildContext context) {


    final selectedTable = ref.watch(tableProvider);
    final selectedRoom = ref.watch(roomProvider);
    if (selectedTable == null && selectedRoom == null) {
      return const _TableSelectionScreen();
    }
    return const _OrderScreen();
  }
}

// ══════════════════════════════════════════════════════════════════════
//  TABLE SELECTION — Visual grid of tables
// ══════════════════════════════════════════════════════════════════════

class _TableSelectionScreen extends ConsumerStatefulWidget {
  const _TableSelectionScreen();

  @override
  ConsumerState<_TableSelectionScreen> createState() => _TableSelectionScreenState();
}

class _TableSelectionScreenState extends ConsumerState<_TableSelectionScreen> {
  bool _isLoading = false;
  List<Order> _activeOrders = [];

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  Future<void> _refreshData() async {
    setState(() => _isLoading = true);
    try {
      final orders = await ref.read(apiClientProvider).getOrders();
      if (!mounted) return;
      setState(() {
        _activeOrders = orders
            .where((o) {
              final s = o.status.toLowerCase();
              return ['pending', 'preparing', 'ready', 'held', 'created'].contains(s);
            })
            .toList();
      });
      // Refreshing the notifier will trigger UI update
      ref.refresh(tableStatusesProvider);
    } catch (e) {
      debugPrint('Error refreshing tables: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onTableSelected(int tableNumber) {
    final tableState = ref.read(tableStatusesProvider)[tableNumber];
    if (tableState?.status == TableStatus.Reserved) {
      _showReservationDialog(tableNumber);
      return;
    }

    final existingOrders = _activeOrders.where((o) => o.tableNumber == tableNumber).toList();

    if (existingOrders.isNotEmpty) {
      _showOrderContinuationDialog(tableNumber, existingOrders.first);
    } else {
      _startNewOrder(tableNumber);
    }
  }

  void _showOrderContinuationDialog(int tableNumber, Order order) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Table $tableNumber - Occupied'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Active order (#${order.id}) is linked to this table.'),
            const SizedBox(height: 8),
            Text('Owner: ${order.customerName ?? "Guest"}'),
            Text('Current Amount: ₹${order.totalAmount.toStringAsFixed(2)}'),
            if (order.status.toLowerCase() == 'paid')
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text('NOTE: This order is PAID. Do you want to clear the table?', style: TextStyle(color: POSTheme.success, fontWeight: FontWeight.bold)),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (c) => AlertDialog(
                  title: const Text('Clear Table?'),
                  content: Text('Are you sure you want to clear Table $tableNumber and mark it as Available? This will mark Order #${order.id} as Completed.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('NO')),
                    ElevatedButton(onPressed: () => Navigator.pop(c, true), child: const Text('YES, CLEAR')),
                  ],
                ),
              );
              if (confirm == true) {
                try {
                  await ref.read(apiClientProvider).updateOrderStatus(order.id, 'Completed');
                  Navigator.pop(ctx);
                  _refreshData();
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error clearing table: $e')));
                }
              }
            },
            child: const Text('CLEAR BILL', style: TextStyle(color: POSTheme.danger)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _continueOrder(tableNumber, order);
            },
            style: ElevatedButton.styleFrom(backgroundColor: POSTheme.success),
            child: const Text('CONTINUE ORDER'),
          ),
        ],
      ),
    );
  }

  void _startNewOrder(int tableNumber) {
    ref.read(tableProvider.notifier).state = tableNumber;
    ref.read(roomProvider.notifier).state = null;
    ref.read(cartProvider.notifier).clearCart();
    ref.read(customerNameProvider.notifier).state = null;
    ref.read(customerPhoneProvider.notifier).state = null;
    ref.read(activeOrderIdProvider.notifier).state = null;
  }

  void _continueOrder(int tableNumber, Order order) {
    ref.read(tableProvider.notifier).state = tableNumber;
    ref.read(roomProvider.notifier).state = null;
    ref.read(cartProvider.notifier).clearCart();
    ref.read(activeOrderIdProvider.notifier).state = order.id;
    ref.read(customerNameProvider.notifier).state = order.customerName;
    ref.read(customerPhoneProvider.notifier).state = order.customerPhone;
    
    // Load existing items into cart
    for (final item in order.items) {
      ref.read(cartProvider.notifier).addExistingItem(
        MenuItem(
          id: item.menuItemId,
          name: item.name,
          price: item.price,
          categoryId: 0,
          isAvailable: true,
          createdAt: DateTime.now(),
        ),
        item.quantity,
        notes: item.notes,
      );
    }
  }

  void _showReservationDialog(int tableNumber) {
    final table = ref.read(tableStatusesProvider)[tableNumber];
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Table $tableNumber - Reserved'),
        content: Text('Reserved for: ${table?.reservedFor ?? "Unknown"}\n\nDo you want to clear this reservation or start an order?'),
        actions: [
          TextButton(
            onPressed: () {
               Navigator.pop(ctx);
               _toggleReservation(tableNumber, clear: true);
            },
            child: const Text('Clear Reservation', style: TextStyle(color: POSTheme.danger)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              // Force select table even if reserved
              ref.read(tableProvider.notifier).state = tableNumber;
            },
            child: const Text('Start Order'),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleReservation(int tableNumber, {bool clear = false}) async {
    final dio = ref.read(dioProvider);
    final table = ref.read(tableStatusesProvider)[tableNumber];
    
    String? reservedFor;
    if (!clear && table?.status == TableStatus.Available) {
      // Ask for name
      final controller = TextEditingController();
      reservedFor = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Reserve Table $tableNumber'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(labelText: 'Guest Name / Phone'),
            autofocus: true,
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, controller.text), child: const Text('Reserve')),
          ],
        ),
      );
      if (reservedFor == null || reservedFor.isEmpty) return;
    }

    try {
      await dio.post('/menu/tables/$tableNumber/reserve', data: {
        'is_reserved': !clear && table?.status == TableStatus.Available,
        'reserved_for': reservedFor,
      });
      // WebSocket will update the UI
    } catch (e) {
       if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
       }
    }
  }

  int? _selectedMergeSource;

  void _showTableContextMenu(BuildContext context, int tableNum, TableModel table, Order? order) {
    final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;

    showMenu<String>(
      context: context,
      position: RelativeRect.fromSize(
        Rect.fromCenter(center: overlay.size.center(Offset.zero), width: 0, height: 0),
        overlay.size,
      ),
      items: [
        if (order != null) PopupMenuItem(
          value: 'details',
          child: _menuItem(Icons.info_outline, 'View Details'),
        ),
        if (order != null) PopupMenuItem(
          value: 'transfer',
          child: _menuItem(Icons.swap_horiz_rounded, 'Transfer Table'),
        ),
        if (order != null) PopupMenuItem(
          value: 'merge',
          child: _menuItem(Icons.merge_type_rounded, 'Merge Tables'),
        ),
        if (order != null) const PopupMenuDivider(),
        if (order != null) PopupMenuItem(
          value: 'clear',
          child: _menuItem(Icons.delete_outline, 'Clear Table', color: POSTheme.danger),
        ),
        if (order == null) PopupMenuItem(
          value: 'reserve',
          child: _menuItem(
            table.status == TableStatus.Available ? Icons.event_seat_rounded : Icons.event_busy_rounded, 
            table.status == TableStatus.Available ? 'Reserve Table' : 'Clear Reservation'
          ),
        ),
      ],
    ).then((value) {
      if (value == null) return;
      switch (value) {
        case 'details':
          _showTableDetails(tableNum, order!);
          break;
        case 'transfer':
          _showTransferDialog(tableNum, order!);
          break;
        case 'merge':
          setState(() => _selectedMergeSource = tableNum);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Now tap the target table to merge Table $tableNum into'),
              backgroundColor: POSTheme.info,
            ),
          );
          break;
        case 'clear':
          _clearTable(tableNum, order!);
          break;
        case 'reserve':
          _toggleReservation(tableNum, clear: table.status != TableStatus.Available);
          break;
      }
    });
  }

  Widget _menuItem(IconData icon, String label, {Color? color}) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color ?? POSTheme.textPrimary),
        const SizedBox(width: 10),
        Text(label, style: GoogleFonts.inter(fontSize: 13, color: color ?? POSTheme.textPrimary)),
      ],
    );
  }

  void _showTableDetails(int tableNum, Order order) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Table $tableNum — Order #${order.id}'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  POSTheme.statusBadge(order.status.toUpperCase(),
                    order.status == 'ready' ? POSTheme.tableBilling : POSTheme.tableOccupied),
                  const Spacer(),
                  Text('₹${order.totalAmount.toStringAsFixed(2)}',
                    style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800, color: POSTheme.primary)),
                ],
              ),
              const Divider(height: 24),
              Text('Items', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              ...order.items.map((item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Text('${item.quantity}×', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: POSTheme.textSecondary)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(item.name, style: GoogleFonts.inter(fontSize: 13))),
                    Text('₹${(item.price * item.quantity).toStringAsFixed(0)}',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                  ],
                ),
              )),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }

  void _showTransferDialog(int tableNum, Order order) {
    final settings = ref.read(settingsProvider);
    final occupied = ref.read(occupiedTablesProvider);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Transfer Table $tableNum'),
        content: SizedBox(
          width: 400,
          height: 300,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Select destination table:',
                style: GoogleFonts.inter(fontSize: 13, color: POSTheme.textSecondary)),
              const SizedBox(height: 12),
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: settings.totalTables,
                  itemBuilder: (context, index) {
                    final t = index + 1;
                    final isCurrentTable = t == tableNum;
                    final isOccupied = occupied.contains(t);

                    return Material(
                      borderRadius: BorderRadius.circular(8),
                      color: isCurrentTable
                          ? POSTheme.primary.withOpacity(0.2)
                          : isOccupied
                              ? POSTheme.warning.withOpacity(0.1)
                              : POSTheme.surface,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: (isCurrentTable || isOccupied) ? null : () async {
                          Navigator.pop(ctx);
                          await ref.read(apiClientProvider).transferOrder(order.id, t);
                          _refreshData();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Order transferred from Table $tableNum to Table $t'),
                                backgroundColor: POSTheme.success,
                              ),
                            );
                          }
                        },
                        child: Center(
                          child: Text('$t',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w700,
                              color: isCurrentTable ? POSTheme.primary
                                  : isOccupied ? POSTheme.textMuted
                                  : POSTheme.textPrimary,
                            )),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ],
      ),
    );
  }

  Future<void> _performMerge(int targetTableNum, Order targetOrder) async {
    final sourceOrderParams = _activeOrders.where((o) => o.tableNumber == _selectedMergeSource);
    if (sourceOrderParams.isEmpty) return;
    final sourceOrder = sourceOrderParams.first;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Merge'),
        content: Text('Merge Table $_selectedMergeSource into Table $targetTableNum?\nAll items will be combined.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: POSTheme.primary),
            child: const Text('Merge'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(apiClientProvider).mergeOrders(targetOrder.id, sourceOrder.id);
      setState(() => _selectedMergeSource = null);
      _refreshData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Table $_selectedMergeSource merged into Table $targetTableNum'),
            backgroundColor: POSTheme.success,
          ),
        );
      }
    } else {
      setState(() => _selectedMergeSource = null);
    }
  }

  Future<void> _clearTable(int tableNum, Order order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Clear Table $tableNum'),
        content: const Text('This will mark the order as completed. Are you sure?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: POSTheme.danger),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(apiClientProvider).updateOrderStatus(order.id, 'completed');
      _refreshData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Table $tableNum cleared'), backgroundColor: POSTheme.success),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final tableStatuses = ref.watch(tableStatusesProvider);
    final totalTables = settings.totalTables;
    final occupiedCount = tableStatuses.values.where((t) => t.status != TableStatus.Available).length;

    return Scaffold(
      backgroundColor: POSTheme.surface,
      body: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
            decoration: BoxDecoration(
              color: POSTheme.cardColor,
              boxShadow: POSTheme.shadowSM,
            ),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(ref.watch(posViewTabProvider) == 1 ? 'Room Service' : 'Select Table',
                      style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w800, color: POSTheme.textPrimary)),
                    const SizedBox(height: 4),
                    Text(ref.watch(posViewTabProvider) == 1 ? 'Select a room for order' : '$occupiedCount of $totalTables tables occupied',
                      style: GoogleFonts.inter(fontSize: 13, color: POSTheme.textSecondary)),
                  ],
                ),
                const SizedBox(width: 32),
                ToggleButtons(
                  isSelected: [ref.watch(posViewTabProvider) == 0, ref.watch(posViewTabProvider) == 1],
                  onPressed: (index) {
                    ref.read(posViewTabProvider.notifier).state = index;
                  },
                  borderRadius: BorderRadius.circular(12),
                  color: POSTheme.textSecondary,
                  selectedColor: Colors.white,
                  fillColor: POSTheme.primary,
                  constraints: const BoxConstraints(minHeight: 36),
                  children: [
                    Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text('Tables', style: GoogleFonts.inter(fontWeight: FontWeight.w600))),
                    Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text('Rooms', style: GoogleFonts.inter(fontWeight: FontWeight.w600))),
                  ],
                ),
                const Spacer(),
                // Sync status
                Consumer(
                  builder: (context, ref, _) {
                    final pendingCount = ref.watch(pendingSyncCountProvider);
                    if (pendingCount == 0) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(right: 16.0),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: POSTheme.warning.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: POSTheme.warning.withOpacity(0.5)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.cloud_off_rounded, size: 16, color: POSTheme.warning),
                            const SizedBox(width: 8),
                            Text(
                              '$pendingCount PENDING SYNC',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: POSTheme.warning,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                // Legend
                if (ref.watch(posViewTabProvider) == 0) Row(
                  children: [
                    _legendDot(POSTheme.tableEmpty, 'Available'),
                    const SizedBox(width: 16),
                    _legendDot(POSTheme.tableOccupied, 'Occupied'),
                    const SizedBox(width: 16),
                    _legendDot(POSTheme.warning, 'Held'),
                    const SizedBox(width: 16),
                    _legendDot(Colors.deepOrange, 'Kitchen'),
                    const SizedBox(width: 16),
                    _legendDot(Colors.teal, 'Ready'),
                  ],
                ),
                const SizedBox(width: 24),
                IconButton(
                  onPressed: _refreshData,
                  icon: _isLoading
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.refresh_rounded),
                  tooltip: 'Refresh',
                ),
                if (ref.watch(posViewTabProvider) == 1) ...[
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () {
                      ref.read(selectedScreenProvider.notifier).state = 10; // Navigate to Room Management
                    },
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Add Room'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: POSTheme.primary,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Table grid
          // Grid wrapper
          Expanded(
            child: (ref.watch(posViewTabProvider) == 1) 
              ? ref.watch(roomsProvider).when(
                  data: (rooms) => Padding(
                    padding: const EdgeInsets.all(24),
                    child: GridView.builder(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 5, childAspectRatio: 1.2, crossAxisSpacing: 16, mainAxisSpacing: 16),
                      itemCount: rooms.length,
                      itemBuilder: (context, index) {
                        final room = rooms[index];
                        final activeRoomOrders = _activeOrders.where((o) => o.roomNumber == room.roomNumber).toList();
                        return _buildRoomCard(room, activeRoomOrders);
                      },
                    ),
                  ),
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Error: $e')),
                )
              : Padding(
                  padding: const EdgeInsets.all(24),
                  child: GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 5, childAspectRatio: 1.2, crossAxisSpacing: 16, mainAxisSpacing: 16),
                    itemCount: totalTables,
                    itemBuilder: (context, index) {
                      final tableNum = index + 1;
                      final tableState = tableStatuses[tableNum] ?? TableModel(id: tableNum, name: 'Table $tableNum', status: TableStatus.Available);
                      final tableOrder = _activeOrders.where((o) => o.tableNumber == tableNum).toList();
                      return _buildTableCard(tableNum, tableState, tableOrder);
                    },
                  ),
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableCard(int tableNum, TableModel table, List<Order> orders) {
    Color color = POSTheme.tableEmpty;
    IconData icon = Icons.table_restaurant_rounded;
    String statusLabel = 'Available';
    Color labelColor = POSTheme.success;

    switch (table.status) {
      case TableStatus.Occupied:
        color = POSTheme.tableOccupied;
        icon = Icons.restaurant_rounded;
        statusLabel = 'Occupied';
        labelColor = POSTheme.tableOccupied;
        break;
      case TableStatus.Held:
        color = POSTheme.warning;
        icon = Icons.pause_circle_outline_rounded;
        statusLabel = 'Held';
        labelColor = POSTheme.warning;
        break;
      case TableStatus.Preparing:
        color = Colors.deepOrange;
        icon = Icons.soup_kitchen_rounded;
        statusLabel = 'In Kitchen';
        labelColor = Colors.deepOrange;
        break;
      case TableStatus.Ready:
        color = Colors.teal;
        icon = Icons.notifications_active_rounded;
        statusLabel = 'Ready';
        labelColor = Colors.teal;
        break;
      case TableStatus.Billing:
        color = POSTheme.info;
        icon = Icons.receipt_long_rounded;
        statusLabel = 'Billing';
        labelColor = POSTheme.info;
        break;
      case TableStatus.Reserved:
        color = POSTheme.primary;
        icon = Icons.event_seat_rounded;
        statusLabel = 'Reserved';
        labelColor = POSTheme.primary;
        break;
      case TableStatus.Available:
        color = POSTheme.tableEmpty;
        icon = Icons.table_restaurant_rounded;
        statusLabel = 'Available';
        labelColor = POSTheme.success;
        break;
      default:
        color = POSTheme.tableEmpty;
        icon = Icons.table_restaurant_rounded;
        statusLabel = 'Available';
        labelColor = POSTheme.success;
        break;
    }

    final orderAmount = orders.isNotEmpty ? orders.first.totalAmount : 0.0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (_selectedMergeSource != null && orders.isNotEmpty && _selectedMergeSource != tableNum) {
            _performMerge(tableNum, orders.first);
            return;
          }
          _onTableSelected(tableNum);
        },
        onLongPress: () {
          Future.microtask(() {
            if (mounted) _showTableContextMenu(context, tableNum, table, orders.isNotEmpty ? orders.first : null);
          });
        },
        borderRadius: BorderRadius.circular(POSTheme.radiusLG),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: (_selectedMergeSource != null && orders.isNotEmpty && _selectedMergeSource != tableNum)
                ? POSTheme.info.withOpacity(0.08)
                : POSTheme.cardColor,
            borderRadius: BorderRadius.circular(POSTheme.radiusLG),
            border: Border.all(
              color: (_selectedMergeSource != null && orders.isNotEmpty && _selectedMergeSource != tableNum) 
                  ? POSTheme.info 
                  : color.withOpacity(0.4), 
              width: (_selectedMergeSource != null && orders.isNotEmpty && _selectedMergeSource != tableNum) ? 2.5 : 2
            ),
            boxShadow: POSTheme.shadowSM,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 22,
                ),
              ),
              const SizedBox(height: 8),
              Text(table.name,
                style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15, color: POSTheme.textPrimary)),
              const SizedBox(height: 4),
              if (orderAmount > 0)
                Text('₹${orderAmount.toStringAsFixed(0)}',
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: POSTheme.primary)),
              if (orderAmount == 0)
                Text(statusLabel,
                  style: GoogleFonts.inter(fontSize: 11, color: labelColor, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: GoogleFonts.inter(fontSize: 12, color: POSTheme.textSecondary)),
      ],
    );
  }

  void _onRoomSelected(Room room) {
    final existingOrders = _activeOrders.where((o) => o.roomNumber == room.roomNumber).toList();
    if (existingOrders.isNotEmpty) {
      _showRoomOrderContinuationDialog(room, existingOrders.first);
    } else {
      _startRoomOrder(room);
    }
  }

  void _startRoomOrder(Room room) {
    ref.read(tableProvider.notifier).state = null;
    ref.read(roomProvider.notifier).state = room.roomNumber;
    ref.read(cartProvider.notifier).clearCart();
    ref.read(customerNameProvider.notifier).state = room.guestName;
    ref.read(customerPhoneProvider.notifier).state = null;
    ref.read(activeOrderIdProvider.notifier).state = null;
    ref.read(orderTypeProvider.notifier).state = 'room_service';
  }

  void _showRoomOrderContinuationDialog(Room room, Order order) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Room ${room.roomNumber} - Active Order'),
        content: Text('There is an active order (#${order.id}) for this room.\nAmount: ₹${order.totalAmount.toStringAsFixed(2)}'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(tableProvider.notifier).state = null;
              ref.read(roomProvider.notifier).state = room.roomNumber;
              ref.read(cartProvider.notifier).clearCart();
              ref.read(activeOrderIdProvider.notifier).state = order.id;
              ref.read(customerNameProvider.notifier).state = order.customerName;
              ref.read(customerPhoneProvider.notifier).state = order.customerPhone;
              for (final item in order.items) {
                ref.read(cartProvider.notifier).addExistingItem(
                  MenuItem(id: item.menuItemId, name: item.name, price: item.price, categoryId: 0, isAvailable: true, createdAt: DateTime.now()),
                  item.quantity, notes: item.notes,
                );
              }
              ref.read(orderTypeProvider.notifier).state = 'room_service';
            },
            style: ElevatedButton.styleFrom(backgroundColor: POSTheme.primary),
            child: const Text('CONTINUE ORDER'),
          ),
        ],
      ),
    );
  }

  Widget _buildRoomCard(Room room, List<Order> orders) {
    bool isOccupied = room.status.toLowerCase() != 'available';
    Color color = isOccupied ? POSTheme.tableOccupied : POSTheme.tableEmpty;
    final orderAmount = orders.isNotEmpty ? orders.first.totalAmount : 0.0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _onRoomSelected(room),
        borderRadius: BorderRadius.circular(POSTheme.radiusLG),
        child: Container(
          decoration: BoxDecoration(
            color: POSTheme.cardColor,
            borderRadius: BorderRadius.circular(POSTheme.radiusLG),
            border: Border.all(color: color.withOpacity(0.4), width: 2),
            boxShadow: POSTheme.shadowSM,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.meeting_room_rounded, color: color, size: 22),
              ),
              const SizedBox(height: 8),
              Text(room.roomNumber, style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15, color: POSTheme.textPrimary)),
              if (room.guestName?.isNotEmpty == true) ...[
                const SizedBox(height: 4),
                Text(room.guestName!, style: GoogleFonts.inter(fontSize: 11, color: POSTheme.textSecondary), maxLines: 1),
              ],
              const SizedBox(height: 4),
              if (orderAmount > 0)
                Text('₹${orderAmount.toStringAsFixed(0)}', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: POSTheme.primary)),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
//  ORDER SCREEN — Triple Pane: Categories | Items | Cart
// ══════════════════════════════════════════════════════════════════════

class _OrderScreen extends ConsumerStatefulWidget {
  const _OrderScreen();

  @override
  ConsumerState<_OrderScreen> createState() => _OrderScreenState();
}

class _OrderScreenState extends ConsumerState<_OrderScreen> {
  int? _selectedCategoryId;
  String _searchQuery = '';
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tableNum = ref.watch(tableProvider) ?? 0;

    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.escape): () {
          ref.read(tableProvider.notifier).state = null;
          ref.read(roomProvider.notifier).state = null;
          ref.read(cartProvider.notifier).clearCart();
        },
        const SingleActivator(LogicalKeyboardKey.keyF, control: true): () {
          _searchFocus.requestFocus();
        },
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: POSTheme.surface,
          body: Row(
            children: [
              // ─── Left: Categories ────────────────────────────────
              _CategoriesPanel(
                selectedCategoryId: _selectedCategoryId,
                onCategorySelected: (id) => setState(() {
                  _selectedCategoryId = id;
                  _searchQuery = '';
                  _searchController.clear();
                }),
              ),

              // ─── Center: Items ───────────────────────────────────
              Expanded(
                child: _ItemsPanel(
                  selectedCategoryId: _selectedCategoryId,
                  searchQuery: _searchQuery,
                  searchController: _searchController,
                  searchFocus: _searchFocus,
                  onSearchChanged: (q) => setState(() => _searchQuery = q),
                  tableNumber: ref.watch(tableProvider),
                  roomNumber: ref.watch(roomProvider),
                ),
              ),

              // ─── Right: Cart ─────────────────────────────────────
              const SizedBox(
                width: 360,
                child: _CartPanel(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
//  LEFT PANEL — Category navigation
// ══════════════════════════════════════════════════════════════════════

class _CategoriesPanel extends ConsumerWidget {
  final int? selectedCategoryId;
  final ValueChanged<int?> onCategorySelected;

  const _CategoriesPanel({
    required this.selectedCategoryId,
    required this.onCategorySelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(menuCategoriesProvider);

    return Container(
      width: 160, // Reduced from 200
      decoration: BoxDecoration(
        color: POSTheme.cardColor,
        border: Border(right: BorderSide(color: POSTheme.border)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'CATEGORIES',
                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: POSTheme.textMuted, letterSpacing: 1.0)
                ),
                IconButton(
                  onPressed: () {
                    ref.invalidate(menuCategoriesProvider);
                    ref.invalidate(menuItemsProvider);
                  },
                  icon: const Icon(Icons.refresh_rounded, size: 16, color: POSTheme.primary),
                  tooltip: 'Refresh Menu',
                ),
              ],
            ),
          ),

          // "All" button
          _buildCategoryTile(null, 'All Items', Icons.apps_rounded),
          const Divider(height: 1),

          // Category list
          Expanded(
            child: categoriesAsync.when(
              data: (categories) => SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  children: (categories as List<Category>).map<Widget>((cat) => _buildCategoryTile(cat.id, cat.name, Icons.restaurant_rounded)).toList(),
                ),
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error', style: GoogleFonts.inter(color: POSTheme.danger))),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryTile(int? id, String name, IconData icon) {
    final isSelected = selectedCategoryId == id;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onCategorySelected(id),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isSelected ? POSTheme.primary.withOpacity(0.08) : Colors.transparent,
            border: Border(
              left: BorderSide(
                color: isSelected ? POSTheme.primary : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18,
                color: isSelected ? POSTheme.primary : POSTheme.textMuted),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  name,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected ? POSTheme.primary : POSTheme.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
//  CENTER PANEL — Items grid with search
// ══════════════════════════════════════════════════════════════════════

class _ItemsPanel extends ConsumerWidget {
  final int? selectedCategoryId;
  final String searchQuery;
  final TextEditingController searchController;
  final FocusNode searchFocus;
  final ValueChanged<String> onSearchChanged;
  final int? tableNumber;
  final String? roomNumber;

  const _ItemsPanel({
    required this.selectedCategoryId,
    required this.searchQuery,
    required this.searchController,
    required this.searchFocus,
    required this.onSearchChanged,
    required this.tableNumber,
    required this.roomNumber,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(menuItemsProvider);

    return Column(
      children: [
        // Search bar + table indicator
        Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          decoration: BoxDecoration(
            color: POSTheme.cardColor,
            boxShadow: POSTheme.shadowSM,
          ),
          child: Row(
            children: [
              // Table badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: POSTheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(POSTheme.radiusSM),
                  border: Border.all(color: POSTheme.primary.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    Icon(roomNumber != null ? Icons.meeting_room_rounded : Icons.table_restaurant, size: 16, color: POSTheme.primary),
                    const SizedBox(width: 6),
                    Text(roomNumber != null ? 'Room $roomNumber' : 'Table $tableNumber',
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: POSTheme.primary)),
                  ],
                ),
              ),
              const SizedBox(width: 16),

              // Search
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: TextField(
                    focusNode: searchFocus,
                    controller: searchController,
                    onChanged: onSearchChanged,
                    decoration: InputDecoration(
                      hintText: 'Search items... (Ctrl+F)',
                      hintStyle: GoogleFonts.inter(fontSize: 13, color: POSTheme.textMuted),
                      prefixIcon: const Icon(Icons.search_rounded, size: 18),
                      suffixIcon: searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 16),
                              onPressed: () {
                                searchController.clear();
                                onSearchChanged('');
                              },
                            )
                          : null,
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      filled: true,
                      fillColor: POSTheme.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(POSTheme.radiusSM),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // Sync status
              Consumer(
                builder: (context, ref, _) {
                  final pendingCount = ref.watch(pendingSyncCountProvider);
                  if (pendingCount == 0) return const SizedBox.shrink();
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: POSTheme.warning.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: POSTheme.warning.withOpacity(0.5)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.cloud_off_rounded, size: 16, color: POSTheme.warning),
                        const SizedBox(width: 8),
                        Text(
                          '$pendingCount PENDING',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: POSTheme.warning,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),

              // Back to tables
              OutlinedButton.icon(
                onPressed: () {
                  ref.read(tableProvider.notifier).state = null;
                  ref.read(roomProvider.notifier).state = null;
                  ref.read(posViewTabProvider.notifier).state = roomNumber != null ? 1 : 0;
                  ref.read(cartProvider.notifier).clearCart();
                },
                icon: Icon(roomNumber != null ? Icons.meeting_room_rounded : Icons.grid_view_rounded, size: 16),
                label: Text(roomNumber != null ? 'Rooms' : 'Tables'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: POSTheme.textSecondary,
                  side: const BorderSide(color: POSTheme.border),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
              ),
            ],
          ),
        ),

        // Items grid
        Expanded(
          child: itemsAsync.when(
            data: (allItems) {
              var items = allItems.where((i) => i.isAvailable).toList();

              if (selectedCategoryId != null) {
                items = items.where((i) => i.categoryId == selectedCategoryId).toList();
              }
              if (searchQuery.isNotEmpty) {
                final q = searchQuery.toLowerCase();
                items = items.where((i) => i.name.toLowerCase().contains(q)).toList();
              }

              if (items.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.search_off_rounded, size: 48, color: POSTheme.textMuted),
                      const SizedBox(height: 12),
                      Text('No items found',
                        style: GoogleFonts.inter(color: POSTheme.textSecondary, fontSize: 14)),
                    ],
                  ),
                );
              }

              return LayoutBuilder(
                builder: (context, constraints) {
                  // Dynamically calculate columns based on width
                  // Target min width ~220px per card for readability on Windows
                  int crossAxisCount = (constraints.maxWidth / 220).floor().clamp(2, 8);
                  
                  return GridView.builder(
                    padding: const EdgeInsets.all(20),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      mainAxisExtent: 150, // Increased for safe name mapping/price
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return _ItemCard(item: item);
                    },
                  );
                }
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error loading menu: $e')),
          ),
        ),
      ],
    );
  }
}

/// Individual menu item card
class _ItemCard extends ConsumerWidget {
  final MenuItem item;
  const _ItemCard({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);


    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          try {
            final apiClient = ref.read(apiClientProvider);
            final mods = await apiClient.getItemModifiers(item.id);
            
            // Show dialog if there are modifiers OR combo components
            if ((mods.isNotEmpty || item.comboItems.isNotEmpty) && context.mounted) {
              _showModifiersDialog(context, ref, item, mods);
            } else {
              ref.read(cartProvider.notifier).addItem(item);
              _showSuccessSnackBar(context, '${item.name} added');
            }
          } catch (e) {
            ref.read(cartProvider.notifier).addItem(item);
            _showSuccessSnackBar(context, '${item.name} added');
          }
        },
        borderRadius: BorderRadius.circular(POSTheme.radiusMD),
        child: Container(
          decoration: BoxDecoration(
            color: POSTheme.cardColor,
            borderRadius: BorderRadius.circular(POSTheme.radiusMD),
            border: Border.all(color: POSTheme.primary.withOpacity(0.12), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Text(
                    item.name,
                    style: GoogleFonts.outfit(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: POSTheme.textPrimary,
                      height: 1.2,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                  decoration: BoxDecoration(
                    color: POSTheme.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${settings.currencySymbol}${item.price.toStringAsFixed(0)}',
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: POSTheme.primary,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
//  RIGHT PANEL — Cart & Billing
// ══════════════════════════════════════════════════════════════════════

class _CartPanel extends ConsumerWidget {
  const _CartPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartItems = ref.watch(cartProvider);
    final tableNum = ref.watch(tableProvider);
    final activeOrderId = ref.watch(activeOrderIdProvider);
    final customerName = ref.watch(customerNameProvider);
    final settings = ref.watch(settingsProvider);

    return Container(
      decoration: BoxDecoration(
        color: POSTheme.cardColor,
        border: Border(left: BorderSide(color: POSTheme.border)),
      ),
      child: Column(
        children: [
          // Cart Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: POSTheme.border)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          activeOrderId != null ? 'Order #$activeOrderId' : 'New Order',
                          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: POSTheme.textPrimary),
                        ),
                        if (customerName != null)
                          Text(customerName, style: GoogleFonts.inter(fontSize: 12, color: POSTheme.textMuted)),
                      ],
                    ),
                    const Spacer(),
                    if (activeOrderId != null && tableNum != null) ...[
                      IconButton(
                        onPressed: () => _showTransferDialog(context, ref, activeOrderId!, tableNum!),
                        icon: const Icon(Icons.swap_horiz_rounded, color: POSTheme.primary),
                        tooltip: 'Transfer Table',
                      ),
                      IconButton(
                        onPressed: () => _showMergeDialog(context, ref, activeOrderId!, tableNum!),
                        icon: const Icon(Icons.merge_type_rounded, color: POSTheme.info),
                        tooltip: 'Merge Table',
                      ),
                    ],
                    if (cartItems.isNotEmpty)
                      IconButton(
                        onPressed: () {
                          ref.read(cartProvider.notifier).clearCart();
                          ref.read(customerNameProvider.notifier).state = null;
                          ref.read(customerPhoneProvider.notifier).state = null;
                          ref.read(activeOrderIdProvider.notifier).state = null;
                        },
                        icon: const Icon(Icons.delete_sweep_rounded, color: POSTheme.danger),
                        tooltip: 'Clear Cart',
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                // Customer CRM Inputs
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        onChanged: (val) => ref.read(customerNameProvider.notifier).state = val,
                        controller: TextEditingController(text: ref.read(customerNameProvider))..selection = TextSelection.collapsed(offset: ref.read(customerNameProvider)?.length ?? 0),
                        decoration: InputDecoration(
                          hintText: 'Customer Name',
                          hintStyle: GoogleFonts.inter(fontSize: 11),
                          prefixIcon: const Icon(Icons.person_outline, size: 14),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        style: GoogleFonts.inter(fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        onChanged: (val) {
                          ref.read(customerPhoneProvider.notifier).state = val;
                          ref.read(customerMobileProvider.notifier).state = val; // Sync both for lookup
                        },
                        controller: TextEditingController(text: ref.read(customerPhoneProvider))..selection = TextSelection.collapsed(offset: ref.read(customerPhoneProvider)?.length ?? 0),
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          hintText: 'Phone / Mobile',
                          hintStyle: GoogleFonts.inter(fontSize: 11),
                          prefixIcon: const Icon(Icons.phone_outlined, size: 14),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.manage_search_rounded, size: 18, color: POSTheme.primary),
                            onPressed: () => _lookupCustomer(context, ref),
                          ),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 8),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        style: GoogleFonts.inter(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Cart Items List
          Expanded(
            child: cartItems.isEmpty
                ? Center(
                    child: SizedBox(
                      width: 200,
                      height: 120,
                      child: CustomPaint(
                        painter: _EmptyCartPainter(color: Colors.grey.shade300),
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: cartItems.length,
                    separatorBuilder: (context, index) => Divider(height: 1, color: POSTheme.border.withOpacity(0.5)),
                    itemBuilder: (context, index) => _CartItemTile(cartItem: cartItems[index]),
                  ),
          ),

          // Order Type Selection
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _orderTypeChip('dine_in', 'Dine-in', ref),
                const SizedBox(width: 8),
                _orderTypeChip('takeaway', 'Takeaway', ref),
                const SizedBox(width: 8),
                _orderTypeChip('delivery', 'Delivery', ref),
              ],
            ),
          ),

          // Billing Summary
          _BillingSummary(
            subtotal: ref.watch(cartProvider.notifier).subtotal,
            taxRate: settings.taxRate,
            tableNum: tableNum ?? 0,
            activeOrderId: activeOrderId,
          ),
        ],
      ),
    );
  }

  Widget _orderTypeChip(String type, String label, WidgetRef ref) {
    final current = ref.watch(orderTypeProvider);
    final isActive = current == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => ref.read(orderTypeProvider.notifier).state = type,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: isActive ? POSTheme.primary.withOpacity(0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(POSTheme.radiusSM),
            border: Border.all(
              color: isActive ? POSTheme.primary : POSTheme.border,
              width: isActive ? 1.5 : 1,
            ),
          ),
          child: Center(
            child: Text(label,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                color: isActive ? POSTheme.primary : POSTheme.textSecondary,
              )),
          ),
        ),
      ),
    );
  }

  void _lookupCustomer(BuildContext context, WidgetRef ref) async {
    final phone = ref.read(customerPhoneProvider);
    if (phone == null || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a phone number first')));
      return;
    }

    try {
      final customer = await ref.read(apiClientProvider).getCustomerByPhone(phone);
      ref.read(customerNameProvider.notifier).state = customer.name;
      ref.read(customerMobileProvider.notifier).state = customer.phone; // Map found phone directly to mobile too
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Customer Found: ${customer.name}'), backgroundColor: POSTheme.success),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Customer not found in CRM'), backgroundColor: POSTheme.warning),
        );
      }
    }
  }

  void _showTransferDialog(BuildContext context, WidgetRef ref, int orderId, int currentTable) {
    final settings = ref.read(settingsProvider);
    final occupied = ref.read(occupiedTablesProvider);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Transfer Table $currentTable'),
        content: SizedBox(
          width: 400,
          height: 300,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Select destination table:'),
              const SizedBox(height: 12),
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: settings.totalTables,
                  itemBuilder: (context, index) {
                    final t = index + 1;
                    final isCurrentTable = t == currentTable;
                    final isOccupied = occupied.contains(t);

                    return Material(
                      borderRadius: BorderRadius.circular(8),
                      color: isCurrentTable
                          ? POSTheme.primary.withOpacity(0.2)
                          : isOccupied
                              ? POSTheme.warning.withOpacity(0.1)
                              : POSTheme.surface,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: (isCurrentTable || isOccupied) ? null : () async {
                          Navigator.pop(ctx);
                          try {
                            await ref.read(apiClientProvider).transferOrder(orderId, t);
                            ref.read(tableProvider.notifier).state = t;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Transferred to Table $t'), backgroundColor: POSTheme.success),
                            );
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: $e'), backgroundColor: POSTheme.danger),
                            );
                          }
                        },
                        child: Center(
                          child: Text('$t',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w700,
                              color: isCurrentTable ? POSTheme.primary
                                  : isOccupied ? POSTheme.textMuted
                                  : POSTheme.textPrimary,
                            )),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel'))],
      ),
    );
  }

  void _showMergeDialog(BuildContext context, WidgetRef ref, int orderId, int currentTable) {
    final occupied = ref.read(occupiedTablesProvider);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Merge Table $currentTable Into...'),
        content: SizedBox(
          width: 400,
          height: 300,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Select target table to merge INTO:'),
              const SizedBox(height: 12),
              Expanded(
                child: occupied.where((t) => t != currentTable).isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.merge_type_rounded, size: 48, color: Colors.grey[300]),
                            const SizedBox(height: 16),
                            Text(
                              'No other active orders found.',
                              style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: POSTheme.textPrimary),
                            ),
                            const SizedBox(height: 8),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 32),
                              child: Text(
                                'You can only merge Table $currentTable with another table that already has an active order. To move this order to an empty table, use the "Transfer" button instead.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(fontSize: 12, color: POSTheme.textMuted),
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView(
                        children: occupied.where((t) => t != currentTable).map((t) {
                          return ListTile(
                            leading: const Icon(Icons.table_restaurant, color: POSTheme.warning),
                            title: Text('Table $t'),
                            subtitle: const Text('Tap to merge current items into this table'),
                            onTap: () async {
                              Navigator.pop(ctx);
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (c) => AlertDialog(
                                  title: const Text('Confirm Merge'),
                                  content: Text('Move all items from Table $currentTable to Table $t?'),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('No')),
                                    ElevatedButton(onPressed: () => Navigator.pop(c, true), child: const Text('Yes, Merge')),
                                  ],
                                ),
                              );

                              if (confirm == true) {
                                try {
                                  // Find target order ID from active orders
                                  final orders = await ref.read(apiClientProvider).getOrders();
                                  final targetOrder = orders.firstWhere((o) => o.tableNumber == t && ['pending', 'preparing', 'ready', 'served'].contains(o.status.toLowerCase()));
                                  
                                  await ref.read(apiClientProvider).mergeOrders(targetOrder.id, orderId);
                                  
                                  // Reset current screen
                                  ref.read(tableProvider.notifier).state = null;
                                  ref.read(cartProvider.notifier).clearCart();
                                  ref.read(activeOrderIdProvider.notifier).state = null;

                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Merged into Table $t'), backgroundColor: POSTheme.success),
                                  );
                                } catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Error: $e'), backgroundColor: POSTheme.danger),
                                  );
                                }
                              }
                            },
                          );
                        }).toList(),
                      ),
              ),
            ],
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel'))],
      ),
    );
  }
}

class _BillingSummary extends ConsumerWidget {
  final double subtotal;
  final double taxRate;
  final int tableNum;
  final int? activeOrderId;

  const _BillingSummary({
    required this.subtotal,
    required this.taxRate,
    required this.tableNum,
    this.activeOrderId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final cartDiscount = ref.watch(cartDiscountProvider);
    final cartItems = ref.watch(cartProvider);
    
    // Split Calculation Logic
    double discountableSubtotal = 0.0;
    double nonDiscountableSubtotal = 0.0;
    
    // Split items into discountable and non-discountable
    for (var item in cartItems) {
      if (item.menuItem.allowDiscount) {
        discountableSubtotal += item.total;
      } else {
        nonDiscountableSubtotal += item.total;
      }
    }

    // Apply cart discount proportionately to discountable items only
    final maxDiscountAllowed = discountableSubtotal;
    final actualDiscountApplied = cartDiscount > maxDiscountAllowed ? maxDiscountAllowed : cartDiscount;
    final finalDiscountableAmt = (discountableSubtotal - actualDiscountApplied).clamp(0.0, double.infinity);

    // Calculate Taxes strictly on taxable items
    double calculatedTotalTax = 0.0;
    for (var item in cartItems) {
      if (item.menuItem.taxEnabled) {
        double itemBaseAmt = item.total;
        
        // Distribute discount proportionately if this item is discountable
        if (item.menuItem.allowDiscount && discountableSubtotal > 0) {
          final share = item.total / discountableSubtotal;
          itemBaseAmt -= (actualDiscountApplied * share);
        }
        
        calculatedTotalTax += (itemBaseAmt * (item.menuItem.taxPercentage / 100));
      }
    }

    final total = finalDiscountableAmt + nonDiscountableSubtotal + calculatedTotalTax;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: POSTheme.surface,
        border: Border(top: BorderSide(color: POSTheme.border)),
      ),
      child: Column(
        children: [
          if (discountableSubtotal > 0)
            _summaryRow('Subtotal (Regular)', discountableSubtotal, settings.currencySymbol),
          if (nonDiscountableSubtotal > 0)
            _summaryRow('Subtotal (No-Discount)', nonDiscountableSubtotal, settings.currencySymbol),
            
          if (actualDiscountApplied > 0)
             _summaryRow('Cart Discount', -actualDiscountApplied, settings.currencySymbol, isNegative: true),
             
          if (calculatedTotalTax > 0)
             _summaryRow('Taxes Added', calculatedTotalTax, settings.currencySymbol),
             
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total Payable', 
                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: POSTheme.textPrimary)),
              Text('${settings.currencySymbol}${total.toStringAsFixed(2)}',
                style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w900, color: POSTheme.primary)),
            ],
          ),
          const SizedBox(height: 20),
          
          // Action Buttons
          Row(
            children: [
              // Hold/Save Button
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: subtotal > 0 ? () => _holdOrder(context, ref) : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: POSTheme.warning,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(POSTheme.radiusMD)),
                  ),
                  child: const Text('Hold Order', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 8),
              // Split & Pay Button
              Expanded(
                flex: 3,
                child: ElevatedButton(
                  onPressed: (subtotal > 0 && !ref.watch(posProcessingProvider)) ? () => _showSplitBillDialog(context, ref, total) : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: POSTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(POSTheme.radiusMD)),
                  ),
                  child: const Text('Split & Pay', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Quick Mark Paid for Active Orders
          if (activeOrderId != null)
            Consumer(builder: (context, ref, child) {
              final orders = ref.watch(ordersProvider).value ?? [];
              final order = orders.cast<Order?>().firstWhere((o) => o?.id == activeOrderId, orElse: () => null);
              if (order != null && (order.status.toLowerCase() == 'served' || order.status.toLowerCase() == 'ready')) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        try {
                          final api = ref.read(apiClientProvider);
                          await api.updateOrderStatus(activeOrderId!, 'paid');
                          
                          ref.invalidate(ordersProvider);
                          ref.read(activeOrderIdProvider.notifier).state = null;
                          ref.read(cartProvider.notifier).clearCart();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Order Paid & Stock Deducted'), backgroundColor: POSTheme.success),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: $e'), backgroundColor: POSTheme.danger),
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.check_circle_outline, size: 18),
                      label: const Text('MARK AS PAID (CASH/QUICK)', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.1)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueGrey[800],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(POSTheme.radiusMD)),
                      ),
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            }),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Builder(
                  builder: (context) {
                    final discount = ref.watch(cartDiscountProvider);
                    final isActive = discount > 0;
                    return OutlinedButton.icon(
                      onPressed: () => _showDiscountDialog(context, ref, subtotal),
                      icon: Icon(isActive ? Icons.local_offer_rounded : Icons.local_offer_outlined, size: 14),
                      label: Text(isActive ? '-₹${discount.toStringAsFixed(0)}' : 'Discount', style: const TextStyle(fontSize: 11), maxLines: 1),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        backgroundColor: isActive ? POSTheme.primary.withValues(alpha: 0.1) : null,
                        foregroundColor: isActive ? POSTheme.primary : null,
                        side: isActive ? const BorderSide(color: POSTheme.primary, width: 1.5) : null,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _printKOTDirect(context, ref, activeOrderId),
                  icon: const Icon(Icons.print_rounded, size: 14),
                  label: const Text('KOT', style: TextStyle(fontSize: 11), maxLines: 1),
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 4)),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: activeOrderId != null ? () async {
                    try {
                      final order = (ref.read(ordersProvider).value ?? []).firstWhere((o) => o.id == activeOrderId);
                      final settings = ref.read(settingsProvider);
                      final printerAddress = settings.billPrinterAddress;
                      
                      if (printerAddress == null || printerAddress.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bill printer not configured. Go to Settings.')));
                        return;
                      }

                      // Try to fetch bill data for full breakdown
                      Bill? billData;
                      final id = activeOrderId!; 
                      try {
                        final billJson = await ref.read(apiClientProvider).generateBill(
                          id,
                          taxRate: settings.taxRate,
                        );
                        billData = Bill.fromJson(billJson);
                      } catch (_) {
                        // Bill generation may not be available; print with order data only
                      }

                      await PrinterService().printBill(
                        order: order,
                        printerAddress: printerAddress,
                        port: settings.billPrinterPort,
                        type: settings.billPrinterType,
                        restaurantName: settings.restaurantName,
                        headerInfo: {
                          'address': settings.restaurantAddress,
                          'phone': settings.restaurantPhone,
                          'gstin': settings.gstin,
                          'fssai': settings.fssaiLicense,
                        },
                        bill: billData,
                        taxLabel: settings.taxLabel,
                        footerText: settings.billFooter,
                      );
                      
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bill printed successfully'), backgroundColor: POSTheme.success));
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Print Error: $e'), backgroundColor: POSTheme.danger));
                    }
                  } : () {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please hold or place order first')));
                  },
                  icon: const Icon(Icons.receipt_long_rounded, size: 14),
                  label: const Text('Bill', style: TextStyle(fontSize: 11), maxLines: 1),
                  style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 4)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Send to Kitchen Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: (subtotal > 0 && !ref.watch(posProcessingProvider)) 
                ? () async {
                    ref.read(posProcessingProvider.notifier).state = true;
                    try {
                      await _holdOrder(context, ref, silent: true, bypassProcessingCheck: true);
                      final orderId = ref.read(activeOrderIdProvider);
                      if (orderId != null) {
                        try {
                          await ref.read(apiClientProvider).updateOrderStatus(orderId, 'Preparing');
                          
                          // TRIGGER SILENT KOT PRINT
                          await _printKOTDirect(context, ref, orderId, silent: true);

                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Order sent to kitchen & KOTs printed!'), backgroundColor: POSTheme.success),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: $e'), backgroundColor: POSTheme.danger),
                            );
                          }
                        }
                      }
                    } finally {
                      ref.read(posProcessingProvider.notifier).state = false;
                    }
                  }
                : null,
              icon: const Icon(Icons.restaurant, size: 18),
              label: const Text('SEND TO KITCHEN', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepOrange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(POSTheme.radiusMD)),
                elevation: 4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, double amount, String currency, {bool isNegative = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 13, color: POSTheme.textSecondary)),
          Text('$currency${amount.abs().toStringAsFixed(2)}',
            style: GoogleFonts.inter(
              fontSize: 13, 
              fontWeight: FontWeight.w600, 
              color: isNegative ? POSTheme.success : POSTheme.textPrimary
            )),
        ],
      ),
    );
  }

  void _showDiscountDialog(BuildContext context, WidgetRef ref, double subtotal) {
    bool isPercent = false;
    final controller = TextEditingController();
    final cartItems = ref.read(cartProvider);
    final settings = ref.read(settingsProvider);
    final sym = settings.currencySymbol;
    
    // Calculate discountable vs non-discountable
    double eligibleSubtotal = 0.0;
    double nonEligibleSubtotal = 0.0;
    for (var item in cartItems) {
      if (item.menuItem.allowDiscount) {
        eligibleSubtotal += item.total;
      } else {
        nonEligibleSubtotal += item.total;
      }
    }
    
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          // Live preview calculation
          double inputVal = double.tryParse(controller.text) ?? 0.0;
          double discountAmt = isPercent ? (eligibleSubtotal * (inputVal / 100)) : inputVal;
          discountAmt = discountAmt.clamp(0.0, eligibleSubtotal);
          final finalTotal = (eligibleSubtotal - discountAmt) + nonEligibleSubtotal;
          
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Icon(Icons.local_offer_rounded, color: POSTheme.primary, size: 22),
                const SizedBox(width: 8),
                const Expanded(child: Text('Apply Order Discount', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
              ],
            ),
            content: SizedBox(
              width: 380,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Toggle selector
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setDialogState(() => isPercent = false),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: !isPercent ? POSTheme.primary : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Center(child: Text('$sym Flat', style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: !isPercent ? Colors.white : POSTheme.textSecondary,
                              ))),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setDialogState(() => isPercent = true),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: isPercent ? POSTheme.primary : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Center(child: Text('% Percent', style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: isPercent ? Colors.white : POSTheme.textSecondary,
                              ))),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Input field
                  TextField(
                    controller: controller,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: isPercent ? 'Enter Percentage' : 'Enter Amount',
                      prefixText: isPercent ? null : '$sym ',
                      suffixText: isPercent ? '%' : null,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    autofocus: true,
                    onChanged: (_) => setDialogState(() {}), // Trigger live preview
                  ),
                  const SizedBox(height: 20),
                  
                  // Live breakdown
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F9FA),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Column(
                      children: [
                        _discountRow('Eligible Subtotal', '$sym${eligibleSubtotal.toStringAsFixed(2)}'),
                        if (nonEligibleSubtotal > 0)
                          _discountRow('Non-eligible Items', '$sym${nonEligibleSubtotal.toStringAsFixed(2)}', muted: true),
                        const Divider(height: 16),
                        _discountRow(
                          isPercent ? 'Discount (${inputVal.toStringAsFixed(1)}%)' : 'Discount (Flat)',
                          '- $sym${discountAmt.toStringAsFixed(2)}',
                          color: POSTheme.danger,
                        ),
                        const SizedBox(height: 8),
                        _discountRow('Final Total', '$sym${finalTotal.toStringAsFixed(2)}', bold: true, color: POSTheme.primary),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  ref.read(cartDiscountProvider.notifier).state = 0.0;
                  Navigator.pop(ctx);
                },
                child: const Text('Clear', style: TextStyle(color: POSTheme.danger)),
              ),
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () {
                  final percentage = discountAmt / (eligibleSubtotal > 0 ? eligibleSubtotal : 1);
                  final authUser = ref.read(authProvider);
                  final isManager = authUser != null && ['admin', 'manager', 'super_admin'].contains(authUser.role.toLowerCase());
                  
                  if (percentage > 0.15 && !isManager) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Discount > 15% requires Manager/Admin approval.'),
                      backgroundColor: POSTheme.danger,
                    ));
                    return;
                  }
                  
                  ref.read(cartDiscountProvider.notifier).state = discountAmt;
                  Navigator.pop(ctx);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: POSTheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: const Text('Apply Discount', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _discountRow(String label, String value, {bool bold = false, bool muted = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(
            fontSize: 13,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
            color: muted ? POSTheme.textMuted : (color ?? POSTheme.textPrimary),
          )),
          Text(value, style: TextStyle(
            fontSize: 13,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
            color: color ?? (muted ? POSTheme.textMuted : POSTheme.textPrimary),
          )),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
//  LOGIC & HELPERS
// ══════════════════════════════════════════════════════════════════════

Future<void> _holdOrder(BuildContext context, WidgetRef ref, {bool silent = false, bool bypassProcessingCheck = false}) async {
  final cartItems = ref.read(cartProvider);
  final tableNum = ref.read(tableProvider) ?? 0;
  final activeOrderId = ref.read(activeOrderIdProvider);
  final orderType = ref.read(orderTypeProvider);
  final isProcessing = ref.read(posProcessingProvider);
  
  if (cartItems.isEmpty || (isProcessing && !bypassProcessingCheck)) return;
  
  final phone = ref.read(customerPhoneProvider) ?? '';
  if (phone.isNotEmpty && phone.length < 10) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error: Customer phone must be at least 10 digits'), backgroundColor: POSTheme.danger));
    }
    return;
  }
  
  if (!bypassProcessingCheck) {
    ref.read(posProcessingProvider.notifier).state = true;
  }
  
  try {
    final settings = ref.read(settingsProvider);
    if (activeOrderId != null) {
      final newItems = cartItems.where((i) => !i.isExisting).toList();
      if (newItems.isNotEmpty) {
        await ref.read(apiClientProvider).addItemsToOrder(
          activeOrderId,
          newItems.map((i) => {
            'menu_item_id': i.menuItem.id,
            'quantity': i.quantity,
            'notes': i.notes,
          }).toList(),
        );
      }
      // Update customer info if changed/provided
      final cName = ref.read(customerNameProvider);
      final cPhone = ref.read(customerPhoneProvider);
      final cMobile = ref.read(customerMobileProvider);
      final rNumber = ref.read(roomProvider);
      if (cName != null || cPhone != null || rNumber != null) {
        await ref.read(apiClientProvider).updateOrder(
          activeOrderId,
          customerName: cName,
          customerPhone: cPhone,
          customerMobile: cMobile,
          roomNumber: rNumber,
          orderType: orderType,
          discountAmount: ref.read(cartDiscountProvider),
          taxRate: settings.taxRate,
        );
      }
    } else {
      final order = await ref.read(apiClientProvider).createOrder(
        tableNumber: tableNum,
        roomNumber: ref.read(roomProvider),
        items: cartItems.map((i) => {
          'menu_item_id': i.menuItem.id,
          'quantity': i.quantity,
          'notes': i.notes,
        }).toList(),
        orderType: orderType,
        customerName: ref.read(customerNameProvider),
        customerPhone: ref.read(customerPhoneProvider),
        customerMobile: ref.read(customerMobileProvider),
        discountAmount: ref.read(cartDiscountProvider),
        taxRate: settings.taxRate,
        counterId: settings.counterId,
      );
      ref.read(activeOrderIdProvider.notifier).state = order.id;
      ref.invalidate(ordersProvider);
    }

    // Force backend status to 'held' to update table status
    final finalOrderId = ref.read(activeOrderIdProvider);
    if (finalOrderId != null) {
      await ref.read(apiClientProvider).holdOrder(finalOrderId);
    }

    if (!silent && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order saved to table'), backgroundColor: POSTheme.success),
      );
    }
  } catch (e) {
    if (!silent && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: POSTheme.danger),
      );
    }
  } finally {
    if (!bypassProcessingCheck) {
      ref.read(posProcessingProvider.notifier).state = false;
    }
  }
}

void _showSplitBillDialog(BuildContext context, WidgetRef ref, double total) {
  final splitEntries = <Map<String, dynamic>>[
    {'method': 'cash', 'amount': total, 'controller': TextEditingController(text: total.toStringAsFixed(2))}
  ];

  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) {
        double currentTotal = 0;
        for (var e in splitEntries) {
          currentTotal += double.tryParse(e['controller'].text) ?? 0;
        }
        final remaining = (total - currentTotal);

        return AlertDialog(
          title: const Text('Split Payment Reconciliation'),
          content: SizedBox(
            width: 450,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: POSTheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Bill Total: ₹${total.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text('Remaining: ₹${remaining.toStringAsFixed(2)}', 
                        style: TextStyle(color: remaining > 0 ? POSTheme.danger : POSTheme.success, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                   children: [
                     _quickSplitButton('Split by 2', 2, total, splitEntries, setDialogState),
                     const SizedBox(width: 8),
                     _quickSplitButton('Split by 3', 3, total, splitEntries, setDialogState),
                     const SizedBox(width: 8),
                     _quickSplitButton('Split by 4', 4, total, splitEntries, setDialogState),
                   ],
                ),
                const Divider(height: 32),
                SizedBox(
                  height: 250,
                  child: ListView.builder(
                    itemCount: splitEntries.length,
                    itemBuilder: (lCtx, index) {
                      final entry = splitEntries[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: DropdownButtonFormField<String>(
                                value: entry['method'],
                                decoration: const InputDecoration(labelText: 'Method', border: OutlineInputBorder()),
                                items: ['cash', 'card', 'upi'].map((m) => DropdownMenuItem(value: m, child: Text(m.toUpperCase()))).toList(),
                                onChanged: (val) => setDialogState(() => entry['method'] = val),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 3,
                              child: TextField(
                                controller: entry['controller'],
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(labelText: 'Amount ₹', border: OutlineInputBorder()),
                                onChanged: (val) => setDialogState(() {}),
                              ),
                            ),
                            IconButton(
                              onPressed: splitEntries.length > 1 ? () => setDialogState(() {
                                entry['controller'].dispose();
                                splitEntries.removeAt(index);
                              }) : null,
                              icon: const Icon(Icons.remove_circle_outline, color: POSTheme.danger),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                TextButton.icon(
                  onPressed: () => setDialogState(() => splitEntries.add({
                    'method': 'cash', 
                    'amount': remaining, 
                    'controller': TextEditingController(text: remaining.toStringAsFixed(2))
                  })),
                  icon: const Icon(Icons.add_circle_outline),
                  label: const Text('Add Payment Method'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: remaining.abs() < 0.05 ? () => _processSplitPayments(ctx, ref, splitEntries) : null,
              style: ElevatedButton.styleFrom(backgroundColor: POSTheme.primary, foregroundColor: Colors.white),
              child: const Text('Confirm & Pay'),
            ),
          ],
        );
      },
    ),
  );
}

Widget _quickSplitButton(String label, int count, double total, List<Map<String, dynamic>> entries, StateSetter setDialogState) {
  return Expanded(
    child: ElevatedButton(
      onPressed: () => setDialogState(() {
        for (var e in entries) { e['controller'].dispose(); }
        entries.clear();
        final splitAmt = (total / count).toStringAsFixed(2);
        final lastAmt = (total - (double.parse(splitAmt) * (count - 1))).toStringAsFixed(2);
        
        for (int i = 0; i < count; i++) {
          final amt = (i == count - 1) ? lastAmt : splitAmt;
          entries.add({'method': 'cash', 'amount': double.parse(amt), 'controller': TextEditingController(text: amt)});
        }
      }),
      style: ElevatedButton.styleFrom(
        padding: EdgeInsets.zero,
        backgroundColor: POSTheme.primary.withOpacity(0.1),
        foregroundColor: POSTheme.primary,
        elevation: 0,
      ),
      child: Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
    ),
  );
}

Future<void> _processSplitPayments(BuildContext context, WidgetRef ref, List<Map<String, dynamic>> splitEntries) async {
  if (ref.read(posProcessingProvider)) return;
  
  final phone = ref.read(customerPhoneProvider) ?? '';
  if (phone.isNotEmpty && phone.length < 10) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error: Customer phone must be at least 10 digits'), backgroundColor: POSTheme.danger));
    return;
  }
  
  ref.read(posProcessingProvider.notifier).state = true;

  Navigator.pop(context);
  
  final cartItems = ref.read(cartProvider);
  final tableNum = ref.read(tableProvider) ?? 0;
  final activeOrderId = ref.read(activeOrderIdProvider);
  final orderType = ref.read(orderTypeProvider);
  
  try {
    int orderId;
    if (activeOrderId != null) {
      orderId = activeOrderId;
      final newItems = cartItems.where((i) => !i.isExisting).toList();
      if (newItems.isNotEmpty) {
        await ref.read(apiClientProvider).addItemsToOrder(orderId, 
          newItems.map((i) => {'menu_item_id': i.menuItem.id, 'quantity': i.quantity, 'notes': i.notes}).toList());
      }
      // CRITICAL: Sync latest financial data before payment
      await ref.read(apiClientProvider).updateOrder(
        orderId,
        customerName: ref.read(customerNameProvider),
        customerPhone: ref.read(customerPhoneProvider),
        customerMobile: ref.read(customerMobileProvider),
        roomNumber: ref.read(roomProvider),
        orderType: orderType,
        discountAmount: ref.read(cartDiscountProvider),
        taxRate: ref.read(settingsProvider).taxRate,
      );
    } else {
      final order = await ref.read(apiClientProvider).createOrder(
        tableNumber: tableNum,
        roomNumber: ref.read(roomProvider),
        items: cartItems.map((i) => {'menu_item_id': i.menuItem.id, 'quantity': i.quantity, 'notes': i.notes}).toList(),
        orderType: orderType,
        customerName: ref.read(customerNameProvider),
        customerPhone: ref.read(customerPhoneProvider),
        customerMobile: ref.read(customerMobileProvider),
        discountAmount: ref.read(cartDiscountProvider),
        taxRate: ref.read(settingsProvider).taxRate,
      );
      orderId = order.id;
    }

    // Record each split payment
    for (final entry in splitEntries) {
      final amt = double.tryParse(entry['controller'].text) ?? 0;
      if (amt > 0) {
        await ref.read(apiClientProvider).recordPayment(orderId, amt, entry['method']);
      }
    }

    // Cleanup split controllers
    for (final entry in splitEntries) {
      entry['controller'].dispose();
    }

    // NEW: Check if order is fully paid before clearing
    final balanceInfo = await ref.read(apiClientProvider).getPaymentBalance(orderId);
    
    if (balanceInfo['is_fully_paid'] == true) {


      ref.read(cartProvider.notifier).clearCart();
      ref.read(tableProvider.notifier).state = null;
      ref.read(roomProvider.notifier).state = null;
      ref.read(activeOrderIdProvider.notifier).state = null;
      ref.read(customerNameProvider.notifier).state = null;
      ref.read(customerPhoneProvider.notifier).state = null;
      ref.read(customerMobileProvider.notifier).state = null;
      ref.read(cartDiscountProvider.notifier).state = 0.0;
      ref.read(orderTypeProvider.notifier).state = 'dine_in';
    } else {
      // Partial payment: Keep order active, but clear the cart and reload from server
      // to ensure we only have existing items left
      ref.read(refreshedTablesProvider.notifier).state = DateTime.now(); // Trigger underlying refresh
    }

    if (context.mounted) {
      final typeLabel = {'dine_in': 'Dine-in', 'takeaway': 'Takeaway', 'delivery': 'Delivery'}[orderType] ?? orderType;
      final methodsStr = splitEntries.map((e) => e['method']).toSet().join('+');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text('$typeLabel order placed • Table $tableNum • Split: $methodsStr'),
            ],
          ),
          backgroundColor: POSTheme.success,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: POSTheme.danger));
    }
  } finally {
    ref.read(posProcessingProvider.notifier).state = false;
  }
}

Future<void> _printKOTDirect(BuildContext context, WidgetRef ref, int? orderId, {bool silent = false}) async {
  int? finalOrderId = orderId;
  if (finalOrderId == null) {
    await _holdOrder(context, ref, silent: true);
    finalOrderId = ref.read(activeOrderIdProvider);
  }
  
  if (finalOrderId == null) return;

  try {
    // 1. Get all necessary data
    final counters = ref.read(kitchenCountersProvider).value ?? [];
    final itemsAsync = ref.read(menuItemsProvider).value ?? [];
    final categories = ref.read(menuCategoriesProvider).value ?? [];
    
    // Find the order
    final orders = ref.read(ordersProvider).value ?? [];
    final heldOrders = ref.read(heldOrdersProvider).value ?? [];
    final cartItems = ref.read(cartProvider);

    Order? targetOrder;
    try {
      targetOrder = orders.firstWhere((o) => o.id == finalOrderId);
    } catch (_) {
      try {
        targetOrder = heldOrders.firstWhere((o) => o.id == finalOrderId);
      } catch (_) {}
    }

    if (targetOrder == null) throw Exception('Order #$finalOrderId not found in local sync.');

    // 2. Identify items to print (new ones if in cart, or all if reprinting)
    List<OrderItem> itemsToPrint = [];
    bool isNewVersion = false;
    if (cartItems.isNotEmpty) {
      isNewVersion = true;
      // Print cart items (new items being added)
      for (var ci in cartItems) {
        int? counterId = ci.menuItem.kitchenCounterId;
        if (counterId == null) {
          try {
            final cat = categories.firstWhere((c) => c.id == ci.menuItem.categoryId);
            counterId = cat.kitchenCounterId;
          } catch (_) {}
        }

        itemsToPrint.add(OrderItem(
          menuItemId: ci.menuItem.id, 
          name: ci.menuItem.name, 
          quantity: ci.quantity, 
          price: ci.menuItem.price,
          notes: ci.notes,
          kitchenCounterId: counterId,
          modifiers: ci.modifiers,
          allowDiscount: ci.menuItem.allowDiscount,
          taxEnabled: ci.menuItem.taxEnabled,
          taxPercentage: ci.menuItem.taxPercentage,
        ));
      }
    } else {
      itemsToPrint = targetOrder.items;
    }

    // 3. Determine KOT version from existing order items
    int kotVersion = 1;
    String? kotAction;
    if (isNewVersion && targetOrder.items.isNotEmpty) {
      // This is an update to an existing order
      kotVersion = (targetOrder.items.map((i) => i.kotVersion).reduce((a, b) => a > b ? a : b)) + 1;
      kotAction = 'modified';
    }

    // 4. Delegate to PrinterService
    if (!silent) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Processing thermal KOTs...'), duration: Duration(milliseconds: 500)));
    }

    await PrinterService().printKOT(
      order: targetOrder,
      items: itemsToPrint,
      counters: counters,
      kotVersion: kotVersion,
      kotAction: kotAction,
    );

    if (!silent && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('KOTs printed successfully'), backgroundColor: POSTheme.success));
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('KOT Print Error: $e\nHint: Check printer IP or try re-logging.'),
        backgroundColor: POSTheme.danger,
        duration: const Duration(seconds: 5),
      ));
    }
  }
}

void _showKOTDialog(BuildContext context, WidgetRef ref, int? orderId) async {
  int? finalOrderId = orderId;
  if (finalOrderId == null) {
    await _holdOrder(context, ref, silent: true);
    finalOrderId = ref.read(activeOrderIdProvider);
  }
  
  if (finalOrderId == null || !context.mounted) return;

  showDialog(
    context: context,
    builder: (ctx) => Consumer(
      builder: (context, ref, _) {
        final countersAsync = ref.watch(kitchenCountersProvider);
        final categoriesAsync = ref.watch(menuCategoriesProvider);
        final itemsAsync = ref.watch(menuItemsProvider);
        final ordersAsync = ref.watch(ordersProvider);
        final heldOrdersAsync = ref.watch(heldOrdersProvider);
        final cartItems = ref.watch(cartProvider);
        
        // Wait for all essential data to load
        if (countersAsync.isLoading || categoriesAsync.isLoading || itemsAsync.isLoading || ordersAsync.isLoading || heldOrdersAsync.isLoading) {
          return AlertDialog(
            content: Container(
              height: 150,
              alignment: Alignment.center,
              child: const CircularProgressIndicator(),
            ),
          );
        }

        final allCounters = countersAsync.value ?? [];
        final allCats = categoriesAsync.value ?? [];
        final allItems = itemsAsync.value ?? [];
        final allActiveOrders = ordersAsync.value ?? [];
        final allHeldOrders = heldOrdersAsync.value ?? [];
        
        final stationsInOrder = <int>{};
        
        if (cartItems.isNotEmpty) {
          for (var item in cartItems) {
            int? counterId = item.menuItem.kitchenCounterId;
            if (counterId == null) {
              try {
                final parentCat = allCats.firstWhere((c) => c.id == item.menuItem.categoryId);
                counterId = parentCat.kitchenCounterId;
              } catch (_) {}
            }
            if (counterId != null) stationsInOrder.add(counterId);
          }
        } else {
          // Look for the order in either active or held lists
          final targetOrder = (allActiveOrders.any((o) => o.id == finalOrderId))
              ? allActiveOrders.firstWhere((o) => o.id == finalOrderId)
              : (allHeldOrders.any((o) => o.id == finalOrderId))
                  ? allHeldOrders.firstWhere((o) => o.id == finalOrderId)
                  : null;

          if (targetOrder != null) {
            for (var orderItem in targetOrder.items) {
              try {
                final menuItem = allItems.firstWhere((m) => m.id == orderItem.menuItemId);
                int? counterId = menuItem.kitchenCounterId;
                if (counterId == null) {
                  final parentCat = allCats.firstWhere((c) => c.id == menuItem.categoryId);
                  counterId = parentCat.kitchenCounterId;
                }
                if (counterId != null) stationsInOrder.add(counterId);
              } catch (_) {}
            }
          }
        }

        final relevantStations = allCounters.where((s) => stationsInOrder.contains(s.id)).toList();
        final otherStations = allCounters.where((s) => !stationsInOrder.contains(s.id)).toList();

        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.restaurant_menu_rounded, color: POSTheme.primary),
              SizedBox(width: 10),
              Text('Print KOT'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Choose printing mode:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(Icons.print_rounded, color: POSTheme.primary),
                  title: const Text('All Items (Combined)', style: TextStyle(fontWeight: FontWeight.bold)),
                  tileColor: POSTheme.primary.withOpacity(0.05),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final url = ref.read(apiClientProvider).getKotPrintUrl(finalOrderId!, mode: 'all');
                    if (await canLaunchUrl(Uri.parse(url))) {
                      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                    }
                  },
                ),
                const SizedBox(height: 8),
                ListTile(
                  leading: const Icon(Icons.call_split_rounded, color: Colors.deepOrange),
                  title: const Text('Separate by Counter'),
                  subtitle: const Text('Prints 1 ticket per counter', style: TextStyle(fontSize: 11)),
                  tileColor: Colors.deepOrange.withOpacity(0.05),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final url = ref.read(apiClientProvider).getKotPrintUrl(finalOrderId!, mode: 'separate');
                    if (await canLaunchUrl(Uri.parse(url))) {
                      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                    }
                  },
                ),
                const Divider(height: 32),
                const Text('Or print for a specific counter:', style: TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                
                // Show relevant stations first
                ...relevantStations.map((s) => ListTile(
                  leading: const Icon(Icons.countertops_rounded, color: POSTheme.primary),
                  title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(4)),
                    child: const Text('In Order', style: TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.bold)),
                  ),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final url = ref.read(apiClientProvider).getKotPrintUrl(finalOrderId!, mode: 'specific', targetCounterId: s.id);
                    if (await canLaunchUrl(Uri.parse(url))) {
                      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                    }
                  },
                )),
                
                // Show other stations
                ...otherStations.map((s) => ListTile(
                  leading: const Icon(Icons.countertops_outlined, color: Colors.grey),
                  title: Text(s.name, style: const TextStyle(color: Colors.grey)),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final url = ref.read(apiClientProvider).getKotPrintUrl(finalOrderId!, mode: 'specific', targetCounterId: s.id);
                    if (await canLaunchUrl(Uri.parse(url))) {
                      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                    }
                  },
                )),
                
                if (allCounters.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text('No counters configured. Go to Settings > Kitchen Counters.', style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12)),
                  ),
              ],
            ),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel'))],
        );
      },
    ),
  );
}

class _PaymentMethodButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final int paymentMethod;
  final double total;
  final VoidCallback onPay;

  const _PaymentMethodButton({
    required this.icon,
    required this.label,
    required this.paymentMethod,
    required this.total,
    required this.onPay,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton.icon(
        onPressed: onPay,
        icon: Icon(icon, size: 20),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: POSTheme.border),
          foregroundColor: POSTheme.textPrimary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(POSTheme.radiusMD)),
        ),
      ),
    );
  }
}

void _showSuccessSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context).clearSnackBars();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      duration: const Duration(milliseconds: 800),
      behavior: SnackBarBehavior.floating,
      width: 240,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      backgroundColor: POSTheme.primary,
    ),
  );
}

void _showModifiersDialog(BuildContext context, WidgetRef ref, MenuItem item, List<MenuItemModifier> rawMods) {
  final List<CartItemModifier> selectedMods = [];
  showDialog(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) {
        final groups = <String, List<MenuItemModifier>>{};
        for (final m in rawMods) {
          final g = m.modifierGroup;
          groups.putIfAbsent(g, () => []).add(m);
        }
        return Dialog(
          backgroundColor: const Color(0xFFFCEFE9),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Container(
            width: 500,
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Customize ${item.name}', 
                  style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.bold, color: const Color(0xFF1E1E2D))
                ),
                const SizedBox(height: 24),
                
                // Content area
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Combo Components Section
                        if (item.comboItems.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.all(16),
                            margin: const EdgeInsets.only(bottom: 24),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.deepOrange.withOpacity(0.2)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.auto_awesome_motion_rounded, size: 16, color: Colors.deepOrange),
                                    const SizedBox(width: 8),
                                    Text('COMBO COMPONENTS', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.deepOrange)),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                ...item.comboItems.map((c) => Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.check_circle_outline, size: 14, color: Colors.green),
                                      const SizedBox(width: 8),
                                      Text('${c.quantity}x ${c.name ?? 'Item ${c.componentItemId}'}', 
                                        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500)),
                                    ],
                                  ),
                                )),
                              ],
                            ),
                          ),
                        ],

                        // Modifiers Section
                        ...groups.entries.map((group) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                child: Text(group.key.toUpperCase(), style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: POSTheme.textMuted)),
                              ),
                              ...group.value.map((m) {
                                final mod = CartItemModifier(name: m.name, priceDelta: m.priceDelta);
                                final isSelected = selectedMods.any((sm) => sm.name == mod.name);
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  decoration: BoxDecoration(
                                    color: isSelected ? Colors.deepOrange.withOpacity(0.05) : Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: isSelected ? Colors.deepOrange.withOpacity(0.3) : Colors.transparent),
                                  ),
                                  child: CheckboxListTile(
                                    title: Text(mod.name, style: GoogleFonts.inter(fontSize: 14, fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400)),
                                    secondary: Text('+₹${mod.priceDelta.toStringAsFixed(0)}', style: GoogleFonts.inter(color: Colors.deepOrange, fontWeight: FontWeight.bold)),
                                    value: isSelected,
                                    activeColor: Colors.deepOrange,
                                    onChanged: (val) {
                                      setDialogState(() {
                                        if (val == true) selectedMods.add(mod);
                                        else selectedMods.removeWhere((sm) => sm.name == mod.name);
                                      });
                                    },
                                    dense: true,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    controlAffinity: ListTileControlAffinity.leading,
                                  ),
                                );
                              }),
                              const SizedBox(height: 16),
                            ],
                          );
                        }),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 32),
                
                // Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel', style: TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepOrange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      onPressed: () {
                        ref.read(cartProvider.notifier).addItem(item, modifiers: selectedMods);
                        Navigator.pop(context);
                        _showSuccessSnackBar(context, '${item.name} added to cart');
                      },
                      child: const Text('Add to Cart', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

class _EmptyCartPainter extends CustomPainter {
  final Color color;
  _EmptyCartPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2 // Ultra-sharp thin line matching the image
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    double centerX = size.width / 2;
    double centerY = size.height / 2;
    double plateRadius = size.height * 0.45;

    // 1. Draw Plate (Exact 1:1 Dual Rim)
    canvas.drawCircle(Offset(centerX, centerY), plateRadius, paint);
    canvas.drawCircle(Offset(centerX, centerY), plateRadius * 0.82, paint);

    // 2. Draw Fork (Left - Exact 1:1 Match: 3 Tines)
    double forkX = centerX - plateRadius - 35;
    double forkWidth = 14;
    double tinesHeight = 18;
    Path forkPath = Path();
    // 3 tines
    for (int i = 0; i < 3; i++) {
        double ox = forkX - (forkWidth/2) + (i * (forkWidth/2));
        forkPath.moveTo(ox, centerY - 25);
        forkPath.lineTo(ox, centerY - (25 - tinesHeight));
    }
    // Fork base (Rectangular)
    forkPath.moveTo(forkX - (forkWidth/2), centerY - (25 - tinesHeight));
    forkPath.lineTo(forkX - (forkWidth/2), centerY);
    forkPath.lineTo(forkX + (forkWidth/2), centerY);
    forkPath.lineTo(forkX + (forkWidth/2), centerY - (25 - tinesHeight));
    // Fork Handle
    forkPath.moveTo(forkX, centerY);
    forkPath.lineTo(forkX, centerY + 30);
    canvas.drawPath(forkPath, paint);

    // 3. Draw Knife (Right - Exact 1:1 Match)
    double knifeX = centerX + plateRadius + 35;
    double knifeWidth = 12;
    Path knifePath = Path();
    // Blade (Curved top corner)
    knifePath.moveTo(knifeX - (knifeWidth/2), centerY + 5);
    knifePath.lineTo(knifeX - (knifeWidth/2), centerY - 25);
    knifePath.lineTo(knifeX + (knifeWidth/4), centerY - 25);
    knifePath.quadraticBezierTo(knifeX + (knifeWidth/2), centerY - 25, knifeX + (knifeWidth/2), centerY - 18);
    knifePath.lineTo(knifeX + (knifeWidth/2), centerY + 5);
    knifePath.close();
    // Handle
    knifePath.moveTo(knifeX, centerY + 5);
    knifePath.lineTo(knifeX, centerY + 30);
    canvas.drawPath(knifePath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CartItemTile extends ConsumerWidget {
  final CartItem cartItem;
  const _CartItemTile({required this.cartItem});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final user = ref.watch(authProvider);
    final isManager = ['admin', 'manager', 'super_admin'].contains(user?.role.toLowerCase());
    final modKey = cartItem.modifiers.map((m) => m.name).join('|');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(cartItem.menuItem.name, maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13, color: POSTheme.textPrimary)),
                    if (cartItem.modifiers.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(cartItem.modifiers.map((m) => m.name).join(', '),
                          style: GoogleFonts.inter(fontSize: 10, color: POSTheme.primary, fontWeight: FontWeight.w500)),
                      ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _qtyButton(Icons.remove, cartItem.isSentToKitchen ? null : () => ref.read(cartProvider.notifier).updateQuantity(cartItem.menuItem.id, cartItem.quantity - 1, modKey: modKey)),
                  SizedBox(width: 30, child: Center(child: Text('${cartItem.quantity}', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13)))),
                  _qtyButton(Icons.add, () => ref.read(cartProvider.notifier).updateQuantity(cartItem.menuItem.id, cartItem.quantity + 1, modKey: modKey)),
                ],
              ),
              const SizedBox(width: 8),
              // PRICE AREA — Tap to Override (Manager only)
              InkWell(
                onTap: () {
                  if (!isManager) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Manager/Admin permission required to edit price')),
                    );
                    return;
                  }
                  _showPriceEditDialog(context, ref, cartItem);
                },
                borderRadius: BorderRadius.circular(4),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: cartItem.priceOverride != null ? POSTheme.warning.withOpacity(0.1) : Colors.transparent,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: cartItem.priceOverride != null ? POSTheme.warning : Colors.transparent),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('${settings.currencySymbol}${cartItem.total.toStringAsFixed(2)}',
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: POSTheme.primary)),
                      if (cartItem.priceOverride != null)
                        Text('was ${settings.currencySymbol}${cartItem.menuItem.price.toStringAsFixed(0)}',
                          style: GoogleFonts.inter(fontSize: 9, color: POSTheme.textMuted, decoration: TextDecoration.lineThrough)),
                      if (cartItem.discountAmount > 0)
                        Text('-${settings.currencySymbol}${cartItem.discountAmount.toStringAsFixed(0)}',
                          style: GoogleFonts.inter(fontSize: 9, color: POSTheme.success, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (cartItem.notes != null && cartItem.notes!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('Note: ${cartItem.notes}', style: GoogleFonts.inter(fontSize: 10, fontStyle: FontStyle.italic, color: POSTheme.textMuted)),
            ),
        ],
      ),
    );
  }

  void _showPriceEditDialog(BuildContext context, WidgetRef ref, CartItem item) {
    final controller = TextEditingController(text: (item.priceOverride ?? item.menuItem.price).toStringAsFixed(0));
    final modKey = item.modifiers.map((m) => m.name).join('|');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Override Price: ${item.menuItem.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Original Price: ₹${item.menuItem.price.toStringAsFixed(2)}', style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'New Unit Price',
                prefixText: '₹ ',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL')),
          if (item.priceOverride != null)
            TextButton(
              onPressed: () {
                ref.read(cartProvider.notifier).updateItemPrice(item.menuItem.id, item.menuItem.price, modKey: modKey);
                Navigator.pop(ctx);
              },
              child: const Text('RESET', style: TextStyle(color: POSTheme.danger)),
            ),
          ElevatedButton(
            onPressed: () {
              final newPrice = double.tryParse(controller.text);
              if (newPrice != null && newPrice >= 0) {
                ref.read(cartProvider.notifier).updateItemPrice(item.menuItem.id, newPrice, modKey: modKey);
                Navigator.pop(ctx);
              }
            },
            child: const Text('SAVE'),
          ),
        ],
      ),
    );
  }

  void _showItemDiscountDialog(BuildContext context, WidgetRef ref, CartItem item) {
    final controller = TextEditingController(text: item.discountAmount > 0 ? item.discountAmount.toStringAsFixed(0) : '');
    bool isPercent = false;
    final basePrice = item.baseUnitPrice * item.quantity;
    final modKey = item.modifiers.map((m) => m.name).join('|');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text('Discount: ${item.menuItem.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(child: _itemDiscountToggle('Flat ₹', !isPercent, () => setState(() => isPercent = false))),
                  const SizedBox(width: 8),
                  Expanded(child: _itemDiscountToggle('Percent %', isPercent, () => setState(() => isPercent = true))),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: isPercent ? 'Percentage %' : 'Amount ₹',
                  prefixIcon: Icon(isPercent ? Icons.percent : Icons.currency_rupee, size: 18),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                ref.read(cartProvider.notifier).updateItemDiscount(item.menuItem.id, 0.0, modKey: modKey);
                Navigator.pop(ctx);
              },
              child: const Text('Clear'),
            ),
            ElevatedButton(
              onPressed: () {
                final val = double.tryParse(controller.text) ?? 0.0;
                double finalDiscount = isPercent ? (basePrice * (val / 100)) : val;
                ref.read(cartProvider.notifier).updateItemDiscount(item.menuItem.id, finalDiscount.clamp(0.0, basePrice), modKey: modKey);
                Navigator.pop(ctx);
              },
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _itemDiscountToggle(String label, bool isActive, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? POSTheme.primary.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: isActive ? POSTheme.primary : POSTheme.border),
        ),
        child: Center(child: Text(label, style: TextStyle(fontSize: 12, fontWeight: isActive ? FontWeight.bold : FontWeight.normal, color: isActive ? POSTheme.primary : POSTheme.textSecondary))),
      ),
    );
  }

  Widget _qtyButton(IconData icon, VoidCallback? onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(border: Border.all(color: POSTheme.border), borderRadius: BorderRadius.circular(4)),
        child: Icon(icon, size: 14, color: onTap != null ? POSTheme.primary : Colors.grey),
      ),
    );
  }
}