/**
 * =========================================================================
 *  HOFIS ATTENDANCE SYSTEM - ESP8266 RFID RC522 CLIENT
 * =========================================================================
 *  Hardware Connections:
 * 
 *  1. RC522 RFID Reader -> ESP8266 (NodeMCU):
 *     - 3.3V  -> 3.3V (3V3)
 *     - GND   -> GND
 *     - RST   -> D3 (GPIO 0)
 *     - MISO  -> D6 (GPIO 12)
 *     - MOSI  -> D7 (GPIO 13)
 *     - SCK   -> D5 (GPIO 14)
 *     - SDA/SS-> D8 (GPIO 15)
 * 
 *  2. 16x2 I2C LCD Display -> ESP8266:
 *     - VCC   -> 3.3V (or VIN/5V if LCD requires 5V)
 *     - GND   -> GND
 *     - SDA   -> D2 (GPIO 4)
 *     - SCL   -> D1 (GPIO 5)
 *     - I2C Address: Usually 0x27 or 0x3F
 * 
 *  3. Buzzer -> ESP8266:
 *     - Positive (+) -> D4 (GPIO 2)  [RECOMMENDED SAFE PIN]
 *     - Negative (-) -> GND
 * 
 *  Required Arduino Libraries (Install via Arduino IDE Library Manager):
 *   1. "MFRC522" by GithubCommunity
 *   2. "LiquidCrystal I2C" by Frank de Brabander
 *   3. "ArduinoJson" (v6 or v7) by Benoit Blanchon
 *   4. ESP8266 Board Package by ESP8266 Community
 * =========================================================================
 */

#include <ESP8266WiFi.h>
#include <ESP8266HTTPClient.h>
#include <WiFiClientSecure.h>
#include <SPI.h>
#include <MFRC522.h>
#include <Wire.h>
#include <LiquidCrystal_I2C.h>
#include <ArduinoJson.h>

// ---------------------- PIN DEFINITIONS ----------------------
#define RST_PIN     D3    // RC522 Reset
#define SS_PIN      D8    // RC522 SDA (SPI Slave Select)
#define BUZZER_PIN  D4    // Buzzer Positive (+) -> D4

// ---------------------- WIFI CREDENTIALS ---------------------
const char* WIFI_SSID     = "hofis123";
const char* WIFI_PASSWORD = "hofis123";

// ---------------------- BACKEND API URL ----------------------
// Your live cloud backend on Render
const char* SERVER_URL    = "https://hofisattendance.onrender.com/api/attendance/tap";

// ---------------------- HARDWARE INSTANCES -------------------
MFRC522 mfrc522(SS_PIN, RST_PIN);
LiquidCrystal_I2C lcd(0x27, 16, 2); // Default I2C address 0x27 (change to 0x3F if your LCD doesn't show text)

// ---------------------- TIMING HELPERS -----------------------
unsigned long lastTapTime = 0;
const unsigned long TAP_COOLDOWN_MS = 2500; // 2.5s debounce to prevent accidental double-scans
String lastScannedUID = "";

// =============================================================
//  BUZZER BEEP FUNCTIONS
// =============================================================

// Single Beep Helper
void singleBeep(int durationMs = 120, int pauseMs = 80) {
  digitalWrite(BUZZER_PIN, HIGH);
  delay(durationMs);
  digitalWrite(BUZZER_PIN, LOW);
  delay(pauseMs);
}

// 1 Beep: Card Scanned & Attendance Successfully Marked
void beepSuccess() {
  singleBeep(180, 50);
}

// 2 Beeps: WiFi Connected Successfully
void beepWiFiConnected() {
  singleBeep(120, 80);
  singleBeep(120, 80);
}

// 3 Beeps: Card Not Found / Error / Card Not Read
void beepError() {
  singleBeep(100, 70);
  singleBeep(100, 70);
  singleBeep(220, 100);
}

// =============================================================
//  LCD HELPER FUNCTIONS
// =============================================================

