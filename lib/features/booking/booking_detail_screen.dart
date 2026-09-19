import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../core/models/barbershop_model.dart';
import '../../core/models/service_model.dart';
import '../../core/models/staff_model.dart';
import '../../core/results/result.dart';
import '../barber/barber_repository.dart';
import 'booking_repository.dart';
import 'package:intl/intl.dart';
import 'booking_confirmation_screen.dart';

class BookingDetailScreen extends StatefulWidget {
  final Barbershop barbershop;
  final List<BarberService> selectedServices;

  const BookingDetailScreen({
    super.key,
    required this.barbershop,
    required this.selectedServices,
  });

  @override
  State<BookingDetailScreen> createState() => _BookingDetailScreenState();
}

class _BookingDetailScreenState extends State<BookingDetailScreen> {
  // Using the correct repository class name
  final _barberRepository = BarbershopRepository();
  final _bookingRepository = BookingRepository();
  
  DateTime _selectedDate = DateTime.now();
  Staff? _selectedStaff;
  List<Staff> _staff = [];
  Map<String, dynamic>? _availability;
  bool _isLoading = true;
  bool _isBooking = false;
  
  // WebSocket variables
  WebSocketChannel? _channel;
  int _currentTurnNumber = 0;
  int _finishedBookingsCount = 0;

  @override
  void initState() {
    super.initState();
    // 🚀 Fix: Initialize with existing shop data so it doesn't show #0 while loading
    _currentTurnNumber = widget.barbershop.currentTurnNumber;
    _loadData();
    _connectWebSocket();
  }
  
  void _connectWebSocket() {
    // 🚀 Fix: Use the correct server IP and standard ws:// protocol since SSL is not yet active
    final wsUrl = 'ws://64.226.87.65/ws/barbershop/${widget.barbershop.id}/';
    try {
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      
      _channel!.stream.listen(
        (message) {
          try {
            final jsonData = jsonDecode(message) as Map<String, dynamic>;
            if (mounted) {
              setState(() {
                if (jsonData.containsKey('current_turn_number')) {
                  _currentTurnNumber = jsonData['current_turn_number'];
                }
                if (jsonData.containsKey('finished_bookings_count')) {
                  _finishedBookingsCount = jsonData['finished_bookings_count'];
                }
              });
            }
          } catch (e) {
            debugPrint('WebSocket parse error: $e');
          }
        },
        onError: (error) => debugPrint('WebSocket error: $error'),
        onDone: () {
          debugPrint('WebSocket closed — reconnecting in 5s');
          Future.delayed(const Duration(seconds: 5), () {
            if (mounted) _connectWebSocket();
          });
        },
      );
    } catch (e) {
      debugPrint('WebSocket connection failed: $e');
    }
  }

