import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:profit_league_documents/api/api_client.dart';
import 'package:profit_league_documents/features/auth/screens/authorization_screen.dart';
import 'package:profit_league_documents/shared/auth_storage.dart';
import 'package:profit_league_documents/firebase/firebase_service.dart';
import 'package:profit_league_documents/navigation_service.dart';
import 'package:profit_league_documents/main_navigation.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FirebaseService.initialize();

  if (!kIsWeb) {
    await _requestNotificationPermissionIfNeeded();
  }

  runApp(MyApp());
}

Future<void> _requestNotificationPermissionIfNeeded() async {
  if (defaultTargetPlatform == TargetPlatform.android) {
    final androidInfo = await DeviceInfoPlugin().androidInfo;
    if (androidInfo.version.sdkInt >= 33) {
      final status = await Permission.notification.status;
      if (!status.isGranted) {
        await Permission.notification.request();
      }
    }
  }
}

class MyApp extends StatelessWidget {
  final ApiClient _apiClient = ApiClient();

  MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Документы',
      navigatorKey: navigatorKey,
      theme: ThemeData(
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(48),
            shadowColor: Colors.transparent,
          ),
        ),
        primarySwatch: Colors.green,
        fontFamily: 'Roboto',
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: Colors.red,
          ),
        ),
      ),
      home: StartScreen(apiClient: _apiClient),
      debugShowCheckedModeBanner: false,
    );
  }
}

class StartScreen extends StatefulWidget {
  final ApiClient apiClient;

  const StartScreen({super.key, required this.apiClient});

  @override
  State<StartScreen> createState() => _StartScreenState();
}

class _StartScreenState extends State<StartScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuthAndNavigate();
  }

  Future<void> _checkAuthAndNavigate() async {
    final storage = AuthStorage();
    final accessToken = await storage.getAccessToken();
    final expiresAt = await storage.getAccessTokenExpiresAt();

    final hasValidToken = accessToken != null &&
        expiresAt != null &&
        DateTime.now().isBefore(expiresAt);

    if (hasValidToken) {
      try {
        final response = await widget.apiClient.get('/ping');
        if (response.statusCode == 200 && mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => MainNavigation(apiClient: widget.apiClient),
            ),
          );

          // Просто вызываем метод, не сохраняем его результат
          //FirebaseService.consumeInitialPushData();

          return;
        }
      } catch (_) {}
    }

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => AuthorizationScreen(apiClient: widget.apiClient),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
