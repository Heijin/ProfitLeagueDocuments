import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthStorage {
  static const _storage = FlutterSecureStorage();

  static const _kEmail = 'email';
  static const _kAccessToken = 'access_token';
  static const _kRefreshToken = 'refresh_token';
  static const _kAccessTokenExpiresIn = 'access_token_expires_in';
  static const _kTokenType = 'token_type';
  static const _kDocuments = 'documents';
  // Новый ключ для FCM токена
  static const _kFcmToken = 'fcm_token';

  Future<void> saveTokens({
    required String email,
    required String accessToken,
    required String refreshToken,
    required DateTime accessTokenExpiresAt,
    required String tokenType,
  }) async {
    await _storage.write(key: _kEmail, value: email);
    await _storage.write(key: _kAccessToken, value: accessToken);
    await _storage.write(key: _kRefreshToken, value: refreshToken);
    await _storage.write(key: _kAccessTokenExpiresIn, value: accessTokenExpiresAt.toIso8601String());
    await _storage.write(key: _kTokenType, value: tokenType);
  }

  Future<void> saveTokensFromResponse(Map<String, dynamic> json) async {
    final email = await getEmail() ?? '';
    final expiresIn = json['expires_in'] as int;
    final expiresAt = DateTime.now().add(Duration(seconds: expiresIn));

    await saveTokens(
      email: email,
      accessToken: json['access_token'],
      refreshToken: json['refresh_token'],
      tokenType: json['token_type'],
      accessTokenExpiresAt: expiresAt,
    );
  }

  Future<void> saveDocuments(String documentsJson) async {
    await _storage.write(key: _kDocuments, value: documentsJson);
  }

  Future<String?> getDocuments() async {
    return await _storage.read(key: _kDocuments);
  }

  Future<void> clearDocuments() async {
    await _storage.delete(key: _kDocuments);
  }

  Future<String?> getAccessToken() => _storage.read(key: _kAccessToken);
  Future<String?> getRefreshToken() => _storage.read(key: _kRefreshToken);
  Future<String?> getTokenType() => _storage.read(key: _kTokenType);
  Future<String?> getEmail() => _storage.read(key: _kEmail);

  Future<DateTime?> getAccessTokenExpiresAt() async {
    final value = await _storage.read(key: _kAccessTokenExpiresIn);
    if (value == null) return null;
    return DateTime.tryParse(value);
  }

  Future<void> clear() async {
    await _storage.deleteAll();
  }

  Future<void> saveEmail(String email) async {
    await _storage.write(key: _kEmail, value: email);
  }

  Future<void> saveFcmToken(String token) async {
    await _storage.write(key: _kFcmToken, value: token);
  }

  Future<String?> getFcmToken() async {
    return await _storage.read(key: _kFcmToken);
  }

  Future<void> clearFcmToken() async {
    await _storage.delete(key: _kFcmToken);
  }
}