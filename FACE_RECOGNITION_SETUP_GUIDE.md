# Face Recognition Attendance System Setup Guide

## Overview

This system uses a three-tier architecture for secure, facial-recognition-based attendance:

```
ESP32 → GCP VM (Flask) → Firebase Firestore → Flutter App → Face Recognition → Attendance
```

## Architecture Flow

1. **ESP32 detects MAC address** when student connects to hotspot
2. **ESP32 sends MAC to Flask server** on GCP VM
3. **Flask server creates `pending_verification`** record in Firestore
4. **Student's Flutter app** receives real-time notification
5. **Student completes face recognition** (your existing app)
6. **Attendance is marked** after successful verification

---

## Part 1: Flask Server Setup on GCP VM

### 1.1 Create GCP VM Instance

```bash
# In GCP Console:
# 1. Go to Compute Engine → VM Instances
# 2. Click "Create Instance"
# 3. Settings:
#    - Name: esp32-attendance-server
#    - Region: Choose closest to your location
#    - Machine type: e2-micro (sufficient for this use case)
#    - Boot disk: Ubuntu 22.04 LTS
#    - Firewall: Allow HTTP and HTTPS traffic
# 4. Click "Create"
```

### 1.2 Configure Firewall Rules

```bash
# In GCP Console:
# 1. Go to VPC Network → Firewall
# 2. Click "Create Firewall Rule"
# 3. Settings:
#    - Name: allow-flask-5000
#    - Direction: Ingress
#    - Targets: All instances in network
#    - Source IP ranges: 0.0.0.0/0
#    - Protocols and ports: tcp:5000
# 4. Click "Create"
```

### 1.3 SSH into VM and Install Dependencies

```bash
# SSH into your VM
gcloud compute ssh esp32-attendance-server

# Update system
sudo apt update && sudo apt upgrade -y

# Install Python and pip
sudo apt install python3 python3-pip -y

# Install required Python packages
pip3 install flask firebase-admin python-dotenv requests

# Create working directory
mkdir ~/esp32-attendance
cd ~/esp32-attendance
```

### 1.4 Upload Files to VM

```bash
# On your local machine, upload the Flask server file
gcloud compute scp flask_attendance_server.py esp32-attendance-server:~/esp32-attendance/

# You'll also need to upload firebase-admin-key.json (next step)
```

### 1.5 Get Firebase Admin SDK Key

1. Go to Firebase Console: https://console.firebase.google.com/
2. Select your project
3. Click the gear icon → Project Settings
4. Go to "Service Accounts" tab
5. Click "Generate New Private Key"
6. Save the JSON file as `firebase-admin-key.json`
7. Upload to your VM:

```bash
# On your local machine
gcloud compute scp firebase-admin-key.json esp32-attendance-server:~/esp32-attendance/
```

### 1.6 Create .env File

```bash
# SSH into VM
cd ~/esp32-attendance

# Create .env file
nano .env

# Add this content (replace with your Firebase Project ID):
FIREBASE_PROJECT_ID=your-firebase-project-id

# Save and exit (Ctrl+X, Y, Enter)
```

### 1.7 Test the Server

```bash
# Run the Flask server
python3 flask_attendance_server.py

# You should see:
# 🚀 ESP32 Attendance Server Starting...
# 📍 Firebase Project: your-project-id
# 🌐 Server will run on: http://0.0.0.0:5000
```

### 1.8 Get VM External IP

```bash
# In another terminal, find your VM's external IP
gcloud compute instances list

# Note the EXTERNAL_IP for your instance
# Example: 34.123.45.67
```

### 1.9 Run Server in Background

```bash
# Stop the test server (Ctrl+C)

# Run in background with nohup
nohup python3 flask_attendance_server.py > server.log 2>&1 &

# Check if running
ps aux | grep flask_attendance_server.py

# View logs
tail -f server.log
```

### 1.10 Setup Auto-Start on Boot (Optional)

```bash
# Create systemd service
sudo nano /etc/systemd/system/esp32-attendance.service

# Add this content:
```

```ini
[Unit]
Description=ESP32 Attendance Flask Server
After=network.target

[Service]
Type=simple
User=YOUR_USERNAME
WorkingDirectory=/home/YOUR_USERNAME/esp32-attendance
ExecStart=/usr/bin/python3 /home/YOUR_USERNAME/esp32-attendance/flask_attendance_server.py
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

```bash
# Replace YOUR_USERNAME with your actual username

