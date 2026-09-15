const express = require('express');
const router = express.Router();
const User = require('../models/User');
const AttendanceLog = require('../models/AttendanceLog');
const {
  getLocalDateString,
  runNightUpdate,
  getNightUpdateStatus,
} = require('../services/nightUpdateService');

/**
 * @route   POST /api/attendance/tap
 * @desc    Process an RFID card scan/tap (Hardware IoT or Web Simulator)
 * @body    { rfidCardNumber: string }
 */
router.post('/tap', async (req, res) => {
  try {
    const { rfidCardNumber } = req.body;

    if (!rfidCardNumber) {
      return res.status(400).json({
        success: false,
        message: 'Missing rfidCardNumber in request body',
      });
    }

    const normalizedRfid = rfidCardNumber.trim().toUpperCase();

    // Find student with matching RFID
    const student = await User.findOne({ rfidCardNumber: normalizedRfid });

    if (!student) {
      return res.status(404).json({
        success: false,
        message: `Unknown RFID Card (${normalizedRfid}). Please register this card to a student first.`,
        rfidCardNumber: normalizedRfid,
      });
    }

    const now = new Date();
    let action = '';
    let eventType = '';

    // Check if previous tap was from today
    const isSameDay = student.inTime &&
      student.inTime.getFullYear() === now.getFullYear() &&
      student.inTime.getMonth() === now.getMonth() &&
      student.inTime.getDate() === now.getDate();

    // Logic: If first tap of the day, or previous was a different day, or status is Absent
    // First tap of the day -> Check In (Status: Present, inTime: now, outTime: null)
    // Second tap of the same day -> Check Out (outTime: now)
    if (!isSameDay || !student.inTime || student.status === 'Absent') {
      student.status = 'Present';
      student.inTime = now;
      student.outTime = null; // Fresh start for the new day
      student.lastTap = now;
      action = 'Checked In';
      eventType = 'CHECK_IN';
    } else {
      student.outTime = now;
      student.lastTap = now;
      action = 'Checked Out';
      eventType = 'CHECK_OUT';
    }

    await student.save();

    // Record immutable audit log with local date
    try {
      const localDateStr = getLocalDateString(now);
      await AttendanceLog.create({
        userId: student._id,
        rfidCardNumber: student.rfidCardNumber,
        studentName: student.studentName,
        class: student.class,
        eventType: eventType,
        timestamp: now,
        dateString: localDateStr,
      });
    } catch (logErr) {
      console.error('Failed to write attendance log:', logErr.message);
    }

    const timeStr = now.toLocaleTimeString('en-US', {
      timeZone: process.env.TIMEZONE || 'Asia/Kolkata',
      hour: '2-digit',
      minute: '2-digit',
      hour12: true,
    });

    return res.json({
      success: true,
      action: action,
      message: `${student.studentName} successfully ${action.toLowerCase()} at ${timeStr}`,
      data: {
        id: student._id,
        rfidCardNumber: student.rfidCardNumber,
        studentName: student.studentName,
        class: student.class,
        status: student.status,
        inTime: student.inTime,
        outTime: student.outTime,
        lastTap: student.lastTap,
      },
    });
  } catch (error) {
    return res.status(500).json({ success: false, message: error.message });
  }
});

/**
 * @route   GET /api/attendance/stats
 * @desc    Get real-time attendance dashboard statistics
 */
router.get('/stats', async (req, res) => {
  try {
    const mongoose = require('mongoose');
    if (mongoose.connection.readyState !== 1) {
      return res.json({
        success: true,
        data: {
          totalStudents: 0,
          totalPresent: 0,
          totalAbsent: 0,
          attendanceRate: 0,
        },
      });
    }

    const totalStudents = await User.countDocuments();
    const totalPresent = await User.countDocuments({ status: 'Present' });
    const totalAbsent = totalStudents - totalPresent;
    const attendanceRate = totalStudents > 0 ? Math.round((totalPresent / totalStudents) * 100) : 0;

    return res.json({
      success: true,
      data: {
        totalStudents,
        totalPresent,
        totalAbsent,
        attendanceRate,
      },
    });
  } catch (error) {
    return res.status(500).json({ success: false, message: error.message });
  }
});

/**
 * @route   POST /api/attendance/night-update
 * @desc    Trigger the 11:59 PM night attendance update and day reset manually or via scheduler
 */
router.post('/night-update', async (req, res) => {
  try {
    const result = await runNightUpdate();
    return res.json({
      success: result.success,
      message: result.success
        ? `11:59 PM Night update completed successfully. Reset ${result.studentsReset} students to Absent for the new day.`
        : `Night update failed: ${result.message}`,
      data: result,
    });
  } catch (error) {
    return res.status(500).json({ success: false, message: error.message });
  }
});

