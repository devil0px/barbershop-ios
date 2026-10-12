import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../core/models/barbershop_model.dart';
import '../../core/models/service_model.dart';
import '../../core/models/staff_model.dart';
import '../../core/models/review_model.dart';
import '../../core/widgets/glass_box.dart';
import '../booking/booking_detail_screen.dart';
import 'add_review_screen.dart';
import 'barber_repository.dart';
import '../../core/results/result.dart';
import 'package:cached_network_image/cached_network_image.dart';

class BarberDetailsScreen extends StatefulWidget {
  final Barbershop barbershop;
  const BarberDetailsScreen({super.key, required this.barbershop});

  @override
  State<BarberDetailsScreen> createState() => _BarberDetailsScreenState();
}

class _BarberDetailsScreenState extends State<BarberDetailsScreen> {
  final _barberRepository = BarbershopRepository();
  List<BarberService> _services = [];
  List<Staff> _staff = [];
  List<Review> _reviews = [];
  bool _isLoading = true;
  final Set<int> _selectedServiceIds = {};

  WebSocketChannel? _turnChannel;
  int _currentTurnNumber = 0;
  late Barbershop _barbershop;

  @override
  void initState() {
    super.initState();
    _barbershop = widget.barbershop;
    _currentTurnNumber = _barbershop.currentTurnNumber;
    _loadDetails();
    _connectTurnWebSocket();
  }

  @override
  void dispose() {
    _turnChannel?.sink.close();
    super.dispose();
  }

  void _connectTurnWebSocket() {
    try {
      final wsUrl = 'ws://64.226.87.65/ws/barbershop/${widget.barbershop.id}/';
      _turnChannel = WebSocketChannel.connect(Uri.parse(wsUrl));
      _turnChannel!.stream.listen((message) {
        final data = json.decode(message);
        if (mounted && data.containsKey('current_turn_number')) {
          setState(() {
            _currentTurnNumber = data['current_turn_number'];
          });
        }
      }, onError: (err) {
        print('WebSocket Error: $err');
      });
    } catch (e) {
      print('Could not connect to turn WebSocket: $e');
    }
  }

  Future<void> _loadDetails() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    
    // Performance: Parallel Execution 
    final results = await Future.wait([
      _barberRepository.getServices(widget.barbershop.id),
      _barberRepository.getStaff(widget.barbershop.id),
      _barberRepository.getReviews(widget.barbershop.id),
      _barberRepository.getBarbershopDetails(widget.barbershop.id), // 🚀 Added: Refresh shop info
    ]);

