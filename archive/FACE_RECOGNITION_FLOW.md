# Face Recognition Flow Diagram

## System Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                         FACE RECOGNITION SYSTEM                      │
└─────────────────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────────────────┐
│                      1. FACE ENROLLMENT FLOW                          │
└──────────────────────────────────────────────────────────────────────┘

   Student Opens App
         │
         ▼
   ┌─────────────────┐
   │ Check Firestore │
   │  Has Face Data? │
   └────────┬────────┘
            │
      ┌─────┴─────┐
      │           │
     NO          YES
      │           │
      ▼           ▼
┌──────────┐  ┌────────────────┐
│  Show    │  │ Hide Enrollment│
│ "Enroll  │  │     Card       │
│  Face"   │  │                │
│  Card    │  │  (Ready for    │
└────┬─────┘  │  verification) │
     │        └────────────────┘
     ▼
┌──────────────────┐
│ Student Clicks   │
│ "Enroll Face Now"│
└────────┬─────────┘
         │
         ▼
┌──────────────────────────┐
│  Face Enrollment Screen  │
│                          │
│  Instructions:           │
│  • Face camera directly  │
│  • Good lighting         │
│  • Remove glasses        │
│  • Neutral expression    │
└────────┬─────────────────┘
         │
    ┌────┴────┐
    │         │
  Camera   Gallery
    │         │
    └────┬────┘
         │
         ▼
┌─────────────────────┐
│  Capture Image      │
│  (JPEG format)      │
└──────────┬──────────┘
           │
           ▼
┌──────────────────────────┐
│   FaceSDK Processing     │
│                          │
│  1. Detect face in image │
│  2. Extract face region  │
│  3. Generate embedding   │
│     (faceTemplates)      │
└──────────┬───────────────┘
           │
     ┌─────┴──────┐
     │            │
   Success      Failed
     │            │
     ▼            ▼
┌──────────┐  ┌──────────┐
│  Store   │  │  Show    │
│  in      │  │  Error   │
│ Firestore│  │ Message  │
└────┬─────┘  └──────────┘
     │
     ▼
┌────────────────────────┐
│  Firestore Document    │
│  student_profiles/XYZ  │
│                        │
│  {                     │
│    faceJpg: [bytes],   │
│    faceTemplates:      │
│      [bytes],          │
│    faceEnrolledAt:     │
│      timestamp         │
│  }                     │
└────────────────────────┘


┌──────────────────────────────────────────────────────────────────────┐
│                   2. FACE VERIFICATION FLOW                           │
└──────────────────────────────────────────────────────────────────────┘

┌──────────────────┐
│  ESP32 Device    │
│  Detects Student │
│  in Classroom    │
└────────┬─────────┘
         │
         ▼
┌─────────────────────────────┐
│  Create pending_verification│
│  in Firestore               │
│                             │
│  {                          │
│    studentEnrollment,       │
│    courseName,              │
│    professorName,           │
│    status: "pending",       │
│    expiresAt: +5min         │
│  }                          │
└────────┬────────────────────┘
         │
         ▼
┌────────────────────────────┐
│  Real-time Listener        │
│  Triggers on Student App   │
└────────┬───────────────────┘
         │
         ▼
┌─────────────────────────────┐
│  Show Modal Bottom Sheet    │
│                             │
│  ┌───────────────────────┐  │
│  │  Face Verification    │  │
│  │  Required             │  │
│  │                       │  │
│  │  Course: Data Science │  │
│  │  Prof: Dr. Smith      │  │
│  │                       │  │
│  │  Time: 04:45          │  │
│  │                       │  │
│  │  [Verify & Mark      │  │
│  │   Attendance]         │  │
│  └───────────────────────┘  │
└────────┬────────────────────┘
         │
         ▼
┌────────────────────────────┐
│  Student Clicks Button     │
└────────┬───────────────────┘
         │
         ▼
┌────────────────────────────┐
│  Check if Face Enrolled    │
└────────┬───────────────────┘
         │
    ┌────┴────┐
    │         │
   YES       NO
    │         │
    │         ▼
    │    ┌──────────────────┐
    │    │  Show Error:     │
    │    │  "Please enroll  │
    │    │   face first"    │
    │    └──────────────────┘
    │
    ▼
┌──────────────────────────┐
│  Open Front Camera       │
│  (ImageSource.camera)    │
└────────┬─────────────────┘
         │
         ▼
┌──────────────────────────┐
│  Capture Live Photo      │
└────────┬─────────────────┘
         │
         ▼
┌──────────────────────────────┐
│   FaceSDK Processing         │
│                              │
│  1. Extract face from photo  │
│  2. Generate embedding       │
│  3. Calculate liveness score │
└────────┬─────────────────────┘
         │
         ▼
┌──────────────────────────────────┐
│  Retrieve Stored Embedding       │
│  from Firestore                  │
│  (student_profiles collection)   │
└────────┬─────────────────────────┘
         │
         ▼
┌──────────────────────────────────┐
│  FaceSDK Similarity Calculation  │
│                                  │
│  Compare:                        │
│  - Captured embedding            │
│  - Stored embedding              │
│                                  │
│  Returns: similarity (0.0-1.0)   │
└────────┬─────────────────────────┘
         │
         ▼
┌──────────────────────────────────┐
│  Verification Checks             │
│                                  │
│  similarity >= 0.8 (80%) ?       │
│  liveness >= 0.7 (70%) ?         │
└────────┬─────────────────────────┘
         │
    ┌────┴────┐
    │         │
  PASS      FAIL
    │         │
    │         ▼
    │    ┌─────────────────────────┐
    │    │  Show Error Message:    │
    │    │  - "Face doesn't match" │
    │    │  - "Use live camera"    │
    │    │                         │
    │    │  Allow retry            │
    │    └─────────────────────────┘
    │
    ▼
