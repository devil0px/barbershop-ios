import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/api_constants.dart';

class ApiService {
  // Singleton pattern — only one Dio instance throughout the app lifecycle
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;

  String? _accessToken; // Memory cache for the token
  Future<bool>? _refreshFuture; // Lock for token refresh process

  final Dio _dio = Dio(BaseOptions(
    baseUrl: ApiConstants.baseUrl,
    receiveTimeout: const Duration(seconds: 15), // Reduced for faster feedback
    connectTimeout: const Duration(seconds: 15),
    contentType: 'application/json',
  ));

  ApiService._internal() {
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        // Performance Mutation: Instant memory token access
        if (_accessToken != null) {
          options.headers['Authorization'] = 'Bearer $_accessToken';
        } else {
          // Fast fallback to SharedPreferences if memory is empty
          final prefs = await SharedPreferences.getInstance();
          _accessToken = prefs.getString('access_token');
          if (_accessToken != null) {
            options.headers['Authorization'] = 'Bearer $_accessToken';
          }
        }
        return handler.next(options);
      },
      onResponse: (response, handler) {
        // 🧱 Architecture Mutation: Standardized Unwrapping
        // This ensures the repositories still receive the raw data they expect
        if (response.data is Map<String, dynamic>) {
          final map = response.data as Map<String, dynamic>;
          if (map.containsKey('success') && map.containsKey('data')) {
            debugPrint('✅ API Success: ${map['message']}');
            // Unwrap the data so the rest of the app doesn't need to know about the wrapper
            response.data = map['data'];
          }
        }
        return handler.next(response);
      },
      onError: (DioException e, handler) async {
        // 🛡️ Network Hardening Mutation: Intelligent Retry Engine
        bool isRetryable = e.type == DioExceptionType.connectionError || 
                          e.type == DioExceptionType.connectionTimeout ||
                          e.type == DioExceptionType.sendTimeout ||
                          e.type == DioExceptionType.receiveTimeout;

        // Only retry GET requests or specific safe operations
        if (isRetryable && e.requestOptions.method == 'GET') {
          int retryCount = (e.requestOptions.extra['retryCount'] ?? 0);
          if (retryCount < 2) { // Max 2 retries
            debugPrint('🔄 Network Resilience: Retrying request... Attempt ${retryCount + 1}');
            e.requestOptions.extra['retryCount'] = retryCount + 1;
            
            // Wait a bit before retrying (Exponential style)
            await Future.delayed(Duration(seconds: 1 * (retryCount + 1)));
            
            try {
              final response = await _dio.fetch(e.requestOptions);
              return handler.resolve(response);
            } catch (_) {
              // If retry fails, continue to standard error handling
            }
          }
        }

        if (e.response?.statusCode == 401) {
          debugPrint('🔑 Session Expired: Attempting silent token refresh...');
          final refreshed = await _refreshToken();
          if (refreshed && _accessToken != null) {
            e.requestOptions.headers['Authorization'] = 'Bearer $_accessToken';
            try {
              final response = await _dio.fetch(e.requestOptions);
              return handler.resolve(response);
            } catch (retryError) {
              return handler.next(e);
            }
          } else {
            await _clearTokens();
          }
        }
        return handler.next(e);
      },
    ));
  }

  /// Update memory cache (called after login/registration)
  void setAccessToken(String? token) {
    _accessToken = token;
  }

  /// Refresh the access token using the refresh token
  Future<bool> _refreshToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final refreshToken = prefs.getString('refresh_token');
      
      if (refreshToken == null) return false;

      // Use a separate Dio instance to avoid interceptor loop
      final refreshDio = Dio(BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        contentType: 'application/json',
      ));

      final response = await refreshDio.post(
        ApiConstants.tokenRefresh,
        data: {'refresh': refreshToken},
      );

      if (response.statusCode == 200) {
        final newAccessToken = response.data['access'];
        _accessToken = newAccessToken; // Update memory cache
        await prefs.setString('access_token', newAccessToken);
        
        final newRefreshToken = response.data['refresh'];
        if (newRefreshToken != null) {
          await prefs.setString('refresh_token', newRefreshToken);
        }
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Clear all stored tokens
  Future<void> _clearTokens() async {
    _accessToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
  }

  Dio get client => _dio;
}
