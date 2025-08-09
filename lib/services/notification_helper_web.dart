import 'package:flutter/foundation.dart';
import 'dart:async';
import 'package:js/js.dart';
import 'package:js/js_util.dart' as js_util;

@JS('window')
external dynamic get window;

/// Проверка разрешений на уведомления
Future<bool> requestNotificationPermission() async {
  final permission = await js_util.promiseToFuture<String>(
    js_util.callMethod(
      js_util.getProperty(window, 'Notification'),
      'requestPermission',
      [],
    ),
  );
  return permission == 'granted';
}

/// Показ уведомления в Web с обработчиком клика
Future<void> showWebNotification({
  required String title,
  required String body,
  String? icon,
  Map<String, dynamic>? data,
  void Function()? onClick,
}) async {
  final granted = await requestNotificationPermission();
  if (!granted) return;

  final options = {
    'body': body,
    'icon': icon ?? '/icons/Icon-192.png',
    'data': data ?? {},
  };

  final notificationConstructor = js_util.getProperty(window, 'Notification');
  final notification = js_util.callConstructor(notificationConstructor, [
    title,
    js_util.jsify(options),
  ]);

  // Проверяем наличие type и равенство 'new_task'
  if (data != null && data['type'] == 'new_task') {
    try {
      final audioConstructor = js_util.getProperty(window, 'Audio');
      final audio = js_util.callConstructor(audioConstructor, ['/sounds/new_task.wav']);
      js_util.callMethod(audio, 'play', []);
    } catch (e) {
      // Игнорируем ошибку, например, если нет доступа к аудио
    }
  }

  if (onClick != null) {
    // Устанавливаем обработчик onclick уведомления
    js_util.setProperty(notification, 'onclick', allowInterop((event) {
      onClick();
      // Пример: фокусируем окно, если нужно
      try {
        js_util.callMethod(window, 'focus', []);
      } catch (_) {}
      // Можно закрыть уведомление после клика
      js_util.callMethod(notification, 'close', []);
    }));
  }
}

/// Фокусировка окна
void focusWindow() {
  try {
    js_util.callMethod(window, 'focus', []);
  } catch (_) {}
}

bool checkPermissionWeb() {
  if (!kIsWeb) return true;
  try {
    final notification = js_util.getProperty(window, 'Notification');
    if (notification == null) {
      print('[notification_helper_web] Notification API недоступен');
      return false;
    }
    final permission = js_util.getProperty(notification, 'permission') as String? ?? 'default';
    print('[notification_helper_web] Текущее разрешение на уведомления: $permission');
    return permission == 'granted';
  } catch (e, st) {
    print('[notification_helper_web] Ошибка проверки разрешения: $e\n$st');
    return false;
  }
}
