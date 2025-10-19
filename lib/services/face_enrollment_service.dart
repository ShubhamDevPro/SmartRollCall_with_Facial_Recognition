import 'dart:typed_data';
import 'package:facesdk_plugin/facesdk_plugin.dart';
import 'dart:io' show Platform;
import 'student_profile_service.dart';

/// Service to handle face enrollment and verification using FaceSDK
class FaceEnrollmentService {
  final FacesdkPlugin _facesdkPlugin = FacesdkPlugin();
  final StudentProfileService _profileService = StudentProfileService();

  bool _isInitialized = false;

  /// Initialize FaceSDK with license
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      int facepluginState = -1;

      // Set activation based on platform
      if (Platform.isAndroid) {
        await _facesdkPlugin
            .setActivation(
                "j63rQnZifPT82LEDGFa+wzorKx+M55JQlNr+S0bFfvMULrNYt+UEWIsa11V/Wk1bU9Srti0/FQqp"
                "UczeCxFtiEcABmZGuTzNd27XnwXHUSIMaFOkrpNyNE4MHb7HBm5kU/0J/SAMfybICCWyFajuZ4fL"
                "agozJV5DPKj22oFVaueWMjO/9fMvcps4u1AIiHH2rjP4mEYfiAE8nhHBa1Ou3u/WkXj6jdDafyJo"
                "AFtQHYJYKDU+hcbtCZ3P1f8y1JB5JxOf92ItK4euAt6/OFG9jGfKpo/Fs2mAgwxH3HoWMLJQ16Iy"
                "u2K6boMyDxRQtBJFTiktuJ+ltlay+dVqIi3Jpg==")
            .then((value) => facepluginState = value ?? -1);
      } else {
        await _facesdkPlugin
            .setActivation(
                "qtUa0F+8kUQ3IKx0KnH7INdhZobNEry1toTG1IqYBCeFFj66uMc2Znp3Tlj+fPdO212bCJrRCK27"
                "xKyn0qNtbRene869aUDxMf9nZyPDVDuWoz6TZKdKhgAGlQ65RoLAunUrbLfIwR/OqqZU8zwxwAYU"
                "BPn6f7X0zkoAFDwMUgBMR87RQdLDkGssfCDOmyOYW3qq1hX9k9FZvFMuC6nzJQhQgAy1edFJ4YuW"
                "g5BKXKsulTTzq2cPwz0qPUNp1qR75OitXjo9KoojhJEM6Hj7n8l6ydcPpZpdpUURrn5/7RLEVteX"
                "l84vhHGm6jXjOftcNdR1ikC7wM2hhfVQuhK0gA==")
            .then((value) => facepluginState = value ?? -1);
      }

      if (facepluginState == 0) {
        await _facesdkPlugin
            .init()
            .then((value) => facepluginState = value ?? -1);
      }

      // Set default parameters
      if (facepluginState == 0) {
        await _facesdkPlugin.setParam({'check_liveness_level': 0});
      }

      _isInitialized = facepluginState == 0;

      if (_isInitialized) {
        print('✅ FaceSDK initialized successfully');
      } else {
        String errorMsg = '';
        switch (facepluginState) {
          case -1:
            errorMsg = 'Invalid license';
            break;
          case -2:
            errorMsg =
                'License expired - Please contact KBY-AI (contact@kby-ai.com)';
            break;
          case -3:
            errorMsg = 'Invalid license format';
            break;
          case -4:
            errorMsg = 'Not activated';
            break;
          case -5:
            errorMsg = 'Initialization error';
            break;
          default:
            errorMsg = 'Unknown error';
        }
        print(
            '❌ FaceSDK initialization failed with code: $facepluginState ($errorMsg)');
      }

      return _isInitialized;
    } catch (e) {
      print('❌ Error initializing FaceSDK: $e');
      return false;
    }
  }

  /// Extract face from image and return face data (templates and liveness only)
  Future<Map<String, dynamic>?> extractFaceFromImage(String imagePath) async {
    try {
      if (!_isInitialized) {
        print('⚠️ FaceSDK not initialized, attempting to initialize...');
        final initialized = await initialize();
        if (!initialized) {
          return null;
        }
      }

      print('🔍 Extracting face from image: $imagePath');

      final faces = await _facesdkPlugin.extractFaces(imagePath);

      if (faces == null || faces.isEmpty) {
        print('❌ No face detected in image');
        return null;
      }

      if (faces.length > 1) {
        print('⚠️ Multiple faces detected, using first face');
      }

      final face = faces[0];
      print('✅ Face extracted successfully');

      // Return only templates (embeddings) and liveness, no face image
      return {
        'templates': face['templates'] as Uint8List,
        'liveness': face['liveness'] ?? 0.0,
      };
    } catch (e) {
      print('❌ Error extracting face: $e');
      return null;
    }
  }

  /// Enroll face for a student
  Future<bool> enrollFace({
    required String enrollmentNumber,
    required String imagePath,
  }) async {
    try {
      // Extract face from image
      final faceData = await extractFaceFromImage(imagePath);
      if (faceData == null) {
        return false;
      }

      // Store only templates (embeddings) in Firestore
      final success = await _profileService.storeFaceEmbedding(
        enrollmentNumber: enrollmentNumber,
        templates: faceData['templates'],
      );

      return success;
    } catch (e) {
      print('❌ Error enrolling face: $e');
      return false;
    }
  }

  /// Verify face against enrolled template
  Future<Map<String, dynamic>?> verifyFace({
    required String enrollmentNumber,
    required String imagePath,
  }) async {
    try {
      if (!_isInitialized) {
        final initialized = await initialize();
        if (!initialized) {
          return null;
        }
      }

      // Get stored embedding (templates only)
      final storedEmbedding =
          await _profileService.getFaceEmbedding(enrollmentNumber);
      if (storedEmbedding == null) {
        print('❌ No face embedding found for enrollment: $enrollmentNumber');
        return null;
      }

      // Extract face from current image
      final faceData = await extractFaceFromImage(imagePath);
      if (faceData == null) {
        return null;
      }

      // Calculate similarity using only embeddings
      final similarity = await _facesdkPlugin.similarityCalculation(
        faceData['templates'],
        storedEmbedding,
      );

      if (similarity == null) {
        print('❌ Failed to calculate similarity');
        return null;
      }

      print('📊 Similarity score: $similarity');
      print('📊 Liveness score: ${faceData['liveness']}');

      // Return only similarity and liveness, no face images
      return {
        'similarity': similarity,
        'liveness': faceData['liveness'],
      };
    } catch (e) {
      print('❌ Error verifying face: $e');
      return null;
    }
  }

  /// Check if student has face enrolled
  Future<bool> hasFaceEnrolled(String enrollmentNumber) async {
    return await _profileService.hasFaceEmbedding(enrollmentNumber);
  }
}
