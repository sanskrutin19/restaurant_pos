import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../utils/time_utils.dart';
import '../providers.dart';
import '../core/pos_theme.dart';

final staffUsersProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  return await ref.read(apiClientProvider).getStaffUsers();
});

final attendanceLogsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  return await ref.read(apiClientProvider).getAttendanceLogs();
});

class StaffManagementScreen extends ConsumerStatefulWidget {
  const StaffManagementScreen({super.key});

  @override
  ConsumerState<StaffManagementScreen> createState() => _StaffManagementScreenState();
}

class _StaffManagementScreenState extends ConsumerState<StaffManagementScreen> {
  @override
  Widget build(BuildContext context) {
    final authUser = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: POSTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: Text('Staff Management', style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: POSTheme.textDark)),
        iconTheme: const IconThemeData(color: POSTheme.textDark),
        actions: [
          if (authUser?.role?.toLowerCase() == 'admin' || authUser?.role?.toLowerCase() == 'owner' || authUser?.role?.toLowerCase() == 'manager')
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ElevatedButton.icon(
                onPressed: () => _showAddStaffDialog(context),
                icon: const Icon(Icons.person_add, size: 20),
                label: const Text('Add Staff'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: POSTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Welcome, ${authUser?.username ?? 'Staff'}', style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.bold, color: POSTheme.textDark)),
            Text('Manage staff shifts, attendance, and records here.', style: GoogleFonts.inter(color: POSTheme.textMuted, fontSize: 16)),
            const SizedBox(height: 32),
            
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _ClockInCard()),
                const SizedBox(width: 32),
                const Expanded(child: _ShiftSummaryCard()),
              ],
            ),
            
