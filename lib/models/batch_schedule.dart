import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a batch with scheduling information for time-based attendance
class BatchSchedule {
  final String batchId;
  final String batchName;
  final String batchYear;
  final String title;
  final int iconCodePoint;
  final String dayOfWeek; // "Monday", "Tuesday", etc.
  final String startTime; // "16:00" (4:00 PM)
  final String endTime;   // "17:00" (5:00 PM)
  final bool isActive;
  final DateTime createdAt;

  BatchSchedule({
    required this.batchId,
    required this.batchName,
    required this.batchYear,
    required this.title,
    required this.iconCodePoint,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    this.isActive = true,
    required this.createdAt,
  });

  /// Factory constructor to create a BatchSchedule instance from Firestore document
  factory BatchSchedule.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map;
    return BatchSchedule(
      batchId: doc.id,
      batchName: data['batchName'] ?? '',
      batchYear: data['batchYear'] ?? '',
      title: data['title'] ?? '',
      iconCodePoint: data['icon'] ?? 0xe1ac, // Default icon
      dayOfWeek: data['dayOfWeek'] ?? 'Monday',
      startTime: data['startTime'] ?? '09:00',
      endTime: data['endTime'] ?? '10:00',
      isActive: data['isActive'] ?? true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// Converts BatchSchedule instance to a Map for Firestore storage
  Map<String, dynamic> toMap() {
    return {
      'batchName': batchName,
      'batchYear': batchYear,
      'title': title,
      'icon': iconCodePoint,
      'dayOfWeek': dayOfWeek,
      'startTime': startTime,
      'endTime': endTime,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  /// Check if this batch is currently scheduled based on current time
  bool isCurrentlyScheduled() {
    final now = DateTime.now();
    final currentDay = _getDayName(now.weekday);
    final currentTime = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
    
    return isActive && 
           dayOfWeek == currentDay && 
           currentTime.compareTo(startTime) >= 0 && 
           currentTime.compareTo(endTime) <= 0;
  }

  /// Check if this batch is scheduled for today
  bool isScheduledToday() {
    final now = DateTime.now();
    final currentDay = _getDayName(now.weekday);
    return isActive && dayOfWeek == currentDay;
  }

  /// Get the formatted time range as a string
  String getTimeRange() {
    return "$startTime - $endTime";
  }

  /// Convert weekday number to day name
  String _getDayName(int weekday) {
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return days[weekday - 1];
  }

  /// Get current day name
  static String getCurrentDayName() {
    final now = DateTime.now();
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return days[now.weekday - 1];
  }

  /// Get current time in HH:MM format
  static String getCurrentTime() {
    final now = DateTime.now();
    return "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
  }

  /// Validate time format (HH:MM)
  static bool isValidTimeFormat(String time) {
    final timeRegex = RegExp(r'^([0-1]?[0-9]|2[0-3]):[0-5][0-9]$');
    return timeRegex.hasMatch(time);
  }

  /// Check if start time is before end time
  static bool isValidTimeRange(String startTime, String endTime) {
    if (!isValidTimeFormat(startTime) || !isValidTimeFormat(endTime)) {
      return false;
    }
    return startTime.compareTo(endTime) < 0;
  }
}