    if (mounted) {
      setState(() {
        // Safe Extraction using Result Pattern
        _services = (results[0] as Result<List<BarberService>, ApiException>).successOrNull ?? [];
        _staff = (results[1] as Result<List<Staff>, ApiException>).successOrNull ?? [];
        _reviews = (results[2] as Result<List<Review>, ApiException>).successOrNull ?? [];
        
        final updatedShopResult = results[3] as Result<Barbershop, ApiException>;
        if (updatedShopResult.isSuccess) {
           _barbershop = updatedShopResult.successOrNull!;
           _currentTurnNumber = _barbershop.currentTurnNumber;
        }
        
        _isLoading = false;
      });
    }
  }

  Future<void> _launchURL(String url, {bool isExternal = false}) async {
    final uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: isExternal ? LaunchMode.externalApplication : LaunchMode.platformDefault,
        );
      } else {
        debugPrint('Could not launch $url');
      }
    } catch (e) {
      debugPrint('Error launching URL: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildShopInfo(),
                  const SizedBox(height: 20),
                  _buildWorkingHoursSection(),
                  const SizedBox(height: 32),
                  DefaultTabController(
                    length: _barbershop.galleryImages.isNotEmpty ? 4 : 3,
                    child: Column(
                      children: [
                        TabBar(
                          indicatorColor: const Color(0xFFD4AF37),
                          labelColor: const Color(0xFFD4AF37),
                          unselectedLabelColor: Colors.white54,
                          isScrollable: _barbershop.galleryImages.isNotEmpty,
                          tabs: [
                            const Tab(text: 'الخدمات'),
                            if (_barbershop.galleryImages.isNotEmpty)
                              const Tab(text: 'معرض الصور'),
                            const Tab(text: 'طاقم العمل'),
                            const Tab(text: 'التقييمات'),
                          ],
                        ),
                        SizedBox(
                          height: 400,
                          child: TabBarView(
                            children: [
                              _buildServicesTab(),
                              if (_barbershop.galleryImages.isNotEmpty)
                                _buildGalleryTab(),
                              _buildStaffTab(),
                              _buildReviewsTab(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomSheet: _buildBottomAction(),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 250,
      pinned: true,
      backgroundColor: const Color(0xFF1A1A1A),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            if (_barbershop.logoUrl != null)
              CachedNetworkImage(
                imageUrl: _barbershop.logoUrl!,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(color: const Color(0xFF333333)),
                errorWidget: (context, url, error) => Container(color: const Color(0xFF333333)),
              )
            else
              Container(color: const Color(0xFF333333)),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withOpacity(0.9)],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShopInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                _barbershop.name,
                style: GoogleFonts.playfairDisplay(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            GlassBox(
              borderRadius: 12,
              opacity: 0.1,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    const Icon(Icons.star, size: 18, color: Color(0xFFD4AF37)),
                    const SizedBox(width: 6),
                    Text(
                      _barbershop.rating.toString(),
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(Icons.location_on, color: Color(0xFFD4AF37), size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _barbershop.address,
                style: const TextStyle(color: Colors.white70, fontSize: 16),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        GlassBox(
          borderRadius: 20,
          opacity: 0.05,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('الدور الحالي', style: TextStyle(color: Colors.white60, fontSize: 14)),
                    const SizedBox(height: 4),
                    Text(
                      _currentTurnNumber > 0 ? _currentTurnNumber.toString() : '--',
                      style: const TextStyle(color: Color(0xFFD4AF37), fontSize: 36, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD4AF37).withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.confirmation_number_outlined, color: Color(0xFFD4AF37), size: 32),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            _buildContactIcon(Icons.phone, 'اتصال', () {
              if (_barbershop.phone != null && _barbershop.phone!.isNotEmpty) {
                _launchURL('tel:${_barbershop.phone}', isExternal: true);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('رقم الهاتف غير متوفر')),
                );
              }
            }),
            const SizedBox(width: 12),
            _buildContactIcon(Icons.map, 'الموقع', () {
              if (_barbershop.latitude != null && _barbershop.longitude != null) {
                _launchURL('https://www.google.com/maps/search/?api=1&query=${_barbershop.latitude},${_barbershop.longitude}', isExternal: true);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('موقع الصالون غير محدد بدقة')),
                );
              }
            }),
            const SizedBox(width: 12),
            _buildContactIcon(Icons.message, 'واتساب', () {
              // Prefer whatsapp_number, fallback to phone
              String? waNumber = _barbershop.whatsappNumber;
              if (waNumber == null || waNumber.isEmpty) waNumber = _barbershop.phone;
              if (waNumber != null && waNumber.isNotEmpty) {
                // Egyptian numbers: 0xxx → 20xxx
                String processedPhone = waNumber.replaceAll(RegExp(r'[^0-9+]'), '');
                if (processedPhone.startsWith('0')) {
                  processedPhone = '2$processedPhone';
                }
                _launchURL('https://wa.me/$processedPhone', isExternal: true);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('رقم الواتساب غير متوفر')),
                );
              }
            }),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          _barbershop.description,
          style: const TextStyle(color: Colors.white54, fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildContactIcon(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFD4AF37).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.3)),
            ),
            child: Icon(icon, color: const Color(0xFFD4AF37), size: 20),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildServiceTile(BarberService service) {
    final isSelected = _selectedServiceIds.contains(service.id);
    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedServiceIds.remove(service.id);
          } else {
            _selectedServiceIds.add(service.id);
          }
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        child: GlassBox(
          borderRadius: 16,
          opacity: isSelected ? 0.15 : 0.05,
          border: isSelected ? Border.all(color: const Color(0xFFD4AF37), width: 2) : null,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (service.imageUrl != null) ...[
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: CachedNetworkImage(
                                imageUrl: service.imageUrl!,
                                width: 40,
                                height: 40,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(color: Colors.white10),
                                errorWidget: (context, url, error) => const Icon(Icons.cut, color: const Color(0xFFD4AF37)),
                              ),
                            ),
                            const SizedBox(width: 12),
                          ],
                          Expanded(
                            child: Text(
                              service.name,
                              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            '${service.price} جنيه',
                            style: const TextStyle(color: Color(0xFFD4AF37), fontWeight: FontWeight.bold),
                          ),
                          const Text(' • ', style: TextStyle(color: Colors.white24)),
                          Text(
                            '${service.duration} دقيقة',
                            style: const TextStyle(color: Colors.white54),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(
                  isSelected ? Icons.check_circle : Icons.add_circle_outline,
                  color: const Color(0xFFD4AF37),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomAction() {
    if (_selectedServiceIds.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(24),
      color: const Color(0xFF1A1A1A),
      child: ElevatedButton(
        onPressed: () {
          final selectedServices = _services.where((s) => _selectedServiceIds.contains(s.id)).toList();
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => BookingDetailScreen(
                barbershop: _barbershop,
                selectedServices: selectedServices,
              ),
            ),
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFD4AF37),
          foregroundColor: Colors.black,
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: const Text(
          'حجز الدور الآن',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
    );
  }

  Widget _buildServicesTab() {
    if (_services.isEmpty && !_isLoading) return const Center(child: Text('لا توجد خدمات حالياً', style: TextStyle(color: Colors.white54)));
    return ListView(
      padding: const EdgeInsets.only(top: 16, bottom: 20),
      children: _services.map((s) => _buildServiceTile(s)).toList(),
    );
  }

  Widget _buildStaffTab() {
    if (_staff.isEmpty && !_isLoading) return const Center(child: Text('لا يوجد موظفون متاحون حالياً', style: TextStyle(color: Colors.white54)));
    return ListView.builder(
      padding: const EdgeInsets.only(top: 16, bottom: 20),
      itemCount: _staff.length,
      itemBuilder: (context, index) {
        final member = _staff[index];
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: const Color(0xFFD4AF37).withOpacity(0.1),
            backgroundImage: member.photoUrl != null ? CachedNetworkImageProvider(member.photoUrl!) : null,
            child: member.photoUrl == null ? const Icon(Icons.person, color: Color(0xFFD4AF37)) : null,
          ),
          title: Text(member.fullName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          subtitle: Text(member.role ?? '', style: const TextStyle(color: Colors.white54)),
          trailing: Icon(
            Icons.circle,
            size: 12,
            color: member.isAvailable ? Colors.green : Colors.red,
          ),
        );
      },
    );
  }

  Widget _buildReviewsTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton.icon(
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AddReviewScreen(
                    shopId: _barbershop.id,
                    shopName: widget.barbershop.name,
                  ),
                ),
              );
              if (result == true) _loadDetails();
            },
            icon: const Icon(Icons.add_comment),
            label: const Text('أضف تقييمك'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD4AF37).withOpacity(0.1),
              foregroundColor: const Color(0xFFD4AF37),
              side: const BorderSide(color: Color(0xFFD4AF37)),
              minimumSize: const Size(double.infinity, 44),
            ),
          ),
        ),
        Expanded(
          child: _reviews.isEmpty
              ? const Center(child: Text('لا توجد تقييمات حتى الآن', style: TextStyle(color: Colors.white54)))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _reviews.length,
                  itemBuilder: (context, index) {
                    final review = _reviews[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: const Color(0xFFD4AF37).withOpacity(0.1),
                                backgroundImage: review.customerPhoto != null 
                                    ? CachedNetworkImageProvider(review.customerPhoto!) 
                                    : null,
                                child: review.customerPhoto == null 
                                    ? const Icon(Icons.person, color: Color(0xFFD4AF37), size: 20) 
                                    : null,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      review.customerName,
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _formatDate(review.createdAt),
                                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                              Row(
                                children: List.generate(5, (i) => Icon(
                                  Icons.star,
                                  size: 14,
                                  color: i < review.rating ? const Color(0xFFD4AF37) : Colors.white24,
                                )),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(review.comment, style: const TextStyle(color: Colors.white70)),
                          const SizedBox(height: 8),
                          const Divider(color: Colors.white12),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // ── Working Hours Section ──
  static const _dayNames = {
    'saturday': 'السبت',
    'sunday': 'الأحد',
    'monday': 'الاثنين',
    'tuesday': 'الثلاثاء',
    'wednesday': 'الأربعاء',
    'thursday': 'الخميس',
    'friday': 'الجمعة',
  };

  Widget _buildWorkingHoursSection() {
    final hours = _barbershop.workingHours;
    if (hours.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
          iconColor: const Color(0xFFD4AF37),
          collapsedIconColor: const Color(0xFFD4AF37),
          title: const Row(
            children: [
              Icon(Icons.schedule, color: Color(0xFFD4AF37), size: 18),
              SizedBox(width: 8),
              Text('ساعات العمل', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
            ],
          ),
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
              child: Column(
                children: ['saturday', 'sunday', 'monday', 'tuesday', 'wednesday', 'thursday', 'friday'].map((day) {
                  final dayData = hours[day];
                  if (dayData == null || dayData is! Map) return const SizedBox.shrink();

                  final isOpen = dayData['is_open'] ?? true;
                  final openTime = dayData['open'] ?? dayData['start'] ?? '';
                  final closeTime = dayData['close'] ?? dayData['end'] ?? '';
                  final dayLabel = _dayNames[day] ?? day;

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(dayLabel, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                        Text(
                          isOpen && openTime.toString().isNotEmpty
                              ? ((openTime.toString().trim() == '00:00' || openTime.toString().trim() == '0:00') &&
                                      (closeTime.toString().trim() == '23:59' ||
                                          closeTime.toString().trim() == '24:00' ||
                                          closeTime.toString().trim() == '00:00')
                                  ? 'مفتوح 24 ساعة'
                                  : '$openTime - $closeTime')
                              : 'مغلق',
                          style: TextStyle(
                            color: isOpen ? const Color(0xFFD4AF37) : Colors.red.shade300,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Gallery Tab ──
  Widget _buildGalleryTab() {
    if (_barbershop.galleryImages.isEmpty) {
      return const Center(child: Text('لا توجد صور', style: TextStyle(color: Colors.white54)));
    }
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1,
      ),
      itemCount: _barbershop.galleryImages.length,
      itemBuilder: (context, index) {
        final imageUrl = _barbershop.galleryImages[index];
        return GestureDetector(
          onTap: () => _showFullImage(context, imageUrl, index),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.cover,
              placeholder: (ctx, url) => Container(
                color: Colors.white.withOpacity(0.05),
                child: const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFD4AF37))),
              ),
              errorWidget: (ctx, url, err) => Container(
                color: Colors.white.withOpacity(0.05),
                child: const Icon(Icons.broken_image, color: Colors.white24),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showFullImage(BuildContext context, String imageUrl, int index) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          children: [
            InteractiveViewer(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            Positioned(
              top: 8,
              left: 8,
              child: CircleAvatar(
                backgroundColor: Colors.black54,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
            Positioned(
              bottom: 12,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${index + 1} / ${_barbershop.galleryImages.length}',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) {
          return 'الآن';
        }
        return 'منذ ${difference.inMinutes} دقيقة';
      }
      return 'منذ ${difference.inHours} ساعة';
    } else if (difference.inDays == 1) {
      return 'أمس';
    } else if (difference.inDays < 7) {
      return 'منذ ${difference.inDays} أيام';
    } else if (difference.inDays < 30) {
      return 'منذ ${(difference.inDays / 7).floor()} أسابيع';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
