import 'dart:convert';

import 'package:ab_learning/core/network/api_client.dart';
import 'package:ab_learning/core/network/api_exception.dart';
import 'package:ab_learning/features/marketplace/data/rest_course_repository.dart';
import 'package:ab_learning/features/marketplace/domain/course_model.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'support/fake_token_storage.dart';

http.Response json(Object body, [int status = 200]) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

Map<String, dynamic> apiCourse({
  int id = 3,
  double price = 1000,
  double? discount,
  String status = 'published',
}) =>
    {
      'id': id,
      'title': 'Go for beginners',
      'slug': 'go-for-beginners-abc123',
      'description': 'Learn Go',
      'thumbnail_url': '/uploads/images/a.png',
      'price': price,
      'discount_price': discount,
      'rating_avg': 4.5,
      'student_count': 12,
      'level': 'beginner',
      'status': status,
      'category': 'programming',
      'instructor': {'id': 9, 'display_name': 'Ada Lee'},
    };

class Harness {
  Harness(Future<http.Response> Function(http.Request) handler) {
    api = ApiClient(
      baseUrl: 'https://api.example.test',
      tokenStorage: tokens,
      client: MockClient((r) async {
        requests.add(r);
        return handler(r);
      }),
    );
    repo = RestCourseRepository(api);
  }

  final tokens = FakeTokenStorage()..access = 'tok';
  final requests = <http.Request>[];
  late final ApiClient api;
  late final RestCourseRepository repo;
}

void main() {
  test('published courses map prices, category slug and instructor', () async {
    final h = Harness((r) async => json([
          apiCourse(),
          apiCourse(id: 4, price: 1000, discount: 700),
        ]));

    final courses = await h.repo.getPublishedCourses(categoryId: 'programming');

    expect(h.requests.single.url.path, '/api/v1/courses');
    expect(h.requests.single.url.queryParameters['category'], 'programming');
    expect(h.requests.single.headers.containsKey('Authorization'), isFalse);
    expect(courses, hasLength(2));
    expect(courses[0].id, '3');
    expect(courses[0].price, 1000);
    expect(courses[0].originalPrice, isNull);
    expect(courses[0].categoryId, 'programming');
    expect(courses[0].instructorId, '9');
    expect(courses[0].instructorName, 'Ada Lee');
    expect(courses[0].status, CourseStatus.published);
    expect(courses[0].avgRating, 4.5);
    expect(courses[0].totalStudents, 12);
    expect(courses[1].price, 700, reason: 'discount is the selling price');
    expect(courses[1].originalPrice, 1000);
  });

  test('search sends the trimmed query', () async {
    final h = Harness((r) async => json([apiCourse()]));
    await h.repo.searchCourses('  go lang ');
    expect(h.requests.single.url.path, '/api/v1/search');
    expect(h.requests.single.url.queryParameters['q'], 'go lang');
  });

  test('categories use the slug as id and prefer the Thai name', () async {
    final h = Harness((r) async => json([
          {'id': 1, 'name_th': 'โปรแกรมมิ่ง', 'name_en': 'Programming', 'slug': 'programming'},
          {'id': 2, 'name_th': '', 'name_en': 'Design', 'slug': 'design'},
        ]));
    final cats = await h.repo.getCategories();
    expect(cats.map((c) => c.id), ['programming', 'design']);
    expect(cats.map((c) => c.name), ['โปรแกรมมิ่ง', 'Design']);
  });

  test('course detail merges the curriculum', () async {
    final h = Harness((r) async {
      if (r.url.path.endsWith('/curriculum')) {
        return json([
          {
            'id': 11,
            'title': 'Basics',
            'lessons': [
              {'id': 21, 'title': 'Intro', 'duration_seconds': 90, 'is_preview': true, 'video_url': '/uploads/videos/a.mp4'},
              {'id': 22, 'title': 'Loops', 'duration_seconds': 0, 'is_preview': false, 'video_url': ''},
            ],
          },
          {'id': 12, 'title': 'Empty section', 'lessons': null},
        ]);
      }
      return json(apiCourse());
    });

    final course = await h.repo.getCourseById('3');

    expect(course, isNotNull);
    expect(course!.sections, hasLength(2));
    final lectures = course.sections[0].lectures;
    expect(lectures[0].isPreview, isTrue);
    expect(lectures[0].videoRef, '/uploads/videos/a.mp4');
    expect(lectures[1].videoRef, isNull, reason: 'empty URL means not uploaded');
    expect(lectures[1].order, 1);
    expect(course.sections[1].lectures, isEmpty);
  });

  test('unknown or non-numeric course id returns null', () async {
    final h = Harness((r) async => json({'error': 'course not found'}, 404));
    expect(await h.repo.getCourseById('999'), isNull);
    expect(await h.repo.getCourseById('abc'), isNull);
    expect(h.requests, hasLength(1), reason: 'non-numeric ids never hit the API');
  });

  test('server errors other than 404 propagate', () async {
    final h = Harness((r) async => json({'error': 'internal error'}, 500));
    await expectLater(h.repo.getCourseById('3'), throwsA(isA<ApiException>()));
  });

  test('createCourse resolves the category slug to its numeric id', () async {
    final h = Harness((r) async {
      if (r.url.path == '/api/v1/categories') {
        return json([
          {'id': 5, 'name_th': 'x', 'name_en': 'x', 'slug': 'programming'},
        ]);
      }
      return json({'id': 42}, 201);
    });

    final id = await h.repo.createCourse(
        title: 'New', description: 'd', price: 500, categoryId: 'programming');

    expect(id, '42');
    final post = h.requests.last;
    expect(post.method, 'POST');
    expect(post.url.path, '/api/v1/instructor/courses');
    expect(post.headers['Authorization'], 'Bearer tok');
    expect(jsonDecode(post.body), {
      'title': 'New',
      'description': 'd',
      'price': 500,
      'category_id': 5,
    });
  });

  test('createCourse rejects an unknown category without posting', () async {
    final h = Harness((r) async => json([]));
    await expectLater(
      h.repo.createCourse(
          title: 'New', description: 'd', price: 1, categoryId: 'nope'),
      throwsA(isA<ApiException>()),
    );
    expect(h.requests.where((r) => r.method == 'POST'), isEmpty);
  });

  test('sections, lectures and submit use the instructor endpoints', () async {
    final h = Harness((r) async => json({'id': 1}, 201));

    await h.repo.addSection('3', 'Basics');
    await h.repo.addLecture('3', '11', 'Intro');
    await h.repo.publishCourse('3');

    expect(h.requests[0].url.path, '/api/v1/course-sections');
    expect(jsonDecode(h.requests[0].body), {'course_id': 3, 'title': 'Basics'});
    expect(h.requests[1].url.path, '/api/v1/lessons');
    expect(jsonDecode(h.requests[1].body),
        {'section_id': 11, 'title': 'Intro', 'type': 'video'});
    expect(h.requests[2].url.path, '/api/v1/instructor/courses/3/submit');
    expect(() => h.repo.publishCourse('abc'), throwsArgumentError);
  });

  test('instructor courses require the signed-in session', () async {
    final h = Harness((r) async => json([apiCourse(status: 'pending_review')]));
    final list = await h.repo.getInstructorCourses('ignored');
    expect(h.requests.single.headers['Authorization'], 'Bearer tok');
    expect(list.single.status, CourseStatus.pendingReview);
  });
}
