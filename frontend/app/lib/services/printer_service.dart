import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:network_info_plus/network_info_plus.dart';
import '../models/order_model.dart';
import '../models/bill_model.dart';
import '../models/system_model.dart';
import '../models/menu_model.dart';
import 'api_client.dart';

class PrinterService {
  static final PrinterService _instance = PrinterService._internal();
  factory PrinterService() => _instance;
  PrinterService._internal();

  ApiClient? _apiClient;
  void init(ApiClient apiClient) => _apiClient = apiClient;

  /// Discover network printers on a subnet using manual socket scanning
  Future<Stream<String>> discoverPrinters() async {
    final info = NetworkInfo();
    String? ip = await info.getWifiIP();
    if (ip == null) throw Exception('Could not get local IP address. Are you on WiFi?');
    
    final String subnet = ip.substring(0, ip.lastIndexOf('.'));
    const int port = 9100;
    
    final controller = StreamController<String>();
    
    int scanned = 0;
    for (int i = 1; i < 255; i++) {
        final target = '$subnet.$i';
        Socket.connect(target, port, timeout: const Duration(seconds: 1)).then((s) {
            controller.add(target);
            s.close();
        }).catchError((_) {
            // Ignore refused/timed out
        }).whenComplete(() {
            scanned++;
            if (scanned >= 254 && !controller.isClosed) {
                controller.close();
            }
        });
    }
    
    return controller.stream;
  }

  /// Scan for printers on both local network and via the backend server (Windows printers)
  Future<List<String>> scanAllPrinters() async {
    final List<String> allPrinters = [];

    // 1. Network Discovery (Concurrent)
    try {
       final stream = await discoverPrinters();
       // Only wait 3 seconds for network discovery to keep UI snappy
       await for (final ip in stream.timeout(const Duration(seconds: 3), onTimeout: (sink) => sink.close())) {
          if (!allPrinters.contains(ip)) allPrinters.add(ip);
       }
    } catch (e) {
       debugPrint('Network scan failed: $e');
    }

    // 2. Server-side Discovery
    if (_apiClient != null) {
       try {
          final serverPrinters = await _apiClient!.scanPrinters();
          for (var p in serverPrinters) {
             final name = p['name'] ?? 'Unknown';
             if (!allPrinters.contains(name)) allPrinters.add(name);
          }
       } catch (e) {
          debugPrint('Server scan failed: $e');
       }
    }

    return allPrinters;
  }

  // ═══════════════════════════════════════════════════════════════════
  //  KOT PRINTING — With version, action label, modifiers & room info
  // ═══════════════════════════════════════════════════════════════════

