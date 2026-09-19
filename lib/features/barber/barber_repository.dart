import 'package:dio/dio.dart';
import '../../core/network/api_service.dart';
import '../../core/constants/api_constants.dart';
import '../../core/models/barbershop_model.dart';
import '../../core/models/service_model.dart';
import '../../core/models/staff_model.dart';
import '../../core/models/review_model.dart';
import '../../core/results/result.dart';

/// Contract for Barbershop Repository - following Clean Architecture principles
/// derived from advanced engineering patterns.
abstract class IBarbershopRepository {
  Future<Result<List<Barbershop>, ApiException>> getBarbershops({bool forceRefresh = false});
  Stream<Result<List<Barbershop>, ApiException>> getBarbershopsStream();
  Future<Result<List<BarberService>, ApiException>> getServices(int shopId);
  Future<Result<List<Staff>, ApiException>> getStaff(int shopId);
  Future<Result<List<Review>, ApiException>> getReviews(int shopId);
  Future<Result<Barbershop, ApiException>> getBarbershopDetails(int id);
  Future<Result<Map<String, dynamic>, ApiException>> checkAvailability(int shopId, String date);
  Future<Result<Map<String, dynamic>, ApiException>> submitReview(int shopId, double rating, String comment, {int? bookingId});
}

/// A Professional Implementation of [IBarbershopRepository]
class BarbershopRepository implements IBarbershopRepository {
  final ApiService _apiService = ApiService();

  // ── Optimized Internal Cache ───────────────────────────────────────────
  static final Map<String, dynamic> _cache = {};
  static final Map<String, DateTime> _cacheTime = {};
  static const Duration _cacheTtl = Duration(minutes: 5);

  static void invalidateCache() {
    _cache.clear();
    _cacheTime.clear();
  }
  // ───────────────────────────────────────────────────────────────────────

  @override
  Future<Result<List<Barbershop>, ApiException>> getBarbershops({
    bool forceRefresh = false,
    int page = 1,
    String? search,
  }) async {
    final String cacheKey = 'barbershops_list_page_$page';
    
    // Performance Optimization: Cache Hit Evaluation
    if (!forceRefresh && _cache.containsKey(cacheKey) && search == null) {
      final lastFetch = _cacheTime[cacheKey];
      if (lastFetch != null && DateTime.now().difference(lastFetch) < _cacheTtl) {
        return Success(_cache[cacheKey] as List<Barbershop>);
      }
    }

    try {
      final response = await _apiService.client.get(
        ApiConstants.barbershops,
        queryParameters: {
          'page': page,
          if (search != null) 'search': search,
        },
      );
      
      if (response.statusCode == 200) {
        dynamic responseData = response.data;
        
        // Handle CoreJSONRenderer wrapping
        if (responseData is Map && responseData.containsKey('data')) {
          responseData = responseData['data'];
        }

        // Support both paginated and non-paginated responses for backward compatibility
        List<dynamic> listData = (responseData is Map && responseData.containsKey('results')) ? responseData['results'] : responseData;
        
        final shops = listData.map((json) => Barbershop.fromJson(json)).toList();
        
        // Persistence: Update Cache only for main list
        if (search == null) {
          _cache[cacheKey] = shops;
          _cacheTime[cacheKey] = DateTime.now();
        }
        
        return Success(shops);
      }
      return Failure(ApiException('Unexpected status code: ${response.statusCode}', statusCode: response.statusCode));
    } catch (e) {
      return Failure(_handleError(e, 'Failed to fetch barbershops'));
    }
  }

  @override
  Stream<Result<List<Barbershop>, ApiException>> getBarbershopsStream() async* {
    const String cacheKey = 'barbershops_list_page_1';
    
    // ⚡ Phase 2 Mutation: Immediate Cache Delivery
    if (_cache.containsKey(cacheKey)) {
      yield Success(_cache[cacheKey] as List<Barbershop>);
    }

    // 🔄 Background Refresh (Starts with page 1)
    final result = await getBarbershops(forceRefresh: true, page: 1);
    yield result;
  }

  @override
  Future<Result<List<BarberService>, ApiException>> getServices(int shopId) async {
    try {
      final response = await _apiService.client.get(ApiConstants.barbershopServices(shopId));
      if (response.statusCode == 200) {
        dynamic responseData = response.data;
        
        // Handle CoreJSONRenderer wrapping
        if (responseData is Map && responseData.containsKey('data')) {
          responseData = responseData['data'];
        }

        final list = (responseData is Map ? responseData['results'] : responseData) as List;
        return Success(list.map((j) => BarberService.fromJson(j)).toList());
      }
      return Failure(ApiException('Failed to fetch services', statusCode: response.statusCode));
    } catch (e) {
      return Failure(_handleError(e, 'Error fetching services'));
    }
  }