void displayDefaultScreen() {
  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print("HOFIS ATTENDANCE");
  lcd.setCursor(0, 1);
  lcd.print("Ready! Tap Card ");
}

void displayConnectingWiFi() {
  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print("HOFIS ATTENDANCE");
  lcd.setCursor(0, 1);
  lcd.print("Connecting WiFi.");
}

// =============================================================
//  WIFI CONNECTION
// =============================================================
void connectToWiFi() {
  displayConnectingWiFi();
  Serial.print("Connecting to WiFi: ");
  Serial.println(WIFI_SSID);

  WiFi.mode(WIFI_STA);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);

  int dotCount = 0;
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
    dotCount++;

    // Update animated dots on LCD
    lcd.setCursor(15, 1);
    if (dotCount % 2 == 0) {
      lcd.print(".");
    } else {
      lcd.print(" ");
    }

    // Auto-retry reset if stuck connecting for > 25 seconds
    if (dotCount > 50) {
      Serial.println("\nWiFi timeout. Retrying...");
      WiFi.disconnect();
      WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
      dotCount = 0;
    }
  }

  Serial.println("\n✅ WiFi Connected!");
  Serial.print("IP Address: ");
  Serial.println(WiFi.localIP());

  // Produce 2 beeps on WiFi connect
  beepWiFiConnected();

  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print("WiFi Connected!");
  lcd.setCursor(0, 1);
  lcd.print(WiFi.localIP().toString().substring(0, 16));
  delay(1500);

  displayDefaultScreen();
}

// =============================================================
//  SEND RFID TAP TO BACKEND SERVER
// =============================================================
void sendCardTapToServer(String rfidUID) {
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("❌ WiFi Disconnected. Reconnecting...");
    lcd.clear();
    lcd.setCursor(0, 0);
    lcd.print("WiFi Lost!");
    lcd.setCursor(0, 1);
    lcd.print("Reconnecting...");
    beepError();
    connectToWiFi();
    return;
  }

  // Display reading state
  lcd.clear();
  lcd.setCursor(0, 0);
  lcd.print("Processing Card ");
  lcd.setCursor(0, 1);
  lcd.print("UID: " + rfidUID);

  Serial.print("\n📡 Sending RFID to Cloud: ");
  Serial.println(rfidUID);

  // Use WiFiClientSecure with setInsecure for HTTPS Render server
  WiFiClientSecure client;
  client.setInsecure(); // Allows HTTPS without static fingerprint
  client.setTimeout(8000);

  HTTPClient http;

  if (http.begin(client, SERVER_URL)) {
    http.addHeader("Content-Type", "application/json");

    // Prepare JSON payload: {"rfidCardNumber":"XXXXXX"}
    String requestBody = "{\"rfidCardNumber\":\"" + rfidUID + "\"}";

    int httpCode = http.POST(requestBody);

    Serial.print("HTTP Response Code: ");
    Serial.println(httpCode);

    if (httpCode == HTTP_CODE_OK || httpCode == 200) {
      String responsePayload = http.getString();
      Serial.println("Server Response: " + responsePayload);

      // Parse JSON response
      DynamicJsonDocument doc(1024);
      DeserializationError error = deserializeJson(doc, responsePayload);

      if (!error && doc["success"] == true) {
        String studentName = doc["data"]["studentName"].as<String>();
        String action      = doc["action"].as<String>();     // "Checked In" or "Checked Out"
        String status      = doc["data"]["status"].as<String>(); // "Present"
        String studentClass= doc["data"]["class"].as<String>();

        // 1 Beep: Successful attendance mark
        beepSuccess();

        // Display confirmation on LCD
        lcd.clear();
        lcd.setCursor(0, 0);
        // Truncate name if longer than 16 chars
        if (studentName.length() > 16) {
          lcd.print(studentName.substring(0, 16));
        } else {
          lcd.print(studentName);
        }

        lcd.setCursor(0, 1);
        if (action == "Checked In") {
          lcd.print("IN: Present OK ");
        } else {
          lcd.print("OUT: Checked Out");
        }

        Serial.println("✅ Attendance Marked: " + studentName + " [" + action + "]");
        delay(2500);

      } else {
        // Response format issue
        beepError();
        lcd.clear();
        lcd.setCursor(0, 0);
        lcd.print("System Error");
        lcd.setCursor(0, 1);
        lcd.print("Please Try Again");
        delay(2000);
      }

    } else if (httpCode == 404) {
      // 404: Card not found in database!
      Serial.println("❌ Card Not Found in Database!");
      // 3 Beeps: Card not found / rejected
      beepError();

      lcd.clear();
      lcd.setCursor(0, 0);
      lcd.print("CARD NOT FOUND!");
      lcd.setCursor(0, 1);
      lcd.print("Please Register");
      delay(2500);

    } else {
      // Server error or timeout
      Serial.printf("❌ Server Error: %d\n", httpCode);
      beepError();

      lcd.clear();
      lcd.setCursor(0, 0);
      lcd.print("Server Error: ");
      lcd.print(httpCode);
      lcd.setCursor(0, 1);
      lcd.print("Please Retry");
      delay(2000);
    }

    http.end();

  } else {
    Serial.println("❌ Failed to initiate HTTPS connection.");
    beepError();

    lcd.clear();
    lcd.setCursor(0, 0);
    lcd.print("Conn. Error!");
    lcd.setCursor(0, 1);
    lcd.print("Check Server");
    delay(2000);
  }

  // Return to standby ready screen
  displayDefaultScreen();
}

