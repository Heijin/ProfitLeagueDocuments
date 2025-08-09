// lib/services/notification_helper_stub.dart
/// Заглушка, чтобы импорт был безопасен на non-web платформах.
void showWebNotification({
  required String title,
  required String body,
  Map<String, dynamic>? data,
  String? icon,
}) {
  // noop on non-web
}