            if (authUser?.role?.toLowerCase() == 'admin' || authUser?.role?.toLowerCase() == 'owner' || authUser?.role?.toLowerCase() == 'manager') ...[
              const SizedBox(height: 48),
              Text('Active & Registered Staff', style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.bold, color: POSTheme.textDark)),
              const SizedBox(height: 16),
              _StaffListWidget(),
            ],
          ],
        ),
      ),
    );
  }

  void _showAddStaffDialog(BuildContext context) {
    final usernameCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    final hourlyRateCtrl = TextEditingController(text: '100.0');
    String selectedRole = 'cashier';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text('Register New Staff', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: usernameCtrl,
                    decoration: InputDecoration(labelText: 'Username', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: passwordCtrl,
                    obscureText: true,
                    decoration: InputDecoration(labelText: 'Secure Password', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: hourlyRateCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: 'Hourly Rate (₹)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                  ),
                  const SizedBox(height: 16),
                  Text('Role', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: POSTheme.textMuted)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: ref.watch(rolesProvider).when(
                        data: (roles) {
                          final currentRoles = ['admin', 'cashier', 'waiter', 'chef', 'manager', 'owner'];
                          String effectiveRole = selectedRole;
                          bool hasMatch = roles.any((r) => r.name.toLowerCase() == selectedRole.toLowerCase()) || 
                                         currentRoles.contains(selectedRole.toLowerCase());
                                         
                          if (!hasMatch && roles.isNotEmpty) {
                              effectiveRole = roles.first.name.toLowerCase();
                          }
                          
                          String safeEffectiveRole = effectiveRole.toLowerCase();
                          
                          return DropdownButton<String>(
                            isExpanded: true,
                            value: safeEffectiveRole,
                            items: [
                              ...roles.map((r) => DropdownMenuItem(value: r.name.toLowerCase(), child: Text(r.name.toUpperCase()))),
                              if (roles.isEmpty) ...[
                                const DropdownMenuItem(value: 'admin', child: Text('Admin (Full Access)')),
                                const DropdownMenuItem(value: 'cashier', child: Text('Cashier (Billing & Orders)')),
                                const DropdownMenuItem(value: 'waiter', child: Text('Waiter (Orders Only)')),
                                const DropdownMenuItem(value: 'chef', child: Text('Chef (Kitchen Display)')),
                              ]
                            ],
                            onChanged: (val) {
                              if (val != null) setState(() => selectedRole = val);
                            },
                          );
                        },
                        loading: () => const Center(child: CircularProgressIndicator()),
                        error: (_, __) => DropdownButton<String>(
                          isExpanded: true,
                          value: selectedRole.toLowerCase(),
                          items: const [
                            DropdownMenuItem(value: 'admin', child: Text('Admin (Full Access)')),
                            DropdownMenuItem(value: 'cashier', child: Text('Cashier (Billing & Orders)')),
                            DropdownMenuItem(value: 'waiter', child: Text('Waiter (Orders Only)')),
                            DropdownMenuItem(value: 'chef', child: Text('Chef (Kitchen Display)')),
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() => selectedRole = val);
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: POSTheme.primary, foregroundColor: Colors.white),
              onPressed: () async {
                if (usernameCtrl.text.isEmpty || passwordCtrl.text.isEmpty) return;
                try {
                  await ref.read(apiClientProvider).createStaff(
                    usernameCtrl.text, 
                    passwordCtrl.text, 
                    selectedRole,
                    hourlyRate: double.tryParse(hourlyRateCtrl.text) ?? 100.0,
                  );
                  ref.invalidate(staffUsersProvider);
                  if (mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Staff created successfully'), backgroundColor: POSTheme.success));
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: POSTheme.danger));
                }
              },
              child: const Text('Add Staff'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditStaffDialog(BuildContext context, Map<String, dynamic> user) {
    final usernameCtrl = TextEditingController(text: user['username']);
    final passwordCtrl = TextEditingController();
    final hourlyRateCtrl = TextEditingController(text: (user['hourly_rate'] ?? 100).toString());
    String selectedRole = (user['role'] ?? 'cashier').toString().toLowerCase();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text('Edit Staff Member', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: usernameCtrl,
                    decoration: InputDecoration(labelText: 'Username', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: passwordCtrl,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'New Password (Leave blank to keep current)', 
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: hourlyRateCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: 'Hourly Rate (₹)', border: OutlineInputBorder(borderRadius: BorderRadius.circular(8))),
                  ),
                  const SizedBox(height: 16),
                  Text('Role', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: POSTheme.textMuted)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: ref.watch(rolesProvider).when(
                        data: (roles) {
                          final currentRoles = ['admin', 'cashier', 'waiter', 'chef', 'manager', 'owner']; // Fallback options
                          final dynamicRoleNames = roles.map((r) => r.name.toLowerCase()).toList();
                          
                          // Ensure the selectedRole is valid in the available list, otherwise fallback to first valid option
                          String effectiveRole = selectedRole;
                          bool hasMatch = roles.any((r) => r.name.toLowerCase() == selectedRole.toLowerCase()) || 
                                         currentRoles.contains(selectedRole.toLowerCase());
                                         
                          if (!hasMatch && roles.isNotEmpty) {
                              effectiveRole = roles.first.name.toLowerCase();
                          }
                          
                          String safeEffectiveRole = effectiveRole.toLowerCase();
                          
                          return DropdownButton<String>(
                            isExpanded: true,
                            value: safeEffectiveRole,
                            items: [
                              ...roles.map((r) => DropdownMenuItem(value: r.name.toLowerCase(), child: Text(r.name.toUpperCase()))),
                              if (roles.isEmpty) ...[
                                const DropdownMenuItem(value: 'admin', child: Text('Admin')),
                                const DropdownMenuItem(value: 'cashier', child: Text('Cashier')),
                                const DropdownMenuItem(value: 'waiter', child: Text('Waiter')),
                                const DropdownMenuItem(value: 'chef', child: Text('Chef')),
                              ]
                            ],
                            onChanged: (val) {
                              if (val != null) setState(() => selectedRole = val);
                            },
                          );
                        },
                        loading: () => const Center(child: CircularProgressIndicator()),
                        error: (_, __) => DropdownButton<String>(
                          isExpanded: true,
                          value: selectedRole.toLowerCase(),
                          items: const [
                            DropdownMenuItem(value: 'admin', child: Text('Admin')),
                            DropdownMenuItem(value: 'cashier', child: Text('Cashier')),
                            DropdownMenuItem(value: 'waiter', child: Text('Waiter')),
                            DropdownMenuItem(value: 'chef', child: Text('Chef')),
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() => selectedRole = val);
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (id) => AlertDialog(
                    title: const Text('Confirm Deletion'),
                    content: Text('Are you sure you want to delete ${user['username']}?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(id, false), child: const Text('No')),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: POSTheme.danger, foregroundColor: Colors.white),
                        onPressed: () => Navigator.pop(id, true), 
                        child: const Text('Yes, Delete')
                      ),
                    ],
                  ),
                );
                
                if (confirm == true) {
                  try {
                    await ref.read(apiClientProvider).deleteStaff(user['id']);
                    ref.invalidate(staffUsersProvider);
                    if (mounted) {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Staff deleted'), backgroundColor: POSTheme.danger));
                    }
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: POSTheme.danger));
                  }
                }
              }, 
              child: const Text('Delete Account', style: TextStyle(color: POSTheme.danger))
            ),
            const Spacer(),
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: POSTheme.primary, foregroundColor: Colors.white),
              onPressed: () async {
                try {
                  await ref.read(apiClientProvider).updateStaff(
                    user['id'],
                    username: usernameCtrl.text, 
                    password: passwordCtrl.text.isEmpty ? null : passwordCtrl.text,
                    role: selectedRole,
                    hourlyRate: double.tryParse(hourlyRateCtrl.text),
                  );
                  ref.invalidate(staffUsersProvider);
                  if (mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Staff updated!'), backgroundColor: POSTheme.success));
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: POSTheme.danger));
                }
              },
              child: const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StaffListWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final staffAsync = ref.watch(staffUsersProvider);

    return staffAsync.when(
      data: (users) {
        if (users.isEmpty) return const Center(child: Text('No staff registered.'));
        
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey[200]!),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: users.length,
            separatorBuilder: (context, index) => Divider(height: 1, color: Colors.grey[100]),
            itemBuilder: (context, index) {
              final user = users[index];
              final bool isClockedIn = user['is_clocked_in'] == true;
              
              String timeSince = 'Offline';
              if (isClockedIn && user['active_session_start'] != null) {
                final start = TimeUtils.parseUtc(user['active_session_start']).toLocal();
                final diff = DateTime.now().difference(start);
                timeSince = 'In: ${DateFormat('hh:mm a').format(start)} (${diff.inHours}h ${diff.inMinutes.remainder(60)}m)';
              }

              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                leading: CircleAvatar(
                  backgroundColor: POSTheme.primary.withOpacity(0.1),
                  radius: 24,
                  child: Text(
                    user['username'].toString().substring(0, 1).toUpperCase(), 
                    style: GoogleFonts.inter(color: POSTheme.primary, fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ),
                title: Text(user['username'], style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16)),
                subtitle: Text(user['role'].toString().toUpperCase(), style: GoogleFonts.inter(color: POSTheme.textMuted, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isClockedIn ? POSTheme.success.withOpacity(0.1) : Colors.grey[100],
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: isClockedIn ? POSTheme.success.withOpacity(0.3) : Colors.grey[300]!),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8, height: 8,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: isClockedIn ? POSTheme.success : Colors.grey[400]),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isClockedIn ? timeSince : 'Not Clocked In',
                        style: GoogleFonts.inter(
                          color: isClockedIn ? POSTheme.success : Colors.grey[600],
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                onTap: () {
                  final parentState = context.findAncestorStateOfType<_StaffManagementScreenState>();
                  if (parentState != null) {
                    parentState._showEditStaffDialog(context, user);
                  }
                },
              );
            },
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, trace) {
        if (e.toString().contains('401')) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_clock, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                const Text('Session Expired', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                const Text('Please tap the user icon top-right and Logout,\nthen log in again to refresh your session.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
              ],
            ),
          );
        }
        return Center(child: Text('Error loading staff: $e\n$trace'));
      },
    );
  }
}

