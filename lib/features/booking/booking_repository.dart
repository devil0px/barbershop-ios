import 'package:dio/dio.dart';
import '../../core/network/api_service.dart';
import '../../core/constants/api_constants.dart';
import '../../core/models/booking_model.dart';
import '../../core/results/result.dart';

/// BookingRepository — optimized with cache for read operations
class BookingRepository {
  final ApiService _apiService = ApiService();

  // ── Cache ──────────────────────────────────────────────────────────
  static List<Booking>? _myBookingsCache;
  static DateTime? _myBookingsCacheTime;
  static const Duration _cacheTtl = Duration(minutes: 2);

  static void invalidateCache() {
    _myBookingsCache = null;
    _myBookingsCacheTime = null;
  }
  // ──────────────────────────────────────────────────────────────────

  /// SWR (Stale-While-Revalidate) Mutation:
  /// Provides a stream that emits cached data instantly, then fetches fresh data.
  Stream<List<Booking>> getMyBookingsStream() async* {
    // 1. Yield stale cache instantly if available (Evaluation: Perceived speed)
    if (_myBookingsCache != null) {
      yield _myBookingsCache!;
    }

    try {
      final response = await _apiService.client.get('${ApiConstants.bookings}my_bookings/');
      if (response.statusCode == 200) {
        dynamic responseData = response.data;
        
        // Handle CoreJSONRenderer wrapping
        if (responseData is Map && responseData.containsKey('data')) {
          responseData = responseData['data'];
        }

        List<dynamic> dataList;

        if (responseData is Map && responseData.containsKey('results')) {
          dataList = responseData['results'];
        } else if (responseData is List) {
          dataList = responseData;
        } else {
          yield [];
          return;
        }

        final bookings = dataList.map((json) => Booking.fromJson(json)).toList();
        
        // 2. Update cache and yield fresh data
        _myBookingsCache = bookings;
        _myBookingsCacheTime = DateTime.now();
        yield bookings;
      }
    } catch (e) {
      // On error, the stream has already yielded the stale cache (if any)
      if (_myBookingsCache == null) yield [];
    }
  }

  /// Legacy compatibility Future (Mutation: wraps the stream)
  Future<List<Booking>> getMyBookings({bool forceRefresh = false}) async {
    if (!forceRefresh &&
        _myBookingsCache != null &&
        _myBookingsCacheTime != null &&
        DateTime.now().difference(_myBookingsCacheTime!) < _cacheTtl) {
      return _myBookingsCache!;
    }
    
    // Return the last emission of the stream (the fresh data)
    return getMyBookingsStream().last;
  }

  Future<Result<Booking, ApiException>> createBooking({
    required int shopId,
    required List<int> serviceIds,
    required String date,
    int? staffId,
  }) async {
    try {
      final response = await _apiService.client.post(
        ApiConstants.bookings,
        data: {
          'barbershop_id': shopId,
          'booking_day': date,
          'services': serviceIds.map((id) => {'service_id': id}).toList(),
          if (staffId != null) 'staff_id': staffId,
        },
      );
      if (response.statusCode == 201 || response.statusCode == 200) {
        invalidateCache(); // Invalidate so next fetch is fresh
        final dynamic responseData = response.data;
        final actualData = (responseData is Map && responseData.containsKey('data')) 
            ? responseData['data'] 
            : responseData;
        return Success(Booking.fromJson(actualData));
      }
      return Failure(ApiException('فشل التسجيل. السيرفر أرجع رمز ${response.statusCode}'));
    } on DioException catch (e) {
      String errorMessage = 'فشل الحجز. يرجى مراجعة البيانات.';
      
      if (e.response != null && e.response?.data != null) {
        final data = e.response?.data;
        if (data is Map) {
          // Check for standardized response
          final errorsObj = data.containsKey('errors') ? data['errors'] : data;
          
          if (errorsObj is Map && errorsObj.isNotEmpty) {
            List<String> errors = [];
            errorsObj.forEach((key, value) {
              String cleanKey = key == 'non_field_errors' || key == 'detail' || key == 'error' ? '' : '$key: ';
              if (value is List) {
                errors.add('$cleanKey${value.join(", ")}');
              } else {
                errors.add('$cleanKey$value');
              }
            });
            if (errors.isNotEmpty) {
              errorMessage = errors.join('\n').trim();
            }
          } else if (data['message'] != null && data['message'].toString().isNotEmpty && data['message'] != 'An error occurred') {
            errorMessage = data['message'].toString();
          } else if (errorsObj is String) {
             errorMessage = errorsObj;
          }
        } else {
          errorMessage = data.toString();
        }
      }
      return Failure(ApiException(errorMessage, statusCode: e.response?.statusCode));
    } catch (e) {
      return Failure(ApiException('حدث خطأ غير متوقع: ${e.toString()}'));
    }
  }

  Future<Result<bool, ApiException>> cancelBooking(int id) async {
    try {
      final response = await _apiService.client.post('${ApiConstants.bookings}$id/cancel/');
      invalidateCache();
      if (response.statusCode != null && response.statusCode! >= 200 && response.statusCode! < 300) {
        return const Success(true);
      }
      return Failure(ApiException('فشل الإلغاء. رمز الخطأ: ${response.statusCode}'));
    } on DioException catch (e) {
      invalidateCache();
      final data = e.response?.data;
      String errorMsg = 'فشل إلغاء الحجز';

      if (data is Map) {
        final err = data['error'] ?? data['detail'] ?? data['message'];
        if (err != null) errorMsg = err.toString();
        if (errorMsg.contains('ملغ')) return const Success(true);
      } else if (data != null) {
        errorMsg = data.toString();
      }
      return Failure(ApiException(errorMsg, statusCode: e.response?.statusCode));
    } catch (e) {
      return Failure(ApiException('حدث خطأ غير متوقع: ${e.toString()}'));
    }
  }

  Future<List<Map<String, dynamic>>> getMessages(int bookingId) async {
    try {
      final response = await _apiService.client.get('${ApiConstants.bookings}$bookingId/messages/');
      if (response.statusCode == 200) {
        dynamic responseData = response.data;
        
        // Handle CoreJSONRenderer wrapping
        if (responseData is Map && responseData.containsKey('data')) {
          responseData = responseData['data'];
        }

        List<dynamic> dataList;
        if (responseData is Map && responseData.containsKey('results')) {
          dataList = responseData['results'];
        } else if (responseData is List) {
          dataList = responseData;
        } else {
          return [];
        }
        return dataList.map((m) => Map<String, dynamic>.from(m as Map)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<bool> sendMessage(int bookingId, String message) async {
    try {
      final response = await _apiService.client.post(
        '${ApiConstants.bookings}$bookingId/send_message/',
        data: {'message': message},
      );
      return response.statusCode == 201 || response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<bool> markAsRead(int bookingId) async {
    try {
      final response = await _apiService.client.post('${ApiConstants.bookings}$bookingId/mark_messages_read/');
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}