  /// Prints KOT to their respective counters
  Future<void> printKOT({
    required Order order,
    required List<OrderItem> items,
    required List<KitchenCounter> counters,
    bool isReprint = false,
    int? kotVersion,
    String? kotAction,
  }) async {
    // 1. Group items by counter ID
    final Map<int?, List<OrderItem>> grouped = {};
    for (var item in items) {
      grouped.putIfAbsent(item.kitchenCounterId, () => []).add(item);
    }

    // 2. Iterate through counters and print
    for (final counterId in grouped.keys) {
      final counter = counters.firstWhere(
        (c) => c.id == counterId,
        orElse: () => KitchenCounter(name: 'General', id: null),
      );

      if (counter.printerAddress == null || counter.printerAddress!.isEmpty) {
          debugPrint('No printer configured for station: ${counter.name}');
          continue;
      }

      final ticketBytes = await _generateKOTBytes(
        order: order,
        items: grouped[counterId]!,
        counterName: counter.name,
        isReprint: isReprint,
        kotVersion: kotVersion,
        kotAction: kotAction,
      );

      await _directPrint(
        address: counter.printerAddress!,
        port: counter.printerPort,
        type: counter.printerType,
        bytes: ticketBytes,
      );
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  //  BILL PRINTING — With split tax, discount, CGST/SGST, bill number
  // ═══════════════════════════════════════════════════════════════════

  /// Prints Final Bill with full split tax/discount breakdown
  Future<void> printBill({
    required Order order,
    required String printerAddress,
    int port = 9100,
    String type = 'network',
    required String restaurantName,
    Map<String, String>? headerInfo,
    Bill? bill,
    String? footerText,
    String taxLabel = 'GST',
  }) async {
    final ticketBytes = await _generateBillBytes(
      order: order,
      restaurantName: restaurantName,
      headerInfo: headerInfo,
      bill: bill,
      footerText: footerText,
      taxLabel: taxLabel,
    );

    await _directPrint(
      address: printerAddress,
      port: port,
      type: type,
      bytes: ticketBytes,
    );
  }

  /// Core logic to send bytes to printer
  Future<void> _directPrint({
    required String address,
    required int port,
    required String type,
    required List<int> bytes,
  }) async {
    if (type == 'network') {
      // Check if address is an IP or a hostname
      final isIp = RegExp(r'^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$').hasMatch(address);

      if (isIp) {
        try {
          final socket = await Socket.connect(address, port, timeout: const Duration(seconds: 5));
          socket.add(bytes);
          await socket.flush();
          await Future.delayed(const Duration(milliseconds: 500));
          await socket.close();
        } catch (e) {
          throw Exception('Failed to connect to Network Printer at $address: $e');
        }
      } else {
        // If not an IP, it's likely a Windows network printer name or a printer on the server
        if (_apiClient == null) throw Exception('Server-side printing requires ApiClient initialization.');
        final base64Bytes = base64Encode(bytes);
        await _apiClient!.rawPrint(address, base64Bytes);
      }
    } else if (type == 'usb' || type == 'local') {
      if (_apiClient == null) throw Exception('Server-side printing requires ApiClient initialization.');
      
      final base64Bytes = base64Encode(bytes);
      await _apiClient!.rawPrint(address, base64Bytes);
    } else {
      throw UnimplementedError('Printer type $type not yet supported on this platform.');
    }
  }

  // ─────────────────────────────────────────────────────────────────
  //  KOT Byte Generation
  // ─────────────────────────────────────────────────────────────────

  Future<List<int>> _generateKOTBytes({
    required Order order,
    required List<OrderItem> items,
    required String counterName,
    bool isReprint = false,
    int? kotVersion,
    String? kotAction,
  }) async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm80, profile);
    List<int> bytes = [];

    // ── Header: Station name (large) ──
    bytes += generator.setStyles(const PosStyles(
      align: PosAlign.center, bold: true,
      height: PosTextSize.size2, width: PosTextSize.size2,
    ));
    bytes += generator.text(counterName);

    // ── Version & Action Banner ──
    if (kotVersion != null && kotVersion > 1) {
      final actionLabel = _kotActionLabel(kotAction);
      bytes += generator.setStyles(const PosStyles(
        align: PosAlign.center, bold: true,
        height: PosTextSize.size1, width: PosTextSize.size2,
      ));
      bytes += generator.text('*** $actionLabel v$kotVersion ***');
    }

    if (isReprint) {
      bytes += generator.setStyles(const PosStyles(align: PosAlign.center, bold: true));
      bytes += generator.text('*** REPRINT ***');
    }

    bytes += generator.feed(1);

    // ── Order metadata ──
    bytes += generator.setStyles(const PosStyles(align: PosAlign.left, bold: true));
    bytes += generator.text('Order: #${order.id}');

    // Table or Room
    if (order.roomNumber != null && order.roomNumber!.isNotEmpty) {
      bytes += generator.text('Room: ${order.roomNumber}');
      if (order.guestName != null && order.guestName!.isNotEmpty) {
        bytes += generator.text('Guest: ${order.guestName}');
      }
    } else {
      bytes += generator.text('Table: ${order.tableNumber}');
    }

    if (order.paxCount > 1) {
      bytes += generator.text('Pax: ${order.paxCount}');
    }

    // Customer
    if (order.customerName != null && order.customerName!.isNotEmpty) {
      bytes += generator.text('Customer: ${order.customerName}');
    }

    // Order type badge
    if (order.orderType != 'dine_in') {
      bytes += generator.setStyles(const PosStyles(align: PosAlign.left, bold: true));
      bytes += generator.text('Type: ${_prettyOrderType(order.orderType)}');
    }

    bytes += generator.setStyles(const PosStyles(align: PosAlign.left));
    bytes += generator.text('Time: ${_formatTime(DateTime.now())}');
    bytes += generator.hr();

    // ── Items table header ──
    bytes += generator.row([
      PosColumn(text: 'Item', width: 9, styles: const PosStyles(bold: true)),
      PosColumn(text: 'Qty', width: 3, styles: const PosStyles(bold: true, align: PosAlign.right)),
    ]);
    bytes += generator.hr();

    // ── Items ──
    for (var item in items) {
      // Skip cancelled items UNLESS we are specifically printing a cancellation notice
      bool isCancelled = item.kotStatus.toLowerCase() == 'cancelled';
      if (isCancelled && kotAction?.toLowerCase() != 'cancelled') continue;

      final prefix = isCancelled ? '[CANCELLED] ' : '';

      bytes += generator.row([
        PosColumn(text: '$prefix${item.name}', width: 9),
        PosColumn(text: item.quantity.toString(), width: 3, styles: const PosStyles(align: PosAlign.right)),
      ]);
      
      // Modifiers
      for (var mod in item.modifiers) {
        bytes += generator.setStyles(const PosStyles(align: PosAlign.left));
        bytes += generator.text('  + ${mod.name}${mod.priceDelta != 0 ? " (+${mod.priceDelta.toStringAsFixed(0)})" : ""}');
      }
      
      // Notes
      if (item.notes != null && item.notes!.isNotEmpty) {
        bytes += generator.setStyles(const PosStyles(align: PosAlign.left, bold: true));
        bytes += generator.text('  NOTE: ${item.notes}');
      }
    }

    bytes += generator.hr();

    // ── Total items count ──
    final totalQty = items
        .where((i) {
          bool isCancelled = i.kotStatus.toLowerCase() == 'cancelled';
          return !isCancelled || kotAction?.toLowerCase() == 'cancelled';
        })
        .fold<int>(0, (sum, i) => sum + i.quantity);
    bytes += generator.setStyles(const PosStyles(align: PosAlign.center));
    bytes += generator.text('Total Items: $totalQty');

    bytes += generator.feed(3);
    bytes += generator.cut();

    return bytes;
  }

