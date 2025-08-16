import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:google_api_availability/google_api_availability.dart';
import 'dart:developer';

class DeviceUtils {
  static Future<bool> hasGMS() async {

    if (Platform.isIOS) {
      log('🍏 iOS-платформа, GMS неприменимо → true');
      return true;
    }

    try {
      final status = await GoogleApiAvailability.instance.checkGooglePlayServicesAvailability();
      final result = status == GooglePlayServicesAvailability.success;
      log('✅ GMS статус: $status → ${result ? "доступен" : "недоступен"}');
      return result;
    } catch (e) {
      log('❌ Ошибка при проверке GMS: $e');
      return false;
    }
  }
}
