import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:smart_roll_call_flutter/models/batch_schedule.dart';
import 'package:smart_roll_call_flutter/models/course_schedule.dart';
import 'package:smart_roll_call_flutter/models/attendance_record.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get the current authenticated user's ID
  String get userId {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('No user is currently logged in');
    }
    return user.uid;
  }

  // Get batches for current user with their schedules
  Stream<QuerySnapshot> getBatches() {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('batches')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // Get schedules for a specific course/batch
  Stream<QuerySnapshot> getCourseSchedules(String batchId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('batches')
        .doc(batchId)
        .collection('schedules')
        .orderBy('dayOfWeek')
        .orderBy('startTime')
        .snapshots();
  }

  // Add new batch with multiple schedules
  Future<DocumentReference> addBatchWithSchedules(
    String name,
    String year,
    IconData icon,
    String title,
    List<Map<String, String>>
        schedules, // List of {dayOfWeek, startTime, endTime}
  ) async {
    try {
      // First create the batch document
      final batchRef = await _firestore
          .collection('users')
          .doc(userId)
          .collection('batches')
          .add({
        'batchName': name,
        'batchYear': year,
        'icon': icon.codePoint,
        'title': title,
        'isActive': true,
        'createdAt': Timestamp.now(),
      });

      // Then add schedules to the schedules subcollection
      final batch = _firestore.batch();
      for (var schedule in schedules) {
        final scheduleRef = batchRef.collection('schedules').doc();
        batch.set(scheduleRef, {
          'dayOfWeek': schedule['dayOfWeek'],
          'startTime': schedule['startTime'],
          'endTime': schedule['endTime'],
          'isActive': true,
          'createdAt': Timestamp.now(),
        });
      }
      await batch.commit();

      return batchRef;
    } catch (e) {
      print('Error adding batch with schedules: $e');
      rethrow;
    }
  }

  // Add a single schedule to an existing course
  Future<void> addScheduleToCourse(
    String batchId,
    String dayOfWeek,
    String startTime,
    String endTime,
  ) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('batches')
          .doc(batchId)
          .collection('schedules')
          .add({
        'dayOfWeek': dayOfWeek,
        'startTime': startTime,
        'endTime': endTime,
        'isActive': true,
        'createdAt': Timestamp.now(),
      });
    } catch (e) {
      print('Error adding schedule: $e');
      rethrow;
    }
  }

  // Update a specific schedule
  Future<void> updateSchedule(
    String batchId,
    String scheduleId,
    String dayOfWeek,
    String startTime,
    String endTime,
  ) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('batches')
          .doc(batchId)
          .collection('schedules')
          .doc(scheduleId)
          .update({
        'dayOfWeek': dayOfWeek,
        'startTime': startTime,
        'endTime': endTime,
      });
    } catch (e) {
      print('Error updating schedule: $e');
      rethrow;
    }
  }

  // Delete a specific schedule
  Future<void> deleteSchedule(String batchId, String scheduleId) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('batches')
          .doc(batchId)
          .collection('schedules')
          .doc(scheduleId)
          .delete();
    } catch (e) {
      print('Error deleting schedule: $e');
      rethrow;
    }
  }

  // Get all schedules for a course as a list
  Future<List<CourseSchedule>> getCourseSchedulesList(String batchId) async {
    try {
      // FIXED: Remove multiple orderBy to avoid requiring composite index
      // We'll sort in memory instead
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('batches')
          .doc(batchId)
          .collection('schedules')
          .get();

      // Convert to list and sort in memory
      final schedules = snapshot.docs
          .map((doc) => CourseSchedule.fromFirestore(doc))
          .toList();

      // Sort by day of week, then by start time
      schedules.sort((a, b) {
        final dayOrder = [
          'Monday',
          'Tuesday',
          'Wednesday',
          'Thursday',
          'Friday',
          'Saturday',
          'Sunday'
        ];
        final dayComparison = dayOrder
            .indexOf(a.dayOfWeek)
            .compareTo(dayOrder.indexOf(b.dayOfWeek));
        if (dayComparison != 0) return dayComparison;
        return a.startTime.compareTo(b.startTime);
      });

      return schedules;
    } catch (e) {
      print('Error getting course schedules: $e');
      rethrow;
    }
  }

  // Backward compatibility: Add batch with single schedule (for existing UI)
  Future<DocumentReference> addBatchWithSchedule(
    String name,
    String year,
    IconData icon,
    String title,
    String dayOfWeek,
    String startTime,
    String endTime,
  ) async {
    return addBatchWithSchedules(name, year, icon, title, [
      {
        'dayOfWeek': dayOfWeek,
        'startTime': startTime,
        'endTime': endTime,
      }
    ]);
  }

  // DEPRECATED: Old method kept for backward compatibility but not recommended
  // Use saveAttendanceWithSchedule instead for proper schedule-linked attendance
  @Deprecated('Use saveAttendanceWithSchedule instead')
  Future<void> saveAttendanceForDate(String batchId, DateTime date,
      List<Map<String, dynamic>> attendanceData) async {
    // This method should no longer be used as it doesn't support multiple schedules per day
    print(
        '⚠️ WARNING: Using deprecated saveAttendanceForDate. Use saveAttendanceWithSchedule instead.');

    final dateStr =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

    try {
      // Create a batch write to handle multiple operations
      WriteBatch batch = _firestore.batch();

      // First, get all students in the batch
      final studentsSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('batches')
          .doc(batchId)
          .collection('students')
          .get();

      // Create a map of enrollment numbers to student documents for quick lookup
      final studentDocs = Map.fromEntries(studentsSnapshot.docs
          .map((doc) => MapEntry(doc.data()['enrollNumber'] as String, doc)));

      // For each student's attendance
      for (var studentData in attendanceData) {
        final studentDoc = studentDocs[studentData['enrollNumber']];
        if (studentDoc != null) {
          // Add attendance record to student's attendance subcollection
          // NOTE: This will overwrite if multiple classes exist on same date
          final attendanceRef =
              studentDoc.reference.collection('attendance').doc(dateStr);
          batch.set(attendanceRef, {
            'date': Timestamp.fromDate(date),
            'isPresent': studentData['isPresent'],
          });
        }
      }

      // Commit the batch
      await batch.commit();
    } catch (e) {
      print('Error saving attendance: $e');
      rethrow;
    }
  }

  // Add method to get attendance for a specific date
  Stream<QuerySnapshot> getAttendanceForDate(
      String batchId, String studentId, DateTime date) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('batches')
        .doc(batchId)
        .collection('students')
        .doc(studentId)
        .collection('attendance')
        .where('date', isEqualTo: Timestamp.fromDate(date))
        .snapshots();
  }

  // FIXED: Get attendance for all students on a specific date, supporting multiple schedules per day
  Future<List<Map<String, dynamic>>> getAttendanceForDateAll(DateTime date,
      [String? selectedBatchId]) async {
    final dateStart = DateTime(date.year, date.month, date.day);
    final dateEnd = DateTime(date.year, date.month, date.day, 23, 59, 59);

    List<Map<String, dynamic>> attendanceList = [];

    try {
      // FIXED: Use single where clause on batchId if provided, then filter by date in memory
      // This avoids requiring a composite index
      Query query = _firestore.collection('attendance_records');

      if (selectedBatchId != null) {
        query = query.where('batchId', isEqualTo: selectedBatchId);
      }

      final attendanceRecords = await query.get();

      // Filter by date range in memory
      final filteredRecords = attendanceRecords.docs.where((doc) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data == null) return false;

        final recordDate = (data['date'] as Timestamp?)?.toDate();
        if (recordDate == null) return false;

        return recordDate
                .isAfter(dateStart.subtract(const Duration(seconds: 1))) &&
            recordDate.isBefore(dateEnd.add(const Duration(seconds: 1)));
      }).toList();

      // Group attendance records by student to get all their schedule attendances for this date
      Map<String, List<DocumentSnapshot>> studentAttendanceMap = {};
      for (var record in filteredRecords) {
        final data = record.data() as Map<String, dynamic>?;
        if (data == null) continue;

        final studentId = data['studentId'] as String?;
        if (studentId == null) continue;

        if (!studentAttendanceMap.containsKey(studentId)) {
          studentAttendanceMap[studentId] = [];
        }
        studentAttendanceMap[studentId]!.add(record);
      }

      // For each student with attendance records
      for (var entry in studentAttendanceMap.entries) {
        final studentId = entry.key;
        final studentRecords = entry.value;

        // Get student details - need to find which batch they're in
        String? batchId;
        Map<String, dynamic>? studentData;

        // Get batch ID from the first record
        if (studentRecords.isNotEmpty) {
          final firstRecordData =
              studentRecords.first.data() as Map<String, dynamic>?;
          if (firstRecordData != null) {
            batchId = firstRecordData['batchId'] as String?;
          }

          if (batchId != null) {
            // Get student document
            final studentDoc = await _firestore
                .collection('users')
                .doc(userId)
                .collection('batches')
                .doc(batchId)
                .collection('students')
                .doc(studentId)
                .get();

            if (studentDoc.exists) {
              studentData = studentDoc.data();
            }
          }
        }

        if (studentData != null && batchId != null) {
          // Calculate overall statistics for this student
          final allAttendanceQuery = await _firestore
              .collection('attendance_records')
              .where('studentId', isEqualTo: studentId)
              .where('batchId', isEqualTo: batchId)
              .get();

          int totalDays = allAttendanceQuery.docs.length;
          int presentDays = allAttendanceQuery.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>?;
            return data?['isPresent'] == true;
          }).length;

          // Add a separate entry for each schedule on this date
          for (var record in studentRecords) {
            final recordData = record.data() as Map<String, dynamic>?;
            if (recordData == null) continue;

            final scheduleId = recordData['scheduleId'] as String? ?? 'unknown';

            attendanceList.add({
              'name': studentData['name'],
              'enrollNumber': studentData['enrollNumber'],
              'isPresent': recordData['isPresent'] as bool? ?? false,
              'batchId': batchId,
              'scheduleId': scheduleId,
              'totalDays': totalDays,
              'presentDays': presentDays,
              'markedBy': recordData['markedBy'],
              'markedAt': recordData['markedAt'],
              'attendanceRecordId': record.id, // Include for potential updates
            });
          }
        }
      }

      return attendanceList;
    } catch (e) {
      print('Error getting attendance: $e');
      rethrow;
    }
  }

  // NEW: Update attendance record in the new attendance_records collection
  Future<void> updateAttendanceRecord(
    String attendanceRecordId,
    bool newStatus,
  ) async {
    try {
      await _firestore
          .collection('attendance_records')
          .doc(attendanceRecordId)
          .update({'isPresent': newStatus});
      print('✅ Attendance record updated successfully');
    } catch (e) {
      print('Error updating attendance record: $e');
      rethrow;
    }
  }

  // OLD: Update attendance status using the old structure (for backward compatibility)
  Future<void> updateAttendanceStatus(
    String batchId,
    String enrollNumber,
    DateTime date,
    bool newStatus,
  ) async {
    try {
      // First, find the student document
      final studentsSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('batches')
          .doc(batchId)
          .collection('students')
          .where('enrollNumber', isEqualTo: enrollNumber)
          .get();

      if (studentsSnapshot.docs.isEmpty) {
        throw 'Student not found';
      }

      // Update the attendance status in old structure
      final studentDoc = studentsSnapshot.docs.first;
      // Try to find attendance records for this date with any schedule
      final attendanceSnapshot = await studentDoc.reference
          .collection('attendance')
          .where('date', isEqualTo: Timestamp.fromDate(date))
          .get();

      // Update all matching records (in case there are multiple schedules)
      final batch = _firestore.batch();
      for (var doc in attendanceSnapshot.docs) {
        batch.update(doc.reference, {'isPresent': newStatus});
      }
      await batch.commit();
    } catch (e) {
      print('Error updating attendance status: $e');
      rethrow;
    }
  }

  // Add this new method to get all attendance dates and data
  Future<Map<String, dynamic>> getAllAttendanceData() async {
    try {
      Set<String> allDates = {};
      Map<String, Map<String, bool>> studentAttendance = {};
      Map<String, Map<String, String>> studentInfo = {};

      // Get all batches
      final batchesSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('batches')
          .get();

      // For each batch
      for (var batch in batchesSnapshot.docs) {
        // Get all students in the batch
        final studentsSnapshot =
            await batch.reference.collection('students').get();

        // For each student
        for (var student in studentsSnapshot.docs) {
          final enrollNumber = student.data()['enrollNumber'] as String;

          // Store student info
          studentInfo[enrollNumber] = {
            'name': student.data()['name'] as String,
            'enrollNumber': enrollNumber,
          };

          // Get all attendance records for this student
          final attendanceSnapshot =
              await student.reference.collection('attendance').get();

          // Store attendance data and collect dates
          Map<String, bool> dates = {};
          for (var attendance in attendanceSnapshot.docs) {
            final date =
                attendance.id; // Using the document ID which is the date string
            dates[date] = attendance.data()['isPresent'] as bool;
            allDates.add(date);
          }
          studentAttendance[enrollNumber] = dates;
        }
      }

      return {
        'dates': allDates.toList()..sort(),
        'studentAttendance': studentAttendance,
        'studentInfo': studentInfo,
      };
    } catch (e) {
      print('Error getting all attendance data: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> getAllAttendanceDataUntilDate(
    DateTime endDate,
    String? batchId,
  ) async {
    try {
      final Map<String, dynamic> studentAttendance = {};

      // Get all attendance records up to the selected date
      final QuerySnapshot attendanceSnapshot = await _firestore
          .collection('attendance')
          .where('batchId', isEqualTo: batchId)
          .where('date', isLessThanOrEqualTo: endDate)
          .get();

      // Process attendance records
      for (var doc in attendanceSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final date = (data['date'] as Timestamp).toDate();
        final dateStr = '${date.year}-${date.month}-${date.day}';

        for (var student in data['students']) {
          final enrollNo = student['enrollNumber'];
          if (!studentAttendance.containsKey(enrollNo)) {
            studentAttendance[enrollNo] = {
              'name': student['name'],
              'attendance': {}
            };
          }
          studentAttendance[enrollNo]['attendance'][dateStr] =
              student['isPresent'];
        }
      }

      return studentAttendance;
    } catch (e) {
      throw Exception('Failed to fetch attendance data: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getAttendanceHistory(
      String batchId) async {
    try {
      Map<String, Map<String, dynamic>> studentData = {};

      // Get all students in the batch
      final studentsSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('batches')
          .doc(batchId)
          .collection('students')
          .get();

      // Process each student
      for (var student in studentsSnapshot.docs) {
        final enrollNumber = student.data()['enrollNumber'] as String;
        final name = student.data()['name'] as String;

        // Get all attendance records for this student
        final attendanceSnapshot =
            await student.reference.collection('attendance').get();

        // Create attendance map
        Map<String, bool> attendance = {};
        for (var record in attendanceSnapshot.docs) {
          attendance[record.id] = record.data()['isPresent'] as bool;
        }

        studentData[enrollNumber] = {
          'name': name,
          'enrollNumber': enrollNumber,
          'attendance': attendance,
        };
      }

      return studentData.values.toList();
    } catch (e) {
      print('Error getting attendance history: $e');
      rethrow;
    }
  }

  /// Get currently scheduled batch based on time and day
  Future<String?> getCurrentlyScheduledBatch() async {
    try {
      final now = DateTime.now();
      final currentDay = _getDayName(now.weekday);
      final currentTime =
          "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";

      final batchesSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('batches')
          .where('dayOfWeek', isEqualTo: currentDay)
          .where('isActive', isEqualTo: true)
          .get();

      for (var batch in batchesSnapshot.docs) {
        final data = batch.data();
        final startTime = data['startTime'] as String? ?? '09:00';
        final endTime = data['endTime'] as String? ?? '10:00';

        if (currentTime.compareTo(startTime) >= 0 &&
            currentTime.compareTo(endTime) <= 0) {
          print(
              'Found currently scheduled batch: ${batch.id} ($startTime-$endTime)');
          return batch.id;
        }
      }

      print('No batch currently scheduled at $currentTime on $currentDay');
      return null; // No batch currently scheduled
    } catch (e) {
      print('Error getting current batch: $e');
      return null;
    }
  }

  /// Get all batches scheduled for today
  Future<List<BatchSchedule>> getTodaysBatches() async {
    try {
      final currentDay = _getDayName(DateTime.now().weekday);

      final batchesSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('batches')
          .where('dayOfWeek', isEqualTo: currentDay)
          .where('isActive', isEqualTo: true)
          .orderBy('startTime')
          .get();

      return batchesSnapshot.docs
          .map((doc) => BatchSchedule.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('Error getting today\'s batches: $e');
      return [];
    }
  }

  /// Get student by MAC address in currently scheduled batch only
  Future<Map<String, dynamic>?> getStudentByMacAddressInCurrentBatch(
      String macAddress) async {
    try {
      final currentBatchId = await getCurrentlyScheduledBatch();
      if (currentBatchId == null) {
        print('No batch currently scheduled');
        return null;
      }

      final studentsSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('batches')
          .doc(currentBatchId)
          .collection('students')
          .where('macAddress', isEqualTo: macAddress.toUpperCase())
          .get();

      if (studentsSnapshot.docs.isNotEmpty) {
        final studentDoc = studentsSnapshot.docs.first;
        return {
          'studentId': studentDoc.id,
          'batchId': currentBatchId,
          'name': studentDoc.data()['name'],
          'enrollNumber': studentDoc.data()['enrollNumber'],
          'macAddress': studentDoc.data()['macAddress'],
        };
      }

      print(
          'No student found with MAC $macAddress in current batch $currentBatchId');
      return null;
    } catch (e) {
      print('Error finding student by MAC in current batch: $e');
      return null;
    }
  }

  /// Mark attendance via ESP32 for currently scheduled batch only
  Future<bool> markAttendanceByMacAddressCurrentBatch(
      String macAddress, DateTime date) async {
    try {
      // Find student in currently scheduled batch
      final studentData =
          await getStudentByMacAddressInCurrentBatch(macAddress);
      if (studentData == null) {
        print(
            'No student found with MAC address: $macAddress in current batch');
        return false;
      }

      final dateStr =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

      final studentRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('batches')
          .doc(studentData['batchId'])
          .collection('students')
          .doc(studentData['studentId']);

      final attendanceRef = studentRef.collection('attendance').doc(dateStr);
      final existingAttendance = await attendanceRef.get();

      if (existingAttendance.exists) {
        print(
            'Attendance already marked for ${studentData['name']} on $dateStr in batch ${studentData['batchId']}');
        return true;
      }

      // Get current class time for context
      final classTime = await _getCurrentClassTime(studentData['batchId']);

      // Mark attendance with batch context
      await attendanceRef.set({
        'date': Timestamp.fromDate(date),
        'isPresent': true,
        'markedBy': 'ESP32',
        'markedAt': Timestamp.now(),
        'macAddress': macAddress.toUpperCase(),
        'batchId': studentData['batchId'],
        'classTime': classTime,
        'markedDuringClass':
            true, // Flag to indicate this was marked during actual class time
      });

      print(
          '✅ Attendance marked for ${studentData['name']} (${studentData['enrollNumber']}) in batch ${studentData['batchId']} via ESP32');
      return true;
    } catch (e) {
      print('Error marking attendance by MAC address: $e');
      return false;
    }
  }

  /// Get current class time information for a batch
  Future<String?> _getCurrentClassTime(String batchId) async {
    try {
      final batchDoc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('batches')
          .doc(batchId)
          .get();

      if (batchDoc.exists) {
        final data = batchDoc.data()!;
        return "${data['startTime']}-${data['endTime']}";
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Convert weekday number to day name
  String _getDayName(int weekday) {
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
    return days[weekday - 1];
  }

  /// Delete batch and all its data
  Future<void> deleteBatch(String batchId) async {
    try {
      final batchRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('batches')
          .doc(batchId);

      // Delete all subcollections (students, schedules, etc.)
      final studentsSnapshot = await batchRef.collection('students').get();
      for (var studentDoc in studentsSnapshot.docs) {
        // Delete student's attendance records
        final attendanceSnapshot =
            await studentDoc.reference.collection('attendance').get();
        for (var attendanceDoc in attendanceSnapshot.docs) {
          await attendanceDoc.reference.delete();
        }
        await studentDoc.reference.delete();
      }

      final schedulesSnapshot = await batchRef.collection('schedules').get();
      for (var scheduleDoc in schedulesSnapshot.docs) {
        await scheduleDoc.reference.delete();
      }

      // Finally delete the batch itself
      await batchRef.delete();
      print('Batch deleted successfully: $batchId');
    } catch (e) {
      print('Error deleting batch: $e');
      rethrow;
    }
  }

  /// Update batch information
  Future<void> updateBatch(
    String batchId,
    String title,
    String batchName,
    String batchYear,
    int iconCodePoint,
    String dayOfWeek,
    String startTime,
    String endTime,
  ) async {
    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('batches')
          .doc(batchId)
          .update({
        'title': title,
        'batchName': batchName,
        'batchYear': batchYear,
        'icon': iconCodePoint,
        'dayOfWeek': dayOfWeek,
        'startTime': startTime,
        'endTime': endTime,
      });
      print('Batch updated successfully: $batchId');
    } catch (e) {
      print('Error updating batch: $e');
      rethrow;
    }
  }

  /// Get students in a batch
  Stream<QuerySnapshot> getStudents(String batchId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('batches')
        .doc(batchId)
        .collection('students')
        .orderBy('enrollNumber')
        .snapshots();
  }

  /// Add a student to a batch
  Future<DocumentReference> addStudent(
    String batchId,
    Map<String, dynamic> studentData,
  ) async {
    try {
      final studentRef = await _firestore
          .collection('users')
          .doc(userId)
          .collection('batches')
          .doc(batchId)
          .collection('students')
          .add({
        ...studentData,
        'createdAt': Timestamp.now(),
      });
      print('Student added successfully: ${studentData['enrollNumber']}');
      return studentRef;
    } catch (e) {
      print('Error adding student: $e');
      rethrow;
    }
  }

  /// Get student by MAC address across all batches
  /// Used by ESP32 to identify student before marking attendance
  Future<Map<String, dynamic>?> getStudentByMacAddress(
      String macAddress) async {
    try {
      // Convert to uppercase for consistent comparison
      final normalizedMac = macAddress.toUpperCase();

      // Get all batches
      final batchesSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('batches')
          .get();

      // Search through each batch
      for (var batch in batchesSnapshot.docs) {
        final studentsSnapshot = await batch.reference
            .collection('students')
            .where('macAddress', isEqualTo: normalizedMac)
            .get();

        if (studentsSnapshot.docs.isNotEmpty) {
          final studentDoc = studentsSnapshot.docs.first;
          return {
            'studentId': studentDoc.id,
            'batchId': batch.id,
            'name': studentDoc.data()['name'],
            'enrollNumber': studentDoc.data()['enrollNumber'],
            'macAddress': studentDoc.data()['macAddress'],
          };
        }
      }

      return null; // Student not found
    } catch (e) {
      print('Error getting student by MAC address: $e');
      rethrow;
    }
  }

  /// Mark attendance via ESP32 integration
  /// Used when ESP32 detects a student's device
  Future<bool> markAttendanceByMacAddress(
      String macAddress, DateTime date) async {
    try {
      // Use the new schedule-linked attendance marking
      return await markAttendanceByMacAddressWithSchedule(macAddress, date);
    } catch (e) {
      print('Error marking attendance by MAC address: $e');
      return false;
    }
  }

  /// NEW SCHEDULE-LINKED ATTENDANCE METHODS

  /// Get schedules that match a specific date (day of week)
  Future<List<CourseSchedule>> getSchedulesForDate(
      String batchId, DateTime date) async {
    try {
      final weekdayNames = [
        '',
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
        'Sunday'
      ];
      final dayOfWeek = weekdayNames[date.weekday];

      // Modified query to avoid composite index requirement
      // First get all active schedules, then filter by day of week in memory
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('batches')
          .doc(batchId)
          .collection('schedules')
          .where('isActive', isEqualTo: true)
          .get();

      // Filter by dayOfWeek and sort in memory to avoid composite index
      final schedules = snapshot.docs
          .map((doc) => CourseSchedule.fromFirestore(doc))
          .where((schedule) => schedule.dayOfWeek == dayOfWeek)
          .toList();

      // Sort by start time
      schedules.sort((a, b) => a.startTime.compareTo(b.startTime));

      print('Found ${schedules.length} schedules for $dayOfWeek ($date)');
      for (var schedule in schedules) {
        print('- ${schedule.displayString}');
      }

      return schedules;
    } catch (e) {
      print('Error getting schedules for date: $e');
      return [];
    }
  }

  /// Save attendance records linked to specific scheduled class sessions
  Future<void> saveAttendanceWithSchedule(
    String batchId,
    String scheduleId,
    DateTime date,
    List<Map<String, dynamic>> attendanceData, {
    String markedBy = 'Teacher',
  }) async {
    try {
      final batch = _firestore.batch();
      final now = DateTime.now();

      // Get all students in the batch
      final studentsSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('batches')
          .doc(batchId)
          .collection('students')
          .get();
      
      // Get batch/course information for denormalization
      final batchDoc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('batches')
          .doc(batchId)
          .get();
      
      final courseName = batchDoc.data()?['courseName'] ?? 'Unknown Course';
      
      // Get professor information
      final professorDoc = await _firestore
          .collection('users')
          .doc(userId)
          .get();
      
      final professorName = professorDoc.data()?['displayName'] ?? 'Unknown Professor';

      // Create a map of enrollment numbers to student data for quick lookup
      final studentDataMap = Map.fromEntries(studentsSnapshot.docs.map((doc) {
        final data = doc.data();
        return MapEntry(
          data['enrollNumber'] as String,
          {
            'id': doc.id,
            'name': data['name'] ?? 'Unknown Student',
            'enrollNumber': data['enrollNumber'],
          },
        );
      }));

      // Save attendance records in a global attendance collection for easy querying
      for (var studentAttendance in attendanceData) {
        final enrollNumber = studentAttendance['enrollNumber'];
        final studentInfo = studentDataMap[enrollNumber];
        
        if (studentInfo != null) {
          // Create attendance record in global collection with unique ID
          final attendanceRef =
              _firestore.collection('attendance_records').doc();
          final attendanceRecord = AttendanceRecord(
            id: attendanceRef.id,
            studentId: studentInfo['id'],
            batchId: batchId,
            scheduleId: scheduleId,
            date: date,
            isPresent: studentAttendance['isPresent'] ?? false,
            markedAt: now,
            markedBy: markedBy,
            // NEW: Add denormalized data for easy student queries
            studentEnrollment: enrollNumber,
            studentName: studentInfo['name'],
            professorId: userId,
            professorName: professorName,
            courseName: courseName,
          );

          batch.set(attendanceRef, attendanceRecord.toMap());

          // FIXED: Use composite key (date + scheduleId) to prevent overwrites when multiple classes exist on same date
          final studentRef = studentsSnapshot.docs
              .firstWhere((doc) => doc.id == studentInfo['id'])
              .reference;

          final dateStr =
              '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
          // Create unique document ID by combining date and first 8 chars of scheduleId
          final compositeKey = '${dateStr}_${scheduleId.substring(0, 8)}';
          final oldAttendanceRef =
              studentRef.collection('attendance').doc(compositeKey);

          batch.set(oldAttendanceRef, {
            'date': Timestamp.fromDate(date),
            'isPresent': studentAttendance['isPresent'],
            'scheduleId': scheduleId, // Add schedule reference to old structure
            'markedAt': Timestamp.fromDate(now),
            'markedBy': markedBy,
          });
        }
      }

      await batch.commit();
      print('✅ Attendance saved successfully with schedule link');
    } catch (e) {
      print('Error saving attendance with schedule: $e');
      rethrow;
    }
  }

  /// Get attendance records for a student with schedule information
  Future<List<AttendanceRecord>> getStudentAttendanceWithSchedules(
    String studentId,
    String batchId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      // FIXED: Use simpler query and filter in memory to avoid composite index
      final snapshot = await _firestore
          .collection('attendance_records')
          .where('studentId', isEqualTo: studentId)
          .where('batchId', isEqualTo: batchId)
          .get();

      // Filter by date range in memory and sort
      var records = snapshot.docs
          .map((doc) => AttendanceRecord.fromFirestore(doc))
          .where((record) {
        if (startDate != null && record.date.isBefore(startDate)) return false;
        if (endDate != null && record.date.isAfter(endDate)) return false;
        return true;
      }).toList();

      // Sort by date descending
      records.sort((a, b) => b.date.compareTo(a.date));

      return records;
    } catch (e) {
      print('Error getting student attendance with schedules: $e');
      return [];
    }
  }

  /// Get attendance summary for a student showing which specific classes they attended
  Future<StudentAttendanceSummary> getStudentAttendanceSummary(
    String studentId,
    String batchId,
  ) async {
    try {
      // Get student info
      final studentDoc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('batches')
          .doc(batchId)
          .collection('students')
          .doc(studentId)
          .get();

      if (!studentDoc.exists) {
        throw 'Student not found';
      }

      final studentData = studentDoc.data()!;

      // Get attendance records
      final attendanceRecords =
          await getStudentAttendanceWithSchedules(studentId, batchId);

      return StudentAttendanceSummary(
        studentId: studentId,
        studentName: studentData['name'] ?? '',
        enrollNumber: studentData['enrollNumber'] ?? '',
        attendanceRecords: attendanceRecords,
      );
    } catch (e) {
      print('Error getting student attendance summary: $e');
      rethrow;
    }
  }

  /// Get attendance records for a specific date and schedule
  Future<List<Map<String, dynamic>>> getAttendanceForScheduleAndDate(
    String batchId,
    String scheduleId,
    DateTime date,
  ) async {
    try {
      // FIXED: Use fewer where clauses and filter in memory
      final snapshot = await _firestore
          .collection('attendance_records')
          .where('batchId', isEqualTo: batchId)
          .where('scheduleId', isEqualTo: scheduleId)
          .get();

      // Filter by date in memory
      final dateStart = DateTime(date.year, date.month, date.day);
      final dateEnd = DateTime(date.year, date.month, date.day, 23, 59, 59);

      final List<Map<String, dynamic>> attendanceList = [];

      for (var doc in snapshot.docs) {
        final record = AttendanceRecord.fromFirestore(doc);

        // Skip if date doesn't match
        if (record.date.isBefore(dateStart) || record.date.isAfter(dateEnd)) {
          continue;
        }

        // Get student info
        final studentDoc = await _firestore
            .collection('users')
            .doc(userId)
            .collection('batches')
            .doc(batchId)
            .collection('students')
            .doc(record.studentId)
            .get();

        if (studentDoc.exists) {
          final studentData = studentDoc.data()!;
          attendanceList.add({
            'name': studentData['name'],
            'enrollNumber': studentData['enrollNumber'],
            'isPresent': record.isPresent,
            'markedAt': record.markedAt,
            'markedBy': record.markedBy,
          });
        }
      }

      return attendanceList;
    } catch (e) {
      print('Error getting attendance for schedule and date: $e');
      return [];
    }
  }

  /// Mark attendance via ESP32 with schedule linking
  Future<bool> markAttendanceByMacAddressWithSchedule(
      String macAddress, DateTime date) async {
    try {
      // Find student in currently scheduled batch
      final studentData =
          await getStudentByMacAddressInCurrentBatch(macAddress);
      if (studentData == null) {
        print(
            'No student found with MAC address: $macAddress in current batch');
        return false;
      }

      // Get current schedules for this batch and date
      final schedules = await getSchedulesForDate(studentData['batchId'], date);
      if (schedules.isEmpty) {
        print('No schedules found for current date and batch');
        return false;
      }

      // Find the current time slot
      final now = DateTime.now();
      final currentTime =
          "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";

      CourseSchedule? currentSchedule;
      for (var schedule in schedules) {
        if (currentTime.compareTo(schedule.startTime) >= 0 &&
            currentTime.compareTo(schedule.endTime) <= 0) {
          currentSchedule = schedule;
          break;
        }
      }

      if (currentSchedule == null) {
        print('No class currently in session');
        return false;
      }

      // FIXED: Check if attendance already marked for this schedule (use fewer where clauses)
      final existingAttendance = await _firestore
          .collection('attendance_records')
          .where('studentId', isEqualTo: studentData['studentId'])
          .where('scheduleId', isEqualTo: currentSchedule.id)
          .get();

      // Filter by batchId and date in memory
      final dateStart = DateTime(date.year, date.month, date.day);
      final dateEnd = DateTime(date.year, date.month, date.day, 23, 59, 59);

      final matchingRecords = existingAttendance.docs.where((doc) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data == null) return false;

        if (data['batchId'] != studentData['batchId']) return false;

        final recordDate = (data['date'] as Timestamp?)?.toDate();
        if (recordDate == null) return false;

        return recordDate
                .isAfter(dateStart.subtract(const Duration(seconds: 1))) &&
            recordDate.isBefore(dateEnd.add(const Duration(seconds: 1)));
      }).toList();

      if (matchingRecords.isNotEmpty) {
        print('Attendance already marked for this schedule');
        return true;
      }

      // Mark attendance for the specific schedule
      await saveAttendanceWithSchedule(
        studentData['batchId'],
        currentSchedule.id,
        date,
        [
          {
            'enrollNumber': studentData['enrollNumber'],
            'isPresent': true,
          }
        ],
        markedBy: 'ESP32',
      );

      print(
          '✅ Attendance marked for ${studentData['name']} for ${currentSchedule.displayString}');
      return true;
    } catch (e) {
      print('Error marking attendance by MAC with schedule: $e');
      return false;
    }
  }
}