  // ─────────────────────────────────────────────────────────────────
  //  Bill Byte Generation — Full split tax/discount breakdown
  // ─────────────────────────────────────────────────────────────────

  Future<List<int>> _generateBillBytes({
    required Order order,
    required String restaurantName,
    Map<String, String>? headerInfo,
    Bill? bill,
    String? footerText,
    String taxLabel = 'GST',
  }) async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm80, profile);
    List<int> bytes = [];

    // ══════════════ HEADER ══════════════
    bytes += generator.setStyles(const PosStyles(
      align: PosAlign.center, bold: true,
      height: PosTextSize.size2,
    ));
    bytes += generator.text(restaurantName);
    
    if (headerInfo != null) {
      bytes += generator.setStyles(const PosStyles(align: PosAlign.center));
      if (headerInfo['address'] != null && headerInfo['address']!.isNotEmpty) {
        bytes += generator.text(headerInfo['address']!);
      }
      if (headerInfo['phone'] != null && headerInfo['phone']!.isNotEmpty) {
        bytes += generator.text('Tel: ${headerInfo['phone']}');
      }
      if (headerInfo['gstin'] != null && headerInfo['gstin']!.isNotEmpty) {
        bytes += generator.text('GSTIN: ${headerInfo['gstin']}');
      }
      if (headerInfo['fssai'] != null && headerInfo['fssai']!.isNotEmpty) {
        bytes += generator.text('FSSAI: ${headerInfo['fssai']}');
      }
    }
    
    bytes += generator.feed(1);

    // Bill number & date
    bytes += generator.setStyles(const PosStyles(align: PosAlign.left));
    final billNo = bill?.billNumber ?? '#${order.id}';
    bytes += generator.text('Bill No: $billNo');
    bytes += generator.text('Date: ${_formatDateTime(DateTime.now())}');

    // Table or Room
    if (order.roomNumber != null && order.roomNumber!.isNotEmpty) {
      bytes += generator.text('Room: ${order.roomNumber}');
      if (order.guestName != null && order.guestName!.isNotEmpty) {
        bytes += generator.text('Guest: ${order.guestName}');
      }
    } else if (order.tableNumber > 0) {
      bytes += generator.text('Table: ${order.tableNumber}');
    }

    // Customer info — Always print customer details on bill
    final custName = order.customerName;
    final custPhone = order.customerMobile ?? order.customerPhone;
    
    if (custName != null && custName.isNotEmpty) {
      bytes += generator.text('Customer: $custName');
    }
    if (custPhone != null && custPhone.isNotEmpty) {
      bytes += generator.text('Phone: $custPhone');
    }
    // Walk-in fallback when no customer info present
    if ((custName == null || custName.isEmpty) &&
        (custPhone == null || custPhone.isEmpty)) {
      bytes += generator.text('Customer: Walk-in');
    }

    // Order type
    if (order.orderType != 'dine_in') {
      bytes += generator.text('Type: ${_prettyOrderType(order.orderType)}');
    }

    if (order.paxCount > 1) {
      bytes += generator.text('Pax: ${order.paxCount}');
    }

    // Reprint badge
    if (bill?.isReprint == true) {
      bytes += generator.setStyles(const PosStyles(align: PosAlign.center, bold: true));
      bytes += generator.text('*** REPRINT ***');
    }

    bytes += generator.hr(ch: '=');

    // ══════════════ ITEMS ══════════════
    bytes += generator.row([
      PosColumn(text: 'Item', width: 6, styles: const PosStyles(bold: true)),
      PosColumn(text: 'Qty', width: 1, styles: const PosStyles(bold: true, align: PosAlign.right)),
      PosColumn(text: 'Rate', width: 2, styles: const PosStyles(bold: true, align: PosAlign.right)),
      PosColumn(text: 'Amt', width: 3, styles: const PosStyles(bold: true, align: PosAlign.right)),
    ]);
    bytes += generator.hr();

    // Filter out cancelled items
    final activeItems = order.items
        .where((i) => i.kotStatus.toLowerCase() != 'cancelled')
        .toList();

    for (var item in activeItems) {
      final itemTotal = item.price * item.quantity;
      bytes += generator.row([
        PosColumn(text: item.name, width: 6),
        PosColumn(text: '${item.quantity}', width: 1, styles: const PosStyles(align: PosAlign.right)),
        PosColumn(text: item.price.toStringAsFixed(0), width: 2, styles: const PosStyles(align: PosAlign.right)),
        PosColumn(text: itemTotal.toStringAsFixed(2), width: 3, styles: const PosStyles(align: PosAlign.right)),
      ]);

      // Modifiers
      for (var mod in item.modifiers) {
        bytes += generator.row([
          PosColumn(text: '  + ${mod.name}', width: 9),
          PosColumn(text: '+${mod.priceDelta.toStringAsFixed(0)}', width: 3, styles: const PosStyles(align: PosAlign.right)),
        ]);
      }

      // Tax badge inline (only if non-standard)
      if (!item.taxEnabled) {
        bytes += generator.text('    [No Tax]');
      }
      if (!item.allowDiscount) {
        bytes += generator.text('    [No Discount]');
      }
    }

    bytes += generator.hr(ch: '=');

    // ══════════════ TOTALS SECTION ══════════════
    if (bill != null) {
      // ── Full breakdown from Bill object ──
      _addTotalRow(bytes, generator, 'Subtotal', bill.subtotal);

      // Discount
      if (bill.discount > 0) {
        _addTotalRow(bytes, generator, 'Discount', -bill.discount);
        if (bill.discountNote != null && bill.discountNote!.isNotEmpty) {
          bytes += generator.setStyles(const PosStyles(align: PosAlign.left));
          bytes += generator.text('  (${bill.discountNote})');
        }
      }

      // Tax breakdown
      if (bill.cgst > 0 || bill.sgst > 0) {
        _addTotalRow(bytes, generator, 'C$taxLabel', bill.cgst);
        _addTotalRow(bytes, generator, 'S$taxLabel', bill.sgst);
      } else if (bill.tax > 0) {
        _addTotalRow(bytes, generator, taxLabel, bill.tax);
      }

      // Room service charge
      if (order.roomServiceCharge > 0) {
        _addTotalRow(bytes, generator, 'Room Svc Charge', order.roomServiceCharge);
      }

      // Round off
      if (bill.roundOff != 0) {
        _addTotalRow(bytes, generator, 'Round Off', bill.roundOff);
      }

      bytes += generator.hr();

      // Grand total
      bytes += generator.setStyles(const PosStyles(bold: true));
      bytes += generator.row([
        PosColumn(text: 'GRAND TOTAL', width: 7, styles: const PosStyles(bold: true, height: PosTextSize.size2)),
        PosColumn(
          text: bill.totalAmount.toStringAsFixed(2),
          width: 5,
          styles: const PosStyles(bold: true, align: PosAlign.right, height: PosTextSize.size2),
        ),
      ]);

    } else {
      // ── Fallback: simple total from order ──
      final subtotal = activeItems.fold<double>(0.0, (sum, i) => sum + (i.price * i.quantity));

      _addTotalRow(bytes, generator, 'Subtotal', subtotal);

      bytes += generator.hr();
      bytes += generator.setStyles(const PosStyles(bold: true));
      bytes += generator.row([
        PosColumn(text: 'TOTAL', width: 7, styles: const PosStyles(bold: true, height: PosTextSize.size2)),
        PosColumn(
          text: subtotal.toStringAsFixed(2),
          width: 5,
          styles: const PosStyles(bold: true, align: PosAlign.right, height: PosTextSize.size2),
        ),
      ]);
    }

    bytes += generator.feed(1);

    // ══════════════ FOOTER ══════════════
    bytes += generator.setStyles(const PosStyles(align: PosAlign.center));
    
    if (footerText != null && footerText.isNotEmpty) {
      bytes += generator.text(footerText);
    } else {
      bytes += generator.text('Thank you! Visit Again.');
    }

    bytes += generator.feed(3);
    bytes += generator.cut();

    return bytes;
  }

  // ─────────────────────────────────────────────────────────────────
  //  Helpers
  // ─────────────────────────────────────────────────────────────────

  /// Adds a line like:  Label ............ Amount
  void _addTotalRow(List<int> bytes, Generator gen, String label, double amount) {
    final sign = amount < 0 ? '-' : '';
    final absAmount = amount.abs();
    bytes.addAll(gen.row([
      PosColumn(text: label, width: 7),
      PosColumn(
        text: '$sign${absAmount.toStringAsFixed(2)}',
        width: 5,
        styles: const PosStyles(align: PosAlign.right),
      ),
    ]));
  }

  String _kotActionLabel(String? action) {
    switch (action?.toLowerCase()) {
      case 'modified':
        return 'MODIFIED KOT';
      case 'cancelled':
        return 'CANCELLED KOT';
      case 'added':
        return 'ADDED ITEMS';
      case 'removed':
        return 'REMOVED ITEMS';
      default:
        return 'UPDATED KOT';
    }
  }

  String _prettyOrderType(String type) {
    switch (type.toLowerCase()) {
      case 'dine_in':
        return 'Dine In';
      case 'takeaway':
        return 'Takeaway';
      case 'delivery':
        return 'Delivery';
      case 'room_service':
        return 'Room Service';
      default:
        return type;
    }
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/'
        '${dt.month.toString().padLeft(2, '0')}/'
        '${dt.year} '
        '${_formatTime(dt)}';
  }
}
