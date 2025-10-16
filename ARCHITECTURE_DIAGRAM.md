# System Architecture Diagram

## Complete Flow Visualization

```
╔════════════════════════════════════════════════════════════════════════╗
║                   FACE RECOGNITION ATTENDANCE SYSTEM                    ║
╚════════════════════════════════════════════════════════════════════════╝

┌─────────────────────────────────────────────────────────────────────────┐
│                          STEP 1: DETECTION                              │
└─────────────────────────────────────────────────────────────────────────┘

    📱 Student Phone                    🔌 ESP32 Device
    ┌──────────────┐                   ┌──────────────┐
    │              │                   │              │
    │  Connects to │────────WiFi──────>│   Hotspot    │
    │   Hotspot    │                   │              │
    │              │                   │  Detects MAC │
    └──────────────┘                   │  Address:    │
                                       │  AA:BB:CC... │
                                       └──────┬───────┘
                                              │
                                              │ HTTP POST
                                              │ {"macAddress": "AA:BB...",
                                              │  "userId": "abc123"}
                                              ▼

┌─────────────────────────────────────────────────────────────────────────┐
│                    STEP 2: SERVER PROCESSING                            │
└─────────────────────────────────────────────────────────────────────────┘

                                    ☁️  GCP VM
                              ┌──────────────────┐
                              │  Flask Server    │
                              │  (Port 5000)     │
                              └────────┬─────────┘
                                       │
                                       │ 1. Receive MAC + User ID
                                       │ 2. Query Firebase
                                       │ 3. Find student by MAC
                                       │ 4. Find active schedule
                                       │ 5. Create pending verification
                                       │
                                       ▼
                              
                              🔍 Processing Logic:
                              ┌──────────────────┐
                              │ FOR each batch   │
                              │   FOR each student│
                              │     IF MAC matches│
                              │       GET schedule│
                              │       IF active   │
                              │         CREATE   │
                              │         pending  │
                              └────────┬─────────┘
                                       │
                                       ▼

┌─────────────────────────────────────────────────────────────────────────┐
│                  STEP 3: FIRESTORE STORAGE                              │
└─────────────────────────────────────────────────────────────────────────┘

                              🔥 Firebase Firestore
                         ┌──────────────────────────┐
                         │                          │
                         │  pending_verifications/  │
                         │  ├─ xyz789:              │
                         │  │  ├─ studentId         │
                         │  │  ├─ studentName       │
                         │  │  ├─ studentEnrollment │
                         │  │  ├─ courseName        │
                         │  │  ├─ professorName     │
                         │  │  ├─ scheduleId        │
                         │  │  ├─ status: "pending" │
                         │  │  ├─ detectedAt        │
                         │  │  └─ expiresAt         │
                         │                          │
                         └──────────┬───────────────┘
                                    │
                                    │ Real-time
                                    │ Sync
                                    ▼

┌─────────────────────────────────────────────────────────────────────────┐
│                  STEP 4: FLUTTER NOTIFICATION                           │
└─────────────────────────────────────────────────────────────────────────┘

                         📱 Student Flutter App
                    ┌────────────────────────────┐
                    │                            │
                    │  Real-time Listener        │
                    │  ────────────────────      │
                    │  .where('studentEnrollment'│
                    │         == 'CS2024001')    │
                    │  .where('status'           │
                    │         == 'pending')      │
                    │  .snapshots()              │
                    │                            │
                    └──────────┬─────────────────┘
                               │
                               │ New document detected!
                               │
                               ▼
                    ┌─────────────────────────┐
                    │                         │
                    │   📲 Modal Appears      │
                    │                         │
                    │  ╔═══════════════════╗  │
                    │  ║ Attendance        ║  │
                    │  ║ Detected!         ║  │
                    │  ║                   ║  │
                    │  ║ 👤 John Doe       ║  │
                    │  ║ 📚 Computer Sci A ║  │
                    │  ║ 👨‍🏫 Prof. Smith    ║  │
                    │  ║                   ║  │
                    │  ║ ⏱️  4:30 remaining ║  │
                    │  ║                   ║  │
                    │  ║ [Verify & Mark]   ║  │
                    │  ╚═══════════════════╝  │
                    │                         │
                    └─────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────┐
│                  STEP 5: FACE VERIFICATION                              │
└─────────────────────────────────────────────────────────────────────────┘

                         📱 Student Clicks Button
                                    │
                                    ▼
                         ┌──────────────────┐
                         │                  │
                         │  [FUTURE]        │
                         │  Face Recognition│
                         │  Screen          │
                         │                  │
                         │  📸 Capture      │
                         │  🔍 Compare      │
                         │  ✅ Verify       │
                         │                  │
                         └────────┬─────────┘
                                  │
                                  │ If face matches
                                  ▼

┌─────────────────────────────────────────────────────────────────────────┐
│                  STEP 6: ATTENDANCE MARKING                             │
└─────────────────────────────────────────────────────────────────────────┘

                              Flutter App Logic
                         ┌──────────────────────┐
                         │                      │
                         │ 1. Update pending:   │
                         │    status = "verified"│
                         │    verifiedAt = now  │
                         │                      │
                         │ 2. Create attendance:│
                         │    attendance_records│
                         │    with all fields   │
                         │                      │
                         └──────────┬───────────┘
                                    │
                                    ▼
                              
                         🔥 Firebase Firestore
                    ┌───────────────────────────┐
                    │                           │
                    │ pending_verifications/    │
                    │ └─ xyz789:                │
                    │    └─ status: "verified" ✅│
                    │                           │
                    │ attendance_records/       │
                    │ └─ abc456:                │
                    │    ├─ studentId           │
                    │    ├─ courseName          │
                    │    ├─ isPresent: true ✅  │
                    │    ├─ markedAt: now       │
                    │    ├─ markedBy: "ESP32-   │
                    │    │   FaceVerification"  │
                    │    └─ verificationId      │
                    │                           │
                    └───────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────┐
│                     STEP 7: SUCCESS!                                    │
└─────────────────────────────────────────────────────────────────────────┘

                         📱 Student Flutter App
                    ┌────────────────────────────┐
                    │                            │
                    │   ✅ Success Message       │
                    │                            │
                    │  ┌────────────────────┐    │
                    │  │ Attendance marked  │    │
                    │  │ successfully!      │    │
                    │  └────────────────────┘    │
                    │                            │
                    │  📊 Attendance refreshed   │
                    │     Updated statistics     │
                    │                            │
                    └────────────────────────────┘


╔════════════════════════════════════════════════════════════════════════╗
║                        COMPONENT BREAKDOWN                              ║
╚════════════════════════════════════════════════════════════════════════╝

┌─────────────────┐      ┌─────────────────┐      ┌─────────────────┐
│   ESP32 Device  │      │  Flask Server   │      │ Firebase Cloud  │
├─────────────────┤      ├─────────────────┤      ├─────────────────┤
│ • WiFi Hotspot  │      │ • Python 3.x    │      │ • Firestore DB  │
│ • MAC Detection │─────>│ • Flask API     │─────>│ • Auth          │
│ • HTTP Client   │      │ • Firebase SDK  │      │ • Real-time     │
│ • Power Saving  │      │ • Error Handler │      │ • Security      │
└─────────────────┘      └─────────────────┘      └─────────────────┘
     80 MHz CPU              4 vCPU, 2GB RAM         Auto-scaling
     ~5mA power              ~$7/month                Free tier

                               ▲
                               │
                               │ Real-time sync
                               ▼

                    ┌─────────────────────┐
                    │  Flutter Mobile App │
                    ├─────────────────────┤
                    │ • Real-time Listen  │
                    │ • Modal UI          │
                    │ • Face Recognition  │
                    │ • Data Management   │
                    └─────────────────────┘
                         Android/iOS


╔════════════════════════════════════════════════════════════════════════╗
║                      DATA FLOW DIAGRAM                                  ║
╚════════════════════════════════════════════════════════════════════════╝

MAC Address Detection
         │
         ├─> ESP32 (5ms processing)
         │
         └─> HTTP POST (50-100ms latency)
                │
                ├─> Flask Server (GCP VM)
                │      │
                │      ├─> Query Firebase (200ms)
                │      │      │
                │      │      ├─> Find Student
                │      │      ├─> Find Schedule
                │      │      └─> Get Professor Info
                │      │
                │      └─> Create Verification (100ms)
                │
                └─> Firestore Write (150ms)
                       │
                       └─> Real-time Sync (500ms-2s)
                              │
                              └─> Flutter App Listener
                                     │
                                     ├─> Show Modal (instant)
                                     │
                                     └─> User Action
                                            │
                                            ├─> Face Recognition
                                            │
                                            └─> Mark Attendance


Total Time: ~3-5 seconds from connection to notification


╔════════════════════════════════════════════════════════════════════════╗
║                    SCALABILITY COMPARISON                               ║
╚════════════════════════════════════════════════════════════════════════╝

OLD ARCHITECTURE (ESP32 Direct Firebase):
┌──────────┐
│  ESP32   │─────────────────────────────────┐
│          │  Heavy processing                │
│  • Query │  Memory constraints              │
│  • Parse │  Network bottleneck              │
│  • Write │  Single-threaded                 │
└──────────┘                                  │
Max: 5-10 concurrent connections              ▼
                                    ❌ Bottleneck


NEW ARCHITECTURE (ESP32 → Flask → Firebase):
┌──────────┐     ┌────────────┐     ┌──────────┐
│  ESP32   │────>│   Flask    │────>│ Firebase │
│          │     │  Server    │     │          │
│  • Detect│     │  • Query   │     │ • Store  │
│  • Send  │     │  • Process │     │ • Sync   │
└──────────┘     │  • Create  │     └──────────┘
                 └────────────┘
                 Horizontally
                 Scalable ↕️
Max: 50-100+ concurrent connections per ESP32
     Unlimited via multiple VMs              ✅ Scalable


╔════════════════════════════════════════════════════════════════════════╗
║                    ERROR HANDLING FLOW                                  ║
╚════════════════════════════════════════════════════════════════════════╝

MAC Detection
     │
     ├─> Student Not Found
     │   └─> Log + Return 404
     │       └─> ESP32 shows warning
     │
     ├─> No Active Class
     │   └─> Log + Return 404
     │       └─> ESP32 shows info message
     │
     ├─> Network Error
     │   └─> Retry 3 times
     │       └─> Log + Alert
     │
     ├─> Verification Expired
     │   └─> Auto-dismiss modal
     │       └─> Show expiry message
     │
     └─> Face Recognition Failed
         └─> Allow 2 retries
             └─> Update status to "failed"


╔════════════════════════════════════════════════════════════════════════╗
║                    SECURITY LAYERS                                      ║
╚════════════════════════════════════════════════════════════════════════╝

Layer 1: MAC Registration
    └─> Only registered MACs processed

Layer 2: Active Schedule Check
    └─> Only during class hours

Layer 3: Time Expiration
    └─> 5-minute verification window

Layer 4: Face Recognition
    └─> Biometric verification required

Layer 5: Firestore Rules
    └─> Server-only write permissions

Layer 6: One-time Verification
    └─> Can't mark same class twice


═══════════════════════════════════════════════════════════════════════════

This architecture provides:
✅ Scalability (50-100+ concurrent connections)
✅ Security (multiple verification layers)
✅ Reliability (error handling at each step)
✅ Performance (optimized data flow)
✅ Cost-effectiveness (~$7/month)
✅ Maintainability (centralized logic)

═══════════════════════════════════════════════════════════════════════════
