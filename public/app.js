// State
let studentsList = [];
let availableClasses = [];
let isEditing = false;
let editingStudentId = null;

// DOM Elements
const studentTableBody = document.getElementById('student-table-body');
const formRfidTap = document.getElementById('form-rfid-tap');
const rfidTapInput = document.getElementById('rfid-tap-input');
const tapBanner = document.getElementById('tap-banner');
const bannerTitle = document.getElementById('banner-title');
const bannerDesc = document.getElementById('banner-desc');
const bannerIcon = document.getElementById('banner-icon');

const statTotal = document.getElementById('stat-total');
const statPresent = document.getElementById('stat-present');
const statAbsent = document.getElementById('stat-absent');
const statRate = document.getElementById('stat-rate');

const filterSearch = document.getElementById('filter-search');
const filterClass = document.getElementById('filter-class');
const filterStatus = document.getElementById('filter-status');
const btnResetDay = document.getElementById('btn-reset-day');

// Modal Elements
const studentModal = document.getElementById('student-modal');
const modalTitle = document.getElementById('modal-title');
const studentForm = document.getElementById('student-form');
const studentIdInput = document.getElementById('student-id');
const formRfid = document.getElementById('form-rfid');
const formName = document.getElementById('form-name');
const formClass = document.getElementById('form-class');
const formStatus = document.getElementById('form-status');
const formInTime = document.getElementById('form-in-time');
const formOutTime = document.getElementById('form-out-time');
const btnOpenCreateModal = document.getElementById('btn-open-create-modal');
const btnCloseModal = document.getElementById('btn-close-modal');
const btnCancelModal = document.getElementById('btn-cancel-modal');
const btnToggleCustomClass = document.getElementById('btn-toggle-custom-class');
const customClassContainer = document.getElementById('custom-class-container');
const formCustomClass = document.getElementById('form-custom-class');

// Hardware Modal Elements
const hardwareModal = document.getElementById('hardware-modal');
const btnHardwareGuide = document.getElementById('btn-hardware-guide');
const btnCloseHardware = document.getElementById('btn-close-hardware');
const btnDismissHardware = document.getElementById('btn-dismiss-hardware');
const btnCopyHardwareCode = document.getElementById('btn-copy-hardware-code');

// Initialize on DOM load
document.addEventListener('DOMContentLoaded', () => {
  loadClasses();
  loadStudents();
  loadStats();
  setupEventListeners();
});

function setupEventListeners() {
  // Simulator tap submission
  formRfidTap.addEventListener('submit', handleRfidTap);

  // Filters
  filterSearch.addEventListener('input', debounce(loadStudents, 300));
  filterClass.addEventListener('change', loadStudents);
  filterStatus.addEventListener('change', loadStudents);

  // New Day Reset
  btnResetDay.addEventListener('click', handleResetDay);

  // Modal handlers
  btnOpenCreateModal.addEventListener('click', openCreateModal);
  btnCloseModal.addEventListener('click', closeModal);
  btnCancelModal.addEventListener('click', closeModal);
  studentForm.addEventListener('submit', handleSaveStudent);

  // Custom class input toggle
  btnToggleCustomClass.addEventListener('click', () => {
    customClassContainer.classList.toggle('hidden');
    if (!customClassContainer.classList.contains('hidden')) {
      formCustomClass.focus();
    }
  });

  // Hardware guide modal handlers
  btnHardwareGuide.addEventListener('click', () => hardwareModal.classList.remove('hidden'));
  btnCloseHardware.addEventListener('click', () => hardwareModal.classList.add('hidden'));
  btnDismissHardware.addEventListener('click', () => hardwareModal.classList.add('hidden'));
  btnCopyHardwareCode.addEventListener('click', () => {
    const code = document.getElementById('hardware-code').innerText;
    navigator.clipboard.writeText(code).then(() => {
      btnCopyHardwareCode.innerText = 'Copied!';
      setTimeout(() => (btnCopyHardwareCode.innerText = 'Copy Arduino Code'), 2000);
    });
  });

  // Close modals on outside click
  window.addEventListener('click', (e) => {
    if (e.target === studentModal) closeModal();
    if (e.target === hardwareModal) hardwareModal.classList.add('hidden');
  });
}

