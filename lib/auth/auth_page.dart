import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/session_service.dart';
import '../screens/Professor/homescreen.dart';
import 'login_page.dart';

// AuthPage handles the authentication state and decides which page to show
class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> with WidgetsBindingObserver {
  final SessionService _sessionService = SessionService();
  bool _isCheckingSession = true;
  bool _isAuthenticated = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkSession();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Update activity when app becomes active
    if (state == AppLifecycleState.resumed) {
      _sessionService.updateActivity();
    }
  }

  Future<void> _checkSession() async {
    try {
      // Check if user has a valid session
      final hasValidSession = await _sessionService.isSessionValid();
      final user = FirebaseAuth.instance.currentUser;

      setState(() {
        _isAuthenticated = hasValidSession && user != null;
        _isCheckingSession = false;
      });
    } catch (e) {
      print('Error checking session: $e');
      setState(() {
        _isAuthenticated = false;
        _isCheckingSession = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingSession) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      body: _isAuthenticated ? MyHomePage() : LoginPage(),
    );
  }
}
