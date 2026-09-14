import 'dart:math';
import 'package:flutter/material.dart';
import '../models/student.dart';
import '../services/api_service.dart';

class RegisterStudentScreen extends StatefulWidget {
  final Student? studentToEdit;
  final List<String> availableClasses;

  const RegisterStudentScreen({
    super.key,
    this.studentToEdit,
    required this.availableClasses,
  });

  @override
  State<RegisterStudentScreen> createState() => _RegisterStudentScreenState();
}

class _RegisterStudentScreenState extends State<RegisterStudentScreen> {
  final _formKey = GlobalKey<FormState>();
  final ApiService _apiService = ApiService();

  late TextEditingController _rfidController;
  late TextEditingController _nameController;
  late TextEditingController _customClassController;

  String? _selectedClass;
  String _selectedStatus = 'Absent';
  bool _isCustomClass = false;
  bool _isSubmitting = false;

  late List<String> _classList;

  @override
  void initState() {
    super.initState();

    _classList = List<String>.from(widget.availableClasses);
    if (_classList.isEmpty) {
      _classList = [
        'Class 1-A', 'Class 2-A', 'Class 3-A', 'Class 4-A', 'Class 5-A',
        'Class 6-A', 'Class 7-A', 'Class 8-A', 'Class 9-A', 'Class 10-A',
        'Class 11 - Science', 'Class 11 - Commerce', 'Class 11 - Arts',
        'Class 12 - Science', 'Class 12 - Commerce', 'Class 12 - Arts',
        'BCA - 1st Year', 'CSE - 1st Year', 'ECE - 1st Year'
      ];
    }

    final s = widget.studentToEdit;
    _rfidController = TextEditingController(text: s?.rfidCardNumber ?? '');
    _nameController = TextEditingController(text: s?.studentName ?? '');
    _customClassController = TextEditingController();

    if (s != null) {
      _selectedStatus = s.status;
      if (_classList.contains(s.studentClass)) {
        _selectedClass = s.studentClass;
      } else {
        _classList.add(s.studentClass);
        _selectedClass = s.studentClass;
      }
    } else {
      _selectedClass = _classList.first;
    }
  }

  @override
  void dispose() {
    _rfidController.dispose();
    _nameController.dispose();
    _customClassController.dispose();
    super.dispose();
  }

