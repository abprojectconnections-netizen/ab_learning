import 'dart:convert';

import 'package:ab_learning/core/network/api_client.dart';
import 'package:ab_learning/core/network/api_exception.dart';
import 'package:ab_learning/core/network/api_providers.dart';
import 'package:ab_learning/features/auth/data/rest_auth_repository.dart';
import 'package:ab_learning/features/auth/domain/user_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'support/fake_token_storage.dart';

http.Response jsonResponse(Object body, [int status = 200]) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

Map<String, dynamic> userJson({String role = 'LEARNER'}) => {
      'id': 7,
      'email': 'ada@example.test',
      'role': role,
      'first_name': 'Ada',
      'last_name': 'Lee',
      'avatar_url': '',
      'instructor_verified': false,
    };

Map<String, dynamic> sessionJson({String role = 'LEARNER'}) => {
      'access_token': 'access-1',
      'refresh_token': 'refresh-1',
      'user': userJson(role: role),
    };

class Harness {
  Harness(Future<http.Response> Function(http.Request request) handler)
      : tokens = FakeTokenStorage(),
        events = SessionEvents() {
    final client = MockClient((request) async {
      requests.add(request);
      return handler(request);
    });
    api = ApiClient(
      baseUrl: 'https://api.example.test',
      tokenStorage: tokens,
      client: client,
      onSessionExpired: events.notifyExpired,
    );
    repo = RestAuthRepository(api, tokens, sessionExpired: events.expired);
  }

  final FakeTokenStorage tokens;
  final SessionEvents events;
  final List<http.Request> requests = [];
  late final ApiClient api;
  late final RestAuthRepository repo;

  void dispose() {
    repo.dispose();
    events.dispose();
    api.close();
  }
}

