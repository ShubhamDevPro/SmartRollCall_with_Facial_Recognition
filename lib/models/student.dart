import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a student entity with their attendance status
class Student {
  // Basic student information
  final String id;
  final String name;
  final String enrollNumber;
  final String? macAddress; // MAC address for ESP32 integration
  bool isPresent;

  /// Constructor to create a new Student instance
  /// [id] - Unique identifier for the student
  /// [name] - Student's full name
  /// [enrollNumber] - Unique enrollment identifier
  /// [macAddress] - MAC address for ESP32 integration (optional)
  /// [isPresent] - Attendance status, defaults to false
  Student({
    required this.id,
    required this.name,
    required this.enrollNumber,
    this.macAddress,
    this.isPresent = false,
  });

  /// Factory constructor to create a Student instance from Firestore document
  /// [doc] - Firestore DocumentSnapshot containing student data
  factory Student.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map;
    return Student(
      id: doc.id,
      name: data['name'] ?? '', // Default to empty string if null
      enrollNumber: data['enrollNumber'] ?? '',
      macAddress: data['macAddress'], // Can be null
      isPresent: data['isPresent'] ?? false,
    );
  }

  /// Converts Student instance to a Map for Firestore storage
  /// Returns a Map with student properties as key-value pairs
  Map<String, dynamic> toMap() {
    final map = {
      'name': name,
      'enrollNumber': enrollNumber,
      'isPresent': isPresent,
    };
    
    // Only include macAddress if it's not null
    if (macAddress != null) {
      map['macAddress'] = macAddress!;
    }
    
    return map;
  }
}