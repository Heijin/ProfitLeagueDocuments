import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../utils/device_utils.dart';
import 'dart:developer';
import 'dart:convert';
import '../api/api_client.dart';
import '../features/notifications/screens/push_details_screen.dart';
import '../navigation_service.dart';
import 'package:flutter/foundation.dart';
import 'package:app_settings/app_settings.dart';
import 'firebase_options.dart';

final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
FlutterLocalNotificationsPlugin();
final ApiClient _apiClient = ApiClient();

Map<String, dynamic>? _initialPushData;

class FirebaseService {
  static Future<void> initialize() async {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    // Проверка GMS только для Android
    final hasGMS = await DeviceUtils.hasGMS();
    if (!hasGMS && defaultTargetPlatform == TargetPlatform.android) {
      log('🚫 Устройство Android без GMS — пропускаем инициализацию FCM');
      return;
    }

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    final messaging = FirebaseMessaging.instance;
    final settings = await messaging.requestPermission(alert: true, badge: true, sound: true);
    log('🔔 Статус разрешения на пуши: ${settings.authorizationStatus}');
    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      showDialog(
        context: navigatorKey.currentContext!,
        builder: (context) => AlertDialog(
          title: const Text('Уведомления отключены'),
          content: const Text('Вы отключили уведомления. Вы можете включить их в настройках приложения.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Позже'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await AppSettings.openAppSettings(); // Открытие настроек
              },
              child: const Text('Открыть настройки'),
            ),
          ],
        ),
      );
    }

    final token = await messaging.getToken();
    log('📱 FCM токен: $token');

    if (token != null) {
      await _safeRegisterToken(token);

      if (!kIsWeb) {
        try {
          await messaging.subscribeToTopic("news");
          log('✅ Подписка на топик "news" выполнена');
        } catch (e) {
          log('❌ Ошибка подписки на топик "news": $e');
        }
      } else {
        log('ℹ️ Пропущена подписка на топик — Web-платформа не поддерживает');
      }
    }


    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _flutterLocalNotificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        if (details.payload != null) {
          try {
            final data = jsonDecode(details.payload!);
            _openPushScreen(data);
          } catch (e) {
            log('❌ Ошибка при парсинге payload: $e');
          }
        }
      },
    );

    // Каналы только для Android
    if (defaultTargetPlatform == TargetPlatform.android) {
      const newTaskChannel = AndroidNotificationChannel(
        'new_task_channel',
        'Новые задачи',
        description: 'Канал для новых задач с кастомным звуком',
        importance: Importance.high,
        sound: RawResourceAndroidNotificationSound('new_task'),
      );

      const defaultChannel = AndroidNotificationChannel(
        'default_channel',
        'Обычные уведомления',
        description: 'Канал по умолчанию',
        importance: Importance.high,
      );

      final androidPlugin = _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

      await androidPlugin?.createNotificationChannel(newTaskChannel);
      await androidPlugin?.createNotificationChannel(defaultChannel);
    }

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final notification = message.notification;
      final type = message.data['type'];

      final data = {
        'title': notification?.title,
        'body': notification?.body,
        ...message.data,
      };

      if (notification != null) {
        final isNewTask = type == 'new_task';

        final androidDetails = AndroidNotificationDetails(
          isNewTask ? 'new_task_channel' : 'default_channel',
          isNewTask ? 'Новые задачи' : 'Обычные уведомления',
          channelDescription:
          isNewTask ? 'Канал для новых задач с кастомным звуком' : 'Канал по умолчанию',
          importance: Importance.max,
          priority: Priority.high,
          sound: isNewTask ? RawResourceAndroidNotificationSound('new_task') : null,
          icon: '@mipmap/ic_launcher',
        );

        final iosDetails = DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          sound: isNewTask ? 'new_task.wav' : null,
        );

        final notificationDetails = NotificationDetails(
          android: androidDetails,
          iOS: iosDetails,
        );

        _flutterLocalNotificationsPlugin.show(
          notification.hashCode,
          notification.title,
          notification.body,
          notificationDetails,
          payload: jsonEncode(data),
        );
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _openPushScreen({
        'title': message.notification?.title,
        'body': message.notification?.body,
        ...message.data,
      });
    });

    final initialMessage = await messaging.getInitialMessage();
    if (initialMessage != null) {
      _initialPushData = {
        'title': initialMessage.notification?.title,
        'body': initialMessage.notification?.body,
        ...initialMessage.data,
      };
      log('🚀 Запуск из terminated push');
    }
  }

  static Map<String, dynamic>? consumeInitialPushData() {
    final data = _initialPushData;
    _initialPushData = null;
    return data;
  }

  static void _openPushScreen(Map<String, dynamic> data) {
    final context = navigatorKey.currentContext;
    if (context != null) {
      navigatorKey.currentState?.push(
        MaterialPageRoute(builder: (_) => PushDetailsScreen(data: data)),
      );
    } else {
      log('⚠️ navigatorKey недоступен — не удалось открыть экран');
    }
  }

  static Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
    await Firebase.initializeApp();
    log('🕹️ Фоновое уведомление: ${message.notification?.title}');
  }

  static Future<void> _safeRegisterToken(String token) async {
    try {
      await _apiClient.registerPushToken(token);
      log('✅ FCM токен отправлен на сервер');
    } catch (e) {
      log('❌ Ошибка отправки токена: $e');
    }
  }
}
