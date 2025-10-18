"""
Flask Attendance Server for ESP32 Integration
==============================================

This server receives MAC addresses from ESP32 devices and creates
pending verification records in Firebase Firestore.

The student's Flutter app listens for these pending verifications
and prompts them to complete face recognition before marking attendance.

Setup Instructions:
-------------------
1. Install required packages:
   pip install flask firebase-admin requests python-dotenv

2. Download Firebase Admin SDK JSON key:
   - Go to Firebase Console > Project Settings > Service Accounts
   - Click "Generate New Private Key"
   - Save as 'firebase-admin-key.json' in the same directory

3. Create a .env file with:
   FIREBASE_PROJECT_ID=your-project-id

4. Run the server:
   python flask_attendance_server.py

5. For GCP VM deployment:
   - Upload this file and firebase-admin-key.json to VM
   - Install dependencies
   - Run with: nohup python flask_attendance_server.py &
   - Configure firewall to allow port 5000

ESP32 Configuration:
-------------------
Update your ESP32 code with:
const char* SERVER_URL = "http://YOUR_VM_IP:5000/api/mark-attendance";
"""

from flask import Flask, request, jsonify
from datetime import datetime, timedelta
import firebase_admin
from firebase_admin import credentials, firestore
import os
from dotenv import load_dotenv
import threading
import time

# Load environment variables
load_dotenv()

# Initialize Flask app
app = Flask(__name__)

# Request counter for monitoring
request_counter = 0
request_lock = threading.Lock()

# Initialize Firebase Admin SDK
try:
    cred = credentials.Certificate('firebase-admin-key.json')
    firebase_admin.initialize_app(cred)
    db = firestore.client()
    print("✅ Firebase Admin SDK initialized successfully")
except Exception as e:
    print(f"❌ Failed to initialize Firebase: {e}")
    print("⚠️  Make sure 'firebase-admin-key.json' exists in the same directory")
    exit(1)

FIREBASE_PROJECT_ID = "smart-roll-call-76a46"


def get_current_time_ist():
    """Get current time in IST (GMT+5:30)"""
    return datetime.utcnow() + timedelta(hours=5, minutes=30)


def get_day_name():
    """Get current day name"""
    days = ['Monday', 'Tuesday', 'Wednesday',
            'Thursday', 'Friday', 'Saturday', 'Sunday']
    return days[datetime.now().weekday()]


def get_current_time_24():
    """Get current time in HH:MM format"""
    now = get_current_time_ist()
    return f"{now.hour:02d}:{now.minute:02d}"


def find_current_schedule(user_id, batch_id):
    """Find currently active schedule for a batch"""
    try:
        current_day = get_day_name()
        current_time = get_current_time_24()

        # Query schedules for this batch and day
        schedules_ref = db.collection('users').document(user_id)\
            .collection('batches').document(batch_id)\
            .collection('schedules')

        schedules = schedules_ref.where('dayOfWeek', '==', current_day)\
            .where('isActive', '==', True)\
            .stream()

        for schedule in schedules:
            data = schedule.to_dict()
            start_time = data.get('startTime', '')
            end_time = data.get('endTime', '')

            # Check if current time is within schedule
            if start_time <= current_time <= end_time:
                print(
                    f"✅ Found active schedule: {schedule.id} ({start_time} - {end_time})")
                return {
                    'scheduleId': schedule.id,
                    'startTime': start_time,
                    'endTime': end_time,
                    'dayOfWeek': current_day
                }

        print(
            f"⚠️  No active schedule found for {current_day} at {current_time}")
        return None

    except Exception as e:
        print(f"❌ Error finding current schedule: {e}")
        return None


