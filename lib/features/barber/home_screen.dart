import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/widgets/glass_box.dart';
import '../../core/models/barbershop_model.dart';
import '../../features/barber/barber_repository.dart';
import '../notifications/notification_screen.dart';
import 'barber_details_screen.dart';
import 'filter_modal.dart';
import '../../core/services/location_service.dart';
import '../../core/services/favorites_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:async';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with AutomaticKeepAliveClientMixin {
  final _barberRepository = BarbershopRepository();
  final _searchController = TextEditingController();
  List<Barbershop> _barbershops = [];
  List<Barbershop> _filteredBarbershops = [];
  List<int> _favoriteIds = [];
  bool _isLoading = true;
  bool _isLocating = false;
  String? _errorMessage;
  String _userName = 'زائر';
  
  @override
  bool get wantKeepAlive => true; 
  
  Map<String, dynamic> _filters = {
    'minRating': 0.0,
    'showOnlyOpen': false,
    'showOnlyFavorites': false,
    'sortByNearest': true,
  };
  Position? _userPosition;

  StreamSubscription? _dataSubscription;
  final ScrollController _scrollController = ScrollController();
  int _currentPage = 1;
  bool _hasMoreData = true;
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _loadUserName();
    _loadData();
    _loadFavorites();
    _searchController.addListener(_onSearchChanged);
    _scrollController.addListener(_onScroll);
  }

  Future<void> _loadUserName() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        final full = prefs.getString('full_name') ?? '';
        _userName = full.isNotEmpty ? full.split(' ').first : 'زائر';
      });
    }
  }

  Future<void> _loadFavorites() async {
    final ids = await FavoritesService.getFavoriteIds();
    if (mounted) setState(() => _favoriteIds = ids);
  }

  Future<void> _toggleFavorite(int shopId) async {
    await FavoritesService.toggleFavorite(shopId);
    await _loadFavorites();
  }

  @override
  void dispose() {
    _dataSubscription?.cancel();
    _scrollController.dispose();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _filteredBarbershops = _barbershops.where((shop) {
        final query = _searchController.text.toLowerCase();
        final matchesText =
            shop.name.toLowerCase().contains(query) ||
            shop.address.toLowerCase().contains(query) ||
            shop.staffNames.any((staff) => staff.toLowerCase().contains(query));
        final matchesRating = shop.rating >= (_filters['minRating'] ?? 0.0);
        final matchesOpen = !(_filters['showOnlyOpen'] ?? false) || shop.isOpen;
        final matchesFavorite =
            !(_filters['showOnlyFavorites'] ?? false) || _favoriteIds.contains(shop.id);
        return matchesText && matchesRating && matchesOpen && matchesFavorite;
      }).toList();

      _sortByNearest(_filteredBarbershops);
    });
  }

  void _sortByNearest(List<Barbershop> list) {
    if (_userPosition != null) {
      list.sort((a, b) {
        if (a.latitude == null || a.longitude == null) return 1;
        if (b.latitude == null || b.longitude == null) return -1;
        double dA = LocationService.calculateDistance(
            _userPosition!.latitude, _userPosition!.longitude, a.latitude!, a.longitude!);
        double dB = LocationService.calculateDistance(
            _userPosition!.latitude, _userPosition!.longitude, b.latitude!, b.longitude!);
        return dA.compareTo(dB);
      });
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _hasMoreData && _errorMessage == null) {
        _loadMoreData();
      }
    }
  }

  Future<void> _loadData({bool forceRefresh = false}) async {
    if (!mounted) return;
    
    _currentPage = 1;
    _hasMoreData = true;
    _dataSubscription?.cancel();
    
    _userPosition = await LocationService.getCurrentLocation();
    
    _dataSubscription = _barberRepository.getBarbershopsStream().listen((result) {
      if (!mounted) return;
      
      result.when(
        onSuccess: (shops) {
          if (mounted) {
            setState(() {
              _barbershops = shops;
              _isLoading = false;
              _errorMessage = null;
              _onSearchChanged(); 
            });
          }
        },
        onFailure: (error) {
          if (mounted && _barbershops.isEmpty) {
            setState(() {
              _isLoading = false;
              _errorMessage = error.message;
            });
          }
        },
      );
    });
  }

  Future<void> _loadMoreData() async {
    if (_isLoadingMore || !_hasMoreData) return;

    setState(() => _isLoadingMore = true);
    _currentPage++;

    final result = await _barberRepository.getBarbershops(
      page: _currentPage,
      search: _searchController.text.isNotEmpty ? _searchController.text : null,
    );

    if (mounted) {
      result.when(
        onSuccess: (newShops) {
          setState(() {
            _isLoadingMore = false;
            // Standard page size is 20. If we got less, there's no more data.
            if (newShops.isEmpty || newShops.length < 20) {
              _hasMoreData = false;
            }
            
            if (newShops.isNotEmpty) {
              // Add only new unique shops
              for (var shop in newShops) {
                if (!_barbershops.any((existing) => existing.id == shop.id)) {
                  _barbershops.add(shop);
                }
              }
              _onSearchChanged();
            }
          });
        },
        onFailure: (error) {
          setState(() {
            _isLoadingMore = false;
            _currentPage--;
          });
        },
      );
    }
  }

  Future<void> _requestAndSortByLocation() async {
    setState(() => _isLocating = true);
    final pos = await LocationService.getCurrentLocation();
    if (!mounted) return;

    if (pos != null) {
      setState(() {
        _userPosition = pos;
        _isLocating = false;
      });
      _onSearchChanged();
    } else {
      setState(() => _isLocating = false);
    }
  }

  String _formatDistance(Barbershop shop) {
    if (_userPosition == null || shop.latitude == null || shop.longitude == null) return '';
    final km = LocationService.calculateDistance(
        _userPosition!.latitude, _userPosition!.longitude, shop.latitude!, shop.longitude!);
    if (km < 1.0) return '${(km * 1000).round()} م';
    return '${km.toStringAsFixed(1)} كم';
  }

  void _openFilters() async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FilterModal(currentFilters: _filters),
    );

    if (result != null) {
      setState(() {
        _filters = result;
      });
      _onSearchChanged();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'BarberShop',
          style: GoogleFonts.playfairDisplay(
            color: const Color(0xFFD4AF37),
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const NotificationScreen()),
              );
            },
          ),
          const CircleAvatar(
            backgroundColor: Color(0xFFD4AF37),
            radius: 16,
            child: Icon(Icons.person, color: Colors.black, size: 20),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFD4AF37)))
          : _errorMessage != null
              ? _buildErrorState()
              : RefreshIndicator(
                  color: const Color(0xFFD4AF37),
                  backgroundColor: const Color(0xFF1A1A1A),
                  onRefresh: () => _loadData(forceRefresh: true),
                  child: CustomScrollView(
                    controller: _scrollController,
                    slivers: [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildHeader(),
                              const SizedBox(height: 16),
                              _buildSearchBar(),
                              const SizedBox(height: 16),
                              _buildLocationBanner(),
                              const SizedBox(height: 24),
                              _buildHowItWorksBanner(),
                              const SizedBox(height: 24),
                              _buildSortHeader(),
                              const SizedBox(height: 12),
                            ],
                          ),
                        ),
                      ),
                      if (_filteredBarbershops.isEmpty)
                        const SliverFillRemaining(
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.search_off, color: Colors.white24, size: 60),
                                SizedBox(height: 12),
                                Text('لا توجد نتائج تطابق بحثك',
                                    style: TextStyle(color: Colors.white54)),
                              ],
                            ),
                          ),
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (ctx, i) => _buildBarberCard(_filteredBarbershops[i], i),
                              childCount: _filteredBarbershops.length,
                            ),
                          ),
                        ),
                      if (_isLoadingMore)
                        const SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 20),
                            child: Center(
                              child: CircularProgressIndicator(
                                color: Color(0xFFD4AF37),
                                strokeWidth: 2,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: GlassBox(
          borderRadius: 20,
          opacity: 0.1,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 40.0, horizontal: 24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.wifi_off_rounded, color: Colors.redAccent, size: 48),
                ),
                const SizedBox(height: 24),
                const Text(
                  'عذراً، قطع الاتصال',
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  _errorMessage ?? 'حدث خطأ غير متوقع',
                  style: const TextStyle(color: Colors.white54, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: () => _loadData(forceRefresh: true),
                  icon: const Icon(Icons.refresh, color: Colors.black),
                  label: const Text('إعادة المحاولة', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD4AF37),
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('أهلاً بك، $_userName 👋',
                style: const TextStyle(color: Colors.white54, fontSize: 15)),
            const Text(
              'ابحث عن حلاقك المفضل',
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLocationBanner() {
    if (_userPosition != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green.withOpacity(0.3)),
        ),
        child: const Row(
          children: [
            Icon(Icons.near_me, color: Colors.green, size: 18),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'مرتبة حسب الأقرب إليك تلقائياً',
                style: TextStyle(color: Colors.green, fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: _isLocating ? null : _requestAndSortByLocation,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFFD4AF37).withOpacity(0.15),
              const Color(0xFFD4AF37).withOpacity(0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.4)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFD4AF37).withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: _isLocating
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Color(0xFFD4AF37)),
                    )
                  : const Icon(Icons.my_location, color: Color(0xFFD4AF37), size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isLocating ? 'جاري تحديد موقعك...' : 'احسب المسافة ورتّب الأقرب أولاً',
                    style: const TextStyle(
                        color: Color(0xFFD4AF37),
                        fontSize: 13,
                        fontWeight: FontWeight.bold),
                  ),
                  const Text('اضغط لتفعيل خدمة الموقع',
                      style: TextStyle(color: Colors.white38, fontSize: 11)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: Color(0xFFD4AF37), size: 14),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return GlassBox(
      borderRadius: 16,
      opacity: 0.05,
      child: TextField(
        controller: _searchController,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'ابحث عن صالون أو منطقة...',
          hintStyle: const TextStyle(color: Colors.white38),
          prefixIcon: const Icon(Icons.search, color: Color(0xFFD4AF37)),
          suffixIcon: IconButton(
            icon: Icon(
              Icons.tune,
              color: (_filters['minRating'] > 0 || _filters['showOnlyOpen'])
                  ? const Color(0xFFD4AF37)
                  : Colors.white24,
            ),
            onPressed: _openFilters,
          ),
          filled: true,
          fillColor: Colors.transparent,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
          color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
    );
  }

  Widget _buildSortHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'الصالونات المتاحة (${_filteredBarbershops.length})',
          style: const TextStyle(
              color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        if (_userPosition != null)
          Row(
            children: [
              const Icon(Icons.near_me, color: Color(0xFFD4AF37), size: 14),
              const SizedBox(width: 4),
              const Text('الأقرب أولاً',
                  style: TextStyle(color: Color(0xFFD4AF37), fontSize: 12)),
            ],
          ),
      ],
    );
  }

  Widget _buildHowItWorksBanner() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [
            const Color(0xFFD4AF37).withOpacity(0.15),
            const Color(0xFFB8860B).withOpacity(0.08),
          ],
        ),
        border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFD4AF37).withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.confirmation_number_outlined,
                    color: Color(0xFFD4AF37), size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                'كيف يعمل نظام الدور؟',
                style: TextStyle(
                    color: Color(0xFFD4AF37),
                    fontSize: 15,
                    fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const _StepRow(number: '1', text: 'احجز موعدك واحصل على رقم دورك'),
          const SizedBox(height: 8),
          const _StepRow(number: '2', text: 'تابع دورك مباشرة من التطبيق'),
          const SizedBox(height: 8),
          const _StepRow(number: '3', text: 'استقبل إشعاراً فور اقتراب دورك'),
        ],
      ),
    );
  }

  String _getTodayWorkingHours(Map<String, dynamic> hours) {
    if (hours.isEmpty) return '';
    final dayNames = {
      1: 'monday', 2: 'tuesday', 3: 'wednesday', 4: 'thursday',
      5: 'friday', 6: 'saturday', 7: 'sunday'
    };
    final today = dayNames[DateTime.now().weekday];
    final dayData = hours[today];
    if (dayData == null || dayData is! Map) return '';
    final isOpen = dayData['is_open'] ?? true;
    if (!isOpen) return 'مغلق اليوم';
    final openTime = dayData['open'] ?? dayData['start'] ?? '';
    final closeTime = dayData['close'] ?? dayData['end'] ?? '';
    if (openTime.toString().isEmpty || closeTime.toString().isEmpty) return '';

    // تحويل 10:00 إلى 10
    String formatTime(String time) {
      if (time.endsWith(':00')) return time.substring(0, time.length - 3);
      return time;
    }
    return 'متاح من ${formatTime(openTime.toString())} لـ ${formatTime(closeTime.toString())}';
  }

  Widget _buildBarberCard(Barbershop shop, int index) {
    final isFavorite = _favoriteIds.contains(shop.id);
    final distanceText = _formatDistance(shop);
    final isNearest = index == 0 && _userPosition != null && distanceText.isNotEmpty;
    
    String displayName = shop.name;
    final query = _searchController.text.toLowerCase();
    if (query.isNotEmpty) {
      final matchedStaff = shop.staffNames.where((staff) => staff.toLowerCase().contains(query)).toList();
      if (matchedStaff.isNotEmpty) {
        displayName = '${shop.name} (مع ${matchedStaff.first})';
      }
    }

    return RepaintBoundary( 
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => BarberDetailsScreen(barbershop: shop)),
          );
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 14),
          child: Stack(
            children: [
              GlassBox(
                borderRadius: 20,
                opacity: 0.05,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          width: 90,
                          height: 90,
                          color: const Color(0xFFD4AF37).withOpacity(0.1),
                          child: shop.logoUrl != null && shop.logoUrl!.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: shop.logoUrl!,
                                  fit: BoxFit.cover,
                                  memCacheWidth: 200, 
                                  placeholder: (context, url) => Container(
                                    color: Colors.white.withOpacity(0.05),
                                    child: const Center(
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFD4AF37)),
                                    ),
                                  ),
                                  errorWidget: (context, url, error) =>
                                      const Icon(Icons.store, color: Color(0xFFD4AF37), size: 40),
                                )
                              : const Icon(Icons.store, color: Color(0xFFD4AF37), size: 40),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    displayName,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => _toggleFavorite(shop.id),
                                  child: Padding(
                                    padding: const EdgeInsets.all(4),
                                    child: Icon(
                                      isFavorite ? Icons.favorite : Icons.favorite_border,
                                      color: isFavorite ? Colors.redAccent : Colors.white38,
                                      size: 20,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              shop.address,
                              style: const TextStyle(color: Colors.white54, fontSize: 12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Icon(Icons.star_rounded, color: Color(0xFFD4AF37), size: 16),
                                const SizedBox(width: 3),
                                Text(shop.rating.toStringAsFixed(1),
                                    style: const TextStyle(color: Colors.white70, fontSize: 13)),
                                const SizedBox(width: 10),
                                Container(
                                  width: 7,
                                  height: 7,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: shop.isOpen ? Colors.green : Colors.redAccent,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  shop.isOpen ? 'مفتوح' : 'مغلق',
                                  style: TextStyle(
                                    color: shop.isOpen ? Colors.green : Colors.redAccent,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                if (distanceText.isNotEmpty) ...[
                                  const Spacer(),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFD4AF37).withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                          color: const Color(0xFFD4AF37).withOpacity(0.4)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.near_me_rounded,
                                            color: Color(0xFFD4AF37), size: 13),
                                        const SizedBox(width: 3),
                                        Text(distanceText,
                                            style: const TextStyle(
                                                color: Color(0xFFD4AF37),
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            if (_getTodayWorkingHours(shop.workingHours).isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  const Icon(Icons.access_time, color: Colors.white54, size: 13),
                                  const SizedBox(width: 4),
                                  Text(
                                    _getTodayWorkingHours(shop.workingHours),
                                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (isNearest)
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD4AF37),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.location_on, color: Colors.black, size: 11),
                        SizedBox(width: 2),
                        Text('الأقرب',
                            style: TextStyle(
                                color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              if (_userPosition != null && index < 3)
                Positioned(
                  top: 10,
                  left: 10,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: index == 0
                          ? const Color(0xFFD4AF37)
                          : index == 1
                              ? Colors.grey[400]
                              : Colors.brown[300],
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(
                            color: Colors.black, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  final String number;
  final String text;
  const _StepRow({required this.number, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: const Color(0xFFD4AF37).withOpacity(0.2),
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.5)),
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                  color: Color(0xFFD4AF37),
                  fontSize: 12,
                  fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(text, style: const TextStyle(color: Colors.white70, fontSize: 13)),
      ],
    );
  }
}