// =============================================================
//  SETUP
// =============================================================
void setup() {
  Serial.begin(115200);
  delay(200);
  Serial.println("\n\n==========================================");
  Serial.println("  HOFIS ATTENDANCE - ESP8266 SYSTEM");
  Serial.println("==========================================");

  // Initialize Buzzer
  pinMode(BUZZER_PIN, OUTPUT);
  digitalWrite(BUZZER_PIN, LOW);

  // Initialize I2C LCD
  // SDA on D2 (GPIO 4), SCL on D1 (GPIO 5)
  Wire.begin(D2, D1);
  lcd.init();
  lcd.backlight();

  // Initialize SPI & RC522 RFID
  SPI.begin();
  mfrc522.PCD_Init();
  delay(100);
  mfrc522.PCD_DumpVersionToSerial();

  // Connect to WiFi (Beeps 2 times on success)
  connectToWiFi();
}

// =============================================================
//  MAIN LOOP
// =============================================================
void loop() {
  // Ensure WiFi is still connected
  if (WiFi.status() != WL_CONNECTED) {
    connectToWiFi();
  }

  // Check if a new RFID card is presented
  if (!mfrc522.PICC_IsNewCardPresent()) {
    return;
  }

  // Select card
  if (!mfrc522.PICC_ReadCardSerial()) {
    return;
  }

  // Read Card UID into uppercase Hex string
  String cardUID = "";
  for (byte i = 0; i < mfrc522.uid.size; i++) {
    if (mfrc522.uid.uidByte[i] < 0x10) {
      cardUID += "0";
    }
    cardUID += String(mfrc522.uid.uidByte[i], HEX);
  }
  cardUID.toUpperCase();

  // Halt card reading
  mfrc522.PICC_HaltA();
  mfrc522.PCD_StopCrypto1();

  // Check debounce cooldown to prevent rapid accidental double-reads
  unsigned long now = millis();
  if (cardUID == lastScannedUID && (now - lastTapTime < TAP_COOLDOWN_MS)) {
    Serial.println("⚠️ Debounce: Ignoring repeated scan within 2.5s.");
    return;
  }

  lastTapTime = now;
  lastScannedUID = cardUID;

  // Process the tap with the backend server
  sendCardTapToServer(cardUID);
}
