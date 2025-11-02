import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../auth/auth_page.dart';
import '../../services/optimized_student_attendance_service.dart';
import '../../services/face_enrollment_service.dart';
import 'package:intl/intl.dart';
import 'face_recognition_prompt.dart';
import 'face_enrollment_screen.dart';

/// Screen to display student's own attendance using optimized flat database structure
class StudentAttendanceViewScreen extends StatefulWidget {
  final String studentEmail;
  final String studentName;
  final String enrollmentNumber;

  const StudentAttendanceViewScreen({
    super.key,
    required this.studentEmail,
    required this.studentName,
    required this.enrollmentNumber,
  });

  @override
  State<StudentAttendanceViewScreen> createState() =>
      _StudentAttendanceViewScreenState();
}

class _StudentAttendanceViewScreenState
    extends State<StudentAttendanceViewScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _attendanceRecords = [];
  int _totalClasses = 0;
  int _presentCount = 0;
  double _attendancePercentage = 0.0;
  Map<String, Map<String, dynamic>> _courseStats = {};
  bool _hasFaceEnrolled = false;

  // Use the new optimized service (10-20x faster!)
  final OptimizedStudentAttendanceService _attendanceService =
      OptimizedStudentAttendanceService();

  // Face verification listener
  final FaceVerificationListener _verificationListener =
      FaceVerificationListener();

  // Face enrollment service
  final FaceEnrollmentService _enrollmentService = FaceEnrollmentService();

  @override
  void initState() {
    super.initState();
    _loadAttendanceData();
    _startVerificationListener();
    _checkFaceEnrollment();
  }

  @override
  void dispose() {
    _verificationListener.stopListening();
    super.dispose();
  }

  /// Check if student has face enrolled
  Future<void> _checkFaceEnrollment() async {
    try {
      final hasEnrolled = await _enrollmentService.hasFaceEnrolled(
        widget.enrollmentNumber,
      );
      setState(() {
        _hasFaceEnrolled = hasEnrolled;
      });
    } catch (e) {
      print('❌ Error checking face enrollment: $e');
    }
  }

  /// Start listening for pending face verifications
  void _startVerificationListener() {
    _verificationListener.startListening(
      enrollmentNumber: widget.enrollmentNumber,
      onVerificationReceived: (verificationData) {
        // Show face verification prompt modal
        showFaceVerificationPrompt(
          context,
          verificationData,
          () {
            // Refresh attendance data after successful verification
            _loadAttendanceData(forceRefresh: true);
          },
        );
      },
    );
  }

  /// Navigate to face enrollment screen
  Future<void> _navigateToEnrollment() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FaceEnrollmentScreen(
          enrollmentNumber: widget.enrollmentNumber,
          studentName: widget.studentName,
        ),
      ),
    );

    // If enrollment was successful, refresh the face enrollment status
    if (result == true) {
      await _checkFaceEnrollment();
    }
  }

  /// Load attendance data using the optimized flat collection
  /// This is 10-20x faster than scanning nested collections!
  Future<void> _loadAttendanceData({bool forceRefresh = false}) async {
    setState(() {
      _isLoading = true;
    });

    try {
      print('🎓 Loading attendance for enrollment: ${widget.enrollmentNumber}');

      // Use the new optimized service - single query, super fast!
      final attendanceRecords = await _attendanceService.getStudentAttendance(
        widget.enrollmentNumber,
        forceRefresh: forceRefresh,
      );

      if (attendanceRecords.isEmpty) {
        print('❌ No attendance records found');
        setState(() {
          _isLoading = false;
        });

        // Show helpful message to user
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'No attendance records found. Your professor needs to mark attendance first.'),
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      // Process the records - group by course
      final Map<String, Map<String, dynamic>> courseStatsTemp = {};

      for (var record in attendanceRecords) {
        final courseKey = '${record['courseName']}-${record['professorName']}';

        if (!courseStatsTemp.containsKey(courseKey)) {
          courseStatsTemp[courseKey] = {
            'total': 0,
            'present': 0,
            'professorName': record['professorName'],
            'courseName': record['courseName'],
            'records': <Map<String, dynamic>>[], // Store individual records
          };
        }

        courseStatsTemp[courseKey]!['total'] =
            (courseStatsTemp[courseKey]!['total'] as int) + 1;

        if (record['isPresent'] == true) {
          courseStatsTemp[courseKey]!['present'] =
              (courseStatsTemp[courseKey]!['present'] as int) + 1;
        }

        // Add record to this course's records list
        (courseStatsTemp[courseKey]!['records'] as List<Map<String, dynamic>>)
            .add(record);
      }

      // Sort records within each course by date (most recent first)
      for (var courseData in courseStatsTemp.values) {
        (courseData['records'] as List<Map<String, dynamic>>).sort(
          (a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime),
        );
      }

      // Sort by date (already sorted from service, but just in case)
      attendanceRecords.sort(
          (a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));

      // Calculate statistics
      final totalClasses = attendanceRecords.length;
      final presentCount =
          attendanceRecords.where((r) => r['isPresent'] == true).length;
      final percentage =
          totalClasses > 0 ? (presentCount / totalClasses) * 100 : 0.0;

      print('📊 Statistics:');
      print('   Total classes: $totalClasses');
      print('   Present: $presentCount');
      print('   Percentage: ${percentage.toStringAsFixed(1)}%');
      print('   Courses: ${courseStatsTemp.length}');

      setState(() {
        _attendanceRecords = attendanceRecords;
        _totalClasses = totalClasses;
        _presentCount = presentCount;
        _attendancePercentage = percentage;
        _courseStats = courseStatsTemp;
        _isLoading = false;
      });

      print('✅ Attendance data loaded successfully!');
    } catch (e) {
      print('❌ Error loading attendance: $e');

      // Show error to user with retry option
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading attendance: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () => _loadAttendanceData(forceRefresh: true),
            ),
          ),
        );
      }

      setState(() {
        _isLoading = false;
      });
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
              widget.studentName,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.white,
                fontSize: 18,
              ),
            ),
            Text(
              'Enroll: ${widget.enrollmentNumber}',
              style: const TextStyle(
                fontWeight: FontWeight.w400,
                color: Colors.white70,
                fontSize: 12,
              ),
            ),
          ],
        ),
        backgroundColor: Colors.deepPurple,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () => _loadAttendanceData(forceRefresh: true),
            tooltip: 'Refresh attendance',
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const AuthPage()),
                  (route) => false,
                );
              }
            },
            tooltip: 'Logout',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _attendanceRecords.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.school_outlined,
                        size: 100,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'No Attendance Records Found',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 40.0),
                        child: Text(
                          'Your professor hasn\'t marked any attendance yet.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: () =>
                            _loadAttendanceData(forceRefresh: true),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Refresh'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () => _loadAttendanceData(forceRefresh: true),
                  child: ListView(
                    padding: const EdgeInsets.all(16.0),
                    children: [
                      // Face Enrollment Card (show if not enrolled)
                      if (!_hasFaceEnrolled)
                        Card(
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.orange.shade400,
                                  Colors.deepOrange.shade600,
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(15),
                            ),
                            padding: const EdgeInsets.all(20.0),
                            child: Column(
                              children: [
                                const Icon(
                                  Icons.face_outlined,
                                  size: 60,
                                  color: Colors.white,
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'Face Not Enrolled',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Enroll your face to enable automatic attendance verification',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.white70,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  onPressed: _navigateToEnrollment,
                                  icon: const Icon(Icons.camera_alt),
                                  label: const Text('Enroll Face Now'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: Colors.deepOrange,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(25),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                      if (!_hasFaceEnrolled) const SizedBox(height: 20),

                      // Overall Stats Card
                      Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.deepPurple.shade400,
                                Colors.deepPurple.shade600,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            children: [
                              const Text(
                                'Overall Attendance',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 20),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  _buildStatColumn(
                                    'Total',
                                    _totalClasses.toString(),
                                    Icons.calendar_today,
                                  ),
                                  _buildStatColumn(
                                    'Present',
                                    _presentCount.toString(),
                                    Icons.check_circle,
                                  ),
                                  _buildStatColumn(
                                    'Percentage',
                                    '${_attendancePercentage.toStringAsFixed(1)}%',
                                    Icons.trending_up,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 15),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: LinearProgressIndicator(
                                  value: _attendancePercentage / 100,
                                  minHeight: 10,
                                  backgroundColor: Colors.white30,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    _attendancePercentage >= 75
                                        ? Colors.greenAccent
                                        : _attendancePercentage >= 65
                                            ? Colors.orangeAccent
                                            : Colors.redAccent,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Course-wise Stats
                      if (_courseStats.isNotEmpty) ...[
                        const Text(
                          'Course-wise Attendance',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 10),
                        ..._courseStats.entries.map((entry) {
                          final stats = entry.value;
                          final total = stats['total'] as int;
                          final present = stats['present'] as int;
                          final percentage =
                              total > 0 ? (present / total) * 100 : 0.0;

                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            child: ListTile(
                              title: Text(
                                stats['courseName'] ?? 'Unknown Course',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                'Prof. ${stats['professorName'] ?? 'Unknown'}\n$present/$total classes',
                              ),
                              trailing: CircleAvatar(
                                backgroundColor: percentage >= 75
                                    ? Colors.green
                                    : percentage >= 65
                                        ? Colors.orange
                                        : Colors.red,
                                child: Text(
                                  '${percentage.toStringAsFixed(0)}%',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                        const SizedBox(height: 20),
                      ],

                      // Attendance History - Grouped by Course
                      const Text(
                        'Attendance History (Grouped by Course)',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ..._courseStats.entries.map((entry) {
                        final stats = entry.value;
                        final courseName =
                            stats['courseName'] ?? 'Unknown Course';
                        final professorName =
                            stats['professorName'] ?? 'Unknown Professor';
                        final records =
                            stats['records'] as List<Map<String, dynamic>>;
                        final total = stats['total'] as int;
                        final present = stats['present'] as int;
                        final percentage =
                            total > 0 ? (present / total) * 100 : 0.0;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 15),
                          elevation: 3,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Theme(
                            data: Theme.of(context).copyWith(
                              dividerColor: Colors.transparent,
                            ),
                            child: ExpansionTile(
                              tilePadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              leading: CircleAvatar(
                                backgroundColor: percentage >= 75
                                    ? Colors.green.shade100
                                    : percentage >= 65
                                        ? Colors.orange.shade100
                                        : Colors.red.shade100,
                                child: Icon(
                                  Icons.school,
                                  color: percentage >= 75
                                      ? Colors.green
                                      : percentage >= 65
                                          ? Colors.orange
                                          : Colors.red,
                                ),
                              ),
                              title: Text(
                                courseName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                              subtitle: Text(
                                'Prof. $professorName • $present/$total Present',
                                style: const TextStyle(fontSize: 13),
                              ),
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: percentage >= 75
                                      ? Colors.green
                                      : percentage >= 65
                                          ? Colors.orange
                                          : Colors.red,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  '${percentage.toStringAsFixed(0)}%',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              children: [
                                const Divider(height: 1),
                                ListView.separated(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  padding: const EdgeInsets.all(12),
                                  itemCount: records.length,
                                  separatorBuilder: (context, index) =>
                                      const Divider(height: 1),
                                  itemBuilder: (context, index) {
                                    final record = records[index];
                                    final date = record['date'] as DateTime;
                                    final isPresent =
                                        record['isPresent'] as bool;

                                    return ListTile(
                                      dense: true,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 4,
                                      ),
                                      leading: Icon(
                                        isPresent
                                            ? Icons.check_circle
                                            : Icons.cancel,
                                        color: isPresent
                                            ? Colors.green
                                            : Colors.red,
                                        size: 28,
                                      ),
                                      title: Text(
                                        DateFormat('EEEE, MMM dd, yyyy')
                                            .format(date),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w500,
                                          fontSize: 14,
                                        ),
                                      ),
                                      trailing: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isPresent
                                              ? Colors.green.shade50
                                              : Colors.red.shade50,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          border: Border.all(
                                            color: isPresent
                                                ? Colors.green
                                                : Colors.red,
                                            width: 1,
                                          ),
                                        ),
                                        child: Text(
                                          isPresent ? 'Present' : 'Absent',
                                          style: TextStyle(
                                            color: isPresent
                                                ? Colors.green
                                                : Colors.red,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
    );
  }

  Widget _buildStatColumn(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 30),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            color: Colors.white70,
          ),
        ),
      ],
    );
  }
}
