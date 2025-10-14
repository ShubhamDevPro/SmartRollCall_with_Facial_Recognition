# Smart Roll Call - Integrated Attendance Management System

A fully integrated attendance management system that combines a Flutter mobile application with ESP32-based automatic attendance tracking. The system features complete Firebase Firestore integration, enabling seamless synchronization between manual attendance (via Flutter app) and automatic attendance (via ESP32 MAC address detection). Students register their device MAC addresses through the Flutter app, and the ESP32 automatically marks attendance when they connect to the class WiFi hotspot during scheduled class hours.

## ✅ Implementation Status

| Feature | Status | Description |
|---------|--------|-------------|
| Flutter App | ✅ Complete | Full attendance management with batches, students, schedules |
| Manual Attendance | ✅ Complete | Manual attendance marking via Flutter interface |
| Firebase Integration | ✅ Complete | Real-time sync with Firestore database |
| ESP32 Hardware | ✅ Complete | WiFi hotspot + device detection |
| ESP32 Firebase Integration | ✅ Complete | Direct REST API integration with Firestore |
| Schedule-Based Attendance | ✅ Complete | ESP32 loads and validates class schedules |
| MAC Address Registration | ✅ Complete | Students register devices via Flutter app |
| Automatic Attendance | ✅ Complete | ESP32 marks attendance when students connect |
| Duplicate Prevention | ✅ Complete | Smart checking prevents duplicate records |
| Real-time Sync | ✅ Complete | Instant updates between Flutter app and ESP32 |

## 🚀 Features

### Flutter Mobile Application
- **Authentication System**: Secure login and user management
- **Batch Management**: Create and manage different batches/classes
- **Manual Attendance**: Mark attendance manually with an intuitive interface
- **Student Management**: Add, edit, and manage student records
- **Attendance Dashboard**: Visual charts and statistics
- **Attendance History**: View and export attendance records
- **Excel Export**: Export attendance data to Excel files
- **Real-time Sync**: All data synchronized with Firebase in real-time

### ESP32 Automatic Attendance (✅ Fully Integrated!)
- **MAC Address Detection**: Automatically detect student devices when they connect to ESP32 WiFi hotspot
- **Firebase Integration**: Direct integration with Firebase Firestore database 
- **Schedule-Based Attendance**: Only marks attendance during active class schedules
- **Automatic Attendance Marking**: Mark attendance automatically based on device MAC addresses
- **Device Registration**: Students register their device MAC addresses in the Flutter app
- **Dual Tracking**: Support both manual and automatic attendance methods  
- **Real-time Updates**: Attendance marked by ESP32 appears immediately in Flutter app
- **Anti-Proxy System**: Each student registers their own device MAC address
- **Power Optimized**: CPU frequency and WiFi power optimizations for extended operation
- **Duplicate Prevention**: Smart checking to prevent duplicate attendance records

## 🏗️ System Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│  Flutter App    │    │   Firebase      │    │   ESP32 Module  │
│  (Manual Mode)  │◄──►│   Firestore     │◄──►│ (Auto Mode)     │
└─────────────────┘    └─────────────────┘    └─────────────────┘
        │                       │                       │
        │                       │                       │
   ┌─────────┐              ┌─────────┐              ┌─────────┐
   │Batches  │              │Students │              │Schedule │
   │Students │              │MAC Addr │              │Checker  │
   │Schedules│              │Records  │              │Detector │
   └─────────┘              └─────────┘              └─────────┘
