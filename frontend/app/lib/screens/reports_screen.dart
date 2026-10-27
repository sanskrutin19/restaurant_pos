import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:typed_data';
import '../core/pos_theme.dart';
import '../providers.dart';
import 'widgets/download_report_button.dart';


class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  Map<String, dynamic>? _dailyData;
  List<Map<String, dynamic>> _categoryData = [];
  Map<String, dynamic>? _taxData;
  List<Map<String, dynamic>> _paymentData = [];

  @override
  void initState() {
    super.initState();
    _fetchReports();
  }

  Future<void> _fetchReports() async {
    setState(() => _isLoading = true);
    final apiClient = ref.read(apiClientProvider);
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);

    try {
      final results = await Future.wait([
        apiClient.getDailyReport(date: dateStr),
        apiClient.getCategorySalesReport(date: dateStr),
        apiClient.getTaxSummaryReport(date: dateStr),
        apiClient.getPaymentMethodsReport(date: dateStr),
      ]);

      setState(() {
        _dailyData = results[0] as Map<String, dynamic>;
        _categoryData = results[1] as List<Map<String, dynamic>>;
        _taxData = results[2] as Map<String, dynamic>;
        _paymentData = results[3] as List<Map<String, dynamic>>;
      });
    } catch (e) {
      debugPrint('Error fetching reports: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }




  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text('Business Insights', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        actions: [
          const Padding(
            padding: EdgeInsets.only(top: 8.0),
            child: DownloadReportButton(),
          ),
          const SizedBox(width: 8),

          _buildDatePicker(),
          const SizedBox(width: 16),
        ],
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchReports,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSummaryCards(),
                    const SizedBox(height: 24),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 3, child: _buildCategoryPieChart()),
                        const SizedBox(width: 24),
                        Expanded(flex: 2, child: _buildTaxSummary()),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _buildPaymentBarChart()),
                        const SizedBox(width: 24),
                        Expanded(child: _buildOrderTypePieChart()),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _buildTopItemsList(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildOrderTypePieChart() {
    final data = (_dailyData?['order_type_breakdown'] as Map?) ?? {};
    if (data.isEmpty) return const SizedBox.shrink();

    final colors = {'dine_in': POSTheme.primary, 'takeaway': Colors.orange, 'delivery': Colors.purple};
    final labels = {'dine_in': 'Dine-in', 'takeaway': 'Takeaway', 'delivery': 'Delivery'};

    final sections = data.entries.map((e) {
      final type = e.key.toString();
      final count = (e.value as num).toDouble();
      return PieChartSectionData(
        color: colors[type] ?? Colors.grey,
        value: count,
        title: count.toInt().toString(),
        radius: 50,
        titleStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
      );
    }).toList();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: POSTheme.shadowSM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Orders by Type', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: Row(
              children: [
                Expanded(child: PieChart(PieChartData(sections: sections, centerSpaceRadius: 30))),
                const SizedBox(width: 16),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: data.keys.map((type) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Container(width: 10, height: 10, decoration: BoxDecoration(color: colors[type] ?? Colors.grey, shape: BoxShape.circle)),
                        const SizedBox(width: 8),
                        Text(labels[type] ?? type, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  )).toList(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDatePicker() {
    return InkWell(
      onTap: () async {
        final date = await showDatePicker(
          context: context, 
          initialDate: _selectedDate, 
          firstDate: DateTime(2020), 
          lastDate: DateTime.now()
        );
        if (date != null) {
          setState(() => _selectedDate = date);
          _fetchReports();
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: POSTheme.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: POSTheme.primary.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_rounded, size: 18, color: POSTheme.primary),
            const SizedBox(width: 12),
            Text(
              DateFormat('MMMM dd, yyyy').format(_selectedDate),
              style: GoogleFonts.inter(color: POSTheme.primary, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCards() {
    return Row(
      children: [
        _summaryCard('Total Revenue', '₹${(_dailyData?['total_revenue'] ?? 0).toStringAsFixed(2)}', Icons.payments_rounded, POSTheme.primary),
        _summaryCard('Total Orders', '${_dailyData?['total_orders'] ?? 0}', Icons.shopping_bag_rounded, POSTheme.success),
        _summaryCard('Avg Order Value', '₹${(_dailyData?['average_order_value'] ?? 0).toStringAsFixed(2)}', Icons.analytics_rounded, Colors.orange),
        _summaryCard('Cancelled', '${_dailyData?['cancelled_orders'] ?? 0}', Icons.cancel_rounded, POSTheme.danger),
      ],
    );
  }

  Widget _summaryCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(right: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: POSTheme.shadowSM,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.inter(color: POSTheme.textMuted, fontSize: 13, fontWeight: FontWeight.w500)),
                Text(value, style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w700, color: POSTheme.textDark)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryPieChart() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: POSTheme.shadowSM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Sales by Category', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 32),
          SizedBox(
            height: 300,
            child: Row(
              children: [
                Expanded(
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 4,
                      centerSpaceRadius: 40,
                      sections: _generateCategorySections(),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _generateCategoryLegend(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<PieChartSectionData> _generateCategorySections() {
    if (_categoryData.isEmpty) return [];
    final colors = [POSTheme.primary, POSTheme.success, Colors.orange, Colors.purple, Colors.cyan, Colors.pink];
    
    return List.generate(_categoryData.length, (i) {
      final data = _categoryData[i];
      return PieChartSectionData(
        color: colors[i % colors.length],
        value: (data['sales'] as num).toDouble(),
        title: '${(data['sales'] as num).toInt()}',
        radius: 60,
        titleStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
      );
    });
  }

  List<Widget> _generateCategoryLegend() {
    if (_categoryData.isEmpty) return [];
    final colors = [POSTheme.primary, POSTheme.success, Colors.orange, Colors.purple, Colors.cyan, Colors.pink];
    
    return List.generate(_categoryData.length, (i) {
      final data = _categoryData[i];
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Container(width: 12, height: 12, decoration: BoxDecoration(color: colors[i % colors.length], shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Text(data['category'], style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500)),
          ],
        ),
      );
    });
  }

  Widget _buildTaxSummary() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: POSTheme.shadowSM, border: Border(left: BorderSide(color: POSTheme.primary, width: 4))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Tax Summary (GST)', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 24),
          _reportRow('Subtotal', '₹${(_taxData?['subtotal'] ?? 0).toStringAsFixed(2)}', isBold: false),
          const Divider(height: 24),
          _reportRow('CGST (${(ref.watch(settingsProvider).taxRate / 2).toStringAsFixed(1)}%)', '₹${(_taxData?['cgst'] ?? 0).toStringAsFixed(2)}'),
          _reportRow('SGST (${(ref.watch(settingsProvider).taxRate / 2).toStringAsFixed(1)}%)', '₹${(_taxData?['sgst'] ?? 0).toStringAsFixed(2)}'),
          const Divider(height: 24),
          _reportRow('Total Collection', '₹${(_taxData?['grand_total'] ?? 0).toStringAsFixed(2)}', isBold: true, color: POSTheme.primary),
        ],
      ),
    );
  }

  Widget _reportRow(String label, String value, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 14, color: isBold ? POSTheme.textDark : POSTheme.textMuted, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(value, style: GoogleFonts.inter(fontSize: 16, fontWeight: isBold ? FontWeight.w800 : FontWeight.w600, color: color ?? POSTheme.textDark)),
        ],
      ),
    );
  }

  Widget _buildPaymentBarChart() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: POSTheme.shadowSM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Payment Mode Distribution', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 32),
          SizedBox(
            height: 250,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: _calculateMaxPayment(),
                barTouchData: BarTouchData(enabled: true),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, getTitlesWidget: _getPaymentLabel)),
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                gridData: const FlGridData(show: false),
                barGroups: _generatePaymentGroups(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  double _calculateMaxPayment() {
    if (_paymentData.isEmpty) return 100;
    return (_paymentData.fold(0.0, (max, p) => (p['amount'] as num) > max ? (p['amount'] as num).toDouble() : max) * 1.2);
  }

  Widget _getPaymentLabel(double value, TitleMeta meta) {
    if (value.toInt() >= _paymentData.length) return const Text('');
    return SideTitleWidget(
      meta: meta,
      child: Text(_paymentData[value.toInt()]['method'].toUpperCase(), style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: POSTheme.textMuted)),
    );
  }

  List<BarChartGroupData> _generatePaymentGroups() {
    return List.generate(_paymentData.length, (i) {
      return BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: (_paymentData[i]['amount'] as num).toDouble(),
            color: POSTheme.primary,
            width: 30,
            borderRadius: BorderRadius.circular(6),
            backDrawRodData: BackgroundBarChartRodData(show: true, toY: _calculateMaxPayment(), color: Colors.grey[100]),
          ),
        ],
      );
    });
  }

  Widget _buildTopItemsList() {
    final topItems = (_dailyData?['top_selling_items'] as List?) ?? [];
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: POSTheme.shadowSM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Top Selling Items', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 16),
          if (topItems.isEmpty) 
            const Center(child: Text('No data available'))
          else
            ...topItems.map((item) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(width: 36, height: 36, decoration: BoxDecoration(color: POSTheme.primary.withOpacity(0.1), shape: BoxShape.circle), child: Center(child: Text('${topItems.indexOf(item) + 1}', style: const TextStyle(color: POSTheme.primary, fontWeight: FontWeight.bold)))),
              title: Text(item['name'] ?? 'Item #${item['item_id']}', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14)),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: POSTheme.success.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                child: Text('${item['quantity']} sold', style: GoogleFonts.inter(color: POSTheme.success, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            )),
        ],
      ),
    );
  }
}