/**
 * Fetch available classes and populate dropdowns
 */
async function loadClasses() {
  try {
    const res = await fetch('/api/classes');
    const result = await res.json();
    if (result.success) {
      availableClasses = result.data;
      populateClassDropdowns(availableClasses);
    }
  } catch (err) {
    console.error('Failed to load classes:', err);
  }
}

function populateClassDropdowns(classes) {
  // Populate filter dropdown
  const currentFilterVal = filterClass.value;
  filterClass.innerHTML = '<option value="">All Classes</option>';
  classes.forEach((cls) => {
    const opt = document.createElement('option');
    opt.value = cls;
    opt.textContent = cls;
    filterClass.appendChild(opt);
  });
  if (currentFilterVal) filterClass.value = currentFilterVal;

  // Populate modal create/edit dropdown
  const currentFormVal = formClass.value;
  formClass.innerHTML = '<option value="" disabled selected>-- Choose Class from Dropdown --</option>';
  classes.forEach((cls) => {
    const opt = document.createElement('option');
    opt.value = cls;
    opt.textContent = cls;
    formClass.appendChild(opt);
  });
  if (currentFormVal) formClass.value = currentFormVal;
}

/**
 * Fetch and render students list with active filters
 */
async function loadStudents() {
  try {
    const search = filterSearch.value.trim();
    const studentClass = filterClass.value;
    const status = filterStatus.value;

    const params = new URLSearchParams();
    if (search) params.append('search', search);
    if (studentClass) params.append('class', studentClass);
    if (status) params.append('status', status);

    const res = await fetch(`/api/users?${params.toString()}`);
    const result = await res.json();

    if (result.success) {
      studentsList = result.data;
      renderStudentsTable(studentsList);
      loadStats();
    } else if (result.connectionStatus === 'disconnected') {
      studentTableBody.innerHTML = `
        <tr>
          <td colspan="7" style="padding: 40px 20px; text-align: center;">
            <div style="max-width: 540px; margin: 0 auto; background: rgba(245, 158, 11, 0.08); border: 1px solid rgba(245, 158, 11, 0.25); border-radius: 12px; padding: 24px;">
              <div style="font-size: 1.5rem; margin-bottom: 8px;">⚙️ MongoDB Atlas Setup Required</div>
              <p style="color: #cbd5e1; font-size: 0.9rem; margin-bottom: 12px;">
                Please paste your MongoDB Atlas connection string into the <code>.env</code> file:
              </p>
              <pre style="background: rgba(0,0,0,0.4); padding: 10px 14px; border-radius: 8px; font-family: monospace; font-size: 0.8rem; color: #f59e0b; overflow-x: auto; text-align: left;">MONGODB_URI=mongodb+srv://&lt;username&gt;:&lt;password&gt;@cluster0.mongodb.net/rfid_attendance</pre>
              <p style="color: #94a3b8; font-size: 0.8rem; margin-top: 12px;">
                Once updated, restart the server to start creating students, selecting classes from the dropdown, and tapping RFID cards!
              </p>
            </div>
          </td>
        </tr>`;
    } else {
      studentTableBody.innerHTML = `<tr><td colspan="7" class="empty-state">${escapeHtml(result.message) || 'Error loading students'}</td></tr>`;
    }
  } catch (err) {
    console.error('Failed to load students:', err);
    studentTableBody.innerHTML = `<tr><td colspan="7" class="empty-state text-rose">Failed to connect to backend server.</td></tr>`;
  }
}

/**
 * Render table rows
 */
