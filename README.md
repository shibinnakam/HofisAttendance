# RFID Based Attendance System Backend

A Node.js and MongoDB Atlas backend for an RFID-based student attendance system. Includes full CRUD operations for students/users, class selection dropdown support, automatic In/Out time logging on RFID card tap, and a built-in web dashboard and RFID simulator.

---

## Features

- **User / Student Management (CRUD)**:
  - **Create Student**: Register RFID card UID, student name, class (selected via dropdown or custom), status, and optional in/out times.
  - **View Students**: List all students with real-time status badges (`Present` / `Absent`), class tag, and formatted In-Time / Out-Time.
  - **Filter & Search**: Search by student name, RFID UID, or filter dynamically by class and status.
  - **Update Student**: Modify name, RFID UID, class, or attendance status.
  - **Delete Student**: Remove student records.
- **Dynamic Class Dropdown**:
  - Preloaded with standard school/college grades & sections.
  - Automatically indexes custom classes from the database into the dropdown.
- **RFID Tap Processing (IoT & Hardware Ready)**:
  - Microcontroller endpoint: `POST /api/attendance/tap` with `{ "rfidCardNumber": "..." }`.
  - First tap of the day automatically records **In-Time** and marks status as **Present**.
  - Subsequent tap records **Out-Time**.
  - Maintains an immutable audit history log (`AttendanceLog`).
- **Interactive Web Dashboard**:
  - Glassmorphic dark UI served directly at `http://localhost:5000/`.
  - Live RFID Card Reader simulator.
  - Real-time attendance rate metrics.
  - Ready-to-use ESP8266/ESP32 Arduino C++ code snippet.

---

## 1. Quick Start

### Step 1: Configure MongoDB Atlas
Open the [.env](file:///d:/rfidhofis/.env) file in the root directory and replace the placeholder with your MongoDB Atlas connection string:

```env
PORT=5000
MONGODB_URI=mongodb+srv://<username>:<password>@cluster0.mongodb.net/rfid_attendance?retryWrites=true&w=majority
```

> **Note on MongoDB Atlas Setup:**
> 1. In MongoDB Atlas, go to **Database Access** and make sure you have a user with read/write privileges.
> 2. Go to **Network Access** and click **Add IP Address** -> select **Allow Access from Anywhere** (`0.0.0.0/0`) during development.

### Step 2: Start the Server

```powershell
# Using npm
npm start

# Or with live reloading
npm run dev
```

The server will start at:
- Web Dashboard: **`http://localhost:5000`**
- API Base URL: **`http://localhost:5000/api`**

---

## 2. API Reference

### Student / User Management

| Method | Endpoint | Description | Request Body / Query |
|---|---|---|---|
| `GET` | `/api/classes` | Get all available classes for dropdown | — |
| `GET` | `/api/users` | List students (with filters) | `?search=rahul&class=Class+10-A&status=Present` |
| `GET` | `/api/users/:id` | Get single student by Mongo ID or RFID UID | — |
| `POST` | `/api/users` | Register a new student | `{ "rfidCardNumber": "A1B2C3D4", "studentName": "Rahul Sharma", "class": "Class 10-A", "status": "Absent" }` |
| `PUT` | `/api/users/:id` | Update student details | `{ "studentName": "Rahul S", "class": "Class 10-B" }` |
| `DELETE` | `/api/users/:id` | Delete student | — |

#### Example: Create Student (`POST /api/users`)
```json
{
  "rfidCardNumber": "5A3F9B2C",
  "studentName": "Emily Watson",
  "class": "Class 10-A",
  "status": "Absent"
}
```

---

### RFID Card Reader & Attendance

| Method | Endpoint | Description | Request Body |
|---|---|---|---|
| `POST` | `/api/attendance/tap` | Scan/Tap an RFID card (IoT / Hardware) | `{ "rfidCardNumber": "5A3F9B2C" }` |
| `GET` | `/api/attendance/stats` | Get total, present, absent counts & rate | — |
| `POST` | `/api/attendance/reset-daily` | Reset all students to Absent for new day | — |
| `GET` | `/api/attendance/logs` | Fetch historical tap event logs | `?limit=50` |

#### Example: Tap RFID Card (`POST /api/attendance/tap`)
```json
// Request
{
  "rfidCardNumber": "5A3F9B2C"
}

// Response (First tap -> Check In)
{
  "success": true,
  "action": "Checked In",
  "message": "Emily Watson successfully checked in at 09:15:32 AM",
  "data": {
    "id": "664b...",
    "rfidCardNumber": "5A3F9B2C",
    "studentName": "Emily Watson",
    "class": "Class 10-A",
    "status": "Present",
    "inTime": "2026-09-14T03:45:32.000Z",
    "outTime": null
  }
}
```

---

## 3. IoT Hardware Wiring & Microcontroller Code

Connect an **MFRC522 RFID reader** to an **ESP8266 (NodeMCU)** or **ESP32**:

| MFRC522 Pin | ESP8266 (NodeMCU) | ESP32 |
|---|---|---|
| 3.3V | 3.3V | 3.3V |
| RST | D3 (GPIO 0) | GPIO 22 |
| GND | GND | GND |
| MISO | D6 (GPIO 12) | GPIO 19 |
| MOSI | D7 (GPIO 13) | GPIO 23 |
| SCK | D5 (GPIO 14) | GPIO 18 |
| SDA (SS) | D8 (GPIO 15) | GPIO 5 |

You can copy the complete Arduino C++ code directly from the **"IoT Hardware Code"** button in the Web Dashboard.
