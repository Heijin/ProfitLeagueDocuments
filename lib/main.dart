import 'package:flutter/material.dart';
import 'package:profit_league_documents/api/api_client.dart';
import 'package:profit_league_documents/features/auth/screens/authorization_screen.dart';
import 'package:profit_league_documents/features/documents/screens/document_screen.dart';
import 'package:profit_league_documents/shared/auth_storage.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  final ApiClient _apiClient = ApiClient();

  MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Документы',
      theme: ThemeData(
        primarySwatch: Colors.green,
        fontFamily: 'Roboto', // Указываем sans-serif шрифт Roboto
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          elevation: 0,
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

    final bool hasValidToken = accessToken != null &&
        expiresAt != null &&
        DateTime.now().isBefore(expiresAt);

    if (hasValidToken) {
      try {
        final response = await widget.apiClient.get('/ping');
        if (response.statusCode == 200) {
          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => DocumentScreen(apiClient: widget.apiClient),
            ),
          );
          return;
        }
      } catch (_) {
        // ignore errors, fall back to auth screen
      }
    }

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => AuthorizationScreen(apiClient: widget.apiClient),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
