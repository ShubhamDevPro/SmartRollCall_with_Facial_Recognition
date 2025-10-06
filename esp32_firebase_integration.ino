#include <WiFi.h>
#include "esp_wifi.h"
#include <vector>
#include <HTTPClient.h>
#include <ArduinoJson.h>
#include <Arduino.h>
#include <WiFiClientSecure.h>
#include <time.h>

#define LED_BUILTIN 2  // Define LED_BUILTIN for ESP32

// Firebase configuration
const char* FIREBASE_PROJECT_ID = "smart-roll-call-37be0";
const char* FIREBASE_API_KEY = "AIzaSyBB1XPKuOYk6N83m9YB9a_s6Frrc9nGCu4"; // Android API key
const char* FIREBASE_USER_ID = "public_user";

// For hotspot
const char* ssid = "Smart_Roll_Call_ESP32";
const char* password = "attendance123";
const int channel = 10;
const bool hide_SSID = false;
const int max_connection = 20;

// For connection to Home WiFi (for internet)
const char* wifi_network_ssid = "GGSIPU_EDC_STUDENT";
const char* wifi_network_password = NULL;

// Time configuration
const char* ntpServer = "pool.ntp.org";
const long gmtOffset_sec = 19800; // GMT+5:30 for India
const int daylightOffset_sec = 0;

struct ConnectedDevice {
  uint8_t mac[6];
  ip4_addr_t ip;
};

std::vector<ConnectedDevice> connectedDevices;

// To run the functions with different time delays
unsigned long lastDisplayTime = 0;
const int displayInterval = 5000;

void setup() {
  pinMode(LED_BUILTIN, OUTPUT);
  Serial.begin(115200);
  Serial.println("\n[*] Creating AP for Smart Roll Call");
  WiFi.mode(WIFI_AP_STA);
  WiFi.softAP(ssid, password, channel, hide_SSID, max_connection);
  Serial.print("[+] AP Created with IP Gateway ");
  Serial.println(WiFi.softAPIP());

  // Connect to internet for Firebase access
  WiFi.begin(wifi_network_ssid, wifi_network_password);
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println();
  Serial.print("[+] Connected to internet with IP: ");
  Serial.println(WiFi.localIP());

  // Initialize time
  configTime(gmtOffset_sec, daylightOffset_sec, ntpServer);
  Serial.println("[+] Time synchronized");
}

bool isDeviceConnected(const uint8_t* mac) {
  for (const auto& device : connectedDevices) {
    if (memcmp(device.mac, mac, 6) == 0) {
      return true;  // Device is already in the list
    }
  }
  return false;  // Device not found in the list
}

void check_if_esp32_is_connected_to_internet() {
  if (WiFi.status() == WL_CONNECTED) {
    digitalWrite(LED_BUILTIN, HIGH);
    delay(200);
    digitalWrite(LED_BUILTIN, LOW);
    delay(200);
  }
}

String getMacAddressString(const uint8_t* mac) {
  char macStr[18];
  sprintf(macStr, "%02X:%02X:%02X:%02X:%02X:%02X", 
          mac[0], mac[1], mac[2], mac[3], mac[4], mac[5]);
  return String(macStr);
}

String getCurrentDayName() {
  struct tm timeinfo;
  if (!getLocalTime(&timeinfo)) {
    return "Unknown";
  }
  
  const char* days[] = {"Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"};
  return String(days[timeinfo.tm_wday]);
}

String getCurrentTime() {
  struct tm timeinfo;
  if (!getLocalTime(&timeinfo)) {
    return "00:00";
  }
  
  char timeStr[6];
  sprintf(timeStr, "%02d:%02d", timeinfo.tm_hour, timeinfo.tm_min);
  return String(timeStr);
}