```

### ✅ Fully Integrated System
- **Flutter App** ↔ **Firebase Firestore**: Manual attendance management with batch/schedule system
- **ESP32 Module** ↔ **Firebase Firestore**: Automatic attendance marking with schedule validation  
- **Student Device Registration**: MAC addresses stored in Firebase and synced to ESP32
- **Unified Attendance Records**: Both manual and automatic attendance in single `attendance_records` collection
- **Schedule Integration**: ESP32 loads class schedules and only marks attendance during active classes

## � Project Structure

```
SmartRollCall_with_Facial_Recognition/
├── ESP32_Actual_Current_Implementation.cpp  # ✅ Current ESP32 implementation (USE THIS)
├── lib/                                     # Flutter source code
│   ├── auth/                               # Authentication screens
│   │   ├── auth_page.dart                  # Authentication wrapper
│   │   ├── login_page.dart                 # Login interface
│   │   └── logout_page.dart                # Post-login home
│   ├── models/
│   │   ├── student.dart                    # Student data model (includes MAC address)
│   │   ├── attendance_record.dart          # Attendance data model
│   │   └── batch_schedule.dart             # Schedule data model
│   ├── screens/
│   │   ├── AttendanceScreen.dart           # Manual attendance marking
│   │   ├── attendance_dashboard.dart       # Analytics and charts
│   │   ├── homescreen.dart                 # Main dashboard
│   │   └── View-Edit History/              # Attendance history features
│   ├── services/
│   │   ├── auth_service.dart               # Firebase authentication
│   │   ├── firestore_service.dart          # Database operations
│   │   └── optimized_student_attendance_service.dart  # Student attendance queries
│   └── widgets/
│       ├── AddStudentModal.dart            # Student addition interface
│       └── batches.dart                    # Batch management widgets
├── android/                                # Android build configuration  
├── ios/                                    # iOS build configuration
├── pubspec.yaml                            # Flutter dependencies
├── firebase.json                           # Firebase project configuration
├── firestore_security_rules.rules          # Database security rules
└── README.md                               # Project documentation
```

### 📋 Key Files

- **`ESP32_Actual_Current_Implementation.cpp`**: Complete ESP32 code with Firebase integration
- **`lib/services/firestore_service.dart`**: Main Flutter-Firebase database interface  
- **`lib/models/student.dart`**: Student model including MAC address registration
- **`firestore_security_rules.rules`**: Firestore database access control

## 🔧 ESP32 Module (Current Implementation: `ESP32_Actual_Current_Implementation.cpp`)

### Hardware Requirements
- ESP32 Development Board (any variant)
- WiFi capability (built-in)
- Built-in LED (for status indication)

### ✅ Current Functionality  
- **Dual WiFi Mode**: Creates hotspot (AP mode) + connects to home WiFi (STA mode)
- **Schedule Integration**: Loads daily class schedules from Firebase automatically
- **Smart Detection**: Detects devices connecting to hotspot and matches with registered student MAC addresses
- **Firebase Integration**: Direct REST API integration with Firestore database
- **Attendance Validation**: Only marks attendance during active class schedules
- **Duplicate Prevention**: Checks for existing attendance records to prevent duplicates
- **Power Optimization**: CPU frequency reduction and WiFi power saving for extended operation
- **Automatic Time Sync**: NTP time synchronization for accurate timestamps
- **Real-time Monitoring**: Continuous device monitoring with automatic cleanup
- **LED Status Indication**: Built-in LED heartbeat for system status

### Configuration
- All credentials stored in `include/config.h` (not committed to Git)
- Configurable hotspot settings (SSID, password, channel)
- Timezone and NTP server configuration
- Customizable check intervals and power settings

## 🛠️ Technology Stack

### Flutter Application
- **Framework**: Flutter 3.5.3+
- **Database**: Firebase Firestore
- **Authentication**: Firebase Auth
- **State Management**: Provider/setState
- **Charts**: Syncfusion Flutter Charts
- **Export**: Excel package
- **Platform**: Cross-platform (Android, iOS, Web)

### ESP32 Module  
- **Platform**: Arduino IDE / PlatformIO
- **Microcontroller**: ESP32 (any variant)
- **Networking**: WiFi (AP + STA mode simultaneously)
- **Data Format**: JSON (Firestore REST API format)
- **Communication**: HTTPS with Firebase Firestore REST API
- **Libraries**: WiFi, ArduinoJson, HTTPClient, esp_wifi, time
- **Memory Management**: Dynamic vectors for device and schedule management
- **Power Management**: CPU frequency scaling and WiFi power optimization

### Backend Services
- **Database**: Firebase Firestore
- **Authentication**: Firebase Authentication
- **Storage**: Firebase Storage (for exports)
- **Real-time Updates**: Firestore real-time listeners

## 📋 Installation & Setup

### Prerequisites
- Flutter SDK (≥3.5.3)
- Android Studio / VS Code
- Firebase account
- Arduino IDE (for ESP32)
- ESP32 development board

### Flutter App Setup

1. **Clone the repository**
   ```bash
   git clone https://github.com/YourUsername/Smart_RollCall_Flutter.git
   cd Smart_RollCall_Flutter
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Firebase Configuration**
   - Create a new Firebase project
   - Enable Firestore Database and Authentication
   - Download `google-services.json` (Android) and `GoogleService-Info.plist` (iOS)
   - Place configuration files in respective platform directories
   - Update `firebase_options.dart` with your project configuration

4. **Run the application**
   ```bash
   flutter run
   ```

## 🔧 ESP32 Troubleshooting

### Common Issues & Solutions

#### 1. **Firebase Connection Issues**
- **Error**: "User not found (HTTP 404)" or "Authentication/Permission error"
- **Solution**: 
  - Verify `FIREBASE_USER_ID` in `config.h` matches your Firebase Auth User ID
  - Check Firebase API key is correct and has proper permissions
  - Ensure Firestore security rules allow read/write access

