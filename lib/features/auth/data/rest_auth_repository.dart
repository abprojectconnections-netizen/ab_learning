// lib/features/auth/data/rest_auth_repository.dart
//
// AuthRepository backed by the Go + MySQL API (access JWT + rotating opaque
// refresh token). Selected when --dart-define=API_BASE_URL is set.
import 'dart:async';
import 'dart:convert';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/storage/token_storage.dart';
import '../domain/user_model.dart';
import 'auth_repository.dart';

class RestAuthRepository implements AuthRepository {
  RestAuthRepository(
    this._api,
    this._tokens, {
    Stream<void>? sessionExpired,
  }) {
    _expiredSub = sessionExpired?.listen((_) => _setUser(null));
  }

  final ApiClient _api;
  final TokenStorage _tokens;
  final StreamController<AppUser?> _controller =
      StreamController<AppUser?>.broadcast();
  StreamSubscription<void>? _expiredSub;
  AppUser? _current;
  Future<AppUser?>? _restoring;

  void dispose() {
    _expiredSub?.cancel();
    _controller.close();
  }

  @override
  Stream<AppUser?> authStateChanges() async* {
    await (_restoring ??= _restore());
    yield _current;
    yield* _controller.stream;
  }

  /// Restores a stored session. A rejected session (401) is cleared; a network
  /// failure keeps the tokens so the user is not logged out while offline.
  Future<AppUser?> _restore() async {
    if (!await _tokens.hasSession()) {
      _current = null;
      return null;
    }
    try {
      final res = await _api.get('/api/v1/me');
      _current = _userFrom(_decodeMap(res.body));
    } on ApiException catch (e) {
      if (e.statusCode == 401) await _tokens.clear();
      _current = null;
    } catch (_) {
      _current = null;
    }
    return _current;
  }

  @override
  Future<AppUser> signIn(
      {required String email, required String password}) async {
    final res = await _api.post(
      '/api/v1/auth/login',
      body: {'identifier': email.trim(), 'password': password},
      authenticated: false,
    );
    return _startSession(res.body);
  }

  @override
  Future<AppUser> register({
    required String email,
    required String password,
    String? firstName,
    String? lastName,
  }) async {
    final first = firstName?.trim() ?? '';
    final last = lastName?.trim() ?? '';
    if (first.isEmpty || last.isEmpty) {
      throw ArgumentError('firstName and lastName are required');
    }
    final res = await _api.post(
      '/api/v1/auth/register',
      body: {
        'first_name': first,
        'last_name': last,
        'email': email.trim(),
        'password': password,
      },
      authenticated: false,
    );
    return _startSession(res.body);
  }

  @override
  Future<void> signOut() async {
    final refresh = await _tokens.readRefreshToken();
    if (refresh != null && refresh.isNotEmpty) {
      try {
        await _api.post(
          '/api/v1/auth/logout',
          body: {'refresh_token': refresh},
          authenticated: false,
        );
      } catch (_) {
        // The local session is cleared even if the server is unreachable.
      }
    }
    await _tokens.clear();
    _setUser(null);
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    await _api.post(
      '/api/v1/auth/password/forgot',
      body: {'email': email.trim()},
      authenticated: false,
    );
  }

  Future<AppUser> _startSession(String body) async {
    final json = _decodeMap(body);
    final access = json['access_token'];
    final refresh = json['refresh_token'];
    final user = json['user'];
    if (access is! String ||
        access.isEmpty ||
        refresh is! String ||
        refresh.isEmpty ||
        user is! Map<String, dynamic>) {
      throw const FormatException('Unexpected authentication response');
    }
    await _tokens.saveTokens(accessToken: access, refreshToken: refresh);
    final appUser = _userFrom(user);
    _setUser(appUser);
    return appUser;
  }

  void _setUser(AppUser? user) {
    _current = user;
    if (!_controller.isClosed) _controller.add(user);
  }

  static Map<String, dynamic> _decodeMap(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Expected a JSON object');
    }
    return decoded;
  }

  static AppUser _userFrom(Map<String, dynamic> json) {
    final first = (json['first_name'] as String?)?.trim() ?? '';
    final last = (json['last_name'] as String?)?.trim() ?? '';
    final name = '$first $last'.trim();
    final avatar = json['avatar_url'];
    return AppUser(
      uid: '${json['id']}',
      email: (json['email'] as String?) ?? '',
      role: UserRoleTypeClaim.fromClaim(json['role']),
      displayName: name.isEmpty ? null : name,
      photoUrl: avatar is String && avatar.isNotEmpty ? avatar : null,
    );
  }
}
