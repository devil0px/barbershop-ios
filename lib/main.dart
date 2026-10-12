import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'core/screens/splash_screen.dart';
import 'features/auth/login_page.dart';
import 'features/auth/register_page.dart';
import 'core/main_navigation.dart';
import 'core/services/notification_service.dart';
import 'core/services/notification_ws_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/network/api_service.dart';

/// ✅ CRITICAL: Background/Terminated FCM message handler
/// Must be a TOP-LEVEL function (not inside a class) with this pragma annotation.
/// This runs in a SEPARATE ISOLATE — no UI access allowed.
///
/// Android behaviour:
/// • If message has notification payload → system shows it automatically, this
///   handler still runs for data processing.
/// • If message is DATA-ONLY → system does NOT show anything automatically;
///   we MUST show a local notification here.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();

  debugPrint(
      '📩 BG FCM: notification=${message.notification?.title}, data=${message.data}');

  // Build title/body from notification payload OR data payload
  final String title = message.notification?.title ??
      message.data['title'] ??
      message.data['type'] ??
      'إشعار جديد';

  final String body = message.notification?.body ??
      message.data['body'] ??
      message.data['message'] ??
      '';

  // For DATA-ONLY messages the system won't show anything — show manually.
  // For messages with a notification payload the system already shows a banner
  // on most Android versions, but we still show one to ensure delivery on
  // Chinese OEM phones that suppress system FCM notifications.
  try {
    final FlutterLocalNotificationsPlugin localNotifications =
        FlutterLocalNotificationsPlugin();

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    await localNotifications.initialize(
      const InitializationSettings(android: androidSettings),
    );

    // Ensure channel exists (idempotent) — ✅ Use Importance.max for alert
    final androidPlugin = localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        'barbershop_high_importance',
        'إشعارات الصالون',
        description: 'إشعارات الحجوزات والرسائل من تطبيق الصالون',
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        showBadge: true,
      ),
    );

    if (title.isNotEmpty) {
      // ✅ Unique ID with prefix 200000 to avoid collision with foreground/WS
      final notificationId =
          200000 + (DateTime.now().millisecondsSinceEpoch % 100000);

      await localNotifications.show(
        notificationId,
        title,
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'barbershop_high_importance',
            'إشعارات الصالون',
            channelDescription:
                'إشعارات الحجوزات والرسائل من تطبيق الصالون',
            importance: Importance.max,
            priority: Priority.max,
            icon: '@mipmap/ic_launcher',
            playSound: true,
            enableVibration: true,
            // ✅ Show on lock screen
            visibility: NotificationVisibility.public,
            // ✅ Ticker text
            ticker: 'إشعار جديد من الصالون',
            // ✅ Notification category
            category: AndroidNotificationCategory.message,
          ),
        ),
      );
      debugPrint('✅ Background local notification shown: $title');
    }
  } catch (e) {
    debugPrint('⚠️ Background local notification error: $e');
  }
}


void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 🛡️ Global Error Shield: Capture all Flutter-level errors
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('Global Flutter Error: ${details.exception}');
  };

  // Capture errors outside the Flutter context (Asynchronous errors)
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Global Async Error: $error');
    return true;
  };

  // Initialize Firebase
  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    await NotificationService.initialize();
  } catch (e) {
    debugPrint('Firebase initialization error: $e');
  }

  await initializeDateFormatting('ar', null);

  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('access_token');
  ApiService().setAccessToken(token);

  // ✅ Start WebSocket notification listener if user is already logged in
  // This maintains a real-time channel for instant in-app + banner notifications
  if (token != null && token.isNotEmpty) {
    NotificationWsService().connect();
  }

  runApp(const BarberShopApp());
}

class BarberShopApp extends StatelessWidget {
  const BarberShopApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'El Shmony Barber',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFFD4AF37),
        scaffoldBackgroundColor: const Color(0xFF1A1A1A),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFD4AF37),
          secondary: Color(0xFFD4AF37),
          surface: Color(0xFF252525),
          onSurface: Colors.white,
          background: Color(0xFF1A1A1A),
        ),
        textTheme: GoogleFonts.cairoTextTheme(ThemeData.dark().textTheme),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1A1A1A),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        snackBarTheme: const SnackBarThemeData(
          backgroundColor: Color(0xFF2A2A2A),
          contentTextStyle: TextStyle(color: Colors.white),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white.withOpacity(0.05),
          labelStyle: const TextStyle(color: Colors.white60),
          hintStyle: const TextStyle(color: Colors.white38),
        ),
        useMaterial3: true,
      ),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('ar', ''),
        Locale('en', ''),
      ],
      // Force Arabic as default — always RTL
      locale: const Locale('ar', ''),
      localeResolutionCallback: (locale, supportedLocales) {
        // Always use Arabic for this app
        return const Locale('ar', '');
      },
      builder: (context, child) {
        // 🏗️ Architecture Mutation: Global Error Boundary UI
        ErrorWidget.builder = (FlutterErrorDetails details) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, color: Color(0xFFD4AF37), size: 60),
                    const SizedBox(height: 16),
                    const Text(
                      'نعتذر، حدث خطأ غير متوقع',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      details.exceptionAsString(),
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                      textAlign: TextAlign.center,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pushReplacementNamed('/'),
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD4AF37)),
                      child: const Text('إعادة تحميل التطبيق', style: TextStyle(color: Colors.black)),
                    ),
                  ],
                ),
              ),
            ),
          );
        };

        return Directionality(
          textDirection: TextDirection.rtl,
          child: child!,
        );
      },
      // Start at SplashScreen which handles session check & routing
      home: const SplashScreen(),
      routes: {
        '/': (context) => const MainNavigationContainer(),
        '/login': (context) => const LoginPage(),
        '/register': (context) => const RegisterPage(),
      },
    );
  }
}
