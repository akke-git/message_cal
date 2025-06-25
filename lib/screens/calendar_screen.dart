import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:message_cal/services/calendar_service.dart';
import 'package:googleapis/calendar/v3.dart' as calendar;

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _selectedDate = DateTime.now();
  final CalendarService _calendarService = CalendarService();
  List<calendar.Event> _events = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final events = await _calendarService.getEvents(
        startDate: DateTime(_selectedDate.year, _selectedDate.month, 1),
        endDate: DateTime(_selectedDate.year, _selectedDate.month + 1, 0),
      );
      
      setState(() {
        _events = events;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      print('Failed to load events: $e');
    }
  }

  DateTime _convertToKoreanTime(DateTime utcTime, calendar.Event event) {
    // Google Calendar API가 Asia/Seoul 시간대 이벤트를 UTC로 반환하는 경우
    // 수동으로 9시간을 더해서 한국 시간으로 변환
    if (event.start?.timeZone == 'Asia/Seoul' && utcTime.isUtc) {
      return utcTime.add(const Duration(hours: 9));
    }
    
    // 이미 로컬 시간인 경우 그대로 반환
    return utcTime.toLocal();
  }

  String _getEventCategory(calendar.Event event) {
    // colorId를 기반으로 카테고리 추정
    switch (event.colorId) {
      case '9':
        return '업무';
      case '10':
        return '개인';
      case '11':
        return '건강';
      case '5':
        return '금융';
      default:
        return '기타';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('캘린더'),
        actions: [
          IconButton(
            icon: const Icon(Icons.today),
            onPressed: () {
              setState(() {
                _selectedDate = DateTime.now();
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Month header
          Container(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () {
                    setState(() {
                      _selectedDate = DateTime(
                        _selectedDate.year,
                        _selectedDate.month - 1,
                      );
                    });
                    _loadEvents();
                  },
                ),
                Text(
                  DateFormat('yyyy년 MM월').format(_selectedDate),
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () {
                    setState(() {
                      _selectedDate = DateTime(
                        _selectedDate.year,
                        _selectedDate.month + 1,
                      );
                    });
                    _loadEvents();
                  },
                ),
              ],
            ),
          ),
          
          // Calendar grid placeholder
          Container(
            height: 200,
            margin: const EdgeInsets.symmetric(horizontal: 16.0),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: Text(
                '달력 뷰\n(향후 구현 예정)',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Events list
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '이번 달 일정',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : _events.isEmpty
                            ? const Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.event_note,
                                      size: 60,
                                      color: Colors.grey,
                                    ),
                                    SizedBox(height: 16),
                                    Text(
                                      '등록된 일정이 없습니다',
                                      style: TextStyle(color: Colors.grey),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                itemCount: _events.length,
                                itemBuilder: (context, index) {
                                  final event = _events[index];
                                  final category = _getEventCategory(event);
                                  final startTime = event.start?.dateTime ?? event.start?.date;
                                  
                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    child: ListTile(
                                      leading: CircleAvatar(
                                        backgroundColor: _getCategoryColor(category),
                                        child: Icon(
                                          _getCategoryIcon(category),
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                      ),
                                      title: Text(
                                        event.summary ?? '제목 없음',
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                      subtitle: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          if (startTime != null) ...[
                                            Text(
                                              '${DateFormat('MM월 dd일').format(_convertToKoreanTime(startTime, event))} ${DateFormat('HH:mm').format(_convertToKoreanTime(startTime, event))}',
                                            ),
                                            if (kDebugMode) ...[
                                              Text(
                                                'UTC: ${startTime}',
                                                style: const TextStyle(fontSize: 9, color: Colors.red),
                                              ),
                                              Text(
                                                'KST: ${_convertToKoreanTime(startTime, event)}',
                                                style: const TextStyle(fontSize: 9, color: Colors.blue),
                                              ),
                                            ],
                                          ],
                                          if (event.location != null && event.location!.isNotEmpty)
                                            Text(
                                              '📍 ${event.location}',
                                              style: TextStyle(color: Colors.grey[600]),
                                            ),
                                        ],
                                      ),
                                      trailing: Text(
                                        category,
                                        style: TextStyle(
                                          color: _getCategoryColor(category),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Color _getCategoryColor(String category) {
    switch (category) {
      case '업무':
        return Colors.blue;
      case '개인':
        return Colors.green;
      case '건강':
        return Colors.red;
      case '금융':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }
  
  IconData _getCategoryIcon(String category) {
    switch (category) {
      case '업무':
        return Icons.work;
      case '개인':
        return Icons.person;
      case '건강':
        return Icons.health_and_safety;
      case '금융':
        return Icons.account_balance;
      default:
        return Icons.event;
    }
  }
}
