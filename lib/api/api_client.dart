import 'dart:convert';
import 'package:http/http.dart' as http;
import 'models/photo.dart';
import 'package:profit_league_documents/shared/auth_storage.dart';

class ApiClient {
  //static const String _baseHost = 'exchange.pr-lg.ru';
  static const String _baseHost = 'neptune.pr-lg.ru:81';
  //static const String _baseHost = '10.0.17.18:81';
  //static const String _basePath = '/trade11-photoSave/hs/PhotoSave';
  static const String _basePath = '/trade115-tkach-photoSave/hs/PhotoSave';
  static const bool _useHttps = false;

  final http.Client _http = http.Client();
  final AuthStorage _storage = AuthStorage();

  Future<Map<String, dynamic>> authorize(String email, String passwordHash) async {
    final uri = _buildUri('/authorize', queryParameters: {
      'email': email,
      'password': passwordHash,
    });

    final response = await _http.get(uri);
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> register(String email, String passwordHash, String userName) async {
    final uri = _buildUri('/registration');
    final response = await _http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': passwordHash,
        'userName': userName,
      }),
    );
    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> refreshToken() async {
    final refreshToken = await _storage.getRefreshToken();
    if (refreshToken == null) throw Exception('Нет refresh_token');

    final uri = _buildUri('/token');
    final response = await _http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'grant_type': 'refresh_token',
        'refresh_token': refreshToken,
      }),
    );

    final data = await _handleResponse(response);
    await _storage.saveTokensFromResponse(data);
    return data;
  }

  Future<Map<String, dynamic>> getDocumentInfo(String navLink) async {
    await _ensureValidToken();
    return _retryIfTokenExpired(() async {
      final token = await _storage.getAccessToken();
      final uri = _buildUri('/docInfo', queryParameters: {'navLink': navLink});

      final response = await _http.get(
        uri,
        headers: {
          'token': '$token',
          'Content-Type': 'application/json',
        },
      );
      return _handleResponse(response);
    });
  }

  Future<Map<String, dynamic>> parkDocument(String navLink, String areaId) async {
    await _ensureValidToken();
    return _retryIfTokenExpired(() async {
      final token = await _storage.getAccessToken();
      final uri = _buildUri('/park');

      final response = await _http.post(
        uri,
        headers: {
          'token': '$token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'navLink': navLink,
          'areaId': areaId,
        }),
      );
      return _handleResponse(response);
    });
  }

  Future<Map<String, dynamic>> sendPhotoToBackend(Photo photo, String navLink) async {
    await _ensureValidToken();
    return _retryIfTokenExpired(() async {
      final token = await _storage.getAccessToken();
      final uri = _buildUri('/docPhoto', queryParameters: {'navLink': navLink});

      String base64Image = photo.filePath;
      // Удаляем префикс Data URL, если он присутствует
      if (base64Image.startsWith('data:image/')) {
        base64Image = base64Image.split(',').last;
      }

      //print('Sending base64 for photo ${photo.name}: ${base64Image.substring(0, 100)}...'); // Отладочный вывод

      final response = await _http.post(
        uri,
        headers: {
          'token': '$token',
          'Content-Type': 'application/json; charset=utf-8',
        },
        body: jsonEncode({
          'base64': base64Image,
          'name': photo.name,
          'ext': photo.ext,
        }),
      );
      return _handleResponse(response);
    });
  }

  Future<http.Response> get(
      String path, {
        Map<String, String>? headers,
        bool withAuth = true,
      }) async {
    final uri = _buildUri(path);

    if (!withAuth) {
      // Запрос без авторизации
      return _http.get(
        uri,
        headers: headers,
      );
    }

    // Запрос с авторизацией
    await _ensureValidToken();
    return _retryIfTokenExpired(() async {
      final token = await _storage.getAccessToken();
      return _http.get(
        uri,
        headers: {
          'token': '$token',
          ...?headers,
        },
      );
    });
  }


  Future<http.Response> post(String path, {Map<String, String>? headers, Object? body}) async {
    await _ensureValidToken();
    return _retryIfTokenExpired(() async {
      final token = await _storage.getAccessToken();
      final uri = _buildUri(path);
      return _http.post(
        uri,
        headers: {
          'token': '$token',
          'Content-Type': 'application/json',
          ...?headers,
        },
        body: jsonEncode(body),
      );
    });
  }

  // === INTERNAL HELPERS ===

  Uri _buildUri(String path, {Map<String, String>? queryParameters, bool useHttps = _useHttps}) {
    return useHttps
        ? Uri.https(_baseHost, '$_basePath$path', queryParameters)
        : Uri.http(_baseHost, '$_basePath$path', queryParameters);
  }

  Future<void> _ensureValidToken() async {
    final expiresAt = await _storage.getAccessTokenExpiresAt();
    if (expiresAt == null || DateTime.now().isAfter(expiresAt)) {
      await refreshToken();
    }
  }

  Future<T> _retryIfTokenExpired<T>(Future<T> Function() requestFn) async {
    final response = await requestFn();
    if (response is http.Response && response.statusCode == 401) {
      final data = jsonDecode(response.body);
      if (data['code'] == 'TOKEN_EXPIRED') {
        await refreshToken();
        return await requestFn();
      }
    }
    return response;
  }

  Future<Map<String, dynamic>> _handleResponse(http.Response response) async {
    final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      return data;
    } else {
      throw ApiException(
        code: data['code'] ?? 'UNKNOWN_ERROR',
        message: data['message'] ?? 'Ошибка сервера',
        details: data['details'],
      );
    }
  }

  Future<void> registerPushToken(String pushToken) async {
    await _ensureValidToken();
    await _retryIfTokenExpired(() async {
      final token = await _storage.getAccessToken();
      final uri = _buildUri('/registerPushToken');

      final response = await _http.post(
        uri,
        headers: {
          'token': '$token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'pushToken': pushToken}),
      );

      if (response.statusCode != 200) {
        throw ApiException(
          code: 'PUSH_TOKEN_ERROR',
          message: 'Не удалось зарегистрировать push-токен',
          details: response.body,
        );
      }

      return null;
    });
  }

}

class ApiException implements Exception {
  final String code;
  final String message;
  final dynamic details;

  ApiException({required this.code, required this.message, this.details});

  @override
  String toString() => '[$code] $message';
}