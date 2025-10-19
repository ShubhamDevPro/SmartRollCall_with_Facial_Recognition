import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_exif_rotation/flutter_exif_rotation.dart';
import 'dart:io';
import '../../services/face_enrollment_service.dart';

/// Screen for students to enroll their face for attendance verification
class FaceEnrollmentScreen extends StatefulWidget {
  final String enrollmentNumber;
  final String studentName;

  const FaceEnrollmentScreen({
    Key? key,
    required this.enrollmentNumber,
    required this.studentName,
  }) : super(key: key);

  @override
  State<FaceEnrollmentScreen> createState() => _FaceEnrollmentScreenState();
}

class _FaceEnrollmentScreenState extends State<FaceEnrollmentScreen> {
  final FaceEnrollmentService _enrollmentService = FaceEnrollmentService();
  bool _isProcessing = false;
  File? _selectedImage;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _initializeFaceSDK();
  }

  Future<void> _initializeFaceSDK() async {
    setState(() {
      _statusMessage = 'Initializing face recognition...';
    });

    final initialized = await _enrollmentService.initialize();

    setState(() {
      if (initialized) {
        _statusMessage = 'Ready to capture your face';
      } else {
        _statusMessage =
            'Failed to initialize face recognition. Please try again.';
      }
    });
  }

  Future<void> _captureImage(ImageSource source) async {
    try {
      setState(() {
        _isProcessing = true;
        _statusMessage = 'Capturing image...';
      });

      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        preferredCameraDevice: CameraDevice.front,
        imageQuality: 90,
      );

      if (image == null) {
        setState(() {
          _isProcessing = false;
          _statusMessage = 'Image capture cancelled';
        });
        return;
      }

      // Rotate image if needed
      final rotatedImage =
          await FlutterExifRotation.rotateImage(path: image.path);

      setState(() {
        _selectedImage = File(rotatedImage.path);
        _statusMessage = 'Image captured. Processing...';
      });

      // Process the image
      await _processImage(rotatedImage.path);
    } catch (e) {
      print('❌ Error capturing image: $e');
      setState(() {
        _isProcessing = false;
        _statusMessage = 'Error capturing image: ${e.toString()}';
      });
    }
  }

  Future<void> _processImage(String imagePath) async {
    try {
      setState(() {
        _statusMessage = 'Detecting face...';
      });

      // Enroll the face
      final success = await _enrollmentService.enrollFace(
        enrollmentNumber: widget.enrollmentNumber,
        imagePath: imagePath,
      );

      if (success) {
        setState(() {
          _isProcessing = false;
          _statusMessage = 'Face enrolled successfully! ✅';
        });

        // Show success dialog
        if (mounted) {
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 32),
                  SizedBox(width: 12),
                  Text('Success!'),
                ],
              ),
              content: const Text(
                'Your face has been enrolled successfully. You can now use face verification for attendance.',
              ),
              actions: [
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context); // Close dialog
                    Navigator.pop(context,
                        true); // Return to previous screen with success
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Done'),
                ),
              ],
            ),
          );
        }
      } else {
        setState(() {
          _isProcessing = false;
          _statusMessage =
              'Failed to enroll face. Please try again with a clear face photo.';
        });
      }
    } catch (e) {
      print('❌ Error processing image: $e');
      setState(() {
        _isProcessing = false;
        _statusMessage = 'Error processing image: ${e.toString()}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Enroll Your Face',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.deepPurple,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Student Info Card
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.deepPurple,
                      child: Icon(
                        Icons.person,
                        size: 50,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      widget.studentName,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Enrollment: ${widget.enrollmentNumber}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Instructions Card
            Card(
              color: Colors.blue.shade50,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue.shade700),
                        const SizedBox(width: 8),
                        Text(
                          'Instructions',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '• Face the camera directly\n'
                      '• Ensure good lighting\n'
                      '• Remove glasses if possible\n'
                      '• Keep a neutral expression\n'
                      '• Only your face should be visible',
                      style: TextStyle(fontSize: 14, height: 1.5),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Image Preview
            if (_selectedImage != null)
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    _selectedImage!,
                    height: 300,
                    fit: BoxFit.cover,
                  ),
                ),
              ),

            const SizedBox(height: 24),

            // Status Message
            if (_statusMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _statusMessage!.contains('successfully')
                      ? Colors.green.shade50
                      : _statusMessage!.contains('Error') ||
                              _statusMessage!.contains('Failed')
                          ? Colors.red.shade50
                          : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      _statusMessage!.contains('successfully')
                          ? Icons.check_circle
                          : _statusMessage!.contains('Error') ||
                                  _statusMessage!.contains('Failed')
                              ? Icons.error
                              : Icons.info,
                      color: _statusMessage!.contains('successfully')
                          ? Colors.green
                          : _statusMessage!.contains('Error') ||
                                  _statusMessage!.contains('Failed')
                              ? Colors.red
                              : Colors.orange,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _statusMessage!,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 24),

            // Capture Buttons
            if (!_isProcessing) ...[
              SizedBox(
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: () => _captureImage(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Capture from Camera'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: () => _captureImage(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Choose from Gallery'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.deepPurple,
                    side: const BorderSide(color: Colors.deepPurple),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ] else
              const Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 12),
                    Text(
                      'Processing...',
                      style: TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
