import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Service to handle student profile operations
class StudentProfileService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Check if enrollment number exists for the student
  Future<Map<String, dynamic>?> getStudentProfile(String userId) async {
    try {
      final doc = await _firestore
          .collection('student_profiles')
          .doc(userId)
          .get();

      if (doc.exists) {
        return doc.data();
      }
      return null;
    } catch (e) {
      print('Error getting student profile: $e');
      return null;
    }
  }

  /// Save or update student enrollment number
  Future<void> saveEnrollmentNumber({
    required String userId,
    required String enrollmentNumber,
    required String email,
    required String name,
  }) async {
    try {
      // Use email as document ID (sanitized)
      final docId = email.replaceAll('.', '_').replaceAll('@', '_at_');
      
      await _firestore.collection('student_profiles').doc(docId).set({
        'enrollmentNumber': enrollmentNumber.toUpperCase(),
        'email': email,
        'name': name,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('Error saving enrollment number: $e');
      rethrow;
    }
  }

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

  /// Check if enrollment number already exists
  Future<bool> enrollmentNumberExists(String enrollmentNumber) async {
    try {
      final querySnapshot = await _firestore
          .collection('student_profiles')
          .where('enrollmentNumber', isEqualTo: enrollmentNumber.toUpperCase())
          .limit(1)
          .get();

      return querySnapshot.docs.isNotEmpty;
    } catch (e) {
      print('Error checking enrollment number: $e');
      return false;
    }
  }
}