  @override
  void dispose() {
    _channel?.sink.close();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    
    try {
      // Parallel execution to speed up loading
      final results = await Future.wait([
        _barberRepository.getStaff(widget.barbershop.id),
        _barberRepository.checkAvailability(widget.barbershop.id, _formatDate(_selectedDate)),
        _barberRepository.getBarbershopDetails(widget.barbershop.id), // Added to get latest turn info
      ]);

      if (mounted) {
        setState(() {
          // 🚀 Fixed: Cast results correctly to extract data
          final staffResult = results[0] as Result<List<Staff>, ApiException>;
          _staff = staffResult.successOrNull ?? [];

          _availability = results[1] as Map<String, dynamic>?;
          
          // 🚀 Added: Get current turn from availability response if available
          if (_availability != null && _availability!.containsKey('current_turn_number')) {
            _currentTurnNumber = _availability!['current_turn_number'] ?? _currentTurnNumber;
          }
          
          final shopDetailsResult = results[2] as Result<Barbershop, ApiException>;
          if (shopDetailsResult.isSuccess) {
            final shop = shopDetailsResult.successOrNull!;
            _currentTurnNumber = shop.currentTurnNumber;
          }
          
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading booking details: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _formatDate(DateTime date) => "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFFD4AF37),
              onPrimary: Colors.black,
              surface: Color(0xFF1A1A1A),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      _loadData();
    }
  }

  Future<void> _confirmBooking() async {
    setState(() => _isBooking = true);
    
    final result = await _bookingRepository.createBooking(
      shopId: widget.barbershop.id,
      serviceIds: widget.selectedServices.map((s) => s.id).toList(),
      date: _formatDate(_selectedDate),
      staffId: _selectedStaff?.id,
    );

    if (!mounted) return;
    setState(() => _isBooking = false);

    result.when(
      onSuccess: (booking) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => BookingConfirmationScreen(booking: booking)),
          (route) => false,
        );
      },
      onFailure: (error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.message),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    double total = widget.selectedServices.map((s) => s.price).fold(0.0, (a, b) => a + b);

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('تفاصيل الحجز', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFD4AF37)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle('التاريخ'),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: _selectDate,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today, color: Color(0xFFD4AF37)),
                          const SizedBox(width: 12),
                          Text(
                            DateFormat('EEEE, d MMMM yyyy', 'ar').format(_selectedDate),
                            style: const TextStyle(color: Colors.white, fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  _buildSectionTitle('اختيار الحلاق (اختياري)'),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 100,
                    child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _staff.length + 1,
                        itemBuilder: (context, index) {
                          if (index == 0) {
                            // General Booking Option
                            bool isSelected = _selectedStaff == null;
                            return GestureDetector(
                              onTap: () => setState(() => _selectedStaff = null),
                              child: Container(
                                width: 80,
                                margin: const EdgeInsets.only(left: 12),
                                child: Column(
                                  children: [
                                    CircleAvatar(
                                      radius: 30,
                                      backgroundColor: isSelected ? const Color(0xFFD4AF37) : Colors.white.withOpacity(0.1),
                                      child: Icon(Icons.people, color: isSelected ? Colors.black : Colors.white54),
                                    ),
                                    const SizedBox(height: 4),
                                    const Text(
                                      'أي حلاق',
                                      style: TextStyle(color: Colors.white, fontSize: 12),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }

                          final member = _staff[index - 1];
                          bool isSelected = _selectedStaff?.id == member.id;
                          return GestureDetector(
                            onTap: () => setState(() => _selectedStaff = isSelected ? null : member),
                            child: Container(
                              width: 100, // Increased width to fit more info
                              margin: const EdgeInsets.only(left: 12),
                              child: Column(
                                children: [
                                  Stack(
                                    children: [
                                      CircleAvatar(
                                        radius: 30,
                                        backgroundColor: isSelected ? const Color(0xFFD4AF37) : Colors.white.withOpacity(0.1),
                                        backgroundImage: member.photoUrl != null ? NetworkImage(member.photoUrl!) : null,
                                        child: member.photoUrl == null ? Icon(Icons.person, color: isSelected ? Colors.black : const Color(0xFFD4AF37)) : null,
                                      ),
                                      if (member.currentTurnNumber > 0)
                                        Positioned(
                                          right: 0,
                                          bottom: 0,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFD4AF37),
                                              borderRadius: BorderRadius.circular(10),
                                              border: Border.all(color: Colors.black, width: 1.5),
                                            ),
                                            child: Text(
                                              '#${member.currentTurnNumber}',
                                              style: const TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    member.fullName,
                                    style: TextStyle(
                                      color: isSelected ? const Color(0xFFD4AF37) : Colors.white,
                                      fontSize: 12,
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    ),
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    '${member.bookingsCountToday} زبائن',
                                    style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 10),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                  ),
                  const SizedBox(height: 32),
                  // WebSocket real-time turn information
                  _buildSectionTitle('حالة الدور (حي)'),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD4AF37).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('الدور الحالي:', style: TextStyle(color: Colors.white70)),
                            Text('#$_currentTurnNumber', style: const TextStyle(color: Color(0xFFD4AF37), fontWeight: FontWeight.bold, fontSize: 18)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('حجوزات مكتملة اليوم:', style: TextStyle(color: Colors.white70)),
                            Text('$_finishedBookingsCount', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  if (_availability != null) ...[
                    _buildSectionTitle('معلومات الحجز'),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD4AF37).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, color: Color(0xFFD4AF37)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _availability!['message'] ?? 'الدور متاح حالياً',
                              style: const TextStyle(color: Colors.white70),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 32),
                  _buildSectionTitle('ملخص الحجز'),
                  const SizedBox(height: 12),
                  ...widget.selectedServices.map((s) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(s.name, style: const TextStyle(color: Colors.white70)),
                        Text('\$${s.price}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  )),
                  const Divider(color: Colors.white24, height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('الإجمالي', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      Text('\$$total', style: const TextStyle(color: Color(0xFFD4AF37), fontSize: 20, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 40),
                  ElevatedButton(
                    onPressed: _isBooking ? null : _confirmBooking,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD4AF37),
                      foregroundColor: Colors.black,
                      minimumSize: const Size(double.infinity, 56),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: _isBooking
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                        : const Text('تأكيد الحجز الآن', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
    );
  }
}