/**
 * @route   GET /api/attendance/night-update/status
 * @desc    Get status of the 11:59 PM night update scheduler
 */
router.get('/night-update/status', (req, res) => {
  const status = getNightUpdateStatus();
  return res.json({ success: true, data: status });
});

/**
 * @route   POST /api/attendance/reset-daily
 * @desc    Reset all student statuses to Absent and clear in/out times for a new day
 */
router.post('/reset-daily', async (req, res) => {
  try {
    const result = await runNightUpdate();
    return res.json({
      success: result.success,
      message: `Daily attendance reset completed. Updated ${result.studentsReset ?? 0} student records.`,
      data: result,
    });
  } catch (error) {
    return res.status(500).json({ success: false, message: error.message });
  }
});

/**
 * @route   GET /api/attendance/logs
 * @desc    Get historical attendance tap logs
 */
router.get('/logs', async (req, res) => {
  try {
    const limit = parseInt(req.query.limit) || 50;
    const logs = await AttendanceLog.find().sort({ timestamp: -1 }).limit(limit);
    return res.json({ success: true, count: logs.length, data: logs });
  } catch (error) {
    return res.status(500).json({ success: false, message: error.message });
  }
});

/**
 * @route   GET /api/attendance/report
 * @desc    Get attendance report for a specific class on a custom date
 * @query   class: string, date: YYYY-MM-DD
 */
router.get('/report', async (req, res) => {
  try {
    const { class: studentClass, date } = req.query;
    const todayLocalStr = getLocalDateString(new Date());
    const queryDateStr = date || todayLocalStr;

    // Parse YYYY-MM-DD components
    const [y, m, d] = queryDateStr.split('-').map(Number);
    const startOfDay = new Date(y, m - 1, d, 0, 0, 0, 0);
    const endOfDay = new Date(y, m - 1, d, 23, 59, 59, 999);

    const userQuery = {};
    if (studentClass && studentClass !== 'All' && studentClass !== 'All Classes') {
      userQuery.class = studentClass;
    }

    const students = await User.find(userQuery).sort({ studentName: 1 });

    const logs = await AttendanceLog.find({
      $or: [
        { dateString: queryDateStr },
        { timestamp: { $gte: startOfDay, $lte: endOfDay } }
      ]
    }).sort({ timestamp: 1 });

    const logsByStudent = {};
    logs.forEach(log => {
      const keyId = log.userId ? log.userId.toString() : '';
      if (keyId) {
        if (!logsByStudent[keyId]) logsByStudent[keyId] = [];
        logsByStudent[keyId].push(log);
      }
      if (log.rfidCardNumber) {
        if (!logsByStudent[log.rfidCardNumber]) logsByStudent[log.rfidCardNumber] = [];
        logsByStudent[log.rfidCardNumber].push(log);
      }
    });

    const isToday = queryDateStr === todayLocalStr;
    let presentCount = 0;

    const records = students.map(student => {
      const studentLogs = logsByStudent[student._id.toString()] || logsByStudent[student.rfidCardNumber] || [];
      let inTime = null;
      let outTime = null;
      let status = 'Absent';

      if (studentLogs.length > 0) {
        const checkIns = studentLogs.filter(l => l.eventType === 'CHECK_IN');
        const checkOuts = studentLogs.filter(l => l.eventType === 'CHECK_OUT');

        if (checkIns.length > 0) {
          inTime = checkIns[0].timestamp;
          status = 'Present';
        }
        if (checkOuts.length > 0) {
          outTime = checkOuts[checkOuts.length - 1].timestamp;
        }
      }

      if (isToday && student.status === 'Present') {
        status = 'Present';
        if (!inTime && student.inTime) inTime = student.inTime;
        if (!outTime && student.outTime) outTime = student.outTime;
      }

      if (status === 'Present') {
        presentCount++;
      }

      return {
        id: student._id,
        rfidCardNumber: student.rfidCardNumber,
        studentName: student.studentName,
        class: student.class,
        status: status,
        inTime: inTime,
        outTime: outTime,
      };
    });

    const totalStudents = students.length;
    const absentCount = totalStudents - presentCount;
    const percentage = totalStudents > 0 ? Math.round((presentCount / totalStudents) * 100) : 0;

    return res.json({
      success: true,
      date: queryDateStr,
      class: studentClass || 'All Classes',
      summary: {
        total: totalStudents,
        present: presentCount,
        absent: absentCount,
        rate: `${percentage}%`,
        percentage: percentage,
      },
      data: records,
    });
  } catch (error) {
    return res.status(500).json({ success: false, message: error.message });
  }
});

module.exports = router;

