import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers.dart';
import '../core/pos_theme.dart';
import '../models/system_model.dart';

class RoleManagementScreen extends ConsumerStatefulWidget {
  const RoleManagementScreen({super.key});

  @override
  ConsumerState<RoleManagementScreen> createState() => _RoleManagementScreenState();
}

class _RoleManagementScreenState extends ConsumerState<RoleManagementScreen> {
  Role? _selectedRole;
  Map<String, bool> _activePermissions = {};
  Map<String, dynamic> _matrix = {};
  bool _isLoadingMatrix = true;
  final TextEditingController _nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchMatrix();
  }

  Future<void> _fetchMatrix() async {
    try {
      final m = await ref.read(apiClientProvider).getPermissionsMatrix();
      if (mounted) {
        setState(() {
          _matrix = m;
          _isLoadingMatrix = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        setState(() => _isLoadingMatrix = false);
      }
    }
  }

  void _selectRole(Role? role) {
    setState(() {
      _selectedRole = role;
      _nameController.text = role?.name ?? '';
      _activePermissions = {};
      
      if (role != null && role.permissions != null) {
        role.permissions!.forEach((key, value) {
          if (value == true) _activePermissions[key] = true;
        });
      }
    });
  }

  Future<void> _saveRole() async {
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a role name')));
      return;
    }

    try {
      if (_selectedRole == null) {
        await ref.read(apiClientProvider).createRole(_nameController.text, _activePermissions);
      } else {
        await ref.read(apiClientProvider).updateRole(_selectedRole!.id!, _nameController.text, _activePermissions);
      }
      ref.invalidate(rolesProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Role saved successfully!'), backgroundColor: POSTheme.success));
        _selectRole(null);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: POSTheme.danger));
    }
  }

  @override
  Widget build(BuildContext context) {
    final rolesAsync = ref.watch(rolesProvider);

    return Scaffold(
      backgroundColor: POSTheme.surface,
      appBar: AppBar(
        title: Text('Roles & Permissions', style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 20)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Row(
        children: [
          // Left Sidebar: Role List
          Container(
            width: 320,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(right: BorderSide(color: POSTheme.border)),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: ElevatedButton.icon(
                    onPressed: () => _selectRole(null),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('CREATE NEW ROLE'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: POSTheme.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 54),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: rolesAsync.when(
                    data: (roles) => ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: roles.length,
                      separatorBuilder: (c, i) => const Divider(height: 1, indent: 24, endIndent: 24),
                      itemBuilder: (context, index) {
                        final r = roles[index];
                        final isSelected = _selectedRole?.id == r.id;
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                          title: Text(r.name.toUpperCase(), 
                            style: GoogleFonts.inter(
                              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                              color: isSelected ? POSTheme.primary : POSTheme.textPrimary,
                              letterSpacing: 0.5,
                            )
                          ),
                          subtitle: Text('${(r.permissions ?? {}).length} Permissions active', style: GoogleFonts.inter(fontSize: 12)),
                          trailing: isSelected ? const Icon(Icons.chevron_right_rounded, color: POSTheme.primary) : null,
                          tileColor: isSelected ? POSTheme.primary.withOpacity(0.05) : null,
                          onTap: () => _selectRole(r),
                        );
                      },
                    ),
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(child: Text('Error: $e')),
                  ),
                ),
              ],
            ),
          ),

          // Main Pane: Permission Management
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _selectedRole == null ? 'Create New Role' : 'Manage Role: ${_selectedRole!.name.toUpperCase()}',
                              style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w900, color: POSTheme.textPrimary),
                            ),
                            const Text('Assign exact capabilities to this staff role with surgical precision.', style: TextStyle(color: POSTheme.textMuted)),
                          ],
                        ),
                      ),
                      if (_selectedRole != null)
                        TextButton.icon(
                          onPressed: () async {
                             final confirm = await showDialog<bool>(
                              context: context,
                              builder: (c) => AlertDialog(
                                title: const Text('Delete Role?'),
                                content: Text('Delete "${_selectedRole!.name.toUpperCase()}" role permanently?'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(backgroundColor: POSTheme.danger, foregroundColor: Colors.white),
                                    onPressed: () => Navigator.pop(c, true), 
                                    child: const Text('Delete')
                                  ),
                                ],
                              ),
                            );
                            if (confirm == true) {
                               await ref.read(apiClientProvider).deleteRole(_selectedRole!.id!);
                               ref.invalidate(rolesProvider);
                               _selectRole(null);
                            }
                          },
                          icon: const Icon(Icons.delete_outline_rounded, color: POSTheme.danger),
                          label: const Text('DELETE ROLE', style: TextStyle(color: POSTheme.danger, fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 40),

                  // Role Name Input
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 500),
                    child: TextField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: 'Role Label',
                        hintText: 'e.g. Supervisor, Night Cashier',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: POSTheme.border)),
                        prefixIcon: const Icon(Icons.badge_outlined),
                      ),
                      style: GoogleFonts.inter(fontWeight: FontWeight.bold),
                    ),
                  ),

                  const SizedBox(height: 48),
                  Text('POLICIES & PERMISSIONS', style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 13, color: POSTheme.textMuted, letterSpacing: 1.5)),
                  const SizedBox(height: 24),

                  // Permission Grid
                  Expanded(
                    child: _isLoadingMatrix 
                      ? const Center(child: CircularProgressIndicator())
                      : _buildPermissionGrid(),
                  ),

                  const SizedBox(height: 32),
                  // Bottom Actions
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: _saveRole,
                        icon: const Icon(Icons.check_circle_outline_rounded),
                        label: Text(_selectedRole == null ? 'CREATE ROLE' : 'SAVE CHANGES', style: const TextStyle(letterSpacing: 1.2)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: POSTheme.success,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 24),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 8,
                          shadowColor: POSTheme.success.withOpacity(0.4),
                        ),
                      ),
                      const SizedBox(width: 24),
                      OutlinedButton(
                        onPressed: () => _selectRole(_selectedRole),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('RESET TO DEFAULT'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionGrid() {
    // Group permissions (Logic to group them based on keys)
    final Map<String, Map<String, String>> groups = {
      'POS & Orders': {},
      'Billing & Payments': {},
      'Staff & Attendance': {},
      'Settings & Menu': {},
      'Reports & Insights': {},
      'Customers & CRM': {},
      'Inventory & Rooms': {},
      'Other': {},
    };

    _matrix.forEach((key, value) {
      final name = value.toString();
      if (key.contains('order') || key.contains('kot') || key.contains('pos')) {
        groups['POS & Orders']![key] = name;
      } else if (key.contains('bill') || key.contains('pay') || key.contains('settle') || key.contains('tax')) {
        groups['Billing & Payments']![key] = name;
      } else if (key.contains('staff') || key.contains('attendance') || key.contains('role') || key.contains('user')) {
        groups['Staff & Attendance']![key] = name;
      } else if (key.contains('menu') || key.contains('settings') || key.contains('floor') || key.contains('counter') || key.contains('system')) {
        groups['Settings & Menu']![key] = name;
      } else if (key.contains('report') || key.contains('summary') || key.contains('insight') || key.contains('sales')) {
        groups['Reports & Insights']![key] = name;
      } else if (key.contains('crm') || key.contains('customer')) {
        groups['Customers & CRM']![key] = name;
      } else if (key.contains('room') || key.contains('table')) {
        groups['Inventory & Rooms']![key] = name;
      } else {
        groups['Other']![key] = name;
      }
    });

    return ListView(
      children: groups.entries.where((e) => e.value.isNotEmpty).map((group) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Row(
                children: [
                  Text(group.key, style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16)),
                  const SizedBox(width: 12),
                  const Expanded(child: Divider()),
                ],
              ),
            ),
            Wrap(
              spacing: 20,
              runSpacing: 20,
              children: group.value.entries.map((p) {
                final isActive = _activePermissions[p.key] == true;
                return Container(
                  width: 380,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isActive ? POSTheme.primary.withOpacity(0.3) : POSTheme.border),
                    boxShadow: isActive ? [BoxShadow(color: POSTheme.primary.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))] : null,
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isActive ? POSTheme.primary.withOpacity(0.1) : Colors.grey[50],
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          isActive ? Icons.verified_user_rounded : Icons.lock_outline_rounded,
                          size: 18,
                          color: isActive ? POSTheme.primary : POSTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p.value, style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13, color: POSTheme.textPrimary)),
                            Text(p.key, style: GoogleFonts.inter(fontSize: 10, color: POSTheme.textMuted, letterSpacing: 0.5)),
                          ],
                        ),
                      ),
                      Switch.adaptive(
                        value: isActive,
                        activeColor: POSTheme.primary,
                        onChanged: (val) {
                          setState(() {
                            if (val) {
                              _activePermissions[p.key] = true;
                            } else {
                              _activePermissions.remove(p.key);
                            }
                          });
                        },
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ],
        );
      }).toList(),
    );
  }
}
