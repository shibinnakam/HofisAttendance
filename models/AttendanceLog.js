const mongoose = require('mongoose');

const attendanceLogSchema = new mongoose.Schema(
  {
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: true,
    },
    rfidCardNumber: {
      type: String,
      required: true,
      uppercase: true,
    },
    studentName: {
      type: String,
      required: true,
    },
    class: {
      type: String,
      required: true,
    },
    eventType: {
      type: String,
      enum: ['CHECK_IN', 'CHECK_OUT'],
      required: true,
    },
    timestamp: {
      type: Date,
      default: Date.now,
    },
    dateString: {
      type: String, // YYYY-MM-DD for easy grouping
      default: () => new Date().toISOString().split('T')[0],
      index: true,
    },
  },
  {
    timestamps: true,
  }
);

const AttendanceLog = mongoose.model('AttendanceLog', attendanceLogSchema);

module.exports = AttendanceLog;
