import 'package:flutter/material.dart';
import '../../core/widgets/glass_box.dart';
import '../../core/models/booking_model.dart';
import '../../core/main_navigation.dart';
import 'booking_repository.dart';
import 'booking_detail_view.dart';
import 'chat_screen.dart';
import 'package:intl/intl.dart';
import 'dart:async';

class MyBookingsScreen extends StatefulWidget {
  const MyBookingsScreen({super.key});

  @override
  State<MyBookingsScreen> createState() => _MyBookingsScreenState();
}

class _MyBookingsScreenState extends State<MyBookingsScreen> {
  final _bookingRepository = BookingRepository();
  StreamSubscription? _bookingsSubscription;
  List<Booking> _bookings = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBookings();

    // ✅ Real-time: Listen to FCM notifications to auto-refresh bookings
    // When a booking status changes (confirmed, cancelled, etc.) or a new
    // booking arrives, this callback fires and reloads the list instantly
    addNotificationListener(_onNotificationRefresh);
  }

  @override
  void dispose() {
    _bookingsSubscription?.cancel();
    // ✅ Unregister FCM listener
    removeNotificationListener(_onNotificationRefresh);
    super.dispose();
  }

  /// ✅ Called when any FCM notification arrives — invalidates cache & reloads
  void _onNotificationRefresh() {
    BookingRepository.invalidateCache();
    _loadBookings();
  }

  Future<void> _loadBookings() async {
    // ⚡ Performance Mutation: Listen to the SWR Stream
    _bookingsSubscription?.cancel();
    _bookingsSubscription = _bookingRepository.getMyBookingsStream().listen((bookings) {
      if (mounted) {
        setState(() {
          // 🔃 Sort by ID descending (Latest first)
          _bookings = List.from(bookings)..sort((a, b) => b.id.compareTo(a.id));
          _isLoading = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'حجوزاتي',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFD4AF37)))
          : _bookings.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadBookings,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    itemCount: _bookings.length,
                    itemBuilder: (context, index) => _buildBookingCard(_bookings[index]),
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.calendar_today, size: 80, color: Colors.white.withOpacity(0.05)),
          const SizedBox(height: 16),
          const Text(
            'لا توجد حجوزات حتى الآن',
            style: TextStyle(color: Colors.white70, fontSize: 18),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD4AF37),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('احجز الآن', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingCard(Booking booking) {
    Color statusColor;
    String statusAr;
    switch (booking.status.toLowerCase()) {
      case 'confirmed': 
        statusColor = Colors.green; 
        statusAr = 'مؤكد';
        break;
      case 'pending': 
        statusColor = Colors.orange; 
        statusAr = 'قيد الانتظار';
        break;
      case 'cancelled': 
        statusColor = Colors.red; 
        statusAr = 'ملغى';
        break;
      case 'completed':
        statusColor = Colors.blue;
        statusAr = 'مكتمل';
        break;
      default: 
        statusColor = Colors.white54;
        statusAr = 'غير معروف';
    }

    return GestureDetector(
      onTap: () async {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => BookingDetailView(booking: booking)),
        );
        if (result == true) {
          _loadBookings();
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        child: GlassBox(
          borderRadius: 20,
          opacity: 0.05,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        booking.barbershopName,
                        style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chat, color: Color(0xFFD4AF37)),
                      tooltip: 'محادثة',
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChatScreen(
                              bookingId: booking.id,
                              barbershopName: booking.barbershopName,
                            ),
                          ),
                        );
                      },
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: statusColor.withOpacity(0.3)),
                      ),
                      child: Text(
                        statusAr,
                        style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(Icons.location_on, size: 16, color: Colors.white38),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        booking.barbershopAddress,
                        style: const TextStyle(color: Colors.white38, fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (booking.staffName != null && booking.staffName!.isNotEmpty) ...[
                  Row(
                    children: [
                      const Icon(Icons.person, size: 16, color: Color(0xFFD4AF37)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'الحلاق: ${booking.staffName}',
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
                if (booking.serviceList.isNotEmpty) ...[
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: booking.serviceList.map((service) => GlassBox(
                      borderRadius: 8,
                      opacity: 0.1,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        child: Text(service, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                      ),
                    )).toList(),
                  ),
                  const SizedBox(height: 16),
                ],
                Row(
                  children: [
                    const Icon(Icons.event, color: Colors.white54, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        DateFormat('EEEE, d MMMM', 'ar').format(booking.bookingDay),
                        style: const TextStyle(color: Colors.white70, fontSize: 14),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD4AF37).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.4)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.confirmation_number, color: Color(0xFFD4AF37), size: 16),
                          const SizedBox(width: 4),
                          Text(
                            'دور رقم: ${booking.queueNumber}',
                            style: const TextStyle(color: Color(0xFFD4AF37), fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // ── Advanced Queue State UI (Derived from Server Architecture) ──
                if ((booking.status == 'pending' || booking.status == 'confirmed') && booking.queueNumber > 0) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: booking.peopleAhead == 0 
                          ? Colors.green.withOpacity(0.1) 
                          : Colors.indigo.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: booking.peopleAhead == 0 
                            ? Colors.green.withOpacity(0.3) 
                            : Colors.indigo.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          booking.peopleAhead == 0 ? Icons.check_circle_outline : Icons.groups,
                          color: booking.peopleAhead == 0 ? Colors.green : Colors.indigoAccent,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'الصالون يخدم الآن رقم: ${booking.currentServingQueue}',
                                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                booking.peopleAhead == 0 
                                    ? 'استعد! دورك الآن أو التالي مباشرة 🔥' 
                                    : 'متبقي أمامك ${booking.peopleAhead} ${booking.peopleAhead == 1 ? "شخص" : "أشخاص"}',
                                style: TextStyle(
                                  color: booking.peopleAhead == 0 ? Colors.green : Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                // ────────────────────────────────────────────────────────────────

                const Divider(height: 32, color: Colors.white12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'إجمالي الحساب (تقريبي)',
                      style: TextStyle(color: Colors.white54, fontSize: 14),
                    ),
                    Text(
                      '${booking.totalPrice} \$',
                      style: const TextStyle(color: Color(0xFFD4AF37), fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
