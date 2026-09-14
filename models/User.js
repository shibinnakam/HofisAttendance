const mongoose = require('mongoose');

const userSchema = new mongoose.Schema(
  {
    rfidCardNumber: {
      type: String,
      required: [true, 'RFID Card Number is required'],
      unique: true,
      trim: true,
      uppercase: true,
      index: true,
    },
    studentName: {
      type: String,
      required: [true, 'Student Name is required'],
      trim: true,
    },
    class: {
      type: String,
      required: [true, 'Student Class is required'],
      trim: true,
    },
    status: {
      type: String,
      enum: ['Present', 'Absent'],
      default: 'Absent',
    },
    inTime: {
      type: Date,
      default: null,
    },
    outTime: {
      type: Date,
      default: null,
    },
    lastTap: {
      type: Date,
      default: null,
    }
  },
  {
    timestamps: true,
  }
);

// Virtual to format timestamps if needed
userSchema.set('toJSON', {
  virtuals: true,
  transform: function (doc, ret) {
    ret.id = ret._id;
    delete ret.__v;
    return ret;
  },
});

const User = mongoose.model('User', userSchema);

module.exports = User;
