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
  String _selectedCategory = '점심';
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
          _selectedCategory = '점심';
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
    
    final cleanText = text.toLowerCase().trim();
    
    // 1. 제목 추출 개선
    _extractTitle(text);
    
    // 2. 날짜 분석 개선
    _extractDate(cleanText);
    
    // 3. 시간 분석 개선
    _extractTime(cleanText);
    
    // 4. 카테고리 분석 개선
    _extractCategory(cleanText);
    
    setState(() {});
  }

  void _extractTitle(String text) {
    // 줄바꿈으로 분리해서 가장 의미있는 첫 번째 줄을 제목으로
    final lines = text.split('\n').where((line) => line.trim().isNotEmpty).toList();
    if (lines.isNotEmpty) {
      String title = lines.first.trim();
      // 불필요한 접두사 제거
      title = title.replaceAll(RegExp(r'^(안녕하세요|안녕|헤이|하이|[!@#$%^&*()])+'), '').trim();
      _titleController.text = title.isNotEmpty ? title : '일정';
    }
  }

  void _extractDate(String text) {
    final now = DateTime.now();
    
    // 상대적 날짜
    if (text.contains('내일') || text.contains('tomorrow')) {
      _selectedDate = now.add(const Duration(days: 1));
    } else if (text.contains('모레') || text.contains('day after tomorrow')) {
      _selectedDate = now.add(const Duration(days: 2));
    } else if (text.contains('오늘') || text.contains('today')) {
      _selectedDate = now;
    } else if (text.contains('다음주') || text.contains('담주')) {
      _selectedDate = now.add(const Duration(days: 7));
    }
    
    // 구체적 날짜 패턴
    final dateRegex = RegExp(r'(\d{1,2})월\s*(\d{1,2})일');
    final dateMatch = dateRegex.firstMatch(text);
    if (dateMatch != null) {
      final month = int.tryParse(dateMatch.group(1)!) ?? now.month;
      final day = int.tryParse(dateMatch.group(2)!) ?? now.day;
      int year = now.year;
      
      // 월이 현재보다 작으면 내년으로 설정
      if (month < now.month || (month == now.month && day < now.day)) {
        year = now.year + 1;
      }
      
      _selectedDate = DateTime(year, month, day);
    }
  }

  void _extractTime(String text) {
    // 오전/오후 시간
    final amPmRegex = RegExp(r'(오전|오후)\s*(\d{1,2})(?:시)?(?:\s*(\d{1,2})분?)?');
    final amPmMatch = amPmRegex.firstMatch(text);
    if (amPmMatch != null) {
      final isPm = amPmMatch.group(1) == '오후';
      int hour = int.tryParse(amPmMatch.group(2)!) ?? 0;
      final minute = int.tryParse(amPmMatch.group(3) ?? '0') ?? 0;
      
      if (isPm && hour != 12) hour += 12;
      if (!isPm && hour == 12) hour = 0;
      
      _selectedTime = TimeOfDay(hour: hour, minute: minute);
      return;
    }
    
    // 24시간 형식
    final time24Regex = RegExp(r'(\d{1,2}):(\d{2})|(\d{1,2})시(?:\s*(\d{1,2})분?)?');
    final time24Match = time24Regex.firstMatch(text);
    if (time24Match != null) {
      int hour = 0;
      int minute = 0;
      
      if (time24Match.group(1) != null && time24Match.group(2) != null) {
        hour = int.tryParse(time24Match.group(1)!) ?? 0;
        minute = int.tryParse(time24Match.group(2)!) ?? 0;
      } else if (time24Match.group(3) != null) {
        hour = int.tryParse(time24Match.group(3)!) ?? 0;
        minute = int.tryParse(time24Match.group(4) ?? '0') ?? 0;
      }
      
      _selectedTime = TimeOfDay(hour: hour, minute: minute);
    }
  }

  void _extractCategory(String text) {
    // 카테고리별 키워드와 가중치
    final categoryKeywords = {
      '예약': ['예약', '병원', '미용실', '치과', '상담', '약속', '클리닉'],
      '점심': ['점심', '식사', '밥', '먹자', '맛집', '카페', '브런치', '저녁'],
      '골프': ['골프', '라운딩', '필드', '연습장', '운동', '헬스', '짐', '수영'],
      '결제': ['결제', '카드값', '대금', '청구서', '납부', '요금', '비용'],
      '기념일': ['생일', '기념일', '축하', '파티', '선물', '이벤트'],
      '회사': ['회의', '업무', '출장', '프레젠테이션', '미팅', '컨퍼런스', '워크샵'],
    };
    
    String bestCategory = '점심'; // 기본값
    int maxScore = 0;
    
    for (final entry in categoryKeywords.entries) {
      final category = entry.key;
      final keywords = entry.value;
      int score = 0;
      
      for (final keyword in keywords) {
        if (text.contains(keyword)) {
          score += keyword.length; // 긴 키워드에 더 높은 점수
        }
      }
      
      if (score > maxScore) {
        maxScore = score;
        bestCategory = category;
      }
    }
    
    _selectedCategory = bestCategory;
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
                        DropdownMenuItem(value: '예약', child: Text('예약')),
                        DropdownMenuItem(value: '점심', child: Text('점심')),
                        DropdownMenuItem(value: '골프', child: Text('골프')),
                        DropdownMenuItem(value: '결제', child: Text('결제')),
                        DropdownMenuItem(value: '기념일', child: Text('기념일')),
                        DropdownMenuItem(value: '회사', child: Text('회사')),
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