// Optional: Simple HTTP server for ESP32 integration
// This can be used instead of direct Firebase REST API calls from ESP32
// Place this in a separate file if you want to add HTTP server capability to your Flutter app

import 'dart:convert';
import 'dart:io';
import 'package:smart_roll_call_flutter/services/firestore_service.dart';

class ESP32Server {
  static final FirestoreService _firestoreService = FirestoreService();
  static HttpServer? _server;
  static const int PORT = 8080;

  /// Start HTTP server for ESP32 integration
  static Future<void> startServer() async {
    try {
      _server = await HttpServer.bind(InternetAddress.anyIPv4, PORT);
      print('ESP32 Integration Server running on port $PORT');
      
      await for (HttpRequest request in _server!) {
        await _handleRequest(request);
      }
    } catch (e) {
      print('Error starting server: $e');
    }
  }

  /// Handle incoming HTTP requests from ESP32
  static Future<void> _handleRequest(HttpRequest request) async {
    // Enable CORS
    request.response.headers.add('Access-Control-Allow-Origin', '*');
    request.response.headers.add('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    request.response.headers.add('Access-Control-Allow-Headers', 'Content-Type');

    if (request.method == 'OPTIONS') {
      request.response.statusCode = 200;
      await request.response.close();
      return;
    }

    try {
      if (request.uri.path == '/mark-attendance' && request.method == 'POST') {
        await _handleMarkAttendance(request);
      } else if (request.uri.path == '/find-student' && request.method == 'GET') {
        await _handleFindStudent(request);
      } else {
        request.response.statusCode = 404;
        request.response.write(jsonEncode({'error': 'Endpoint not found'}));
      }
    } catch (e) {
      request.response.statusCode = 500;
      request.response.write(jsonEncode({'error': e.toString()}));
    }

    await request.response.close();
  }

  /// Handle attendance marking from ESP32
  static Future<void> _handleMarkAttendance(HttpRequest request) async {
    try {
      final String body = await utf8.decoder.bind(request).join();
      final Map<String, dynamic> data = jsonDecode(body);
      
      final String macAddress = data['macAddress'];
      final DateTime date = data['date'] != null 
          ? DateTime.parse(data['date']) 
          : DateTime.now();

      final bool success = await _firestoreService.markAttendanceByMacAddress(macAddress, date);
      
      if (success) {
        request.response.statusCode = 200;
        request.response.write(jsonEncode({
          'success': true,
          'message': 'Attendance marked successfully',
          'macAddress': macAddress,
          'date': date.toIso8601String(),
        }));
      } else {
        request.response.statusCode = 404;
        request.response.write(jsonEncode({
          'success': false,
          'message': 'Student not found or attendance already marked',
          'macAddress': macAddress,
        }));
      }
    } catch (e) {
      request.response.statusCode = 400;
      request.response.write(jsonEncode({
        'success': false,
        'error': e.toString(),
      }));
    }
  }

  /// Handle student lookup by MAC address
  static Future<void> _handleFindStudent(HttpRequest request) async {
    try {
      final String? macAddress = request.uri.queryParameters['macAddress'];
      
      if (macAddress == null) {
        request.response.statusCode = 400;
        request.response.write(jsonEncode({'error': 'macAddress parameter required'}));
        return;
      }

      final Map<String, dynamic>? studentData = await _firestoreService.getStudentByMacAddress(macAddress);
      
      if (studentData != null) {
        request.response.statusCode = 200;
        request.response.write(jsonEncode({
          'found': true,
          'student': {
            'name': studentData['name'],
            'enrollNumber': studentData['enrollNumber'],
            'batchId': studentData['batchId'],
            // Don't send sensitive data like studentId
          }
        }));
      } else {
        request.response.statusCode = 404;
        request.response.write(jsonEncode({
          'found': false,
          'message': 'Student not found',
        }));
      }
    } catch (e) {
      request.response.statusCode = 500;
      request.response.write(jsonEncode({
        'error': e.toString(),
      }));
    }
  }

  /// Stop the server
  static Future<void> stopServer() async {
    await _server?.close();
    _server = null;
    print('ESP32 Integration Server stopped');
  }
}