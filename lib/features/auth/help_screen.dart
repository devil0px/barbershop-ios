import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  Future<void> _launchURL(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('المساعدة والدعم', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionHeader('الأسئلة الشائعة'),
          _buildFaqItem(
            'كيف أحجز موعد؟',
            'اختر الصالون المناسب من الصفحة الرئيسية، ثم اختر الخدمة واضغط على "احجز الآن". سيتم تحديد رقم دورك تلقائياً.',
          ),
          _buildFaqItem(
            'كيف أعرف رقم دوري؟',
            'يمكنك معرفة رقم دورك من صفحة "حجوزاتي" أو من شاشة تأكيد الحجز مباشرة بعد الحجز.',
          ),
          _buildFaqItem(
            'كيف ألغي حجزي؟',
            'اذهب إلى صفحة "حجوزاتي"، اختر الحجز الذي تريد إلغاءه، ثم اضغط على زر الإلغاء.',
          ),
          _buildFaqItem(
            'هل يمكنني تغيير موعد الحجز؟',
            'حالياً لا يمكن تغيير موعد الحجز. يمكنك إلغاء الحجز الحالي وإنشاء حجز جديد.',
          ),
          const Divider(color: Colors.white12, height: 32),
          _buildSectionHeader('تواصل معنا'),
          _buildContactItem(Icons.email_outlined, 'البريد الإلكتروني', 'support@barbershop.com', () {
            _launchURL('mailto:support@barbershop.com');
          }),
          _buildContactItem(Icons.phone_outlined, 'الهاتف', '+20 123 456 7890', () {
            _launchURL('tel:+201234567890');
          }),
          _buildContactItem(Icons.chat_outlined, 'واتساب', 'تحدث معنا عبر واتساب', () {
            _launchURL('https://wa.me/201234567890');
          }),
          const SizedBox(height: 32),
          Center(
            child: Text(
              'نحن هنا لمساعدتك على مدار الساعة',
              style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 12),
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

  Widget _buildFaqItem(String question, String answer) {
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: Text(question, style: const TextStyle(color: Colors.white)),
      iconColor: const Color(0xFFD4AF37),
      collapsedIconColor: Colors.white54,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Text(answer, style: const TextStyle(color: Colors.white54, fontSize: 14)),
        ),
      ],
    );
  }

  Widget _buildContactItem(IconData icon, String title, String subtitle, VoidCallback onTap) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: const Color(0xFFD4AF37)),
      title: Text(title, style: const TextStyle(color: Colors.white)),
      subtitle: Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 12)),
      trailing: const Icon(Icons.chevron_left, color: Colors.white24),
      onTap: onTap,
    );
  }
}
