import 'dart:async';
import 'dart:math';

enum PaymentType { upi, card }

class PaymentGatewayMock {
  static Future<bool> processPayment(double amount, PaymentType type) async {
    // Simulate network delay
    await Future.delayed(const Duration(seconds: 2));
    
    // 90% success rate for mock
    return Random().nextDouble() < 0.9;
  }
  
  static String generateUpiQR(double amount) {
    // In a real app, this would be a dynamic UPI URL
    return "upi://pay?pa=restaurant@bank&pn=PremiumRestaurant&am=$amount&cu=INR";
  }
}
