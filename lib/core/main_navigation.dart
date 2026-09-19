import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../features/auth/auth_repository.dart';
import '../features/barber/home_screen.dart';
import '../features/booking/my_bookings_screen.dart';
import '../features/notifications/notification_screen.dart';
import '../features/notifications/notification_repository.dart';
import '../features/owner/barber_bookings_history_screen.dart';
import '../features/auth/profile_screen.dart';
import '../features/owner/owner_dashboard_screen.dart';
import 'services/notification_service.dart';

/// Multi-listener notification hub.
/// Any screen can add itself here to be notified when an FCM arrives.
/// This replaces the single-callback pattern that caused screens to fight each other.
final Set<NotificationCallback> _globalNotificationListeners = {};

void addNotificationListener(NotificationCallback cb) {
  _globalNotificationListeners.add(cb);
}

void removeNotificationListener(NotificationCallback cb) {
  _globalNotificationListeners.remove(cb);
}

void _dispatchNotification() {
  debugPrint('🔔 Dispatching notification to ${_globalNotificationListeners.length} listeners');
  for (final cb in List<NotificationCallback>.from(_globalNotificationListeners)) {
    try {
      cb();
    } catch (e) {
      debugPrint('Error in notification listener: $e');
    }
  }
}

class MainNavigationContainer extends StatefulWidget {
  const MainNavigationContainer({super.key, this.initialIndex = 0});
  final int initialIndex;

  @override
  State<MainNavigationContainer> createState() => MainNavigationContainerState();

  static MainNavigationContainerState? of(BuildContext context) {
    return context.findAncestorStateOfType<MainNavigationContainerState>();
  }
}

