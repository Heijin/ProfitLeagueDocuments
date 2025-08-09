import 'dart:convert';
import 'dart:developer';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:profit_league_documents/api/api_client.dart';
import 'package:profit_league_documents/navigation_service.dart';
import 'package:profit_league_documents/features/notifications/screens/push_details_screen.dart';
import 'package:profit_league_documents/shared/auth_storage.dart';
import 'package:app_settings/app_settings.dart';
import 'package:profit_league_documents/firebase/firebase_options.dart';
import 'package:profit_league_documents/services/notification_helper.dart';

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
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
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

    if (kIsWeb) {
      final fcmToken = await AuthStorage().getFcmToken();
      // fcmToken можно позже отправить при авторизации
    } else {
      await _requestPermission();
      await _getToken();
    }

    _setupForegroundMessageHandler();
    _setupBackgroundMessageHandler();

    _initialMessage = await messaging.getInitialMessage();
  }

  static Future<bool> requestPermissionWeb() async {
    if (!kIsWeb) return true;
    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    log('🔔 [WEB] Статус разрешения на пуши: ${settings.authorizationStatus}');
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  static Future<void> _requestPermission() async {
    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    log('🔔 Статус разрешения на пуши: ${settings.authorizationStatus}');

    if (!kIsWeb && settings.authorizationStatus == AuthorizationStatus.denied) {
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
  }

  static Future<void> _getToken() async {
    final token = await messaging.getToken();
    log('📱 FCM токен: $token');
    final accessToken = await AuthStorage().getAccessToken();
    if (token != null && accessToken != null) {
      try {
        await ApiClient().post(
          '/registerPushToken',
          body: {'pushToken': token},
          headers: {'Authorization': 'Bearer $accessToken'},
        );
        log('✅ FCM токен отправлен на сервер');
      } catch (e) {
        log('❌ Ошибка при отправке FCM токена: $e');
      }
    }
  }

  static Future<String?> getTokenWeb() async {
    if (!kIsWeb) return null;
    try {
      final token = await messaging.getToken();
      log('📱 [WEB] FCM токен: $token');
      return token;
    } catch (e) {
      log('❌ Ошибка получения FCM токена для Web: $e');
      return null;
    }
  }

  static void _setupForegroundMessageHandler() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      log('📩 Получено push-сообщение (foreground): ${message.data}');

      final notification = message.notification;
      final android = notification?.android;
      final type = message.data['type'];
      final isNewTask = type == 'new_task';

      // --- Web: показываем нативный Web Notification ---
      if (kIsWeb) {
        final title = notification?.title ?? message.data['title'] ?? '';
        final body = notification?.body ?? message.data['body'] ?? '';
        // путь к иконке укажи свой, например '/icons/icon-192.png'
        showWebNotification(
          title: title,
          body: body,
          data: message.data,
          icon: '/icons/icon-192.png',
          onClick: () {
            navigatorKey.currentState?.push(
              MaterialPageRoute(
                builder: (_) => PushDetailsScreen(
                    data: {
                      'title': message.notification?.title,
                      'body': message.notification?.body,
                      ...message.data,
                    }),
              ),
            );
          },
        );

        return;
      }

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
