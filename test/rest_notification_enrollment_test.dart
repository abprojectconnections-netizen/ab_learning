import 'dart:async';
import 'dart:convert';

import 'package:ab_learning/core/network/api_client.dart';
import 'package:ab_learning/core/network/api_exception.dart';
import 'package:ab_learning/core/network/polling_stream.dart';
import 'package:ab_learning/features/enrollment/data/rest_enrollment_repository.dart';
import 'package:ab_learning/features/notification/data/rest_notification_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'support/fake_token_storage.dart';

http.Response json(Object body, [int status = 200]) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

ApiClient client(FakeTokenStorage tokens, List<http.Request> log,
        Future<http.Response> Function(http.Request) handler) =>
    ApiClient(
      baseUrl: 'https://api.example.test',
      tokenStorage: tokens,
      client: MockClient((r) async {
        log.add(r);
        return handler(r);
      }),
    );

void main() {
  group('pollingStream', () {
    test('loads on listen, on refresh and on the interval', () async {
      var calls = 0;
      final refresh = StreamController<void>.broadcast();
      addTearDown(refresh.close);
      final values = <int>[];
      final sub = pollingStream<int>(() async => ++calls,
              interval: const Duration(milliseconds: 40),
              refresh: refresh.stream)
          .listen(values.add);
      addTearDown(sub.cancel);

      await pumpEventQueue();
      expect(values, [1]);
      refresh.add(null);
      await pumpEventQueue();
      expect(values, [1, 2]);
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(values.length, greaterThanOrEqualTo(3));
    });

    test('reports load errors without closing the stream', () async {
      var calls = 0;
      final refresh = StreamController<void>.broadcast();
      addTearDown(refresh.close);
      final values = <int>[];
      final errors = <Object>[];
      final sub = pollingStream<int>(() async {
        calls++;
        if (calls == 1) throw StateError('offline');
        return calls;
      }, interval: const Duration(hours: 1), refresh: refresh.stream)
          .listen(values.add, onError: errors.add);
      addTearDown(sub.cancel);

      await pumpEventQueue();
      refresh.add(null);
      await pumpEventQueue();
      expect(errors.single, isA<StateError>());
      expect(values, [2]);
    });

    test('stops polling after cancel', () async {
      var calls = 0;
      final sub = pollingStream<int>(() async => ++calls,
              interval: const Duration(milliseconds: 10))
          .listen((_) {});
      await pumpEventQueue();
      await sub.cancel();
      final after = calls;
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(calls, after);
    });
  });

  group('RestNotificationRepository', () {
    test('maps the API list and marks one notification read', () async {
      final tokens = FakeTokenStorage()..access = 'tok';
      final log = <http.Request>[];
      var read = false;
      final api = client(tokens, log, (r) async {
        if (r.method == 'POST') {
          read = true;
          return http.Response('', 204);
        }
        return json({
          'items': [
            {
              'id': 5,
              'type': 'payment',
              'title': 'Payment received',
              'body': 'Thanks!',
              'is_read': read,
              'created_at': '2026-11-28T10:00:00Z',
            },
          ],
          'unread_count': read ? 0 : 1,
        });
      });
      final repo = RestNotificationRepository(api, tokens,
          interval: const Duration(hours: 1));
      addTearDown(repo.dispose);

      final seen = <bool>[];
      final sub = repo.watchMine().listen((items) {
        expect(items.single.id, '5');
        expect(items.single.title, 'Payment received');
        expect(items.single.message, 'Thanks!');
        expect(items.single.timestamp.toUtc(), DateTime.utc(2026, 11, 28, 10));
        seen.add(items.single.isRead);
      });
      addTearDown(sub.cancel);

      await pumpEventQueue();
      await repo.markRead('5');
      await pumpEventQueue();

      expect(seen, [false, true], reason: 'marking read refreshes the list');
      expect(log.where((r) => r.method == 'POST').single.url.path,
          '/api/v1/notifications/5/read');
      expect(log.first.headers['Authorization'], 'Bearer tok');
    });

    test('signed out means an empty list and no request', () async {
      final tokens = FakeTokenStorage();
      final log = <http.Request>[];
      final repo = RestNotificationRepository(
          client(tokens, log, (r) async => json({'items': []})), tokens);
      addTearDown(repo.dispose);

      expect(await repo.watchMine().first, isEmpty);
      expect(log, isEmpty);
    });

    test('rejects non-numeric ids', () async {
      final tokens = FakeTokenStorage()..access = 'tok';
      final repo = RestNotificationRepository(
          client(tokens, [], (r) async => json({})), tokens);
      addTearDown(repo.dispose);
      expect(() => repo.markRead('abc'), throwsArgumentError);
    });
  });

  group('RestEnrollmentRepository', () {
    test('lists enrolled course ids and refreshes after enrolling', () async {
      final tokens = FakeTokenStorage()..access = 'tok';
      final log = <http.Request>[];
      var enrolled = <int>[3];
      final api = client(tokens, log, (r) async {
        if (r.method == 'POST') {
          enrolled = [...enrolled, jsonDecode(r.body)['course_id'] as int];
          return json({'id': 1, 'course_id': 4, 'status': 'active'}, 201);
        }
        return json([
          for (final id in enrolled) {'id': id, 'enrollment_id': id * 10},
        ]);
      });
      final repo = RestEnrollmentRepository(api, tokens,
          interval: const Duration(hours: 1));
      addTearDown(repo.dispose);

      final seen = <Set<String>>[];
      final sub = repo.watchEnrolledCourseIds().listen(seen.add);
      addTearDown(sub.cancel);
      await pumpEventQueue();
      await repo.enrollFreeCourse('4');
      await pumpEventQueue();

      expect(seen, [
        {'3'},
        {'3', '4'},
      ]);
      final post = log.firstWhere((r) => r.method == 'POST');
      expect(post.url.path, '/api/v1/enrollments');
      expect(jsonDecode(post.body), {'course_id': 4});
    });

    test('a paid course surfaces the payment-required error', () async {
      final tokens = FakeTokenStorage()..access = 'tok';
      final repo = RestEnrollmentRepository(
          client(tokens, [], (r) async =>
              json({'error': 'Purchase this course before enrolling.'}, 402)),
          tokens);
      addTearDown(repo.dispose);

      await expectLater(
        repo.enrollFreeCourse('9'),
        throwsA(isA<ApiException>()
            .having((e) => e.statusCode, 'statusCode', 402)),
      );
    });

    test('signed out means no enrollments and no request', () async {
      final tokens = FakeTokenStorage();
      final log = <http.Request>[];
      final repo = RestEnrollmentRepository(
          client(tokens, log, (r) async => json([])), tokens);
      addTearDown(repo.dispose);

      expect(await repo.watchEnrolledCourseIds().first, isEmpty);
      expect(log, isEmpty);
    });
  });
}