#### 2. **No Schedules Loaded**
- **Error**: "No classes scheduled for today"
- **Solution**:
  - Create batches and schedules in Flutter app first
  - Verify schedule `dayOfWeek` matches current day (e.g., "Monday")
  - Check schedules are marked as active (`isActive: true`)

#### 3. **Students Not Found**
- **Error**: "No student found with MAC address"
- **Solution**:
  - Students must register their device MAC addresses in the Flutter app
  - MAC addresses must match exactly (case-insensitive)
  - Ensure students are enrolled in the correct batch

#### 4. **WiFi Connection Problems**
- **Error**: "Failed to connect to home WiFi"
- **Solution**:
  - Verify `WIFI_SSID` and `WIFI_PASSWORD` in `config.h`
  - Check WiFi signal strength and network availability
  - ESP32 only supports 2.4GHz WiFi networks

#### 5. **Time Synchronization Issues**
- **Error**: "Failed to obtain time from NTP server"
- **Solution**:
  - Ensure internet connectivity via home WiFi
  - Check NTP server accessibility (default: `pool.ntp.org`)
  - Verify timezone settings in config

### Serial Monitor Output
Monitor the ESP32 serial output at 115200 baud for detailed logs:
- System initialization status
- Firebase connection and data loading
- Device detection and attendance marking
- Error descriptions and troubleshooting hints

### ESP32 Setup

1. **Install Arduino IDE**
   - Download and install Arduino IDE (1.8.19+ recommended)
   - Install ESP32 board package via Board Manager

2. **Install Required Libraries**
   ```
   - WiFi (built-in)
   - ArduinoJson (6.21.0+)
   - HTTPClient (built-in) 
   - esp_wifi (built-in)
   - time (built-in)
   ```

3. **Configuration Setup**
   - Copy `include/config.example.h` to `include/config.h`
   - Edit `include/config.h` with your credentials:
     - Firebase project ID, API key, and user ID
     - WiFi credentials (home WiFi for internet)
     - Hotspot settings (SSID, password for student devices)
     - Timezone and NTP server settings

4. **Upload to ESP32**
   - Open `ESP32_Actual_Current_Implementation.cpp` in Arduino IDE
   - Connect ESP32 to computer via USB
   - Select correct ESP32 board and COM port
   - Upload the code and monitor Serial output

5. **Verification**
   - Check Serial Monitor for initialization logs
   - Verify Firebase connection and schedule loading
   - Test hotspot creation and device detection

## � ESP32 Workflow

The ESP32 system follows this automated workflow:

1. **Initialization**
   - Apply power optimizations (80MHz CPU, WiFi power save)
   - Create WiFi hotspot for student devices
   - Connect to home WiFi for Firebase access
   - Sync time from NTP server

2. **Schedule Loading**
   - Load daily class schedules from Firebase
   - Filter schedules by current day of week
   - Maintain active schedule list

3. **Device Monitoring**
   - Continuously monitor hotspot connections
   - Detect new device MAC addresses
   - Identify students by registered MAC addresses

4. **Attendance Processing**
   - Check if current time matches any active schedule
   - Verify student is enrolled in the batch for current schedule
   - Mark attendance in Firebase `attendance_records` collection
   - Prevent duplicate attendance for same student/schedule/date

5. **Maintenance**
   - Periodic time synchronization
   - Schedule refresh (handles day changes)
   - Device cleanup (remove disconnected devices)
   - LED heartbeat for status indication

##  Database Schema

The system uses Firebase Firestore with the following collections:

### `users/{userId}/batches/{batchId}` - Batch Information
```json
{
  "batchName": "Computer Science A",
  "batchYear": "2024",
  "title": "CS-A Batch",
  "icon": "school",
  "createdAt": "2024-10-14T10:30:00Z"
}
```

### `users/{userId}/batches/{batchId}/students/{studentId}` - Student Records
```json
{
  "name": "John Doe",
  "enrollNumber": "CS2024001", 
  "macAddress": "AA:BB:CC:DD:EE:FF",  // ✅ Required for ESP32 integration
  "isPresent": false,
  "createdAt": "2024-10-14T10:30:00Z"
}
```

### `users/{userId}/batches/{batchId}/schedules/{scheduleId}` - Class Schedules
```json
{
  "dayOfWeek": "Monday",
  "startTime": "09:00",
  "endTime": "10:00", 
  "isActive": true,
  "createdAt": "2024-10-14T10:30:00Z"
}
```

### `attendance_records/{recordId}` - Unified Attendance (✅ Used by ESP32)
```json
{
  "studentId": "student_document_id",
  "batchId": "batch_document_id",
  "scheduleId": "schedule_document_id",
  "date": "2024-10-14T09:15:00Z",
  "isPresent": true,
  "markedBy": "ESP32",  // "manual" for Flutter app, "ESP32" for automatic
  "markedAt": "2024-10-14T09:15:30Z"
}
```

