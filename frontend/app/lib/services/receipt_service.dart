import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/order_model.dart';
import '../models/settings_model.dart';
import '../models/cart_model.dart';

class ReceiptService {
  static Future<void> printReceipt({
    required AppSettings settings,
    required List<CartItem> items,
    required double total,
    required int tableNumber,
    required String paymentMethod,
    double? amountReceived,
    double? change,
  }) async {
    final doc = pw.Document();

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                child: pw.Text(settings.restaurantName, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
              ),
              pw.SizedBox(height: 10),
              pw.Text('Table: $tableNumber'),
              pw.Text('Date: ${DateTime.now().toString().split('.')[0]}'),
              pw.Divider(),
              pw.SizedBox(height: 5),
              ...items.map((item) => pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('${item.quantity}x ${item.menuItem.name}'),
                      pw.Text('${settings.currencySymbol}${(item.menuItem.price * item.quantity).toStringAsFixed(2)}'),
                    ],
                  )),
              pw.Divider(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Subtotal:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  pw.Text('${settings.currencySymbol}${(total / (1 + settings.taxRate / 100)).toStringAsFixed(2)}'),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Tax (${settings.taxRate}%):'),
                  pw.Text('${settings.currencySymbol}${(total - (total / (1 + settings.taxRate / 100))).toStringAsFixed(2)}'),
                ],
              ),
              pw.Divider(thickness: 2),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('TOTAL:', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                  pw.Text('${settings.currencySymbol}${total.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                ],
              ),
              pw.SizedBox(height: 10),
              pw.Text('Paid via: $paymentMethod'),
              if (amountReceived != null) pw.Text('Received: ${settings.currencySymbol}${amountReceived.toStringAsFixed(2)}'),
              if (change != null) pw.Text('Change: ${settings.currencySymbol}${change.toStringAsFixed(2)}'),
              pw.SizedBox(height: 20),
              pw.Center(child: pw.Text('Thank you! Visit again.')),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => doc.save());
  }
}