  void _generateRandomRfid() {
    final random = Random();
    final hexDigits = '0123456789ABCDEF';
    String rfid = '';
    for (int i = 0; i < 8; i++) {
      rfid += hexDigits[random.nextInt(hexDigits.length)];
    }
    setState(() {
      _rfidController.text = rfid;
    });
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    final rfid = _rfidController.text.trim().toUpperCase();
    final name = _nameController.text.trim();
    final studentClass = _isCustomClass
        ? _customClassController.text.trim()
        : _selectedClass!;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final student = Student(
        id: widget.studentToEdit?.id ?? '',
        rfidCardNumber: rfid,
        studentName: name,
        studentClass: studentClass,
        status: _selectedStatus,
      );

      if (widget.studentToEdit != null) {
        await _apiService.updateStudent(widget.studentToEdit!.id, student);
      } else {
        await _apiService.createStudent(student);
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.studentToEdit != null
              ? 'Student updated successfully!'
              : 'Student registered successfully!'),
          backgroundColor: const Color(0xFF10B981),
        ),
      );

      Navigator.of(context).pop(true);
    } catch (e) {
      setState(() {
        _isSubmitting = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: const Color(0xFFF43F5E),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.studentToEdit != null;

    return Scaffold(
      backgroundColor: const Color(0xFF0B0F19),
      appBar: AppBar(
        backgroundColor: const Color(0xFF121826),
        elevation: 0,
        title: Text(
          isEditing ? 'Edit Student' : 'Register New Student',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF121826),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.school_rounded,
                        color: Color(0xFF818CF8),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isEditing ? 'Update Details' : 'Student Enrollment',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Select student class from the dropdown and link RFID UID.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Field 1: RFID Card UID
              const Text(
                'RFID Card UID *',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFCBD5E1),
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _rfidController,
                textCapitalization: TextCapitalization.characters,
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'monospace',
                  letterSpacing: 1.0,
                ),
                decoration: InputDecoration(
                  hintText: 'e.g. 5A3F9B2C or E20041',
                  hintStyle: const TextStyle(color: Color(0xFF64748B)),
                  filled: true,
                  fillColor: const Color(0xFF121826),
                  prefixIcon:
                      const Icon(Icons.nfc, color: Color(0xFF6366F1), size: 20),
                  suffixIcon: TextButton(
                    onPressed: _generateRandomRfid,
                    child: const Text(
                      'Auto Gen',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF06B6D4),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF6366F1)),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter or scan RFID card number';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 20),

              // Field 2: Student Full Name
              const Text(
                'Student Full Name *',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFCBD5E1),
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'e.g. Rahul Sharma or Emily Watson',
                  hintStyle: const TextStyle(color: Color(0xFF64748B)),
                  filled: true,
                  fillColor: const Color(0xFF121826),
                  prefixIcon:
                      const Icon(Icons.person_outline, color: Color(0xFF6366F1), size: 20),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF6366F1)),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter student name';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 20),

              // Field 3: Class Selection Dropdown (REQUIRED BY USER)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Select Class from Dropdown *',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFCBD5E1),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _isCustomClass = !_isCustomClass;
                      });
                    },
                    child: Text(
                      _isCustomClass ? '← Choose from Dropdown' : '+ Custom Class',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF06B6D4),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              if (!_isCustomClass) ...[
                DropdownButtonFormField<String>(
                  initialValue: _selectedClass,
                  dropdownColor: const Color(0xFF1E293B),
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color(0xFF121826),
                    prefixIcon: const Icon(Icons.class_outlined,
                        color: Color(0xFF6366F1), size: 20),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF6366F1)),
                    ),
                  ),
                  items: _classList.map((String c) {
                    return DropdownMenuItem<String>(
                      value: c,
                      child: Text(c),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _selectedClass = val;
                    });
                  },
                  validator: (val) {
                    if (val == null || val.isEmpty) {
                      return 'Please select a class';
                    }
                    return null;
                  },
                ),
              ] else ...[
                TextFormField(
                  controller: _customClassController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Enter custom class (e.g., Grade 9-C)',
                    hintStyle: const TextStyle(color: Color(0xFF64748B)),
                    filled: true,
                    fillColor: const Color(0xFF121826),
                    prefixIcon: const Icon(Icons.edit_note,
                        color: Color(0xFF06B6D4), size: 20),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF06B6D4)),
                    ),
                  ),
                  validator: (val) {
                    if (_isCustomClass &&
                        (val == null || val.trim().isEmpty)) {
                      return 'Please enter custom class name';
                    }
                    return null;
                  },
                ),
              ],

              const SizedBox(height: 20),

              // Field 4: Initial Status
              const Text(
                'Initial Attendance Status',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFCBD5E1),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _selectedStatus = 'Absent'),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _selectedStatus == 'Absent'
                              ? const Color(0xFFF43F5E).withOpacity(0.18)
                              : const Color(0xFF121826),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _selectedStatus == 'Absent'
                                ? const Color(0xFFF43F5E)
                                : Colors.white.withOpacity(0.08),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.cancel_rounded,
                              size: 16,
                              color: _selectedStatus == 'Absent'
                                  ? const Color(0xFFF43F5E)
                                  : Colors.white54,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Absent',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _selectedStatus == 'Absent'
                                    ? const Color(0xFFFDA4AF)
                                    : Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: () => setState(() => _selectedStatus = 'Present'),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _selectedStatus == 'Present'
                              ? const Color(0xFF10B981).withOpacity(0.18)
                              : const Color(0xFF121826),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _selectedStatus == 'Present'
                                ? const Color(0xFF10B981)
                                : Colors.white.withOpacity(0.08),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.check_circle_rounded,
                              size: 16,
                              color: _selectedStatus == 'Present'
                                  ? const Color(0xFF10B981)
                                  : Colors.white54,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Present',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _selectedStatus == 'Present'
                                    ? const Color(0xFF6EE7B7)
                                    : Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 36),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitForm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 3,
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          isEditing ? 'Update Student' : 'Save Student',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
