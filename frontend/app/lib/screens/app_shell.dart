import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/pos_theme.dart';
import '../providers.dart';
import 'pos_screen.dart';
import 'dashboard_screen.dart';
import 'kitchen_screen.dart';
import 'orders_screen.dart';
import 'settings_screen.dart';
import 'reports_screen.dart';
import 'staff_management_screen.dart';
import 'menu_management_screen.dart';
import 'table_management_screen.dart';
import 'room_management_screen.dart';
import 'crm_screen.dart';

import 'bulk_pricing_screen.dart';
import 'guest_menu_screen.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  bool _isSidebarExpanded = true;

  @override
  void initState() {
    super.initState();
    // One-time sync on startup to ensure latest restaurant details are loaded
    Future.microtask(() {
      ref.read(settingsProvider.notifier).syncWithBackend();
      ref.read(tableStatusesProvider.notifier).syncWithBackend();
    });
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = ref.watch(selectedScreenProvider);
    final authUser = ref.watch(authProvider);
    final role = authUser?.role ?? '';
    final settings = ref.watch(settingsProvider);

    final List<Map<String, dynamic>> allNavItems = [
      {'index': 0, 'icon': Icons.point_of_sale, 'label': 'Cashier POS', 'roles': ['admin', 'cashier', 'manager', 'captain']},
      {'index': 1, 'icon': Icons.dashboard_rounded, 'label': 'Dashboard', 'roles': ['admin', 'manager']},
      {'index': 2, 'icon': Icons.soup_kitchen_rounded, 'label': 'Kitchen Display', 'roles': ['admin', 'kitchen', 'chef']},
      {'index': 3, 'icon': Icons.receipt_long_rounded, 'label': 'Order History', 'roles': ['admin', 'cashier', 'manager']},
      {'index': 5, 'icon': Icons.analytics_rounded, 'label': 'Insights', 'roles': ['admin', 'manager']},
      {'index': 6, 'icon': Icons.people_alt_rounded, 'label': 'Staff', 'roles': ['admin', 'manager']},
      {'index': 7, 'icon': Icons.restaurant_menu_rounded, 'label': 'Menu', 'roles': ['admin', 'manager']},
      {'index': 8, 'icon': Icons.grid_view_rounded, 'label': 'Tables', 'roles': ['admin', 'cashier', 'manager', 'captain']},
      {'index': 10, 'icon': Icons.meeting_room_rounded, 'label': 'Rooms', 'roles': ['admin', 'cashier', 'manager', 'captain']},
      {'index': 9, 'icon': Icons.history_edu_rounded, 'label': 'CRM', 'roles': ['admin', 'manager']},
      {'index': 11, 'icon': Icons.sell_rounded, 'label': 'Pricing', 'roles': ['admin', 'manager']},
      {'index': 4, 'icon': Icons.settings_rounded, 'label': 'Settings', 'roles': ['admin']},
    ];

    final roleLower = role.toLowerCase();
    final visibleItems = allNavItems.where((item) {
      final List roles = item['roles'];
      return roles.contains(roleLower) || roleLower == 'super admin' || roleLower == 'super_admin';
    }).toList();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Auto-jump for Kitchen staff
      if ((roleLower == 'kitchen' || roleLower == 'chef') && selectedIndex != 2) {
        ref.read(selectedScreenProvider.notifier).state = 2;
        return;
      }

      if (!visibleItems.any((item) => item['index'] == selectedIndex) && visibleItems.isNotEmpty) {
        ref.read(selectedScreenProvider.notifier).state = visibleItems.first['index'];
      }
    });

    final isMobile = MediaQuery.of(context).size.width < 768; // Wait, was this here? No.

    return Scaffold(
      body: Row(
        children: [
          // ─── Premium Sidebar ─────────────────────────────────────
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            width: _isSidebarExpanded ? 240 : 80,
            decoration: const BoxDecoration(
              color: POSTheme.sidebarDark,
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 12,
                  offset: Offset(2, 0),
                ),
              ],
            ),
            child: Column(
              children: [
                const SizedBox(height: 28),

                // Brand / Toggle
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: EdgeInsets.symmetric(horizontal: _isSidebarExpanded ? 16 : 0, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        POSTheme.primary.withOpacity(0.15),
                        POSTheme.primary.withOpacity(0.05),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(POSTheme.radiusMD),
                    border: Border.all(color: POSTheme.primary.withOpacity(0.2)),
                  ),
                  child: _isSidebarExpanded 
                    ? Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.asset(
                                'assets/images/logo.png',
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) => const Icon(Icons.restaurant, color: Colors.white, size: 18),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  settings.restaurantName,
                                  style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  'POS Terminal',
                                  style: GoogleFonts.inter(
                                    color: POSTheme.sidebarText,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      )
                    : IconButton(
                        icon: const Icon(Icons.menu_rounded, color: Colors.white),
                        onPressed: () => setState(() => _isSidebarExpanded = !_isSidebarExpanded),
                        padding: EdgeInsets.zero,
                      ),
                ),

                const SizedBox(height: 24),

                // Manual Toggle if expanded
                if (_isSidebarExpanded)
                  Padding(
                    padding: const EdgeInsets.only(left: 20, right: 10, bottom: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'NAVIGATION',
                          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: POSTheme.sidebarText.withOpacity(0.5), letterSpacing: 1.0),
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_left_rounded, color: POSTheme.sidebarText, size: 20),
                          onPressed: () => setState(() => _isSidebarExpanded = false),
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 8),

                // Navigation
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: visibleItems.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 2),
                    itemBuilder: (context, index) {
                      final item = visibleItems[index];
                      final isSelected = selectedIndex == item['index'];

                      // Kitchen badge
                      Widget? badge;
                      if (item['index'] == 2) {
                        final count = ref.watch(activeOrdersProvider).length;
                        if (count > 0) {
                          badge = Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: POSTheme.primary,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$count',
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          );
                        }
                      }

                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            ref.read(selectedScreenProvider.notifier).state = item['index'];
                          },
                          borderRadius: BorderRadius.circular(POSTheme.radiusMD),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeInOut,
                            padding: EdgeInsets.symmetric(horizontal: _isSidebarExpanded ? 14 : 0, vertical: 12),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? POSTheme.primary.withOpacity(0.12)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(POSTheme.radiusMD),
                              border: isSelected && _isSidebarExpanded
                                  ? Border.all(color: POSTheme.primary.withOpacity(0.2))
                                  : null,
                            ),
                            child: Row(
                              mainAxisAlignment: _isSidebarExpanded ? MainAxisAlignment.start : MainAxisAlignment.center,
                              children: [
                                Icon(
                                  item['icon'],
                                  color: isSelected ? POSTheme.primary : POSTheme.sidebarText,
                                  size: 20,
                                ),
                                if (_isSidebarExpanded) ...[
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      item['label'],
                                      style: GoogleFonts.inter(
                                        color: isSelected ? POSTheme.primary : POSTheme.sidebarText,
                                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  if (badge != null) badge,
                                ],
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // User info & Logout
                Container(
                  margin: const EdgeInsets.all(12),
                  padding: EdgeInsets.all(_isSidebarExpanded ? 12 : 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(POSTheme.radiusMD),
                  ),
                  child: _isSidebarExpanded 
                    ? Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: POSTheme.primary.withOpacity(0.2),
                            child: Text(
                              (authUser?.username ?? '?')[0].toUpperCase(),
                              style: GoogleFonts.inter(
                                color: POSTheme.primary,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  authUser?.username ?? 'User',
                                  style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  role.toUpperCase(),
                                  style: GoogleFonts.inter(
                                    color: POSTheme.sidebarText,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 18),
                            onPressed: () async {
                              await ref.read(authProvider.notifier).logout();
                            },
                            tooltip: 'Logout',
                            splashRadius: 18,
                          ),
                        ],
                      )
                    : Column(
                        children: [
                          CircleAvatar(
                            radius: 14,
                            backgroundColor: POSTheme.primary.withOpacity(0.2),
                            child: Text(
                              (authUser?.username ?? '?')[0].toUpperCase(),
                              style: GoogleFonts.inter(
                                color: POSTheme.primary,
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          IconButton(
                            icon: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 16),
                            onPressed: () async {
                              await ref.read(authProvider.notifier).logout();
                            },
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),

          // ─── Main Content ────────────────────────────────────────
          Expanded(
            child: _buildBody(selectedIndex),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(int index) {
    switch (index) {
      case 0:
        return const PosScreen();
      case 1:
        return const DashboardScreen();
      case 2:
        return const KitchenScreen();
      case 3:
        return const OrdersScreen();
      case 4:
        return const SettingsScreen();
      case 5:
        return const ReportsScreen();
      case 6:
        return const StaffManagementScreen();
      case 7:
        return const MenuManagementScreen();
      case 8:
        return const TableManagementScreen();
      case 9:
        return const CRMScreen();
      case 10:
        return const RoomManagementScreen();

      case 11:
        return const BulkPricingScreen();
      default:
        return const Center(child: Text('Screen not found'));
    }
  }
}
