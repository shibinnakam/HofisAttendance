# Hofis Attendance - ESP8266 + RC522 + LCD + Buzzer Guide

This folder contains the complete Arduino sketch (`esp8266_rfid_attendance.ino`) for the **ESP8266 NodeMCU** physical attendance scanner.

---

## 1. Pin Wiring Diagram

### A. RFID RC522 -> ESP8266 (NodeMCU)
| RC522 Pin | ESP8266 Pin | Pin Description |
| :--- | :--- | :--- |
| **3.3V** | **3V3** (3.3V) | Power supply (Do NOT connect to 5V!) |
| **GND** | **GND** | Ground |
| **RST** | **D3** (GPIO 0) | Reset |
| **MISO** | **D6** (GPIO 12) | SPI Master In Slave Out |
| **MOSI** | **D7** (GPIO 13) | SPI Master Out Slave In |
| **SCK** | **D5** (GPIO 14) | SPI Clock |
| **SDA (SS)** | **D8** (GPIO 15) | SPI Chip Select |

---

### B. 16x2 I2C LCD Display -> ESP8266
| LCD I2C Pin | ESP8266 Pin | Notes |
| :--- | :--- | :--- |
| **GND** | **GND** | Ground |
| **VCC** | **3V3** or **VIN (5V)** | Most I2C LCD modules operate best on 5V/VIN |
| **SDA** | **D2** (GPIO 4) | I2C Data |
| **SCL** | **D1** (GPIO 5) | I2C Clock |

*Note: Default I2C address in code is `0x27`. If your LCD backlight turns on but no text appears, change `0x27` to `0x3F` or adjust the blue potentiometer on the back of the LCD.*

---

### C. Buzzer -> ESP8266 (Selected Safe Pin)
| Buzzer Leg | ESP8266 Pin |
| :--- | :--- |
| **Positive (+ / Long Leg)** | **D4** (GPIO 2) |
| **Negative (- / Short Leg)** | **GND** |

*Why **D4**? On ESP8266 NodeMCU, D4 (GPIO 2) is a safe digital output pin that doesn't conflict with SPI (D5, D6, D7, D8) or I2C (D1, D2) or Reset (D3).*

---

## 2. Buzzer Sound Legend

| Sound | Event | Meaning |
| :--- | :--- | :--- |
| 🔔🔔 **2 Beeps** | WiFi Connected | ESP8266 successfully joined `hofis123` and is ready |
| 🔔 **1 Beep** | Card Recognized | Card UID found in database, attendance recorded (In or Out) |
| 🔔🔔🔔 **3 Beeps** | Card Error / Not Found | Card is NOT registered in database or read failed |

---

## 3. Attendance In & Out Logic

1. **First Tap of the Day**:
   * Status changes from `Absent` to **`Present`**.
   * `In Time` recorded.
   * LCD displays: `[Student Name]` / `IN: Present OK`.
   * Buzzer: **1 Beep**.

2. **Second Tap of the Same Day**:
   * `Out Time` recorded.
   * LCD displays: `[Student Name]` / `OUT: Checked Out`.
   * Buzzer: **1 Beep**.

3. **Every Midnight (12:00 AM)**:
   * The backend server automatically rolls over to the new day.
   * Any new tap starts fresh as **First Tap (Check In)** for that day.

---

## 4. Arduino IDE Setup Instructions

1. **Install ESP8266 Board Support**:
   * In Arduino IDE: `File` -> `Preferences`.
   * Additional Board Manager URLs, add:
     ```text
     http://arduino.esp8266.com/stable/package_esp8266com_index.json
     ```
   * Open `Tools` -> `Board` -> `Boards Manager`, search for **`esp8266`**, click **Install**.

2. **Install Required Libraries**:
   * In Arduino IDE, go to `Sketch` -> `Include Library` -> `Manage Libraries...`:
     1. Search **`MFRC522`** by GithubCommunity -> Click **Install**.
     2. Search **`LiquidCrystal I2C`** by Frank de Brabander -> Click **Install**.
     3. Search **`ArduinoJson`** by Benoit Blanchon -> Click **Install**.

3. **Select Board & Port**:
   * Board: **NodeMCU 1.0 (ESP-12E Module)** (or Generic ESP8266 Module).
   * CPU Frequency: **80 MHz** (or 160 MHz).
   * Port: Select your ESP8266 COM Port.

4. **Upload**:
   * Open `esp8266_rfid_attendance.ino`.
   * Click the **Upload** arrow (`Ctrl + U`).
