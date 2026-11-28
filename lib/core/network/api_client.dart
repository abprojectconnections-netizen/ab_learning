import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../storage/token_storage.dart';
import 'api_exception.dart';

class ApiClient {
  ApiClient({
    required String baseUrl,
    required TokenStorage tokenStorage,
    http.Client? client,
    this.timeout = const Duration(seconds: 15),
    this.onSessionExpired,
  })  : _baseUri = Uri.parse(baseUrl.trim().replaceFirst(RegExp(r'/+$'), '')),
        _tokenStorage = tokenStorage,
        _client = client ?? http.Client() {
    if (!_baseUri.hasScheme ||
        !_baseUri.hasAuthority ||
        (_baseUri.scheme != 'http' && _baseUri.scheme != 'https')) {
      throw ArgumentError.value(baseUrl, 'baseUrl', 'Invalid API URL');
    }
  }

  final Uri _baseUri;
  final TokenStorage _tokenStorage;
  final http.Client _client;
  final Duration timeout;

  /// Called when a request got 401 and the refresh token could not renew the
  /// session (tokens are cleared first).
  final void Function()? onSessionExpired;

  Future<bool>? _refreshing;

  Uri _uri(String path) {
    final normalized = path.startsWith('/') ? path : '/$path';
    return _baseUri.resolve(normalized);
  }

  Future<http.Response> get(
    String path, {
    bool authenticated = true,
  }) {
    return _request('GET', path, authenticated: authenticated);
  }

  Future<http.Response> post(
    String path, {
    Object? body,
    bool authenticated = true,
  }) {
    return _request(
      'POST',
      path,
      body: body,
      authenticated: authenticated,
    );
  }

  Future<http.Response> put(
    String path, {
    Object? body,
    bool authenticated = true,
  }) {
    return _request(
      'PUT',
      path,
      body: body,
      authenticated: authenticated,
    );
  }

  Future<http.Response> _send(
    String method,
    String path, {
    Object? body,
    bool authenticated = true,
  }) async {
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json; charset=utf-8',
    };

    if (authenticated) {
      final token = await _tokenStorage.readAccessToken();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    final request = http.Request(method, _uri(path));
    request.headers.addAll(headers);

    if (body != null) {
      request.body = jsonEncode(body);
    }

    try {
      final streamed = await _client.send(request).timeout(timeout);
      return await http.Response.fromStream(streamed).timeout(timeout);
    } on TimeoutException {
      rethrow;
    } on http.ClientException {
      rethrow;
    }
  }

  Future<http.Response> _request(
    String method,
    String path, {
    Object? body,
    bool authenticated = true,
  }) async {
    var response = await _send(
      method,
      path,
      body: body,
      authenticated: authenticated,
    );

    if (response.statusCode == 401 && authenticated) {
      final refreshed = await _refreshAccessToken();

      if (refreshed) {
        response = await _send(
          method,
          path,
          body: body,
          authenticated: true,
        );
      } else {
        onSessionExpired?.call();
      }
    }

    _checkResponse(response);
    return response;
  }

  Future<bool> _refreshAccessToken() async {
    final existing = _refreshing;
    if (existing != null) return existing;

    final future = _performRefresh();
    _refreshing = future;

    try {
      return await future;
    } finally {
      if (identical(_refreshing, future)) {
        _refreshing = null;
      }
    }
  }

  Future<bool> _performRefresh() async {
    final refreshToken = await _tokenStorage.readRefreshToken();

    if (refreshToken == null || refreshToken.isEmpty) {
      await _tokenStorage.clear();
      return false;
    }

    final request = http.Request(
      'POST',
      _uri('/api/v1/auth/refresh'),
    );

    request.headers.addAll({
      'Accept': 'application/json',
      'Content-Type': 'application/json; charset=utf-8',
    });

    request.body = jsonEncode({
      'refresh_token': refreshToken,
    });

    final streamed = await _client.send(request).timeout(timeout);
    final response = await http.Response.fromStream(streamed).timeout(timeout);

    if (response.statusCode != 200) {
      await _tokenStorage.clear();
      return false;
    }

    try {
      final decoded = jsonDecode(response.body);

      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Invalid refresh response');
      }

      final access = decoded['access_token'];
      final refresh = decoded['refresh_token'];

      if (access is! String ||
          access.isEmpty ||
          refresh is! String ||
          refresh.isEmpty) {
        throw const FormatException('Missing refreshed tokens');
      }

      await _tokenStorage.saveTokens(
        accessToken: access,
        refreshToken: refresh,
      );

      return true;
    } on FormatException {
      await _tokenStorage.clear();
      return false;
    }
  }

  void _checkResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return;
    }

    String message = 'Request failed';

    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic> && decoded['error'] is String) {
        message = decoded['error'] as String;
      }
    } on FormatException {
      // Keep the generic message for non-JSON responses.
    }

    throw ApiException(
      statusCode: response.statusCode,
      message: message,
    );
  }

  void close() {
    _client.close();
  }
}
