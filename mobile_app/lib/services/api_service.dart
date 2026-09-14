import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/student.dart';

class ApiService {
  // Singleton instance
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal() {
    _initDefaultBaseUrl();
  }

  late String _baseUrl;

  String get baseUrl => _baseUrl;

  void setBaseUrl(String url) {
    var trimmed = url.trim();
    if (trimmed.endsWith('/')) {
      trimmed = trimmed.substring(0, trimmed.length - 1);
    }
    _baseUrl = trimmed;
  }

  void _initDefaultBaseUrl() {
    // Production Cloud Server on Render
    _baseUrl = 'https://hofisattendance.onrender.com';
  }

  // Helper headers
  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  /// Check Backend Server Health
  Future<Map<String, dynamic>> checkHealth() async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/api/health'))
          .timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        return {'online': true, ...jsonDecode(response.body)};
      }
      return {'online': false, 'message': 'HTTP ${response.statusCode}'};
    } catch (e) {
      return {'online': false, 'message': e.toString()};
    }
  }

  /// Get list of classes for dropdown
  Future<List<String>> getClasses() async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/api/classes'))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] is List) {
          return List<String>.from(data['data']);
        }
      }
      return _defaultClasses();
    } catch (e) {
      return _defaultClasses();
    }
  }

  List<String> _defaultClasses() {
    return [
      'Class 1-A', 'Class 2-A', 'Class 3-A', 'Class 4-A', 'Class 5-A',
      'Class 6-A', 'Class 7-A', 'Class 8-A', 'Class 9-A', 'Class 10-A',
      'Class 11 - Science', 'Class 11 - Commerce', 'Class 11 - Arts',
      'Class 12 - Science', 'Class 12 - Commerce', 'Class 12 - Arts',
      'BCA - 1st Year', 'CSE - 1st Year', 'ECE - 1st Year'
    ];
  }

  /// Get Students with optional filters
  Future<List<Student>> getStudents({
    String? search,
    String? studentClass,
    String? status,
  }) async {
    final queryParams = <String, String>{};
    if (search != null && search.isNotEmpty) queryParams['search'] = search;
    if (studentClass != null && studentClass.isNotEmpty) {
      queryParams['class'] = studentClass;
    }
    if (status != null && status.isNotEmpty) queryParams['status'] = status;

    final uri = Uri.parse('$_baseUrl/api/users').replace(queryParameters: queryParams);

    final response = await http.get(uri).timeout(const Duration(seconds: 6));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['success'] == true && data['data'] is List) {
        return (data['data'] as List)
            .map((item) => Student.fromJson(item))
            .toList();
      }
      return [];
    } else {
      final data = jsonDecode(response.body);
      throw Exception(data['message'] ?? 'Failed to load students');
    }
  }

  /// Get Attendance Stats
  Future<AttendanceStats> getStats() async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/api/attendance/stats'))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return AttendanceStats.fromJson(data['data']);
        }
      }
      return AttendanceStats.empty();
    } catch (e) {
      return AttendanceStats.empty();
    }
  }

  /// Register / Create Student
  Future<Student> createStudent(Student student) async {
    final response = await http
        .post(
          Uri.parse('$_baseUrl/api/users'),
          headers: _headers,
          body: jsonEncode(student.toJson()),
        )
        .timeout(const Duration(seconds: 6));

    final data = jsonDecode(response.body);
    if (response.statusCode == 201 || response.statusCode == 200) {
      return Student.fromJson(data['data']);
    } else {
      throw Exception(data['message'] ?? 'Failed to create student');
    }
  }

  /// Update Student
  Future<Student> updateStudent(String id, Student student) async {
    final response = await http
        .put(
          Uri.parse('$_baseUrl/api/users/$id'),
          headers: _headers,
          body: jsonEncode(student.toJson()),
        )
        .timeout(const Duration(seconds: 6));

    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return Student.fromJson(data['data']);
    } else {
      throw Exception(data['message'] ?? 'Failed to update student');
    }
  }

  /// Delete Student
  Future<bool> deleteStudent(String id) async {
    final response = await http
        .delete(Uri.parse('$_baseUrl/api/users/$id'))
        .timeout(const Duration(seconds: 6));

    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return true;
    } else {
      throw Exception(data['message'] ?? 'Failed to delete student');
    }
  }

  /// Process RFID Tap
  Future<Map<String, dynamic>> tapCard(String rfidCardNumber) async {
    final response = await http
        .post(
          Uri.parse('$_baseUrl/api/attendance/tap'),
          headers: _headers,
          body: jsonEncode({'rfidCardNumber': rfidCardNumber.trim().toUpperCase()}),
        )
        .timeout(const Duration(seconds: 6));

    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return {
        'success': true,
        'action': data['action'] ?? 'Card Tapped',
        'message': data['message'] ?? 'Tap recorded successfully',
        'student': data['data'] != null ? Student.fromJson(data['data']) : null,
      };
    } else {
      return {
        'success': false,
        'message': data['message'] ?? 'Card tap failed',
      };
    }
  }

  /// Reset Day Attendance
  Future<String> resetDaily() async {
    final response = await http
        .post(Uri.parse('$_baseUrl/api/attendance/reset-daily'))
        .timeout(const Duration(seconds: 6));

    final data = jsonDecode(response.body);
    if (response.statusCode == 200) {
      return data['message'] ?? 'Daily attendance reset complete';
    } else {
      throw Exception(data['message'] ?? 'Failed to reset attendance');
    }
  }
}
