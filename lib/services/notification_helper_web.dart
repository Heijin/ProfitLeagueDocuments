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
