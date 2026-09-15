const mongoose = require('mongoose');
const User = require('../models/User');
const AttendanceLog = require('../models/AttendanceLog');

let lastNightUpdate = null;
let nextScheduledNightUpdate = null;
let timerId = null;

const APP_TIMEZONE = process.env.TIMEZONE || 'Asia/Kolkata';

/**
 * Format a Date object into YYYY-MM-DD using configured timezone (defaults to Asia/Kolkata)
 */
function getLocalDateString(d = new Date(), timeZone = APP_TIMEZONE) {
  try {
    const formatter = new Intl.DateTimeFormat('en-CA', {
      timeZone: timeZone,
      year: 'numeric',
      month: '2-digit',
      day: '2-digit',
    });
    return formatter.format(d); // Returns 'YYYY-MM-DD'
  } catch (e) {
    const year = d.getFullYear();
    const month = String(d.getMonth() + 1).padStart(2, '0');
    const day = String(d.getDate()).padStart(2, '0');
    return `${year}-${month}-${day}`;
  }
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

function getMsToNext1159PM(timeZone = APP_TIMEZONE) {
  const now = new Date();
  try {
    const parts = new Intl.DateTimeFormat('en-US', {
      timeZone,
      hour12: false,
      hour: 'numeric',
      minute: 'numeric',
      second: 'numeric',
    }).formatToParts(now);

    const hour = parseInt(parts.find((p) => p.type === 'hour').value, 10);
    const minute = parseInt(parts.find((p) => p.type === 'minute').value, 10);
    const second = parseInt(parts.find((p) => p.type === 'second').value, 10);

    const currentSeconds = (hour % 24) * 3600 + minute * 60 + second;
    const targetSeconds = 23 * 3600 + 59 * 60; // 11:59:00 PM

    let diffSeconds = targetSeconds - currentSeconds;
    if (diffSeconds <= 0) {
      diffSeconds += 24 * 3600;
    }
    return diffSeconds * 1000;
  } catch (e) {
    const target = new Date(
      now.getFullYear(),
      now.getMonth(),
      now.getDate(),
      23, 59, 0, 0
    );
    if (now.getTime() >= target.getTime()) {
      target.setDate(target.getDate() + 1);
    }
    return target.getTime() - now.getTime();
  }
}

/**
 * Schedule the night update timer for exactly 11:59:00 PM tonight in the local/configured timezone
 */
function scheduleNightUpdate() {
  if (timerId) {
    clearTimeout(timerId);
  }

  const msToTarget = getMsToNext1159PM(APP_TIMEZONE);
  const target = new Date(Date.now() + msToTarget);
  nextScheduledNightUpdate = target;

  console.log(
    `⏰ [11:59 PM UPDATE SCHEDULER] Next daily night update scheduled for: ${target.toLocaleString('en-US', { timeZone: APP_TIMEZONE })} (${APP_TIMEZONE}) (in ${Math.round(msToTarget / 1000 / 60)} minutes)`
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
    const todayStr = getLocalDateString(now, APP_TIMEZONE);

    // Look for students marked Present whose inTime calendar date was before today's date
    const presentStudents = await User.find({ status: 'Present' });
    const staleStudents = presentStudents.filter((s) => {
      if (!s.inTime) return false;
      const sDate = getLocalDateString(new Date(s.inTime), APP_TIMEZONE);
      return sDate < todayStr;
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
    timezone: APP_TIMEZONE,
    currentServerTime: new Date().toISOString(),
    currentServerLocalTime: new Date().toLocaleString('en-US', { timeZone: APP_TIMEZONE }),
    lastNightUpdate: lastNightUpdate ? lastNightUpdate.toISOString() : null,
    lastNightUpdateLocal: lastNightUpdate ? lastNightUpdate.toLocaleString('en-US', { timeZone: APP_TIMEZONE }) : null,
    nextScheduledNightUpdate: nextScheduledNightUpdate ? nextScheduledNightUpdate.toISOString() : null,
    nextScheduledNightUpdateLocal: nextScheduledNightUpdate ? nextScheduledNightUpdate.toLocaleString('en-US', { timeZone: APP_TIMEZONE }) : null,
  };
}

module.exports = {
  getLocalDateString,
  runNightUpdate,
  scheduleNightUpdate,
  checkStartupCatchup,
  getNightUpdateStatus,
};
