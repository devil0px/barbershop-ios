import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/widgets/glass_box.dart';
import '../../core/models/booking_model.dart';
import 'booking_repository.dart';
import 'chat_screen.dart';

class BookingDetailView extends StatefulWidget {
  final Booking booking;
  const BookingDetailView({super.key, required this.booking});

  @override
  State<BookingDetailView> createState() => _BookingDetailViewState();
}

class _BookingDetailViewState extends State<BookingDetailView> {
  final _bookingRepository = BookingRepository();
  bool _isCancelling = false;

  Future<void> _cancelBooking() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('\u062a\u0623\u0643\u064a\u062f \u0627\u0644\u0625\u0644\u063a\u0627\u0621', style: TextStyle(color: Colors.white)),
        content: const Text('\u0647\u0644 \u0623\u0646\u062a \u0645\u062a\u0623\u0643\u062f \u0645\u0646 \u0625\u0644\u063a\u0627\u0621 \u0647\u0630\u0627 \u0627\u0644\u062d\u062c\u0632\u061f', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('\u062a\u0631\u0627\u062c\u0639', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent.withOpacity(0.8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('\u0646\u0639\u0645\u060c \u0623\u0644\u063a\u0650 \u0627\u0644\u062d\u062c\u0632', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      if (mounted) setState(() => _isCancelling = true);
      final result = await _bookingRepository.cancelBooking(widget.booking.id);
      if (mounted) {
        setState(() => _isCancelling = false);
        result.when(
          onSuccess: (_) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('\u062a\u0645 \u0625\u0644\u063a\u0627\u0621 \u0627\u0644\u062d\u062c\u0632 \u0628\u0646\u062c\u0627\u062d'),
                backgroundColor: Colors.green,
              ),
            );
            Navigator.pop(context, true);
          },
          onFailure: (err) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(err.message),
                backgroundColor: Colors.redAccent,
              ),
            );
          },
        );
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    final booking = widget.booking;
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('تفاصيل الدور', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Badge
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: _getStatusColor(booking.status).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: _getStatusColor(booking.status).withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.circle, size: 10, color: _getStatusColor(booking.status)),
                    const SizedBox(width: 8),
                    Text(
                      _getStatusText(booking.status),
                      style: TextStyle(color: _getStatusColor(booking.status), fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            // ── Combined Compact Queue Status ──
            GlassBox(
              borderRadius: 20,
              opacity: booking.peopleAhead == 0 ? 0.1 : 0.05,
              border: Border.all(
                color: booking.peopleAhead == 0 
                  ? Colors.green.withOpacity(0.3) 
                  : const Color(0xFFD4AF37).withOpacity(0.2)
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Queue Number Circle
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD4AF37).withOpacity(0.1),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.4)),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('دورك', style: TextStyle(color: Colors.white54, fontSize: 11)),
                          Text(
                            '${booking.queueNumber}',
                            style: const TextStyle(color: Color(0xFFD4AF37), fontSize: 32, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Live Queue Status
                    if ((booking.status.toLowerCase() == 'pending' || booking.status.toLowerCase() == 'confirmed') && booking.queueNumber > 0)
                      Expanded(
                        child: Column(
                          children: [
                            const Text('حالة الطابور المباشرة', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                Column(
                                  children: [
                                    Text('${booking.currentServingQueue}', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 2),
                                    const Text('الحالي', style: TextStyle(color: Colors.white54, fontSize: 11)),
                                  ],
                                ),
                                Container(width: 1, height: 30, color: Colors.white12),
                                Column(
                                  children: [
                                    Text(
                                      '${booking.peopleAhead}',
                                      style: TextStyle(
                                        color: booking.peopleAhead == 0 ? Colors.greenAccent : Colors.indigoAccent,
                                        fontSize: 24, fontWeight: FontWeight.bold
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      booking.peopleAhead == 0 ? 'استعد الآن!' : 'شخص أمامك',
                                      style: TextStyle(
                                        color: booking.peopleAhead == 0 ? Colors.greenAccent : Colors.white54, 
                                        fontSize: 11
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      )
                    else
                      const Expanded(
                        child: Center(
                          child: Text('معلومات الطابور غير متاحة', style: TextStyle(color: Colors.white38, fontSize: 13)),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            // ────────────────────────────────
            const SizedBox(height: 48),
            _buildSectionHeader('معلومات الصالون'),
            const SizedBox(height: 12),
            _buildInfoCard(),
            const SizedBox(height: 24),
            _buildSectionHeader('الخدمات المحجوزة'),
            const SizedBox(height: 12),
            _buildServicesCard(),
            const SizedBox(height: 48),
            // Actions
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ChatScreen(bookingId: booking.id, barbershopName: booking.barbershopName)),
                );
              },
              icon: const Icon(Icons.chat_bubble_outline),
              label: const Text('تحدث مع الحلاق الآن', style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD4AF37),
                foregroundColor: Colors.black,
                minimumSize: const Size(double.infinity, 60),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 4,
              ),
            ),
            if (booking.status.toLowerCase() != 'cancelled' && booking.status.toLowerCase() != 'completed') ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isCancelling ? null : _cancelBooking,
                  icon: _isCancelling 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.redAccent)) 
                    : const Icon(Icons.cancel_outlined, color: Colors.redAccent),
                  label: Text(_isCancelling ? 'جاري الإلغاء...' : 'إلغاء حجز الدور', style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.redAccent.withOpacity(0.5)),
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
    );
  }

  Widget _buildInfoCard() {
    final booking = widget.booking;
    return GlassBox(
      borderRadius: 20,
      opacity: 0.03,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildInfoRow(Icons.storefront, 'الصالون', booking.barbershopName),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Divider(color: Colors.white10),
            ),
            _buildInfoRow(Icons.location_on_outlined, 'الموقع', booking.barbershopAddress),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Divider(color: Colors.white10),
            ),
            if (booking.staffName != null && booking.staffName!.isNotEmpty) ...[
              _buildInfoRow(Icons.person, 'الحلاق', booking.staffName!),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Divider(color: Colors.white10),
              ),
            ],
            _buildInfoRow(Icons.event_available, 'تاريخ الحجز', DateFormat('EEEE, d MMMM yyyy', 'ar').format(booking.bookingDay)),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Divider(color: Colors.white10),
            ),
            _buildInfoRow(Icons.payments_outlined, 'إجمالي التكلفة', '${booking.totalPrice} جنيه', isGold: true),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, {bool isGold = false}) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: (isGold ? const Color(0xFFD4AF37) : Colors.white).withOpacity(0.05),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: isGold ? const Color(0xFFD4AF37) : Colors.white60, size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: Colors.white38, fontSize: 12)),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  color: isGold ? const Color(0xFFD4AF37) : Colors.white,
                  fontSize: 15,
                  fontWeight: isGold ? FontWeight.bold : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildServicesCard() {
    final services = widget.booking.serviceList;
    return GlassBox(
      borderRadius: 20,
      opacity: 0.03,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (services.isEmpty)
              const Center(child: Text('لم يتم تحديد خدمات', style: TextStyle(color: Colors.white38)))
            else
              ...services.map((service) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline, color: Color(0xFFD4AF37), size: 18),
                    const SizedBox(width: 12),
                    Text(service, style: const TextStyle(color: Colors.white, fontSize: 15)),
                  ],
                ),
              )),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed': return Colors.greenAccent;
      case 'pending': return Colors.orangeAccent;
      case 'cancelled': return Colors.redAccent;
      case 'completed': return Colors.lightBlueAccent;
      default: return Colors.white54;
    }
  }

  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed': return 'مؤكد من الصالون';
      case 'pending': return 'قيد المراجعة';
      case 'cancelled': return 'حجز ملغي';
      case 'completed': return 'تمت الخدمة';
      default: return 'حالة غير معروفة';
    }
  }
}
