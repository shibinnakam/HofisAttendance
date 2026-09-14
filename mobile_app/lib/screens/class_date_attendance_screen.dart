import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';

class ClassDateAttendanceScreen extends StatefulWidget {
  final List<String> availableClasses;
  final String? initialClass;

  const ClassDateAttendanceScreen({
    super.key,
    required this.availableClasses,
    this.initialClass,
  });

  @override
  State<ClassDateAttendanceScreen> createState() =>
      _ClassDateAttendanceScreenState();
}

class _ClassDateAttendanceScreenState extends State<ClassDateAttendanceScreen> {
  final ApiService _apiService = ApiService();

  late String _selectedClass;
  late DateTime _selectedDate;
  late List<String> _classList;

  bool _isLoading = false;
  String? _errorMessage;

  Map<String, dynamic> _summary = {
    'total': 0,
    'present': 0,
    'absent': 0,
    'rate': '0%',
  };

  List<dynamic> _students = [];
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();

    _classList = List<String>.from(widget.availableClasses);
    if (!_classList.contains('All Classes')) {
      _classList.insert(0, 'All Classes');
    }

    _selectedClass = widget.initialClass != null &&
            _classList.contains(widget.initialClass)
        ? widget.initialClass!
        : (_classList.length > 1 ? _classList[1] : 'All Classes');

    _selectedDate = DateTime.now();

    _loadReport();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String get _formattedDateParam =>
      DateFormat('yyyy-MM-dd').format(_selectedDate);

  String get _displayDateStr {
    final now = DateTime.now();
    if (_selectedDate.year == now.year &&
        _selectedDate.month == now.month &&
        _selectedDate.day == now.day) {
      return 'Today, ${DateFormat('MMM d, yyyy').format(_selectedDate)}';
    }
    final yesterday = now.subtract(const Duration(days: 1));
    if (_selectedDate.year == yesterday.year &&
        _selectedDate.month == yesterday.month &&
        _selectedDate.day == yesterday.day) {
      return 'Yesterday, ${DateFormat('MMM d, yyyy').format(_selectedDate)}';
    }
    return DateFormat('EEE, MMM d, yyyy').format(_selectedDate);
  }