  @override
  Future<Result<List<Staff>, ApiException>> getStaff(int shopId) async {
    try {
      final response = await _apiService.client.get(ApiConstants.barbershopStaff(shopId));
      if (response.statusCode == 200) {
        dynamic responseData = response.data;
        
        // Handle CoreJSONRenderer wrapping
        if (responseData is Map && responseData.containsKey('data')) {
          responseData = responseData['data'];
        }

        final list = (responseData is Map ? responseData['results'] : responseData) as List;
        return Success(list.map((j) => Staff.fromJson(j)).toList());
      }
      return Failure(ApiException('Failed to fetch staff', statusCode: response.statusCode));
    } catch (e) {
      return Failure(_handleError(e, 'Error fetching staff'));
    }
  }

  @override
  Future<Result<List<Review>, ApiException>> getReviews(int shopId) async {
    try {
      final response = await _apiService.client.get(ApiConstants.barbershopReviews(shopId));
      if (response.statusCode == 200) {
        dynamic responseData = response.data;
        
        // Handle CoreJSONRenderer wrapping
        if (responseData is Map && responseData.containsKey('data')) {
          responseData = responseData['data'];
        }

        final list = (responseData is Map ? responseData['results'] : responseData) as List;
        return Success(list.map((j) => Review.fromJson(j)).toList());
      }
      return Failure(ApiException('Failed to fetch reviews', statusCode: response.statusCode));
    } catch (e) {
      return Failure(_handleError(e, 'Error fetching reviews'));
    }
  }

  @override
  Future<Result<Barbershop, ApiException>> getBarbershopDetails(int id) async {
    try {
      final response = await _apiService.client.get('${ApiConstants.barbershops}$id/');
      if (response.statusCode == 200) {
        final dynamic responseData = response.data;
        final actualData = (responseData is Map && responseData.containsKey('data')) 
            ? responseData['data'] 
            : responseData;
        return Success(Barbershop.fromJson(actualData));
      }
      return Failure(ApiException('Details not found', statusCode: response.statusCode));
    } catch (e) {
      return Failure(_handleError(e, 'Error getting shop details'));
    }
  }

  @override
  Future<Result<Map<String, dynamic>, ApiException>> checkAvailability(int shopId, String date) async {
    try {
      final response = await _apiService.client.get(
        ApiConstants.checkAvailability(shopId),
        queryParameters: {'date': date},
      );
      if (response.statusCode == 200) {
        final dynamic responseData = response.data;
        final actualData = (responseData is Map && responseData.containsKey('data')) 
            ? responseData['data'] 
            : responseData;
            
        return Success(actualData is Map ? Map<String, dynamic>.from(actualData) : {});
      }
      return Failure(ApiException('Availability check failed', statusCode: response.statusCode));
    } catch (e) {
      return Failure(_handleError(e, 'Network error during availability check'));
    }
  }

  @override
  Future<Result<Map<String, dynamic>, ApiException>> submitReview(
    int shopId, double rating, String comment, {int? bookingId}
  ) async {
    try {
      final response = await _apiService.client.post(
        ApiConstants.reviews,
        data: {
          'barbershop_id': shopId,
          'rating': rating.toInt(),
          'comment': comment,
          if (bookingId != null) 'booking_id': bookingId,
        },
      );
      if (response.statusCode == 201 || response.statusCode == 200) {
        return Success({'success': true, 'message': 'تم إضافة التقييم بنجاح'});
      }
      return Failure(ApiException('Failed to submit review', statusCode: response.statusCode));
    } catch (e) {
      return Failure(_handleError(e, 'Submission failed'));
    }
  }

  // ── Error Orchestration ───────────────────────────────────────────────
  ApiException _handleError(dynamic error, String defaultMessage) {
    if (error is DioException) {
      final serverMessage = error.response?.data is Map 
          ? error.response?.data['detail'] ?? error.response?.data['message']
          : null;
      return ApiException(
        serverMessage ?? error.message ?? defaultMessage,
        statusCode: error.response?.statusCode,
        originalError: error,
      );
    }
    return ApiException(defaultMessage, originalError: error);
  }
}
