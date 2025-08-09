// lib/main_navigation.dart
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
import 'package:js/js.dart';
@JS('window')
external dynamic get window;

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
  Future<void> initState() async {
    super.initState();
    _currentIndex = widget.initialTabIndex;

    // Проверяем разрешение для Web
    if (kIsWeb) {
      print('[Web] initState: начинаем проверку разрешения на уведомления...');
      _isNotificationPermissionGranted = FirebaseService.checkPermissionWeb();

      if (_isNotificationPermissionGranted) {
        final fcmToken = await FirebaseMessaging.instance.getToken();
        if (fcmToken != null) {
          await widget.apiClient.registerPushToken(fcmToken);
        }
      }

      setState(() {});
    }
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

        // Блокирующий overlay с сообщением и кнопкой для запроса разрешения (только Web и если нет разрешения)
        if (kIsWeb && !_isNotificationPermissionGranted)
          Positioned.fill(
            child: Container(
              color: Colors.black54,
              alignment: Alignment.topCenter,
              padding: const EdgeInsets.all(20),
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 16,
                    horizontal: 24,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Для корректной работы приложения\nпожалуйста, разрешите уведомления',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () async {
                          print('[Web] Кнопка "Разрешить уведомления" нажата');

                          final granted =
                              await FirebaseService.requestPermissionWeb();
                          setState(() {
                            _isNotificationPermissionGranted = granted;
                          });

                          print(
                            '[Web] После запроса разрешения _isNotificationPermissionGranted = $_isNotificationPermissionGranted',
                          );
                          if (_isNotificationPermissionGranted) {
                            final fcmToken = await FirebaseMessaging.instance
                                .getToken();
                            if (fcmToken != null) {
                              await widget.apiClient.registerPushToken(
                                fcmToken,
                              );
                            }
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Разрешение на уведомления получено',
                                ),
                              ),
                            );
                          }
                        },
                        child: const Text('Разрешить уведомления'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
