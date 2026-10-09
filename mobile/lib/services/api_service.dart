import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/attendance_session.dart';
import '../models/auth_session.dart';

class ApiException implements Exception {
  const ApiException(this.code, this.message, this.statusCode);

  final String code;
  final String message;
  final int statusCode;

  @override
  String toString() => message;
}

class ApiService {
  ApiService({http.Client? client}) : _client = client ?? http.Client();

  static const baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000',
  );

  final http.Client _client;

  Future<dynamic> _request(
    String method,
    String path, {
    String? token,
    Map<String, dynamic>? body,
  }) async {
    final uri = Uri.parse('$baseUrl$path');
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (token != null) headers['Authorization'] = 'Bearer $token';
    late http.Response response;
    try {
      response = method == 'GET'
          ? await _client.get(uri, headers: headers).timeout(const Duration(seconds: 25))
          : await _client
              .post(uri, headers: headers, body: jsonEncode(body ?? const {}))
              .timeout(const Duration(seconds: 25));
    } catch (_) {
      throw const ApiException(
        'NETWORK_ERROR',
        'Could not reach the attendance server. Check the API address and network.',
        0,
      );
    }
    final decoded = response.body.isEmpty ? <String, dynamic>{} : jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final detail = decoded is Map<String, dynamic> ? decoded['detail'] : null;
      if (detail is Map<String, dynamic>) {
        throw ApiException(
          detail['code'] as String? ?? 'REQUEST_FAILED',
          detail['message'] as String? ?? 'Request failed',
          response.statusCode,
        );
      }
      throw ApiException('REQUEST_FAILED', 'Request failed (${response.statusCode})', response.statusCode);
    }
    return decoded;
  }

  Future<AuthSession> teacherLogin(String email, String password) async {
    final json = await _request('POST', '/auth/teacher/login', body: {
      'email': email,
      'password': password,
    }) as Map<String, dynamic>;
    return AuthSession(
      token: json['access_token'] as String,
      role: UserRole.teacher,
      id: json['teacher_id'] as int,
      name: json['name'] as String,
    );
  }

  Future<AuthSession> studentLogin(String studentCode, String password) async {
    final json = await _request('POST', '/auth/student/login', body: {
      'student_code': studentCode,
      'password': password,
    }) as Map<String, dynamic>;
    return AuthSession(
      token: json['access_token'] as String,
      role: UserRole.student,
      id: json['student_id'] as int,
      name: json['name'] as String,
      studentCode: json['student_code'] as String,
      hasAttendancePin: json['has_attendance_pin'] as bool? ?? false,
    );
  }

  Future<void> registerDevice(String token, String deviceId) async {
    await _request('POST', '/students/register-device', token: token, body: {'device_id': deviceId});
  }

  Future<void> setPin(String token, String deviceId, String pin) async {
    await _request('POST', '/students/set-attendance-pin', token: token, body: {
      'device_id': deviceId,
      'pin': pin,
    });
  }

  Future<AttendanceSession> startSession(String token) async {
    final json = await _request('POST', '/sessions/start', token: token, body: {
      'subject': 'Machine Learning',
    }) as Map<String, dynamic>;
    return AttendanceSession.fromJson(json);
  }

  Future<AttendanceSession> getSession(String token, String id) async {
    final json = await _request('GET', '/sessions/$id', token: token) as Map<String, dynamic>;
    return AttendanceSession.fromJson(json);
  }

  Future<AttendanceSession> resolveSession(String token, String code) async {
    final json = await _request('GET', '/sessions/resolve/$code', token: token)
        as Map<String, dynamic>;
    return AttendanceSession.fromJson(json);
  }

  Future<List<Map<String, dynamic>>> sessionAttendance(String token, String id) async {
    final json = await _request('GET', '/sessions/$id/attendance', token: token) as List<dynamic>;
    return json.cast<Map<String, dynamic>>();
  }

  Future<void> stopSession(String token, String id) async {
    await _request('POST', '/sessions/$id/stop', token: token);
  }

  Future<Map<String, dynamic>> markAttendance({
    required String token,
    required String sessionId,
    required String deviceId,
    required String bleToken,
    required int rssi,
    required String pin,
  }) async {
    return await _request('POST', '/attendance/mark', token: token, body: {
      'session_id': sessionId,
      'device_id': deviceId,
      'ble_token': bleToken,
      'ble_rssi': rssi,
      'client_timestamp': DateTime.now().toUtc().toIso8601String(),
      'pin': pin,
    }) as Map<String, dynamic>;
  }
}
