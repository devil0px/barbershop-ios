import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../constants/api_constants.dart';

class VersionCheckResult {
  final bool isUpdateRequired;
  final String title;
  final String message;
  final String storeUrl;
  final String buttonText;

  VersionCheckResult({
    required this.isUpdateRequired,
    this.title = 'تحديث جديد متوفر',
    this.message =
        'يتوفر إصدار جديد من تطبيق Barbershop. يرجى التحديث للمتابعة والاستفادة من كافة الخدمات.',
    this.storeUrl =
        'https://play.google.com/store/apps/details?id=com.barber2shop',
    this.buttonText = 'تحديث الآن',
  });
}

class VersionCheckService {
  static Future<VersionCheckResult> checkVersion() async {
    try {
      final dio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 7),
        receiveTimeout: const Duration(seconds: 7),
      ));

      final response = await dio.get(ApiConstants.appVersion);

      if (response.statusCode == 200 && response.data != null) {
        Map<String, dynamic> data = {};
        String? serverMessage;

        if (response.data is Map<String, dynamic>) {
          final rootMap = response.data as Map<String, dynamic>;
          if (rootMap.containsKey('message') && rootMap['message'] is String) {
            serverMessage = rootMap['message'];
          }
          if (rootMap.containsKey('data') && rootMap['data'] is Map) {
            data = Map<String, dynamic>.from(rootMap['data']);
          } else {
            data = rootMap;
          }
        }

        final int minVersionCode =
            int.tryParse(data['min_version_code']?.toString() ?? '0') ?? 0;
        final bool forceUpdate = data['force_update'] ?? true;
        final String storeUrl = data['store_url'] ??
            'https://play.google.com/store/apps/details?id=com.barber2shop';
        final String title = data['title'] ?? 'تحديث جديد متوفر';
        final String message = serverMessage ??
            data['message'] ??
            'يتوفر إصدار جديد وأكثر استقراراً من تطبيق Barbershop. يرجى التحديث للمتابعة والاستفادة من كافة الخدمات.';
        final String buttonText = data['button_text'] ?? 'تحديث الآن';

        // Check if installed version code is lower than minimum required version code
        if (ApiConstants.currentVersionCode < minVersionCode && forceUpdate) {
          debugPrint(
              '🚨 Update required! Installed: ${ApiConstants.currentVersionCode}, Required: $minVersionCode');
          return VersionCheckResult(
            isUpdateRequired: true,
            title: title,
            message: message,
            storeUrl: storeUrl,
            buttonText: buttonText,
          );
        }
      }
    } catch (e) {
      debugPrint('Version check bypassed due to network error: $e');
    }

    return VersionCheckResult(isUpdateRequired: false);
  }
}
