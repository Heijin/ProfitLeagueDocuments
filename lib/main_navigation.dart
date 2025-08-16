// lib/main_navigation.dart
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:profit_league_documents/api/api_client.dart';
import 'package:profit_league_documents/features/documents/screens/document_screen.dart';
import 'package:profit_league_documents/features/documents/screens/task_list_screen.dart';
import 'package:profit_league_documents/features/settings/screens/settings_screen.dart';
import 'package:profit_league_documents/firebase/firebase_service.dart';
import 'features/notifications/screens/push_details_screen.dart';
import 'navigation_service.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:app_settings/app_settings.dart';

class MainNavigation extends StatefulWidget {
  final ApiClient apiClient;
  final int initialTabIndex;

  const MainNavigation({
    super.key,
    required this.apiClient,
    this.initialTabIndex = 0,
  });

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  late int _currentIndex;
  bool _initialPushHandled = false;

  // Состояние для блокировки экрана (веб)
  bool _isNotificationPermissionGranted =
      true; // по умолчанию true, чтобы не блокировать мобилки

  @override
  void initState() {
    super.initState();
    _initAsync(); // запускаем асинхронную инициализацию
    _currentIndex = widget.initialTabIndex;
  }

  Future<void> _initAsync() async {

    _isNotificationPermissionGranted = await _requestPermission();

    if (_isNotificationPermissionGranted) {
      final fcmToken = await FirebaseMessaging.instance.getToken();
      if (fcmToken != null) {
        await widget.apiClient.registerPushToken(fcmToken);
      }
    }

    setState(() {});
  }

  static Future<bool> _requestPermission() async {

    final FirebaseMessaging messaging = FirebaseMessaging.instance;
    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    log('🔔 Статус разрешения на пуши: ${settings.authorizationStatus}');

    if (settings.authorizationStatus == AuthorizationStatus.authorized)
      {
        return true;
      }

    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      final context = navigatorKey.currentContext;
      if (context != null) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Уведомления отключены'),
            content: const Text(
              'Вы отключили уведомления. Вы можете включить их в настройках приложения.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Позже'),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await AppSettings.openAppSettings();
                },
                child: const Text('Открыть настройки'),
              ),
            ],
          ),
        );
      } else {
        log('⚠️ Контекст недоступен для отображения диалога.');
      }
    }
    return false;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    if (!_initialPushHandled) {
      _initialPushHandled = true;
      final data = FirebaseService.consumeInitialPushData();
      if (data != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          print('[App] Обрабатываем initial push data');
          navigatorKey.currentState?.push(
            MaterialPageRoute(
              builder: (_) =>
                  PushDetailsScreen(apiClient: widget.apiClient, data: data),
            ),
          );
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      DocumentScreen(apiClient: widget.apiClient),
      TaskListScreen(apiClient: widget.apiClient),
      SettingsScreen(apiClient: widget.apiClient),
    ];

    return Stack(
      children: [
        Scaffold(
          body: screens[_currentIndex],
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _currentIndex,
            onTap: (index) => setState(() => _currentIndex = index),
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.camera_alt),
                label: 'Сделать фото',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.list_alt),
                label: 'Активные',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.settings),
                label: 'Настройки',
              ),
            ],
          ),
        ),
      ],
    );
  }
}
