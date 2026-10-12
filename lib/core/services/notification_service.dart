import 'dart:async';
import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/auth/auth_repository.dart';
import '../../features/booking/chat_screen.dart';
import '../main_navigation.dart';

/// Global navigator key for notification-based navigation
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// Global callback — called when any FCM message arrives (foreground)
/// Screens can listen to this to refresh themselves immediately
typedef NotificationCallback = void Function();
NotificationCallback? onNotificationReceived;

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final AuthRepository _authRepository = AuthRepository();

  /// ✅ SINGLE shared local notification plugin instance
  /// Used by NotificationService, NotificationWsService, and background handler.
  static final FlutterLocalNotificationsPlugin localNotifications =
      FlutterLocalNotificationsPlugin();

  /// Android notification channel
  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'barbershop_high_importance',
    'إشعارات الصالون',
    description: 'إشعارات الحجوزات والرسائل من تطبيق الصالون',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
    showBadge: true,
  );

  /// Track whether we have already initialized
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;

    // 1. Setup local notifications and high importance channel FIRST
    await _setupLocalNotifications();

    // 2. Request Android 13+ runtime POST_NOTIFICATIONS permission
    try {
      final androidPlugin = localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await androidPlugin?.requestNotificationsPermission();
    } catch (e) {
      debugPrint('Android requestNotificationsPermission error: $e');
    }

    // 3. Request FCM messaging permission
    try {
      await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: true,
      );
    } catch (e) {
      debugPrint('FCM requestPermission error: $e');
    }

    // ✅ 3. CRITICAL: Set foreground notification presentation options
    // This ensures FCM shows notifications even when the app is in foreground on iOS
    // On Android, we handle it via flutter_local_notifications instead
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // 4. Register FCM token
    await registerToken();

    // 5. Handle token refreshes
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
      debugPrint('🔄 FCM Token refreshed');
      _authRepository.registerDeviceToken(newToken, 'android');
    });

    // 6. Handle app launched from TERMINATED state via notification tap
    RemoteMessage? initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      debugPrint('📩 App opened from terminated state via notification');
      // Delay navigation to ensure the app is fully mounted
      Future.delayed(const Duration(seconds: 2), () {
        _handleNotificationTap(initialMessage.data);
      });
    }

    // 7. Handle notification tap when app is in BACKGROUND (not terminated)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('📩 Notification tapped (background): ${message.data}');
      _handleNotificationTap(message.data);
    });

    // 8. Handle FOREGROUND messages → show local notification banner
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('📩 Foreground FCM: ${message.notification?.title}');
      _showFcmLocalNotification(message);

      // ✅ Trigger refresh callback so ALL listening screens update live
      // This dispatches to notification screen, booking screens, dashboard, etc.
      onNotificationReceived?.call();
    });

    _initialized = true;
    debugPrint('✅ NotificationService fully initialized');
  }

  /// Setup flutter_local_notifications plugin
  static Future<void> _setupLocalNotifications() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
    );

    await localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        debugPrint('📩 Local notification tapped: ${response.payload}');
        if (response.payload != null) {
          try {
            final data = jsonDecode(response.payload!);
            _handleNotificationTap(Map<String, dynamic>.from(data));
          } catch (e) {
            debugPrint('Error parsing notification payload: $e');
          }
        }
      },
    );

    // Create the Android notification channel
    final androidPlugin =
        localNotifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.createNotificationChannel(_channel);
      debugPrint('✅ Notification channel created: ${_channel.id}');
    }
  }

  /// ✅ PUBLIC API: Show a local notification alert.
  /// Used by both FCM foreground handler and WebSocket notification service.
  /// [idPrefix] is used to prevent ID collisions between different sources.
  static Future<void> showLocalAlert({
    required String title,
    required String body,
    String? payload,
    int idPrefix = 0,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      _channel.id,
      _channel.name,
      channelDescription: _channel.description,
      importance: Importance.max,
      priority: Priority.max,
      icon: '@mipmap/ic_launcher',
      color: const Color(0xFFD4AF37),
      playSound: true,
      enableVibration: true,
      // ✅ Show on lock screen
      visibility: NotificationVisibility.public,
      // ✅ Show ticker text in status bar
      ticker: title,
      // ✅ Category for message-style notifications
      category: AndroidNotificationCategory.message,
      styleInformation: BigTextStyleInformation(
        body,
        contentTitle: title,
      ),
    );

    final details = NotificationDetails(android: androidDetails);

    // ✅ Generate unique notification ID
    // idPrefix prevents collision between FCM (0) and WebSocket (100000) sources
    final notificationId =
        idPrefix + (DateTime.now().millisecondsSinceEpoch % 100000);

    await localNotifications.show(
      notificationId,
      title,
      body,
      details,
      payload: payload,
    );
    debugPrint('🔔 Local alert shown (id=$notificationId): $title');
  }

  /// Show a local notification banner when FCM arrives in foreground
  static Future<void> _showFcmLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    // Encode FCM data as payload so we can handle taps correctly
    final payload = jsonEncode(message.data);

    await showLocalAlert(
      title: notification.title ?? 'إشعار جديد',
      body: notification.body ?? '',
      payload: payload,
      idPrefix: 0, // FCM source
    );
  }

  /// Handle notification tap → navigate to the correct screen
  static void _handleNotificationTap(Map<String, dynamic> data) async {
    final type = data['type'] ?? '';
    final bookingIdStr = data['booking_id'] ?? '';
    final navigator = navigatorKey.currentState;

    if (navigator == null) {
      debugPrint('⚠️ Navigator not ready for notification routing');
      return;
    }

    debugPrint('🔀 Routing: type=$type, booking_id=$bookingIdStr');

    // Ensure we're at the root (MainNavigation) first
    navigator.pushNamedAndRemoveUntil('/', (route) => false);

    // Small delay to let the MainNavigationContainer mount
    await Future.delayed(const Duration(milliseconds: 500));

    switch (type) {
      case 'new_message':
        // Navigate directly to ChatScreen if we have a booking_id
        final bookingId = int.tryParse(bookingIdStr);
        if (bookingId != null && bookingId > 0) {
          // First switch to bookings tab so back-nav works correctly
          _switchToTab(1);
          await Future.delayed(const Duration(milliseconds: 200));
          navigator.push(
            MaterialPageRoute(
              builder: (context) => ChatScreen(
                bookingId: bookingId,
                barbershopName: 'الصالون',
              ),
            ),
          );
        } else {
          _switchToTab(1);
        }
        break;

      case 'new_booking':
        // ✅ For barbers: go to Dashboard (index 0) — that's where they accept/reject
        // For customers: go to My Bookings (index 1)
        final prefs = await SharedPreferences.getInstance();
        final userType = prefs.getString('user_type') ?? 'customer';
        if (userType == 'barber') {
          _switchToTab(0); // Owner Dashboard
        } else {
          _switchToTab(1); // My Bookings
        }
        break;

      case 'booking_confirmed':
      case 'booking_cancelled':
      case 'booking_completed':
      case 'booking_rejected':
      case 'turn_updated':
        // Customer: go to My Bookings
        _switchToTab(1);
        break;

      default:
        // Anything else → Notifications tab
        _switchToTab(2);
    }
  }

  /// Switch the bottom navigation tab
  static void _switchToTab(int index) {
    try {
      final context = navigatorKey.currentContext;
      if (context != null) {
        final navState =
            context.findAncestorStateOfType<MainNavigationContainerState>();
        if (navState != null) {
          navState.setSelectedIndex(index);
        }
      }
    } catch (e) {
      debugPrint('Could not switch tab: $e');
    }
  }

  /// Register device token with backend.
  /// Uses refresh_token to check if user is "logged in" (not access_token,
  /// which can expire and cause the token to go unregistered).
  static Future<void> registerToken() async {
    try {
      // ✅ Use refresh_token as the logged-in signal — it lives much longer
      // than access_token and is still valid when the app is in the background.
      final prefs = await SharedPreferences.getInstance();
      final refreshToken = prefs.getString('refresh_token');
      if (refreshToken == null || refreshToken.isEmpty) {
        debugPrint('⚠️ Not logged in — skipping device token registration');
        return;
      }

      String? token = await _messaging.getToken();
      if (token != null) {
        debugPrint('📱 Registering Device Token: ${token.substring(0, 20)}...');
        await _authRepository.registerDeviceToken(token, 'android');
      }
    } catch (e) {
      debugPrint('Error registering device token: $e');
    }
  }
}
