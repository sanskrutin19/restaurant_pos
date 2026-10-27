import 'package:intl/intl.dart';

class TimeUtils {
  static DateTime parseUtc(dynamic value) {
    if (value == null) return DateTime.now();
    final str = value.toString();
    if (str.isEmpty) return DateTime.now();
    
    // If it doesn't end with Z and doesn't contain a + offset, append Z
    final normalized = (str.endsWith('Z') || str.contains('+')) ? str : '${str}Z';
    return DateTime.parse(normalized);
  }

  static DateTime? parseUtcNullable(dynamic value) {
    if (value == null) return null;
    final str = value.toString();
    if (str.isEmpty) return null;
    
    final normalized = (str.endsWith('Z') || str.contains('+')) ? str : '${str}Z';
    return DateTime.parse(normalized);
  }
}
