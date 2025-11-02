import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_exif_rotation/flutter_exif_rotation.dart';
import 'dart:async';
import '../../services/face_enrollment_service.dart';

/// Service to handle real-time pending verification listening
class FaceVerificationListener {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  StreamSubscription<QuerySnapshot>? _subscription;

  /// Start listening for pending verifications for a specific student
  void startListening({
    required String enrollmentNumber,
    required Function(Map<String, dynamic>) onVerificationReceived,
  }) {
    print('🎯 Starting verification listener for: $enrollmentNumber');

    _subscription = _firestore
        .collection('pending_verifications')
        .where('studentEnrollment', isEqualTo: enrollmentNumber)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data() as Map<String, dynamic>;
          data['verificationId'] = change.doc.id;

          print('🔔 New verification received: ${change.doc.id}');
          onVerificationReceived(data);
        }
      }
    });
  }

  /// Stop listening
  void stopListening() {
    _subscription?.cancel();
    _subscription = null;
    print('🛑 Verification listener stopped');
  }
}

/// Modal bottom sheet that shows face verification prompt
class FaceVerificationPrompt extends StatefulWidget {
  final Map<String, dynamic> verificationData;
  final Function() onVerificationComplete;

  const FaceVerificationPrompt({
    Key? key,
    required this.verificationData,
    required this.onVerificationComplete,
  }) : super(key: key);

  @override
  State<FaceVerificationPrompt> createState() => _FaceVerificationPromptState();
}

class _FaceVerificationPromptState extends State<FaceVerificationPrompt> {
  bool _isVerifying = false;
  int _timeRemaining = 5; // 5 minutes
  Timer? _countdownTimer;
  final FaceEnrollmentService _faceService = FaceEnrollmentService();

