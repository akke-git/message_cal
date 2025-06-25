import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:message_cal/services/calendar_service.dart';
import 'package:message_cal/services/auth_service.dart';

class AddScreen extends StatefulWidget {
  const AddScreen({super.key});

  @override
  State<AddScreen> createState() => _AddScreenState();
}

class _AddScreenState extends State<AddScreen> {
  final TextEditingController _textController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  String _selectedCategory = '개인';
  int _reminderMinutes = 30;
  final CalendarService _calendarService = CalendarService();

  Future<void> _saveToCalendar() async {
    // 로그인 상태 확인
    final authService = AuthService();
    final isSignedIn = await authService.isSignedIn();
    final currentUser = authService.getCurrentUser();
    
    if (!isSignedIn || currentUser == null) {
      _showErrorSnackBar('Google 계정에 로그인이 필요합니다. 설정에서 로그인해주세요.');
      return;
    }

    // 필수 필드 검증
    if (_titleController.text.isEmpty) {
      _showErrorSnackBar('일정 제목을 입력해주세요.');
      return;
    }

    if (_selectedDate == null) {
      _showErrorSnackBar('날짜를 선택해주세요.');
      return;
    }

    // 로딩 표시
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      final success = await _calendarService.createEvent(
        title: _titleController.text,
        startDate: _selectedDate!,
        startTime: _selectedTime,
        location: 'Seoul',
        description: _textController.text.isNotEmpty 
            ? '원본 메시지: ${_textController.text}' 
            : '수동 입력으로 생성된 일정',
        category: _selectedCategory,
        reminderMinutes: _reminderMinutes,
      );

      Navigator.of(context).pop(); // 로딩 다이얼로그 닫기

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('일정이 Google Calendar에 저장되었습니다: ${_titleController.text}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
        
        // 폼 초기화
        _textController.clear();
        _titleController.clear();
        setState(() {
          _selectedDate = null;
          _selectedTime = null;
          _selectedCategory = '개인';
          _reminderMinutes = 30;
        });
      } else {
        _showErrorSnackBar('일정 저장에 실패했습니다. 다시 시도해주세요.');
      }
    } catch (e) {
      Navigator.of(context).pop(); // 로딩 다이얼로그 닫기
      _showErrorSnackBar('오류가 발생했습니다: $e');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }
  
  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  void _analyzeText(String text) {
    if (text.isEmpty) return;
    
    // Basic text analysis - extract potential schedule information
    // Extract title (first line or sentence)
    final lines = text.split('\n');
    if (lines.isNotEmpty) {
      _titleController.text = lines.first.trim();
    }
    
    // Look for date/time indicators
    final now = DateTime.now();
    if (text.contains('내일')) {
      _selectedDate = now.add(const Duration(days: 1));
    } else if (text.contains('모레')) {
      _selectedDate = now.add(const Duration(days: 2));
    } else if (text.contains('오늘')) {
      _selectedDate = now;
    }
    
    // Look for time indicators
    final timeRegex = RegExp(r'(\d{1,2})시|(\d{1,2}):(\d{2})|오후 (\d{1,2})시|오전 (\d{1,2})시');
    final timeMatch = timeRegex.firstMatch(text);
    if (timeMatch != null) {
      int hour = 0;
      int minute = 0;
      
      if (timeMatch.group(1) != null) {
        hour = int.tryParse(timeMatch.group(1)!) ?? 0;
      } else if (timeMatch.group(2) != null && timeMatch.group(3) != null) {
        hour = int.tryParse(timeMatch.group(2)!) ?? 0;
        minute = int.tryParse(timeMatch.group(3)!) ?? 0;
      } else if (timeMatch.group(4) != null) {
        hour = (int.tryParse(timeMatch.group(4)!) ?? 0) + 12;
      } else if (timeMatch.group(5) != null) {
        hour = int.tryParse(timeMatch.group(5)!) ?? 0;
      }
      
      _selectedTime = TimeOfDay(hour: hour, minute: minute);
    }
    
    // Categorize based on keywords
    if (text.contains('회의') || text.contains('미팅') || text.contains('업무')) {
      _selectedCategory = '업무';
    } else if (text.contains('병원') || text.contains('운동') || text.contains('헬스')) {
      _selectedCategory = '건강';
    } else if (text.contains('상담') || text.contains('투자') || text.contains('보험')) {
      _selectedCategory = '금융';
    }
    
    setState(() {});
  }

  @override
  void dispose() {
    _textController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('일정 추가'),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Original message
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '메시지 입력',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8.0),
                    TextField(
                      controller: _textController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: '일정 관련 메시지를 입력하면 자동으로 분석됩니다...\n예: 내일 오후 2시 회의',
                      ),
                      onChanged: _analyzeText,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16.0),
            
            // Event details form
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '일정 세부사항',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16.0),
                    
                    // Title
                    TextField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: '일정 제목',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.title),
                      ),
                    ),
                    const SizedBox(height: 16.0),
                    
                    // Date
                    InkWell(
                      onTap: _selectDate,
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: '날짜',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.calendar_today),
                        ),
                        child: Text(
                          _selectedDate != null
                              ? '${_selectedDate!.year}년 ${_selectedDate!.month}월 ${_selectedDate!.day}일'
                              : '날짜를 선택하세요',
                        ),
                      ),
                    ),
                    const SizedBox(height: 16.0),
                    
                    // Time
                    InkWell(
                      onTap: _selectTime,
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: '시간',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.access_time),
                        ),
                        child: Text(
                          _selectedTime != null
                              ? '${_selectedTime!.format(context)}'
                              : '시간을 선택하세요',
                        ),
                      ),
                    ),
                    const SizedBox(height: 16.0),
                    
                    // Reminder
                    DropdownButtonFormField<int>(
                      value: _reminderMinutes,
                      decoration: const InputDecoration(
                        labelText: '알림',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.alarm),
                      ),
                      items: const [
                        DropdownMenuItem(value: 0, child: Text('없음')),
                        DropdownMenuItem(value: 10, child: Text('10분 전')),
                        DropdownMenuItem(value: 30, child: Text('30분 전')),
                        DropdownMenuItem(value: 60, child: Text('1시간 전')),
                        DropdownMenuItem(value: 120, child: Text('2시간 전')),
                        DropdownMenuItem(value: 1440, child: Text('1일 전')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _reminderMinutes = value;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16.0),
                    
                    // Category
                    DropdownButtonFormField<String>(
                      value: _selectedCategory,
                      decoration: const InputDecoration(
                        labelText: '카테고리',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.category),
                      ),
                      items: const [
                        DropdownMenuItem(value: '개인', child: Text('개인')),
                        DropdownMenuItem(value: '업무', child: Text('업무')),
                        DropdownMenuItem(value: '건강', child: Text('건강')),
                        DropdownMenuItem(value: '금융', child: Text('금융')),
                        DropdownMenuItem(value: '기타', child: Text('기타')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _selectedCategory = value;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24.0),
            
            // Save button
            ElevatedButton.icon(
              onPressed: _titleController.text.isEmpty ? null : _saveToCalendar,
              icon: const Icon(Icons.save),
              label: const Text('캘린더에 저장'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}