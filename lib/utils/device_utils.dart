import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart'; // для kIsWeb
import 'dart:developer';

class DeviceUtils {
  /// Проверка наличия GMS (исключает Huawei)
  static Future<bool> hasGMS() async {
    if (kIsWeb) {
      log('🌐 Web-платформа, GMS неприменимо → true');
      return true;
    }

    try {
      final deviceInfo = await DeviceInfoPlugin().androidInfo;
      final manufacturer = deviceInfo.manufacturer?.toLowerCase() ?? '';
      final hasGMS = manufacturer != 'huawei';
      log('🔍 Проверка GMS: $manufacturer → ${hasGMS ? "да" : "нет"}');
      return hasGMS;
    } catch (e) {
      log('❌ Ошибка при проверке GMS: $e');
      return true; // По умолчанию считаем, что GMS есть
    }
  }
}