  Future<void> _pickCustomDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2023, 1, 1),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF6366F1),
              onPrimary: Colors.white,
              surface: Color(0xFF1E293B),
              onSurface: Colors.white,
            ),
            dialogBackgroundColor: const Color(0xFF121826),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      _loadReport();
    }
  }

  Future<void> _loadReport() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await _apiService.getClassDateReport(
        studentClass: _selectedClass,
        date: _formattedDateParam,
      );

      if (res['success'] == true) {
        setState(() {
          _summary = res['summary'] ??
              {'total': 0, 'present': 0, 'absent': 0, 'rate': '0%'};
          _students = res['data'] ?? [];
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = res['message'] ?? 'Failed to load report';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  String _formatTime(dynamic dateVal) {
    if (dateVal == null) return '--:--';
    try {
      final dt = DateTime.parse(dateVal.toString()).toLocal();
      return DateFormat('hh:mm a').format(dt);
    } catch (_) {
      return '--:--';
    }
  }

  List<dynamic> get _filteredStudents {
    if (_searchQuery.trim().isEmpty) return _students;
    final q = _searchQuery.trim().toLowerCase();
    return _students.where((s) {
      final name = (s['studentName'] ?? '').toString().toLowerCase();
      final rfid = (s['rfidCardNumber'] ?? '').toString().toLowerCase();
      final sClass = (s['class'] ?? '').toString().toLowerCase();
      return name.contains(q) || rfid.contains(q) || sClass.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0F19),
      appBar: AppBar(
        backgroundColor: const Color(0xFF121826),
        elevation: 0,
        title: const Text(
          'Class Attendance Report',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF818CF8)),
            onPressed: _loadReport,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Controls Card
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            decoration: BoxDecoration(
              color: const Color(0xFF121826),
              border: Border(
                bottom: BorderSide(color: Colors.white.withOpacity(0.08)),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Class Dropdown Selector
                const Text(
                  'Select Class',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF94A3B8),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: _selectedClass,
                      dropdownColor: const Color(0xFF1E293B),
                      icon: const Icon(Icons.keyboard_arrow_down,
                          color: Color(0xFF818CF8)),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      items: _classList.map((String c) {
                        return DropdownMenuItem<String>(
                          value: c,
                          child: Row(
                            children: [
                              Icon(
                                c == 'All Classes'
                                    ? Icons.groups_rounded
                                    : Icons.class_outlined,
                                size: 16,
                                color: const Color(0xFF818CF8),
                              ),
                              const SizedBox(width: 10),
                              Text(c),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null && val != _selectedClass) {
                          setState(() {
                            _selectedClass = val;
                          });
                          _loadReport();
                        }
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Date Picker Row
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: _pickCustomDate,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: const Color(0xFF6366F1).withOpacity(0.4)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_month_rounded,
                                  size: 18, color: Color(0xFF06B6D4)),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _displayDateStr,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const Icon(Icons.edit_calendar_rounded,
                                  size: 16, color: Color(0xFF94A3B8)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Quick "Today" button
                    OutlinedButton(
                      onPressed: () {
                        setState(() {
                          _selectedDate = DateTime.now();
                        });
                        _loadReport();
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF818CF8),
                        side: BorderSide(
                            color: Colors.white.withOpacity(0.15)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 12),
                      ),
                      child: const Text('Today',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Summary Stats Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: const Color(0xFF0D131F),
            child: Row(
              children: [
                _buildStatItem('Total', '${_summary['total'] ?? 0}',
                    const Color(0xFF818CF8)),
                _buildDivider(),
                _buildStatItem('Present', '${_summary['present'] ?? 0}',
                    const Color(0xFF10B981)),
                _buildDivider(),
                _buildStatItem('Absent', '${_summary['absent'] ?? 0}',
                    const Color(0xFFF43F5E)),
                _buildDivider(),
                _buildStatItem('Rate', '${_summary['rate'] ?? '0%'}',
                    const Color(0xFF06B6D4)),
              ],
            ),
          ),

          // Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search student or RFID...',
                hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                prefixIcon: const Icon(Icons.search,
                    color: Color(0xFF64748B), size: 18),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear,
                            size: 16, color: Color(0xFF64748B)),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFF121826),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFF6366F1)),
                ),
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
          ),

          // Main Content List
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF6366F1)),
                  )
                : _errorMessage != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.error_outline,
                                  size: 44, color: Color(0xFFF43F5E)),
                              const SizedBox(height: 12),
                              Text(
                                _errorMessage!,
                                style: const TextStyle(
                                    color: Color(0xFFFDA4AF), fontSize: 14),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _loadReport,
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF6366F1)),
                                child: const Text('Try Again'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : _filteredStudents.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.person_off_outlined,
                                    size: 48,
                                    color: Colors.white.withOpacity(0.2)),
                                const SizedBox(height: 12),
                                Text(
                                  _students.isEmpty
                                      ? 'No students found in $_selectedClass'
                                      : 'No match for "$_searchQuery"',
                                  style: TextStyle(
                                      color: Colors.white.withOpacity(0.6),
                                      fontSize: 14),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadReport,
                            color: const Color(0xFF6366F1),
                            child: ListView.separated(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              itemCount: _filteredStudents.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 8),
                              itemBuilder: (context, index) {
                                final s = _filteredStudents[index];
                                final isPresent = s['status'] == 'Present';

                                return Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF121826),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isPresent
                                          ? const Color(0xFF10B981)
                                              .withOpacity(0.25)
                                          : Colors.white.withOpacity(0.06),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      // Status Avatar
                                      CircleAvatar(
                                        radius: 20,
                                        backgroundColor: isPresent
                                            ? const Color(0xFF10B981)
                                                .withOpacity(0.18)
                                            : const Color(0xFFF43F5E)
                                                .withOpacity(0.18),
                                        child: Icon(
                                          isPresent
                                              ? Icons.check_circle_rounded
                                              : Icons.cancel_rounded,
                                          color: isPresent
                                              ? const Color(0xFF10B981)
                                              : const Color(0xFFF43F5E),
                                          size: 22,
                                        ),
                                      ),
                                      const SizedBox(width: 14),

                                      // Student Details
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              s['studentName'] ?? 'Unknown',
                                              style: const TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w700,
                                                color: Colors.white,
                                              ),
                                            ),
                                            const SizedBox(height: 3),
                                            Row(
                                              children: [
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                          horizontal: 6,
                                                          vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFF1E293B),
                                                    borderRadius:
                                                        BorderRadius.circular(6),
                                                  ),
                                                  child: Text(
                                                    s['class'] ?? '',
                                                    style: const TextStyle(
                                                      fontSize: 10,
                                                      color: Color(0xFF94A3B8),
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  'RFID: ${s['rfidCardNumber'] ?? '--'}',
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    color: Color(0xFF64748B),
                                                    fontFamily: 'monospace',
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),

                                      // Attendance Times
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.end,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: isPresent
                                                  ? const Color(0xFF10B981)
                                                      .withOpacity(0.2)
                                                  : const Color(0xFFF43F5E)
                                                      .withOpacity(0.2),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              isPresent ? 'PRESENT' : 'ABSENT',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w800,
                                                color: isPresent
                                                    ? const Color(0xFF6EE7B7)
                                                    : const Color(0xFFFDA4AF),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.login,
                                                  size: 11,
                                                  color: isPresent
                                                      ? const Color(0xFF10B981)
                                                      : const Color(0xFF64748B)),
                                              const SizedBox(width: 3),
                                              Text(
                                                _formatTime(s['inTime']),
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: isPresent
                                                      ? Colors.white70
                                                      : const Color(0xFF64748B),
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              Icon(Icons.logout,
                                                  size: 11,
                                                  color: s['outTime'] != null
                                                      ? const Color(0xFF06B6D4)
                                                      : const Color(0xFF64748B)),
                                              const SizedBox(width: 3),
                                              Text(
                                                _formatTime(s['outTime']),
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: s['outTime'] != null
                                                      ? Colors.white70
                                                      : const Color(0xFF64748B),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 24,
      width: 1,
      color: Colors.white.withOpacity(0.08),
    );
  }
}
