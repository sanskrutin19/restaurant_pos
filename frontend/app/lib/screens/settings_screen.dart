import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers.dart';
import '../models/settings_model.dart';
import '../services/printer_service.dart';
import 'floor_plan_designer.dart';
import '../core/pos_theme.dart';
import '../models/system_model.dart';
import 'role_management_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late TextEditingController _nameController;
  late TextEditingController _urlController;
  late TextEditingController _taxController;
  late TextEditingController _tablesController;
  late TextEditingController _currencyController;
  late TextEditingController _counterController;
  late TextEditingController _addressController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _gstinController;
  late TextEditingController _fssaiController;
  late TextEditingController _taxLabelController;
  late TextEditingController _footerController;
  late TextEditingController _billPrinterAddrController;
  late TextEditingController _billPrinterPortController;
  bool _kitchenSoundEnabled = true;
  bool _autoPrintKOT = true;
  String _billPrinterType = 'network';

  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsProvider);
    _nameController = TextEditingController(text: settings.restaurantName);
    _urlController = TextEditingController(text: settings.apiBaseUrl);
    _taxController = TextEditingController(text: settings.taxRate.toString());
    _tablesController = TextEditingController(text: settings.totalTables.toString());
    _currencyController = TextEditingController(text: settings.currencySymbol);
    _counterController = TextEditingController(text: settings.counterId);
    _addressController = TextEditingController(text: settings.restaurantAddress);
    _phoneController = TextEditingController(text: settings.restaurantPhone);
    _emailController = TextEditingController(text: settings.restaurantEmail);
    _gstinController = TextEditingController(text: settings.gstin);
    _fssaiController = TextEditingController(text: settings.fssaiLicense);
    _taxLabelController = TextEditingController(text: settings.taxLabel);
    _footerController = TextEditingController(text: settings.billFooter);
    _billPrinterAddrController = TextEditingController(text: settings.billPrinterAddress ?? '');
    _billPrinterPortController = TextEditingController(text: settings.billPrinterPort.toString());
    _kitchenSoundEnabled = settings.kitchenSoundEnabled;
    _autoPrintKOT = settings.autoPrintKOT;
    _billPrinterType = settings.billPrinterType;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _urlController.dispose();
    _taxController.dispose();
    _tablesController.dispose();
    _currencyController.dispose();
    _counterController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _gstinController.dispose();
    _fssaiController.dispose();
    _taxLabelController.dispose();
    _footerController.dispose();
    _billPrinterAddrController.dispose();
    _billPrinterPortController.dispose();
    super.dispose();
  }

  void _saveSettings() {
    if (_formKey.currentState!.validate()) {
      final newSettings = AppSettings(
        restaurantName: _nameController.text.trim(),
        apiBaseUrl: _urlController.text.trim(),
        taxRate: double.tryParse(_taxController.text) ?? 5.0,
        totalTables: int.tryParse(_tablesController.text) ?? 20,
        currencySymbol: _currencyController.text.trim(),
        kitchenSoundEnabled: _kitchenSoundEnabled,
        counterId: _counterController.text.trim(),
        restaurantAddress: _addressController.text.trim(),
        restaurantPhone: _phoneController.text.trim(),
        restaurantEmail: _emailController.text.trim(),
        gstin: _gstinController.text.trim(),
        fssaiLicense: _fssaiController.text.trim(),
        taxLabel: _taxLabelController.text.trim(),
        billFooter: _footerController.text.trim(),
        billPrinterAddress: _billPrinterAddrController.text.trim(),
        billPrinterPort: int.tryParse(_billPrinterPortController.text) ?? 9100,
        billPrinterType: _billPrinterType,
        autoPrintKOT: _autoPrintKOT,
      );

      ref.read(settingsProvider.notifier).saveSettings(newSettings);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Settings saved successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _resetOrders() async {
    final TextEditingController confirmController = TextEditingController();
    
    final bool? confirm1 = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text('Reset All Orders?'),
          ],
        ),
        content: const Text('This will PERMANENTLY delete all order history, payments, and bills. This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true), 
            child: const Text('CONTINUE', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))
          ),
        ],
      ),
    );

    if (confirm1 != true || !mounted) return;

    final bool? confirm2 = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Final Confirmation'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Please type "RESET" to confirm permanent deletion:'),
            const SizedBox(height: 12),
            TextField(
              controller: confirmController,
              decoration: const InputDecoration(
                hintText: 'RESET',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.characters,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true), 
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('ERASE EVERYTHING')
          ),
        ],
      ),
    );

    if (confirm2 == true && confirmController.text.trim() == "RESET") {
      try {
        await ref.read(apiClientProvider).resetOrders();
        
        // Reset local app state related to orders
        ref.read(cartProvider.notifier).clearCart();
        ref.read(activeOrderIdProvider.notifier).state = null;
        ref.invalidate(ordersProvider);
        ref.invalidate(tableStatusesProvider);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('All order data has been successfully reset.'), backgroundColor: Colors.green),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to reset orders: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
    
    confirmController.dispose();
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: Colors.grey[600],
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 1,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24.0),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 800),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Restaurant Profile
                    _buildSectionHeader('Restaurant Profile'),
                    Card(
                      elevation: 2,
                      surfaceTintColor: Colors.white,
                      color: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Basic details about your restaurant.',
                              style: TextStyle(fontSize: 13, color: Colors.grey),
                            ),
                            const SizedBox(height: 20),
                            TextFormField(
                              controller: _nameController,
                              decoration: InputDecoration(
                                labelText: 'Restaurant Name *',
                                prefixIcon: const Icon(Icons.restaurant),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                filled: true,
                                fillColor: Colors.grey[50],
                              ),
                              validator: (String? v) => (v == null || v.isEmpty) ? 'Required' : null,
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _currencyController,
                                    decoration: InputDecoration(
                                      labelText: 'Currency Symbol',
                                      prefixIcon: const Icon(Icons.money),
                                      hintText: '₹',
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                      filled: true,
                                      fillColor: Colors.grey[50],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: TextFormField(
                                    controller: _taxController,
                                    decoration: InputDecoration(
                                      labelText: 'Default Tax Rate (%)',
                                      prefixIcon: const Icon(Icons.percent),
                                      hintText: '5.0',
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                      filled: true,
                                      fillColor: Colors.grey[50],
                                    ),
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    validator: (String? v) {
                                      if (v == null || v.isEmpty) return 'Required';
                                      if (double.tryParse(v) == null) return 'Must be a valid number';
                                      return null;
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Business Profile (Extended)
                    _buildSectionHeader('Business Profile'),
                    Card(
                      elevation: 2,
                      surfaceTintColor: Colors.white,
                      color: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _addressController,
                              maxLines: 2,
                              decoration: InputDecoration(
                                labelText: 'Address',
                                prefixIcon: const Icon(Icons.location_on),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                filled: true,
                                fillColor: Colors.grey[50],
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _phoneController,
                                    decoration: InputDecoration(
                                      labelText: 'Phone',
                                      prefixIcon: const Icon(Icons.phone),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                      filled: true,
                                      fillColor: Colors.grey[50],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: TextFormField(
                                    controller: _emailController,
                                    decoration: InputDecoration(
                                      labelText: 'Email',
                                      prefixIcon: const Icon(Icons.email),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                      filled: true,
                                      fillColor: Colors.grey[50],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _gstinController,
                                    decoration: InputDecoration(
                                      labelText: 'GSTIN',
                                      prefixIcon: const Icon(Icons.receipt_long),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                      filled: true,
                                      fillColor: Colors.grey[50],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: TextFormField(
                                    controller: _fssaiController,
                                    decoration: InputDecoration(
                                      labelText: 'FSSAI License',
                                      prefixIcon: const Icon(Icons.verified),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                      filled: true,
                                      fillColor: Colors.grey[50],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _taxLabelController,
                                    decoration: InputDecoration(
                                      labelText: 'Tax Label (e.g. GST)',
                                      prefixIcon: const Icon(Icons.percent),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                      filled: true,
                                      fillColor: Colors.grey[50],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                const Spacer(),
                              ],
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _footerController,
                              decoration: InputDecoration(
                                labelText: 'Bill Footer Text',
                                prefixIcon: const Icon(Icons.description),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                filled: true,
                                fillColor: Colors.grey[50],
                              ),
                            ),
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _saveSettings,
                                icon: const Icon(Icons.save),
                                label: const Text('SAVE PROFILE', style: TextStyle(fontWeight: FontWeight.bold)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green[700],
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Printer Configuration
                    _buildSectionHeader('Printer Configuration'),
                    _buildPrinterSettingsSection(),
                    const SizedBox(height: 24),

                    // Layout & Design
                    _buildSectionHeader('Layout & Design'),
                    Card(
                      elevation: 2,
                      surfaceTintColor: Colors.white,
                      color: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  Navigator.push(context, MaterialPageRoute(builder: (c) => const FloorPlanDesigner()));
                                },
                                icon: const Icon(Icons.grid_view_rounded),
                                label: const Text('Open Floor Plan Designer', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: POSTheme.primary,
                                  side: BorderSide(color: POSTheme.primary, width: 2),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Operations
                    _buildSectionHeader('Operations'),
                    _buildKitchenCountersSection(ref),
                    const SizedBox(height: 16),
                    Card(
                      elevation: 2,
                      surfaceTintColor: Colors.white,
                      color: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextFormField(
                              controller: _tablesController,
                              decoration: InputDecoration(
                                labelText: 'Total Tables',
                                prefixIcon: const Icon(Icons.table_restaurant),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                filled: true,
                                fillColor: Colors.grey[50],
                              ),
                              keyboardType: TextInputType.number,
                              validator: (String? v) {
                                if (v == null || v.isEmpty) return 'Required';
                                if (int.tryParse(v) == null) return 'Must be a valid integer';
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _counterController,
                              decoration: InputDecoration(
                                labelText: 'Counter ID',
                                prefixIcon: const Icon(Icons.computer),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                filled: true,
                                fillColor: Colors.grey[50],
                              ),
                              validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                            ),
                            const SizedBox(height: 16),
                            SwitchListTile(
                              title: const Text('New Order Sound (Kitchen)', style: TextStyle(fontWeight: FontWeight.w500)),
                              subtitle: const Text('Play a sound when a new order arrives'),
                              value: _kitchenSoundEnabled,
                              onChanged: (val) => setState(() => _kitchenSoundEnabled = val),
                              activeColor: POSTheme.primary,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // User Security
                    _buildSectionHeader('User Security'),
                    Card(
                      elevation: 2,
                      surfaceTintColor: Colors.white,
                      color: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Update your login credentials here.',
                              style: TextStyle(fontSize: 13, color: Colors.grey),
                            ),
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: ElevatedButton.icon(
                                onPressed: _showChangePasswordDialog,
                                icon: const Icon(Icons.lock_reset_rounded),
                                label: const Text('CHANGE PASSWORD', style: TextStyle(fontWeight: FontWeight.bold)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blueGrey[800],
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Divider(),
                            const SizedBox(height: 16),
                            const Text(
                              'Manage dynamic roles and access controls for staff.',
                              style: TextStyle(fontSize: 13, color: Colors.grey),
                            ),
                            const SizedBox(height: 20),
                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: ElevatedButton.icon(
                                onPressed: _showRolesManagementDialog,
                                icon: const Icon(Icons.security_rounded),
                                label: const Text('MANAGE ROLES & PERMISSIONS', style: TextStyle(fontWeight: FontWeight.bold)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: POSTheme.primary,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Network Configuration
                    _buildSectionHeader('Network Configuration'),
                    Card(
                      elevation: 2,
                      surfaceTintColor: Colors.white,
                      color: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextFormField(
                              controller: _urlController,
                              decoration: InputDecoration(
                                labelText: 'API Base URL',
                                prefixIcon: const Icon(Icons.api),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                filled: true,
                                fillColor: Colors.grey[50],
                              ),
                              validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Note: Make sure this points to your running backend server.',
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    // Server Connection Status
                    _buildSectionHeader('Server Status'),
                    ref.watch(systemInfoProvider).when(
                      data: (info) => Card(
                        elevation: 2,
                        surfaceTintColor: Colors.green,
                        color: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.check_circle, color: Colors.green),
                                  const SizedBox(width: 12),
                                  Text(
                                    'ONLINE: ${info['hostname'] ?? 'Unknown'}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green),
                                  ),
                                  const Spacer(),
                                  TextButton.icon(
                                    onPressed: () => ref.invalidate(systemInfoProvider),
                                    icon: const Icon(Icons.refresh, size: 16),
                                    label: const Text('Refresh'),
                                  ),
                                ],
                              ),
                              const Divider(height: 32),
                              const Text('Connect other terminals using this address:', style: TextStyle(fontSize: 13, color: Colors.grey)),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.grey[50],
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey[200]!),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.link, size: 16, color: POSTheme.primary),
                                    const SizedBox(width: 12),
                                    SelectableText(
                                      'http://${info['local_ip'] ?? '0.0.0.0'}:8000',
                                      style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: POSTheme.primary),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      loading: () => const Card(child: Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator()))),
                      error: (e, _) => Card(
                        elevation: 2,
                        surfaceTintColor: Colors.red,
                        color: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.error_outline, color: Colors.red),
                                  SizedBox(width: 12),
                                  Text('CONNECTION ERROR', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text('The backend server may be offline or unreachable. Check your URL above.', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  OutlinedButton(
                                    onPressed: () => ref.invalidate(systemInfoProvider),
                                    child: const Text('Retry Connection'),
                                  ),
                                  const SizedBox(width: 12),
                                  ElevatedButton.icon(
                                    onPressed: () async {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Scanning for server...')),
                                      );
                                      final success = await ref.read(settingsProvider.notifier).autoDiscoverServer();
                                      if (success && mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Server found and connected!'), backgroundColor: Colors.green),
                                        );
                                        ref.invalidate(systemInfoProvider);
                                        // Update the UI controller
                                        _urlController.text = ref.read(settingsProvider).apiBaseUrl;
                                      } else if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Could not find server automatically.'), backgroundColor: Colors.red),
                                        );
                                      }
                                    },
                                    icon: const Icon(Icons.radar),
                                    label: const Text('Auto-Discover Server'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: POSTheme.primary,
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),
                    _buildSectionHeader('Maintenance'),
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.red.withOpacity(0.2))),
                      color: Colors.red.withOpacity(0.02),
                      child: ListTile(
                        leading: const Icon(Icons.delete_forever_rounded, color: Colors.red),
                        title: const Text('Reset All Order Data', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                        subtitle: const Text('Delete all history, payments, and tickets. Safe for starting a new session.', style: TextStyle(fontSize: 12)),
                        onTap: _resetOrders,
                        trailing: const Icon(Icons.chevron_right, color: Colors.red),
                      ),
                    ),

                    const SizedBox(height: 24),
                    _buildSectionHeader('About App'),
                    const ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('Version', style: TextStyle(fontWeight: FontWeight.bold)),
                      trailing: Text('2.0.0 (Pro)', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                    ),

                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _saveSettings,
                        icon: const Icon(Icons.save),
                        label: const Text('SAVE SETTINGS', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.1)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: POSTheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrinterSettingsSection() {
    return Card(
      elevation: 2,
      surfaceTintColor: Colors.white,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Bill Printer (Thermal)', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: _billPrinterAddrController,
                    decoration: InputDecoration(
                      labelText: 'IP Address',
                      hintText: 'e.g. 192.168.1.100',
                      prefixIcon: const Icon(Icons.settings_ethernet),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.search, color: POSTheme.primary),
                        onPressed: () => _showScanPrintersDialog(_billPrinterAddrController),
                        tooltip: 'Scan for Printers',
                      ),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 1,
                  child: TextFormField(
                    controller: _billPrinterPortController,
                    decoration: InputDecoration(
                      labelText: 'Port',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _billPrinterType,
              decoration: InputDecoration(
                labelText: 'Connection Type',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              items: ['network', 'usb', 'bluetooth'].map((t) => DropdownMenuItem(value: t, child: Text(t.toUpperCase()))).toList(),
              onChanged: (v) => setState(() => _billPrinterType = v!),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Auto-Print KOT on Send', style: TextStyle(fontWeight: FontWeight.w500)),
              subtitle: const Text('Automatically print KOT to station printers when sent to kitchen'),
              value: _autoPrintKOT,
              onChanged: (val) => setState(() => _autoPrintKOT = val),
              activeColor: POSTheme.primary,
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () async {
                final addr = _billPrinterAddrController.text.trim();
                final portStr = _billPrinterPortController.text.trim();
                final targetPort = int.tryParse(portStr) ?? 9100;
                
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Connecting to $addr on port $targetPort...')));
                
                try {
                  // Connect and send a simple bell to test
                  final socket = await Socket.connect(addr, targetPort, timeout: const Duration(seconds: 3));
                  socket.add([0x1B, 0x40, 0x07]); // Initialise + Bell
                  await socket.flush();
                  await socket.close();
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Printer connected & pinged!'), backgroundColor: Colors.green));
                } catch (e) {
                   if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Connect failed: $e'), backgroundColor: Colors.red));
                }
              },
              icon: const Icon(Icons.print_outlined),
              label: const Text('TEST BILL PRINTER'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKitchenCountersSection(WidgetRef ref) {
    final countersAsync = ref.watch(kitchenCountersProvider);

    return Card(
      elevation: 2,
      surfaceTintColor: Colors.white,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Kitchen Stations', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                IconButton(
                  icon: const Icon(Icons.add_circle, color: POSTheme.primary),
                  onPressed: () => _showAddCounterDialog(ref),
                ),
              ],
            ),
            const Text('Map stations to kitchen printers for silent KOT routing.', style: TextStyle(fontSize: 12, color: Colors.grey)),
            const Divider(),
            countersAsync.when(
              data: (counters) => counters.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Center(child: Text('No stations configured', style: TextStyle(color: Colors.grey))),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: counters.length,
                      separatorBuilder: (c, i) => const Divider(height: 1),
                      itemBuilder: (c, i) {
                        final s = counters[i];
                        final hasPrinter = s.printerAddress != null && s.printerAddress!.isNotEmpty;
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor: Color(int.parse(s.color.replaceFirst('#', '0xFF'))).withOpacity(0.1),
                            child: Icon(Icons.print_outlined, size: 18, color: Color(int.parse(s.color.replaceFirst('#', '0xFF')))),
                          ),
                          title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text(hasPrinter ? 'Printer: ${s.printerAddress}:${s.printerPort} (${s.printerType.toUpperCase()})' : 'NO PRINTER MAPPED', 
                            style: TextStyle(fontSize: 11, color: hasPrinter ? Colors.green : Colors.red, fontWeight: FontWeight.bold)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.settings_outlined, size: 20),
                                onPressed: () => _showEditCounterDialog(ref, s),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 20, color: Colors.grey),
                                onPressed: () => _confirmDeleteCounter(ref, s),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
              loading: () => const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator())),
              error: (e, _) => Text('Error: $e', style: const TextStyle(color: Colors.red)),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddCounterDialog(WidgetRef ref) {
    final nameCtrl = TextEditingController();
    final addrCtrl = TextEditingController();
    final portCtrl = TextEditingController(text: '9100');
    String type = 'network';

    showDialog(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add Kitchen Station'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Station Name', hintText: 'e.g. Grill, Bar'),
                  autofocus: true,
                ),
                const SizedBox(height: 16),
                const Text('Printer Configuration (Optional)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: addrCtrl,
                        decoration: InputDecoration(
                          labelText: 'IP Address', 
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.search, color: POSTheme.primary),
                            onPressed: () => _showScanPrintersDialog(addrCtrl),
                            tooltip: 'Scan for Printers',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 1,
                      child: TextField(
                        controller: portCtrl,
                        decoration: const InputDecoration(labelText: 'Port', border: OutlineInputBorder()),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: type,
                  decoration: const InputDecoration(labelText: 'Type', border: OutlineInputBorder()),
                  items: ['network', 'usb', 'bluetooth'].map((t) => DropdownMenuItem(value: t, child: Text(t.toUpperCase()))).toList(),
                  onChanged: (v) => setState(() => type = v!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c), child: const Text('CANCEL')),
            ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.isNotEmpty) {
                  try {
                    await ref.read(kitchenCountersProvider.notifier).addCounter(
                      nameCtrl.text,
                      printerAddress: addrCtrl.text.isEmpty ? null : addrCtrl.text,
                      printerPort: int.tryParse(portCtrl.text) ?? 9100,
                      printerType: type,
                    );
                    if (mounted) Navigator.pop(c);
                  } catch (e) {
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                }
              },
              child: const Text('ADD STATION'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditCounterDialog(WidgetRef ref, KitchenCounter counter) {
    final nameCtrl = TextEditingController(text: counter.name);
    final addrCtrl = TextEditingController(text: counter.printerAddress ?? '');
    final portCtrl = TextEditingController(text: counter.printerPort.toString());
    String type = counter.printerType;

    showDialog(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Edit Station: ${counter.name}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Station Name'),
                ),
                const SizedBox(height: 16),
                const Text('Printer Configuration', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: addrCtrl,
                        decoration: InputDecoration(
                          labelText: 'IP Address', 
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.search, color: POSTheme.primary),
                            onPressed: () => _showScanPrintersDialog(addrCtrl),
                            tooltip: 'Scan for Printers',
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 1,
                      child: TextField(
                        controller: portCtrl,
                        decoration: const InputDecoration(labelText: 'Port', border: OutlineInputBorder()),
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: type,
                  decoration: const InputDecoration(labelText: 'Type', border: OutlineInputBorder()),
                  items: ['network', 'usb', 'bluetooth'].map((t) => DropdownMenuItem(value: t, child: Text(t.toUpperCase()))).toList(),
                  onChanged: (v) => setState(() => type = v!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c), child: const Text('CANCEL')),
            ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.isNotEmpty) {
                  try {
                    await ref.read(apiClientProvider).updateKitchenCounter(
                      counter.id!,
                      nameCtrl.text,
                      printerAddress: addrCtrl.text.isEmpty ? null : addrCtrl.text,
                      printerPort: int.tryParse(portCtrl.text) ?? 9100,
                      printerType: type,
                      icon: counter.icon,
                      color: counter.color,
                      isActive: counter.isActive,
                    );
                    ref.invalidate(kitchenCountersProvider);
                    if (mounted) Navigator.pop(c);
                  } catch (e) {
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                }
              },
              child: const Text('SAVE CHANGES'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteCounter(WidgetRef ref, KitchenCounter counter) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete Counter?'),
        content: Text('Are you sure you want to delete "${counter.name}"? This cannot be undone.'),
        actions: [
          // ... rest of the generic dialog ...
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('CANCEL')),
          TextButton(
            onPressed: () async {
              try {
                await ref.read(kitchenCountersProvider.notifier).removeCounter(counter.id!);
                if (mounted) Navigator.pop(c);
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
              }
            },
            child: const Text('DELETE', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog() {
    final currentPassCtrl = TextEditingController();
    final newPassCtrl = TextEditingController();
    final confirmPassCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Change Password', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: currentPassCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Current Password', border: OutlineInputBorder()),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: newPassCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'New Password', border: OutlineInputBorder()),
                validator: (v) => v!.length < 4 ? 'Min 4 characters' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: confirmPassCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Confirm New Password', border: OutlineInputBorder()),
                validator: (v) => v != newPassCtrl.text ? 'Passwords do not match' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: POSTheme.primary, foregroundColor: Colors.white),
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                try {
                  await ref.read(apiClientProvider).changePassword(
                    currentPassCtrl.text, 
                    newPassCtrl.text
                  );
                  if (mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Password changed successfully!'), backgroundColor: POSTheme.success)
                    );
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: POSTheme.danger)
                  );
                }
              }
            },
            child: const Text('Update Password'),
          ),
        ],
      ),
    );
  }

  void _showRolesManagementDialog() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const RoleManagementScreen()),
    );
  }

  void _showScanPrintersDialog(TextEditingController addrCtrl) {
    showDialog(
      context: context,
      builder: (context) {
        final List<String> found = [];
        bool scanning = true;
        bool hasStarted = false;

        return StatefulBuilder(
          builder: (context, setState) {
            Future<void> startScan() async {
              if (hasStarted) return;
              setState(() => hasStarted = true);

              // 1. Scan network
              PrinterService().discoverPrinters().then((stream) {
                stream.listen((ip) {
                  if (!found.contains(ip)) {
                    setState(() => found.add(ip));
                  }
                });
              }).catchError((e) => debugPrint('Network scan error: $e'));

              // 2. Scan Server-side (new)
              try {
                final serverPrinters = await ref.read(apiClientProvider).scanPrinters();
                for (var p in serverPrinters) {
                  final name = p['name'] ?? 'Unknown';
                  if (!found.contains(name)) {
                    setState(() => found.add(name));
                  }
                }
              } catch (e) {
                debugPrint('Server scan error: $e');
              }
              
              if (mounted) setState(() => scanning = false);
            }

            if (scanning && !hasStarted) {
              startScan();
            }

            return AlertDialog(
              title: const Text('Scanning for Printers...'),
              content: SizedBox(
                width: 350,
                height: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (scanning) const LinearProgressIndicator(),
                    const SizedBox(height: 16),
                    if (found.isEmpty && !scanning)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Text(
                          'No printers found in this subnet. Check if your printer is turned ON and on the same WiFi.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    Expanded(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: found.length,
                        itemBuilder: (ctx, idx) => ListTile(
                          leading: const Icon(Icons.print, color: POSTheme.primary),
                          title: Text(found[idx], style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: const Text('Generic ESC/POS Thermal Printer'),
                          trailing: const Icon(Icons.add_circle_outline, color: Colors.green),
                          onTap: () {
                            addrCtrl.text = found[idx];
                            Navigator.pop(context);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
                if (!scanning)
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        found.clear();
                        scanning = true;
                        hasStarted = false;
                      });
                      startScan();
                    },
                    child: const Text('RE-SCAN'),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}