  @override
  void initState() {
    super.initState();
    _startCountdown();
    _checkExpiration();
    _initializeFaceSDK();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  /// Initialize FaceSDK
  Future<void> _initializeFaceSDK() async {
    await _faceService.initialize();
  }

  void _startCountdown() {
    final expiresAt =
        (widget.verificationData['expiresAt'] as Timestamp?)?.toDate();
    if (expiresAt == null) return;

    _timeRemaining = expiresAt.difference(DateTime.now()).inSeconds;
    if (_timeRemaining < 0) _timeRemaining = 0;

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _timeRemaining--;
          if (_timeRemaining <= 0) {
            timer.cancel();
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                    'Verification expired. Please reconnect to mark attendance.'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        });
      }
    });
  }

  void _checkExpiration() async {
    final expiresAt =
        (widget.verificationData['expiresAt'] as Timestamp?)?.toDate();
    if (expiresAt == null) return;

    if (DateTime.now().isAfter(expiresAt)) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Verification expired.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  Future<void> _verifyAndMarkAttendance() async {
    setState(() {
      _isVerifying = true;
    });

    try {
      final enrollmentNumber =
          widget.verificationData['studentEnrollment'] as String;

      // Try to initialize FaceSDK
      final sdkInitialized = await _faceService.initialize();

      if (!sdkInitialized) {
        // SDK not available (license expired), show option for manual verification
        if (mounted) {
          final shouldContinue = await showDialog<bool>(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.warning, color: Colors.orange),
                  SizedBox(width: 12),
                  Text('Face Recognition Unavailable'),
                ],
              ),
              content: const Text(
                  'Face recognition is temporarily unavailable (license expired).\n\n'
                  'Would you like to mark attendance manually without face verification?\n\n'
                  'Note: Contact admin to enable face verification:\n'
                  '📧 contact@kby-ai.com'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Mark Manually'),
                ),
              ],
            ),
          );

          if (shouldContinue != true) {
            setState(() {
              _isVerifying = false;
            });
            return;
          }

          // Proceed with manual verification (no face recognition)
          print(
              '✅ Manual verification (SDK unavailable) for: $enrollmentNumber');

          final verificationId =
              widget.verificationData['verificationId'] as String;
          await _moveToAttendanceRecords(verificationId);

          if (mounted) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.white),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Attendance marked successfully! (Manual verification)',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ],
                ),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 3),
              ),
            );

            widget.onVerificationComplete();
          }
          return;
        }
      }

      // SDK is available, proceed with face verification
      // Check if student has face enrolled
      final hasEnrolled = await _faceService.hasFaceEnrolled(enrollmentNumber);

      if (!hasEnrolled) {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Please enroll your face first before using face verification.',
              ),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 4),
            ),
          );
        }
        return;
      }

      // Capture face image for verification
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        imageQuality: 90,
      );

      if (image == null) {
        setState(() {
          _isVerifying = false;
        });
        return;
      }

      // Rotate image if needed
      final rotatedImage =
          await FlutterExifRotation.rotateImage(path: image.path);

      print('✅ Verifying face for: $enrollmentNumber');

      // Verify face against stored embedding
      final verificationResult = await _faceService.verifyFace(
        enrollmentNumber: enrollmentNumber,
        imagePath: rotatedImage.path,
      );

      if (verificationResult == null) {
        if (mounted) {
          setState(() {
            _isVerifying = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to verify face. Please try again.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final similarity = verificationResult['similarity'] as double;
      final liveness = verificationResult['liveness'] as double;

      // Thresholds for verification
      const double similarityThreshold = 0.8; // 80% similarity required
      const double livenessThreshold = 0.7; // 70% liveness required

      print('📊 Similarity: $similarity, Liveness: $liveness');

      if (similarity >= similarityThreshold && liveness >= livenessThreshold) {
        // Face verified successfully, mark attendance
        final verificationId =
            widget.verificationData['verificationId'] as String;
        await _moveToAttendanceRecords(verificationId);

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Face verified! Attendance marked successfully!',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );

          widget.onVerificationComplete();
        }
      } else {
        // Face verification failed
        if (mounted) {
          setState(() {
            _isVerifying = false;
          });

          String detailedReason = '';
          if (similarity < similarityThreshold) {
            detailedReason = 'The face does not match your enrolled profile.';
          }
          if (liveness < livenessThreshold) {
            detailedReason += (detailedReason.isEmpty ? '' : ' ') + 'Please use a live camera feed (photos not allowed).';
          }

          // Show stern warning dialog
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.red, size: 32),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Verification Failed',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    detailedReason,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.error_outline, color: Colors.red, size: 20),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '⚠️ Warning: Attempting to verify with someone else\'s face is a serious violation. This incident will be reported to the authorities and may result in disciplinary action.',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.red,
                              fontWeight: FontWeight.w500,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Please try again with your own face or contact your professor.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey[700],
                  ),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    // Allow user to try again
                    _verifyAndMarkAttendance();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Try Again'),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      print('❌ Error verifying attendance: $e');

      if (mounted) {
        setState(() {
          _isVerifying = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error verifying face: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _moveToAttendanceRecords(String verificationId) async {
    final firestore = FirebaseFirestore.instance;

    // Get the pending verification document
    final verificationDoc = await firestore
        .collection('pending_verifications')
        .doc(verificationId)
        .get();

    if (!verificationDoc.exists) {
      throw Exception('Verification record not found');
    }

    final data = verificationDoc.data()!;

    // Create attendance record
    await firestore.collection('attendance_records').add({
      'studentId': data['studentId'],
      'studentEnrollment': data['studentEnrollment'],
      'studentName': data['studentName'],
      'batchId': data['batchId'],
      'scheduleId': data['scheduleId'],
      'courseName': data['courseName'],
      'professorId': data['professorId'],
      'professorName': data['professorName'],
      'date': data['date'],
      'isPresent': true,
      'markedAt': FieldValue.serverTimestamp(),
      'markedBy': 'ESP32-FaceVerification',
      'verificationId': verificationId,
    });

    // Update pending verification status
    await firestore
        .collection('pending_verifications')
        .doc(verificationId)
        .update({
      'status': 'verified',
      'verifiedAt': FieldValue.serverTimestamp(),
    });

    print('✅ Attendance record created and verification updated');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Icon
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.deepPurple.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.face,
              size: 48,
              color: Colors.deepPurple.shade600,
            ),
          ),

          const SizedBox(height: 20),

          // Title
          const Text(
            'Attendance Detected!',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),

          const SizedBox(height: 12),

          // Description
          Text(
            'Your device has been detected in the classroom.\nPlease verify your face to mark attendance.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              height: 1.5,
            ),
          ),

          const SizedBox(height: 20),

          // Course Info Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.school, size: 20, color: Colors.grey[700]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.verificationData['courseName'] ?? 'Class',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.person, size: 20, color: Colors.grey[700]),
                    const SizedBox(width: 8),
                    Text(
                      widget.verificationData['professorName'] ?? 'Professor',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Time remaining
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: _timeRemaining < 60
                  ? Colors.red.shade50
                  : Colors.blue.shade50,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.access_time,
                  size: 16,
                  color: _timeRemaining < 60 ? Colors.red : Colors.blue,
                ),
                const SizedBox(width: 8),
                Text(
                  'Time remaining: ${_formatTime(_timeRemaining)}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: _timeRemaining < 60 ? Colors.red : Colors.blue,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Verify Button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isVerifying ? null : _verifyAndMarkAttendance,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
              child: _isVerifying
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Verify & Mark Attendance',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
            ),
          ),

          const SizedBox(height: 12),

          // Cancel Button
          TextButton(
            onPressed: _isVerifying ? null : () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Helper function to show the face verification prompt
void showFaceVerificationPrompt(
  BuildContext context,
  Map<String, dynamic> verificationData,
  Function() onComplete,
) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    enableDrag: false,
    backgroundColor: Colors.transparent,
    builder: (context) => FaceVerificationPrompt(
      verificationData: verificationData,
      onVerificationComplete: onComplete,
    ),
  );
}
