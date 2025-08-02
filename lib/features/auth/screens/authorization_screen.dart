import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
//import 'dart:io';
import 'package:universal_platform/universal_platform.dart';
import 'package:profit_league_documents/api/api_client.dart';
import 'package:profit_league_documents/features/auth/screens/registration_screen.dart';
import 'package:profit_league_documents/shared/auth_storage.dart';
import 'package:profit_league_documents/shared/widgets/company_footer.dart';
import 'package:profit_league_documents/firebase/firebase_service.dart';
import 'package:profit_league_documents/features/notifications/screens/push_details_screen.dart';
import 'package:profit_league_documents/navigation_service.dart';
import 'package:profit_league_documents/main_navigation.dart';
import 'package:profit_league_documents/utils/device_utils.dart';

class AuthorizationScreen extends StatefulWidget {
  final ApiClient apiClient;

  const AuthorizationScreen({super.key, required this.apiClient});

  @override
  State<AuthorizationScreen> createState() => _AuthorizationScreenState();
}

class _AuthorizationScreenState extends State<AuthorizationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordFocusNode = FocusNode();

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadSavedEmail();
  }

  Future<void> _loadSavedEmail() async {
    final savedEmail = await AuthStorage().getEmail();
    if (savedEmail != null && mounted) {
      setState(() {
        _emailController.text = savedEmail;
      });
      FocusScope.of(context).requestFocus(_passwordFocusNode);
    }
  }

  void _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final passwordHash = sha1.convert(utf8.encode(password)).toString();

    try {
      final response = await widget.apiClient.authorize(email, passwordHash);
      final expiresIn = response['expires_in'] as int;
      final accessTokenExpiresAt = DateTime.now().add(
        Duration(seconds: expiresIn),
      );

      await AuthStorage().saveTokens(
        email: email,
        accessToken: response['access_token'],
        refreshToken: response['refresh_token'],
        tokenType: response['token_type'],
        accessTokenExpiresAt: accessTokenExpiresAt,
      );

      // 🔐 Отправка FCM токена
      bool hasPushSupport = false;

      if (UniversalPlatform.isAndroid) {
        hasPushSupport = await DeviceUtils.hasGMS();
      } else if (UniversalPlatform.isIOS) {
        hasPushSupport = true;
      } else {
        // Web или другие платформы
        hasPushSupport = false;
      }

      if (hasPushSupport) {
        final fcmToken = await FirebaseMessaging.instance.getToken();
        if (fcmToken != null) {
          await widget.apiClient.registerPushToken(fcmToken);
        }
      }

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            //builder: (context) => DocumentScreen(apiClient: widget.apiClient),
            builder: (_) => MainNavigation(apiClient: widget.apiClient),
          ),
        );
      }

      // ✅ После перехода на DocumentScreen — проверим initial push
      if (hasPushSupport) {
        final pushData = FirebaseService.consumeInitialPushData();
        if (pushData != null) {
          // используем глобальный navigatorKey
          navigatorKey.currentState?.push(
            MaterialPageRoute(builder: (_) => PushDetailsScreen(data: pushData)),
          );
        }
      }

    } on ApiException catch (e) {
      setState(() {
        _errorMessage = '${e.message}\n${e.details ?? ''}';
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Неизвестная ошибка: $e';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _navigateToRegistration() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RegistrationScreen(apiClient: widget.apiClient),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Авторизация'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    if (_errorMessage != null) ...[
                      Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                    ],
                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(labelText: 'Почта'),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null ||
                            !RegExp(r'^\S+@\S+\.\S+$').hasMatch(value)) {
                          return 'Введите корректный email';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      focusNode: _passwordFocusNode,
                      decoration: const InputDecoration(labelText: 'Пароль'),
                      obscureText: true,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Введите пароль';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    _isLoading
                        ? const CircularProgressIndicator()
                        : Column(
                            children: [
                              ElevatedButton(
                                onPressed: _login,
                                child: const Text('Войти'),
                              ),
                              const SizedBox(height: 12),
                              TextButton(
                                onPressed: _navigateToRegistration,
                                child: const Text('Зарегистрироваться'),
                              ),
                            ],
                          ),
                  ],
                ),
              ),
            ),
          ),
          const CompanyFooter(),
        ],
      ),
    );
  }
}
