import 'package:hive/hive.dart';
import 'package:flutter/foundation.dart';

class AppSettings {
  final String restaurantName;
  final String apiBaseUrl;
  final double taxRate;
  final int totalTables;
  final String currencySymbol;
  final bool kitchenSoundEnabled;
  final String counterId;
  final Map<String, dynamic> tablePositions;
  final String restaurantAddress;
  final String restaurantPhone;
  final String restaurantEmail;
  final String gstin;
  final String fssaiLicense;
  final String taxLabel;
  final String billFooter;
  final String? billPrinterAddress;
  final int billPrinterPort;
  final String billPrinterType;
  final bool autoPrintKOT;

  AppSettings({
    this.restaurantName = 'My Restaurant',
    this.apiBaseUrl = 'http://127.0.0.1:8000',
    this.taxRate = 5.0,
    this.totalTables = 20,
    this.currencySymbol = '₹',
    this.kitchenSoundEnabled = true,
    this.counterId = 'POS-1',
    this.tablePositions = const {},
    this.restaurantAddress = '',
    this.restaurantPhone = '',
    this.restaurantEmail = '',
    this.gstin = '',
    this.fssaiLicense = '',
    this.taxLabel = 'GST',
    this.billFooter = 'Thank you for dining with us!',
    this.billPrinterAddress,
    this.billPrinterPort = 9100,
    this.billPrinterType = 'network',
    this.autoPrintKOT = true,
  });

  /// Dynamically determines the API URL. On Web, it uses the current origin.
  String get effectiveApiUrl {
    if (kIsWeb) {
      final uri = Uri.base;
      // Reconstruct origin from browser URL
      return "${uri.scheme}://${uri.host}${uri.port == 80 || uri.port == 443 ? '' : ':${uri.port}'}";
    }
    return apiBaseUrl;
  }

  AppSettings copyWith({
    String? restaurantName,
    String? apiBaseUrl,
    double? taxRate,
    int? totalTables,
    String? currencySymbol,
    bool? kitchenSoundEnabled,
    String? counterId,
    Map<String, dynamic>? tablePositions,
    String? restaurantAddress,
    String? restaurantPhone,
    String? restaurantEmail,
    String? gstin,
    String? fssaiLicense,
    String? taxLabel,
    String? billFooter,
    String? billPrinterAddress,
    int? billPrinterPort,
    String? billPrinterType,
    bool? autoPrintKOT,
  }) {
    return AppSettings(
      restaurantName: restaurantName ?? this.restaurantName,
      apiBaseUrl: apiBaseUrl ?? this.apiBaseUrl,
      taxRate: taxRate ?? this.taxRate,
      totalTables: totalTables ?? this.totalTables,
      currencySymbol: currencySymbol ?? this.currencySymbol,
      kitchenSoundEnabled: kitchenSoundEnabled ?? this.kitchenSoundEnabled,
      counterId: counterId ?? this.counterId,
      tablePositions: tablePositions ?? this.tablePositions,
      restaurantAddress: restaurantAddress ?? this.restaurantAddress,
      restaurantPhone: restaurantPhone ?? this.restaurantPhone,
      restaurantEmail: restaurantEmail ?? this.restaurantEmail,
      gstin: gstin ?? this.gstin,
      fssaiLicense: fssaiLicense ?? this.fssaiLicense,
      taxLabel: taxLabel ?? this.taxLabel,
      billFooter: billFooter ?? this.billFooter,
      billPrinterAddress: billPrinterAddress ?? this.billPrinterAddress,
      billPrinterPort: billPrinterPort ?? this.billPrinterPort,
      billPrinterType: billPrinterType ?? this.billPrinterType,
      autoPrintKOT: autoPrintKOT ?? this.autoPrintKOT,
    );
  }

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    // Hive stores nested maps as Map<dynamic, dynamic>, must cast
    Map<String, dynamic> positions = {};
    if (json['tablePositions'] != null && json['tablePositions'] is Map) {
      positions = Map<String, dynamic>.from(json['tablePositions'] as Map);
    }
    return AppSettings(
      restaurantName: json['restaurantName'] ?? 'My Restaurant',
      apiBaseUrl: json['apiBaseUrl'] ?? 'http://127.0.0.1:8000',
      taxRate: (json['taxRate'] ?? 5.0).toDouble(),
      totalTables: json['totalTables'] ?? 20,
      currencySymbol: json['currencySymbol'] ?? '₹',
      kitchenSoundEnabled: json['kitchenSoundEnabled'] ?? true,
      counterId: json['counterId'] ?? 'POS-1',
      tablePositions: positions,
      restaurantAddress: json['restaurantAddress'] ?? '',
      restaurantPhone: json['restaurantPhone'] ?? '',
      restaurantEmail: json['restaurantEmail'] ?? '',
      gstin: json['gstin'] ?? '',
      fssaiLicense: json['fssaiLicense'] ?? '',
      taxLabel: json['taxLabel'] ?? 'GST',
      billFooter: json['billFooter'] ?? 'Thank you for dining with us!',
      billPrinterAddress: json['billPrinterAddress'],
      billPrinterPort: json['billPrinterPort'] ?? 9100,
      billPrinterType: json['billPrinterType'] ?? 'network',
      autoPrintKOT: json['autoPrintKOT'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'restaurantName': restaurantName,
      'apiBaseUrl': apiBaseUrl,
      'taxRate': taxRate,
      'totalTables': totalTables,
      'currencySymbol': currencySymbol,
      'kitchenSoundEnabled': kitchenSoundEnabled,
      'counterId': counterId,
      'tablePositions': tablePositions,
      'restaurantAddress': restaurantAddress,
      'restaurantPhone': restaurantPhone,
      'restaurantEmail': restaurantEmail,
      'gstin': gstin,
      'fssaiLicense': fssaiLicense,
      'taxLabel': taxLabel,
      'billFooter': billFooter,
      'billPrinterAddress': billPrinterAddress,
      'billPrinterPort': billPrinterPort,
      'billPrinterType': billPrinterType,
      'autoPrintKOT': autoPrintKOT,
    };
  }

  // ADD THESE HIVE METHODS
  static AppSettings loadFromHive() {
    final box = Hive.box('settings');
    final json = box.get('app_settings');
    if (json != null && json is Map) {
      return AppSettings.fromJson(Map<String, dynamic>.from(json));
    }
    return AppSettings();
  }

  Future<void> saveToHive() async {
    final box = Hive.box('settings');
    await box.put('app_settings', toJson());
  }
}