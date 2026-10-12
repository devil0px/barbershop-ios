import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

class UpdateRequiredScreen extends StatelessWidget {
  final String title;
  final String message;
  final String storeUrl;
  final String buttonText;

  const UpdateRequiredScreen({
    super.key,
    this.title = 'تحديث جديد متوفر',
    this.message =
        'يتوفر إصدار جديد من تطبيق Barbershop. يرجى التحديث للمتابعة والاستفادة من أحدث الخدمات والميزات.',
    this.storeUrl =
        'https://play.google.com/store/apps/details?id=com.barber2shop',
    this.buttonText = 'تحديث الآن',
  });

  Future<void> _openStore(BuildContext context) async {
    final uri = Uri.parse(storeUrl);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        // Fallback for Android Market intent
        final marketUri =
            Uri.parse('market://details?id=com.barber2shop');
        if (await canLaunchUrl(marketUri)) {
          await launchUrl(marketUri, mode: LaunchMode.externalApplication);
        }
      }
    } catch (e) {
      debugPrint('Error launching store URL: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // PopScope with canPop: false prevents the user from dismissing via the back button
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFF121212),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28.0, vertical: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(),

                // Glowing Gold Update Icon
                Center(
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFD4AF37).withOpacity(0.12),
                      border: Border.all(
                        color: const Color(0xFFD4AF37).withOpacity(0.5),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFD4AF37).withOpacity(0.25),
                          blurRadius: 30,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.system_update_rounded,
                      size: 60,
                      color: Color(0xFFD4AF37),
                    ),
                  ),
                ),

                const SizedBox(height: 36),

                // Title
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.cairo(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 16),

                // Message
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 15,
                    height: 1.6,
                  ),
                ),

                const Spacer(),

                // Update Now Button
                ElevatedButton(
                  onPressed: () => _openStore(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD4AF37),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 5,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.download_rounded, color: Colors.black),
                      const SizedBox(width: 8),
                      Text(
                        buttonText,
                        style: GoogleFonts.cairo(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