def find_student_by_mac(user_id, mac_address):
    """Find student by MAC address across all batches"""
    try:
        print(f"🔍 Searching for student with MAC: {mac_address}")

        # Get all batches for this user
        batches_ref = db.collection('users').document(
            user_id).collection('batches')
        batches = batches_ref.stream()

        for batch in batches:
            batch_id = batch.id
            batch_data = batch.to_dict()

            # Search students in this batch
            students_ref = batch.reference.collection('students')
            students = students_ref.where(
                'macAddress', '==', mac_address.upper()).stream()

            for student in students:
                student_data = student.to_dict()

                # Find current schedule for this batch
                current_schedule = find_current_schedule(user_id, batch_id)

                if not current_schedule:
                    print(
                        f"⚠️  Student found but no active class for batch {batch_id}")
                    continue

                # Get professor info
                user_doc = db.collection('users').document(user_id).get()
                user_data = user_doc.to_dict() or {}

                result = {
                    'studentId': student.id,
                    'studentName': student_data.get('name', 'Unknown'),
                    'studentEnrollment': student_data.get('enrollNumber', 'Unknown'),
                    'batchId': batch_id,
                    'courseName': batch_data.get('batchName', 'Unknown Course'),
                    'scheduleId': current_schedule['scheduleId'],
                    'professorId': user_id,
                    'professorName': user_data.get('displayName', 'Unknown Professor'),
                }

                print(
                    f"✅ Student found: {result['studentName']} ({result['studentEnrollment']})")
                return result

        print(f"❌ No student found with MAC: {mac_address}")
        return None

    except Exception as e:
        print(f"❌ Error finding student: {e}")
        return None


def create_pending_verification(student_data, mac_address):
    """Create pending verification record in Firestore"""
    try:
        now = get_current_time_ist()
        expires_at = now + timedelta(minutes=5)  # 5 minutes to verify

        verification_data = {
            'studentId': student_data['studentId'],
            'studentName': student_data['studentName'],
            'studentEnrollment': student_data['studentEnrollment'],
            'batchId': student_data['batchId'],
            'courseName': student_data['courseName'],
            'scheduleId': student_data['scheduleId'],
            'professorId': student_data['professorId'],
            'professorName': student_data['professorName'],
            'macAddress': mac_address.upper(),
            'date': firestore.SERVER_TIMESTAMP,
            'detectedAt': firestore.SERVER_TIMESTAMP,
            'expiresAt': expires_at,
            'status': 'pending',
            'verifiedAt': None,
        }

        # Check if pending verification already exists for this student/schedule/date
        today_start = datetime.combine(now.date(), datetime.min.time())
        pending_ref = db.collection('pending_verifications')

        existing = pending_ref\
            .where('studentEnrollment', '==', student_data['studentEnrollment'])\
            .where('scheduleId', '==', student_data['scheduleId'])\
            .where('status', '==', 'pending')\
            .stream()

        for doc in existing:
            doc_data = doc.to_dict()
            detected_at = doc_data.get('detectedAt')
            if detected_at and detected_at.date() == now.date():
                print(f"⚠️  Pending verification already exists: {doc.id}")
                return doc.id

        # Create new pending verification
        doc_ref = pending_ref.add(verification_data)
        verification_id = doc_ref[1].id

        print(f"✅ Created pending verification: {verification_id}")
        return verification_id

    except Exception as e:
        print(f"❌ Error creating pending verification: {e}")
        raise


@app.route('/api/health', methods=['GET'])
def health_check():
    """Health check endpoint"""
    return jsonify({
        'status': 'healthy',
        'timestamp': get_current_time_ist().isoformat(),
        'service': 'ESP32 Attendance Server'
    }), 200