function renderStudentsTable(students) {
  if (!students || students.length === 0) {
    studentTableBody.innerHTML = `
      <tr>
        <td colspan="7" class="empty-state">
          No students found matching your criteria. Click <strong>"Register Student"</strong> above to add one.
        </td>
      </tr>`;
    return;
  }

  studentTableBody.innerHTML = students.map((s) => {
    const isPresent = s.status === 'Present';
    const inTimeFormatted = formatTimestamp(s.inTime);
    const outTimeFormatted = formatTimestamp(s.outTime);

    return `
      <tr>
        <td>
          <span class="rfid-pill">${escapeHtml(s.rfidCardNumber)}</span>
        </td>
        <td style="font-weight: 600;">${escapeHtml(s.studentName)}</td>
        <td>
          <span class="class-tag">${escapeHtml(s.class)}</span>
        </td>
        <td>
          <span class="status-pill ${isPresent ? 'status-present' : 'status-absent'}">
            ${s.status}
          </span>
        </td>
        <td class="timestamp-text">${inTimeFormatted}</td>
        <td class="timestamp-text">${outTimeFormatted}</td>
        <td class="text-right">
          <div class="action-buttons">
            <button class="btn btn-outline-sm" title="Simulate Card Tap" onclick="quickTap('${escapeHtml(s.rfidCardNumber)}')">
              ⚡ Tap
            </button>
            <button class="btn btn-icon" title="Edit Student" onclick="openEditModal('${s.id || s._id}')">
              <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7"></path>
                <path d="M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z"></path>
              </svg>
            </button>
            <button class="btn btn-icon btn-delete" title="Delete Student" onclick="deleteStudent('${s.id || s._id}', '${escapeHtml(s.studentName)}')">
              <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <polyline points="3 6 5 6 21 6"></polyline>
                <path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"></path>
              </svg>
            </button>
          </div>
        </td>
      </tr>
    `;
  }).join('');
}

/**
 * Fetch and update dashboard stats
 */
async function loadStats() {
  try {
    const res = await fetch('/api/attendance/stats');
    const result = await res.json();
    if (result.success) {
      statTotal.textContent = result.data.totalStudents;
      statPresent.textContent = result.data.totalPresent;
      statAbsent.textContent = result.data.totalAbsent;
      statRate.textContent = `${result.data.attendanceRate}%`;
    }
  } catch (err) {
    console.error('Failed to load stats:', err);
  }
}

/**
 * Handle RFID Simulator Tap
 */
async function handleRfidTap(e) {
  if (e) e.preventDefault();
  const cardUid = rfidTapInput.value.trim().toUpperCase();

  if (!cardUid) return;

  try {
    const res = await fetch('/api/attendance/tap', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ rfidCardNumber: cardUid }),
    });

    const result = await res.json();

    if (result.success) {
      showBanner('success', `Card Tapped: ${result.action}!`, result.message);
      rfidTapInput.value = '';
      loadStudents();
      loadStats();
    } else {
      showBanner('error', 'Tap Error', result.message);
    }
  } catch (err) {
    showBanner('error', 'Network Error', 'Could not communicate with the backend server.');
  }
}

/**
 * Quick tap from student table row
 */
window.quickTap = function(rfid) {
  rfidTapInput.value = rfid;
  handleRfidTap();
};

/**
 * Show notification banner
 */
function showBanner(type, title, message) {
  tapBanner.className = `tap-banner ${type}`;
  bannerTitle.textContent = title;
  bannerDesc.textContent = message;
  bannerIcon.textContent = type === 'success' ? '✓' : type === 'info' ? 'ℹ' : '✕';
  tapBanner.classList.remove('hidden');

  clearTimeout(tapBanner._timeout);
  tapBanner._timeout = setTimeout(() => {
    tapBanner.classList.add('hidden');
  }, 5000);
}

/**
 * Modal: Open Create
 */
function openCreateModal() {
  isEditing = false;
  editingStudentId = null;
  modalTitle.textContent = 'Register New Student';
  studentForm.reset();
  studentIdInput.value = '';
  formRfid.disabled = false;
  customClassContainer.classList.add('hidden');
  formCustomClass.value = '';
  studentModal.classList.remove('hidden');
  formRfid.focus();
}

/**
 * Modal: Open Edit
 */
