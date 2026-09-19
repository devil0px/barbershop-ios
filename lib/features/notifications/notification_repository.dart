import '../../core/network/api_service.dart';
import '../../core/constants/api_constants.dart';

class NotificationModel {
  final int id;
  final String title;
  final String message;
  final String type;
  final bool isRead;
  final DateTime createdAt;
  final int? bookingId;

  NotificationModel({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.isRead,
    required this.createdAt,
    this.bookingId,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      message: json['message'] ?? '',
      // Backend sends 'notification_type', handle both keys
      type: json['notification_type'] ?? json['type'] ?? '',
      isRead: json['is_read'] ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      bookingId: json['booking_id'] ?? json['booking'],
    );
  }
}

class NotificationRepository {
  final ApiService _apiService = ApiService();

  Future<List<NotificationModel>> getNotifications() async {
    try {
      final response = await _apiService.client.get(ApiConstants.notifications);
      if (response.statusCode == 200) {
        final dynamic responseData = response.data;
        List<dynamic> dataList;
        
        // Handle CoreJSONRenderer wrapping
        dynamic data = responseData;
        if (data is Map && data.containsKey('data')) {
          data = data['data'];
        }
        
        if (data is Map && data.containsKey('results')) {
          dataList = data['results'];
        } else if (data is List) {
          dataList = data;
        } else {
          return [];
        }
        return dataList.map((json) => NotificationModel.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<void> markAsRead(int id) async {
    try {
      await _apiService.client.post(ApiConstants.notificationRead(id));
    } catch (e) {
      // Handle error silently
    }
  }

  Future<int> getUnreadCount() async {
    try {
      final response = await _apiService.client.get(ApiConstants.notificationsUnreadCount);
      if (response.statusCode == 200) {
        final data = response.data;
        if (data is Map) {
          // Handle both direct and wrapped response
          if (data.containsKey('data') && data['data'] is Map) {
            return data['data']['unread_count'] ?? 0;
          }
          return data['unread_count'] ?? 0;
        }
        return 0;
      }
      return 0;
    } catch (e) {
      return 0;
    }
  }

  Future<void> markAllAsRead() async {
    try {
      await _apiService.client.post(ApiConstants.notificationsMarkAllRead);
    } catch (e) {
      // Handle error silently
    }
  }
}
