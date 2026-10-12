import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../core/models/barbershop_model.dart';
import '../../core/models/booking_model.dart';
import '../../core/main_navigation.dart';
import 'owner_repository.dart';
import 'manage_services_screen.dart';
import 'manage_staff_screen.dart';
import 'edit_shop_screen.dart';
import 'add_shop_screen.dart';
import '../booking/chat_screen.dart';

class OwnerDashboardScreen extends StatefulWidget {
  const OwnerDashboardScreen({super.key});

  @override
  State<OwnerDashboardScreen> createState() => _OwnerDashboardScreenState();
}

class _OwnerDashboardScreenState extends State<OwnerDashboardScreen> {
  final _repository = OwnerRepository();
  List<Barbershop> _myShops = [];
  List<Booking> _recentBookings = [];
  Map<String, dynamic> _stats = {};
  bool _isLoading = true;
  Barbershop? _selectedShop;
  WebSocketChannel? _channel;
  int _currentTurn = 0;

  @override
  void initState() {
    super.initState();
    _loadData();

    // ✅ Real-time: Listen to FCM notifications to auto-refresh dashboard
    // When a new booking arrives, status changes, or a message is sent,
    // this callback fires and reloads the bookings list instantly
    addNotificationListener(_onNotificationRefresh);
  }

  @override
  void dispose() {
    _channel?.sink.close();
    // ✅ Unregister FCM listener
    removeNotificationListener(_onNotificationRefresh);
    super.dispose();
  }

  /// ✅ Called when any FCM notification arrives — reloads bookings & stats
  void _onNotificationRefresh() {
    debugPrint('📩 Dashboard: FCM notification received — refreshing data');
    _refreshBookings();
    // Also refresh stats to update income/booking count
    if (_selectedShop != null) {
      _repository.getFinancialStats(_selectedShop!.id).then((stats) {
        if (mounted) {
          setState(() => _stats = stats);
        }
      }).catchError((_) {});
    }
  }

