import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/student.dart';
import '../services/api_service.dart';

class CardTapScreen extends StatefulWidget {
  const CardTapScreen({super.key});

  @override
  State<CardTapScreen> createState() => _CardTapScreenState();
}

class _CardTapScreenState extends State<CardTapScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _rfidController = TextEditingController();

  bool _isProcessing = false;
  Map<String, dynamic>? _lastTapResult;
  List<Student> _recentStudents = [];

  @override
  void initState() {
    super.initState();
    _fetchQuickStudents();
  }

  @override
  void dispose() {
    _rfidController.dispose();
    super.dispose();
  }

  Future<void> _fetchQuickStudents() async {
    try {
      final students = await _apiService.getStudents();
      setState(() {
        _recentStudents = students.take(6).toList();
      });
    } catch (_) {}
  }

  Future<void> _handleTap([String? customRfid]) async {
    final rfid = (customRfid ?? _rfidController.text).trim().toUpperCase();
    if (rfid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter or scan RFID card number'),
          backgroundColor: Color(0xFFF43F5E),
        ),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
      _lastTapResult = null;
    });

    try {
      final result = await _apiService.tapCard(rfid);
      setState(() {
        _lastTapResult = result;
        _isProcessing = false;
      });
      _rfidController.clear();
      _fetchQuickStudents();
    } catch (e) {
      setState(() {
        _lastTapResult = {
          'success': false,
          'message': e.toString().replaceFirst('Exception: ', ''),
        };
        _isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = _lastTapResult;
    final isSuccess = result?['success'] == true;
    final student = result?['student'] as Student?;

    return Scaffold(
      backgroundColor: const Color(0xFF0B0F19),
      appBar: AppBar(
        backgroundColor: const Color(0xFF121826),
        elevation: 0,
        title: const Text(
          'Simulate RFID Tap',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Interactive NFC Scanner Visual Box
            Container(
              padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF6366F1).withOpacity(0.2),
                    const Color(0xFF06B6D4).withOpacity(0.08),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFF6366F1).withOpacity(0.35),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF6366F1).withOpacity(0.5),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.nfc_rounded,
                      size: 40,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Ready to Scan Card',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Enter RFID UID or tap a quick card below to record In/Out time.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // RFID Input Field
            TextField(
              controller: _rfidController,
              textCapitalization: TextCapitalization.characters,
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'monospace',
                fontSize: 16,
                letterSpacing: 1.5,
              ),
              decoration: InputDecoration(
                hintText: 'Enter RFID Card UID...',
                hintStyle: const TextStyle(
                  color: Color(0xFF64748B),
                  fontSize: 14,
                  letterSpacing: 0.5,
                ),
                filled: true,
                fillColor: const Color(0xFF121826),
                prefixIcon:
                    const Icon(Icons.credit_card, color: Color(0xFF06B6D4)),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.arrow_forward_rounded,
                      color: Color(0xFF6366F1)),
                  onPressed: () => _handleTap(),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFF06B6D4)),
                ),
              ),
              onSubmitted: (val) => _handleTap(val),
            ),

            const SizedBox(height: 14),

            // Big Tap Button
            SizedBox(
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _isProcessing ? null : () => _handleTap(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF06B6D4),
                  foregroundColor: Colors.white,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: _isProcessing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.tap_and_play_rounded),
                label: Text(
                  _isProcessing ? 'Processing Tap...' : 'Tap Card',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Result Display Card
            if (result != null) ...[
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: isSuccess
                      ? const Color(0xFF10B981).withOpacity(0.12)
                      : const Color(0xFFF43F5E).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSuccess
                        ? const Color(0xFF10B981).withOpacity(0.4)
                        : const Color(0xFFF43F5E).withOpacity(0.4),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isSuccess
                              ? Icons.check_circle_rounded
                              : Icons.error_rounded,
                          color: isSuccess
                              ? const Color(0xFF10B981)
                              : const Color(0xFFF43F5E),
                          size: 24,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            isSuccess
                                ? (result['action'] ?? 'Card Tapped')
                                : 'Scan Failed',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isSuccess
                                  ? const Color(0xFF6EE7B7)
                                  : const Color(0xFFFDA4AF),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      result['message'] ?? '',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFFCBD5E1),
                      ),
                    ),
                    if (student != null) ...[
                      const SizedBox(height: 12),
                      const Divider(color: Colors.white10, height: 1),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            student.studentName,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF6366F1).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              student.studentClass,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFFA5B4FC),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          if (student.inTime != null)
                            Text(
                              'In: ${DateFormat('hh:mm:ss a').format(student.inTime!)}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontFamily: 'monospace',
                                color: Color(0xFF10B981),
                              ),
                            ),
                          if (student.outTime != null) ...[
                            const SizedBox(width: 12),
                            Text(
                              'Out: ${DateFormat('hh:mm:ss a').format(student.outTime!)}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontFamily: 'monospace',
                                color: Color(0xFF06B6D4),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Quick Tap Registered Cards
            if (_recentStudents.isNotEmpty) ...[
              const Text(
                'QUICK TAP REGISTERED STUDENTS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _recentStudents.map((s) {
                  return ActionChip(
                    backgroundColor: const Color(0xFF121826),
                    side: BorderSide(color: Colors.white.withOpacity(0.1)),
                    avatar: CircleAvatar(
                      backgroundColor: const Color(0xFF6366F1).withOpacity(0.2),
                      child: Text(
                        s.studentName.isNotEmpty ? s.studentName[0] : '?',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF818CF8),
                        ),
                      ),
                    ),
                    label: Text(
                      '${s.studentName} (${s.studentClass})',
                      style: const TextStyle(fontSize: 12, color: Colors.white),
                    ),
                    onPressed: () => _handleTap(s.rfidCardNumber),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
