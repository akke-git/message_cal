import 'dart:async';
import 'package:flutter/material.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:intl/intl.dart';
import 'package:message_cal/services/calendar_service.dart';
import 'package:message_cal/services/auth_service.dart';

class ShareReceiverScreen extends StatefulWidget {
  final String? initialText;
  
  const ShareReceiverScreen({super.key, this.initialText});

  @override
  State<ShareReceiverScreen> createState() => _ShareReceiverScreenState();
}

class _ShareReceiverScreenState extends State<ShareReceiverScreen> {
  late StreamSubscription _intentDataStreamSubscription;
  final TextEditingController _textController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  String _selectedCategory = '개인';
  final CalendarService _calendarService = CalendarService();

  @override
  void initState() {
    super.initState();
    
    // Set initial text if provided
    if (widget.initialText != null) {
      _textController.text = widget.initialText!;
      _analyzeText(widget.initialText!);
    }

    // Listen for shared text coming in while the app is open
    _intentDataStreamSubscription =
        ReceiveSharingIntent.instance.getMediaStream().listen((List<SharedMediaFile> value) {
      final textFiles = value.where((file) => file.type == SharedMediaType.text).toList();
      if (textFiles.isNotEmpty) {
        final sharedText = textFiles.first.path; // For text sharing, path contains the actual text
        setState(() {
          _textController.text = sharedText;
        });
        _analyzeText(sharedText);
      }
    }, onError: (err) {
      debugPrint("getMediaStream error: $err");
    });

    // Get text if the app was started via a share
    ReceiveSharingIntent.instance.getInitialMedia().then((List<SharedMediaFile> value) {
      if (value.isNotEmpty) {
        final textFiles = value.where((file) => file.type == SharedMediaType.text).toList();
        if (textFiles.isNotEmpty) {
          final sharedText = textFiles.first.path; // For text sharing, path contains the actual text
          setState(() {
            _textController.text = sharedText;
          });
          _analyzeText(sharedText);
        }
        ReceiveSharingIntent.instance.reset();
      }
    });
  }

  Future<void> _saveToCalendar() async {
    // 로그인 상태 확인
    final authService = AuthService();
    final isSignedIn = await authService.isSignedIn();
    
    if (!isSignedIn) {
      _showErrorSnackBar('Google 계정에 로그인이 필요합니다.');
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
        location: _locationController.text.isNotEmpty 
            ? _locationController.text 
            : null,
        description: '원본 메시지: ${_textController.text}',
        category: _selectedCategory,
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
        Navigator.of(context).pop(); // 화면 닫기
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
  
  void _analyzeText(String text) {
    // Basic text analysis - extract potential schedule information
    // This is a simplified version, can be enhanced with more sophisticated parsing
    
    // Extract title (first line or sentence)
    final lines = text.split('\n');
    if (lines.isNotEmpty) {
      _titleController.text = lines.first.trim();
    }
    
    // Look for location indicators
    final locationRegex = RegExp(r'(에서|에|에서 만나|에서만나|@|at )([^\n,]+)', caseSensitive: false);
    final locationMatch = locationRegex.firstMatch(text.toLowerCase());
    if (locationMatch != null && locationMatch.groupCount >= 2) {
      _locationController.text = locationMatch.group(2)?.trim() ?? '';
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

  @override
  void dispose() {
    _intentDataStreamSubscription.cancel();
    _textController.dispose();
    _titleController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('일정 생성'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          TextButton(
            onPressed: _textController.text.isEmpty ? null : _saveToCalendar,
            child: const Text(
              '저장',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // Original message
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '원본 메시지',
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
                        hintText: '공유된 메시지가 여기에 표시됩니다...',
                      ),
                      readOnly: true,
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
                    
                    // Location
                    TextField(
                      controller: _locationController,
                      decoration: const InputDecoration(
                        labelText: '장소',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.location_on),
                        hintText: '예: 강남역, 사무실 등',
                      ),
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
          ],
        ),
      ),
    );
  }
}
