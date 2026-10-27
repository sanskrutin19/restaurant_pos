import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:typed_data';
import '../providers.dart';
import '../models/order_model.dart'; 
import '../models/settings_model.dart';
import 'widgets/download_report_button.dart';
import '../utils/time_utils.dart';


class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.refresh(orderSummaryProvider));
  }

  @override
  Widget build(BuildContext context) {
    final summaryAsync = ref.watch(orderSummaryProvider);
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(orderSummaryProvider);
          ref.invalidate(ordersProvider);
          ref.invalidate(menuItemsProvider);
        },
        child: CustomScrollView(
          slivers: [
            // Premium App Bar
            SliverAppBar(
              expandedHeight: 120,
              floating: false,
              pinned: true,
              backgroundColor: Colors.white,
              elevation: 0,
              flexibleSpace: FlexibleSpaceBar(
                title: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      settings.restaurantName,
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text(
                      'Dashboard Overview',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 14,
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                  ],
                ),
                titlePadding: const EdgeInsets.only(left: 24, bottom: 16),
              ),
              actions: [
                const Padding(
                  padding: EdgeInsets.only(top: 8.0),
                  child: DownloadReportButton(),
                ),
                IconButton(

                  icon: const Icon(Icons.refresh, color: Colors.black87),
                  onPressed: () {
                    ref.invalidate(orderSummaryProvider);
                    ref.invalidate(ordersProvider);
                  },
                ),
              ],
            ),

            // Content
            SliverPadding(
              padding: const EdgeInsets.all(24),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  summaryAsync.when(
                    data: (summary) => _buildDashboardContent(summary, settings),
                    loading: () => const Center(
                      child: Padding(
                        padding: EdgeInsets.all(100),
                        child: CircularProgressIndicator(),
                      ),
                    ),
                    error: (error, stack) => _buildErrorState(error),
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardContent(OrderSummary summary, AppSettings settings) {
    return Column(
      children: [
        // Stats Cards
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Total Revenue',
                '${settings.currencySymbol}${summary.totalRevenue.toStringAsFixed(2)}',
                Icons.attach_money_rounded,
                const Color(0xFF10B981),
                const Color(0xFFD1FAE5),
                '+12.5%',
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatCard(
                'Total Orders',
                '${summary.totalOrders}',
                Icons.receipt_long_rounded,
                const Color(0xFF3B82F6),
                const Color(0xFFDBEAFE),
                '+8.3%',
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatCard(
                'Avg Order Value',
                summary.totalOrders > 0
                    ? '${settings.currencySymbol}${(summary.totalRevenue / summary.totalOrders).toStringAsFixed(2)}'
                    : '${settings.currencySymbol}0.00',
                Icons.trending_up_rounded,
                const Color(0xFF8B5CF6),
                const Color(0xFFEDE9FE),
                '+5.2%',
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatCard(
                'Pending Orders',
                '${(summary.ordersByStatus['pending'] ?? 0) + (summary.ordersByStatus['Pending'] ?? 0) + (summary.ordersByStatus['created'] ?? 0) + (summary.ordersByStatus['Created'] ?? 0)}',
                Icons.pending_actions_rounded,
                const Color(0xFFF59E0B),
                const Color(0xFFFEF3C7),
                null,
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),

        // Charts Row
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sales Chart
            Expanded(
              flex: 2,
              child: _buildSalesChart(summary),
            ),
            const SizedBox(width: 24),
            
            // Order Status Pie Chart
            Expanded(
              child: _buildOrderStatusChart(summary),
            ),
          ],
        ),

        const SizedBox(height: 24),

        // Recent Orders
        _buildRecentOrders(),
      ],
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
    Color bgColor,
    String? trend,
  ) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              if (trend != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.trending_up, size: 14, color: Colors.green[700]),
                      const SizedBox(width: 4),
                      Text(
                        trend,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.green[700],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  num _getMaxRevenue(List<TrendPoint> trend) {
    if (trend.isEmpty) return 1000;
    double max = 0;
    for (var p in trend) {
      if (p.revenue > max) max = p.revenue;
    }
    return (max * 1.2).ceil(); // 20% cushion
  }

  Widget _buildSalesChart(OrderSummary summary) {
    final trend = summary.revenueTrend;
    final maxRevenue = _getMaxRevenue(trend).toDouble();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Sales Overview',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Last 7 Days',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: trend.isEmpty
                ? const Center(child: Text('Not enough data for trend yet', style: TextStyle(color: Colors.grey)))
                : LineChart(
                    LineChartData(
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: maxRevenue > 0 ? (maxRevenue / 5) : 1000,
                        getDrawingHorizontalLine: (value) {
                          return FlLine(
                            color: Colors.grey[200],
                            strokeWidth: 1,
                          );
                        },
                      ),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 45,
                            getTitlesWidget: (value, meta) {
                              if (value == 0) return const Text('');
                              return Text(
                                '₹${(value / 1000).toStringAsFixed(1)}k',
                                style: const TextStyle(fontSize: 10, color: Colors.grey),
                              );
                            },
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            interval: 1, // Fixes repeated labels
                            getTitlesWidget: (value, meta) {
                              int index = value.toInt();
                              if (index >= 0 && index < trend.length) {
                                // Extract day part from "YYYY-MM-DD"
                                String dateStr = trend[index].day;
                                if (dateStr.length >= 10) {
                                  try {
                                    final dt = TimeUtils.parseUtc(dateStr);
                                    final days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
                                    return Text(
                                      days[dt.weekday % 7],
                                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                                    );
                                  } catch (e) {
                                    return Text(
                                      dateStr.substring(8), // Just Day "DD" fallback
                                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                                    );
                                  }
                                }
                              }
                              return const Text('');
                            },
                          ),
                        ),
                        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      borderData: FlBorderData(show: false),
                      maxY: maxRevenue,
                      minY: 0,
                      lineBarsData: [
                        LineChartBarData(
                          spots: trend.asMap().entries.map((e) {
                            return FlSpot(e.key.toDouble(), e.value.revenue);
                          }).toList(),
                          isCurved: true,
                          color: const Color(0xFFFF6B35),
                          barWidth: 3,
                          dotData: FlDotData(
                            show: true,
                            getDotPainter: (spot, percent, barData, index) {
                              return FlDotCirclePainter(
                                radius: 4,
                                color: Colors.white,
                                strokeWidth: 2,
                                strokeColor: const Color(0xFFFF6B35),
                              );
                            },
                          ),
                          belowBarData: BarAreaData(
                            show: true,
                            color: const Color(0xFFFF6B35).withOpacity(0.1),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderStatusChart(OrderSummary summary) {
    final statusData = summary.ordersByStatus;
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Order Status',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 200,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 40,
                sections: [
                  PieChartSectionData(
                    value: ((statusData['pending'] ?? 0) + (statusData['Pending'] ?? 0) + (statusData['created'] ?? 0) + (statusData['Created'] ?? 0)).toDouble(),
                    title: 'Pending',
                    color: const Color(0xFFF59E0B),
                    radius: 50,
                    titleStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  PieChartSectionData(
                    value: ((statusData['preparing'] ?? 0) + (statusData['Preparing'] ?? 0)).toDouble(),
                    title: 'Preparing',
                    color: const Color(0xFF3B82F6),
                    radius: 50,
                    titleStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  PieChartSectionData(
                    value: ((statusData['ready'] ?? 0) + (statusData['Ready'] ?? 0)).toDouble(),
                    title: 'Ready',
                    color: const Color(0xFF10B981),
                    radius: 50,
                    titleStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  PieChartSectionData(
                    value: ((statusData['served'] ?? 0) + (statusData['Served'] ?? 0)).toDouble(),
                    title: 'Served',
                    color: const Color(0xFF8B5CF6),
                    radius: 50,
                    titleStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentOrders() {
    final ordersAsync = ref.watch(ordersProvider);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Recent Orders',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: () {},
                  child: const Text('View All'),
                ),
              ],
            ),
          ),
          ordersAsync.when(
            data: (orders) {
              if (orders.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(48),
                  child: Center(
                    child: Text(
                      'No orders yet',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                );
              }

              final recentOrders = orders.take(5).toList();
              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: recentOrders.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final order = recentOrders[index];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    leading: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: _getStatusColor(order.status).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          '#${order.id}',
                          style: TextStyle(
                            color: _getStatusColor(order.status),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    title: Text(
                      'Table ${order.tableNumber}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      '${order.items.length} items • ${_formatTime(order.createdAt)}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _getStatusColor(order.status).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        order.status.toUpperCase(),
                        style: TextStyle(
                          color: _getStatusColor(order.status),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                },
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.all(48),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => Padding(
              padding: const EdgeInsets.all(48),
              child: Center(
                child: Text(
                  'Error loading orders',
                  style: TextStyle(color: Colors.red[600]),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(Object error) {
    return Container(
      padding: const EdgeInsets.all(48),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
          const SizedBox(height: 16),
          const Text(
            'Failed to load dashboard',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            error.toString(),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              ref.invalidate(orderSummaryProvider);
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return const Color(0xFFF59E0B);
      case 'preparing':
        return const Color(0xFF3B82F6);
      case 'ready':
        return const Color(0xFF10B981);
      case 'served':
        return const Color(0xFF8B5CF6);
      default:
        return Colors.grey;
    }
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  Future<void> _showDownloadDialog(BuildContext context, WidgetRef ref) async {
    showDialog(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Export Report'),
        children: [
          SimpleDialogOption(
            onPressed: () {
              Navigator.pop(context);
              _downloadReport(context, ref, 'csv');
            },
            child: const Row(
              children: [
                Icon(Icons.table_chart_outlined, color: Colors.green),
                SizedBox(width: 12),
                Text('Download CSV (Excel)'),
              ],
            ),
          ),
          SimpleDialogOption(
            onPressed: () {
              Navigator.pop(context);
              _downloadReport(context, ref, 'pdf');
            },
            child: const Row(
              children: [
                Icon(Icons.picture_as_pdf_outlined, color: Colors.red),
                SizedBox(width: 12),
                Text('Download PDF (Professional)'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadReport(BuildContext context, WidgetRef ref, String type) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Preparing ${type.toUpperCase()} report...'), duration: const Duration(seconds: 1)),
      );

      final dateStr = DateTime.now().toIso8601String().split('T')[0];
      final Uint8List bytes = await ref.read(apiClientProvider).exportReport(date: dateStr, type: type);
      
      final downloadsDir = await getDownloadsDirectory();
      if (downloadsDir == null) throw Exception("Could not find downloads directory");

      final fileName = 'report_$dateStr.${type.toLowerCase()}';
      final file = File('${downloadsDir.path}/$fileName');
      await file.writeAsBytes(bytes);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Report saved to Downloads: $fileName'),
            backgroundColor: Colors.green,
            action: SnackBarAction(label: 'OK', textColor: Colors.white, onPressed: () {}),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}