  void _connectWebSocket(int shopId) {
    _channel?.sink.close();
    final wsUrl = 'ws://64.226.87.65/ws/barbershop/$shopId/';
    _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
    _channel!.stream.listen((message) {
      final data = jsonDecode(message);
      if (mounted) {
        setState(() {
          _currentTurn = data['current_turn_number'] ?? 0;
        });
        // Refresh bookings list to reflect status changes
        _refreshBookings();
      }
    });
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final shops = await _repository.getMyBarbershops();
      if (shops.isNotEmpty) {
        _selectedShop = shops.first;
        _connectWebSocket(_selectedShop!.id);
        
        final results = await Future.wait<dynamic>([
          _repository.getBarbershopBookings(_selectedShop!.id),
          _repository.getFinancialStats(_selectedShop!.id),
        ]);
        
        setState(() {
          _myShops = shops;
          _recentBookings = results[0] as List<Booking>;
          _stats = results[1] as Map<String, dynamic>;
          _currentTurn = _selectedShop!.currentTurnNumber;
          _isLoading = false;
        });
      } else {
        setState(() {
          _myShops = [];
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _refreshBookings() async {
    if (_selectedShop == null) return;
    try {
      final bookings = await _repository.getBarbershopBookings(_selectedShop!.id);
      if (mounted) {
        setState(() {
          _recentBookings = bookings;
        });
      }
    } catch (_) {}
  }

  Future<void> _nextTurn() async {
    if (_selectedShop == null) return;
    
    final success = await _repository.incrementTurn(_selectedShop!.id);
    if (success) {
      setState(() {
        _currentTurn++;
      });
      // Refresh data to get updated bookings list
      _refreshBookings();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('تم الانتقال للزبون التالي ✅'),
            backgroundColor: Colors.green.shade800,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  Future<void> _updateBookingStatus(int bookingId, String status) async {
    String actionName = status == 'completed' ? 'إكمال' : (status == 'confirmed' ? 'تأكيد' : 'إلغاء');
    
    // 🛡️ Confirmation Dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('$actionName الحجز', style: const TextStyle(color: Colors.white)),
        content: Text('هل أنت متأكد من $actionName هذا الحجز؟', style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('تراجع', style: TextStyle(color: Colors.white38))),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            child: Text(actionName, style: TextStyle(color: status == 'cancelled' ? Colors.red : const Color(0xFFD4AF37)))
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final success = await _repository.updateBookingStatus(bookingId, status);
    if (success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم $actionName الحجز بنجاح ✅'))
        );
      }
      _loadData();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('حدث خطأ أثناء تحديث حالة الحجز'))
        );
      }
    }
  }

  // Count of remaining active bookings
  int get _remainingCustomers => _recentBookings
      .where((b) => b.status == 'pending' || b.status == 'confirmed')
      .length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      floatingActionButton: _myShops.isEmpty ? FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => const AddShopScreen()));
          if (result == true) _loadData();
        },
        backgroundColor: const Color(0xFFD4AF37),
        child: const Icon(Icons.add, color: Colors.black),
      ) : FloatingActionButton(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('لديك صالون نشط بالفعل. لا يمكنك إضافة صالون آخر حالياً.'))
          );
        },
        backgroundColor: Colors.grey,
        child: const Icon(Icons.add, color: Colors.white54),
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: CustomScrollView(
          slivers: [
            _buildAppBar(),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_isLoading)
                      const Center(child: CircularProgressIndicator(color: Color(0xFFD4AF37)))
                    else if (_myShops.isEmpty)
                      _buildNoShopsView()
                    else ...[
                      _buildShopSelector(),
                      const SizedBox(height: 24),
                      _buildQueueControl(),
                      const SizedBox(height: 24),
                      _buildStatsRow(),
                      const SizedBox(height: 32),
                      _buildQuickActions(),
                      const SizedBox(height: 32),
                      _buildRecentBookingsHeader(),
                      const SizedBox(height: 16),
                      _buildRecentBookingsList(),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return const SliverAppBar(
      expandedHeight: 80.0,
      pinned: true,
      backgroundColor: Color(0xFF1A1A1A),
      title: Text('لوحة التحكم', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      centerTitle: true,
    );
  }

  Widget _buildNoShopsView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 100),
        child: Column(
          children: [
            const Icon(Icons.store_outlined, size: 80, color: Colors.white24),
            const SizedBox(height: 20),
            const Text('لا توجد محلات مسجلة', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () async {
                final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => const AddShopScreen()));
                if (result == true) _loadData();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD4AF37),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('إضافة صالونك الأول الآن', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShopSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<Barbershop>(
          value: _selectedShop,
          dropdownColor: const Color(0xFF1A1A1A),
          isExpanded: true,
          items: _myShops.map((shop) => DropdownMenuItem(value: shop, child: Text(shop.name, style: const TextStyle(color: Colors.white)))).toList(),
          onChanged: (shop) {
            if (shop != null) {
              setState(() => _selectedShop = shop);
              _loadData();
            }
          },
        ),
      ),
    );
  }

  Widget _buildQueueControl() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFD4AF37).withOpacity(0.15),
            const Color(0xFFD4AF37).withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('الدور الحالي الآن', style: TextStyle(color: Colors.white70, fontSize: 14)),
                  const SizedBox(height: 4),
                  Text('#$_currentTurn', style: const TextStyle(color: Color(0xFFD4AF37), fontSize: 40, fontWeight: FontWeight.bold)),
                ],
              ),
              Column(
                children: [
                  ElevatedButton.icon(
                    onPressed: _remainingCustomers > 0 ? _nextTurn : null,
                    icon: const Icon(Icons.skip_next, size: 22),
                    label: const Text('الزبون التالي', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _remainingCustomers > 0 ? const Color(0xFFD4AF37) : Colors.grey.shade700,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: _remainingCustomers > 0 ? 4 : 0,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Remaining customers indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: _remainingCustomers > 0 
                  ? Colors.blue.withOpacity(0.1) 
                  : Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _remainingCustomers > 0 
                    ? Colors.blue.withOpacity(0.2) 
                    : Colors.green.withOpacity(0.2),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _remainingCustomers > 0 ? Icons.groups : Icons.check_circle_outline,
                  color: _remainingCustomers > 0 ? Colors.blue : Colors.green,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Text(
                  _remainingCustomers > 0
                      ? 'متبقي $_remainingCustomers ${_remainingCustomers == 1 ? "زبون" : "زبائن"} في الطابور'
                      : 'لا يوجد زبائن في الانتظار ✅',
                  style: TextStyle(
                    color: _remainingCustomers > 0 ? Colors.blue.shade200 : Colors.green.shade200,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(child: _buildStatCard('دخل اليوم', '${_stats['today_income'] ?? 0} ج.م', Colors.blue, Icons.payments)),
        const SizedBox(width: 16),
        Expanded(child: _buildStatCard('الحجوزات', '${_stats['total_bookings_count'] ?? 0}', Colors.green, Icons.calendar_today)),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 12),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildActionIcon('إدارة الخدمات', Icons.cut, const Color(0xFFD4AF37), () {
          if (_selectedShop != null) Navigator.push(context, MaterialPageRoute(builder: (context) => ManageServicesScreen(shopId: _selectedShop!.id)));
        }),
        _buildActionIcon('الموظفين', Icons.people, Colors.blue, () {
          if (_selectedShop != null) Navigator.push(context, MaterialPageRoute(builder: (context) => ManageStaffScreen(shopId: _selectedShop!.id)));
        }),
        _buildActionIcon('الإعدادات', Icons.settings, Colors.grey, () {
          if (_selectedShop != null) Navigator.push(context, MaterialPageRoute(builder: (context) => EditShopScreen(shop: _selectedShop!)));
        }),
      ],
    );
  }

  Widget _buildActionIcon(String label, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
            child: Icon(icon, color: color),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildRecentBookingsHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text('الحجوزات النشطة', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        if (_recentBookings.isNotEmpty)
          Text(
            '${_recentBookings.length} حجز',
            style: const TextStyle(color: Colors.white38, fontSize: 13),
          ),
      ],
    );
  }

  Widget _buildRecentBookingsList() {
    if (_recentBookings.isEmpty) return const Center(child: Padding(padding: EdgeInsets.all(20), child: Text('لا توجد حجوزات نشطة', style: TextStyle(color: Colors.white24))));
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _recentBookings.length,
      itemBuilder: (context, index) {
        final booking = _recentBookings[index];
        final isCurrentTurn = booking.queueNumber == _currentTurn;
        
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isCurrentTurn 
                ? const Color(0xFFD4AF37).withOpacity(0.08) 
                : Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: isCurrentTurn 
                ? Border.all(color: const Color(0xFFD4AF37).withOpacity(0.4), width: 1.5) 
                : null,
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              booking.customerName ?? 'عميل', 
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                            if (isCurrentTurn) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFD4AF37).withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text('الدور الحالي', style: TextStyle(color: Color(0xFFD4AF37), fontSize: 10, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ],
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
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: isCurrentTurn 
                          ? const Color(0xFFD4AF37).withOpacity(0.2) 
                          : Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '#${booking.queueNumber}', 
                      style: TextStyle(
                        color: isCurrentTurn ? const Color(0xFFD4AF37) : Colors.white70,
                        fontWeight: FontWeight.bold, 
                        fontSize: 18,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  if (booking.status == 'pending')
                    _buildStatusBtn('تأكيد ✓', Colors.green, () => _updateBookingStatus(booking.id, 'confirmed')),
                  if (booking.status == 'confirmed')
                    _buildStatusBtn('إكمال ✓', Colors.blue, () => _updateBookingStatus(booking.id, 'completed')),
                  const SizedBox(width: 8),
                  if (booking.status == 'pending' || booking.status == 'confirmed')
                    _buildStatusBtn('إلغاء ✗', Colors.red, () => _updateBookingStatus(booking.id, 'cancelled')),
                  const Spacer(),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.push(
                      context, 
                      MaterialPageRoute(builder: (context) => ChatScreen(
                        bookingId: booking.id, 
                        barbershopName: booking.customerName ?? 'الزبون'
                      ))
                    ),
                    icon: const Icon(Icons.chat_bubble_outline, size: 16),
                    label: const Text('دردشة', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFD4AF37),
                      side: const BorderSide(color: Color(0xFFD4AF37)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusBtn(String label, Color color, VoidCallback onTap) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withOpacity(0.15), 
        foregroundColor: color, 
        elevation: 0, 
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
    );
  }
}