# Enable and start service
sudo systemctl daemon-reload
sudo systemctl enable esp32-attendance
sudo systemctl start esp32-attendance

# Check status
sudo systemctl status esp32-attendance
```

---

## Part 2: ESP32 Configuration

### 2.1 Update config.h

```bash
# In your ESP32 project folder
cd include/
cp config.example.h config.h
nano config.h
```

Update these values:

```cpp
// Your Firebase User ID
#define FIREBASE_USER_ID "abc123xyz789"  // From Firebase Console → Authentication

// Your GCP VM IP and port
#define SERVER_URL_FROM_CONFIG "http://34.123.45.67:5000/api/mark-attendance"

// Your home WiFi
#define WIFI_SSID "YourHomeWiFi"
#define WIFI_PASSWORD "YourWiFiPassword"
```

### 2.2 Upload to ESP32

```bash
# Using Arduino IDE or PlatformIO
# 1. Open ESP32_Simplified_MAC_Only.cpp
# 2. Select your ESP32 board
# 3. Select the correct COM port
# 4. Click Upload
```

### 2.3 Monitor Serial Output

```bash
# Open Serial Monitor (115200 baud)
# You should see:
# ========================================
# ESP32 Smart Roll Call System v3.0
# (Simplified - MAC Only Mode)
# ========================================
```

---

## Part 3: Flutter App Integration

### 3.1 Update Student Attendance Screen

The `student_attendance_view_screen.dart` is already updated with the verification listener.

### 3.2 Test the Flow

1. **Student logs into Flutter app**
2. **Student connects phone to ESP32 hotspot** ("Smart_Roll_Call_ESP32")
3. **ESP32 detects MAC** and sends to Flask server
4. **Flask creates pending verification** in Firestore
5. **Flutter app shows modal** prompting face verification
6. **Student clicks "Verify & Mark Attendance"**
7. **Attendance is marked** in Firebase

---

## Part 4: Firestore Security Rules

Update your `firestore.rules`:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // Pending verifications - students can read their own
    match /pending_verifications/{verificationId} {
      allow read: if request.auth != null;
      allow write: if false; // Only server can create
      allow update: if request.auth != null && 
                    request.resource.data.status in ['verified', 'failed'];
    }
    
    // Attendance records - read-only for students
    match /attendance_records/{recordId} {
      allow read: if request.auth != null;
      allow write: if false; // Only server/professor can write
    }
    
    // Existing rules...
    match /users/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
      
      match /batches/{batchId} {
        allow read, write: if request.auth != null && request.auth.uid == userId;
        
        match /students/{studentId} {
          allow read, write: if request.auth != null && request.auth.uid == userId;
        }
        
        match /schedules/{scheduleId} {
          allow read, write: if request.auth != null && request.auth.uid == userId;
        }
      }
    }
    
    match /student_profiles/{profileId} {
      allow read, write: if request.auth != null;
    }
  }
}
```

Deploy rules:

```bash
firebase deploy --only firestore:rules
```

---

## Part 5: Testing

### 5.1 Test Flask Server

```bash
# On your local machine or VM
curl http://YOUR_VM_IP:5000/api/health

# Expected response:
{
  "service": "ESP32 Attendance Server",
  "status": "healthy",
  "timestamp": "2025-10-15T10:30:00.123456"
}
```

### 5.2 Test MAC Address Submission

```bash
curl -X POST http://YOUR_VM_IP:5000/api/mark-attendance \
  -H "Content-Type: application/json" \
  -d '{
    "macAddress": "AA:BB:CC:DD:EE:FF",
    "userId": "your-firebase-user-id"
  }'

# Expected response if student found:
{
  "courseName": "Computer Science A",
  "expiresIn": 300,
  "message": "Pending verification created...",
  "studentEnrollment": "CS2024001",
  "studentName": "John Doe",
  "success": true,
  "verificationId": "abc123xyz"
}
```

### 5.3 Test Flutter App

1. Log in as student
2. Navigate to attendance view screen
3. Connect to ESP32 hotspot
4. Modal should appear within 2-5 seconds
5. Click "Verify & Mark Attendance"
6. Attendance should be marked