@app.route('/api/mark-attendance', methods=['POST'])
def mark_attendance():
    """
    Endpoint to receive MAC address from ESP32 and create pending verification.

    This endpoint handles all attendance logic:
    1. Receives MAC address from ESP32
    2. Finds student by MAC address (searches all users/batches)
    3. Checks for active class schedule
    4. Creates pending verification in Firestore
    5. Returns success/failure to ESP32
    """
    global request_counter

    with request_lock:
        request_counter += 1
        current_request_id = request_counter

    start_time = time.time()

    try:
        # Get request data
        data = request.get_json()

        if not data:
            print(f"❌ Request #{current_request_id}: No JSON data")
            return jsonify({
                'success': False,
                'error': 'No JSON data provided'
            }), 400

        mac_address = data.get('macAddress')

        # Validate input
        if not mac_address:
            print(f"❌ Request #{current_request_id}: Missing macAddress")
            return jsonify({
                'success': False,
                'error': 'macAddress is required'
            }), 400

        # Get user ID from environment variable
        user_id = os.getenv('FIREBASE_USER_ID')
        if not user_id:
            print(
                f"❌ Request #{current_request_id}: FIREBASE_USER_ID not configured")
            return jsonify({
                'success': False,
                'error': 'Server configuration error'
            }), 500

        print(f"\n{'='*60}")
        print(f"📱 Request #{current_request_id}: New MAC Address Received")
        print(f"{'='*60}")
        print(f"   MAC Address: {mac_address}")
        print(
            f"   Timestamp: {get_current_time_ist().strftime('%Y-%m-%d %H:%M:%S')}")
        print(f"{'='*60}")

        # Step 1: Find student by MAC address
        print(f"🔍 Step 1: Searching for student...")
        student_data = find_student_by_mac(user_id, mac_address)

        if not student_data:
            elapsed = time.time() - start_time
            print(
                f"❌ Request #{current_request_id}: Student not found ({elapsed:.2f}s)")
            print(f"{'='*60}\n")
            return jsonify({
                'success': False,
                'error': 'Student not found or no active class',
                'message': 'No student with this MAC address found in any active class'
            }), 404

        # Step 2: Create pending verification
        print(f"📝 Step 2: Creating pending verification...")
        verification_id = create_pending_verification(
            student_data, mac_address)

        elapsed = time.time() - start_time

        print(f"\n✅ Request #{current_request_id}: SUCCESS ({elapsed:.2f}s)")
        print(f"   Student: {student_data['studentName']}")
        print(f"   Enrollment: {student_data['studentEnrollment']}")
        print(f"   Course: {student_data['courseName']}")
        print(f"   Verification ID: {verification_id}")
        print(f"{'='*60}\n")

        return jsonify({
            'success': True,
            'message': 'Pending verification created',
            'verificationId': verification_id,
            'studentName': student_data['studentName'],
            'studentEnrollment': student_data['studentEnrollment'],
            'courseName': student_data['courseName'],
            'expiresIn': 300  # 5 minutes
        }), 200

    except Exception as e:
        elapsed = time.time() - start_time
        print(f"\n❌ Request #{current_request_id}: ERROR ({elapsed:.2f}s)")
        print(f"   Error: {str(e)}")
        print(f"{'='*60}\n")
        return jsonify({
            'success': False,
            'error': str(e),
            'message': 'Internal server error'
        }), 500


@app.route('/api/cleanup-expired', methods=['POST'])
def cleanup_expired():
    """
    Cleanup expired pending verifications.
    This can be called periodically or triggered manually.
    """
    try:
        now = get_current_time_ist()
        pending_ref = db.collection('pending_verifications')

        # Find expired pending verifications
        expired = pending_ref\
            .where('status', '==', 'pending')\
            .where('expiresAt', '<', now)\
            .stream()

        count = 0
        for doc in expired:
            doc.reference.update({
                'status': 'expired',
                'expiredAt': firestore.SERVER_TIMESTAMP
            })
            count += 1

        print(f"🧹 Cleaned up {count} expired verifications")

        return jsonify({
            'success': True,
            'message': f'Cleaned up {count} expired verifications',
            'count': count
        }), 200

    except Exception as e:
        print(f"❌ Error cleaning up: {e}")
        return jsonify({
            'success': False,
            'error': str(e)
        }), 500


if __name__ == '__main__':
    print("\n" + "="*70)
    print("🚀 ESP32 Attendance Server Starting...")
    print("="*70)
    print(f"📍 Firebase Project: {FIREBASE_PROJECT_ID}")
    print(f"🌐 Server running on: http://0.0.0.0:5000")
    print(f"📡 ESP32 endpoint: POST http://YOUR_IP:5000/api/mark-attendance")
    print(f"❤️  Health check: GET http://YOUR_IP:5000/api/health")
    print(f"🧹 Cleanup: POST http://YOUR_IP:5000/api/cleanup-expired")
    print("="*70)
    print(f"⚡ Ready to handle multiple simultaneous MAC addresses")
    print(f"📊 All attendance logic is handled by this server")
    print(f"🔥 ESP32 only sends MAC addresses - no Firebase on ESP32")
    print("="*70 + "\n")

    # Run the Flask app with threading support
    app.run(host='0.0.0.0', port=5000, debug=False, threaded=True)