┌──────────────────────────────────┐
│  Mark Attendance                 │
│                                  │
│  1. Create attendance_record     │
│  2. Update pending_verification  │
│     status: "verified"           │
└────────┬─────────────────────────┘
         │
         ▼
┌──────────────────────────────────┐
│  Show Success Message            │
│  "Attendance Marked! ✅"         │
└──────────────────────────────────┘


┌──────────────────────────────────────────────────────────────────────┐
│                     3. DATA FLOW DIAGRAM                              │
└──────────────────────────────────────────────────────────────────────┘

┌─────────────────┐
│  Student Device │
└────────┬────────┘
         │
         │ Enroll Face
         ▼
┌──────────────────────────┐
│  FaceSDK (Local)         │
│  • Face Detection        │
│  • Feature Extraction    │
│  • Embedding Generation  │
└────────┬─────────────────┘
         │
         │ faceJpg + faceTemplates
         ▼
┌──────────────────────────┐
│  Firestore               │
│  student_profiles/       │
│    ├─ email             │
│    ├─ enrollmentNumber  │
│    ├─ faceJpg          │
│    └─ faceTemplates    │
└────────┬─────────────────┘
         │
         │ Retrieve on verification
         ▼
┌──────────────────────────┐
│  FaceSDK (Local)         │
│  • Similarity Check      │
│  • Liveness Detection    │
└────────┬─────────────────┘
         │
         │ Match Result
         ▼
┌──────────────────────────┐
│  Firestore               │
│  attendance_records/     │
│    ├─ studentId         │
│    ├─ isPresent: true   │
│    └─ markedAt          │
└──────────────────────────┘


┌──────────────────────────────────────────────────────────────────────┐
│                   4. SECURITY MEASURES                                │
└──────────────────────────────────────────────────────────────────────┘

┌────────────────────────────────┐
│  Anti-Spoofing Techniques      │
├────────────────────────────────┤
│  1. Liveness Detection         │
│     • Checks if face is live   │
│     • Threshold: 70%           │
│     • Prevents photo attacks   │
│                                │
│  2. High Similarity Threshold  │
│     • Requires 80% match       │
│     • Reduces false positives  │
│                                │
│  3. Face Quality Checks        │
│     • Ensures clear image      │
│     • Validates face detection │
│                                │
│  4. Time-Limited Verification  │
│     • 5-minute expiry window   │
│     • Prevents replay attacks  │
└────────────────────────────────┘

┌────────────────────────────────┐
│  Data Protection               │
├────────────────────────────────┤
│  1. Binary Embeddings          │
│     • Not reversible to images │
│     • Privacy-preserving       │
│                                │
│  2. Encrypted Storage          │
│     • Firestore encryption     │
│     • Secure transmission      │
│                                │
│  3. Access Control             │
│     • Student can only access  │
│       their own data           │
│     • Firestore security rules │
└────────────────────────────────┘


┌──────────────────────────────────────────────────────────────────────┐
│                    5. PERFORMANCE METRICS                             │
└──────────────────────────────────────────────────────────────────────┘

Face Enrollment:
├─ Image Capture:         < 1 second
├─ Face Extraction:       1-3 seconds
├─ Firestore Upload:      < 1 second
└─ Total Time:            2-5 seconds

Face Verification:
├─ Camera Open:           < 1 second
├─ Image Capture:         < 1 second
├─ Face Extraction:       1-3 seconds
├─ Similarity Check:      < 0.5 seconds
├─ Firestore Operations:  < 1 second
└─ Total Time:            3-6 seconds

Storage:
├─ Face JPEG:             ~50-100 KB
├─ Face Template:         ~2 KB
└─ Per Student:           ~52-102 KB


┌──────────────────────────────────────────────────────────────────────┐
│                   6. ERROR HANDLING FLOW                              │
└──────────────────────────────────────────────────────────────────────┘

Enrollment Errors:
├─ No Face Detected
│  └─ Show: "No face detected. Please try again with a clear photo."
│
├─ Multiple Faces
│  └─ Show: "Multiple faces detected. Please ensure only your face is visible."
│
├─ Poor Quality
│  └─ Show: "Image quality too low. Please use better lighting."
│
└─ Upload Failed
   └─ Show: "Failed to save. Please check internet and retry."

Verification Errors:
├─ Not Enrolled
│  └─ Show: "Please enroll your face first."
│
├─ Face Mismatch
│  └─ Show: "Face doesn't match. Please try again."
│
├─ Liveness Failed
│  └─ Show: "Please use live camera feed, not a photo."
│
├─ Verification Expired
│  └─ Show: "Verification expired. Please reconnect."
│
└─ Camera Permission Denied
   └─ Show: "Camera access required. Please enable in settings."
```

## Legend

```
┌─────┐
│ Box │  = Process or Component
└─────┘

   │
   ▼      = Flow Direction

┌───┴───┐
│  YES  │ = Decision Branch
└───────┘

┌───────────────┐
│ Firestore DB  │ = Data Storage
└───────────────┘

┌─────────────────┐
│ FaceSDK Plugin  │ = External Service
└─────────────────┘
```

## Key Takeaways

1. **Two Main Flows**: Enrollment (once) and Verification (every attendance)
2. **Local Processing**: Face detection happens on device for speed and privacy
3. **Secure Storage**: Only embeddings stored, not raw face images
4. **Multiple Security Layers**: Similarity + Liveness + Time limits
5. **Fast Performance**: 2-6 seconds total for verification
6. **Error Recovery**: Clear error messages and retry options
