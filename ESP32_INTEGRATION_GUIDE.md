# ESP32 Firebase Integration Setup Guide

This guide explains how to set up the ESP32 integration with your Smart Roll Call Flutter app using Firebase instead of IFTTT.

## Overview

The new system works as follows:
1. Students register their MAC addresses in the Flutter app when added to a batch
2. ESP32 creates a WiFi hotspot for students to connect to
3. When a student's device connects, ESP32 detects the MAC address
4. ESP32 queries Firebase to find the student with that MAC address
5. ESP32 automatically marks attendance in Firebase
6. Flutter app shows updated attendance in real-time

## Flutter App Changes

### New Features Added:
- MAC address field in student registration (optional)
- Firestore methods to find students by MAC address
- Automatic attendance marking via ESP32
- HTTP server option for ESP32 communication

### Files Modified:
- `lib/models/student.dart` - Added macAddress field
- `lib/widgets/AddStudentModal.dart` - Added MAC address input
- `lib/services/firestore_service.dart` - Added ESP32 integration methods
- `lib/services/esp32_server.dart` - Optional HTTP server for ESP32

## ESP32 Setup

### Hardware Requirements:
- ESP32 development board
- USB cable for programming
- WiFi internet connection
- LED indicator (built-in LED works)

### Software Requirements:
- Arduino IDE with ESP32 board support
- Required libraries:
  - WiFi
  - HTTPClient  
  - ArduinoJson
  - WiFiClientSecure

### Installation:

1. **Install ESP32 Board Support:**
   - Open Arduino IDE
   - Go to File → Preferences
   - Add this URL to Additional Board Manager URLs:
     ```
     https://dl.espressif.com/dl/package_esp32_index.json
     ```
   - Go to Tools → Board → Board Manager
   - Search for "ESP32" and install

2. **Install Required Libraries:**
   - Go to Sketch → Include Library → Manage Libraries
   - Install: ArduinoJson, WiFiClientSecure

3. **Upload Code:**
   - Use either `esp32_firebase_integration.ino` (direct Firebase) or `esp32_server_integration.ino` (via HTTP server)
   - Update configuration variables in the code:
     ```cpp
     // For direct Firebase integration:
     const char* FIREBASE_PROJECT_ID = "smart-roll-call-37be0";
     const char* FIREBASE_API_KEY = "your-api-key";
     
     // For HTTP server integration:
     const char* FLUTTER_SERVER_IP = "192.168.1.100";
     ```

## Configuration

### Firebase Configuration:
1. **Update API Key:**
   - Get your Firebase Web API key from Firebase Console
   - Update `FIREBASE_API_KEY` in ESP32 code

2. **Set WiFi Credentials:**
   ```cpp
   const char* wifi_network_ssid = "YOUR_WIFI_NAME";
   const char* wifi_network_password = "YOUR_WIFI_PASSWORD";
   ```

3. **Customize Hotspot:**
   ```cpp
   const char* ssid = "Smart_Roll_Call_ESP32";
   const char* password = "attendance123";
   ```

### Student Registration:
1. Open Flutter app
2. Create or edit a batch
3. Add students with their MAC addresses
4. To find MAC address on mobile devices:
   - **Android:** Settings → About Phone → Status → WiFi MAC Address
   - **iOS:** Settings → General → About → WiFi Address

## Usage

### Starting the System:
1. Power on ESP32 (it will create a WiFi hotspot)
2. Open Flutter app
3. Students connect their devices to the ESP32 hotspot
4. Attendance is automatically marked when devices connect

### LED Indicators:
- **Slow blink:** ESP32 connected to internet
- **Fast 5 blinks:** Attendance marked successfully
- **Solid on:** Device connection detected

### Serial Monitor Output:
```
[*] Creating AP for Smart Roll Call
[+] AP Created with IP Gateway 192.168.4.1
[+] Connected to internet with IP: 192.168.1.123
-----------
[+] Device 0 | MAC: AA:BB:CC:DD:EE:FF | IP: 192.168.4.2
📱 Student found: John Doe (12345)
✅ Attendance marked successfully!
```

## Troubleshooting

### Common Issues:

1. **ESP32 can't connect to internet:**
   - Check WiFi credentials
   - Ensure WiFi network is available
   - Try different WiFi network

2. **Student not found:**
   - Verify MAC address is correctly entered in Flutter app
   - Check MAC address format (AA:BB:CC:DD:EE:FF)
   - Ensure student is in a batch

3. **Firebase access denied:**
   - Check Firebase API key
   - Verify Firebase security rules
   - Ensure project ID is correct

4. **Attendance not marking:**
   - Check internet connection
   - Verify Firebase project configuration
   - Check serial monitor for error messages

### Debug Mode:
- Open Serial Monitor in Arduino IDE (115200 baud)
- Watch for connection and Firebase interaction logs
- Check error messages for troubleshooting

## Security Considerations

1. **WiFi Security:**
   - Use WPA2 password protection on ESP32 hotspot
   - Regularly change hotspot password

2. **Firebase Security:**
   - Implement proper Firestore security rules
   - Use API key restrictions in Firebase console
   - Monitor Firebase usage for unusual activity

3. **MAC Address Privacy:**
   - MAC addresses are only visible to administrators
   - Students cannot see other students' MAC addresses
   - Consider MAC address randomization on newer devices

## Architecture Options

### Option 1: Direct Firebase (Recommended)
- ESP32 directly calls Firebase REST API
- More efficient, fewer dependencies
- Use `esp32_firebase_integration.ino`

### Option 2: HTTP Server
- ESP32 calls Flutter app HTTP server
- Flutter app handles Firebase operations
- Use `esp32_server_integration.ino` + `esp32_server.dart`
- Requires Flutter app to be running with server enabled

## Maintenance

### Regular Tasks:
- Monitor ESP32 power and connectivity
- Update student MAC addresses as needed
- Check Firebase usage and costs
- Review attendance logs for accuracy

### Updates:
- Keep ESP32 firmware updated
- Update Firebase API keys if rotated
- Sync new student registrations with ESP32

## FAQ

**Q: Can multiple ESP32 devices be used?**
A: Yes, multiple ESP32 devices can connect to the same Firebase project and mark attendance independently.

**Q: What happens if a student has multiple devices?**
A: Register all MAC addresses for the student. The first device to connect will mark attendance.

**Q: How accurate is MAC address detection?**
A: Very accurate, but some modern devices use MAC randomization for privacy.

**Q: Can the system work offline?**
A: ESP32 needs internet for Firebase access. Offline mode would require local storage and later sync.

**Q: How many students can one ESP32 handle?**
A: The current configuration supports up to 20 simultaneous connections.