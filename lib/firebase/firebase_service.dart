import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:developer';
import 'dart:convert';

import '../api/api_client.dart';
import '../features/notifications/screens/push_details_screen.dart';
import '../navigation_service.dart';

final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
FlutterLocalNotificationsPlugin();
final ApiClient _apiClient = ApiClient();

Map<String, dynamic>? _initialPushData;

class FirebaseService {
  static Future<void> initialize() async {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    final messaging = FirebaseMessaging.instance;
    final settings =
    await messaging.requestPermission(alert: true, badge: true, sound: true);
    log('🔔 Статус разрешения на пуши: ${settings.authorizationStatus}');

    final token = await messaging.getToken();
    log('📱 FCM токен: $token');

    if (token != null) {
      await _safeRegisterToken(token);
      // Подписка на топик "news"
      try {
        await messaging.subscribeToTopic("news");
        log('✅ Подписка на топик "news" выполнена');
      } catch (e) {
        log('❌ Ошибка подписки на топик "news": $e');
      }
    }

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);

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

    // Регистрируем кастомный канал со звуком new_task.wav (должен лежать в android/app/src/main/res/raw)
    const newTaskChannel = AndroidNotificationChannel(
      'new_task_channel',
      'Новые задачи',
      description: 'Канал для новых задач с кастомным звуком',
      importance: Importance.high,
      sound: RawResourceAndroidNotificationSound('new_task'),
    );

    // Стандартный канал
    const defaultChannel = AndroidNotificationChannel(
      'default_channel',
      'Обычные уведомления',
      description: 'Канал по умолчанию',
      importance: Importance.high,
    );

    final androidPlugin =
    _flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    await androidPlugin?.createNotificationChannel(newTaskChannel);
    await androidPlugin?.createNotificationChannel(defaultChannel);

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final notification = message.notification;
      final type = message.data['type']; // тип уведомления (например, 'new_task')

      final data = {
        'title': notification?.title,
        'body': notification?.body,
        ...message.data,
      };

      if (notification != null) {
        // Выбор канала и звука
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

        final notificationDetails = NotificationDetails(android: androidDetails);

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
