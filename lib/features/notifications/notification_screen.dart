import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/widgets/glass_box.dart';
import '../../features/notifications/notification_repository.dart';
import '../../features/booking/chat_screen.dart';
import '../../core/main_navigation.dart';
import '../../core/services/notification_service.dart';

class NotificationScreen extends StatefulWidget {
  final VoidCallback? onRead;
  const NotificationScreen({super.key, this.onRead});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final _repository = NotificationRepository();
  List<NotificationModel> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();

    // ✅ Auto-refresh: register with the multi-listener hub.
    // When any FCM arrives, _loadNotifications is called — regardless of
    // how many other screens also registered a listener.
    addNotificationListener(_loadNotifications);
  }

  @override
  void dispose() {
    // ✅ Unregister so we don't get called after the screen is gone.
    removeNotificationListener(_loadNotifications);
    super.dispose();
  }

  Future<void> _loadNotifications() async {
    final list = await _repository.getNotifications();
    if (mounted) {
      setState(() {
        _notifications = list;
        _isLoading = false;
      });
    }
  }

  Future<void> _markAsRead(NotificationModel notification) async {
    if (!notification.isRead) {
      await _repository.markAsRead(notification.id);
      // Refresh the list and badge
      await _loadNotifications();
      widget.onRead?.call();
    }
  }

  Future<void> _markAllAsRead() async {
    await _repository.markAllAsRead();
    await _loadNotifications();
    widget.onRead?.call();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم تحديد جميع الإشعارات كمقروءة'),
          backgroundColor: Color(0xFF2A2A2A),
        ),
      );
    }
  }

  void _onNotificationTap(NotificationModel notification) {
    _markAsRead(notification);

    // Navigate based on notification type
    switch (notification.type) {
      case 'new_message':
        // ✅ Navigate directly to ChatScreen if we have a bookingId
        if (notification.bookingId != null && notification.bookingId! > 0) {
          _switchToTab(1); // switch to bookings tab so back-nav works
          Future.delayed(const Duration(milliseconds: 150), () {
            if (mounted) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ChatScreen(
                    bookingId: notification.bookingId!,
                    barbershopName: 'الصالون',
                  ),
                ),
              );
            }
          });
        } else {
          _switchToTab(1);
        }
        break;

      case 'new_booking':
        // ✅ Barber → dashboard tab (0). Customer → bookings tab (1)
        // We read user_type from SharedPreferences via the repository
        _switchToTabForNewBooking();
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
        break;
    }
  }

  void _switchToTabForNewBooking() async {
    // Can't import SharedPreferences directly here so use the navState user_type
    try {
      final navState = context.findAncestorStateOfType<MainNavigationContainerState>();
      if (navState != null) {
        // barber → tab 0 (owner dashboard), customer → tab 1
        navState.setSelectedIndex(navState.userType == 'barber' ? 0 : 1);
      }
    } catch (e) {
      _switchToTab(1);
    }
  }

  void _switchToTab(int index) {
    try {
      final navState = context.findAncestorStateOfType<MainNavigationContainerState>();
      if (navState != null) {
        navState.setSelectedIndex(index);
      }
    } catch (e) {
      debugPrint('Could not switch tab: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasUnread = _notifications.any((n) => !n.isRead);

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('الإشعارات', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          if (hasUnread)
            TextButton.icon(
              onPressed: _markAllAsRead,
              icon: const Icon(Icons.done_all, size: 18, color: Color(0xFFD4AF37)),
              label: const Text('قراءة الكل', style: TextStyle(color: Color(0xFFD4AF37), fontSize: 12)),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFD4AF37)))
          : RefreshIndicator(
              onRefresh: _loadNotifications,
              child: _notifications.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.all(20),
                      itemCount: _notifications.length,
                      itemBuilder: (context, index) => _buildNotificationItem(_notifications[index]),
                    ),
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFFD4AF37).withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.notifications_off_outlined, size: 36, color: Color(0xFFD4AF37)),
          ),
          const SizedBox(height: 20),
          const Text('لا توجد إشعارات حالياً', style: TextStyle(color: Colors.white54, fontSize: 16)),
          const SizedBox(height: 8),
          const Text('ستظهر الإشعارات هنا عند الحجز أو استلام رسائل', style: TextStyle(color: Colors.white30, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildNotificationItem(NotificationModel notification) {
    return GestureDetector(
      onTap: () => _onNotificationTap(notification),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.only(bottom: 12),
        child: GlassBox(
          borderRadius: 16,
          opacity: notification.isRead ? 0.02 : 0.08,
          border: notification.isRead ? null : Border.all(color: const Color(0xFFD4AF37).withOpacity(0.3)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _getColorForType(notification.type).withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _getIconForType(notification.type),
                    color: _getColorForType(notification.type),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              notification.title,
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: notification.isRead ? FontWeight.normal : FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          // Unread indicator dot
                          if (!notification.isRead)
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Color(0xFFD4AF37),
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        notification.message,
                        style: const TextStyle(color: Colors.white60, fontSize: 13, height: 1.4),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _formatTimeAgo(notification.createdAt),
                        style: const TextStyle(color: Colors.white30, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'new_booking': return Icons.calendar_today;
      case 'booking_confirmed': return Icons.check_circle_outline;
      case 'booking_cancelled': return Icons.cancel_outlined;
      case 'booking_completed': return Icons.star_outline;
      case 'new_message': return Icons.chat_bubble_outline;
      case 'turn_updated': return Icons.confirmation_number_outlined;
      case 'review_added': return Icons.star;
      default: return Icons.notifications_none;
    }
  }

  Color _getColorForType(String type) {
    switch (type) {
      case 'new_booking': return Colors.orange;
      case 'booking_confirmed': return Colors.green;
      case 'booking_cancelled': return Colors.red;
      case 'booking_completed': return Colors.blue;
      case 'new_message': return const Color(0xFFD4AF37);
      case 'turn_updated': return Colors.cyan;
      case 'review_added': return Colors.amber;
      default: return Colors.white54;
    }
  }

  String _formatTimeAgo(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) return 'الآن';
    if (difference.inMinutes < 60) return 'منذ ${difference.inMinutes} دقيقة';
    if (difference.inHours < 24) return 'منذ ${difference.inHours} ساعة';
    if (difference.inDays == 1) return 'أمس';
    if (difference.inDays < 7) return 'منذ ${difference.inDays} أيام';
    return DateFormat('d MMM yyyy', 'ar').format(date);
  }
}
