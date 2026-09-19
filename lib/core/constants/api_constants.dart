class ApiConstants {
  // السيرفر البعيد
  static const String baseUrl = 'https://64.226.87.65.nip.io/api/v1';
  
  // WebSocket base URL
  static const String wsBaseUrl = 'wss://64.226.87.65.nip.io/ws';
  
  // Auth endpoints
  static const String login = '$baseUrl/accounts/token/';
  static const String tokenRefresh = '$baseUrl/accounts/token/refresh/';
  static const String register = '$baseUrl/accounts/users/';
  static const String logout = '$baseUrl/accounts/logout/';
  static const String profile = '$baseUrl/accounts/profile/';
  static const String googleLogin = '$baseUrl/accounts/google-signin/';
  
  // Barbershop endpoints
  static const String barbershops = '$baseUrl/barbershops/barbershops/';
  static String barbershopServices(int id) => '$barbershops$id/services/';
  static String barbershopStaff(int id) => '$barbershops$id/staff/';
  static String barbershopReviews(int id) => '$barbershops$id/reviews/';
  static String checkAvailability(int id) => '$barbershops$id/check-availability/';
  static String barbershopWorkingHours(int id) => '$barbershops$id/working_hours/';
  
  static const String services = '$baseUrl/barbershops/services/';
  
  // Booking endpoints
  static const String bookings = '$baseUrl/bookings/bookings/';
  
  // Review endpoints
  static const String reviews = '$baseUrl/reviews/reviews/';
  
  // Notification endpoints
  static const String notifications = '$baseUrl/notifications/notifications/';
  static String notificationRead(int id) => '$notifications$id/mark_as_read/';
  static const String notificationsUnread = '${notifications}unread/';
  static const String notificationsUnreadCount = '${notifications}unread_count/';
  static const String notificationsMarkAllRead = '${notifications}mark_all_read/';
  
  // WebSocket endpoints
  static String chatWebSocket(int bookingId) => '$wsBaseUrl/chat/$bookingId/';
  static String barbershopTurnWebSocket(int shopId) => '$wsBaseUrl/barbershop/$shopId/';
}
