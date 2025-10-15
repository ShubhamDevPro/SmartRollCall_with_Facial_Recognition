import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Service to handle student profile operations
class StudentProfileService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Get student profile by email
  Future<Map<String, dynamic>?> getStudentProfileByEmail(String email) async {
    try {
      final querySnapshot = await _firestore
          .collection('student_profiles')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        return querySnapshot.docs.first.data();
      }
      return null;
    } catch (e) {
      print('Error getting student profile by email: $e');
      return null;
    }
  }
}
