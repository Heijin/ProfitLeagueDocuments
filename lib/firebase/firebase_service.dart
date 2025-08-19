import 'dart:convert';
import 'dart:developer';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
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
    WidgetsFlutterBinding.ensureInitialized();

    // Инициализация Firebase
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // Запрос разрешений на iOS
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      // Настройки отображения пушей в foreground для iOS
      await messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    }

    // Настройки локальных уведомлений
    const AndroidInitializationSettings androidSettings =
    AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const InitializationSettings initSettings =
    InitializationSettings(android: androidSettings, iOS: iosSettings);

    await flutterLocalNotificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        if (details.payload != null) {
          _handleMessage(jsonDecode(details.payload!));
        }
      },
    );

    // Создание кастомных Android каналов (твой оригинальный код)
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

      final androidPlugin = flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

      await androidPlugin?.createNotificationChannel(newTaskChannel);
      await androidPlugin?.createNotificationChannel(defaultChannel);
    }

    // Обработчики пушей
    _setupForegroundMessageHandler();
    _setupBackgroundMessageHandler();

    // Получение push при запуске из terminated
    _initialMessage = await messaging.getInitialMessage();

    // Получение FCM токена
    String? fcmToken = await messaging.getToken();
    log('✅ FCM Token: $fcmToken');
  }

  /// Foreground уведомления (только data-only на iOS)
  static void _setupForegroundMessageHandler() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      log('📩 Получено push-сообщение (foreground): ${message.data}');

      final notification = message.notification;
      final type = message.data['type'];
      final isNewTask = type == 'new_task';

      // На iOS пуш с notification будет показан системой, дублировать не нужно
      if (notification != null && defaultTargetPlatform == TargetPlatform.iOS) {
        return;
      }

      final title = notification?.title ?? message.data['title'] ?? 'Уведомление';
      final body = notification?.body ?? message.data['body'] ?? '';

      final androidDetails = AndroidNotificationDetails(
        isNewTask ? 'new_task_channel' : 'default_channel',
        isNewTask ? 'Новые задачи' : 'Обычные уведомления',
        channelDescription: isNewTask
            ? 'Канал для новых задач с кастомным звуком'
            : 'Канал по умолчанию',
        importance: Importance.max,
        priority: Priority.high,
        sound: isNewTask ? RawResourceAndroidNotificationSound('new_task') : null,
        icon: '@mipmap/ic_launcher',
      );

      final iosDetails = const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      final details = NotificationDetails(android: androidDetails, iOS: iosDetails);

      await flutterLocalNotificationsPlugin.show(
        title.hashCode,
        title,
        body,
        details,
        payload: jsonEncode(message.data),
      );
    });
  }

  /// Background / terminated уведомления
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
      log('📩 Push открыл приложение из terminated: ${_initialMessage!.data}');
      final data = _initialMessage!.data;
      _initialMessage = null;
      return data;
    }
    return null;
  }
}
