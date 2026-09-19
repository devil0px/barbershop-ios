import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;
  bool _darkMode = true;
  String _language = 'ar';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
      _darkMode = prefs.getBool('dark_mode') ?? true;
      _language = prefs.getString('language') ?? 'ar';
    });
  }

  Future<void> _saveSetting(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is bool) {
      await prefs.setBool(key, value);
    } else if (value is String) {
      await prefs.setString(key, value);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('الإعدادات', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionHeader('التنبيهات'),
          _buildSwitchTile(
            'تفعيل الإشعارات',
            'استلام إشعارات الحجوزات والتحديثات',
            Icons.notifications_outlined,
            _notificationsEnabled,
            (value) {
              setState(() => _notificationsEnabled = value);
              _saveSetting('notifications_enabled', value);
            },
          ),
          const Divider(color: Colors.white12),
          _buildSectionHeader('المظهر'),
          _buildSwitchTile(
            'الوضع الداكن',
            'استخدام الألوان الداكنة للتطبيق',
            Icons.dark_mode_outlined,
            _darkMode,
            (value) {
              setState(() => _darkMode = value);
              _saveSetting('dark_mode', value);
            },
          ),
          const Divider(color: Colors.white12),
          _buildSectionHeader('اللغة'),
          _buildLanguageTile(),
          const Divider(color: Colors.white12),
          _buildSectionHeader('حول التطبيق'),
          _buildInfoTile('الإصدار', '1.0.0'),
          _buildInfoTile('المطور', 'Barbershop Team'),
          const SizedBox(height: 32),
          Center(
            child: TextButton(
              onPressed: () {
                showAboutDialog(
                  context: context,
                  applicationName: 'Barbershop',
                  applicationVersion: '1.0.0',
                  applicationLegalese: '© 2024 Barbershop. جميع الحقوق محفوظة.',
                );
              },
              child: const Text('حول التطبيق', style: TextStyle(color: Color(0xFFD4AF37))),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Text(
        title,
        style: const TextStyle(color: Color(0xFFD4AF37), fontSize: 14, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildSwitchTile(String title, String subtitle, IconData icon, bool value, Function(bool) onChanged) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: Colors.white54),
      title: Text(title, style: const TextStyle(color: Colors.white)),
      subtitle: Text(subtitle, style: const TextStyle(color: Colors.white38, fontSize: 12)),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: const Color(0xFFD4AF37),
      ),
    );
  }

  Widget _buildLanguageTile() {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.language, color: Colors.white54),
      title: const Text('اللغة', style: TextStyle(color: Colors.white)),
      subtitle: Text(_language == 'ar' ? 'العربية' : 'English', style: const TextStyle(color: Colors.white38, fontSize: 12)),
      trailing: DropdownButton<String>(
        value: _language,
        dropdownColor: const Color(0xFF2A2A2A),
        underline: const SizedBox(),
        items: const [
          DropdownMenuItem(value: 'ar', child: Text('العربية', style: TextStyle(color: Colors.white))),
          DropdownMenuItem(value: 'en', child: Text('English', style: TextStyle(color: Colors.white))),
        ],
        onChanged: (value) {
          if (value != null) {
            setState(() => _language = value);
            _saveSetting('language', value);
          }
        },
      ),
    );
  }

  Widget _buildInfoTile(String title, String value) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title, style: const TextStyle(color: Colors.white)),
      trailing: Text(value, style: const TextStyle(color: Colors.white54)),
    );
  }
}
