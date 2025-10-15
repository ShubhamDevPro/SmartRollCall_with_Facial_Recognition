import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents an attendance record linked to a specific scheduled class session
class AttendanceRecord {
  final String id;
  final String studentId;
  final String batchId;
  final String scheduleId; // Links to the specific CourseSchedule
  final DateTime date; // The actual date when attendance was marked
  final bool isPresent;
  final DateTime markedAt; // When the attendance was recorded
  final String? markedBy; // Who marked the attendance (teacher, ESP32, etc.)

  // NEW: Student info for easy querying (denormalized data)
  final String? studentEnrollment; // For direct student queries
  final String? studentName;
  final String? professorId;
  final String? professorName;
  final String? courseName;

  AttendanceRecord({
    required this.id,
    required this.studentId,
    required this.batchId,
    required this.scheduleId,
    required this.date,
    required this.isPresent,
    required this.markedAt,
    this.markedBy,
    this.studentEnrollment,
    this.studentName,
    this.professorId,
    this.professorName,
    this.courseName,
  });

  /// Factory constructor to create AttendanceRecord from Firestore document
  factory AttendanceRecord.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map;
    return AttendanceRecord(
      id: doc.id,
      studentId: data['studentId'] ?? '',
      batchId: data['batchId'] ?? '',
      scheduleId: data['scheduleId'] ?? '',
      date: (data['date'] as Timestamp).toDate(),
      isPresent: data['isPresent'] ?? false,
      markedAt: (data['markedAt'] as Timestamp).toDate(),
      markedBy: data['markedBy'],
      studentEnrollment: data['studentEnrollment'],
      studentName: data['studentName'],
      professorId: data['professorId'],
      professorName: data['professorName'],
      courseName: data['courseName'],
    );
  }

  /// Convert AttendanceRecord to Map for Firestore
  Map<String, dynamic> toMap() {
    final map = {
      'studentId': studentId,
      'batchId': batchId,
      'scheduleId': scheduleId,
      'date': Timestamp.fromDate(date),
      'isPresent': isPresent,
      'markedAt': Timestamp.fromDate(markedAt),
    };

    if (markedBy != null) {
      map['markedBy'] = markedBy!;
    }

    // Add denormalized student info for easy querying
    if (studentEnrollment != null) {
      map['studentEnrollment'] = studentEnrollment!;
    }
    if (studentName != null) {
      map['studentName'] = studentName!;
    }
    if (professorId != null) {
      map['professorId'] = professorId!;
    }
    if (professorName != null) {
      map['professorName'] = professorName!;
    }
    if (courseName != null) {
      map['courseName'] = courseName!;
    }

    return map;
  }
}
