// lib/shared/validators.dart
class Validators {
  /// Проверка email
  static bool isValidEmail(String? email) {
    if (email == null) return false;
    final emailRegex = RegExp(r'^\S+@\S+\.\S+$');
    return emailRegex.hasMatch(email);
  }

  /// Проверка сложности пароля
  /// Минимум 6 символов, хотя бы одна буква, хотя бы одна цифра, хотя бы один спецсимвол
  static String? validatePassword(String? value) {
    if (value == null || value.length < 6) {
      return 'Пароль должен быть не менее 6 символов';
    }
    if (!RegExp(r'[A-ZА-Яa-zа-я]').hasMatch(value)) {
      return 'Пароль должен содержать буквы';
    }
    if (!RegExp(r'\d').hasMatch(value)) {
      return 'Пароль должен содержать цифры';
    }
    if (!RegExp(r'[!@#\$%^&*(),.?":{}|<>]').hasMatch(value)) {
      return 'Пароль должен содержать спец. символ';
    }
    return null;
  }
}
