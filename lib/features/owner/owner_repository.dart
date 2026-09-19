import 'package:dio/dio.dart';
import '../../core/network/api_service.dart';
import '../../core/constants/api_constants.dart';
import '../../core/models/barbershop_model.dart';
import '../../core/models/booking_model.dart';
import '../../core/results/result.dart';

class OwnerRepository {
  final ApiService _apiService = ApiService();

  /// Get barbershops owned by the current user
  Future<List<Barbershop>> getMyBarbershops() async {
    try {
      final response = await _apiService.client.get(
        ApiConstants.barbershops,
        queryParameters: {'my_barbershops': 'true'},
      );
      
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
        
        return dataList.map((json) => Barbershop.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      print('Error fetching owner barbershops: $e');
      return [];
    }
  }

  /// Create a new barbershop with optional image
  Future<Result<bool, ApiException>> createBarbershop(Map<String, dynamic> data) async {
    try {
      dynamic finalData;

      // Extract image_path FIRST before building FormData to avoid including it as a field
      final String? imagePath = data.remove('image_path');

      if (imagePath != null) {
        // Build FormData safely — convert numbers to string for multipart
        final Map<String, dynamic> formMap = {};
        data.forEach((key, value) {
          if (value != null) formMap[key] = value.toString();
        });
        formMap['image'] = await MultipartFile.fromFile(
          imagePath,
          filename: 'shop_image_${DateTime.now().millisecondsSinceEpoch}.jpg',
        );
        finalData = FormData.fromMap(formMap);
      } else {
        finalData = Map<String, dynamic>.from(data)
          ..removeWhere((_, v) => v == null);
      }

      final response = await _apiService.client.post(
        ApiConstants.barbershops,
        data: finalData,
        options: Options(
          contentType: finalData is FormData ? 'multipart/form-data' : 'application/json',
        ),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        return const Success(true);
      }
      return Failure(ApiException('فشل التسجيل. السيرفر أرجع رمز \${response.statusCode}'));

    } on DioException catch (e) {
      return Failure(ApiException(_parseDioError(e), statusCode: e.response?.statusCode));
    } catch (e) {
      return Failure(ApiException('حدث خطأ غير متوقع: \${e.toString()}'));
    }
  }

  /// Update an existing barbershop
  /// Returns a Result so the UI can show precise error messages
  Future<Result<bool, ApiException>> updateBarbershopWithResult(
      int shopId, Map<String, dynamic> data) async {
    try {
      dynamic finalData;
      final String? imagePath = data.remove('image_path');

      if (imagePath != null) {
        // Build FormData — exclude image_path (already removed above)
        final Map<String, dynamic> formMap = {};
        data.forEach((key, value) {
          if (value != null) formMap[key] = value.toString();
        });
        formMap['image'] = await MultipartFile.fromFile(
          imagePath,
          filename: 'update_shop_${DateTime.now().millisecondsSinceEpoch}.jpg',
        );
        finalData = FormData.fromMap(formMap);
      } else {
        // JSON body — remove null values to avoid overwriting with null
        finalData = Map<String, dynamic>.from(data)
          ..removeWhere((_, v) => v == null);
      }

      final response = await _apiService.client.patch(
        '${ApiConstants.barbershops}$shopId/',
        data: finalData,
        options: Options(
          contentType:
              finalData is FormData ? 'multipart/form-data' : 'application/json',
        ),
      );
      if (response.statusCode == 200) return const Success(true);
      return Failure(ApiException(
          'السيرفر أرجع رمز خطأ: ${response.statusCode}',
          statusCode: response.statusCode));
    } on DioException catch (e) {
      return Failure(ApiException(_parseDioError(e),
          statusCode: e.response?.statusCode));
    } catch (e) {
      return Failure(ApiException('حدث خطأ غير متوقع: $e'));
    }
  }

  /// Legacy bool wrapper — kept for backward compat
  Future<bool> updateBarbershop(int shopId, Map<String, dynamic> data) async {
    final result = await updateBarbershopWithResult(shopId, data);
    return result is Success;
  }

  /// Update barbershop settings (like working hours)
  Future<bool> updateBarbershopSettings(int shopId, Map<String, dynamic> settings) async {
    try {
      if (settings.containsKey('working_hours')) {
        final response = await _apiService.client.put(
          ApiConstants.barbershopWorkingHours(shopId),
          data: settings['working_hours'],
        );
        return response.statusCode == 200;
      }
      return true;
    } catch (e) {
      print('Error updating settings: $e');
      return false;
    }
  }

  /// Get bookings for a specific barbershop (for owners)
  Future<List<Booking>> getBarbershopBookings(
    int shopId, {
    String? date,
    bool? history,
    int? month,
    int? year,
  }) async {
    try {
      final response = await _apiService.client.get(
        '${ApiConstants.bookings}barbershop_bookings/',
        queryParameters: {
          'barbershop_id': shopId,
          if (date != null) 'date': date,
          if (history == true) 'history': 'true',
          if (month != null) 'month': month,
          if (year != null) 'year': year,
        },
      );
      
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
        
        return dataList.map((json) => Booking.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      print('Error fetching barbershop bookings: $e');
      return [];
    }
  }

  /// Update booking status (confirm, complete, cancel, no_show)
  Future<bool> updateBookingStatus(int bookingId, String status) async {
    try {
      final response = await _apiService.client.post(
        '${ApiConstants.bookings}$bookingId/update_status/',
        data: {'status': status},
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Error updating booking status: $e');
      return false;
    }
  }

  /// Increment shop turn (Next Client)
  Future<bool> incrementTurn(int shopId) async {
    try {
      final response = await _apiService.client.post(
        '${ApiConstants.barbershops}$shopId/increment_turn/',
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Error incrementing turn: $e');
      return false;
    }
  }

  // --- Services Management ---

  Future<List<dynamic>> getServices(int shopId) async {
    try {
      final response = await _apiService.client.get(ApiConstants.barbershopServices(shopId));
      if (response.statusCode == 200) {
        dynamic responseData = response.data;
        
        // Handle CoreJSONRenderer wrapping
        if (responseData is Map && responseData.containsKey('data')) {
          responseData = responseData['data'];
        }
        
        if (responseData is List) return responseData;
        if (responseData is Map && responseData.containsKey('results')) return responseData['results'];
        return [];
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<Result<bool, ApiException>> addService(int shopId, Map<String, dynamic> data) async {
    try {
      dynamic finalData;
      final imagePath = data.remove('image_path'); // Remove before spreading
      
      // Ensure data types are correct for FormData (all primitives should ideally be strings for multipart)
      if (imagePath != null) {
        final Map<String, dynamic> formDataMap = {
          'name': data['name'],
          'price': data['price'].toString(),
          'duration': data['duration'].toString(),
          'category': data['category'] ?? 'haircut',
          'barbershop': shopId.toString(),
          'is_active': 'true',
          'image': await MultipartFile.fromFile(imagePath, filename: 'service_${DateTime.now().millisecondsSinceEpoch}.jpg'),
        };
        finalData = FormData.fromMap(formDataMap);
      } else {
        finalData = {...data, 'barbershop': shopId, 'is_active': true};
      }

      final response = await _apiService.client.post(
        ApiConstants.services, 
        data: finalData,
        options: Options(contentType: finalData is FormData ? 'multipart/form-data' : 'application/json'),
      );
      if (response.statusCode == 201) return const Success(true);
      return Failure(ApiException('فشل إضافة الخدمة.'));
    } on DioException catch (e) {
      return Failure(ApiException(_parseDioError(e)));
    } catch (e) {
      return Failure(ApiException('خطأ: $e'));
    }
  }

  Future<Result<bool, ApiException>> updateService(int serviceId, Map<String, dynamic> data) async {
    try {
      dynamic finalData;
      final imagePath = data.remove('image_path'); // Remove before spreading
      
      if (imagePath != null) {
        final Map<String, dynamic> formDataMap = {};
        
        // Convert all values to string for FormData
        data.forEach((key, value) {
          if (value != null) formDataMap[key] = value.toString();
        });
        
        formDataMap['image'] = await MultipartFile.fromFile(imagePath, filename: 'service_update.jpg');
        finalData = FormData.fromMap(formDataMap);
      } else {
        finalData = data;
      }

      final response = await _apiService.client.patch(
        '${ApiConstants.services}$serviceId/', 
        data: finalData,
        options: Options(contentType: finalData is FormData ? 'multipart/form-data' : 'application/json'),
      );
      if (response.statusCode == 200) return const Success(true);
      return Failure(ApiException('فشل تحديث الخدمة.'));
    } on DioException catch (e) {
      return Failure(ApiException(_parseDioError(e)));
    } catch (e) {
      return Failure(ApiException('خطأ: $e'));
    }
  }

  Future<bool> deleteService(int serviceId) async {
    try {
      final response = await _apiService.client.delete('${ApiConstants.services}$serviceId/');
      return response.statusCode == 204;
    } catch (e) {
      return false;
    }
  }

  // --- Staff Management ---

  Future<List<dynamic>> getStaff(int shopId) async {
    try {
      final response = await _apiService.client.get(ApiConstants.barbershopStaff(shopId));
      if (response.statusCode == 200) return response.data is List ? response.data : response.data['results'] ?? [];
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<Result<bool, ApiException>> addStaff(int shopId, Map<String, dynamic> data) async {
    try {
      dynamic finalData;
      if (data.containsKey('photo_path') && data['photo_path'] != null) {
        final photoPath = data.remove('photo_path') as String;
        final formDataMap = <String, dynamic>{};
        data.forEach((key, value) {
          if (value != null) formDataMap[key] = value.toString();
        });
        formDataMap['photo'] = await MultipartFile.fromFile(photoPath, filename: 'staff_photo.jpg');
        finalData = FormData.fromMap(formDataMap);
      } else {
        finalData = data;
      }

      final response = await _apiService.client.post(
        ApiConstants.barbershopStaff(shopId),
        data: finalData,
        options: Options(contentType: finalData is FormData ? 'multipart/form-data' : 'application/json'),
      );
      if (response.statusCode == 201) return const Success(true);
      return Failure(ApiException('فشل إضافة الموظف.'));
    } on DioException catch (e) {
      return Failure(ApiException(_parseDioError(e)));
    } catch (e) {
      return Failure(ApiException('خطأ: $e'));
    }
  }

  Future<Result<bool, ApiException>> updateStaff(int staffId, Map<String, dynamic> data) async {
    try {
      dynamic finalData;
      if (data.containsKey('photo_path') && data['photo_path'] != null) {
        final photoPath = data.remove('photo_path') as String;
        final formDataMap = <String, dynamic>{};
        data.forEach((key, value) {
          if (value != null) formDataMap[key] = value.toString();
        });
        formDataMap['photo'] = await MultipartFile.fromFile(photoPath, filename: 'staff_photo.jpg');
        finalData = FormData.fromMap(formDataMap);
      } else {
        finalData = data;
      }

      final response = await _apiService.client.patch(
        '${ApiConstants.baseUrl}/barbershops/staff/$staffId/',
        data: finalData,
        options: Options(contentType: finalData is FormData ? 'multipart/form-data' : 'application/json'),
      );
      if (response.statusCode == 200) return const Success(true);
      return Failure(ApiException('فشل تحديث بيانات الموظف.'));
    } on DioException catch (e) {
      return Failure(ApiException(_parseDioError(e)));
    } catch (e) {
      return Failure(ApiException('خطأ: $e'));
    }
  }

  String _parseDioError(DioException e) {
    if (e.response?.data != null) {
      final data = e.response?.data;
      if (data is Map) {
        List<String> errors = [];
        data.forEach((key, value) {
          if (value is List) {
            errors.add('$key: ${value.join(", ")}');
          } else {
            errors.add('$key: $value');
          }
        });
        return errors.join('\n');
      }
      return data.toString();
    }
    return e.message ?? 'خطأ في الاتصال بالسيرفر';
  }

  Future<bool> deleteStaff(int staffId) async {
    try {
      final response = await _apiService.client.delete(
        '${ApiConstants.baseUrl}/barbershops/staff/$staffId/',
      );
      return response.statusCode == 204;
    } catch (e) {
      print('Error deleting staff: $e');
      return false;
    }
  }

  // --- Financial Stats ---
  
  Future<Map<String, dynamic>> getFinancialStats(int shopId) async {
    try {
      final response = await _apiService.client.get('${ApiConstants.barbershops}$shopId/stats/');
      if (response.statusCode == 200) {
        final dynamic responseData = response.data;
        if (responseData is Map && responseData.containsKey('data')) {
          final data = responseData['data'];
          return data is Map ? Map<String, dynamic>.from(data) : {};
        }
        return responseData is Map ? Map<String, dynamic>.from(responseData) : {};
      }
      return {};
    } catch (e) {
      return {};
    }
  }
}
