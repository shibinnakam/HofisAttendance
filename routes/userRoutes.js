const express = require('express');
const router = express.Router();
const User = require('../models/User');

// Default initial list of classes for the dropdown
const DEFAULT_CLASSES = [
  'Class 1-A', 'Class 1-B',
  'Class 2-A', 'Class 2-B',
  'Class 3-A', 'Class 3-B',
  'Class 4-A', 'Class 4-B',
  'Class 5-A', 'Class 5-B',
  'Class 6-A', 'Class 6-B',
  'Class 7-A', 'Class 7-B',
  'Class 8-A', 'Class 8-B',
  'Class 9-A', 'Class 9-B',
  'Class 10-A', 'Class 10-B',
  'Class 11 - Science', 'Class 11 - Commerce', 'Class 11 - Arts',
  'Class 12 - Science', 'Class 12 - Commerce', 'Class 12 - Arts',
  'CSE - 1st Year', 'CSE - 2nd Year', 'CSE - 3rd Year', 'CSE - 4th Year',
  'ECE - 1st Year', 'ECE - 2nd Year', 'ECE - 3rd Year', 'ECE - 4th Year',
  'BCA - 1st Year', 'BCA - 2nd Year', 'BCA - 3rd Year'
];

/**
 * @route   GET /api/classes
 * @desc    Get all available classes for the dropdown (merges predefined + database classes)
 */
router.get('/classes', async (req, res) => {
  try {
    let dbClasses = [];
    if (mongoose.connection.readyState === 1) {
      try {
        dbClasses = await User.distinct('class');
      } catch (e) {
        // Ignore DB read error for distinct classes
      }
    }
    const combined = Array.from(new Set([...DEFAULT_CLASSES, ...dbClasses])).filter(Boolean).sort();
    return res.json({ success: true, data: combined });
  } catch (error) {
    return res.status(500).json({ success: false, message: error.message });
  }
});

const mongoose = require('mongoose');

// Middleware to ensure DB is connected before database operations
const checkDb = (req, res, next) => {
  if (mongoose.connection.readyState !== 1) {
    return res.status(503).json({
      success: false,
      message: 'MongoDB Atlas is not connected yet. Please configure your MONGODB_URI in the .env file with your Atlas connection string.',
      connectionStatus: 'disconnected',
    });
  }
  next();
};

/**
 * @route   GET /api/users
 * @desc    Get all users / students (supports ?search=, ?class=, ?status=)
 */
router.get('/users', checkDb, async (req, res) => {
  try {
    const { search, class: studentClass, status } = req.query;
    const query = {};

    if (studentClass) {
      query.class = studentClass;
    }

    if (status) {
      query.status = status;
    }

    if (search) {
      query.$or = [
        { studentName: { $regex: search, $options: 'i' } },
        { rfidCardNumber: { $regex: search, $options: 'i' } },
        { class: { $regex: search, $options: 'i' } },
      ];
    }

    const users = await User.find(query).sort({ updatedAt: -1, studentName: 1 });
    return res.json({
      success: true,
      count: users.length,
      data: users,
    });
  } catch (error) {
    return res.status(500).json({ success: false, message: error.message });
  }
});

/**
 * @route   GET /api/users/:id
 * @desc    Get single user by MongoDB ID or RFID Card Number
 */
router.get('/users/:id', checkDb, async (req, res) => {
  try {
    const { id } = req.params;
    let user = null;

    if (id.match(/^[0-9a-fA-F]{24}$/)) {
      user = await User.findById(id);
    }
    if (!user) {
      user = await User.findOne({ rfidCardNumber: id.toUpperCase() });
    }

    if (!user) {
      return res.status(404).json({ success: false, message: 'Student / User not found' });
    }

    return res.json({ success: true, data: user });
  } catch (error) {
    return res.status(500).json({ success: false, message: error.message });
  }
});

/**
 * @route   POST /api/users
 * @desc    Create a new user / student
 */
router.post('/users', checkDb, async (req, res) => {
  try {
    const { rfidCardNumber, studentName, class: studentClass, status, inTime, outTime } = req.body;

    // Validation
    if (!rfidCardNumber || !studentName || !studentClass) {
      return res.status(400).json({
        success: false,
        message: 'Please provide rfidCardNumber, studentName, and class',
      });
    }

    const normalizedRfid = rfidCardNumber.trim().toUpperCase();

    // Check for duplicate RFID
    const existing = await User.findOne({ rfidCardNumber: normalizedRfid });
    if (existing) {
      return res.status(400).json({
        success: false,
        message: `RFID Card Number ${normalizedRfid} is already assigned to "${existing.studentName}"`,
      });
    }

    const newUser = await User.create({
      rfidCardNumber: normalizedRfid,
      studentName: studentName.trim(),
      class: studentClass.trim(),
      status: status || 'Absent',
      inTime: inTime ? new Date(inTime) : null,
      outTime: outTime ? new Date(outTime) : null,
    });

    return res.status(201).json({
      success: true,
      message: 'Student registered successfully',
      data: newUser,
    });
  } catch (error) {
    if (error.code === 11000) {
      return res.status(400).json({
        success: false,
        message: 'RFID Card Number already registered',
      });
    }
    return res.status(500).json({ success: false, message: error.message });
  }
});

/**
 * @route   PUT /api/users/:id
 * @desc    Update a user / student
 */
router.put('/users/:id', checkDb, async (req, res) => {
  try {
    const { id } = req.params;
    const { rfidCardNumber, studentName, class: studentClass, status, inTime, outTime } = req.body;

    let user = await User.findById(id);
    if (!user) {
      user = await User.findOne({ rfidCardNumber: id.toUpperCase() });
    }

    if (!user) {
      return res.status(404).json({ success: false, message: 'Student / User not found' });
    }

    if (rfidCardNumber) {
      const normalizedRfid = rfidCardNumber.trim().toUpperCase();
      if (normalizedRfid !== user.rfidCardNumber) {
        const existing = await User.findOne({ rfidCardNumber: normalizedRfid });
        if (existing && existing._id.toString() !== user._id.toString()) {
          return res.status(400).json({
            success: false,
            message: `RFID Card Number ${normalizedRfid} is already assigned to "${existing.studentName}"`,
          });
        }
        user.rfidCardNumber = normalizedRfid;
      }
    }

    if (studentName) user.studentName = studentName.trim();
    if (studentClass) user.class = studentClass.trim();
    if (status !== undefined) user.status = status;
    if (inTime !== undefined) user.inTime = inTime ? new Date(inTime) : null;
    if (outTime !== undefined) user.outTime = outTime ? new Date(outTime) : null;

    const updatedUser = await user.save();

    return res.json({
      success: true,
      message: 'Student updated successfully',
      data: updatedUser,
    });
  } catch (error) {
    return res.status(500).json({ success: false, message: error.message });
  }
});

/**
 * @route   DELETE /api/users/:id
 * @desc    Delete a user / student
 */
router.delete('/users/:id', checkDb, async (req, res) => {
  try {
    const { id } = req.params;

    let user = null;
    if (id.match(/^[0-9a-fA-F]{24}$/)) {
      user = await User.findByIdAndDelete(id);
    }
    if (!user) {
      user = await User.findOneAndDelete({ rfidCardNumber: id.toUpperCase() });
    }

    if (!user) {
      return res.status(404).json({ success: false, message: 'Student / User not found' });
    }

    return res.json({
      success: true,
      message: `Student "${user.studentName}" deleted successfully`,
      data: user,
    });
  } catch (error) {
    return res.status(500).json({ success: false, message: error.message });
  }
});

module.exports = router;