class _ClockInCard extends ConsumerStatefulWidget {
  @override
  _ClockInCardState createState() => _ClockInCardState();
}

class _ClockInCardState extends ConsumerState<_ClockInCard> with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authUser = ref.watch(authProvider);
    final staffAsync = ref.watch(staffUsersProvider);
    
    bool isClockedIn = false;
    String startTimeStr = 'Not Clocked In';
    
    if (staffAsync.hasValue && authUser != null) {
      final staffList = staffAsync.valueOrNull;
      if (staffList != null) {
        final userMatch = staffList.where((u) => u['id'].toString() == authUser.id.toString()).toList();
        if (userMatch.isNotEmpty) {
          final u = userMatch.first;
          isClockedIn = u['is_clocked_in'] == true;
          if (isClockedIn && u['active_session_start'] != null) {
            final start = TimeUtils.parseUtc(u['active_session_start']).toLocal();
            startTimeStr = 'Clocked in since ${DateFormat('hh:mm a').format(start)}';
          }
        }
      }
    }

    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              if (isClockedIn)
                ScaleTransition(
                  scale: Tween(begin: 1.0, end: 1.2).animate(_pulseController),
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: POSTheme.success.withOpacity(0.1)),
                  ),
                ),
              CircleAvatar(
                radius: 40,
                backgroundColor: isClockedIn ? POSTheme.success : POSTheme.surface,
                child: _isLoading 
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Icon(isClockedIn ? Icons.timer : Icons.timer_off, size: 40, color: isClockedIn ? Colors.white : POSTheme.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(isClockedIn ? 'ON DUTY' : 'OFF DUTY', 
            style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w900, color: isClockedIn ? POSTheme.success : POSTheme.textMuted, letterSpacing: 2),
          ),
          const SizedBox(height: 8),
          Text(isClockedIn ? startTimeStr : 'Currently clocked out', style: GoogleFonts.inter(fontSize: 14, color: POSTheme.textMuted)),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: _isLoading ? null : () async {
              if (authUser == null) return;
              
              setState(() => _isLoading = true);
              try {
                if (isClockedIn) {
                  await ref.read(apiClientProvider).clockOut(authUser.id ?? 1);
                } else {
                  await ref.read(apiClientProvider).clockIn(authUser.id ?? 1);
                }
                
                await ref.refresh(staffUsersProvider.future);
                setState(() => _isLoading = false);

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(isClockedIn ? 'Clocked Out Successfully' : 'Clocked In Successfully'),
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: isClockedIn ? POSTheme.textDark : POSTheme.success,
                    ),
                  );
                }
              } catch (e) {
                setState(() => _isLoading = false);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: POSTheme.danger));
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isClockedIn ? POSTheme.danger : POSTheme.success,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 56),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: Text(isClockedIn ? 'END SHIFT' : 'START SHIFT', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1)),
          ),
        ],
      ),
    );
  }
}

class _ShiftSummaryCard extends StatelessWidget {
  const _ShiftSummaryCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: POSTheme.textDark,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
               const Icon(Icons.stars_rounded, color: POSTheme.warning, size: 32),
               Text('TODAY SUMMARY', style: GoogleFonts.inter(color: Colors.white54, fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.5)),
            ],
          ),
          const SizedBox(height: 40),
          _summaryRow('Hours Worked', '8.0h', Colors.white),
          const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Divider(color: Colors.white12, height: 1)),
          _summaryRow('Tips Earned', '₹0.00', POSTheme.success),
          const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Divider(color: Colors.white12, height: 1)),
          _summaryRow('Orders Taken', '0', POSTheme.primary),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.inter(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w500)),
        Text(value, style: GoogleFonts.inter(color: valueColor, fontSize: 24, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
