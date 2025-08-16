import 'dart:convert';
import 'dart:developer';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:profit_league_documents/navigation_service.dart';
import 'package:profit_league_documents/features/notifications/screens/push_details_screen.dart';
import 'package:profit_league_documents/firebase/firebase_options.dart';

class FirebaseService {
  static final FirebaseMessaging messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();
  static RemoteMessage? _initialMessage;

  static Future<void> initialize() async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (details) {
        if (details.payload != null) {
          _handleMessage(jsonDecode(details.payload!));
        }
      },
    );

    // ✅ Создание кастомных Android каналов
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

      final androidPlugin =
      flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

      await androidPlugin?.createNotificationChannel(newTaskChannel);
      await androidPlugin?.createNotificationChannel(defaultChannel);
    }

    _setupForegroundMessageHandler();
    _setupBackgroundMessageHandler();

    _initialMessage = await messaging.getInitialMessage();
  }

  static void _setupForegroundMessageHandler() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      log('📩 Получено push-сообщение (foreground): ${message.data}');

      final notification = message.notification;
      final android = notification?.android;
      final type = message.data['type'];
      final isNewTask = type == 'new_task';

      // --- Mobile (Android / iOS) ---
      // Если у нас есть объект notification — используем его (ручное отображение через flutter_local_notifications)
      if (notification != null) {
        AndroidNotificationDetails? androidDetails;
        if (android != null) {
          androidDetails = AndroidNotificationDetails(
            isNewTask ? 'new_task_channel' : 'default_channel',
            isNewTask ? 'Новые задачи' : 'Обычные уведомления',
            channelDescription:
            isNewTask ? 'Канал для новых задач с кастомным звуком' : 'Канал по умолчанию',
            importance: Importance.max,
            priority: Priority.high,
            sound: isNewTask ? RawResourceAndroidNotificationSound('new_task') : null,
            icon: '@mipmap/ic_launcher',
          );
        }

        final iosDetails = DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          // Для кастомного звука на iOS можно указать: sound: 'new_task.caf'
          // но файл должен быть добавлен в бандл iOS.
          // sound: isNewTask ? 'new_task.caf' : null,
        );

        final details = NotificationDetails(
          android: androidDetails,
          iOS: iosDetails,
        );

        flutterLocalNotificationsPlugin.show(
          notification.hashCode,
          notification.title,
          notification.body,
          details,
          payload: jsonEncode(message.data),
        );
        return;
      }

      // --- Если нет notification, но есть data (data-only message) — можно отобразить локально тоже ---
      if (message.data.isNotEmpty) {
        final title = message.data['title'] ?? 'Уведомление';
        final body = message.data['body'] ?? '';
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
        );

        final details = NotificationDetails(android: androidDetails, iOS: iosDetails);

        flutterLocalNotificationsPlugin.show(
          title.hashCode,
          title,
          body,
          details,
          payload: jsonEncode(message.data),
        );
      }
    });
  }

  static void _setupBackgroundMessageHandler() {
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      log('📩 Push-сообщение открыло приложение (background): ${message.data}');
      _handleMessage(message.data);
    });
  }

  static void _handleMessage(Map<String, dynamic> data) {
    final context = navigatorKey.currentContext;
    if (context != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PushDetailsScreen(data: data),
        ),
      );
    } else {
      log('⚠️ Контекст недоступен при открытии пуша');
    }
  }

  static Map<String, dynamic>? consumeInitialPushData() {
    if (_initialMessage != null) {
      log('📩 Push-сообщение открыло приложение (terminated): ${_initialMessage!.data}');
      final data = _initialMessage!.data;
      _initialMessage = null;
      return data;
    }
    return null;
  }
}
