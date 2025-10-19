# Face SDK License Issue - Solution Guide

## ❌ Current Issue

The app is showing this error:
```
I/flutter (18522): ❌ FaceSDK initialization failed with code: -2
```

**Error Code -2 = License Expired**

## 🔍 Root Cause

The FaceSDK from KBY-AI uses time-limited trial licenses that have expired. The face recognition features will not work until you obtain a valid license.

## ✅ Solutions

### Option 1: Get a Free Trial License (Recommended)

Contact KBY-AI to get a new trial license for your app:

**Contact Information:**
- 📧 **Email:** contact@kby-ai.com
- 💬 **Telegram:** [@kbyaisupport](https://t.me/kbyaisupport)
- 📱 **WhatsApp:** [+19092802609](https://wa.me/+19092802609)
- 💭 **Discord:** [KBY-AI](https://discord.gg/CgHtWQ3k9T)

**What to mention when requesting:**
- You need a license for **Flutter Android app**
- Application ID: `com.example.smart_roll_call_flutter`
- Purpose: Attendance management system with face recognition
- Request a trial license for testing

### Option 2: Disable Face Recognition Temporarily

You can continue using the app without face recognition by modifying the code:

#### Step 1: Update `face_enrollment_service.dart`

Replace the `initialize()` method with a version that returns false without trying to activate:

```dart
Future<bool> initialize() async {
  if (_isInitialized) return true;
  
  print('⚠️ FaceSDK license expired. Please contact KBY-AI for a valid license.');
  print('📧 Email: contact@kby-ai.com');
  print('💬 Telegram: @kbyaisupport');
  
  _isInitialized = false;
  return false;
}
```

#### Step 2: Update `face_enrollment_screen.dart`

Show a license error message instead of enrollment screen:

```dart
@override
void initState() {
  super.initState();
  _showLicenseExpiredDialog();
}

void _showLicenseExpiredDialog() {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('License Expired'),
        content: const Text(
          'The Face Recognition SDK license has expired. '
          'Please contact KBY-AI to get a valid license:\n\n'
          'Email: contact@kby-ai.com\n'
          'Telegram: @kbyaisupport'
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Go back
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  });
}
```

#### Step 3: Update `face_recognition_prompt.dart`

Show clear message when verification is attempted:

```dart
Future<void> _verifyAndMarkAttendance() async {
  // Check SDK initialization
  if (!await _faceService.initialize()) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Face recognition is temporarily unavailable. '
            'License expired. Please contact admin.'
          ),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 5),
        ),
      );
    }
    return;
  }
  // ... rest of verification code
}
```

### Option 3: Use Manual Verification (No Face Recognition)

Comment out the face verification and allow manual attendance:

In `face_recognition_prompt.dart`, replace `_verifyAndMarkAttendance()` with:

```dart
Future<void> _verifyAndMarkAttendance() async {
  setState(() {
    _isVerifying = true;
  });

  try {
    final verificationId = widget.verificationData['verificationId'] as String;

    // Manual verification without face recognition
    print('✅ Manual verification for: $verificationId');

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
  } catch (e) {
    print('❌ Error marking attendance: $e');
    if (mounted) {
      setState(() {
        _isVerifying = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error marking attendance: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
```

## 📝 How to Get and Apply New License

### Step 1: Request License

Contact KBY-AI with these details:
- **App Package Name:** `com.example.smart_roll_call_flutter`
- **Platform:** Android
- **Purpose:** Educational attendance system

### Step 2: Receive License

They will send you a license string that looks like this:
```
"Os8QQO1k4+7MpzJ00bVHLv3UENK8YEB04ohoJsU29wwW1u4..."
```

### Step 3: Apply License

Update `lib/services/face_enrollment_service.dart`:

```dart
// Around line 20-30
if (Platform.isAndroid) {
  await _facesdkPlugin
      .setActivation("YOUR_NEW_LICENSE_KEY_HERE")
      .then((value) => facepluginState = value ?? -1);
}
```

### Step 4: Test

```bash
flutter clean
flutter pub get
flutter run
```

Check the logs for:
```
✅ FaceSDK initialized successfully
```

## 🚨 Understanding Error Codes

| Code | Meaning | Solution |
|------|---------|----------|
| -1 | Invalid license | Check license string format |
| -2 | License expired | Get new license from KBY-AI |
| -3 | Invalid license | License doesn't match app ID |
| -4 | Not activated | Call setActivation() first |
| -5 | Init error | Check SDK installation |
| 0 | Success | SDK is working! |

## 🎯 Quick Fix for Now

**To keep using your app without face recognition:**

1. Hide the "Enroll Face" card in student attendance screen
2. Make attendance marking work without face verification
3. Or use the app's other features (manual attendance, reports, etc.)

**I can help you implement any of these options!**

Just let me know which approach you prefer:
- **Option A:** Wait for new license and keep face recognition
- **Option B:** Disable face features temporarily  
- **Option C:** Remove face recognition and use manual verification only

## 💡 Alternative Solutions

If getting a license is difficult:

1. **Use a different face recognition library:**
   - Google ML Kit (free, but basic)
   - Microsoft Face API (paid)
   - AWS Rekognition (paid)

2. **Use simple photo verification:**
   - Student uploads photo
   - Professor manually verifies
   - No AI required

3. **Use QR code verification:**
   - Generate unique QR per student per class
   - Scan to mark attendance
   - Prevents proxy attendance

Let me know which solution you'd like to implement!