String getCurrentlyScheduledBatch() {
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("No internet connection for batch query");
    return "";
  }

  String currentDay = getCurrentDayName();
  String currentTime = getCurrentTime();
  
  Serial.println("🕐 Current time: " + currentDay + " " + currentTime);
  
  WiFiClientSecure client;
  client.setInsecure();
  HTTPClient http;
  
  // Query Firebase for currently scheduled batch
  String url = "https://firestore.googleapis.com/v1/projects/" + String(FIREBASE_PROJECT_ID) + 
               "/databases/(default)/documents/users/" + String(FIREBASE_USER_ID) + 
               "/batches?key=" + String(FIREBASE_API_KEY);
  
  http.begin(client, url);
  int httpResponseCode = http.GET();
  
  if (httpResponseCode == 200) {
    String response = http.getString();
    DynamicJsonDocument doc(8192);
    deserializeJson(doc, response);
    
    if (doc.containsKey("documents")) {
      JsonArray batches = doc["documents"];
      
      for (JsonObject batch : batches) {
        JsonObject fields = batch["fields"];
        
        if (fields.containsKey("dayOfWeek") && fields.containsKey("startTime") && 
            fields.containsKey("endTime") && fields.containsKey("isActive")) {
          
          String batchDay = fields["dayOfWeek"]["stringValue"];
          String startTime = fields["startTime"]["stringValue"];
          String endTime = fields["endTime"]["stringValue"];
          bool isActive = fields["isActive"]["booleanValue"];
          String batchName = fields["batchName"]["stringValue"];
          
          Serial.println("📚 Found batch: " + batchName + " on " + batchDay + " (" + startTime + "-" + endTime + ")");
          
          if (isActive && batchDay == currentDay && 
              currentTime >= startTime && currentTime <= endTime) {
            
            String batchPath = batch["name"];
            String batchId = batchPath.substring(batchPath.lastIndexOf("/") + 1);
            
            Serial.println("📅 ✅ Current batch: " + batchName + " (ID: " + batchId + ") - " + startTime + "-" + endTime);
            http.end();
            return batchId;
          }
        }
      }
    }
  } else {
    Serial.print("❌ HTTP Error querying batches: ");
    Serial.println(httpResponseCode);
    if (httpResponseCode > 0) {
      Serial.println(http.getString());
    }
  }
  
  http.end();
  Serial.println("⏰ No batch currently scheduled at " + currentTime + " on " + currentDay);
  return "";
}

bool findStudentInCurrentBatch(const String& macAddress, String& batchId, String& studentId, String& studentName, String& enrollNumber) {
  // First get the currently scheduled batch
  String currentBatch = getCurrentlyScheduledBatch();
  if (currentBatch.isEmpty()) {
    return false;
  }
  
  WiFiClientSecure client;
  client.setInsecure();
  HTTPClient http;
  
  // Query students in the current batch only
  String url = "https://firestore.googleapis.com/v1/projects/" + String(FIREBASE_PROJECT_ID) + 
               "/databases/(default)/documents/users/" + String(FIREBASE_USER_ID) + 
               "/batches/" + currentBatch + "/students?key=" + String(FIREBASE_API_KEY);
  
  http.begin(client, url);
  int httpResponseCode = http.GET();
  
  if (httpResponseCode == 200) {
    String response = http.getString();
    DynamicJsonDocument doc(4096);
    deserializeJson(doc, response);
    
    if (doc.containsKey("documents")) {
      JsonArray students = doc["documents"];
      
      for (JsonObject student : students) {
        JsonObject fields = student["fields"];
        if (fields.containsKey("macAddress")) {
          String studentMac = fields["macAddress"]["stringValue"];
          if (studentMac.equalsIgnoreCase(macAddress)) {
            batchId = currentBatch;
            String studentPath = student["name"];
            studentId = studentPath.substring(studentPath.lastIndexOf("/") + 1);
            studentName = fields["name"]["stringValue"];
            enrollNumber = fields["enrollNumber"]["stringValue"];
            http.end();
            return true;
          }
        }
      }
    }
  } else {
    Serial.print("❌ HTTP Error querying students: ");
    Serial.println(httpResponseCode);
  }
  
  http.end();
  return false;
}