void main() {
  group('RestAuthRepository sign in', () {
    test('stores tokens and maps the API user', () async {
      final h = Harness((r) async => jsonResponse(sessionJson()));
      addTearDown(h.dispose);

      final user = await h.repo.signIn(
          email: ' ada@example.test ', password: 'Password123!');

      expect(user.uid, '7');
      expect(user.email, 'ada@example.test');
      expect(user.role, UserRoleType.learner);
      expect(user.displayName, 'Ada Lee');
      expect(user.photoUrl, isNull);
      expect(h.tokens.access, 'access-1');
      expect(h.tokens.refresh, 'refresh-1');

      final request = h.requests.single;
      expect(request.method, 'POST');
      expect(request.url.path, '/api/v1/auth/login');
      expect(request.headers.containsKey('Authorization'), isFalse);
      expect(jsonDecode(request.body), {
        'identifier': 'ada@example.test',
        'password': 'Password123!',
      });
    });

    test('maps backend role names', () async {
      for (final entry in {
        'CORP_ADMIN': UserRoleType.corporateAdmin,
        'CORP_MANAGER': UserRoleType.corporateManager,
        'SUPER_ADMIN': UserRoleType.superAdmin,
        'INSTRUCTOR': UserRoleType.instructor,
      }.entries) {
        final h = Harness(
            (r) async => jsonResponse(sessionJson(role: entry.key)));
        final user = await h.repo.signIn(email: 'a@b.test', password: 'x');
        expect(user.role, entry.value, reason: entry.key);
        h.dispose();
      }
    });

    test('bad credentials throw ApiException and store nothing', () async {
      final h = Harness(
          (r) async => jsonResponse({'error': 'invalid credentials'}, 401));
      addTearDown(h.dispose);

      await expectLater(
        h.repo.signIn(email: 'a@b.test', password: 'wrong'),
        throwsA(isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 401)
            .having((e) => e.message, 'message', 'invalid credentials')),
      );
      expect(h.tokens.access, isNull);
      expect(h.tokens.refresh, isNull);
      // A failed login must not trigger a refresh attempt.
      expect(h.requests, hasLength(1));
    });

    test('a malformed response is rejected without storing tokens', () async {
      final h = Harness((r) async => jsonResponse({'access_token': 'x'}));
      addTearDown(h.dispose);

      await expectLater(
        h.repo.signIn(email: 'a@b.test', password: 'x'),
        throwsFormatException,
      );
      expect(h.tokens.access, isNull);
    });
  });

  group('RestAuthRepository register', () {
    test('sends first and last name and starts a session', () async {
      final h = Harness((r) async => jsonResponse(sessionJson(), 201));
      addTearDown(h.dispose);

      final user = await h.repo.register(
        email: 'ada@example.test',
        password: 'Password123!',
        firstName: ' Ada ',
        lastName: 'Lee',
      );

      expect(user.displayName, 'Ada Lee');
      expect(h.requests.single.url.path, '/api/v1/auth/register');
      expect(jsonDecode(h.requests.single.body), {
        'first_name': 'Ada',
        'last_name': 'Lee',
        'email': 'ada@example.test',
        'password': 'Password123!',
      });
      expect(h.tokens.refresh, 'refresh-1');
    });

    test('requires both names before calling the API', () async {
      final h = Harness((r) async => jsonResponse(sessionJson()));
      addTearDown(h.dispose);

      await expectLater(
        h.repo.register(email: 'a@b.test', password: 'x', firstName: 'Ada'),
        throwsArgumentError,
      );
      expect(h.requests, isEmpty);
    });
  });

  group('RestAuthRepository sign out and password reset', () {
    test('revokes the refresh token and clears local tokens', () async {
      final h = Harness((r) async => http.Response('', 204));
      addTearDown(h.dispose);
      h.tokens
        ..access = 'a'
        ..refresh = 'r';

      await h.repo.signOut();

      expect(h.requests.single.url.path, '/api/v1/auth/logout');
      expect(jsonDecode(h.requests.single.body), {'refresh_token': 'r'});
      expect(h.tokens.access, isNull);
      expect(h.tokens.refresh, isNull);
    });

    test('still clears local tokens when the server is unreachable', () async {
      final h = Harness((r) async => throw http.ClientException('offline'));
      addTearDown(h.dispose);
      h.tokens
        ..access = 'a'
        ..refresh = 'r';

      await h.repo.signOut();

      expect(h.tokens.hasSession(), completion(isFalse));
    });

    test('password reset posts the trimmed email without auth', () async {
      final h = Harness((r) async => jsonResponse({'message': 'ok'}, 202));
      addTearDown(h.dispose);

      await h.repo.sendPasswordReset(' ada@example.test ');

      expect(h.requests.single.url.path, '/api/v1/auth/password/forgot');
      expect(h.requests.single.headers.containsKey('Authorization'), isFalse);
      expect(jsonDecode(h.requests.single.body), {'email': 'ada@example.test'});
    });
  });

  group('RestAuthRepository session restore', () {
    test('no stored tokens means signed out, with no network call', () async {
      final h = Harness((r) async => jsonResponse(userJson()));
      addTearDown(h.dispose);

      expect(await h.repo.authStateChanges().first, isNull);
      expect(h.requests, isEmpty);
    });

    test('stored tokens restore the user from /me', () async {
      final h = Harness((r) async => jsonResponse(userJson()));
      addTearDown(h.dispose);
      h.tokens
        ..access = 'access-1'
        ..refresh = 'refresh-1';

      final user = await h.repo.authStateChanges().first;

      expect(user?.email, 'ada@example.test');
      expect(h.requests.single.url.path, '/api/v1/me');
      expect(h.requests.single.headers['Authorization'], 'Bearer access-1');
    });

    test('an expired access token is refreshed once and retried', () async {
      var meCalls = 0;
      final h = Harness((r) async {
        if (r.url.path == '/api/v1/auth/refresh') {
          expect(jsonDecode(r.body), {'refresh_token': 'refresh-1'});
          return jsonResponse(
              {'access_token': 'access-2', 'refresh_token': 'refresh-2'});
        }
        meCalls++;
        return meCalls == 1
            ? jsonResponse({'error': 'expired'}, 401)
            : jsonResponse(userJson());
      });
      addTearDown(h.dispose);
      h.tokens
        ..access = 'access-1'
        ..refresh = 'refresh-1';

      final user = await h.repo.authStateChanges().first;

      expect(user?.uid, '7');
      expect(h.tokens.access, 'access-2');
      expect(h.tokens.refresh, 'refresh-2');
      expect(h.requests.last.headers['Authorization'], 'Bearer access-2');
    });

    test('a rejected session is cleared and signs the user out', () async {
      final h = Harness((r) async => jsonResponse({'error': 'no'}, 401));
      addTearDown(h.dispose);
      h.tokens
        ..access = 'access-1'
        ..refresh = 'refresh-1';

      expect(await h.repo.authStateChanges().first, isNull);
      expect(await h.tokens.hasSession(), isFalse);
    });

    test('being offline keeps the stored tokens', () async {
      final h = Harness((r) async => throw http.ClientException('offline'));
      addTearDown(h.dispose);
      h.tokens
        ..access = 'access-1'
        ..refresh = 'refresh-1';

      expect(await h.repo.authStateChanges().first, isNull);
      expect(await h.tokens.hasSession(), isTrue);
    });

    test('session expiry from the API client signs the user out', () async {
      final h = Harness((r) async => jsonResponse(sessionJson()));
      addTearDown(h.dispose);
      final seen = <AppUser?>[];
      final sub = h.repo.authStateChanges().listen(seen.add);
      addTearDown(sub.cancel);

      await pumpEventQueue();
      await h.repo.signIn(email: 'a@b.test', password: 'x');
      await pumpEventQueue();
      h.events.notifyExpired();
      await pumpEventQueue();

      expect(seen.length, 3);
      expect(seen[0], isNull);
      expect(seen[1]?.uid, '7');
      expect(seen[2], isNull);
    });
  });
}
