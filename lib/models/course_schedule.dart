class CourseSchedule {
  final String id;
  final String dayOfWeek;
  final String startTime;
  final String endTime;
  final bool isActive;
  final DateTime createdAt;

  CourseSchedule({
    required this.id,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    this.isActive = true,
    required this.createdAt,
  });

  factory CourseSchedule.fromFirestore(Map<String, dynamic> data, String id) {
    return CourseSchedule(
      id: id,
      dayOfWeek: data['dayOfWeek'] ?? 'Monday',
      startTime: data['startTime'] ?? '09:00',
      endTime: data['endTime'] ?? '10:00',
      isActive: data['isActive'] ?? true,
      createdAt: data['createdAt']?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'dayOfWeek': dayOfWeek,
      'startTime': startTime,
      'endTime': endTime,
      'isActive': isActive,
      'createdAt': createdAt,
    };
  }

  // Helper method to get formatted time range
  String get timeRange => '$startTime - $endTime';

  // Helper method to get display text
  String get displayText => '$dayOfWeek $timeRange';

  @override
  String toString() => displayText;
}
