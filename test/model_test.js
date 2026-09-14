const User = require('../models/User');
const AttendanceLog = require('../models/AttendanceLog');

console.log('Testing User Model validation...');

// 1. Missing required fields
const emptyUser = new User({});
const validationErr = emptyUser.validateSync();
if (validationErr && validationErr.errors['rfidCardNumber'] && validationErr.errors['studentName'] && validationErr.errors['class']) {
  console.log('✓ Validation Test Passed: Required fields (rfidCardNumber, studentName, class) properly enforced.');
} else {
  console.error('✗ Validation Test Failed:', validationErr);
  process.exit(1);
}

// 2. Normalization & defaults
const validUser = new User({
  rfidCardNumber: '  a1b2c3d4  ',
  studentName: '  John Doe  ',
  class: 'Class 10-A'
});

if (validUser.rfidCardNumber === 'A1B2C3D4') {
  console.log('✓ Normalization Test Passed: RFID uppercase & trim enforced.');
} else {
  console.error('✗ Normalization Failed for RFID:', validUser.rfidCardNumber);
  process.exit(1);
}

if (validUser.status === 'Absent') {
  console.log('✓ Defaults Test Passed: Default status is "Absent".');
} else {
  console.error('✗ Defaults Test Failed for status:', validUser.status);
  process.exit(1);
}

if (validUser.inTime === null && validUser.outTime === null) {
  console.log('✓ Timestamps Test Passed: Initial inTime and outTime are null.');
} else {
  console.error('✗ Timestamps Test Failed');
  process.exit(1);
}

// 3. Attendance Log schema
const log = new AttendanceLog({
  userId: '507f1f77bcf86cd799439011',
  rfidCardNumber: 'a1b2c3d4',
  studentName: 'John Doe',
  class: 'Class 10-A',
  eventType: 'CHECK_IN'
});

if (log.rfidCardNumber === 'A1B2C3D4' && log.eventType === 'CHECK_IN' && log.dateString) {
  console.log('✓ AttendanceLog Test Passed: Schema validation and default dateString generated.');
} else {
  console.error('✗ AttendanceLog Test Failed');
  process.exit(1);
}

console.log('\nAll model schema unit tests passed successfully!');
