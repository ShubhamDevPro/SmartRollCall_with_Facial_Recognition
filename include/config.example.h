#ifndef CONFIG_H
#define CONFIG_H

// Flask Server URL (your GCP VM IP and port)
#define SERVER_URL_FROM_CONFIG "http://YOUR_VM_IP:5000/api/mark-attendance"

// Access Point (Hotspot) Configuration
#define AP_SSID "Smart_Roll_Call_ESP32"
#define AP_PASSWORD "attendance123"
#define AP_CHANNEL 1
#define HIDE_SSID 0
#define MAX_CONNECTIONS 10

// Home WiFi (for internet access)
#define WIFI_SSID "YOUR_HOME_WIFI_NAME"
#define WIFI_PASSWORD "YOUR_HOME_WIFI_PASSWORD"

// Daylight saving time offset (0 for India)
#define DAYLIGHT_OFFSET_SEC 0

// ==================== TIMING INTERVALS ====================

// Device check interval (milliseconds) - how often to check for new devices
#define DEVICE_CHECK_INTERVAL 5000 // 5 seconds

#endif // CONFIG_H
