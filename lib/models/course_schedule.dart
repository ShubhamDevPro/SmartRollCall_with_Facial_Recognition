import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a scheduled class session with specific time slots
class CourseSchedule {
  final String id;
  final String batchId;
  final String dayOfWeek; // e.g., "Monday", "Tuesday"
  final String startTime; // e.g., "13:00"
  final String endTime; // e.g., "14:00"
  final bool isActive;
  final DateTime createdAt;

  CourseSchedule({
    required this.id,
    required this.batchId,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    this.isActive = true,
    required this.createdAt,
  });

  /// Factory constructor to create CourseSchedule from Firestore document
  factory CourseSchedule.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map;
    return CourseSchedule(
      id: doc.id,
      batchId: doc.reference.parent.parent!.id,
      dayOfWeek: data['dayOfWeek'] ?? '',
      startTime: data['startTime'] ?? '',
      endTime: data['endTime'] ?? '',
      isActive: data['isActive'] ?? true,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  /// Convert CourseSchedule to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'dayOfWeek': dayOfWeek,
      'startTime': startTime,
      'endTime': endTime,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  /// Get a formatted display string for the schedule
  String get displayString => '$dayOfWeek $startTime - $endTime';

  /// Get time range string (for backward compatibility)
  String get timeRange => '$startTime - $endTime';
}
