import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:typed_data';

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
        final data = querySnapshot.docs.first.data();
        data['id'] = querySnapshot.docs.first.id; // Include document ID
        return data;
      }
      return null;
    } catch (e) {
      print('Error getting student profile by email: $e');
      return null;
    }
  }

  /// Get student profile by enrollment number
  Future<Map<String, dynamic>?> getStudentProfileByEnrollment(
      String enrollmentNumber) async {
    try {
      final querySnapshot = await _firestore
          .collection('student_profiles')
          .where('enrollmentNumber', isEqualTo: enrollmentNumber)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final data = querySnapshot.docs.first.data();
        data['id'] = querySnapshot.docs.first.id;
        return data;
      }
      return null;
    } catch (e) {
      print('Error getting student profile by enrollment: $e');
      return null;
    }
  }

  /// Check if student has face embedding enrolled
  Future<bool> hasFaceEmbedding(String enrollmentNumber) async {
    try {
      final profile = await getStudentProfileByEnrollment(enrollmentNumber);
      if (profile == null) return false;

      return profile.containsKey('faceTemplates') &&
          profile['faceTemplates'] != null;
    } catch (e) {
      print('Error checking face embedding: $e');
      return false;
    }
  }

  /// Store face embedding for a student
  Future<bool> storeFaceEmbedding({
    required String enrollmentNumber,
    required Uint8List templates,
  }) async {
    try {
      final profile = await getStudentProfileByEnrollment(enrollmentNumber);
      if (profile == null) {
        print('❌ Student profile not found for enrollment: $enrollmentNumber');
        return false;
      }

      final studentId = profile['id'] as String;

      // Convert Uint8List to List<int> for Firestore storage
      // Only store templates (embeddings), not the face image
      await _firestore.collection('student_profiles').doc(studentId).update({
        'faceTemplates': templates.toList(),
        'faceEnrolledAt': FieldValue.serverTimestamp(),
      });

      print('✅ Face embedding stored successfully for: $enrollmentNumber');
      return true;
    } catch (e) {
      print('❌ Error storing face embedding: $e');
      return false;
    }
  }

  /// Get face embedding for a student
  Future<Uint8List?> getFaceEmbedding(String enrollmentNumber) async {
    try {
      final profile = await getStudentProfileByEnrollment(enrollmentNumber);
      if (profile == null) return null;

      if (profile.containsKey('faceTemplates') &&
          profile['faceTemplates'] != null) {
        return Uint8List.fromList(List<int>.from(profile['faceTemplates']));
      }
      return null;
    } catch (e) {
      print('Error getting face embedding: $e');
      return null;
    }
  }
}