window.openEditModal = function(id) {
  const student = studentsList.find((s) => (s.id || s._id) === id);
  if (!student) return;

  isEditing = true;
  editingStudentId = id;
  modalTitle.textContent = 'Edit Student Details';

  studentIdInput.value = student.id || student._id;
  formRfid.value = student.rfidCardNumber;
  formRfid.disabled = false;
  if (formStatus) formStatus.value = student.status || 'Absent';

  // Ensure class exists in dropdown
  if (!availableClasses.includes(student.class)) {
    availableClasses.push(student.class);
    populateClassDropdowns(availableClasses);
  }
  formClass.value = student.class;

  formInTime.value = student.inTime ? toLocalDatetime(student.inTime) : '';
  formOutTime.value = student.outTime ? toLocalDatetime(student.outTime) : '';

  customClassContainer.classList.add('hidden');
  studentModal.classList.remove('hidden');
  formName.focus();
};

function closeModal() {
  studentModal.classList.add('hidden');
  studentForm.reset();
}

/**
 * Save Student (Create or Update)
 */
async function handleSaveStudent(e) {
  e.preventDefault();

  const rfid = formRfid.value.trim().toUpperCase();
  const name = formName.value.trim();
  let studentClass = formClass.value;

  // Check if custom class is entered
  const customCls = formCustomClass.value.trim();
  if (customCls) {
    studentClass = customCls;
  }

  if (!rfid || !name || !studentClass) {
    alert('Please fill in RFID Card UID, Student Name, and select or enter a Class.');
    return;
  }

  const existingStudent = isEditing ? studentsList.find((s) => (s.id || s._id) === editingStudentId) : null;
  const payload = {
    rfidCardNumber: rfid,
    studentName: name,
    class: studentClass,
    status: formStatus ? formStatus.value : (existingStudent ? existingStudent.status : 'Absent'),
    inTime: formInTime.value ? new Date(formInTime.value).toISOString() : null,
    outTime: formOutTime.value ? new Date(formOutTime.value).toISOString() : null,
  };

  try {
    let res, result;
    if (isEditing) {
      res = await fetch(`/api/users/${editingStudentId}`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload),
      });
    } else {
      res = await fetch('/api/users', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload),
      });
    }

    result = await res.json();

    if (result.success) {
      closeModal();
      showBanner('success', isEditing ? 'Student Updated' : 'Student Registered', result.message);
      await loadClasses();
      loadStudents();
      loadStats();
    } else {
      alert(result.message || 'Error saving student');
    }
  } catch (err) {
    alert('Server connection error: ' + err.message);
  }
}

/**
 * Delete Student
 */
window.deleteStudent = async function(id, name) {
  if (!confirm(`Are you sure you want to delete student "${name}"?`)) return;

  try {
    const res = await fetch(`/api/users/${id}`, { method: 'DELETE' });
    const result = await res.json();
    if (result.success) {
      showBanner('info', 'Student Deleted', result.message);
      loadStudents();
      loadStats();
    } else {
      alert(result.message || 'Error deleting student');
    }
  } catch (err) {
    alert('Server connection error: ' + err.message);
  }
};

/**
 * Reset Day Attendance
 */
async function handleResetDay() {
  if (!confirm('Are you sure you want to reset all students to "Absent" and clear In/Out times for a new day?')) {
    return;
  }

  try {
    const res = await fetch('/api/attendance/reset-daily', { method: 'POST' });
    const result = await res.json();
    if (result.success) {
      showBanner('info', 'Daily Reset Complete', result.message);
      loadStudents();
      loadStats();
    } else {
      alert(result.message || 'Error resetting attendance');
    }
  } catch (err) {
    alert('Server connection error: ' + err.message);
  }
}

// Helpers
function formatTimestamp(isoStr) {
  if (!isoStr) return '<span style="opacity: 0.35;">—</span>';
  try {
    const date = new Date(isoStr);
    return date.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit', second: '2-digit' });
  } catch {
    return isoStr;
  }
}

function toLocalDatetime(isoStr) {
  const d = new Date(isoStr);
  const offset = d.getTimezoneOffset() * 60000;
  return new Date(d.getTime() - offset).toISOString().slice(0, 16);
}

function escapeHtml(str) {
  if (!str) return '';
  return String(str)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#039;');
}

function debounce(func, wait) {
  let timeout;
  return function(...args) {
    clearTimeout(timeout);
    timeout = setTimeout(() => func.apply(this, args), wait);
  };
}
