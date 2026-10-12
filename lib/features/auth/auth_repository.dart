import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../core/network/api_service.dart';
import '../../core/constants/api_constants.dart';
import '../../core/results/result.dart';
import '../booking/booking_repository.dart';
import '../barber/barber_repository.dart';

class AuthRepository {
  final ApiService _apiService = ApiService();

  Future<Result<bool, ApiException>> login(String username, String password) async {
    try {
      final response = await _apiService.client.post(
        ApiConstants.login,
        data: {
          'email': username,
          'password': password,
        },
      );

      if (response.statusCode == 200) {
        final token = response.data['access'];
        final refreshToken = response.data['refresh'];
        final userData = response.data['user'];
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('access_token', token);
        // Save refresh token to preserve session across app restarts
        if (refreshToken != null) await prefs.setString('refresh_token', refreshToken);

        if (userData != null) {
          await prefs.setString('user_id', userData['id'].toString());
          await prefs.setString('user_email', userData['email'] ?? '');
          await prefs.setString('full_name', userData['full_name'] ?? '');
          // Fix: Never save empty user_type — fallback to 'customer'
          final userType = userData['user_type']?.toString() ?? '';
          await prefs.setString('user_type', userType.isNotEmpty ? userType : 'customer');
          await prefs.setString('profile_photo', userData['profile_photo_url'] ?? '');
        }
        return const Success(true);
      }
      return Failure(ApiException('بيانات الدخول غير صحيحة', statusCode: response.statusCode));
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        return Failure(ApiException('البريد الإلكتروني أو كلمة المرور غير صحيحة', statusCode: 401));
      }
      return Failure(ApiException('حدث خطأ في الاتصال بالسيرفر. تأكد من الإنترنت.', statusCode: e.response?.statusCode));
    } catch (e) {
      return Failure(ApiException('حدث خطأ غير متوقع: ${e.toString()}'));
    }
  }

  Future<void> logout() async {
    // 1. Clear static caches in repositories
    BookingRepository.invalidateCache();
    BarbershopRepository.invalidateCache();
    
    // 2. Clear token from ApiService memory
    _apiService.setAccessToken(null);
    
    // 3. Clear SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
    await prefs.remove('user_id');
    await prefs.remove('user_email');
    await prefs.remove('full_name');
    await prefs.remove('user_type');
    await prefs.remove('profile_photo');
    
    // 4. Sign out from Google
    try { await GoogleSignIn().signOut(); } catch (_) {}
  }

  Future<Result<bool, ApiException>> signInWithGoogle() async {
    try {
      const String serverClientId = '792163163483-eoft8le5p2lrma6qmbesuuvdp15u9fcl.apps.googleusercontent.com';
      
      final GoogleSignIn googleSignIn = GoogleSignIn(
        clientId: kIsWeb ? serverClientId : null,
        serverClientId: kIsWeb ? null : serverClientId,
      );

      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      if (googleUser == null) return Failure(ApiException('تم إلغاء تسجيل الدخول'));

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final String? idToken = googleAuth.idToken;

      if (idToken == null) return Failure(ApiException('فشل الحصول على توثيق جوجل'));

      final response = await _apiService.client.post(
        ApiConstants.googleLogin,
        data: {
          'id_token': idToken,
        },
      );

      if (response.statusCode == 200) {
        final token = response.data['access'];
        final refreshToken = response.data['refresh'];
        final userData = response.data['user'];
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('access_token', token);
        if (refreshToken != null) await prefs.setString('refresh_token', refreshToken);

        if (userData != null) {
          await prefs.setString('user_id', userData['id'].toString());
          await prefs.setString('user_email', userData['email'] ?? '');
          await prefs.setString('full_name', userData['full_name'] ?? '');
          // Fix: Never save empty user_type — fallback to 'customer'
          final userType = userData['user_type']?.toString() ?? '';
          await prefs.setString('user_type', userType.isNotEmpty ? userType : 'customer');
          await prefs.setString('profile_photo', userData['profile_photo_url'] ?? '');
        }
        return const Success(true);
      }
      return Failure(ApiException('فشل الدخول بحساب جوجل', statusCode: response.statusCode));
    } on DioException catch (e) {
      return Failure(ApiException('حدث خطأ في الاتصال بالسيرفر. تأكد من الإنترنت.', statusCode: e.response?.statusCode));
    } catch (e) {
      print('Google sign-in error: $e');
      return Failure(ApiException('حدث خطأ أثناء الاتصال بجوجل: ${e.toString()}'));
    }
  }

  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    return token != null && token.isNotEmpty;
  }

  Future<Result<bool, ApiException>> register({
    required String username,
    required String email,
    required String password,
    required String password2,
    required String firstName,
    required String lastName,
    required String phoneNumber,
    String userType = 'customer',
  }) async {
    try {
      final response = await _apiService.client.post(
        ApiConstants.register,
        data: {
          'username': username,
          'email': email,
          'password': password,
          'password2': password2,
          'first_name': firstName,
          'last_name': lastName,
          'phone_number': phoneNumber,
          'user_type': userType,
        },
      );
      if (response.statusCode == 201 || response.statusCode == 200) {
        return const Success(true);
      }
      return Failure(ApiException('فشل إنشاء الحساب. رمز الحالة: ${response.statusCode}'));
    } on DioException catch (e) {
      return Failure(ApiException(
        _extractRegistrationError(e.response?.data),
        statusCode: e.response?.statusCode,
      ));
    } catch (e) {
      return Failure(ApiException('حدث خطأ غير متوقع: $e'));
    }
  }

  /// Extract and translate Django validation errors to Arabic
  String _extractRegistrationError(dynamic responseData) {
    if (responseData == null) {
      return 'حدث خطأ أثناء إنشاء الحساب. يرجى المحاولة لاحقاً.';
    }

    // Handle plain string response
    if (responseData is String && responseData.isNotEmpty) {
      return _translateError('', responseData);
    }

    if (responseData is! Map) {
      return 'حدث خطأ أثناء إنشاء الحساب. يرجى المحاولة لاحقاً.';
    }

    final data = Map<String, dynamic>.from(responseData as Map);

    // ── Handle nested format: {"success": false, "errors": {...}} ──
    if (data.containsKey('errors') && data['errors'] is Map) {
      return _extractRegistrationError(data['errors']);
    }

    // ── Handle {"detail": "message"} format ──
    if (data.containsKey('detail') && data['detail'] is String) {
      return _translateError('detail', data['detail']);
    }

    // ── Priority: check specific DRF field names ──
    final fieldPriority = [
      'email', 'username', 'password', 'password2',
      'phone_number', 'first_name', 'last_name', 'non_field_errors',
    ];

    for (final field in fieldPriority) {
      if (data.containsKey(field)) {
        final raw = data[field];
        // ✅ Skip boolean values — they're not error messages
        if (raw is bool) continue;
        String msg = raw is List && raw.isNotEmpty
            ? raw[0].toString()
            : raw.toString();
        if (msg.isNotEmpty && msg != 'null' && msg != 'false' && msg != 'true') {
          return _translateError(field, msg);
        }
      }
    }

    // ── Fallback: iterate all fields, skip booleans/non-string values ──
    for (final entry in data.entries) {
      final key = entry.key;
      final raw = entry.value;

      // Skip boolean fields (e.g. "success": false)
      if (raw is bool) continue;

      String msg;
      if (raw is List && raw.isNotEmpty) {
        // Skip lists of booleans
        if (raw.first is bool) continue;
        msg = raw[0].toString();
      } else if (raw is String) {
        msg = raw;
      } else {
        continue;
      }

      if (msg.isNotEmpty && msg != 'null' && msg != 'false' && msg != 'true') {
        return _translateError(key, msg);
      }
    }

    return 'حدث خطأ أثناء إنشاء الحساب. يرجى المحاولة لاحقاً.';
  }

  /// Translate a single English Django error string to Arabic
  String _translateError(String field, String msg) {
    final lower = msg.toLowerCase();

    // ── Email ──
    if (field == 'email' || lower.contains('email')) {
      if (lower.contains('already exists') || lower.contains('unique')) {
        return 'هذا البريد الإلكتروني مسجل بالفعل، يرجى تسجيل الدخول.';
      }
      if (lower.contains('valid') || lower.contains('enter a valid')) {
        return 'يرجى إدخال بريد إلكتروني صحيح.';
      }
      if (lower.contains('required') || lower.contains('blank')) {
        return 'البريد الإلكتروني مطلوب.';
      }
    }

    // ── Username ──
    if (field == 'username' || lower.contains('username')) {
      if (lower.contains('already exists') || lower.contains('unique')) {
        return 'اسم المستخدم موجود بالفعل، يرجى اختيار اسم آخر.';
      }
      if (lower.contains('letters') || lower.contains('characters')) {
        return 'اسم المستخدم يجب أن يحتوي على أحرف وأرقام فقط.';
      }
      if (lower.contains('required') || lower.contains('blank')) {
        return 'اسم المستخدم مطلوب.';
      }
    }

    // ── Password ──
    if (field == 'password' || field == 'password2') {
      if (lower.contains('too common') || lower.contains('commonly used')) {
        return 'كلمة المرور شائعة جداً، يرجى اختيار كلمة مرور أصعب.';
      }
      if (lower.contains('too short') || lower.contains('at least 8')) {
        return 'كلمة المرور قصيرة جداً. يجب أن تكون 8 أحرف على الأقل.';
      }
      if (lower.contains('entirely numeric') || lower.contains('only numeric')) {
        return 'كلمة المرور لا يمكن أن تكون أرقاماً فقط.';
      }
      if (lower.contains('similar') || lower.contains('too similar')) {
        return 'كلمة المرور مشابهة جداً لبياناتك الشخصية، يرجى اختيار كلمة مرور مختلفة.';
      }
      if (lower.contains('do not match') || lower.contains('not match')) {
        return 'كلمتا المرور غير متطابقتين.';
      }
    }

    // ── Phone Number ──
    if (field == 'phone_number') {
      if (lower.contains('invalid') || lower.contains('valid')) {
        return 'رقم الهاتف غير صحيح. يجب أن يكون بين 9-15 رقم.';
      }
    }

    // ── Generic translations ──
    if (lower.contains('required') || lower.contains('blank') || lower.contains('null')) {
      return 'يرجى ملء جميع الحقول الأساسية.';
    }
    if (lower.contains('already exists') || lower.contains('unique')) {
      return 'هذه البيانات مسجلة بالفعل، يرجى استخدام بيانات أخرى.';
    }

    // Last resort: return original (might be Arabic from backend)
    return msg;
  }

  Future<Map<String, dynamic>?> getMe() async {
    try {
      final response = await _apiService.client.get('${ApiConstants.register}me/');
      if (response.statusCode == 200) {
        final userData = response.data;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_id', userData['id'].toString());
        await prefs.setString('user_email', userData['email'] ?? '');
        await prefs.setString('full_name', userData['full_name'] ?? '');
        // Fix: Never save empty user_type — fallback to 'customer'
        final userType = userData['user_type']?.toString() ?? '';
        await prefs.setString('user_type', userType.isNotEmpty ? userType : 'customer');
        await prefs.setString('profile_photo', userData['profile_photo_url'] ?? '');
        return userData;
      }
      return null;
    } catch (e) {
      print('Get me error: $e');
      return null;
    }
  }

  Future<Result<Map<String, dynamic>, ApiException>> updateProfile({
    String? firstName,
    String? lastName,
    String? email,
    String? phone,
  }) async {
    try {
      final Map<String, dynamic> data = {};
      if (firstName != null) data['first_name'] = firstName;
      if (lastName != null) data['last_name'] = lastName;
      if (email != null) data['email'] = email;
      if (phone != null && phone.isNotEmpty) data['phone_number'] = phone;

      final response = await _apiService.client.put(
        '${ApiConstants.register}update_profile/',
        data: data,
      );

      if (response.statusCode == 200) {
        final userData = response.data;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_email', userData['email'] ?? '');
        await prefs.setString('full_name', userData['full_name'] ?? '');
        await prefs.setString('profile_photo', userData['profile_photo_url'] ?? '');
        
        final userType = userData['user_type']?.toString() ?? '';
        if (userType.isNotEmpty) {
          await prefs.setString('user_type', userType);
        }
        return Success(userData);
      }
      return Failure(ApiException('فشل تحديث البيانات. رمز الخطأ: ${response.statusCode}'));
    } on DioException catch (e) {
      String errorMessage = 'فشل تحديث البيانات، يرجى المحاولة لاحقاً';
      if (e.response?.data != null) {
        final data = e.response?.data;
        if (data is Map) {
          if (data.containsKey('phone_number')) {
             errorMessage = 'رقم الهاتف: ${data['phone_number'][0]}';
          } else if (data.containsKey('email')) {
             errorMessage = 'البريد: ${data['email'][0]}';
          } else {
             errorMessage = data.values.first is List ? data.values.first[0].toString() : data.values.first.toString();
          }
        }
      }
      return Failure(ApiException(errorMessage));
    } catch (e) {
      return Failure(ApiException(e.toString()));
    }
  }

  Future<bool> registerDeviceToken(String token, String deviceType) async {
    try {
      final response = await _apiService.client.post(
        ApiConstants.deviceToken,
        data: {
          'token': token,
          'device_type': deviceType,
        },
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      print('Device token registration error: $e');
      return false;
    }
  }
}
