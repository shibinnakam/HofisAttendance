class Student {
  final String id;
  final String rfidCardNumber;
  final String studentName;
  final String studentClass;
  final String status;
  final DateTime? inTime;
  final DateTime? outTime;
  final DateTime? lastTap;

  Student({
    required this.id,
    required this.rfidCardNumber,
    required this.studentName,
    required this.studentClass,
    required this.status,
    this.inTime,
    this.outTime,
    this.lastTap,
  });

  bool get isPresent => status.toLowerCase() == 'present';

  static DateTime? _parseLocalDate(dynamic val) {
    if (val == null) return null;
    try {
      final dt = DateTime.tryParse(val.toString());
      return dt?.toLocal();
    } catch (_) {
      return null;
    }
  }

  factory Student.fromJson(Map<String, dynamic> json) {
    return Student(
      id: json['id'] ?? json['_id'] ?? '',
      rfidCardNumber: json['rfidCardNumber'] ?? '',
      studentName: json['studentName'] ?? '',
      studentClass: json['class'] ?? '',
      status: json['status'] ?? 'Absent',
      inTime: _parseLocalDate(json['inTime']),
      outTime: _parseLocalDate(json['outTime']),
      lastTap: _parseLocalDate(json['lastTap']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'rfidCardNumber': rfidCardNumber,
      'studentName': studentName,
      'class': studentClass,
      'status': status,
      if (inTime != null) 'inTime': inTime!.toIso8601String(),
      if (outTime != null) 'outTime': outTime!.toIso8601String(),
    };
  }
}

class AttendanceStats {
  final int totalStudents;
  final int totalPresent;
  final int totalAbsent;
  final int attendanceRate;

  AttendanceStats({
    required this.totalStudents,
    required this.totalPresent,
    required this.totalAbsent,
    required this.attendanceRate,
  });

  factory AttendanceStats.fromJson(Map<String, dynamic> json) {
    return AttendanceStats(
      totalStudents: json['totalStudents'] ?? 0,
      totalPresent: json['totalPresent'] ?? 0,
      totalAbsent: json['totalAbsent'] ?? 0,
      attendanceRate: json['attendanceRate'] ?? 0,
    );
  }

  factory AttendanceStats.empty() {
    return AttendanceStats(
      totalStudents: 0,
      totalPresent: 0,
      totalAbsent: 0,
      attendanceRate: 0,
    );
  }
}
