// lib/features/marketplace/data/rest_course_repository.dart
//
// CourseRepository backed by the Go + MySQL API. Category ids are the API's
// category slugs (the catalog filters and labels courses by slug).
import 'dart:convert';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../domain/course_model.dart';
import 'course_repository.dart';

class RestCourseRepository implements CourseRepository {
  RestCourseRepository(this._api);

  final ApiClient _api;

  @override
  Future<List<CourseModel>> getPublishedCourses({String? categoryId}) async {
    final query = <String, String>{'limit': '100'};
    if (categoryId != null && categoryId.isNotEmpty) {
      query['category'] = categoryId;
    }
    final res = await _api.get(_withQuery('/api/v1/courses', query),
        authenticated: false);
    return _list(res.body).map(_publicCourse).toList();
  }

  @override
  Future<List<CourseModel>> searchCourses(String query) async {
    final res = await _api.get(
        _withQuery('/api/v1/search', {'q': query.trim(), 'limit': '100'}),
        authenticated: false);
    return _list(res.body).map(_publicCourse).toList();
  }

  @override
  Future<List<CategoryModel>> getCategories() async {
    final res = await _api.get('/api/v1/categories', authenticated: false);
    return _list(res.body)
        .map((c) => CategoryModel(
              id: '${c['slug']}',
              name: ((c['name_th'] as String?)?.isNotEmpty ?? false)
                  ? c['name_th'] as String
                  : '${c['name_en'] ?? c['slug']}',
            ))
        .toList();
  }

  @override
  Future<CourseModel?> getCourseById(String courseId) async {
    final id = int.tryParse(courseId);
    if (id == null) return null;
    final Map<String, dynamic> course;
    try {
      final res = await _api.get('/api/v1/courses/$id', authenticated: false);
      course = _map(res.body);
    } on ApiException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
    final curriculum =
        await _api.get('/api/v1/courses/$id/curriculum', authenticated: false);
    return _publicCourse(course, sections: _sections(_list(curriculum.body)));
  }

  /// The API returns the signed-in instructor's own courses; [instructorId] is
  /// kept for interface compatibility.
  @override
  Future<List<CourseModel>> getInstructorCourses(String instructorId) async {
    final res = await _api.get('/api/v1/instructor/courses');
    return _list(res.body)
        .map((c) => _publicCourse(c, instructorId: instructorId))
        .toList();
  }

  @override
  Future<String> createCourse({
    required String title,
    required String description,
    required double price,
    required String categoryId,
  }) async {
    final categories =
        _list((await _api.get('/api/v1/categories', authenticated: false)).body);
    final match = categories.where((c) => '${c['slug']}' == categoryId);
    if (match.isEmpty) {
      throw ApiException(statusCode: 422, message: 'Unknown category');
    }
    final res = await _api.post('/api/v1/instructor/courses', body: {
      'title': title,
      'description': description,
      'price': price,
      'category_id': match.first['id'],
    });
    return '${_map(res.body)['id']}';
  }

  @override
  Future<void> addSection(String courseId, String title) async {
    await _api.post('/api/v1/course-sections', body: {
      'course_id': _id(courseId),
      'title': title,
    });
  }

  @override
  Future<void> addLecture(
      String courseId, String sectionId, String title) async {
    await _api.post('/api/v1/lessons', body: {
      'section_id': _id(sectionId),
      'title': title,
      'type': 'video',
    });
  }

  @override
  Future<void> publishCourse(String courseId) async {
    // "Publish" for an instructor means submit for admin review.
    await _api.post('/api/v1/instructor/courses/${_id(courseId)}/submit');
  }

  // ---- mapping -----------------------------------------------------------

  static int _id(String value) {
    final id = int.tryParse(value);
    if (id == null) throw ArgumentError.value(value, 'id', 'not a numeric id');
    return id;
  }

  static String _withQuery(String path, Map<String, String> query) =>
      Uri(path: path, queryParameters: query).toString();

  static Map<String, dynamic> _map(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Expected a JSON object');
    }
    return decoded;
  }

  static List<Map<String, dynamic>> _list(String body) {
    final decoded = jsonDecode(body);
    if (decoded is! List) throw const FormatException('Expected a JSON array');
    return decoded.whereType<Map<String, dynamic>>().toList();
  }

  static double _num(Object? v) => v is num ? v.toDouble() : 0;

  static CourseStatus _status(Object? v) => switch ('$v') {
        'pending_review' => CourseStatus.pendingReview,
        'published' => CourseStatus.published,
        'rejected' => CourseStatus.rejected,
        'archived' => CourseStatus.archived,
        _ => CourseStatus.draft,
      };

  static CourseModel _publicCourse(
    Map<String, dynamic> c, {
    List<SectionModel> sections = const [],
    String? instructorId,
  }) {
    final price = _num(c['price']);
    final discount = c['discount_price'];
    final instructor = c['instructor'];
    return CourseModel(
      id: '${c['id']}',
      title: '${c['title'] ?? ''}',
      description: '${c['description'] ?? ''}',
      price: discount is num ? discount.toDouble() : price,
      originalPrice: discount is num ? price : null,
      categoryId: '${c['category'] ?? ''}',
      instructorId: instructor is Map ? '${instructor['id']}' : instructorId ?? '',
      instructorName:
          instructor is Map ? '${instructor['display_name'] ?? ''}' : '',
      thumbnailUrl: '${c['thumbnail_url'] ?? ''}',
      status: _status(c['status']),
      avgRating: _num(c['rating_avg']),
      totalStudents: (c['student_count'] as num?)?.toInt() ?? 0,
      sections: sections,
    );
  }

  static List<SectionModel> _sections(List<Map<String, dynamic>> raw) {
    return [
      for (var i = 0; i < raw.length; i++)
        SectionModel(
          id: '${raw[i]['id']}',
          title: '${raw[i]['title'] ?? ''}',
          order: i,
          lectures: [
            for (var j = 0;
                j < ((raw[i]['lessons'] as List?)?.length ?? 0);
                j++)
              _lecture((raw[i]['lessons'] as List)[j] as Map<String, dynamic>, j),
          ],
        ),
    ];
  }

  static LectureModel _lecture(Map<String, dynamic> l, int order) {
    final video = l['video_url'];
    return LectureModel(
      id: '${l['id']}',
      title: '${l['title'] ?? ''}',
      durationSeconds: (l['duration_seconds'] as num?)?.toInt() ?? 0,
      order: order,
      isPreview: l['is_preview'] == true,
      videoRef: video is String && video.isNotEmpty ? video : null,
    );
  }
}
