import 'package:flutter/material.dart';
import 'package:profit_league_documents/api/api_client.dart';
import 'package:profit_league_documents/features/auth/screens/authorization_screen.dart';
import 'package:profit_league_documents/features/notifications/screens/push_details_screen.dart';
import 'package:profit_league_documents/shared/auth_storage.dart';
import 'package:profit_league_documents/firebase/firebase_service.dart';
import 'package:profit_league_documents/navigation_service.dart';
import 'package:profit_league_documents/main_navigation.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FirebaseService.initialize(); // навигатор уже доступен через navigation_service.dart
  runApp(MyApp());
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
            foregroundColor: Colors.red, // цвет текста и ripple
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
              //builder: (_) => DocumentScreen(apiClient: widget.apiClient),
              builder: (_) => MainNavigation(apiClient: widget.apiClient),
            ),
          );

          // ✅ Обработка пуша после авторизации по токену
          final pushData = FirebaseService.consumeInitialPushData();
          if (pushData != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              navigatorKey.currentState?.push(
                MaterialPageRoute(
                  builder: (_) => PushDetailsScreen(data: pushData),
                ),
              );
            });
          }

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
