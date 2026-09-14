const mongoose = require('mongoose');
const User = require('../models/User');
const AttendanceLog = require('../models/AttendanceLog');

let lastNightUpdate = null;
let nextScheduledNightUpdate = null;
let timerId = null;

/**
 * Format a Date object into YYYY-MM-DD using local server time
 */
function getLocalDateString(d = new Date()) {
  const year = d.getFullYear();
  const month = String(d.getMonth() + 1).padStart(2, '0');
  const day = String(d.getDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
}

/**
 * Run the 11:59 PM Night Update:
 * 1. Ensure any student currently marked 'Present' has an AttendanceLog saved for today
 * 2. Reset all students' daily live status to 'Absent' and clear inTime/outTime for the new day
 */
async function runNightUpdate() {
  if (mongoose.connection.readyState !== 1) {
    console.warn('⚠️ [11:59 PM NIGHT UPDATE] Database not connected. Skipping night update.');
    return { success: false, message: 'Database not connected' };
  }

  try {
    const now = new Date();
    const todayStr = getLocalDateString(now);

    // 1. Archive/Verify logs for all students marked 'Present' today
    const presentStudents = await User.find({ status: 'Present' });
    let logsCreated = 0;

    for (const student of presentStudents) {
      const existingLog = await AttendanceLog.findOne({
        $or: [
          { userId: student._id, dateString: todayStr },
          { rfidCardNumber: student.rfidCardNumber, dateString: todayStr },
        ],
      });

      if (!existingLog) {
        await AttendanceLog.create({
          userId: student._id,
          rfidCardNumber: student.rfidCardNumber,
          studentName: student.studentName,
          class: student.class,
          eventType: 'CHECK_IN',
          timestamp: student.inTime || now,
          dateString: todayStr,
        });
        logsCreated++;
      }
    }

    // 2. Reset all students to Absent for the upcoming new day
    const resetResult = await User.updateMany(
      {},
      {
        $set: {
          status: 'Absent',
          inTime: null,
          outTime: null,
        },
      }
    );

    lastNightUpdate = new Date();

    console.log(
      `🌙 [11:59 PM NIGHT UPDATE] Completed at ${lastNightUpdate.toLocaleTimeString()} (${todayStr}). ` +
      `Archived ${logsCreated} missing logs, reset ${resetResult.modifiedCount} students to Absent for tomorrow.`
    );

    return {
      success: true,
      timestamp: lastNightUpdate,
      dateString: todayStr,
      logsArchived: logsCreated,
      studentsReset: resetResult.modifiedCount,
    };
  } catch (error) {
    console.error('❌ [11:59 PM NIGHT UPDATE ERROR]:', error.message);
    return { success: false, message: error.message };
  }
}

/**
 * Schedule the night update timer for exactly 11:59:00 PM tonight
 */
function scheduleNightUpdate() {
  if (timerId) {
    clearTimeout(timerId);
  }

  const now = new Date();
  const target = new Date(
    now.getFullYear(),
    now.getMonth(),
    now.getDate(),
    23, 59, 0, 0 // 11:59:00 PM
  );

  // If 11:59 PM has already passed today, schedule for tomorrow 11:59 PM
  if (now.getTime() >= target.getTime()) {
    target.setDate(target.getDate() + 1);
  }

  const msToTarget = target.getTime() - now.getTime();
  nextScheduledNightUpdate = target;

  console.log(
    `⏰ [11:59 PM UPDATE SCHEDULER] Next daily night update scheduled for: ${target.toLocaleString()} (in ${Math.round(msToTarget / 1000 / 60)} minutes)`
  );

  timerId = setTimeout(async () => {
    await runNightUpdate();
    // Re-schedule for the following night
    scheduleNightUpdate();
  }, msToTarget);
}

/**
 * On server startup: check if students still have 'Present' status from a previous day
 * (e.g., if the server was offline at 11:59 PM) and catch up automatically.
 */
async function checkStartupCatchup() {
  try {
    if (mongoose.connection.readyState !== 1) return;

    const now = new Date();
    const todayStart = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 0, 0, 0, 0);

    // Look for students marked Present whose inTime was before today's 00:00:00
    const staleStudents = await User.find({
      status: 'Present',
      inTime: { $lt: todayStart },
    });

    if (staleStudents.length > 0) {
      console.log(`⚠️ [STARTUP CATCHUP] Found ${staleStudents.length} students with previous-day 'Present' status. Running catch-up night update...`);
      await runNightUpdate();
    }
  } catch (e) {
    console.error('Startup catchup error:', e.message);
  }
}

function getNightUpdateStatus() {
  return {
    currentServerTime: new Date().toISOString(),
    currentServerLocalTime: new Date().toLocaleString(),
    lastNightUpdate: lastNightUpdate ? lastNightUpdate.toISOString() : null,
    lastNightUpdateLocal: lastNightUpdate ? lastNightUpdate.toLocaleString() : null,
    nextScheduledNightUpdate: nextScheduledNightUpdate ? nextScheduledNightUpdate.toISOString() : null,
    nextScheduledNightUpdateLocal: nextScheduledNightUpdate ? nextScheduledNightUpdate.toLocaleString() : null,
  };
}

module.exports = {
  getLocalDateString,
  runNightUpdate,
  scheduleNightUpdate,
  checkStartupCatchup,
  getNightUpdateStatus,
};
