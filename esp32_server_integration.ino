#include <WiFi.h>
#include "esp_wifi.h"
#include <vector>
#include <HTTPClient.h>
#include <ArduinoJson.h>
#include <Arduino.h>

#define LED_BUILTIN 2  // Define LED_BUILTIN for ESP32

// Flutter app server configuration (if using the HTTP server approach)
const char* FLUTTER_SERVER_IP = "192.168.1.100"; // Replace with your Flutter app server IP
const int FLUTTER_SERVER_PORT = 8080;

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

  // Connect to internet for server access
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

bool markAttendanceViaServer(const String& macAddress) {
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("No internet connection");
    return false;
  }

  HTTPClient http;
  String url = "http://" + String(FLUTTER_SERVER_IP) + ":" + String(FLUTTER_SERVER_PORT) + "/mark-attendance";
  
  http.begin(url);
  http.addHeader("Content-Type", "application/json");
  
  // Create JSON payload
  DynamicJsonDocument doc(256);
  doc["macAddress"] = macAddress;
  doc["date"] = ""; // Server will use current date if empty
  
  String jsonString;
  serializeJson(doc, jsonString);
  
  int httpResponseCode = http.POST(jsonString);
  
  if (httpResponseCode == 200) {
    String response = http.getString();
    DynamicJsonDocument responseDoc(512);
    deserializeJson(responseDoc, response);
    
    if (responseDoc["success"] == true) {
      Serial.println("✓ " + responseDoc["message"].as<String>());
      http.end();
      return true;
    }
  } else if (httpResponseCode == 404) {
    Serial.println("❓ Student not found or attendance already marked");
  } else {
    Serial.print("❌ HTTP Error: ");
    Serial.println(httpResponseCode);
    Serial.println(http.getString());
  }
  
  http.end();
  return false;
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

      // Try to mark attendance via server
      if (markAttendanceViaServer(macAddress)) {
        Serial.println("✅ Attendance marked successfully!");
        
        // Flash LED to indicate success
        for (int j = 0; j < 5; j++) {
          digitalWrite(LED_BUILTIN, HIGH);
          delay(100);
          digitalWrite(LED_BUILTIN, LOW);
          delay(100);
        }
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