import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/student.dart';
import '../services/api_service.dart';
import 'register_student_screen.dart';
import 'card_tap_screen.dart';
import 'settings_screen.dart';

class AttendanceDashboardScreen extends StatefulWidget {
  const AttendanceDashboardScreen({super.key});

  @override
  State<AttendanceDashboardScreen> createState() =>
      _AttendanceDashboardScreenState();
}

class _AttendanceDashboardScreenState extends State<AttendanceDashboardScreen> {
  final ApiService _apiService = ApiService();

  List<Student> _students = [];
  List<String> _classes = ['All Classes'];
  AttendanceStats _stats = AttendanceStats.empty();

  bool _isLoading = true;
  String? _errorMessage;
  String _selectedClass = 'All Classes';
  String _searchQuery = '';
  String _selectedStatus = 'All';

  Timer? _autoRefreshTimer;
  bool _autoRefresh = true;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _startAutoRefresh();
  }

  void _startAutoRefresh() {
    _autoRefreshTimer?.cancel();
    if (_autoRefresh) {
      _autoRefreshTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
        if (mounted && !_isLoading) {
          _fetchStudentsSilently();
          _fetchStatsSilently();
        }
      });
    }
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final classes = await _apiService.getClasses();
      final stats = await _apiService.getStats();

      setState(() {
        _classes = ['All Classes', ...classes];
        _stats = stats;
      });

      await _fetchStudents();
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchStudents() async {
    try {
      final students = await _apiService.getStudents(
        search: _searchQuery,
        studentClass: _selectedClass == 'All Classes' ? null : _selectedClass,
        status: _selectedStatus == 'All' ? null : _selectedStatus,
      );

      setState(() {
        _students = students;
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchStudentsSilently() async {
    try {
      final students = await _apiService.getStudents(
        search: _searchQuery,
        studentClass: _selectedClass == 'All Classes' ? null : _selectedClass,
        status: _selectedStatus == 'All' ? null : _selectedStatus,
      );
      if (mounted) {
        setState(() {
          _students = students;
          _errorMessage = null;
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchStatsSilently() async {
    try {
      final stats = await _apiService.getStats();
      if (mounted) {
        setState(() {
          _stats = stats;
        });
      }
    } catch (_) {}
  }

  void _openRegisterScreen({Student? studentToEdit}) async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => RegisterStudentScreen(
          studentToEdit: studentToEdit,
          availableClasses: _classes.where((c) => c != 'All Classes').toList(),
        ),
      ),
    );

    if (result == true) {
      _loadInitialData();
    }
  }

  void _openCardTapScreen() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const CardTapScreen()),
    );
    _loadInitialData();
  }

  void _confirmDeleteStudent(Student student) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('Delete Student', style: TextStyle(color: Colors.white)),
        content: Text(
          'Are you sure you want to delete ${student.studentName} (${student.rfidCardNumber})?',
          style: const TextStyle(color: Color(0xFFCBD5E1)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF43F5E),
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _apiService.deleteStudent(student.id);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Deleted ${student.studentName}'),
                    backgroundColor: const Color(0xFF10B981),
                  ),
                );
                _loadInitialData();
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Failed: $e'),
                    backgroundColor: const Color(0xFFF43F5E),
                  ),
                );
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _confirmResetDay() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text('New Day Reset', style: TextStyle(color: Colors.white)),
        content: const Text(
          'This will reset all students status to "Absent" and clear today\'s In/Out times for a new day. Proceed?',
          style: TextStyle(color: Color(0xFFCBD5E1)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF59E0B),
              foregroundColor: Colors.black87,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                final msg = await _apiService.resetDaily();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(msg),
                    backgroundColor: const Color(0xFF10B981),
                  ),
                );
                _loadInitialData();
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Failed: $e'),
                    backgroundColor: const Color(0xFFF43F5E),
                  ),
                );
              }
            },
            child: const Text('Reset All to Absent'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0F19),
      appBar: AppBar(
        backgroundColor: const Color(0xFF121826),
        elevation: 0,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF6366F1), width: 1.5),
            ),
            child: ClipOval(
              child: Image.asset(
                'assets/images/hofis.jpeg',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    const Icon(Icons.school, size: 20, color: Colors.white),
              ),
            ),
          ),
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'HOFIS Attendance Process',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            Text(
              'Live RFID Monitoring',
              style: TextStyle(
                fontSize: 11,
                color: Color(0xFF94A3B8),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          // Quick RFID Tap Button
          IconButton(
            tooltip: 'Simulate RFID Card Tap',
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.4)),
              ),
              child: const Icon(Icons.nfc, color: Color(0xFFA5B4FC), size: 20),
            ),
            onPressed: _openCardTapScreen,
          ),
          // Day Reset Button
          IconButton(
            tooltip: 'New Day Reset',
            icon: const Icon(Icons.restart_alt_rounded, color: Color(0xFFF59E0B)),
            onPressed: _confirmResetDay,
          ),
          // Settings Button
          IconButton(
            tooltip: 'Server Settings',
            icon: const Icon(Icons.settings_outlined, color: Colors.white70),
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (ctx) => const SettingsScreen()),
              );
              _loadInitialData();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadInitialData,
        color: const Color(0xFF6366F1),
        backgroundColor: const Color(0xFF1E293B),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Process Overview Stats Grid
              _buildStatsGrid(),

              const SizedBox(height: 18),

              // 2. Class Selection Dropdown & Status Filter
              _buildFilterSection(),

              const SizedBox(height: 14),

              // 3. Search Bar
              _buildSearchBar(),

              const SizedBox(height: 18),

              // 4. Students Process List Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'STUDENTS (${_students.length})',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _autoRefresh
                              ? const Color(0xFF10B981)
                              : Colors.grey,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _autoRefresh ? 'Live Polling (4s)' : 'Paused',
                        style: TextStyle(
                          fontSize: 11,
                          color: _autoRefresh
                              ? const Color(0xFF6EE7B7)
                              : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // 5. Students Attendance Cards List
              _buildStudentsList(),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF6366F1),
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(Icons.person_add_rounded),
        label: const Text(
          'Register Student',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        onPressed: () => _openRegisterScreen(),
      ),
    );
  }

  Widget _buildStatsGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Row(
          children: [
            Expanded(
              child: _buildStatCard(
                label: 'Total',
                value: '${_stats.totalStudents}',
                icon: Icons.groups_rounded,
                color: const Color(0xFF6366F1),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildStatCard(
                label: 'Present',
                value: '${_stats.totalPresent}',
                icon: Icons.check_circle_rounded,
                color: const Color(0xFF10B981),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildStatCard(
                label: 'Absent',
                value: '${_stats.totalAbsent}',
                icon: Icons.cancel_rounded,
                color: const Color(0xFFF43F5E),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildStatCard(
                label: 'Rate',
                value: '${_stats.attendanceRate}%',
                icon: Icons.insights_rounded,
                color: const Color(0xFF06B6D4),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF121826),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF94A3B8),
                ),
              ),
              Icon(icon, size: 14, color: color),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF121826),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Row(
        children: [
          const Icon(Icons.filter_list_rounded,
              size: 18, color: Color(0xFF818CF8)),
          const SizedBox(width: 8),
          const Text(
            'Class:',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFFCBD5E1),
            ),
          ),
          const SizedBox(width: 10),
          // Class Dropdown Selection
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedClass,
                isExpanded: true,
                dropdownColor: const Color(0xFF1E293B),
                icon: const Icon(Icons.arrow_drop_down, color: Colors.white70),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
                items: _classes.map((String c) {
                  return DropdownMenuItem<String>(
                    value: c,
                    child: Text(c, overflow: TextOverflow.ellipsis),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedClass = val;
                      _isLoading = true;
                    });
                    _fetchStudents();
                  }
                },
              ),
            ),
          ),
          // Status Quick Filter Chip
          const SizedBox(width: 6),
          PopupMenuButton<String>(
            tooltip: 'Filter Status',
            color: const Color(0xFF1E293B),
            icon: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _selectedStatus == 'All'
                    ? Colors.white.withOpacity(0.06)
                    : const Color(0xFF6366F1).withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _selectedStatus,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _selectedStatus == 'Present'
                      ? const Color(0xFF10B981)
                      : _selectedStatus == 'Absent'
                          ? const Color(0xFFF43F5E)
                          : Colors.white70,
                ),
              ),
            ),
            onSelected: (status) {
              setState(() {
                _selectedStatus = status;
                _isLoading = true;
              });
              _fetchStudents();
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(value: 'All', child: Text('All Statuses')),
              const PopupMenuItem(
                  value: 'Present',
                  child: Text('Present Only',
                      style: TextStyle(color: Color(0xFF10B981)))),
              const PopupMenuItem(
                  value: 'Absent',
                  child: Text('Absent Only',
                      style: TextStyle(color: Color(0xFFF43F5E)))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF121826),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: TextField(
        style: const TextStyle(color: Colors.white, fontSize: 13),
        decoration: InputDecoration(
          hintText: 'Search by student name, RFID UID...',
          hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
          prefixIcon:
              const Icon(Icons.search, color: Color(0xFF64748B), size: 18),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 16, color: Colors.white70),
                  onPressed: () {
                    setState(() {
                      _searchQuery = '';
                    });
                    _fetchStudents();
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
        onChanged: (val) {
          _searchQuery = val.trim();
          _fetchStudents();
        },
      ),
    );
  }

  Widget _buildStudentsList() {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(48.0),
          child: CircularProgressIndicator(color: Color(0xFF6366F1)),
        ),
      );
    }

    if (_errorMessage != null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFFF43F5E).withOpacity(0.1),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFF43F5E).withOpacity(0.3)),
        ),
        child: Column(
          children: [
            const Icon(Icons.cloud_off_rounded,
                size: 36, color: Color(0xFFF43F5E)),
            const SizedBox(height: 10),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFFFDA4AF), fontSize: 13),
            ),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              onPressed: _loadInitialData,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Retry Connection'),
            ),
          ],
        ),
      );
    }

    if (_students.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 20),
        alignment: Alignment.center,
        child: Column(
          children: [
            const Icon(Icons.badge_outlined, size: 48, color: Color(0xFF475569)),
            const SizedBox(height: 12),
            const Text(
              'No Students Found',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF94A3B8),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Tap "+ Register Student" below to register new cards.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _students.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final student = _students[index];
        return _buildStudentCard(student);
      },
    );
  }

  Widget _buildStudentCard(Student student) {
    final isPresent = student.isPresent;
    final inTimeStr = student.inTime != null
        ? DateFormat('hh:mm a').format(student.inTime!)
        : '—';
    final outTimeStr = student.outTime != null
        ? DateFormat('hh:mm a').format(student.outTime!)
        : '—';

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF121826),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isPresent
              ? const Color(0xFF10B981).withOpacity(0.25)
              : Colors.white.withOpacity(0.06),
        ),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Student Name + Status Badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar with initial
              CircleAvatar(
                radius: 20,
                backgroundColor: isPresent
                    ? const Color(0xFF10B981).withOpacity(0.18)
                    : const Color(0xFF6366F1).withOpacity(0.18),
                child: Text(
                  student.studentName.isNotEmpty
                      ? student.studentName[0].toUpperCase()
                      : '?',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isPresent
                        ? const Color(0xFF10B981)
                        : const Color(0xFF818CF8),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      student.studentName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        // Class Badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF6366F1).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            student.studentClass,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFFA5B4FC),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // RFID Chip
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.nfc,
                                  size: 11, color: Color(0xFF94A3B8)),
                              const SizedBox(width: 4),
                              Text(
                                student.rfidCardNumber,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontFamily: 'monospace',
                                  color: Color(0xFFCBD5E1),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Status Badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isPresent
                      ? const Color(0xFF10B981).withOpacity(0.18)
                      : const Color(0xFFF43F5E).withOpacity(0.18),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isPresent
                        ? const Color(0xFF10B981).withOpacity(0.4)
                        : const Color(0xFFF43F5E).withOpacity(0.4),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: isPresent
                            ? const Color(0xFF10B981)
                            : const Color(0xFFF43F5E),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      student.status,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: isPresent
                            ? const Color(0xFF6EE7B7)
                            : const Color(0xFFFDA4AF),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          const Divider(color: Colors.white10, height: 1),
          const SizedBox(height: 10),

          // Row 2: In-Time / Out-Time + Action Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Timestamps
              Row(
                children: [
                  _buildTimestampChip(
                    icon: Icons.login_rounded,
                    label: 'In:',
                    time: inTimeStr,
                    color: const Color(0xFF10B981),
                  ),
                  const SizedBox(width: 14),
                  _buildTimestampChip(
                    icon: Icons.logout_rounded,
                    label: 'Out:',
                    time: outTimeStr,
                    color: const Color(0xFF06B6D4),
                  ),
                ],
              ),

              // Actions (Tap / Edit / Delete)
              Row(
                children: [
                  // Tap Card Button
                  IconButton(
                    icon: const Icon(Icons.bolt_rounded,
                        size: 18, color: Color(0xFFF59E0B)),
                    tooltip: 'Simulate Tap for this Card',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () async {
                      try {
                        final result =
                            await _apiService.tapCard(student.rfidCardNumber);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(result['message'] ?? 'Card Tapped'),
                            backgroundColor: result['success'] == true
                                ? const Color(0xFF10B981)
                                : const Color(0xFFF43F5E),
                          ),
                        );
                        _loadInitialData();
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Tap error: $e'),
                            backgroundColor: const Color(0xFFF43F5E),
                          ),
                        );
                      }
                    },
                  ),
                  const SizedBox(width: 14),
                  // Edit Button
                  IconButton(
                    icon: const Icon(Icons.edit_outlined,
                        size: 17, color: Color(0xFF94A3B8)),
                    tooltip: 'Edit Student',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => _openRegisterScreen(studentToEdit: student),
                  ),
                  const SizedBox(width: 14),
                  // Delete Button
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded,
                        size: 17, color: Color(0xFFF43F5E)),
                    tooltip: 'Delete Student',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => _confirmDeleteStudent(student),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimestampChip({
    required IconData icon,
    required String label,
    required String time,
    required Color color,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Color(0xFF64748B),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          time,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            fontFamily: 'monospace',
            color: Color(0xFFCBD5E1),
          ),
        ),
      ],
    );
  }
}