bool markAttendanceInFirebase(const String& batchId, const String& studentId, const String& macAddress, const String& studentName, const String& enrollNumber) {
  struct tm timeinfo;
  if (!getLocalTime(&timeinfo)) {
    Serial.println("Failed to obtain time");
    return false;
  }
  
  char dateStr[11];
  sprintf(dateStr, "%04d-%02d-%02d", timeinfo.tm_year + 1900, timeinfo.tm_mon + 1, timeinfo.tm_mday);
  
  WiFiClientSecure client;
  client.setInsecure();
  HTTPClient http;
  
  // Check if attendance already exists for today
  String checkUrl = "https://firestore.googleapis.com/v1/projects/" + String(FIREBASE_PROJECT_ID) + 
                   "/databases/(default)/documents/users/" + String(FIREBASE_USER_ID) + 
                   "/batches/" + batchId + "/students/" + studentId + "/attendance/" + String(dateStr) + 
                   "?key=" + String(FIREBASE_API_KEY);
  
  http.begin(client, checkUrl);
  int checkResponse = http.GET();
  
  if (checkResponse == 200) {
    Serial.println("✓ Attendance already marked for " + studentName + " in batch " + batchId + " on " + String(dateStr));
    http.end();
    return true; // Already marked, consider successful
  }
  
  http.end();
  
  // Mark new attendance with enhanced metadata
  String attendanceUrl = "https://firestore.googleapis.com/v1/projects/" + String(FIREBASE_PROJECT_ID) + 
                        "/databases/(default)/documents/users/" + String(FIREBASE_USER_ID) + 
                        "/batches/" + batchId + "/students/" + studentId + "/attendance/" + String(dateStr) + 
                        "?key=" + String(FIREBASE_API_KEY);
  
  DynamicJsonDocument attendanceDoc(1024);
  attendanceDoc["fields"]["isPresent"]["booleanValue"] = true;
  attendanceDoc["fields"]["markedBy"]["stringValue"] = "ESP32";
  attendanceDoc["fields"]["macAddress"]["stringValue"] = macAddress;
  attendanceDoc["fields"]["batchId"]["stringValue"] = batchId;
  attendanceDoc["fields"]["classTime"]["stringValue"] = getCurrentTime();
  attendanceDoc["fields"]["dayOfWeek"]["stringValue"] = getCurrentDayName();
  attendanceDoc["fields"]["markedDuringClass"]["booleanValue"] = true;
  
  // Add timestamp
  char timestampStr[30];
  sprintf(timestampStr, "%04d-%02d-%02dT%02d:%02d:%02dZ", 
          timeinfo.tm_year + 1900, timeinfo.tm_mon + 1, timeinfo.tm_mday,
          timeinfo.tm_hour, timeinfo.tm_min, timeinfo.tm_sec);
  attendanceDoc["fields"]["date"]["timestampValue"] = String(timestampStr);
  attendanceDoc["fields"]["markedAt"]["timestampValue"] = String(timestampStr);
  
  String attendanceJson;
  serializeJson(attendanceDoc, attendanceJson);
  
  http.begin(client, attendanceUrl);
  http.addHeader("Content-Type", "application/json");
  
  int httpResponseCode = http.PATCH(attendanceJson);
  
  if (httpResponseCode == 200 || httpResponseCode == 201) {
    Serial.println("✅ Attendance marked for " + studentName + " (" + enrollNumber + ") in batch " + batchId + " at " + getCurrentTime());
    http.end();
    return true;
  } else {
    Serial.print("❌ Error marking attendance: ");
    Serial.println(httpResponseCode);
    Serial.println(http.getString());
    http.end();
    return false;
  }
}

void display_connected_devices() {
  wifi_sta_list_t wifi_sta_list;
  tcpip_adapter_sta_list_t adapter_sta_list;
  esp_wifi_ap_get_sta_list(&wifi_sta_list);
  tcpip_adapter_get_sta_list(&wifi_sta_list, &adapter_sta_list);

  if (adapter_sta_list.num > 0)
    Serial.println("-----------");

  for (uint8_t i = 0; i < adapter_sta_list.num; i++) {
    tcpip_adapter_sta_info_t station = adapter_sta_list.sta[i];
    if (!isDeviceConnected(station.mac) && connectedDevices.size() < max_connection) {
      ConnectedDevice device;
      memcpy(device.mac, station.mac, 6);
      device.ip = *reinterpret_cast<ip4_addr_t*>(&station.ip);
      connectedDevices.push_back(device);
      
      String macAddress = getMacAddressString(station.mac);
      Serial.print("[+] Device " + String(i) + " | MAC: " + macAddress);
      Serial.println(" | IP: " + String(ip4addr_ntoa(reinterpret_cast<const ip4_addr_t*>(&station.ip))));

      // Try to find student in currently scheduled batch only
      String batchId, studentId, studentName, enrollNumber;
      if (findStudentInCurrentBatch(macAddress, batchId, studentId, studentName, enrollNumber)) {
        Serial.println("� Student found: " + studentName + " (" + enrollNumber + ") in current batch " + batchId);
        
        if (markAttendanceInFirebase(batchId, studentId, macAddress, studentName, enrollNumber)) {
          Serial.println("✅ Attendance marked successfully during scheduled class time!");
          
          // Flash LED to indicate success
          for (int j = 0; j < 5; j++) {
            digitalWrite(LED_BUILTIN, HIGH);
            delay(100);
            digitalWrite(LED_BUILTIN, LOW);
            delay(100);
          }
        } else {
          Serial.println("❌ Failed to mark attendance");
        }
      } else {
        Serial.println("❌ Student not found in current batch or no batch scheduled at this time");
        Serial.println("   MAC: " + macAddress + " - Registration may be needed");
      }
    }
  }
}

void loop() {
  check_if_esp32_is_connected_to_internet();

  unsigned long currentTime = millis();
  if (currentTime - lastDisplayTime >= displayInterval) {
    display_connected_devices();
    lastDisplayTime = currentTime;
  }
}