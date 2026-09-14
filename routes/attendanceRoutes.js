const express = require('express');
const router = express.Router();
const User = require('../models/User');
const AttendanceLog = require('../models/AttendanceLog');

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

    // Record immutable audit log
    try {
      await AttendanceLog.create({
        userId: student._id,
        rfidCardNumber: student.rfidCardNumber,
        studentName: student.studentName,
        class: student.class,
        eventType: eventType,
        timestamp: now,
      });
    } catch (logErr) {
      console.error('Failed to write attendance log:', logErr.message);
    }

    return res.json({
      success: true,
      action: action,
      message: `${student.studentName} successfully ${action.toLowerCase()} at ${now.toLocaleTimeString()}`,
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
 * @route   POST /api/attendance/reset-daily
 * @desc    Reset all student statuses to Absent and clear in/out times for a new day
 */
router.post('/reset-daily', async (req, res) => {
  try {
    const result = await User.updateMany(
      {},
      {
        $set: {
          status: 'Absent',
          inTime: null,
          outTime: null,
        },
      }
    );

    return res.json({
      success: true,
      message: `Daily attendance reset completed. Updated ${result.modifiedCount} student records.`,
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

module.exports = router;
