import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import '../../services/report_service.dart';
import '../../utils/file_helper.dart';

class ReportDownloadDialog extends ConsumerStatefulWidget {
  const ReportDownloadDialog({super.key});

  @override
  ConsumerState<ReportDownloadDialog> createState() => _ReportDownloadDialogState();
}

class _ReportDownloadDialogState extends ConsumerState<ReportDownloadDialog> {
  DateTimeRange _dateRange = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 7)),
    end: DateTime.now(),
  );
  final TextEditingController _nameController = TextEditingController(text: "YOUR_RESTAURANT_NAME");
  bool _isLoading = false;
  String? _statusMessage;
  double? _progress;

  Future<void> _handleDownload(String type) async {
    setState(() {
      _isLoading = true;
      _statusMessage = "Preparing $type data...";
      _progress = 0.1;
    });

    try {
      final reportService = ref.read(reportServiceProvider);
      List<int> bytes;
      String extension;
      String filename;

      setState(() => _progress = 0.3);

      if (type == "Excel") {
        bytes = await reportService.downloadExcel(_dateRange.start, _dateRange.end, _nameController.text);
        extension = "xlsx";
      } else if (type == "PDF" || type == "Print") {
        bytes = await reportService.downloadPDF(_dateRange.start, _dateRange.end, _nameController.text);
        extension = "pdf";
      } else {
        bytes = await reportService.downloadCSV(_dateRange.start, _dateRange.end);
        extension = "csv";
      }

      if (type == "Print") {
        await Printing.layoutPdf(
          onLayout: (format) async => Uint8List.fromList(bytes),
          name: "Sales Report ${DateFormat('dd-MM-yyyy').format(_dateRange.start)}",
        );
        setState(() => _isLoading = false);
        return;
      }

      setState(() => _progress = 0.7);
      filename = "sales_report_${DateFormat('yyyyMMdd').format(_dateRange.start)}_${DateFormat('yyyyMMdd').format(_dateRange.end)}.$extension";
      
      final path = await FileHelper.saveDownloadedFile(bytes, filename);
      
      if (path != null) {
        setState(() {
          _progress = 1.0;
          _statusMessage = "Downloaded Successfully!";
        });
        if (mounted) _showPostDownloadActions(context, path, filename);
      } else {
        throw Exception("Could not save to Downloads folder. Please check permissions or if the file is open in another app.");
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showPostDownloadActions(BuildContext context, String path, String filename) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 64),
            const SizedBox(height: 16),
            Text(filename, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const Text("What would you like to do next?", style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      FileHelper.openFile(path);
                    },
                    icon: const Icon(Icons.open_in_new),
                    label: const Text("Open"),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      FileHelper.shareFile(path, "Sales Report: $filename");
                    },
                    icon: const Icon(Icons.share),
                    label: const Text("Share"),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB), foregroundColor: Colors.white),
                  ),
                ),
              ],
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(this.context);
              },
              child: const Text("Done"),
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Download Sales Report", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
            ],
          ),
          const Divider(),
          const SizedBox(height: 16),
          
          // Date Picker
          InkWell(
            onTap: () async {
              final picked = await showDateRangePicker(
                context: context,
                initialDateRange: _dateRange,
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
              );
              if (picked != null) setState(() => _dateRange = picked);
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today, color: Color(0xFF2563EB)),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Date Range", style: TextStyle(fontSize: 12, color: Colors.grey)),
                      Text(
                        "${DateFormat('dd/MM/yyyy').format(_dateRange.start)} - ${DateFormat('dd/MM/yyyy').format(_dateRange.end)}",
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Restaurant Name
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: "Restaurant Name (For Branding)",
              prefixIcon: const Icon(Icons.storefront, color: Color(0xFF2563EB)),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          
          const SizedBox(height: 24),
          
          if (_isLoading) ...[
            LinearProgressIndicator(value: _progress, backgroundColor: Colors.grey.shade200, color: const Color(0xFF2563EB)),
            const SizedBox(height: 8),
            Center(child: Text(_statusMessage ?? "Downloading...", style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.grey))),
          ] else ...[
            _ActionCard(
              title: "Print Preview",
              description: "View and print report directly",
              icon: Icons.print,
              color: const Color(0xFF2563EB),
              onTap: () => _handleDownload("Print"),
            ),
            const SizedBox(height: 12),
            _ActionCard(
              title: "Excel Report (Colorful)",
              description: "Styled XLSX with charts and colors",
              icon: Icons.table_chart,
              color: Colors.green,
              onTap: () => _handleDownload("Excel"),
            ),
            const SizedBox(height: 12),
            _ActionCard(
              title: "PDF Report (Professional)",
              description: "Print-ready formatted document",
              icon: Icons.picture_as_pdf,
              color: Colors.red,
              onTap: () => _handleDownload("PDF"),
            ),
            const SizedBox(height: 12),
            _ActionCard(
              title: "CSV (Simple)",
              description: "Plain text for custom processing",
              icon: Icons.description,
              color: Colors.blueGrey,
              onTap: () => _handleDownload("CSV"),
            ),
          ],
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade200),
          borderRadius: BorderRadius.circular(16),
          color: color.withOpacity(0.05),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(description, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }
}
