import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/models/booking_model.dart';
import '../../core/models/barbershop_model.dart';
import '../../core/widgets/glass_box.dart';
import '../../core/main_navigation.dart';
import 'owner_repository.dart';

class BarberBookingsHistoryScreen extends StatefulWidget {
  const BarberBookingsHistoryScreen({super.key});

  @override
  State<BarberBookingsHistoryScreen> createState() => _BarberBookingsHistoryScreenState();
}

class _BarberBookingsHistoryScreenState extends State<BarberBookingsHistoryScreen> {
  final _repository = OwnerRepository();
  bool _isLoading = true;
  List<Booking> _bookings = [];
  Barbershop? _selectedShop;
  List<Barbershop> _myShops = [];
  DateTime _selectedMonth = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadData();

    // ✅ Real-time: Listen to FCM notifications to auto-refresh bookings history
    addNotificationListener(_loadData);
  }

  @override
  void dispose() {
    // ✅ Unregister FCM listener
    removeNotificationListener(_loadData);
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      if (_myShops.isEmpty) {
        final shops = await _repository.getMyBarbershops();
        if (shops.isNotEmpty) {
          _myShops = shops;
          _selectedShop = shops.first;
        }
      }

      if (_selectedShop != null) {
        final bookings = await _repository.getBarbershopBookings(
          _selectedShop!.id,
          history: true,
          month: _selectedMonth.month,
          year: _selectedMonth.year,
        );
        setState(() {
          _bookings = bookings;
        });
      }
    } catch (e) {
      debugPrint('Error loading history: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _changeMonth(int offset) {
    setState(() {
      _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + offset, 1);
    });
    _loadData();
  }

  double _calculateMonthlyTotal() {
    double total = 0;
    for (var booking in _bookings) {
      if (booking.status == 'completed') {
        total += booking.totalPrice;
      }
    }
    return total;
  }

  Map<String, List<Booking>> _groupBookingsByDay() {
    final Map<String, List<Booking>> grouped = {};
    for (var booking in _bookings) {
      final dateStr = DateFormat('yyyy-MM-dd').format(booking.bookingDay);
      if (!grouped.containsKey(dateStr)) {
        grouped[dateStr] = [];
      }
      grouped[dateStr]!.add(booking);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _myShops.isEmpty) {
      return const Scaffold(
        backgroundColor: Color(0xFF1A1A1A),
        body: Center(child: CircularProgressIndicator(color: Color(0xFFD4AF37))),
      );
    }

    if (_myShops.isEmpty) {
      return const Scaffold(
        backgroundColor: Color(0xFF1A1A1A),
        body: Center(
          child: Text('لا يوجد لديك صالونات مسجلة', style: TextStyle(color: Colors.white70)),
        ),
      );
    }

    final double monthlyTotal = _calculateMonthlyTotal();
    final groupedBookings = _groupBookingsByDay();
    final sortedDays = groupedBookings.keys.toList()..sort((a, b) => b.compareTo(a));

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('أرباح وحجوزات المحل', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          if (_myShops.length > 1)
            DropdownButtonHideUnderline(
              child: DropdownButton<Barbershop>(
                value: _selectedShop,
                dropdownColor: const Color(0xFF2A2A2A),
                icon: const Icon(Icons.arrow_drop_down, color: Color(0xFFD4AF37)),
                items: _myShops.map((shop) {
                  return DropdownMenuItem(
                    value: shop,
                    child: Text(shop.name, style: const TextStyle(color: Colors.white)),
                  );
                }).toList(),
                onChanged: (shop) {
                  if (shop != null) {
                    setState(() {
                      _selectedShop = shop;
                      _loadData();
                    });
                  }
                },
              ),
            ),
          const SizedBox(width: 16),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        color: const Color(0xFFD4AF37),
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    // Month selector
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_right, color: Colors.white),
                          onPressed: () => _changeMonth(1),
                        ),
                        Text(
                          DateFormat('MMMM yyyy', 'ar').format(_selectedMonth),
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_left, color: Colors.white),
                          onPressed: () => _changeMonth(-1),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // Monthly Dashboard Stats
                    Row(
                      children: [
                        Expanded(
                          child: GlassBox(
                            borderRadius: 20,
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                children: [
                                  const Icon(Icons.account_balance_wallet, color: Color(0xFFD4AF37), size: 32),
                                  const SizedBox(height: 12),
                                  const Text('إجمالي الأرباح', style: TextStyle(color: Colors.white70, fontSize: 14)),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${monthlyTotal.toStringAsFixed(0)} جنيه',
                                    style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: GlassBox(
                            borderRadius: 20,
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                children: [
                                  const Icon(Icons.people, color: Color(0xFFD4AF37), size: 32),
                                  const SizedBox(height: 12),
                                  const Text('عدد الحجوزات', style: TextStyle(color: Colors.white70, fontSize: 14)),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${_bookings.length}',
                                    style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (_isLoading)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator(color: Color(0xFFD4AF37))),
              )
            else if (_bookings.isEmpty)
              SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.history, size: 64, color: Colors.white.withOpacity(0.1)),
                      const SizedBox(height: 16),
                      const Text('لا توجد حجوزات في هذا الشهر', style: TextStyle(color: Colors.white70)),
                    ],
                  ),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final dayStr = sortedDays[index];
                    final dayBookings = groupedBookings[dayStr]!;
                    double dailyTotal = 0;
                    for (var b in dayBookings) {
                      if (b.status == 'completed') dailyTotal += b.totalPrice;
                    }

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                      child: GlassBox(
                        borderRadius: 16,
                        opacity: 0.05,
                        child: Theme(
                          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                          child: ExpansionTile(
                            iconColor: const Color(0xFFD4AF37),
                            collapsedIconColor: Colors.white54,
                            title: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  DateFormat('EEEE, d MMM', 'ar').format(DateTime.parse(dayStr)),
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFD4AF37).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '${dailyTotal.toStringAsFixed(0)} جنيه',
                                    style: const TextStyle(color: Color(0xFFD4AF37), fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                            subtitle: Text('${dayBookings.length} حجوزات', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                            children: dayBookings.map((booking) => _buildBookingRow(booking)).toList(),
                          ),
                        ),
                      ),
                    );
                  },
                  childCount: sortedDays.length,
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }

  Widget _buildBookingRow(Booking booking) {
    Color statusColor;
    String statusAr;
    switch (booking.status) {
      case 'completed': statusColor = Colors.green; statusAr = 'مكتمل'; break;
      case 'cancelled': statusColor = Colors.redAccent; statusAr = 'ملغى'; break;
      case 'pending': statusColor = Colors.orangeAccent; statusAr = 'انتظار'; break;
      default: statusColor = Colors.blue; statusAr = 'مؤكد';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (booking.customerName != null && booking.customerName!.isNotEmpty) 
                      ? booking.customerName! 
                      : 'عميل غير معروف',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  booking.serviceList.join(', '),
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (booking.staffName != null && booking.staffName!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.person, size: 12, color: Color(0xFFD4AF37)),
                      const SizedBox(width: 4),
                      Text(
                        'الحلاق: ${booking.staffName}',
                        style: const TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${booking.totalPrice} جنيه',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                statusAr,
                style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