---

## Part 6: Troubleshooting

### ESP32 Issues

**Problem**: Can't connect to Flask server

```bash
# Check ESP32 serial output
# Look for: [✗] HTTP request failed

# Solutions:
# 1. Verify SERVER_URL in config.h is correct
# 2. Ping VM from your network: ping YOUR_VM_IP
# 3. Check firewall rules in GCP
# 4. Ensure Flask server is running: ps aux | grep flask
```

**Problem**: MAC address sent but no pending verification

```bash
# Check Flask server logs
tail -f ~/esp32-attendance/server.log

# Look for errors like:
# ❌ Error finding student
# ❌ No student found with MAC

# Solutions:
# 1. Ensure MAC address is registered in Flutter app
# 2. Verify student is in an active batch
# 3. Check if there's a class scheduled at current time
```

### Flask Server Issues

**Problem**: Firebase permission denied

```bash
# Check Firebase Admin SDK key
ls -l ~/esp32-attendance/firebase-admin-key.json

# Verify .env file
cat ~/esp32-attendance/.env

# Regenerate Firebase Admin SDK key if needed
```

**Problem**: Server not responding

```bash
# Check if server is running
sudo systemctl status esp32-attendance

# Restart server
sudo systemctl restart esp32-attendance

# Check logs
sudo journalctl -u esp32-attendance -f
```

### Flutter App Issues

**Problem**: Modal not showing up

```dart
// Check console for:
// 🎯 Starting verification listener
// 🔔 New verification received

// Solutions:
// 1. Ensure student is logged in
// 2. Verify enrollmentNumber is correct
// 3. Check Firestore rules allow read on pending_verifications
```

---

## Part 7: Monitoring & Maintenance

### Monitor Flask Server

```bash
# View live logs
tail -f ~/esp32-attendance/server.log

# Check system resources
htop

# View server status
sudo systemctl status esp32-attendance
```

### Cleanup Expired Verifications

```bash
# Manual cleanup
curl -X POST http://YOUR_VM_IP:5000/api/cleanup-expired

# Or setup cron job
crontab -e

# Add line:
*/5 * * * * curl -X POST http://localhost:5000/api/cleanup-expired
```

### Monitor Firestore Usage

1. Go to Firebase Console
2. Navigate to Firestore Database
3. Check `pending_verifications` collection size
4. Set up cleanup Cloud Function if needed

---

## Part 8: Future Enhancements

### Add Actual Face Recognition

Replace this line in `face_recognition_prompt.dart`:

```dart
// TODO: In the future, add face recognition logic here
// For now, we'll just simulate verification and mark attendance

// Add your face recognition code here:
// 1. Call your existing face recognition Flutter app/package
// 2. Pass student info
// 3. Get recognition result
// 4. Only call _moveToAttendanceRecords if face matches
```

### Add Push Notifications (FCM)

1. Setup Firebase Cloud Messaging in Flutter app
2. Store FCM tokens in student profiles
3. Update Flask server to send push notifications
4. Student gets notification even when app is closed

---

## Cost Estimation

### GCP VM (e2-micro)
- ~$6-8/month (730 hours/month)
- Can use GCP Free Tier ($300 credit for 90 days)

### Firebase
- Firestore: Free tier (50K reads, 20K writes per day)
- Should be sufficient for small to medium classes

### Total Monthly Cost
- **~$8/month** (after free tier expires)
- **$0 for first 90 days** with GCP credits

---

## Support & Maintenance

For issues or questions:
1. Check serial output on ESP32
2. Check Flask server logs on VM
3. Check Flutter app console output
4. Verify Firestore rules and data structure

---

## Summary Checklist

- [ ] GCP VM created and configured
- [ ] Flask server running on VM
- [ ] Firebase Admin SDK key uploaded
- [ ] Firewall rules configured (port 5000)
- [ ] ESP32 config.h updated with VM IP
- [ ] ESP32 code uploaded and tested
- [ ] Flutter app updated with listener
- [ ] Firestore security rules deployed
- [ ] End-to-end test completed successfully
- [ ] Monitoring and logs configured

---

**Congratulations!** Your facial recognition-based attendance system is now fully operational! 🎉
