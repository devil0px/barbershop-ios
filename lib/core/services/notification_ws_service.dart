import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as ws_status;
import '../constants/api_constants.dart';
import 'notification_service.dart';

/// NotificationWsService
/// ─────────────────────────────────────────────────────────────────────────
/// Maintains a persistent WebSocket connection to the user's personal
/// notification channel (user_{id}_notifications).
///
/// When a new notification arrives:
///   1. Calls the global [onNotificationReceived] callback → refreshes any
///      listening screen instantly (badge count, notification list, dashboard).
///   2. Shows a local notification banner via the SHARED
///      [NotificationService.showLocalAlert] — uses the same plugin instance
///      as FCM foreground to avoid channel conflicts.
///
/// Designed to run for the lifetime of the app session (login → logout).
/// ─────────────────────────────────────────────────────────────────────────
class NotificationWsService {
  static final NotificationWsService _instance =
      NotificationWsService._internal();
  factory NotificationWsService() => _instance;
  NotificationWsService._internal();

  // ── State ──────────────────────────────────────────────────────────────
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  bool _isConnected = false;
  bool _shouldReconnect = false;
  Timer? _reconnectTimer;
  int _reconnectDelay = 3; // seconds, grows with back-off up to 60s
  int? _userId;

  // ── Public API ─────────────────────────────────────────────────────────

  /// Call after login — loads the user id and starts listening.
  Future<void> connect() async {
    final prefs = await SharedPreferences.getInstance();
    // user_id is stored as a String (see auth_repository.dart)
    final userIdStr = prefs.getString('user_id');
    _userId = userIdStr != null ? int.tryParse(userIdStr) : null;
    if (_userId == null) {
      debugPrint('⚠️ NotificationWsService: user_id not found, cannot connect');
      return;
    }
    _shouldReconnect = true;
    _doConnect();
  }

  /// Call on logout — closes the connection and stops auto-reconnect.
  void disconnect() {
    _shouldReconnect = false;
    _reconnectTimer?.cancel();
    _subscription?.cancel();
    _channel?.sink.close(ws_status.goingAway);
    _channel = null;
    _isConnected = false;
    debugPrint('🔌 NotificationWsService: disconnected');
  }

  bool get isConnected => _isConnected;

  // ── Internal ───────────────────────────────────────────────────────────

  void _doConnect() async {
    if (_userId == null) return;

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token') ?? '';
    final wsUrl = Uri.parse('${ApiConstants.wsBaseUrl}/notifications/$_userId/?token=$token');
    debugPrint('🔌 NotificationWsService: connecting to $wsUrl');

    try {
      _channel = WebSocketChannel.connect(wsUrl);
      _subscription = _channel!.stream.listen(
        _onMessage,
        onError: _onError,
        onDone: _onDone,
        cancelOnError: false,
      );
      _isConnected = true;
      _reconnectDelay = 3; // reset back-off on successful connect
      debugPrint('✅ NotificationWsService: connected');
    } catch (e) {
      debugPrint('❌ NotificationWsService: connect failed — $e');
      _scheduleReconnect();
    }
  }

  void _onMessage(dynamic rawMessage) {
    try {
      final data = jsonDecode(rawMessage as String) as Map<String, dynamic>;
      final type = data['type'] as String? ?? '';

      debugPrint('📩 NotificationWS: received type=$type');

      if (type == 'new_notification') {
        final title = data['title'] as String? ?? 'إشعار جديد';
        final message = data['message'] as String? ?? '';
        final notificationType = data['notification_type'] as String? ?? '';
        final bookingId = data['booking_id'];

        // 1️⃣ Refresh any listening screens (badge, notification list, etc.)
        onNotificationReceived?.call();

        // 2️⃣ Muted the local banner from WebSocket because FCM already triggers it.
        // This prevents duplicate notifications from appearing at the same time.
        /*
        NotificationService.showLocalAlert(
          title: title,
          body: message,
          payload: jsonEncode({
            'type': notificationType,
            'booking_id': bookingId?.toString() ?? '',
          }),
          idPrefix: 100000, // offset to avoid colliding with FCM notification IDs
        );
        */
      }
    } catch (e) {
      debugPrint('⚠️ NotificationWsService: failed to parse message — $e');
    }
  }

  void _onError(Object error) {
    debugPrint('❌ NotificationWsService: error — $error');
    _isConnected = false;
    _scheduleReconnect();
  }

  void _onDone() {
    debugPrint('🔌 NotificationWsService: connection closed');
    _isConnected = false;
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (!_shouldReconnect) return;
    _reconnectTimer?.cancel();
    debugPrint(
        '🔄 NotificationWsService: reconnecting in $_reconnectDelay seconds...');
    _reconnectTimer = Timer(Duration(seconds: _reconnectDelay), () {
      if (_shouldReconnect) _doConnect();
    });
    // Exponential back-off capped at 60s
    _reconnectDelay = (_reconnectDelay * 2).clamp(3, 60);
  }
}
