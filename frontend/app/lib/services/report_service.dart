import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers.dart';

class ReportService {
  final Dio _dio;

  ReportService(this._dio);

  Future<Map<String, dynamic>> getSummary(DateTime start, DateTime end) async {
    try {
      final response = await _dio.get('/reports/summary', queryParameters: {
        'start_date': start.toIso8601String().split('T')[0],
        'end_date': end.toIso8601String().split('T')[0],
      });
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  Future<List<int>> downloadCSV(DateTime start, DateTime end) async {
    try {
      final response = await _dio.get(
        '/reports/export/csv',
        queryParameters: {
          'start_date': start.toIso8601String().split('T')[0],
          'end_date': end.toIso8601String().split('T')[0],
        },
        options: Options(responseType: ResponseType.bytes),
      );
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  Future<List<int>> downloadPDF(DateTime start, DateTime end, String restaurantName, {String orientation = 'portrait'}) async {
    try {
      final response = await _dio.get(
        '/reports/export/pdf',
        queryParameters: {
          'start_date': start.toIso8601String().split('T')[0],
          'end_date': end.toIso8601String().split('T')[0],
          'restaurant_name': restaurantName,
          'orientation': orientation,
        },
        options: Options(responseType: ResponseType.bytes),
      );
      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  Future<List<int>> downloadExcel(DateTime start, DateTime end, String restaurantName) async {
    try {
      final response = await _dio.get(
        '/reports/export/excel',
        queryParameters: {
          'start_date': start.toIso8601String().split('T')[0],
          'end_date': end.toIso8601String().split('T')[0],
          'restaurant_name': restaurantName,
        },
        options: Options(responseType: ResponseType.bytes),
      );
      return response.data;
    } catch (e) {
      rethrow;
    }
  }
}

final reportServiceProvider = Provider<ReportService>((ref) {
  final dio = ref.watch(dioProvider);
  return ReportService(dio);
});
