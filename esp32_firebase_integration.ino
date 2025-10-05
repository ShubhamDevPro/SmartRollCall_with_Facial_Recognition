#include <WiFi.h>
#include "esp_wifi.h"
#include <vector>
#include <HTTPClient.h>
#include <ArduinoJson.h>
#include <Arduino.h>
#include <WiFiClientSecure.h>
#include <base64.h>

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

bool findStudentByMacAddress(const String& macAddress, String& batchId, String& studentId, String& studentName, String& enrollNumber) {
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("No internet connection for Firebase query");
    return false;
  }

  WiFiClientSecure client;
  client.setInsecure(); // Skip certificate verification for simplicity
  HTTPClient http;
  
  // Query Firebase to find student by MAC address
  String url = "https://firestore.googleapis.com/v1/projects/" + String(FIREBASE_PROJECT_ID) + 
               "/databases/(default)/documents/users/" + String(FIREBASE_USER_ID) + "/batches?key=" + String(FIREBASE_API_KEY);
  
  http.begin(client, url);
  http.addHeader("Content-Type", "application/json");
  
  int httpResponseCode = http.GET();
  
  if (httpResponseCode == 200) {
    String response = http.getString();
    DynamicJsonDocument doc(8192);
    deserializeJson(doc, response);
    
    // Check if documents exist
    if (doc.containsKey("documents")) {
      JsonArray batches = doc["documents"];
      
      // Iterate through each batch
      for (JsonObject batch : batches) {
        String currentBatchPath = batch["name"];
        String currentBatchId = currentBatchPath.substring(currentBatchPath.lastIndexOf("/") + 1);
        
        // Query students in this batch
        String studentsUrl = "https://firestore.googleapis.com/v1/projects/" + String(FIREBASE_PROJECT_ID) + 
                           "/databases/(default)/documents/users/" + String(FIREBASE_USER_ID) + 
                           "/batches/" + currentBatchId + "/students?key=" + String(FIREBASE_API_KEY);
        
        HTTPClient studentHttp;
        studentHttp.begin(client, studentsUrl);
        int studentResponse = studentHttp.GET();
        
        if (studentResponse == 200) {
          String studentResponseStr = studentHttp.getString();
          DynamicJsonDocument studentDoc(4096);
          deserializeJson(studentDoc, studentResponseStr);
          
          if (studentDoc.containsKey("documents")) {
            JsonArray students = studentDoc["documents"];
            
            for (JsonObject student : students) {
              JsonObject fields = student["fields"];
              if (fields.containsKey("macAddress")) {
                String studentMac = fields["macAddress"]["stringValue"];
                if (studentMac.equalsIgnoreCase(macAddress)) {
                  // Found the student!
                  batchId = currentBatchId;
                  String studentPath = student["name"];
                  studentId = studentPath.substring(studentPath.lastIndexOf("/") + 1);
                  studentName = fields["name"]["stringValue"];
                  enrollNumber = fields["enrollNumber"]["stringValue"];
                  studentHttp.end();
                  http.end();
                  return true;
                }
              }
            }
          }
        }
        studentHttp.end();
      }
    }
  } else {
    Serial.print("HTTP Error: ");
    Serial.println(httpResponseCode);
    Serial.println(http.getString());
  }
  
  http.end();
  return false;
}

bool markAttendanceInFirebase(const String& batchId, const String& studentId, const String& macAddress, const String& studentName, const String& enrollNumber) {
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("No internet connection for Firebase update");
    return false;
  }

  // Get current date
  time_t now;
  time(&now);
  struct tm timeinfo;
  localtime_r(&now, &timeinfo);
  
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
    Serial.println("Attendance already marked for " + studentName + " on " + String(dateStr));
    http.end();
    return true; // Already marked, consider successful
  }
  
  http.end();
  
  // Mark new attendance
  String attendanceUrl = "https://firestore.googleapis.com/v1/projects/" + String(FIREBASE_PROJECT_ID) + 
                        "/databases/(default)/documents/users/" + String(FIREBASE_USER_ID) + 
                        "/batches/" + batchId + "/students/" + studentId + "/attendance/" + String(dateStr) + 
                        "?key=" + String(FIREBASE_API_KEY);
  
  DynamicJsonDocument attendanceDoc(1024);
  attendanceDoc["fields"]["isPresent"]["booleanValue"] = true;
  attendanceDoc["fields"]["markedBy"]["stringValue"] = "ESP32";
  attendanceDoc["fields"]["macAddress"]["stringValue"] = macAddress;
  
  // Add timestamp
  attendanceDoc["fields"]["date"]["timestampValue"] = String(timeinfo.tm_year + 1900) + "-" + 
                                                     (timeinfo.tm_mon + 1 < 10 ? "0" : "") + String(timeinfo.tm_mon + 1) + "-" +
                                                     (timeinfo.tm_mday < 10 ? "0" : "") + String(timeinfo.tm_mday) + "T" +
                                                     (timeinfo.tm_hour < 10 ? "0" : "") + String(timeinfo.tm_hour) + ":" +
                                                     (timeinfo.tm_min < 10 ? "0" : "") + String(timeinfo.tm_min) + ":" +
                                                     (timeinfo.tm_sec < 10 ? "0" : "") + String(timeinfo.tm_sec) + "Z";
  
  String attendanceJson;
  serializeJson(attendanceDoc, attendanceJson);
  
  http.begin(client, attendanceUrl);
  http.addHeader("Content-Type", "application/json");
  
  int httpResponseCode = http.PATCH(attendanceJson);
  
  if (httpResponseCode == 200 || httpResponseCode == 201) {
    Serial.println("✓ Attendance marked for " + studentName + " (" + enrollNumber + ") via ESP32");
    http.end();
    return true;
  } else {
    Serial.print("Error marking attendance: ");
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

      // Try to find student and mark attendance
      String batchId, studentId, studentName, enrollNumber;
      if (findStudentByMacAddress(macAddress, batchId, studentId, studentName, enrollNumber)) {
        Serial.println("📱 Student found: " + studentName + " (" + enrollNumber + ")");
        
        if (markAttendanceInFirebase(batchId, studentId, macAddress, studentName, enrollNumber)) {
          Serial.println("✅ Attendance marked successfully!");
          
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
        Serial.println("❓ No student found with MAC address: " + macAddress);
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