### Key Integration Points
- **MAC Address**: Stored in student records, used by ESP32 for device identification
- **Schedules**: ESP32 loads these to validate attendance timing  
- **Attendance Records**: Single collection for both manual and automatic attendance
- **User Isolation**: All data scoped under `users/{userId}` for multi-tenant support

## 🔄 System Status

### ✅ **FULLY INTEGRATED SYSTEM** 
The Smart Roll Call system is now complete with full integration between all components:

- **✅ Flutter App**: Complete attendance management with batches, students, and schedules
- **✅ ESP32 Module**: Fully integrated with Firebase, automatic attendance marking
- **✅ Firebase Integration**: Real-time synchronization between Flutter app and ESP32
- **✅ Automatic Attendance**: Schedule-based attendance marking with duplicate prevention
- **✅ Device Registration**: Students can register MAC addresses via Flutter app
- **✅ Unified Database**: Single attendance records collection for both manual and automatic attendance

### How It Works
1. **Setup**: Deploy ESP32 in classroom, configure with Firebase credentials
2. **Registration**: Students register their device MAC addresses through Flutter app
3. **Scheduling**: Create class schedules in Flutter app for different batches
4. **Automatic Operation**: ESP32 automatically marks attendance when students connect during scheduled class times
5. **Manual Override**: Teachers can still manually mark attendance via Flutter app
6. **Real-time Sync**: All attendance data instantly synchronized across both systems

### Phase 2: Database Integration 🚧
- Replace IFTTT with direct Firebase calls from ESP32
- Add MAC address field to student records
- Implement device registration in Flutter app

### Phase 3: Unified System 📋
- Real-time sync between manual and automatic attendance
- Conflict resolution (if both methods mark attendance)
- Enhanced reporting with attendance method tracking

### Phase 4: Advanced Features 🚀
- Multiple ESP32 modules for different locations
- Geofencing for attendance validation
- Advanced analytics and reporting
- Mobile app notifications for automatic attendance

## � Usage

### Setup Process
1. **Configure Firebase Project**
   - Create Firebase project with Firestore and Authentication
   - Deploy Flutter app with Firebase configuration
   - Note your Firebase User ID from Authentication section

2. **Deploy ESP32 Module**
   - Configure `include/config.h` with Firebase credentials and WiFi settings
   - Upload `ESP32_Actual_Current_Implementation.cpp` to ESP32
   - Verify Firebase connection via Serial Monitor

3. **Create Class Structure**
   - Login to Flutter app
   - Create batches (classes) with descriptive names
   - Add students to batches with enrollment numbers
   - Create class schedules with day, start time, and end time

### Daily Operation

#### **Automatic Attendance** ✅
1. ESP32 loads today's class schedules from Firebase
2. During scheduled class hours, ESP32 activates attendance detection
3. Students connect their devices to ESP32 WiFi hotspot
4. ESP32 matches device MAC addresses with registered students
5. Attendance automatically marked in Firebase
6. Real-time updates appear in Flutter app immediately

#### **Manual Attendance** (Traditional method)
1. Login to Flutter app
2. Select batch and navigate to attendance screen
3. Mark students present/absent manually
4. Save attendance record
5. Data synced to Firebase in real-time

### Student MAC Address Registration
1. Students provide their device MAC addresses to administrator
2. Administrator adds MAC addresses to student profiles in Flutter app
3. ESP32 automatically syncs with updated student data
4. Students connect to classroom WiFi for automatic attendance

### Monitoring & Reports
- View real-time attendance dashboard in Flutter app
- Export attendance data to Excel files
- Monitor ESP32 status via Serial output (115200 baud)
- Check Firebase console for attendance records

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/new-feature`)
3. Commit changes (`git commit -am 'Add new feature'`)
4. Push to branch (`git push origin feature/new-feature`)
5. Create Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE.md](Smart-Roll-Call-app-main/LICENSE.md) file for details.

## 🙋‍♂️ Support

For support and questions:
- Create an issue in the GitHub repository
- Check existing documentation
- Review the troubleshooting section

## 🔧 Troubleshooting

### Common Flutter Issues
- **Build errors**: Run `flutter clean` and `flutter pub get`
- **Firebase connection**: Verify configuration files and project settings
- **Permission errors**: Check platform-specific permissions in manifests

### ESP32 Issues
- **Upload failures**: Check board selection and USB connection
- **WiFi connection**: Verify credentials and network availability
- **Memory issues**: Optimize code and reduce memory usage

## 🚀 Future Enhancements

- Machine learning for attendance pattern analysis
- Face recognition integration
- Mobile app for teachers and students
- Integration with LMS systems
- Advanced security features
- Multi-language support
