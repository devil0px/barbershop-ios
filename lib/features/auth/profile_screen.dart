import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/widgets/glass_box.dart';
import '../../core/services/notification_ws_service.dart';
import 'auth_repository.dart';
import '../booking/booking_repository.dart';
import 'edit_profile_screen.dart';
import 'settings_screen.dart';
import 'help_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthRepository _authRepository = AuthRepository();
  final BookingRepository _bookingRepository = BookingRepository();
  String _fullName = 'جاري التحميل...';
  String _email = '';
  String? _photoUrl;
  bool _isLoading = true;
  Map<String, dynamic>? _rawUserData;
  
  // Stats
  int _totalBookings = 0;
  int _pendingBookings = 0;
  int _completedBookings = 0;
  int _cancelledBookings = 0;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadStats();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _fullName = prefs.getString('full_name') ?? 'مستخدم';
        _email = prefs.getString('user_email') ?? '';
        _photoUrl = prefs.getString('profile_photo');
      });
    }

    final userData = await _authRepository.getMe();
    if (userData != null && mounted) {
      setState(() {
        _rawUserData = userData;
        _fullName = userData['full_name'] ?? 'مستخدم';
        _email = userData['email'] ?? '';
        _photoUrl = userData['profile_photo_url'];
        _isLoading = false;
      });
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadStats() async {
    try {
      final bookings = await _bookingRepository.getMyBookings();
      if (mounted) {
        setState(() {
          _totalBookings = bookings.length;
          _pendingBookings = bookings.where((b) => b.status == 'pending').length;
          _completedBookings = bookings.where((b) => b.status == 'completed').length;
          _cancelledBookings = bookings.where((b) => b.status == 'cancelled').length;
        });
      }
    } catch (e) {
      print('Error loading stats: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('الملف الشخصي', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: RefreshIndicator(
        onRefresh: _loadUserData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFD4AF37), width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFD4AF37).withOpacity(0.2),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: 60,
                  backgroundColor: const Color(0xFF333333),
                  backgroundImage: (_photoUrl != null && _photoUrl!.isNotEmpty) 
                    ? NetworkImage(_photoUrl!) 
                    : null,
                  child: (_photoUrl == null || _photoUrl!.isEmpty) 
                    ? const Icon(Icons.person, size: 60, color: Color(0xFFD4AF37)) 
                    : null,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _fullName,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
              ),
              Text(
                _email,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white54, fontSize: 16),
              ),
              const SizedBox(height: 32),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildStatItem('الحجوزات', _totalBookings.toString()),
                  _buildStatItem('قيد الانتظار', _pendingBookings.toString()),
                  _buildStatItem('المكتملة', _completedBookings.toString()),
                ],
              ),
              const SizedBox(height: 32),
              _buildProfileOption(Icons.person_outline, 'تعديل الملف الشخصي', () async {
                if (_rawUserData != null) {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => EditProfileScreen(userData: _rawUserData!)),
                  );
                  if (result == true) {
                    _loadUserData();
                  }
                }
              }),
              _buildProfileOption(Icons.settings_outlined, 'الإعدادات', () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsScreen()));
              }),
              _buildProfileOption(Icons.help_outline, 'المساعدة والدعم', () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const HelpScreen()));
              }),
              const SizedBox(height: 16),
              _buildProfileOption(Icons.logout, 'تسجيل الخروج', () async {
                await _authRepository.logout();
                // ✅ Disconnect WebSocket notification channel
                NotificationWsService().disconnect();
                // Clear all caches on logout (Mutation)
                BookingRepository.invalidateCache();
                if (mounted) {
                  Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
                }
              }, isDestructive: true),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return GlassBox(
      borderRadius: 16,
      opacity: 0.05,
      child: Container(
        padding: const EdgeInsets.all(16),
        width: 100,
        child: Column(
          children: [
            Text(value, style: const TextStyle(color: Color(0xFFD4AF37), fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileOption(IconData icon, String title, VoidCallback onTap, {bool isDestructive = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: GlassBox(
        borderRadius: 16,
        opacity: isDestructive ? 0.02 : 0.05,
        child: ListTile(
          onTap: onTap,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          leading: Icon(icon, color: isDestructive ? Colors.redAccent : const Color(0xFFD4AF37)),
          title: Text(title, style: TextStyle(color: isDestructive ? Colors.redAccent : Colors.white, fontWeight: FontWeight.w500)),
          trailing: Icon(Icons.chevron_left, color: isDestructive ? Colors.redAccent.withOpacity(0.5) : Colors.white24),
        ),
      ),
    );
  }
}
