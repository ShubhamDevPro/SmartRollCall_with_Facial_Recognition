import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:smart_roll_call_flutter/models/batch_schedule.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String userId = 'public_user';

  // Get batches for current user
  Stream<QuerySnapshot> getBatches() {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('batches')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // Add new batch (backward compatible - adds default schedule)
  Future<DocumentReference> addBatch(
      String name, String year, IconData icon, String title) async {
    try {
      return await _firestore
          .collection('users')
          .doc(userId)
          .collection('batches')
          .add({
        'batchName': name,
        'batchYear': year,
        'icon': icon.codePoint,
        'title': title,
        'dayOfWeek': 'Monday', // Default day
        'startTime': '09:00',   // Default start time
        'endTime': '10:00',     // Default end time
        'isActive': true,
        'createdAt': Timestamp.now(),
      });
    } catch (e) {
      print('Error adding batch: $e');
      rethrow;
    }
  }

  // Get students in a batch
  Stream<QuerySnapshot> getStudents(String batchId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('batches')
        .doc(batchId)
        .collection('students')
        .snapshots();
  }

  // Add student to batch
  Future<void> addStudent(
      String batchId, Map<String, dynamic> studentData) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('batches')
        .doc(batchId)
        .collection('students')
        .add(studentData);
  }

  // Update student attendance
  Future<void> updateStudentAttendance(
      String batchId, String studentId, bool isPresent) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('batches')
        .doc(batchId)
        .collection('students')
        .doc(studentId)
        .update({'isPresent': isPresent});
  }

  // Delete batch and all its students
  Future<void> deleteBatch(String batchId) async {
    // Get reference to the batch
    final batchRef = _firestore
        .collection('users')
        .doc(userId)
        .collection('batches')
        .doc(batchId);

    // Get all students in the batch
    final studentsSnapshot = await batchRef.collection('students').get();

    // Delete all students
    for (var doc in studentsSnapshot.docs) {
      await doc.reference.delete();
    }

    // Delete the batch itself
    await batchRef.delete();
  }

  // Add this new method to FirestoreService class
  Future<void> updateBatch(String batchId, String title, String batchName,
      String batchYear, int iconCodePoint, [String? dayOfWeek, String? startTime, String? endTime]) async {
    try {
      print('Updating batch with ID: $batchId');
      final updateData = {
        'title': title,
        'batchName': batchName,
        'batchYear': batchYear,
        'icon': iconCodePoint,
      };
      
      // Add scheduling data if provided
      if (dayOfWeek != null) updateData['dayOfWeek'] = dayOfWeek;
      if (startTime != null) updateData['startTime'] = startTime;
      if (endTime != null) updateData['endTime'] = endTime;
      
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('batches')
          .doc(batchId)
          .update(updateData);
      print('Batch updated successfully');
    } catch (e) {
      print('Error updating batch: $e');
      rethrow;
    }
  }

  // Add new method to save attendance for a specific date
  Future<void> saveAttendanceForDate(String batchId, DateTime date,
      List<Map<String, dynamic>> attendanceData) async {
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

  // Add this new method to get attendance for all students on a specific date
  Future<List<Map<String, dynamic>>> getAttendanceForDateAll(
      DateTime date, [String? selectedBatchId]) async {
    final dateStr =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    List<Map<String, dynamic>> attendanceList = [];

    try {
      // If selectedBatchId is provided, get only that batch, otherwise get all batches
      final Query batchQuery = selectedBatchId != null
          ? _firestore
              .collection('users')
              .doc(userId)
              .collection('batches')
              .where(FieldPath.documentId, isEqualTo: selectedBatchId)
          : _firestore
              .collection('users')
              .doc(userId)
              .collection('batches');

      final batchesSnapshot = await batchQuery.get();

      for (var batch in batchesSnapshot.docs) {
        final studentsSnapshot =
            await batch.reference.collection('students').get();

        for (var student in studentsSnapshot.docs) {
          // Get all attendance records for this student
          final allAttendanceSnapshot =
              await student.reference.collection('attendance').get();

          // Calculate attendance statistics
          int totalDays = allAttendanceSnapshot.docs.length;
          int presentDays = allAttendanceSnapshot.docs
              .where((doc) => doc.data()['isPresent'] == true)
              .length;

          // Get attendance for the specific date
          final attendanceSnapshot = await student.reference
              .collection('attendance')
              .doc(dateStr)
              .get();

          if (attendanceSnapshot.exists) {
            attendanceList.add({
              'name': student.data()['name'],
              'enrollNumber': student.data()['enrollNumber'],
              'isPresent': attendanceSnapshot.data()?['isPresent'] ?? false,
              'batchId': batch.id,
              'totalDays': totalDays,
              'presentDays': presentDays,
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

  // Add this new method to update attendance status
  Future<void> updateAttendanceStatus(
    String batchId,
    String enrollNumber,
    DateTime date,
    bool newStatus,
  ) async {
    final dateStr =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

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

      // Update the attendance status
      final studentDoc = studentsSnapshot.docs.first;
      await studentDoc.reference
          .collection('attendance')
          .doc(dateStr)
          .update({'isPresent': newStatus});
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
          studentAttendance[enrollNo]['attendance'][dateStr] = student['isPresent'];
        }
      }

      return studentAttendance;
    } catch (e) {
      throw Exception('Failed to fetch attendance data: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getAttendanceHistory(String batchId) async {
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
        final attendanceSnapshot = await student.reference
            .collection('attendance')
            .get();
        
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
      final currentTime = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";

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
          print('Found currently scheduled batch: ${batch.id} ($startTime-$endTime)');
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
  Future<Map<String, dynamic>?> getStudentByMacAddressInCurrentBatch(String macAddress) async {
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

      print('No student found with MAC $macAddress in current batch $currentBatchId');
      return null;
    } catch (e) {
      print('Error finding student by MAC in current batch: $e');
      return null;
    }
  }

  /// Mark attendance via ESP32 for currently scheduled batch only
  Future<bool> markAttendanceByMacAddressCurrentBatch(String macAddress, DateTime date) async {
    try {
      // Find student in currently scheduled batch
      final studentData = await getStudentByMacAddressInCurrentBatch(macAddress);
      if (studentData == null) {
        print('No student found with MAC address: $macAddress in current batch');
        return false;
      }

      final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      
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
        print('Attendance already marked for ${studentData['name']} on $dateStr in batch ${studentData['batchId']}');
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
        'markedDuringClass': true, // Flag to indicate this was marked during actual class time
      });

      print('✅ Attendance marked for ${studentData['name']} (${studentData['enrollNumber']}) in batch ${studentData['batchId']} via ESP32');
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
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return days[weekday - 1];
  }

  /// Add batch with scheduling information
  Future<DocumentReference> addBatchWithSchedule(
    String name, 
    String year, 
    IconData icon, 
    String title,
    String dayOfWeek,
    String startTime,
    String endTime,
  ) async {
    try {
      return await _firestore
          .collection('users')
          .doc(userId)
          .collection('batches')
          .add({
        'batchName': name,
        'batchYear': year,
        'icon': icon.codePoint,
        'title': title,
        'dayOfWeek': dayOfWeek,
        'startTime': startTime,
        'endTime': endTime,
        'isActive': true,
        'createdAt': Timestamp.now(),
      });
    } catch (e) {
      print('Error adding batch with schedule: $e');
      rethrow;
    }
  }

  /// Get student by MAC address across all batches
  /// Used by ESP32 to identify student before marking attendance
  Future<Map<String, dynamic>?> getStudentByMacAddress(String macAddress) async {
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
  Future<bool> markAttendanceByMacAddress(String macAddress, DateTime date) async {
    try {
      // Find student by MAC address
      final studentData = await getStudentByMacAddress(macAddress);
      if (studentData == null) {
        print('No student found with MAC address: $macAddress');
        return false;
      }

      final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      
      // Check if attendance already marked for today
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
        print('Attendance already marked for ${studentData['name']} on $dateStr');
        return true; // Already marked, consider it successful
      }

      // Mark attendance as present
      await attendanceRef.set({
        'date': Timestamp.fromDate(date),
        'isPresent': true,
        'markedBy': 'ESP32',
        'markedAt': Timestamp.now(),
        'macAddress': macAddress.toUpperCase(),
      });

      print('Attendance marked for ${studentData['name']} (${studentData['enrollNumber']}) via ESP32');
      return true;
    } catch (e) {
      print('Error marking attendance by MAC address: $e');
      return false;
    }
  }
}
