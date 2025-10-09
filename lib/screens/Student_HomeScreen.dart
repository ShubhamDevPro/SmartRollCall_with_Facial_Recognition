import 'package:flutter/material.dart';
import 'package:smart_roll_call_flutter/services/firestore_service.dart';
import 'package:smart_roll_call_flutter/models/attendance_record.dart';
import 'package:smart_roll_call_flutter/models/course_schedule.dart';
import 'attendance_dashboard.dart';
import '../auth/auth_page.dart';

/// Enhanced Student Home Screen that demonstrates the new schedule-linked attendance system
/// Now students can see exactly which class schedules they attended, not just dates
class StudentHomeScreen extends StatefulWidget {
  final String studentId;
  final String batchId;
  final String studentName;

  const StudentHomeScreen({
    super.key,
    required this.studentId,
    required this.batchId,
    required this.studentName,
  });

  @override
  _StudentHomeScreenState createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends State<StudentHomeScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  StudentAttendanceSummary? attendanceSummary;
  Map<String, CourseSchedule> scheduleCache = {};
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStudentAttendance();
  }

  /// Load student's attendance records with schedule information
  void _loadStudentAttendance() async {
    try {
      // Get student's attendance summary with schedule links
      final summary = await _firestoreService.getStudentAttendanceSummary(
        widget.studentId,
        widget.batchId,
      );

      // Cache schedule information for display
      final allSchedules =
          await _firestoreService.getCourseSchedulesList(widget.batchId);
      final scheduleMap = Map.fromEntries(
          allSchedules.map((schedule) => MapEntry(schedule.id, schedule)));

      setState(() {
        attendanceSummary = summary;
        scheduleCache = scheduleMap;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading attendance: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Welcome, ${widget.studentName}",
              style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  fontSize: 18),
            ),
            const Text(
              "Student Portal",
              style: TextStyle(
                  fontWeight: FontWeight.w400,
                  color: Colors.white70,
                  fontSize: 12),
            ),
          ],
        ),
        backgroundColor: Colors.green.shade700,
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: _loadStudentAttendance,
          ),
          IconButton(
            icon: const Icon(Icons.dashboard, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const AttendanceDashboard()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const AuthPage()),
              );
            },
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Attendance Summary Card
                  _buildAttendanceSummaryCard(),
                  const SizedBox(height: 20),

                  // Recent Attendance with Schedule Information
                  _buildRecentAttendanceSection(),
                  const SizedBox(height: 20),

                  // Schedule-wise Attendance Breakdown
                  _buildScheduleWiseAttendance(),
                ],
              ),
            ),
    );
  }

  /// Build attendance summary card showing overall statistics
  Widget _buildAttendanceSummaryCard() {
    if (attendanceSummary == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('No attendance data available'),
        ),
      );
    }

    final totalClasses = attendanceSummary!.attendanceRecords.length;
    final attendedClasses = attendanceSummary!.attendanceRecords
        .where((record) => record.isPresent)
        .length;
    final attendancePercentage = attendanceSummary!.attendancePercentage;

    return Card(
      elevation: 4,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [Colors.blue.shade700, Colors.blue.shade500],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your Attendance Summary',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatColumn(
                    'Total Classes', '$totalClasses', Icons.class_),
                _buildStatColumn(
                    'Attended', '$attendedClasses', Icons.check_circle),
                _buildStatColumn(
                    'Percentage',
                    '${attendancePercentage.toStringAsFixed(1)}%',
                    Icons.trending_up),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Build individual stat column for summary card
  Widget _buildStatColumn(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.white70,
          ),
        ),
      ],
    );
  }

  /// Build recent attendance section showing specific class schedules attended
  Widget _buildRecentAttendanceSection() {
    if (attendanceSummary == null ||
        attendanceSummary!.attendanceRecords.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('No recent attendance records'),
        ),
      );
    }

    // Get recent 10 attendance records
    final recentRecords =
        attendanceSummary!.attendanceRecords.take(10).toList();

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Recent Attendance',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...recentRecords
                .map((record) => _buildAttendanceRecordTile(record)),
          ],
        ),
      ),
    );
  }

  /// Build individual attendance record tile showing specific schedule attended
  Widget _buildAttendanceRecordTile(AttendanceRecord record) {
    final schedule = scheduleCache[record.scheduleId];
    final dateStr =
        '${record.date.day}/${record.date.month}/${record.date.year}';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: record.isPresent ? Colors.green.shade50 : Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: record.isPresent ? Colors.green.shade200 : Colors.red.shade200,
        ),
      ),
      child: Row(
        children: [
          Icon(
            record.isPresent ? Icons.check_circle : Icons.cancel,
            color: record.isPresent ? Colors.green : Colors.red,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  schedule?.displayString ?? 'Unknown Schedule',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(
                  '$dateStr • ${record.isPresent ? 'Present' : 'Absent'}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          if (record.markedBy != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: record.markedBy == 'ESP32'
                    ? Colors.blue.shade100
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                record.markedBy!,
                style: TextStyle(
                  fontSize: 10,
                  color: record.markedBy == 'ESP32'
                      ? Colors.blue.shade700
                      : Colors.grey.shade700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Build schedule-wise attendance breakdown showing attendance per time slot
  Widget _buildScheduleWiseAttendance() {
    if (attendanceSummary == null || scheduleCache.isEmpty) {
      return const SizedBox();
    }

    final scheduleAttendance = attendanceSummary!.getAttendanceBySchedule();

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Attendance by Class Schedule',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Text(
              'See which specific time slots you attended most',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ...scheduleAttendance.entries.map((entry) {
              final schedule = scheduleCache[entry.key];
              final attendedCount = entry.value;
              final totalForSchedule = attendanceSummary!.attendanceRecords
                  .where((record) => record.scheduleId == entry.key)
                  .length;
              final percentage = totalForSchedule > 0
                  ? (attendedCount / totalForSchedule * 100)
                  : 0.0;

              return Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          schedule?.displayString ?? 'Unknown Schedule',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          '${percentage.toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color:
                                percentage >= 75 ? Colors.green : Colors.orange,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: percentage / 100,
                      backgroundColor: Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        percentage >= 75 ? Colors.green : Colors.orange,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Attended $attendedCount out of $totalForSchedule classes',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }
}
