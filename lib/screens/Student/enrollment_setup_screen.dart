import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'student_attendance_view_screen.dart';

/// Screen to capture enrollment number for first-time student login
class EnrollmentSetupScreen extends StatefulWidget {
  final String studentEmail;
  final String studentName;

  const EnrollmentSetupScreen({
    super.key,
    required this.studentEmail,
    required this.studentName,
  });

  @override
  State<EnrollmentSetupScreen> createState() => _EnrollmentSetupScreenState();
}

class _EnrollmentSetupScreenState extends State<EnrollmentSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _enrollmentController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _enrollmentController.dispose();
    super.dispose();
  }

  Future<void> _saveEnrollmentNumber() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      
      // Use email as document ID (sanitized)
      final docId = widget.studentEmail.replaceAll('.', '_').replaceAll('@', '_at_');

      // Save enrollment number in student_profiles collection
      await FirebaseFirestore.instance
          .collection('student_profiles')
          .doc(docId)
          .set({
        'enrollmentNumber': _enrollmentController.text.trim().toUpperCase(),
        'email': widget.studentEmail,
        'name': widget.studentName,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      // Navigate to student attendance view
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => StudentAttendanceViewScreen(
            studentEmail: widget.studentEmail,
            studentName: widget.studentName,
            enrollmentNumber: _enrollmentController.text.trim().toUpperCase(),
          ),
        ),
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving enrollment number: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Setup Your Profile',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.blue.shade700,
        automaticallyImplyLeading: false,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.blue.shade50,
              Colors.white,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Icon
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.blue.shade700,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.shade200,
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.person_add,
                      size: 60,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Welcome Text
                  Text(
                    'Welcome, ${widget.studentName}!',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade800,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),

                  Text(
                    'Please enter your enrollment number to continue',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 48),

                  // Form Card
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 15,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Enrollment Number Field
                          TextFormField(
                            controller: _enrollmentController,
                            decoration: InputDecoration(
                              labelText: 'Enrollment Number',
                              hintText: 'e.g., 01919051722',
                              prefixIcon: Icon(
                                Icons.badge,
                                color: Colors.blue.shade700,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide:
                                    BorderSide(color: Colors.blue.shade200),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                    color: Colors.blue.shade700, width: 2),
                              ),
                            ),
                            textCapitalization: TextCapitalization.characters,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter your enrollment number';
                              }
                              if (value.trim().length < 3) {
                                return 'Enrollment number is too short';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 24),

                          // Info Card
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.blue.shade200),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  color: Colors.blue.shade700,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'This information is required to fetch your attendance records',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.blue.shade900,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Submit Button
                          SizedBox(
                            height: 56,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _saveEnrollmentNumber,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue.shade700,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 3,
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 24,
                                      width: 24,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text(
                                      'Continue',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
