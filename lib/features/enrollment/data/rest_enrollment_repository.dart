// lib/features/enrollment/data/rest_enrollment_repository.dart
import 'dart:async';
import 'dart:convert';

import '../../../core/network/api_client.dart';
import '../../../core/network/polling_stream.dart';
import '../../../core/storage/token_storage.dart';
import 'enrollment_repository.dart';

/// Enrollments from the Go API. Paid courses become enrolled when the payment
/// webhook succeeds on the server, so the list is refreshed periodically.
class RestEnrollmentRepository implements EnrollmentRepository {
  RestEnrollmentRepository(
    this._api,
    this._tokens, {
    this.interval = const Duration(seconds: 60),
  });

  final ApiClient _api;
  final TokenStorage _tokens;
  final Duration interval;
  final _changed = StreamController<void>.broadcast();

  void dispose() => _changed.close();

  @override
  Stream<Set<String>> watchEnrolledCourseIds() =>
      pollingStream(_load, interval: interval, refresh: _changed.stream);

  Future<Set<String>> _load() async {
    if (!await _tokens.hasSession()) return const <String>{};
    final res = await _api.get('/api/v1/me/courses');
    final body = jsonDecode(res.body);
    final items = body is Map<String, dynamic> ? body['items'] : body;
    if (items is! List) return const <String>{};
    return items
        .whereType<Map<String, dynamic>>()
        .map((c) => '${c['id']}')
        .toSet();
  }

  /// The API decides whether the course is free; a paid course answers 402
  /// (payment required) and must go through checkout instead.
  @override
  Future<void> enrollFreeCourse(String courseId) async {
    final id = int.tryParse(courseId);
    if (id == null) {
      throw ArgumentError.value(courseId, 'courseId', 'not a numeric id');
    }
    await _api.post('/api/v1/enrollments', body: {'course_id': id});
    if (!_changed.isClosed) _changed.add(null);
  }
}
