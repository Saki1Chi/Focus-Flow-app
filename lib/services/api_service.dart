import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/constants/app_constants.dart';
import '../data/models/task_model.dart';
import '../data/models/category_model.dart';
import 'task_mapper.dart';

/// HTTP client that communicates with the FocusFlow CMS backend.
///
/// The backend runs at [AppConstants.apiBaseUrl]. When running on an Android
/// emulator, use `http://10.0.2.2:8000`; for a physical device on the same
/// Wi-Fi, use the server's local IP address.
class ApiService {
  ApiService({String? baseUrl}) : _base = baseUrl ?? AppConstants.apiBaseUrl;

  final String _base;
  static const _timeout = Duration(seconds: 15);

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_token != null) 'X-Token': _token!,
      };

  String? _token;

  // ─── Tasks ────────────────────────────────────────────────────

  Future<List<Task>> getTasks({String? date, int? status, int? mode}) async {
    final params = <String, String>{};
    if (date != null)   params['date']   = date;
    if (status != null) params['status'] = status.toString();
    if (mode != null)   params['mode']   = mode.toString();

    final uri = Uri.parse('$_base/api/tasks').replace(queryParameters: params);
    final res = await http.get(uri, headers: _headers).timeout(_timeout);

    _assertOk(res);
    final List data = jsonDecode(res.body);
    return data.map((j) => Task.fromJson(_snakeToCamel(j))).toList();
  }

  Future<void> createTask(Task task) async {
    final uri = Uri.parse('$_base/api/tasks');
    final res = await http
        .post(uri, headers: _headers, body: jsonEncode(_taskToSnake(task)))
        .timeout(_timeout);
    _assertOk(res);
  }

  Future<void> updateTask(Task task) async {
    final uri = Uri.parse('$_base/api/tasks/${task.id}');
    final res = await http
        .put(uri, headers: _headers, body: jsonEncode(_taskToSnake(task)))
        .timeout(_timeout);
    _assertOk(res);
  }

  Future<void> deleteTask(String id) async {
    final uri = Uri.parse('$_base/api/tasks/$id');
    final res = await http.delete(uri, headers: _headers).timeout(_timeout);
    _assertOk(res);
  }

  /// Upserts all local tasks into the backend in a single request.
  /// Returns a map with `created` and `updated` counts.
  Future<Map<String, int>> bulkSync(List<Task> tasks) async {
    final uri  = Uri.parse('$_base/api/tasks/bulk');
    final body = jsonEncode(tasks.map(_taskToSnake).toList());
    final res  = await http
        .post(uri, headers: _headers, body: body)
        .timeout(const Duration(seconds: 60));
    _assertOk(res);
    final Map<String, dynamic> result = jsonDecode(res.body);
    return {
      'created': result['created'] as int,
      'updated': result['updated'] as int,
    };
  }

  // ─── Categories ───────────────────────────────────────────────

  Future<List<Category>> getCategories() async {
    final uri = Uri.parse('$_base/api/categories');
    final res = await http.get(uri, headers: _headers).timeout(_timeout);
    _assertOk(res);
    final List data = jsonDecode(res.body);
    return data.map((j) => Category.fromJson(Map<String, dynamic>.from(j))).toList();
  }

  // ─── Stats ────────────────────────────────────────────────────

  Future<Map<String, int>> getStats() async {
    final uri = Uri.parse('$_base/api/stats');
    final res = await http.get(uri, headers: _headers).timeout(_timeout);
    _assertOk(res);
    final Map<String, dynamic> data = jsonDecode(res.body);
    return data.map((k, v) => MapEntry(k, (v as num).toInt()));
  }

  // ─── Helpers ──────────────────────────────────────────────────

  void _assertOk(http.Response res) {
    if (res.statusCode < 200 || res.statusCode >= 300) {
      String detail = 'HTTP ${res.statusCode}';
      try {
        final body = jsonDecode(res.body);
        if (body is Map && body.containsKey('detail')) {
          detail = body['detail'].toString();
        }
      } catch (_) {}
      throw Exception(detail);
    }
  }

  // La conversión Task ↔ JSON está centralizada en task_mapper.dart.
  // Ver ese archivo para mantener sincronizado con backend/schemas.py.
  Map<String, dynamic> _taskToSnake(Task task) => taskToSnake(task);
  Map<String, dynamic> _snakeToCamel(dynamic json) => snakeToCamel(json);
}
