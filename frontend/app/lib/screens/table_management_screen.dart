import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../core/pos_theme.dart';
import '../models/order_model.dart';
import '../providers.dart';

/// Dedicated Table Management screen with visual floor plan,
/// merge/transfer context menus, and real-time table status.
class TableManagementScreen extends ConsumerStatefulWidget {
  const TableManagementScreen({super.key});

  @override
  ConsumerState<TableManagementScreen> createState() => _TableManagementScreenState();
}

class _TableManagementScreenState extends ConsumerState<TableManagementScreen> {
  bool _isLoading = false;
  List<Order> _activeOrders = [];
  int? _selectedMergeSource;

  @override
  void initState() {
    super.initState();
    _refreshTables();
  }

  Future<void> _refreshTables() async {
    setState(() => _isLoading = true);
    try {
      // Refresh real-time table statuses mapping
      await ref.read(tableStatusesProvider.notifier).syncWithBackend();
      
      final orders = await ref.read(apiClientProvider).getOrders();
      if (!mounted) return;
      _activeOrders = orders
          .where((o) => ['pending', 'preparing', 'ready'].contains(o.status))
          .toList();
    } catch (e) {
      debugPrint('Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Order? _orderForTable(int tableNum) {
    final matches = _activeOrders.where((o) => o.tableNumber == tableNum);
    return matches.isNotEmpty ? matches.first : null;
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final occupied = ref.watch(occupiedTablesProvider);
    final totalTables = settings.totalTables;
    final availableCount = totalTables - occupied.length;

    return Scaffold(
      backgroundColor: POSTheme.surface,
      body: Column(
        children: [
          // ─── Header ──────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
            decoration: BoxDecoration(
              color: POSTheme.cardColor,
              boxShadow: POSTheme.shadowSM,
            ),
            child: Row(
              children: [
                Text('Table Management',
                  style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w800)),
                const Spacer(),

                // Stats
                _statChip(Icons.check_circle_outline, '$availableCount Available', POSTheme.success),
                const SizedBox(width: 12),
                _statChip(Icons.restaurant_rounded, '${occupied.length} Occupied', POSTheme.warning),
                const SizedBox(width: 24),

                if (_selectedMergeSource != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: POSTheme.info.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(POSTheme.radiusSM),
                      border: Border.all(color: POSTheme.info.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.merge_type, size: 16, color: POSTheme.info),
                        const SizedBox(width: 6),
                        Text('Select target to merge Table $_selectedMergeSource',
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: POSTheme.info)),
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: () => setState(() => _selectedMergeSource = null),
                          child: const Icon(Icons.close, size: 16, color: POSTheme.info),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),
                ],

                IconButton(
                  onPressed: _isLoading ? null : _refreshTables,
                  icon: _isLoading
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.refresh_rounded),
                  tooltip: 'Refresh',
                ),
              ],
            ),
          ),

          // ─── Floor Plan Grid ─────────────────────────────────
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  childAspectRatio: 1.1,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: totalTables,
                itemBuilder: (context, index) {
                  final tableNum = index + 1;
                  final order = _orderForTable(tableNum);
                  return _buildTableCard(tableNum, order);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableCard(int tableNum, Order? order) {
    final isOccupied = order != null;
    final isBilling = order?.status == 'ready';
    final Color statusColor = isBilling
        ? POSTheme.tableBilling
        : isOccupied
            ? POSTheme.tableOccupied
            : POSTheme.tableEmpty;
    final isMergeTarget = _selectedMergeSource != null && _selectedMergeSource != tableNum && isOccupied;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          if (_selectedMergeSource != null && isMergeTarget) {
            _performMerge(tableNum, order);
            return;
          }
          if (isOccupied) {
            _showTableDetails(tableNum, order);
          }
        },
        onSecondaryTap: () {
          Future.microtask(() {
            if (mounted) _showContextMenu(context, tableNum, order);
          });
        },
        onLongPress: () {
          Future.microtask(() {
            if (mounted) _showContextMenu(context, tableNum, order);
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: isMergeTarget
                ? POSTheme.info.withOpacity(0.08)
                : POSTheme.cardColor,
            borderRadius: BorderRadius.circular(POSTheme.radiusLG),
            border: Border.all(
              color: isMergeTarget ? POSTheme.info : statusColor.withOpacity(0.4),
              width: isMergeTarget ? 2.5 : 2,
            ),
            boxShadow: POSTheme.shadowSM,
          ),
          child: Stack(
            children: [
              // QR Shortcut (New Direct Access)
              Positioned(
                top: 8,
                left: 8,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => _showQRDialog(tableNum),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: POSTheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.qr_code_rounded,
                        size: 20,
                        color: POSTheme.primary,
                      ),
                    ),
                  ),
                ),
              ),
  
              // Status indicator
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: statusColor.withOpacity(0.4), blurRadius: 4),
                    ],
                  ),
                ),
              ),
  
              // Content
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        isOccupied ? Icons.restaurant_rounded : Icons.table_restaurant_rounded,
                        color: statusColor,
                        size: 24,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('Table $tableNum',
                      style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    if (isOccupied) ...[
                      Text('₹${order.totalAmount.toStringAsFixed(0)}',
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: POSTheme.primary)),
                      const SizedBox(height: 2),
                      POSTheme.statusBadge(
                        isBilling ? 'Ready' : order.status.toUpperCase(),
                        statusColor,
                      ),
                    ] else
                      Text('Available',
                        style: GoogleFonts.inter(fontSize: 12, color: POSTheme.success, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
  
              // Merge indicator
              if (isMergeTarget)
                Positioned(
                  bottom: 8,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Text('Tap to merge here',
                      style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: POSTheme.info)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showContextMenu(BuildContext context, int tableNum, Order? order) {
    final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    final isOccupied = order != null;

    showMenu<String>(
      context: context,
      position: RelativeRect.fromSize(
        Rect.fromCenter(center: overlay.size.center(Offset.zero), width: 0, height: 0),
        overlay.size,
      ),
      items: [
        if (isOccupied) ...[
          PopupMenuItem(
            value: 'details',
            child: _menuItem(Icons.info_outline, 'View Details'),
          ),
          PopupMenuItem(
            value: 'transfer',
            child: _menuItem(Icons.swap_horiz_rounded, 'Transfer Table'),
          ),
          PopupMenuItem(
            value: 'merge',
            child: _menuItem(Icons.merge_type_rounded, 'Merge Tables'),
          ),
          const PopupMenuDivider(),
          PopupMenuItem(
            value: 'clear',
            child: _menuItem(Icons.delete_outline, 'Clear Table', color: POSTheme.danger),
          ),
          const PopupMenuDivider(),
        ],
        PopupMenuItem(
          value: 'qr',
          child: _menuItem(Icons.qr_code_2_rounded, 'Guest QR', color: POSTheme.primary),
        ),
      ],
    ).then((value) {
      if (value == null) return;
      if (!isOccupied && value != 'qr') return;
      
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
        case 'qr':
          _showQRDialog(tableNum);
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
                          _refreshTables();
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
    final sourceOrder = _orderForTable(_selectedMergeSource!);
    if (sourceOrder == null) return;

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
      _refreshTables();
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
      _refreshTables();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Table $tableNum cleared'), backgroundColor: POSTheme.success),
        );
      }
    }
  }

  Widget _statChip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(POSTheme.radiusFull),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(text, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }

  void _showQRDialog(int tableNum) async {
    final settings = ref.read(settingsProvider);
    String baseUrl = settings.apiBaseUrl;
    
    // On web, use the current browser's address for the QR code
    if (kIsWeb) {
      final uri = Uri.base;
      baseUrl = "${uri.scheme}://${uri.host}${uri.port == 80 || uri.port == 443 ? '' : ':${uri.port}'}";
    } else {
      // For Windows Terminal: Ensure we don't use localhost for QR codes
      if (baseUrl.contains('localhost') || baseUrl.contains('127.0.0.1') || baseUrl.contains('0.0.0.0')) {
        try {
          final interfaces = await NetworkInterface.list(
            type: InternetAddressType.IPv4,
            includeLoopback: false,
          );
          
          String? foundIP;
          for (var interface in interfaces) {
            for (var addr in interface.addresses) {
              if (addr.address.startsWith('192.168.') || 
                  addr.address.startsWith('10.') || 
                  addr.address.startsWith('172.16.') ||
                  addr.address.startsWith('172.31.')) {
                foundIP = addr.address;
                break;
              }
            }
            if (foundIP != null) break;
          }

          if (foundIP != null) {
            // Strip any existing port and use 8000 for the Guest Menu
            baseUrl = "http://$foundIP:8000";
          }
        } catch (e) {
          debugPrint('IP detection error: $e');
        }
      }
    }

    final qrUrl = "$baseUrl/#/guest-order?table=$tableNum";

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        contentPadding: const EdgeInsets.all(24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(POSTheme.radiusLG)),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Guest Digital Menu', 
                style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text('Table $tableNum', 
                style: GoogleFonts.inter(fontSize: 14, color: POSTheme.textSecondary, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              
              if (baseUrl.contains('127.0.0.1') || baseUrl.contains('localhost'))
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: POSTheme.warning.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: POSTheme.warning.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, size: 20, color: POSTheme.warning),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Warning: Using localhost. Set your PC IP in Settings for guests to connect.',
                          style: GoogleFonts.inter(fontSize: 11, color: POSTheme.warning, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 250,
                  height: 250,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(POSTheme.radiusMD),
                    border: Border.all(color: POSTheme.border),
                    boxShadow: POSTheme.shadowSM,
                  ),
                  child: QrImageView(
                    data: qrUrl,
                    version: QrVersions.auto,
                    size: 200.0,
                    gapless: false,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text('Scan to view menu & order', 
                style: GoogleFonts.inter(fontSize: 12, color: POSTheme.textMuted)),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Share.share('Order from Table $tableNum: $qrUrl');
                      },
                      icon: const Icon(Icons.share_rounded, size: 18),
                      label: const Text('Share Link'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: POSTheme.secondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text('Close'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