class MainNavigationContainerState extends State<MainNavigationContainer>
    with WidgetsBindingObserver {
  late int _selectedIndex;
  String _userType = 'customer';
  bool _isLoading = true;
  int _unreadNotificationCount = 0;
  final _notificationRepository = NotificationRepository();

  /// ✅ Periodic refresh timer — backup mechanism for real-time updates
  Timer? _periodicRefreshTimer;

  /// ✅ WebSocket channel للإشعارات الشخصية من السيرفر
  WebSocketChannel? _notificationWsChannel;
  StreamSubscription? _notificationWsSubscription;
  Timer? _wsReconnectTimer;
  int _wsReconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
    _loadUserType();
    _loadUnreadCount();

    // ✅ Use multi-listener hub so screens can chain without overwriting each other
    addNotificationListener(_loadUnreadCount);
    // Also hook the global single callback → dispatch to all listeners
    onNotificationReceived = _dispatchNotification;

    // ✅ Observe app lifecycle to refresh when app comes back to foreground
    WidgetsBinding.instance.addObserver(this);

    // ✅ Start periodic polling as a backup (every 30 seconds)
    _periodicRefreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _loadUnreadCount(),
    );

    // ✅ Connect to notifications WebSocket after a short delay
    // (wait for user type to load first)
    Future.delayed(const Duration(milliseconds: 800), _connectNotificationsWs);
  }

  @override
  void dispose() {
    removeNotificationListener(_loadUnreadCount);
    onNotificationReceived = null;
    _periodicRefreshTimer?.cancel();
    _wsReconnectTimer?.cancel();
    _notificationWsSubscription?.cancel();
    _notificationWsChannel?.sink.close();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// ✅ When app comes back from background, refresh everything + reconnect WS
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      debugPrint('📱 App resumed — refreshing notifications');
      _loadUnreadCount();
      _dispatchNotification();
      // Reconnect WS if it dropped while app was in background
      if (_notificationWsChannel == null) {
        _connectNotificationsWs();
      }
    }
  }

  /// ✅ Connect to personal notifications WebSocket
  Future<void> _connectNotificationsWs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final refreshToken = prefs.getString('refresh_token');
      if (refreshToken == null || refreshToken.isEmpty) {
        debugPrint('⚠️ NotificationWS: Not logged in — skipping');
        return;
      }

      final accessToken = prefs.getString('access_token') ?? '';
      final wsUrl = 'ws://64.226.87.65/ws/notifications/';
      final uri = Uri.parse(
        accessToken.isNotEmpty ? '$wsUrl?token=$accessToken' : wsUrl,
      );

      debugPrint('🔌 NotificationWS: Connecting...');
      _notificationWsChannel = WebSocketChannel.connect(uri);
      _wsReconnectAttempts = 0;

      _notificationWsSubscription = _notificationWsChannel!.stream.listen(
        (rawMessage) {
          try {
            final data = jsonDecode(rawMessage as String) as Map<String, dynamic>;
            if (data['type'] == 'new_notification') {
              debugPrint('📩 NotificationWS: New notification — dispatching');
              _loadUnreadCount();
              _dispatchNotification();
            }
          } catch (_) {}
        },
        onDone: () {
          debugPrint('🔌 NotificationWS: Connection closed — scheduling reconnect');
          _notificationWsChannel = null;
          _scheduleWsReconnect();
        },
        onError: (e) {
          debugPrint('❌ NotificationWS: Error: $e');
          _notificationWsChannel = null;
          _scheduleWsReconnect();
        },
        cancelOnError: false,
      );

      debugPrint('✅ NotificationWS: Connected');
    } catch (e) {
      debugPrint('❌ NotificationWS: Failed to connect: $e');
      _scheduleWsReconnect();
    }
  }

  void _scheduleWsReconnect() {
    if (_wsReconnectAttempts >= _maxReconnectAttempts) return;
    _wsReconnectTimer?.cancel();
    final delay = Duration(seconds: 2 << _wsReconnectAttempts);
    _wsReconnectAttempts++;
    debugPrint('🔄 NotificationWS: Reconnect in ${delay.inSeconds}s (attempt $_wsReconnectAttempts)');
    _wsReconnectTimer = Timer(delay, () {
      if (mounted) _connectNotificationsWs();
    });
  }

  Future<void> _loadUserType() async {
    final prefs = await SharedPreferences.getInstance();
    final savedType = prefs.getString('user_type');
    
    setState(() {
      // Fix: handle both null AND empty string — both should fallback to 'customer'
      _userType = (savedType != null && savedType.isNotEmpty) ? savedType : 'customer';
      _isLoading = false;
    });

    // 🔄 Background refresh: Sync user_type from server to survive role changes
    _refreshUserTypeFromServer();
  }

  Future<void> _refreshUserTypeFromServer() async {
    try {
      final userData = await AuthRepository().getMe();
      if (userData != null && mounted) {
        final serverType = userData['user_type']?.toString() ?? '';
        if (serverType.isNotEmpty && serverType != _userType) {
          setState(() {
            _userType = serverType;
          });
        }
      }
    } catch (_) {
      // Silent fail — local cache is still valid
    }
  }

  Future<void> _loadUnreadCount() async {
    try {
      final count = await _notificationRepository.getUnreadCount();
      if (mounted) {
        setState(() {
          _unreadNotificationCount = count;
        });
      }
    } catch (_) {}
  }

  void setSelectedIndex(int index) {
    setState(() {
      _selectedIndex = index;
    });
    // Refresh unread count when switching to notifications tab
    if (index == 2) {
      _loadUnreadCount();
    }
  }

  /// Public getter so child screens can read current user type
  String get userType => _userType;

  /// Called when returning from notification screen to refresh badge
  void refreshNotificationBadge() {
    _loadUnreadCount();
  }

  List<Widget> get _screens => [
    _userType == 'barber' ? const OwnerDashboardScreen() : const HomeScreen(),
    _userType == 'barber' ? const BarberBookingsHistoryScreen() : const MyBookingsScreen(),
    NotificationScreen(onRead: _loadUnreadCount),
    const ProfileScreen(),
  ];

  List<BottomNavigationBarItem> get _navItems => [
    BottomNavigationBarItem(
      icon: const Icon(Icons.home_outlined),
      activeIcon: const Icon(Icons.home_filled),
      label: _userType == 'barber' ? 'لوحة التحكم' : 'الرئيسية',
    ),
    const BottomNavigationBarItem(
      icon: Icon(Icons.calendar_today_outlined),
      activeIcon: Icon(Icons.calendar_month),
      label: 'حجوزاتي',
    ),
    BottomNavigationBarItem(
      icon: _buildNotificationIcon(false),
      activeIcon: _buildNotificationIcon(true),
      label: 'الإشعارات',
    ),
    const BottomNavigationBarItem(
      icon: Icon(Icons.person_outline),
      activeIcon: Icon(Icons.person),
      label: 'حسابي',
    ),
  ];

  Widget _buildNotificationIcon(bool isActive) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(isActive ? Icons.notifications : Icons.notifications_outlined),
        if (_unreadNotificationCount > 0)
          Positioned(
            right: -6,
            top: -4,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withOpacity(0.4),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              constraints: const BoxConstraints(
                minWidth: 16,
                minHeight: 16,
              ),
              child: Text(
                _unreadNotificationCount > 99
                    ? '99+'
                    : _unreadNotificationCount.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF1A1A1A),
        body: Center(child: CircularProgressIndicator(color: Color(0xFFD4AF37))),
      );
    }

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.5),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: setSelectedIndex,
          backgroundColor: const Color(0xFF1A1A1A),
          selectedItemColor: const Color(0xFFD4AF37),
          unselectedItemColor: Colors.white24,
          type: BottomNavigationBarType.fixed,
          showUnselectedLabels: true,
          selectedFontSize: 12,
          unselectedFontSize: 12,
          items: _navItems,
        ),
      ),
    );
  }
}
