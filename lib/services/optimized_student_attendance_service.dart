import 'package:cloud_firestore/cloud_firestore.dart';

/// Optimized service for fetching student attendance using the flat attendance_records collection
/// This is 10-20x faster than scanning nested collections!
class OptimizedStudentAttendanceService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Cache to avoid repeated queries
  static final Map<String, CachedAttendance> _cache = {};
  static const Duration _cacheDuration = Duration(minutes: 5);
  
  /// Get all attendance records for a student
  /// Uses the flat attendance_records collection for blazing fast queries!
  Future<List<Map<String, dynamic>>> getStudentAttendance(
    String enrollmentNumber, {
    bool forceRefresh = false,
  }) async {
    try {
      // Check cache first
      if (!forceRefresh && _cache.containsKey(enrollmentNumber)) {
        final cached = _cache[enrollmentNumber]!;
        if (DateTime.now().difference(cached.timestamp) < _cacheDuration) {
          print('💾 Returning cached attendance for $enrollmentNumber');
          return cached.records;
        }
      }
      
      print('📊 Fetching attendance for enrollment: $enrollmentNumber');
      
      // Direct query on flat collection - super fast with index!
      final snapshot = await _firestore
          .collection('attendance_records')
          .where('studentEnrollment', isEqualTo: enrollmentNumber)
          .orderBy('date', descending: true)
          .limit(100)  // Last 100 attendance records
          .get();
      
      if (snapshot.docs.isEmpty) {
        print('❌ No attendance records found');
        return [];
      }
      
      print('✅ Found ${snapshot.docs.length} attendance records');
      
      // Convert to app format
      final records = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'studentEnrollment': data['studentEnrollment'],
          'studentName': data['studentName'] ?? 'Unknown',
          'professorName': data['professorName'] ?? 'Unknown Professor',
          'courseName': data['courseName'] ?? 'Unknown Course',
          'date': (data['date'] as Timestamp).toDate(),
          'isPresent': data['isPresent'] ?? false,
          'markedBy': data['markedBy'] ?? 'Unknown',
          'markedAt': (data['markedAt'] as Timestamp?)?.toDate(),
          'batchId': data['batchId'],
          'scheduleId': data['scheduleId'],
        };
      }).toList();
      
      // Cache the results
      _cache[enrollmentNumber] = CachedAttendance(
        records: records,
        timestamp: DateTime.now(),
      );
      
      return records;
      
    } catch (e) {
      print('❌ Error fetching attendance: $e');
      
      // Check if it's an index error
      if (e.toString().contains('index') || e.toString().contains('FAILED_PRECONDITION')) {
        print('');
        print('⚠️  FIRESTORE INDEX REQUIRED! ⚠️');
        print('═══════════════════════════════════════════════════════════');
        print('Your query requires a Firestore composite index.');
        print('');
        print('OPTION 1: Automatic Setup (Easiest)');
        print('  1. Look for an error link in the console (above)');
        print('  2. Click the link to auto-create the index');
        print('  3. Wait 2-5 minutes for index to build');
        print('');
        print('OPTION 2: Manual Setup');
        print('  1. Go to: https://console.firebase.google.com/project/_/firestore/indexes');
        print('  2. Click "Create Index"');
        print('  3. Collection: attendance_records');
        print('  4. Field: studentEnrollment (Ascending)');
        print('  5. Field: date (Descending)');
        print('  6. Click "Create" and wait 2-5 minutes');
        print('');
        print('See FIRESTORE_INDEX_SETUP.md for detailed instructions');
        print('═══════════════════════════════════════════════════════════');
        print('');
      }
      
      rethrow;
    }
  }
  
  /// Get attendance statistics for a student
  Future<Map<String, dynamic>> getAttendanceStats(
    String enrollmentNumber,
  ) async {
    final records = await getStudentAttendance(enrollmentNumber);
    
    if (records.isEmpty) {
      return {
        'total': 0,
        'present': 0,
        'absent': 0,
        'percentage': 0.0,
        'courses': <String, Map<String, dynamic>>{},
      };
    }
    
    final total = records.length;
    final present = records.where((r) => r['isPresent'] == true).length;
    final absent = total - present;
    final percentage = (present / total) * 100;
    
    // Calculate course-wise stats
    final Map<String, Map<String, dynamic>> courseStats = {};
    for (var record in records) {
      final courseName = record['courseName'] as String;
      if (!courseStats.containsKey(courseName)) {
        courseStats[courseName] = {
          'total': 0,
          'present': 0,
          'professorName': record['professorName'],
        };
      }
      courseStats[courseName]!['total'] = 
          (courseStats[courseName]!['total'] as int) + 1;
      if (record['isPresent'] == true) {
        courseStats[courseName]!['present'] = 
            (courseStats[courseName]!['present'] as int) + 1;
      }
    }
    
    return {
      'total': total,
      'present': present,
      'absent': absent,
      'percentage': percentage,
      'courses': courseStats,
    };
  }
  
  /// Get attendance records for a specific course
  Future<List<Map<String, dynamic>>> getCourseAttendance(
    String enrollmentNumber,
    String batchId,
  ) async {
    try {
      final snapshot = await _firestore
          .collection('attendance_records')
          .where('studentEnrollment', isEqualTo: enrollmentNumber)
          .where('batchId', isEqualTo: batchId)
          .orderBy('date', descending: true)
          .get();
      
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'courseName': data['courseName'],
          'date': (data['date'] as Timestamp).toDate(),
          'isPresent': data['isPresent'],
          'markedBy': data['markedBy'],
        };
      }).toList();
    } catch (e) {
      print('❌ Error fetching course attendance: $e');
      return [];
    }
  }
  
  /// Clear cache for a specific student or all students
  void clearCache([String? enrollmentNumber]) {
    if (enrollmentNumber != null) {
      _cache.remove(enrollmentNumber);
      print('🗑️ Cleared cache for $enrollmentNumber');
    } else {
      _cache.clear();
      print('🗑️ Cleared all cache');
    }
  }
  
  /// Get real-time attendance updates (stream)
  Stream<List<Map<String, dynamic>>> watchStudentAttendance(
    String enrollmentNumber,
  ) {
    return _firestore
        .collection('attendance_records')
        .where('studentEnrollment', isEqualTo: enrollmentNumber)
        .orderBy('date', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            return {
              'id': doc.id,
              'studentName': data['studentName'],
              'professorName': data['professorName'],
              'courseName': data['courseName'],
              'date': (data['date'] as Timestamp).toDate(),
              'isPresent': data['isPresent'],
              'markedBy': data['markedBy'],
            };
          }).toList();
        });
  }
}

/// Cache data structure
class CachedAttendance {
  final List<Map<String, dynamic>> records;
  final DateTime timestamp;
  
  CachedAttendance({
    required this.records,
    required this.timestamp,
  });
}
