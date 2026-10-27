import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../providers.dart';
import '../core/pos_theme.dart';
import '../utils/time_utils.dart';

class CRMScreen extends ConsumerStatefulWidget {
  const CRMScreen({super.key});

  @override
  ConsumerState<CRMScreen> createState() => _CRMScreenState();
}

class _CRMScreenState extends ConsumerState<CRMScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  Map<String, dynamic>? _selectedCustomer;
  List<Map<String, dynamic>> _orderHistory = [];
  bool _isLoadingHistory = false;

  Future<void> _performSearch(String query) async {
    if (query.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }

    setState(() => _isSearching = true);
    try {
      final results = await ref.read(apiClientProvider).searchCustomers(query);
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    } catch (e) {
      setState(() => _isSearching = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Search error: $e')));
      }
    }
  }

  Future<void> _selectCustomer(Map<String, dynamic> customer) async {
    setState(() {
      _selectedCustomer = customer;
      _isLoadingHistory = true;
      _orderHistory = [];
    });

    try {
      final history = await ref.read(apiClientProvider).getCustomerHistory(customer['phone']);
      setState(() {
        _orderHistory = history;
        _isLoadingHistory = false;
      });
    } catch (e) {
      setState(() => _isLoadingHistory = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('History error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: POSTheme.background,
      appBar: AppBar(
        title: Text('Enhanced CRM', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
        elevation: 1,
        backgroundColor: Colors.white,
        foregroundColor: POSTheme.textDark,
      ),
      body: Row(
        children: [
          // Left Sidebar: Customer Search
          Container(
            width: 350,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(right: BorderSide(color: POSTheme.border)),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: TextField(
                    controller: _searchController,
                    onChanged: _performSearch,
                    decoration: InputDecoration(
                      hintText: 'Search by Name or Phone...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: POSTheme.surface,
                    ),
                  ),
                ),
                if (_isSearching)
                  const LinearProgressIndicator(),
                Expanded(
                  child: _searchResults.isEmpty && _searchController.text.isNotEmpty
                      ? Center(child: Text('No customers found', style: GoogleFonts.inter(color: POSTheme.textMuted)))
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _searchResults.length,
                          separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey[100]),
                          itemBuilder: (context, index) {
                            final c = _searchResults[index];
                            final bool isSelected = _selectedCustomer?['id'] == c['id'];
                            return ListTile(
                              selected: isSelected,
                              selectedTileColor: POSTheme.primary.withOpacity(0.05),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              title: Text(c['name'] ?? 'Guest', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                              subtitle: Text(c['phone'], style: GoogleFonts.inter(fontSize: 12)),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text('${c['points']} pts', style: GoogleFonts.inter(color: POSTheme.primary, fontWeight: FontWeight.w600, fontSize: 12)),
                                  Text('${c['visits_count']} visits', style: GoogleFonts.inter(color: POSTheme.textMuted, fontSize: 10)),
                                ],
                              ),
                              onTap: () => _selectCustomer(c),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),

          // Main Content: Detailed History
          Expanded(
            child: _selectedCustomer == null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.person_search_rounded, size: 64, color: POSTheme.textMuted.withOpacity(0.3)),
                        const SizedBox(height: 16),
                        Text('Select a customer to view history', style: GoogleFonts.inter(color: POSTheme.textMuted, fontSize: 18)),
                      ],
                    ),
                  )
                : _buildCustomerDetails(),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerDetails() {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Customer Profile Header
          Row(
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: POSTheme.primary.withOpacity(0.1),
                child: Text(_selectedCustomer!['name']?[0].toUpperCase() ?? 'G',
                    style: GoogleFonts.inter(color: POSTheme.primary, fontSize: 32, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_selectedCustomer!['name'] ?? 'Guest Customer',
                        style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.bold, color: POSTheme.textDark)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.phone, size: 16, color: POSTheme.textMuted),
                        const SizedBox(width: 8),
                        Text(_selectedCustomer!['phone'], style: GoogleFonts.inter(color: POSTheme.textMuted, fontSize: 16)),
                        if (_selectedCustomer!['email'] != null) ...[
                          const SizedBox(width: 24),
                          const Icon(Icons.email, size: 16, color: POSTheme.textMuted),
                          const SizedBox(width: 8),
                          Text(_selectedCustomer!['email'], style: GoogleFonts.inter(color: POSTheme.textMuted, fontSize: 16)),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              _statCard('Total Loyalty Points', '${_selectedCustomer!['points']}', POSTheme.primary),
              const SizedBox(width: 16),
              _statCard('Total Visits', '${_selectedCustomer!['visits_count']}', POSTheme.success),
            ],
          ),

          const SizedBox(height: 48),

          Text('Order History', style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.bold, color: POSTheme.textDark)),
          const SizedBox(height: 16),

          Expanded(
            child: _isLoadingHistory
                ? const Center(child: CircularProgressIndicator())
                : _orderHistory.isEmpty
                    ? Center(child: Text('No orders found for this customer.', style: GoogleFonts.inter(color: POSTheme.textMuted)))
                    : ListView.separated(
                        itemCount: _orderHistory.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final order = _orderHistory[index];
                          final date = TimeUtils.parseUtc(order['created_at']).toLocal();
                          return _buildOrderHistoryItem(order, date);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: POSTheme.border),
        boxShadow: POSTheme.shadowSM,
      ),
      child: Column(
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 12, color: POSTheme.textSecondary)),
          const SizedBox(height: 4),
          Text(value, style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _buildOrderHistoryItem(Map<String, dynamic> order, DateTime date) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: POSTheme.border),
      ),
      child: ExpansionTile(
        title: Row(
          children: [
            POSTheme.statusBadge(order['status'].toUpperCase(), _getStatusColor(order['status'])),
            const SizedBox(width: 12),
            Text('Order #${order['id']}', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
            const Spacer(),
            Text(DateFormat('MMM dd, yyyy | hh:mm a').format(date), style: GoogleFonts.inter(fontSize: 13, color: POSTheme.textSecondary)),
            const SizedBox(width: 24),
            Text('₹${order['total_amount'].toStringAsFixed(2)}', style: GoogleFonts.inter(fontWeight: FontWeight.w800, color: POSTheme.primary, fontSize: 16)),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(),
                const SizedBox(height: 8),
                ...?order['items']?.map<Widget>((item) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Text('${item['quantity']}x ', style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: POSTheme.primary)),
                          Expanded(child: Text(item['name'] ?? 'Unknown Item', style: GoogleFonts.inter())),
                          Text('₹${(item['price'] * item['quantity']).toStringAsFixed(2)}', style: GoogleFonts.inter(color: POSTheme.textSecondary)),
                        ],
                      ),
                    )),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text('Payment: ${order['payment_method'] ?? 'Unknown'}', style: GoogleFonts.inter(fontSize: 12, fontStyle: FontStyle.italic)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'paid':
      case 'completed': return POSTheme.success;
      case 'pending': return POSTheme.warning;
      case 'cancelled': return POSTheme.danger;
      default: return POSTheme.textMuted;
    }
  }
}
